#!/bin/bash
# verify-waf.sh
# Verifies the WAF capabilities (issue #24) and the WAF acceptance criteria (issue #7).
# Attacks run from Kali on the Guest network, through the WAF at 192.168.20.15.
#
# Run AFTER the WAF is up: docker compose -f docker/docker-compose.yml up -d firewall dvwa kali waf
# Checks, in order:
#   1. Proxying: a normal login and page load pass through the WAF to DVWA.
#   2. No false positive: a normal lookup (id=1) passes.
#   3. SQL injection is blocked (403) and returns no rows.
#   4. Command injection is blocked (403) and returns no /etc/passwd.
#   5. The WAF logs the rule match for those attacks.
#   6. Direct access to DVWA on 192.168.20.10 is blocked (run route-waf-only.sh apply).
#      Reported as a known gap if it is still reachable.

WAF="http://192.168.20.15:8080"
DIRECT="http://192.168.20.10"
JAR="/tmp/verify-waf-cookies.txt"
PASS=0
FAIL=0
GAPS=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
gap()  { echo "  [GAP]  $1"; GAPS=$((GAPS+1)); }

kali() { docker exec swagpc-kali sh -c "$1"; }

echo "============================================="
echo " SwagPc Café — WAF Verification (ModSecurity + OWASP CRS)"
echo "============================================="

