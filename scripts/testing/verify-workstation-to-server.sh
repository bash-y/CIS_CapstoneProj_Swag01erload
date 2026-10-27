#!/bin/sh
# verify-workstation-to-server.sh
# US-4 (#45) — Verify the employee workstation can reach the café business server.
# Runs the checks FROM the workstation (192.168.20.25) against the business
# server (192.168.20.20), proving intra-business-network connectivity.
#
# Expected result on the undefended/baseline build: all checks PASS (both hosts
# are on business-net with no host firewall between them).

set -e

WS="swagpc-workstation"
SERVER_IP="192.168.20.20"
RC=0

echo "=== US-4 verification: workstation ($WS) -> business server ($SERVER_IP) ==="

echo "--- [1/3] ICMP reachability (ping) ---"
if docker exec "$WS" ping -c 3 -W 2 "$SERVER_IP" >/dev/null 2>&1; then
  echo "PASS: server responds to ping (0% loss)."
else
  echo "FAIL: server not reachable via ICMP."; RC=1
fi

echo "--- [2/3] TCP port 80 open ---"
if docker exec "$WS" nc -z -w 3 "$SERVER_IP" 80 >/dev/null 2>&1; then
  echo "PASS: TCP 80 reachable."
else
  echo "FAIL: TCP 80 not reachable."; RC=1
fi

echo "--- [3/3] HTTP business service responds ---"
BODY=$(docker exec "$WS" curl -s -m 5 "http://$SERVER_IP/" 2>/dev/null || true)
if printf '%s' "$BODY" | grep -q "Business Operations"; then
  echo "PASS: business portal served (found 'Business Operations')."
  echo "      orders export:"
  docker exec "$WS" curl -s -m 5 "http://$SERVER_IP/orders.csv" 2>/dev/null | head -3 | sed 's/^/        /'
else
  echo "FAIL: business portal did not return expected content."; RC=1
fi

echo "=== Result: $([ $RC -eq 0 ] && echo 'ALL CHECKS PASSED' || echo 'ONE OR MORE CHECKS FAILED') ==="
exit $RC
