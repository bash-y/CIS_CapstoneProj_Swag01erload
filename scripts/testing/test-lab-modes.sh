#!/bin/bash
# test-lab-modes.sh: prove the firewall modes (US-17, #127) on a small stand-in topology.
#
#   bash scripts/testing/test-lab-modes.sh
#
# Runs the real defense/firewall/firewall-init.sh in a throwaway firewall container between a Guest
# client and a WAF and a Business server, on private test subnets (10.77.10.0/24 and 10.77.20.0/24)
# that do not touch the lab. All containers and networks are named modetest-* and removed on exit.
# The containers are Ubuntu, not the lab images, so this proves the rule logic and the restart and
# recreation behavior, not the lab's own containers. Needs Docker and access to Ubuntu's apt mirrors.
# Exit code 0 only if every check passes.

set -u
cd "$(dirname "$0")/../.."

IMG=swagpc-modetest:local
GUEST_NET=10.77.10.0/24 BIZ_NET=10.77.20.0/24
FW_ENV=(-e GUEST_NET=$GUEST_NET -e BUSINESS_NET=$BIZ_NET -e WAF_IP=10.77.20.15 -e WAF_PORT=8080)
PASS=0 FAIL=0

cleanup() {
  docker rm -f modetest-fw modetest-waf modetest-biz modetest-guest >/dev/null 2>&1
  docker network rm modetest-guest modetest-biz >/dev/null 2>&1
}
trap cleanup EXIT
cleanup

check() {  # check <label> <expected http code> <url>
  local got
  got=$(docker exec modetest-guest curl -s -m 3 -o /dev/null -w '%{http_code}' "$3" 2>/dev/null)
  if [ "$got" = "$2" ]; then echo "  [PASS] $1 (got $got)"; PASS=$((PASS+1)); else echo "  [FAIL] $1 (want $2, got $got)"; FAIL=$((FAIL+1)); fi
}

expect() {  # expect <label> <condition result 0|1>
  if [ "$2" = 0 ]; then echo "  [PASS] $1"; PASS=$((PASS+1)); else echo "  [FAIL] $1"; FAIL=$((FAIL+1)); fi
}

start_fw() {  # start_fw <LAB_MODE> [nocap]: "nocap" starts the container without NET_ADMIN
  local caps=(--cap-add NET_ADMIN)
  [ "${2:-}" = nocap ] && caps=()
  docker rm -f modetest-fw >/dev/null 2>&1
  docker run -d --name modetest-fw --network modetest-guest --ip 10.77.10.254 --sysctl net.ipv4.ip_forward=1 \
    -e LAB_MODE="$1" "${FW_ENV[@]}" -v "$PWD/defense/firewall:/scripts/firewall:ro" "${caps[@]}" \
    --entrypoint sh "$IMG" -c 'sh /scripts/firewall/firewall-init.sh apply && exec tail -f /dev/null' >/dev/null
  docker network connect --ip 10.77.20.254 modetest-biz modetest-fw
}

running() {  # the firewall container is up, so a dropped packet is the firewall's doing and not a dead router
  [ "$(docker inspect -f '{{.State.Running}}' modetest-fw 2>/dev/null)" = true ]
}

wait_mode() {  # wait_mode <mode>: the live rules report this mode within 15 s
  for _ in $(seq 1 15); do
    [ "$(docker exec modetest-fw sh /scripts/firewall/firewall-init.sh status 2>/dev/null)" = "$1" ] && return 0
    sleep 1
  done
  return 1
}

echo "=== Building the stand-in image (Ubuntu with iptables, curl, python3) ==="
docker build -q -t "$IMG" - >/dev/null <<'EOF' || { echo "[ERROR] image build failed (needs Ubuntu apt mirrors)"; exit 2; }
FROM ubuntu:22.04@sha256:f64b2ffc2f10ab8f8505aa56b2664bd846cbb9df87c7e2532e30f7667021c0e6
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends iptables iproute2 curl python3 >/dev/null
EOF

