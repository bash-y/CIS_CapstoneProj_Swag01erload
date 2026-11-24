#!/bin/sh
# Embedded in CafeSecurity.exe. The caller pins the local café firewall container ID.
# The journal identifies the expected FORWARD policy; rollback deletes only our rules.
set -eu
umask 077

die() { echo "WAF routing: $*" >&2; exit 1; }

[ "$#" -eq 1 ] || die "expected apply or rollback"
case "$1" in apply|rollback) ;; *) die "expected apply or rollback" ;; esac
action=$1

dir=/run/swagpc-cafe-waf
prefix=SWAGPC_CAFE_WAF_V1_
for tool in iptables iptables-restore flock; do
    command -v "$tool" >/dev/null || die "missing required router utility: $tool"
done
mkdir -p "$dir"
exec 9>"$dir/lock"
flock -n 9 || die "another routing operation is active"

work=$(mktemp -d "$dir/transaction.XXXXXX")
trap 'rm -f "$work/current" "$work/remainder" "$work/batch" "$work/prior"; rmdir "$work"' EXIT
trap 'exit 1' HUP INT TERM

guest=192.168.10.0/24
business=192.168.20.0/24
# The scoped equivalent of the base route-waf-only policy. Traffic outside
# Guest -> Business continues through the pre-existing rules in its original order.
established="-s $guest -d $business -m state --state ESTABLISHED,RELATED -m comment --comment ${prefix}ESTABLISHED -j ACCEPT"
proxy="-s $guest -d 192.168.20.15/32 -p tcp --dport 8080 -m comment --comment ${prefix}PROXY -j ACCEPT"
reply="-s 192.168.20.15/32 -d $guest -p tcp --sport 8080 -m state --state ESTABLISHED -m comment --comment ${prefix}REPLY -j ACCEPT"
deny="-s $guest -d $business -m comment --comment ${prefix}DENY -j DROP"

read_forward() {
    iptables -w 5 -t filter -S FORWARD > "$work/current" || die "cannot read FORWARD policy"
    grep -q '^-P FORWARD ' "$work/current" || die "unexpected FORWARD listing"
}

has_managed_prefix() {
    # A canonical iptables listing may reorder match options. Check rule semantics
    # with -C and validate exact position independently using the unique comments.
    awk -v prefix="$prefix" '
        NR == 2 { first = index($0, prefix "ESTABLISHED") }
        NR == 3 { second = index($0, prefix "PROXY") }
        NR == 4 { third = index($0, prefix "REPLY") }
        NR == 5 { fourth = index($0, prefix "DENY") }
        index($0, prefix) { count++ }
        END { exit !(first && second && third && fourth && count == 4) }
    ' "$work/current" &&
        iptables -w 5 -C FORWARD $established &&
        iptables -w 5 -C FORWARD $proxy &&
        iptables -w 5 -C FORWARD $reply &&
        iptables -w 5 -C FORWARD $deny
}

matches_managed() {
    has_managed_prefix || return 1
    sed '2,5d' "$work/current" > "$work/remainder" || return 1
    cmp -s "$dir/prior" "$work/remainder"
}

commit_rules() {
    # One COMMIT to one table. --noflush keeps other chains and policies intact.
    {
        echo '*filter'
        if [ "$1" = apply ]; then
            echo "-I FORWARD 1 $deny"
            echo "-I FORWARD 1 $reply"
            echo "-I FORWARD 1 $proxy"
            echo "-I FORWARD 1 $established"
        else
            echo "-D FORWARD $established"
            echo "-D FORWARD $proxy"
            echo "-D FORWARD $reply"
            echo "-D FORWARD $deny"
        fi
        echo COMMIT
    } > "$work/batch"
    iptables-restore -w 5 --noflush --test < "$work/batch" &&
        iptables-restore -w 5 --noflush < "$work/batch"
}

read_forward
if [ ! -f "$dir/prior" ]; then
    if grep -Fq "$prefix" "$work/current"; then
        die "found reserved rule markers without their journal; inspect the router"
    fi
    if [ "$action" = rollback ]; then
        echo "WAF routing: no managed policy to roll back"
        exit 0
    fi
    cp "$work/current" "$work/prior"
    mv "$work/prior" "$dir/prior"
fi

if cmp -s "$dir/prior" "$work/current"; then
    if [ "$action" = rollback ]; then
        rm "$dir/prior"
        echo "WAF routing: prior policy already in place"
        exit 0
    fi
elif matches_managed; then
    if [ "$action" = apply ]; then
        echo "WAF routing: managed policy already in place"
        exit 0
    fi
else
    die "FORWARD changed outside this transaction; leaving the policy and journal intact"
fi

if ! commit_rules "$action"; then
    read_forward
    if cmp -s "$dir/prior" "$work/current"; then
        rm "$dir/prior"
    elif [ "$action" = apply ] && matches_managed; then
        commit_rules rollback || die "apply failed; rollback pending with journal intact"
        read_forward
        cmp -s "$dir/prior" "$work/current" || die "rollback needs inspection; journal retained"
        rm "$dir/prior"
    fi
    die "$action failed; inspect the local router before retrying"
fi

read_forward
if [ "$action" = rollback ]; then
    cmp -s "$dir/prior" "$work/current" || die "post-rollback drift; journal retained"
    rm "$dir/prior"
    echo "WAF routing: original FORWARD policy restored"
elif matches_managed; then
    echo "WAF routing: scoped rules installed; prior policy journal retained"
elif has_managed_prefix; then
    # An independent writer changed the baseline while we applied. Remove only
    # our verified prefix, keeping the other writer's rules and the journal.
    commit_rules rollback || die "post-apply drift; recovery requires inspection"
    die "post-apply drift; managed prefix removed, journal retained for inspection"
else
    die "post-apply validation failed; leaving rules and journal intact for inspection"
fi
