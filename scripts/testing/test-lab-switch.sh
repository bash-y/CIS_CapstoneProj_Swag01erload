#!/bin/bash
# test-lab-switch.sh: run the real lab.sh and docker-compose.yml through every mode switch. US-17 (#127).
#
#   bash scripts/testing/test-lab-switch.sh
#
# Uses the real lab.sh, the real compose file, the real firewall-init.sh, and the real DVWA, WAF and
# Suricata images. Only the firewall, Kali, workstation and business server are Ubuntu stand-ins, and the
# two Wazuh services are off (scripts/testing/lab-standin.override.yml), because those images need package
# hosts that may be blocked. So this is not a run of the full lab. The lab runs under its own compose project
# name (labswitch). The test refuses to start if any swagpc-* container or the guest-net or business-net
# network already exists, and it removes everything it created at the end, including its own volumes.
# Checks: baseline is a working positive control; defended blocks Guest to Business and DVWA direct but allows
# Guest to the WAF and all employee (Business) traffic; this holds after a mode switch, a firewall restart
# and a stop and start; a plain start is defended; lab data in a named volume is never lost.
# Exit code 0 only if every check passes. Needs Docker, Docker Hub and Ubuntu's apt mirrors.

set -u
cd "$(dirname "$0")/../.."

P=labswitch
export LAB_COMPOSE="docker compose -p $P -f docker/docker-compose.yml -f scripts/testing/lab-standin.override.yml"
IMG=swagpc-labstandin:local
VOL="${P}_suricata_logs"
PASS=0 FAIL=0

if docker ps -a --format '{{.Names}}' | grep -q '^swagpc-' || docker network ls --format '{{.Name}}' | grep -qxE 'guest-net|business-net'; then
  echo "[ERROR] a swagpc-* container or the guest-net / business-net network already exists. Stop the lab first (bash lab.sh stop)."
  exit 2
fi

W=$(mktemp -d)
anon() { docker volume ls -q --filter label=com.docker.volume.anonymous | sort; }
anon > "$W/anon.before"
# lab.sh stop is "compose down" without -v, so the anonymous volumes the Suricata image declares are orphaned each
# time. Remove the ones this run created (and only those), after removing the test's own project volumes.
cleanup() {
  $LAB_COMPOSE down -v >/dev/null 2>&1
  comm -13 "$W/anon.before" <(anon) | xargs -r docker volume rm >/dev/null 2>&1
  rm -rf "$W"
}
trap cleanup EXIT

expect() {  # expect <label> <0 = pass>
  if [ "$2" = 0 ]; then echo "  [PASS] $1"; PASS=$((PASS+1)); else echo "  [FAIL] $1"; FAIL=$((FAIL+1)); fi
}

code() { docker exec "$1" curl -s -m 4 -o /dev/null -w '%{http_code}' "$2" 2>/dev/null; }

reach() {  # reach <kali|workstation> <up|down> <label> <url>: "up" is any HTTP answer, "down" is none
  local c
  c=$(code "swagpc-$1" "$4")
  if [ "$2" = up ] && [ -n "$c" ] && [ "$c" != 000 ]; then echo "  [PASS] $1 -> $3 answers (HTTP $c)"; PASS=$((PASS+1))
  elif [ "$2" = down ] && [ "$c" = 000 ]; then echo "  [PASS] $1 -> $3 is blocked"; PASS=$((PASS+1))
  else echo "  [FAIL] $1 -> $3 should be $2 (got HTTP ${c:-none})"; FAIL=$((FAIL+1)); fi
}

WAF=http://192.168.20.15:8080/ DVWA=http://192.168.20.10/ BIZ=http://192.168.20.20/

wait_up() {  # DVWA and the WAF take a while to start; the employee path does not cross the router
  for _ in $(seq 1 60); do
    [ "$(code swagpc-workstation $DVWA)" != 000 ] && [ "$(code swagpc-workstation $WAF)" != 000 ] \
      && [ "$(code swagpc-workstation $BIZ)" != 000 ] && return 0
    sleep 2
  done
  return 1
}

