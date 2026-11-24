#!/bin/bash
# test-zap-runner.sh: prove the ZAP runner starts, keeps its reports, and leaves other data alone across
# stop, restart and recreation. US-19 (#130). Starts no scan.
#
#   bash scripts/testing/test-zap-runner.sh
#
# Starts only the zap service from docker/docker-compose.yml under its own compose project name (zaptest),
# so it does not touch a lab started with lab.sh. It refuses to run if a container named swagpc-zap already
# exists. It uses the Guest network (guest-net), which compose creates if it is missing. A sibling volume
# (zaptest_sibling) stands in for the lab's own data: the test checks that ZAP's lifecycle commands leave it
# untouched. Everything the test creates is removed at the end. The checks that need the firewall, WAF and
# DVWA are not part of this test (check-ready.sh --no-lab). Needs Docker and the pinned ZAP image (3.7 GB).
# Exit code 0 only if every check passes.

set -u
cd "$(dirname "$0")/../.."

P=zaptest
C="docker compose -f docker/docker-compose.yml -p $P --profile zap"
Z=swagpc-zap
IMG=$(sed -n 's/^ *image: \(zaproxy\/[^ ]*\)$/\1/p' docker/docker-compose.yml)
PASS=0 FAIL=0

if docker ps -a --format '{{.Names}}' | grep -qx "$Z"; then
  echo "[ERROR] a container named $Z already exists. Stop it first (docker compose --profile zap stop zap), then run this test."
  exit 2
fi

cleanup() {
  $C down >/dev/null 2>&1
  docker volume rm "${P}_zap_reports" "${P}_sibling" >/dev/null 2>&1
}
trap cleanup EXIT
cleanup

expect() {  # expect <label> <0 = pass>
  if [ "$2" = 0 ]; then echo "  [PASS] $1"; PASS=$((PASS+1)); else echo "  [FAIL] $1"; FAIL=$((FAIL+1)); fi
}

wait_ready() {  # wait_ready <n>: the init script has printed its ready line n times (docker logs keeps earlier runs)
  for _ in $(seq 1 30); do
    [ "$(docker logs "$Z" 2>&1 | grep -c 'swagpc-zap ready')" -ge "$1" ] && return 0
    sleep 1
  done
  return 1
}

ready_checks() {  # ready_checks <label> <ready lines expected so far>
  wait_ready "$2"; expect "$1: init finished" $?
  bash scripts/zap/check-ready.sh --no-lab >/dev/null 2>&1; expect "$1: check-ready.sh --no-lab passes (identity, Guest-only network, route, reports, version, add-ons)" $?
}

has() {  # has <volume> <expected content>
  [ "$(docker run --rm --user root -v "$1:/d:ro" --entrypoint cat "$IMG" /d/marker 2>/dev/null)" = "$2" ]
}

echo "=== start the runner (opt-in profile) ==="
$C up -d zap >/dev/null 2>&1; expect "compose starts the zap service" $?
ready_checks "first start" 1

echo "=== data to keep ==="
docker exec -u zap "$Z" sh -c 'echo report-1 > /zap/wrk/marker'; expect "a report file is written as zap" $?
docker volume create "${P}_sibling" >/dev/null
docker run --rm --user root -v "${P}_sibling:/d" --entrypoint sh "$IMG" -c 'echo lab-data > /d/marker'; expect "a sibling volume holds other data" $?

echo "=== stop and start ==="
$C stop zap >/dev/null 2>&1; $C start zap >/dev/null 2>&1; expect "stop then start" $?
ready_checks "after restart" 2
has "${P}_zap_reports" report-1; expect "the report file survived the restart" $?

echo "=== remove the container and create it again ==="
$C rm -sf zap >/dev/null 2>&1; $C up -d zap >/dev/null 2>&1; expect "remove then up" $?
ready_checks "after recreation" 1
has "${P}_zap_reports" report-1; expect "the report file survived the recreation" $?
has "${P}_sibling" lab-data; expect "the sibling volume is untouched" $?

echo "=== Result: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
