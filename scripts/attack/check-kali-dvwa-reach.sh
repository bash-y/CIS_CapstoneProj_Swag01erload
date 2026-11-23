#!/bin/bash
# check-kali-dvwa-reach.sh
# US-5 (#46): confirm the Kali attacker on Guest VLAN 10 can reach the DVWA café
# web app across the undefended network. Focused reachability proof (not a full
# recon or exploit) so it can be captured as discrete #46 evidence.
#
# Run from Kali:
#   docker exec swagpc-kali bash /scripts/attack/check-kali-dvwa-reach.sh
# Capture as evidence:
#   sh scripts/capture-evidence.sh attack kali-dvwa-reach "US-5 Kali->DVWA reachability" \
#      docker exec swagpc-kali bash /scripts/attack/check-kali-dvwa-reach.sh
#
# Exit 0 only if DVWA's login page is reachable over HTTP; non-zero otherwise, so
# the evidence helper records an honest pass/fail.

set -u
DVWA_IP="${DVWA_IP:-192.168.20.10}"
TARGET="http://${DVWA_IP}"
FW="${FW:-192.168.10.254}"

echo "=== [US-5 #46] Kali -> DVWA reachability (undefended) ==="
echo "Attacker: Kali (Guest 192.168.10.50)   Target: DVWA ${DVWA_IP}"

# Ensure the route to the business subnet via the firewall router exists.
ip route add 192.168.20.0/24 via "$FW" 2>/dev/null || true

fail=0

echo ""
echo "1. ICMP to DVWA host:"
if ping -c 2 -W 2 "$DVWA_IP" >/dev/null 2>&1; then
    echo "   [OK] host replies to ping"
else
    echo "   [WARN] no ping reply (ICMP may be filtered; HTTP check below is authoritative)"
fi

echo ""
echo "2. TCP/80 open:"
if nc -z -w 3 "$DVWA_IP" 80 2>/dev/null; then
    echo "   [OK] port 80 open"
else
    echo "   [FAIL] port 80 not reachable"
    fail=1
fi

echo ""
echo "3. HTTP GET of DVWA login page:"
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$TARGET/login.php")
echo "   GET $TARGET/login.php -> HTTP ${code:-ERR}"
case "$code" in
    200|302) echo "   [OK] DVWA web app is reachable" ;;
    *)       echo "   [FAIL] DVWA did not return an expected status"; fail=1 ;;
esac

echo ""
if [ "$fail" -eq 0 ]; then
    echo "RESULT: PASS — Kali reaches the DVWA app across the undefended network (US-5 #46)."
else
    echo "RESULT: FAIL — DVWA not reachable from Kali. Check the lab is up and routing is in place."
fi
exit "$fail"
