#!/bin/sh
# harden-dvwa-security-level.sh
# Application-layer hardening for the café web app (US-10, issue #51).
#
#   sh defense/application-security/harden-dvwa-security-level.sh apply
#       Set DVWA's DEFAULT security level to "impossible" so new sessions start
#       with full input sanitization / parameterized queries.
#
#   sh defense/application-security/harden-dvwa-security-level.sh revert
#       Set the default back to "low" (undefended baseline) for before/after demos.
#
#   sh defense/application-security/harden-dvwa-security-level.sh status
#       Print the current default security level from the container config.
#
# Mechanism: DVWA reads its default security level from
#   /var/www/html/config/config.inc.php  ->  $_DVWA['default_security_level']
# At "impossible", DVWA uses prepared statements and strict validation, so the
# SQL injection and command-injection payloads in scripts/attack/ no longer
# return data. This is the input-sanitization control for US-10.
#
# HONEST SCOPE: DVWA's live security level is also held in a per-session cookie,
# so a change here hardens the DEFAULT for new sessions. It is layered with the
# WAF path control (defense/firewall/route-waf-only.sh) so the attacker on the
# Guest network cannot simply flip their own cookie back to "low" against a
# directly reachable DVWA. See README.md in this folder.
#
# NOTE: Written to match the repo's apply/revert defense pattern. Run it against
# the live lab (bash lab.sh start) to verify; it has not been executed in the
# authoring environment.

set -e

DVWA="swagpc-dvwa"
CONFIG="/var/www/html/config/config.inc.php"
BACKUP="/var/www/html/config/config.inc.php.swagpc.bak"

require_running() {
  if ! docker ps --format '{{.Names}}' | grep -qx "$DVWA"; then
    echo "[ERROR] $DVWA is not running. Start it with: bash lab.sh start" >&2
    exit 1
  fi
  if ! docker exec "$DVWA" test -f "$CONFIG"; then
    echo "[ERROR] DVWA config not found at $CONFIG inside $DVWA." >&2
    exit 1
  fi
}

# Print the current default security level (the level word on the config line).
current_level() {
  docker exec "$DVWA" sh -c "grep default_security_level '$CONFIG'" 2>/dev/null \
    | grep -oiE "(impossible|medium|high|low)" | head -n1 | tr 'A-Z' 'a-z'
}

# Rewrite the level word on the default_security_level line to $1, in place.
# awk keeps the quoting simple: the program has no quotes of its own, and the
# new level is passed in with -v.
set_level() {
  level="$1"
  docker exec "$DVWA" sh -c "[ -f '$BACKUP' ] || cp '$CONFIG' '$BACKUP'"
  docker exec "$DVWA" sh -c \
    "awk -v lvl='$level' '/default_security_level/{sub(/(impossible|medium|high|low)/,lvl)}1' '$CONFIG' > '$CONFIG.tmp' && mv '$CONFIG.tmp' '$CONFIG'"
}

apply() {
  echo "=== Hardening DVWA: default security level -> impossible ==="
  set_level "impossible"
  echo "[OK] DVWA default security level is now: $(current_level)"
  echo "Re-run scripts/attack/sqli-exploit.sh and the command-injection step —"
  echo "payloads should return no rows / sanitized output."
}

revert() {
  echo "=== Reverting DVWA: default security level -> low (undefended baseline) ==="
  set_level "low"
  echo "[OK] DVWA default security level is now: $(current_level)"
}

status() {
  echo "DVWA default security level: $(current_level)"
}

[ $# -eq 1 ] || { echo "Usage: sh $0 [apply|revert|status]"; exit 1; }
require_running

case "$1" in
  apply)  apply ;;
  revert) revert ;;
  status) status ;;
  *)      echo "Usage: sh $0 [apply|revert|status]"; exit 1 ;;
esac
