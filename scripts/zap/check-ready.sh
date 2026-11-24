#!/bin/bash
# check-ready.sh: readiness checks for the swagpc-zap container. US-19 (#130).
#
#   bash scripts/zap/check-ready.sh            all checks; needs the rest of the lab (firewall, WAF, DVWA) running
#   bash scripts/zap/check-ready.sh --no-lab   skip the checks that need the rest of the lab; they are reported as SKIPPED
#
# Starts no scan. Every call has a finite timeout, and every failure says what to do next.
# Exit code 0 only if every check that ran passed. A SKIPPED check is not a pass.
# Start the runner first:  docker compose -f docker/docker-compose.yml --profile zap up -d zap

set -u
cd "$(dirname "$0")/../.."

Z="${ZAP_CONTAINER:-swagpc-zap}"
FW="${FIREWALL_CONTAINER:-swagpc-firewall}"
WAF=http://192.168.20.15:8080/
DVWA=http://192.168.20.10/
LAB=1
[ "${1:-}" = "--no-lab" ] && LAB=0
PASS=0 FAIL=0 SKIP=0

t() {  # t <seconds> <command...>: run with a time limit (timeout, gtimeout on macOS with coreutils, or none)
  local s=$1; shift
  if command -v timeout >/dev/null; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null; then gtimeout "$s" "$@"
  else "$@"; fi
}
ok()   { echo "  [PASS] $1"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $1"; [ -n "${2:-}" ] && echo "         -> $2"; FAIL=$((FAIL+1)); }
skip() { echo "  [SKIPPED] $1 (--no-lab)"; SKIP=$((SKIP+1)); }
zexec() { t "${T:-60}" docker exec "$@"; }

echo "=== ZAP runner readiness ($Z) ==="

echo "--- configuration (no Docker daemon needed)"
if out=$(python3 -I scripts/zap/zap_check.py config 2>&1); then ok "compose service and allowlist pass zap_check.py"; else bad "zap_check.py config" "$out"; fi

echo "--- container"
if [ "$(t 20 docker inspect -f '{{.State.Running}}' "$Z" 2>/dev/null)" != true ]; then
  bad "$Z is running" "start it: docker compose -f docker/docker-compose.yml --profile zap up -d zap  (then: docker logs $Z)"
  echo "=== Result: $PASS passed, $FAIL failed, $SKIP skipped ==="
  exit 1
fi
ok "$Z is running"

img=$(t 20 docker inspect -f '{{.Config.Image}}' "$Z")
echo "      image: $img"
status=$(zexec "$Z" grep -E '^(Uid|CapEff|CapBnd|NoNewPrivs)' /proc/1/status | tr -s '\t ' ' ' | tr '\n' ';')
case "$status" in
  "Uid: 1000 1000 1000 1000;CapEff: 0000000000000000;CapBnd: 0000000000000000;NoNewPrivs: 1;") ok "main process runs as zap (uid 1000) with no capabilities and no-new-privs" ;;
  *) bad "main process identity" "expected uid 1000, empty capability sets, NoNewPrivs 1; got: $status" ;;
esac

net=$(zexec "$Z" python3 -c '
import socket, struct
ip = lambda h: socket.inet_ntoa(struct.pack("<L", int(h, 16)))
rows = [l.split() for l in open("/proc/net/route").read().splitlines()[1:]]
nics = {l.split(":")[0].strip() for l in open("/proc/net/dev").read().splitlines()[2:]} - {"lo"}
connected = {(ip(r[1]), ip(r[7])) for r in rows if r[2] == "00000000" and r[1] != "00000000"}
via = {(ip(r[1]), ip(r[2]), ip(r[7])) for r in rows if int(r[3], 16) & 2 and r[1] != "00000000"}
if len(nics) != 1: print("FAIL: expected one network interface, found %s" % sorted(nics))
elif connected != {("192.168.10.0", "255.255.255.0")}: print("FAIL: directly connected networks are %s, expected only the Guest network" % sorted(connected))
elif via != {("192.168.20.0", "192.168.10.254", "255.255.255.0")}: print("FAIL: routes via a gateway are %s, expected only 192.168.20.0/24 via 192.168.10.254" % sorted(via))
else: print("OK")
' 2>&1)
if [ "$net" = OK ]; then ok "Guest network only (192.168.10.0/24), Business reached only via the firewall 192.168.10.254"; else bad "network placement" "$net"; fi

if zexec -u zap "$Z" sh -c 'f=/zap/wrk/.ready.$$; touch "$f" && rm "$f"' 2>/dev/null; then ok "report folder /zap/wrk is writable by zap"; else bad "report folder /zap/wrk" "it must be writable by zap; check the zap_reports volume and docker logs $Z"; fi

want=$(printf '%s' "$img" | sed 's/.*:\([^:@]*\)@.*/\1/')
got=$(T=120 zexec -u zap "$Z" /zap/zap.sh -cmd -silent -version 2>/dev/null | tail -1)
if [ "$got" = "$want" ]; then ok "ZAP reports version $got, the pinned tag"; else bad "ZAP version" "pinned tag is '$want', ZAP says '$got'"; fi

live=$(T=120 zexec -u zap "$Z" /zap/zap.sh -cmd -silent -addonlist 2>/dev/null | grep -P '\t')
recorded=$(grep -v '^#' configs/zap/addons.txt)
if [ -n "$live" ] && [ "$live" = "$recorded" ]; then ok "$(printf '%s\n' "$live" | wc -l | tr -d ' ') add-on versions match configs/zap/addons.txt"
else bad "add-on versions" "they differ from configs/zap/addons.txt; the image may have changed. Compare: diff <(docker exec -u zap $Z /zap/zap.sh -cmd -silent -addonlist | grep -P '\t') <(grep -v '^#' configs/zap/addons.txt)"; fi

echo "--- the Guest path through the firewall"
code() { zexec -u zap "$Z" curl -s -m 5 -o /dev/null -w '%{http_code}' "$1" 2>/dev/null; }
if [ "$LAB" = 0 ]; then
  skip "firewall mode, WAF reachable from the scanner, DVWA direct path matches the mode"
else
  mode=$(t 20 docker exec "$FW" sh /scripts/firewall/firewall-init.sh status 2>/dev/null)
  case "$mode" in defended|baseline) ok "firewall is in $mode mode" ;; *) bad "firewall mode" "got '${mode:-none}'; start the lab: bash lab.sh start" ;; esac
  c=$(code $WAF)
  if [ -n "$c" ] && [ "$c" != 000 ]; then ok "scanner reaches the WAF $WAF through the firewall (HTTP $c)"
  else bad "scanner reaches the WAF" "got no answer. On Docker 28 or newer with bridge netfilter on, the host may drop the traffic before the firewall; see wiki/Lab-Modes.md"; fi
  d=$(code $DVWA)
  if [ "$mode" = defended ]; then
    [ "$d" = 000 ] && ok "DVWA direct $DVWA is blocked in defended mode, as it should be" || bad "DVWA direct path in defended mode" "expected no answer, got HTTP $d"
  elif [ "$mode" = baseline ]; then
    [ -n "$d" ] && [ "$d" != 000 ] && ok "DVWA direct $DVWA is reachable in baseline mode (HTTP $d)" || bad "DVWA direct path in baseline mode" "expected an answer, got none"
  fi
fi

echo "=== Result: $PASS passed, $FAIL failed, $SKIP skipped ==="
[ "$FAIL" -eq 0 ]
