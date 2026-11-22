#!/bin/bash
# test-suricata-rules.sh: check that Suricata loads configs/monitoring/swagpc-custom.rules and that the
# recon, SQL injection and command injection rules alert on matching traffic. US-11 (#77).
#
#   bash scripts/testing/test-suricata-rules.sh
#
# Part 1 runs "suricata -T" on the lab's config and rules, using the Suricata image pinned in
# docker/docker-compose.yml. Part 2 sends a small recon burst, one SQL injection request and one command
# injection request between two throwaway containers (a client at 10.79.1.50 and a web server at
# 10.79.2.20 on a private network), captures them to a pcap, and replays the pcap through Suricata offline.
# Suricata's GUEST_NET and BUSINESS_NET are overridden to those test addresses, so nothing touches the lab
# subnets or a running lab. The traffic never leaves the two containers. This is a replay of synthetic
# traffic, not a capture from the live lab. Needs Docker, Docker Hub and Ubuntu's apt mirrors.
# Exit code 0 only if every check passes.

set -u
cd "$(dirname "$0")/../.."

SURICATA=$(sed -n 's/^ *image: \(jasonish\/suricata[^ ]*\)$/\1/p' docker/docker-compose.yml)
[ -n "$SURICATA" ] || { echo "[ERROR] no Suricata image found in docker/docker-compose.yml"; exit 2; }
CLIENT_IMG=swagpc-suritest:local
RULES="$PWD/configs/monitoring/swagpc-custom.rules"
PASS=0 FAIL=0

W=$(mktemp -d)
mkdir -p "$W/cap" "$W/logs"
cleanup() {
  docker rm -f suritest-guest suritest-biz >/dev/null 2>&1
  docker network rm suritest >/dev/null 2>&1
  rm -rf "$W"
}
trap cleanup EXIT
cleanup_early() { docker rm -f suritest-guest suritest-biz >/dev/null 2>&1; docker network rm suritest >/dev/null 2>&1; }
cleanup_early
mkdir -p "$W/cap" "$W/logs"

expect() {  # expect <label> <0 = pass>
  if [ "$2" = 0 ]; then echo "  [PASS] $1"; PASS=$((PASS+1)); else echo "  [FAIL] $1"; FAIL=$((FAIL+1)); fi
}

# The image ships no default ruleset (suricata.rules), so list only the custom file; the lab config is otherwise unchanged.
sed '/^  - suricata.rules$/d' configs/monitoring/suricata.yaml > "$W/suricata.yaml"
suri() { docker run --rm -v "$W/suricata.yaml:/etc/suricata/suricata.yaml:ro" -v "$RULES:/etc/suricata/rules/swagpc-custom.rules:ro" "$@"; }

echo "=== Part 1: Suricata loads the custom rules ($SURICATA) ==="
n=$(grep -c '^alert' "$RULES")
suri "$SURICATA" -T -c /etc/suricata/suricata.yaml -v > "$W/test.txt" 2>&1
expect "suricata -T exits 0" $?
grep -q "$n rules successfully loaded, 0 rules failed" "$W/test.txt"; expect "all $n rules in the file load, 0 fail" $?
grep -E "rules successfully loaded|^Error" "$W/test.txt" | sed 's/^/    /'

echo "=== Part 2: replay synthetic recon and web-attack traffic ==="
docker build -q -t "$CLIENT_IMG" - >/dev/null <<'EOF' || { echo "[ERROR] image build failed (needs Ubuntu apt mirrors)"; exit 2; }
FROM ubuntu:22.04@sha256:f64b2ffc2f10ab8f8505aa56b2664bd846cbb9df87c7e2532e30f7667021c0e6
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends tcpdump curl python3 >/dev/null
EOF
docker network create --subnet 10.79.0.0/16 suritest >/dev/null
docker run -d --name suritest-biz --network suritest --ip 10.79.2.20 "$CLIENT_IMG" sh -c 'cd /tmp && exec python3 -m http.server 80' >/dev/null
docker run -d --name suritest-guest --network suritest --ip 10.79.1.50 -v "$W/cap:/cap" "$CLIENT_IMG" sleep infinity >/dev/null
sleep 2
docker exec -d suritest-guest tcpdump -i eth0 -U -w /cap/t.pcap host 10.79.2.20
sleep 2
docker exec suritest-guest bash -c 'for p in $(seq 9001 9030); do timeout 1 bash -c "echo > /dev/tcp/10.79.2.20/$p" 2>/dev/null; done'
docker exec suritest-guest curl -s -m 3 -o /dev/null "http://10.79.2.20/?id=1%27%20union%20select%201,2"
docker exec suritest-guest curl -s -m 3 -o /dev/null -d 'ip=127.0.0.1;cat /etc/passwd&Submit=Submit' http://10.79.2.20/
sleep 1
docker exec suritest-guest pkill tcpdump
sleep 1
[ -s "$W/cap/t.pcap" ]; expect "traffic was captured to a pcap" $?

# The lab config writes fast.log to the absolute path /var/log/suricata/fast.log, so mount the log folder there.
suri -v "$W/cap:/cap" -v "$W/logs:/var/log/suricata" "$SURICATA" -r /cap/t.pcap -c /etc/suricata/suricata.yaml -k none \
  --set 'vars.address-groups.GUEST_NET=[10.79.1.0/24]' --set 'vars.address-groups.BUSINESS_NET=[10.79.2.0/24]' > "$W/replay.txt" 2>&1
expect "suricata replay exits 0" $?

fast="$W/logs/fast.log"
for sig in "SWAGPC RECON" "SWAGPC WEB SQL Injection" "SWAGPC WEB Command Injection"; do
  grep -q "$sig.*10\.79\.1\.50.*-> 10\.79\.2\.20" "$fast" 2>/dev/null; expect "alert in fast.log: $sig (source 10.79.1.50)" $?
done
echo "--- fast.log"; sed 's/^/    /' "$fast" 2>/dev/null | cut -c1-170

echo "=== Result: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