echo "=== Building the stand-in topology ==="
# Docker 28 and newer drop packets addressed to a container IP that arrive from another bridge, on hosts with
# bridge netfilter on. That would drop Guest traffic before the firewall sees it, so these two disposable test
# networks turn the filter off (gateway_mode_ipv4=nat-unprotected). Older Docker may not know the option.
for spec in "modetest-guest $GUEST_NET" "modetest-biz $BIZ_NET"; do
  set -- $spec
  docker network create -o com.docker.network.bridge.gateway_mode_ipv4=nat-unprotected --subnet "$2" "$1" >/dev/null 2>&1 \
    || docker network create --subnet "$2" "$1" >/dev/null
done
# Servers answer through the firewall (explicit return route), so the test does not depend on Docker bridge forwarding.
for spec in "waf 10.77.20.15 8080" "biz 10.77.20.20 80"; do
  set -- $spec
  docker run -d --name modetest-$1 --network modetest-biz --ip $2 --cap-add NET_ADMIN "$IMG" \
    sh -c "ip route add $GUEST_NET via 10.77.20.254 && cd /tmp && exec python3 -m http.server $3" >/dev/null
done
docker run -d --name modetest-guest --network modetest-guest --ip 10.77.10.50 --cap-add NET_ADMIN "$IMG" \
  sh -c "ip route add $BIZ_NET via 10.77.10.254 && exec sleep infinity" >/dev/null
sleep 2

WAF=http://10.77.20.15:8080/ BIZ=http://10.77.20.20/

echo "=== positive control: baseline must forward, or every 'dropped' result below would mean nothing ==="
start_fw baseline
wait_mode baseline || { echo "[ERROR] firewall did not start in baseline"; docker logs modetest-fw; exit 2; }
for url in $WAF $BIZ; do
  [ "$(docker exec modetest-guest curl -s -m 3 -o /dev/null -w '%{http_code}' "$url")" = 200 ] \
    || { echo "[ERROR] the stand-in topology does not forward Guest -> $url even in baseline, so this host cannot run the test"; exit 2; }
done
echo "  [PASS] baseline forwards Guest -> WAF and Guest -> Business"

echo "=== defended: start ==="
start_fw defended
wait_mode defended; expect "firewall reports defended" $?
running; expect "firewall container is running" $?
check "Guest -> WAF :8080 is allowed" 200 $WAF
check "Guest -> Business server is dropped" 000 $BIZ

echo "=== defended: rules are idempotent ==="
before=$(docker exec modetest-fw iptables -S FORWARD)
docker exec modetest-fw sh /scripts/firewall/firewall-init.sh apply defended >/dev/null
[ "$before" = "$(docker exec modetest-fw iptables -S FORWARD)" ]; expect "applying twice leaves identical rules" $?

echo "=== defended: container restart ==="
docker restart modetest-fw >/dev/null
wait_mode defended; expect "rules are back after restart" $?
running; expect "firewall container is running" $?
check "Guest -> WAF :8080 still allowed" 200 $WAF
check "Guest -> Business server still dropped" 000 $BIZ

echo "=== defended: container recreation ==="
start_fw defended
wait_mode defended; expect "rules are back after recreation" $?
running; expect "firewall container is running" $?
check "Guest -> WAF :8080 still allowed" 200 $WAF
check "Guest -> Business server still dropped" 000 $BIZ

echo "=== unknown mode fails closed ==="
start_fw bogus
[ "$(docker wait modetest-fw)" = 2 ]; expect "container exits with code 2" $?
check "Guest -> WAF is not forwarded" 000 $WAF
check "Guest -> Business server is not forwarded" 000 $BIZ

echo "=== rules that cannot be applied fail closed (no NET_ADMIN) ==="
start_fw defended nocap
[ "$(docker wait modetest-fw)" != 0 ]; expect "container exits non-zero" $?
check "Guest -> WAF is not forwarded" 000 $WAF
check "Guest -> Business server is not forwarded" 000 $BIZ

echo "=== baseline is an explicit choice ==="
start_fw baseline
wait_mode baseline; expect "firewall reports baseline" $?
check "Guest -> Business server is reachable" 200 $BIZ

echo "=== back to defended ==="
start_fw defended
wait_mode defended; expect "firewall reports defended again" $?
running; expect "firewall container is running" $?
check "Guest -> Business server is dropped again" 000 $BIZ
check "Guest -> WAF :8080 is allowed" 200 $WAF

echo "=== Result: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
