#!/bin/sh
# Exercises the embedded transaction against a temporary, file-backed FORWARD chain.
# No Docker daemon, elevated privileges or real firewall utilities are needed.
set -eu
tool_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
export CAFE_FIXTURE="$root"
mkdir "$root/bin"
sed 's|^dir=/run/swagpc-cafe-waf$|dir=$CAFE_FIXTURE/journal|' "$tool_dir/waf-policy.sh" > "$root/policy"
grep -Fq 'dir=$CAFE_FIXTURE/journal' "$root/policy"
cat > "$root/bin/iptables" <<'MOCK'
#!/bin/sh
set -eu
shift 2 # -w 5
case "$1" in
    -t) cat "$CAFE_FIXTURE/chain" ;;
    -C) shift; grep -Fxq -- "-A $*" "$CAFE_FIXTURE/chain" ;;
    *) exit 1 ;;
esac
MOCK
cat > "$root/bin/iptables-restore" <<'MOCK'
#!/bin/sh
set -eu
cat > "$CAFE_FIXTURE/input"
case "$*" in *--test*) exit 0 ;; esac
[ ! -f "$CAFE_FIXTURE/fail" ] || exit 1
awk '
    NR == FNR { rows[++n] = $0; next }
    /^-I FORWARD 1 / {
        sub(/^-I FORWARD 1 /, "-A FORWARD ")
        for (i=n; i>=2; i--) rows[i+1]=rows[i]
        rows[2]=$0; n++; next
    }
    /^-D FORWARD / {
        sub(/^-D /, "-A ")
        for (i=2; i<=n; i++) if (rows[i]==$0) {
            for (j=i; j<n; j++) rows[j]=rows[j+1]
            n--; next
        }
        exit 1
    }
    END { for (i=1; i<=n; i++) print rows[i] }
' "$CAFE_FIXTURE/chain" "$CAFE_FIXTURE/input" > "$CAFE_FIXTURE/next"
mv "$CAFE_FIXTURE/next" "$CAFE_FIXTURE/chain"
MOCK
printf '%s\n' '#!/bin/sh' 'test ! -f "$CAFE_FIXTURE/busy"' > "$root/bin/flock"
if command -v chmod >/dev/null; then chmod +x "$root/bin/"*; fi
for tool in iptables iptables-restore flock; do
    [ -x "$root/bin/$tool" ] || exit 1
done
export PATH="$root/bin:$PATH"
printf '%s\n' '-P FORWARD DROP' '-A FORWARD -s 10.0.0.0/24 -j ACCEPT' > "$root/start"
cp "$root/start" "$root/chain"
sh "$root/policy" apply
grep -Fq -- '--sport 8080' "$root/chain"
cp "$root/chain" "$root/managed"
sh "$root/policy" apply
cmp "$root/chain" "$root/managed"
sh "$root/policy" rollback
cmp "$root/chain" "$root/start"
sh "$root/policy" rollback
touch "$root/fail"
if sh "$root/policy" apply; then exit 1; fi
cmp "$root/chain" "$root/start"
rm "$root/fail"
touch "$root/busy"
if sh "$root/policy" apply; then exit 1; fi
cmp "$root/chain" "$root/start"
rm "$root/busy"
sh "$root/policy" apply
echo '-A FORWARD -s 10.1.0.0/24 -j DROP' >> "$root/chain"
cp "$root/chain" "$root/drifted"
if sh "$root/policy" rollback; then exit 1; fi
cmp "$root/chain" "$root/drifted"
echo "PASS: scoped reply, repeat apply, exact restore, repeat rollback, failure, busy lock and drift"
