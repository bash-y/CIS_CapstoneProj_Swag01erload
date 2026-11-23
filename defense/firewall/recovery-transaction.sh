#!/bin/sh
# Execute in an identified disposable café router or workstation.
set -eu
umask 077
die() { echo "cafe firewall: $*" >&2; exit 1; }
case "$#:$*" in
    '2:router apply'|'2:router rollback') parent=FORWARD; managed=CAFE150_GUEST ;;
    '2:workstation apply'|'2:workstation rollback') parent=INPUT; managed=CAFE150_WORKSTATION ;;
    *) die 'expected router|workstation apply|rollback' ;;
esac
action=$2
dir=/run/swagpc-firewall-recovery
mkdir -p "$dir"
exec 9>"$dir/lock"
flock -n 9 || die 'another recovery operation is active'
work=$(mktemp -d "$dir/operation.XXXXXX")
trap 'rm -f "$work/current" "$work/remainder" "$work/batch" "$work/prior" "$work/expected" "$work/numbered"; rmdir "$work"' EXIT
trap 'exit 1' HUP INT TERM

guest=192.168.10.0/24
business=192.168.20.0/24
if [ "$parent" = FORWARD ]; then
    hook="-s $guest -d $business -j $managed"
    cat > "$work/expected" <<RULES
-m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
-j LOG --log-prefix FW-DROP-GUEST: --log-level 4
-j DROP
RULES
else
    hook="-j $managed"
    cat > "$work/expected" <<RULES
-i lo -j RETURN
-m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
-s $business -j RETURN
-s $guest -j LOG --log-prefix WS-ENDPOINT-DROP-GUEST: --log-level 4
-s $guest -j DROP
-j LOG --log-prefix WS-ENDPOINT-DROP-OTHER: --log-level 4
-j DROP
RULES
fi

# Number each owned rule so both membership and order survive backend formatting.
awk '{ if ($0 ~ /^-j /) $0=" " $0; sub(/ -j /, " -m comment --comment CAFE150-" NR " -j "); print }' \
    "$work/expected" > "$work/numbered"

read_policy() { iptables -w 5 -S "$parent" > "$work/current"; }
has_chain() { iptables -w 5 -S "$managed" >/dev/null 2>&1; }
matches() {
    has_chain || return 1
    # Require our jump to be first and the prior chain to follow byte-for-byte.
    sed -n '2p' "$work/current" | grep -Fq -- " -j $managed" || return 1
    iptables -w 5 -C "$parent" $hook || return 1
    sed '2d' "$work/current" > "$work/remainder"
    cmp -s "$dir/prior" "$work/remainder" || return 1
    # Canonical order from iptables -S also verifies the order of the owned rules.
    actual=$(iptables -w 5 -S "$managed") || return 1
    expected_count=$(wc -l < "$work/numbered")
    printf '%s\n' "$actual" | awk -v n="$expected_count" '
        NR>1 && $0 !~ ("--comment \"?CAFE150-" (NR-1) "\"? ") { invalid=1 }
        END { exit (invalid || NR != n+1) }'
    [ "$?" -eq 0 ] || return 1
    while IFS= read -r rule; do iptables -w 5 -C "$managed" $rule || return 1; done < "$work/numbered"
}

build_batch() {
    {
        echo '*filter'
        if [ "$action" = apply ]; then
            echo "-N $managed"
            while IFS= read -r rule; do echo "-A $managed $rule"; done < "$work/numbered"
            echo "-I $parent 1 $hook"
        else
            echo "-D $parent $hook"
            echo "-F $managed"
            echo "-X $managed"
        fi
        echo COMMIT
    } > "$work/batch"
}

read_policy || die 'cannot read existing policy'
if [ ! -f "$dir/prior" ]; then
    if has_chain; then die 'reserved chain exists without a journal'; fi
    if [ "$action" = rollback ]; then echo 'No managed policy to restore.'; exit 0; fi
    cp "$work/current" "$work/prior"
    mv "$work/prior" "$dir/prior"
fi

if cmp -s "$dir/prior" "$work/current" && ! has_chain; then
    if [ "$action" = rollback ]; then
        rm "$dir/prior"
        echo "Original $parent policy already in place."
        exit 0
    fi
elif matches; then
    if [ "$action" = apply ]; then echo "Managed $parent policy already active."; exit 0; fi
else
    die 'policy changed outside the transaction; journal retained'
fi

build_batch
# A single COMMIT prevents a partially installed policy. The journal is in place
# before the transaction, so rollback can identify either side after interruption.
iptables-restore -w 5 --noflush --test < "$work/batch" || die 'invalid policy batch'
iptables-restore -w 5 --noflush < "$work/batch" || die 'no confirmed commit; run rollback'
read_policy || die 'cannot verify policy; run rollback'
if [ "$action" = rollback ]; then
    cmp -s "$dir/prior" "$work/current" && ! has_chain || die 'rollback differs from journal'
    rm "$dir/prior"
    echo "Original $parent policy restored."
else
    matches || die 'installed policy differs from journal; inspect before retrying'
    echo "Managed $parent policy active."
fi