employee_paths() {  # the Business-internal paths never cross the router, so they must work in every mode
  reach workstation up "business server" $BIZ
  reach workstation up "DVWA" $DVWA
  reach workstation up "WAF" $WAF
}

defended_paths() {
  reach kali up "WAF (the allowed Guest path)" $WAF
  reach kali down "DVWA direct" $DVWA
  reach kali down "business server" $BIZ
  employee_paths
}

baseline_paths() {
  reach kali up "WAF" $WAF
  reach kali up "DVWA direct" $DVWA
  reach kali up "business server" $BIZ
  employee_paths
}

mode_is() { bash lab.sh mode 2>/dev/null | grep -q "configured=$1 live=$1"; }
fw_id() { docker inspect -f '{{.Id}}' swagpc-firewall 2>/dev/null; }
marker() { [ "$(docker run --rm --user root -v "$VOL:/d:ro" --entrypoint cat "$IMG" /d/marker 2>/dev/null)" = lab-data ]; }

echo "=== building the stand-in image ==="
docker build -q -t "$IMG" - >/dev/null <<'EOF' || { echo "[ERROR] image build failed (needs Ubuntu apt mirrors)"; exit 2; }
FROM ubuntu:22.04@sha256:f64b2ffc2f10ab8f8505aa56b2664bd846cbb9df87c7e2532e30f7667021c0e6
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends iptables iproute2 curl python3 >/dev/null
EOF

echo "=== lab.sh start baseline (positive control: everything must be reachable) ==="
bash lab.sh start baseline > "$W/start.log" 2>&1; expect "lab.sh start baseline exits 0" $?
grep -q "Entering BASELINE" "$W/start.log"; expect "baseline announces itself" $?
mode_is baseline; expect "lab.sh mode: configured=baseline live=baseline" $?
wait_up; expect "DVWA, WAF and the business server answer the workstation" $?
baseline_paths
docker run --rm --user root -v "$VOL:/d" --entrypoint sh "$IMG" -c 'echo lab-data > /d/marker'; expect "lab data written to a named volume" $?

before=$(fw_id)
echo "=== lab.sh defend ==="
bash lab.sh defend > "$W/defend.log" 2>&1; expect "lab.sh defend exits 0" $?
[ "$(fw_id)" != "$before" ] && [ -n "$(fw_id)" ]; expect "the firewall container was recreated" $?
mode_is defended; expect "lab.sh mode: configured=defended live=defended" $?
defended_paths
marker; expect "lab data survived the switch" $?
bash lab.sh attack >/dev/null 2>&1; [ $? = 1 ]; expect "lab.sh attack refuses in the defended mode (exit 1)" $?

echo "=== firewall container restart ==="
docker restart swagpc-firewall >/dev/null
for _ in $(seq 1 30); do mode_is defended && break; sleep 1; done
mode_is defended; expect "defended rules are back after the restart" $?
defended_paths

echo "=== lab.sh undefend, then defend again ==="
bash lab.sh undefend >/dev/null 2>&1; expect "lab.sh undefend exits 0" $?
mode_is baseline; expect "lab.sh mode: baseline" $?
baseline_paths
marker; expect "lab data survived the switch to baseline" $?
bash lab.sh defend >/dev/null 2>&1; expect "lab.sh defend exits 0 again" $?
defended_paths

echo "=== lab.sh stop, then a plain lab.sh start ==="
bash lab.sh stop >/dev/null 2>&1; expect "lab.sh stop exits 0" $?
docker volume inspect "$VOL" >/dev/null 2>&1; expect "the named volume still exists after stop" $?
bash lab.sh start > "$W/start2.log" 2>&1; expect "plain lab.sh start exits 0" $?
mode_is defended; expect "a plain start is DEFENDED" $?
wait_up; expect "services answer after the restart" $?
defended_paths
marker; expect "lab data survived stop and start" $?

echo "=== Result: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
