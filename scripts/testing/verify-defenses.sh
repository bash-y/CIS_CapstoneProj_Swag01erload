#!/bin/bash
# verify-defenses.sh
# Re-runs all attacks from Kali and confirms they are BLOCKED or DETECTED.
# Run AFTER enable-segmentation.sh has been applied.

set -e
PASS=0
FAIL=0

check() {
    local label="$1"
    local result="$2"
    local expect_blocked="$3"

    if [ "$expect_blocked" = "yes" ]; then
        if echo "$result" | grep -qE "100% packet loss|timed out|No route|Connection refused|filtered"; then
            echo "  [PASS] $label"
            PASS=$((PASS+1))
        else
            echo "  [FAIL] $label — traffic NOT blocked!"
            FAIL=$((FAIL+1))
        fi
    else
        if echo "$result" | grep -qE "100% packet loss|timed out|No route|Connection refused|filtered"; then
            echo "  [FAIL] $label — should be reachable but isn't!"
            FAIL=$((FAIL+1))
        else
            echo "  [PASS] $label"
            PASS=$((PASS+1))
        fi
    fi
}

echo "============================================="
echo " SwagPc Café — Defense Verification Suite"
echo "============================================="
echo ""
echo "[TEST 1] Guest -> Business: ICMP Ping (should be BLOCKED after segmentation)"
RESULT=$(docker exec swagpc-kali ping -c 2 -W 2 192.168.20.10 2>&1 || true)
check "Guest ping to DVWA (192.168.20.10)" "$RESULT" "yes"

echo ""
echo "[TEST 2] Guest -> Business: HTTP to DVWA (should be BLOCKED)"
RESULT=$(docker exec swagpc-kali curl -s --max-time 3 http://192.168.20.10 2>&1 || true)
check "Guest HTTP to DVWA web portal" "$RESULT" "yes"

echo ""
echo "[TEST 3] Guest -> Employee Workstation ping (should be BLOCKED)"
RESULT=$(docker exec swagpc-kali ping -c 2 -W 2 192.168.20.25 2>&1 || true)
check "Guest ping to workstation (192.168.20.25)" "$RESULT" "yes"

echo ""
echo "[TEST 4] Business -> Internet: Basic connectivity (should be ALLOWED)"
RESULT=$(docker exec swagpc-dvwa curl -s --max-time 5 -I http://example.com 2>&1 || true)
check "DVWA outbound internet access" "$RESULT" "no"

echo ""
echo "[TEST 5] Suricata: Alert log has entries (attack signatures detected)"
ALERT_COUNT=$(docker exec swagpc-suricata wc -l < /var/log/suricata/fast.log 2>/dev/null || echo "0")
if [ "$ALERT_COUNT" -gt 0 ]; then
    echo "  [PASS] Suricata has $ALERT_COUNT alert(s) in fast.log"
    PASS=$((PASS+1))
else
    echo "  [WARN] Suricata fast.log is empty — run attack scripts first"
fi

echo ""
echo "============================================="
echo " Results: $PASS PASSED | $FAIL FAILED"
echo "============================================="
[ $FAIL -eq 0 ]