# Reset DVWA's database from the host, the local admin path. Guest hosts are refused /setup.php at the WAF (#79).
rm -f /tmp/verify-reset.txt; TK=$(curl -s -c /tmp/verify-reset.txt -b /tmp/verify-reset.txt http://127.0.0.1:8080/setup.php | grep -o "user_token' value='[^']*" | sed "s/.*value='//"); curl -s -c /tmp/verify-reset.txt -b /tmp/verify-reset.txt -d "create_db=Create+%2F+Reset+Database&user_token=$TK" http://127.0.0.1:8080/setup.php -o /dev/null >/dev/null 2>&1

echo ""
echo "[1] Proxying: login and page load through the WAF"
LOGIN=$(kali "rm -f $JAR; TK=\$(curl -s -c $JAR -b $JAR $WAF/login.php | grep -o \"user_token' value='[^']*\" | sed \"s/.*value='//\"); curl -s -c $JAR -b $JAR -d \"username=admin&password=password&Login=Login&user_token=\$TK\" $WAF/login.php -o /dev/null -w '%{http_code}'")
if [ "$LOGIN" = "302" ]; then ok "login through WAF returned 302 (proxied)"; else bad "login through WAF returned $LOGIN"; fi
INDEX=$(kali "curl -s -c $JAR -b $JAR $WAF/index.php -o /tmp/vw-index.html -w '%{http_code}'; grep -qi logout /tmp/vw-index.html && echo logged-in")
if echo "$INDEX" | grep -q logged-in; then ok "session established through WAF"; else bad "no session through WAF"; fi

echo ""
echo "[2] No false positive: normal lookup id=1"
BENIGN=$(kali "curl -s -c $JAR -b $JAR -G '$WAF/vulnerabilities/sqli/' --data-urlencode 'id=1' --data-urlencode 'Submit=Submit' -o /tmp/vw-benign.html -w '%{http_code}'; grep -o 'First name:[^<]*' /tmp/vw-benign.html | head -1")
if echo "$BENIGN" | grep -q "200" && echo "$BENIGN" | grep -q "First name: admin"; then ok "benign lookup passes (200, one row)"; else bad "benign lookup blocked or wrong: $BENIGN"; fi

echo ""
echo "[3] SQL injection blocked (issue #2 payload)"
SQLI=$(kali "curl -s -c $JAR -b $JAR -G '$WAF/vulnerabilities/sqli/' --data-urlencode \"id=1' UNION SELECT user,password FROM users#\" --data-urlencode 'Submit=Submit' -o /tmp/vw-sqli.html -w '%{http_code}\n'; grep -o 'First name' /tmp/vw-sqli.html | wc -l")
SQLI_CODE=$(echo "$SQLI" | sed -n '1p'); SQLI_ROWS=$(echo "$SQLI" | sed -n '2p')
if [ "$SQLI_CODE" = "403" ] && [ "${SQLI_ROWS:-0}" = "0" ]; then ok "UNION SQLi blocked: 403, 0 rows"; else bad "UNION SQLi not blocked: code=$SQLI_CODE rows=$SQLI_ROWS"; fi

echo ""
echo "[4] Command injection blocked"
CMDI=$(kali "curl -s -c $JAR -b $JAR -d 'ip=127.0.0.1;cat+/etc/passwd&Submit=Submit' '$WAF/vulnerabilities/exec/' -o /tmp/vw-cmdi.html -w '%{http_code}\n'; grep -c 'root:x:0:0' /tmp/vw-cmdi.html")
CMDI_CODE=$(echo "$CMDI" | sed -n '1p'); CMDI_HITS=$(echo "$CMDI" | sed -n '2p')
if [ "$CMDI_CODE" = "403" ] && [ "${CMDI_HITS:-0}" = "0" ]; then ok "command injection blocked: 403, no /etc/passwd"; else bad "command injection not blocked: code=$CMDI_CODE passwd=$CMDI_HITS"; fi

echo ""
echo "[5] Rule matches are logged"
RULES=$(docker exec swagpc-waf sh -c "cat /var/log/modsecurity/audit/audit.log" 2>&1 | grep -oE '"ruleId":"[0-9]+"' | sort -u | tr -d '"' | sed 's/ruleId://' | tr '\n' ' ')
if echo "$RULES" | grep -q "942100"; then ok "SQLi rule 942100 logged. All rule IDs seen: $RULES"; else bad "no SQLi rule match in WAF log"; fi
if echo "$RULES" | grep -q "932160"; then ok "command-injection rule 932160 logged"; else bad "no command-injection rule match in WAF log"; fi

echo ""
echo "[6] Direct access to DVWA (must be blocked once routed)"
DIRECT_CODE=$(kali "rm -f /tmp/vw-d.txt; TK=\$(curl -s --max-time 8 -c /tmp/vw-d.txt -b /tmp/vw-d.txt $DIRECT/login.php | grep -o \"user_token' value='[^']*\" | sed \"s/.*value='//\"); curl -s --max-time 8 -c /tmp/vw-d.txt -b /tmp/vw-d.txt -d \"username=admin&password=password&Login=Login&user_token=\$TK\" $DIRECT/login.php -o /dev/null; curl -s --max-time 8 -c /tmp/vw-d.txt -b /tmp/vw-d.txt -G '$DIRECT/vulnerabilities/sqli/' --data-urlencode \"id=1' UNION SELECT user,password FROM users#\" --data-urlencode 'Submit=Submit' -o /dev/null -w '%{http_code}'")
if [ "$DIRECT_CODE" = "200" ]; then
  gap "DVWA reachable directly on 192.168.20.10 (UNION SQLi returned 200), bypassing the WAF. Run route-waf-only.sh apply (#7)"
elif [ "$DIRECT_CODE" = "000" ] || [ "$DIRECT_CODE" = "403" ]; then
  ok "direct access to DVWA is blocked (code $DIRECT_CODE), so the WAF is the only path"
else
  bad "direct access returned unexpected code $DIRECT_CODE"
fi


echo ""
echo "[7] Admin pages are refused to Guest hosts at the WAF (#79)"
SETUP=$(kali "curl -s --max-time 5 -o /dev/null -w '%{http_code}' '$WAF/setup.php'")
if [ "$SETUP" = "403" ]; then ok "/setup.php refused to Guest through the WAF (403)"; else bad "/setup.php returned $SETUP to Guest"; fi

echo ""
echo "============================================="
echo " Results: $PASS PASSED | $FAIL FAILED | $GAPS KNOWN GAP(S)"
echo "============================================="
[ $FAIL -eq 0 ]
