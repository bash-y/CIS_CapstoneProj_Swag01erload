#!/bin/bash
# broken-access-control.sh
# Demonstrates broken access control on the café fixture app (US-10, #110), then
# proves the secure endpoint denies the same unauthorized requests.
#
# Run from Kali on the lab, pointing at the deployed fixture:
#   FIXTURE_URL=http://192.168.20.10/bac docker exec -e FIXTURE_URL \
#       swagpc-kali bash /scripts/attack/broken-access-control.sh
#
# The fixture lives in defense/application-security/broken-access-control/.
# For a quick local review you can serve it with PHP's built-in server:
#   php -S 127.0.0.1:8090 -t defense/application-security/broken-access-control
#   FIXTURE_URL=http://127.0.0.1:8090 bash scripts/attack/broken-access-control.sh
#
# Actors (synthetic, lab-only): alice/bob = staff, admin = admin.
# Protected read  = an order record (owner-only). Order 1001 = alice, 1002 = bob.
# State-changing  = delete an order (admin-only).

set -u

FIXTURE_URL="${FIXTURE_URL:-http://192.168.20.10/bac}"
EVIDENCE_DIR="${EVIDENCE_DIR:-/evidence/attack}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUT="$EVIDENCE_DIR/broken-access-control-$TIMESTAMP.txt"
JAR_ALICE="/tmp/bac-alice-$$.txt"
JAR_ADMIN="/tmp/bac-admin-$$.txt"
JAR_NONE="/tmp/bac-none-$$.txt"

mkdir -p "$EVIDENCE_DIR" 2>/dev/null || true
cleanup() { rm -f "$JAR_ALICE" "$JAR_ADMIN" "$JAR_NONE"; }
trap cleanup EXIT

log() { echo "$1" | tee -a "$OUT"; }

# request <jar> <url>  -> prints "HTTP <code> | <body first line>"
request() {
    local jar="$1" url="$2" resp code body
    resp=$(curl -s -w $'\n__HTTP__%{http_code}' -b "$jar" -c "$jar" "$url" 2>/dev/null)
    code=$(printf '%s' "$resp" | sed -n 's/.*__HTTP__\([0-9][0-9]*\)$/\1/p')
    body=$(printf '%s' "$resp" | sed 's/__HTTP__[0-9]*$//' | head -n1)
    echo "HTTP ${code:-ERR} | ${body}"
}

login() { # login <jar> <user> <pass>
    curl -s -b "$1" -c "$1" -d "username=$2" -d "password=$3" "$FIXTURE_URL/login.php" >/dev/null 2>&1
}

log "================================================================"
log " SwagPc Café — Broken Access Control Demonstration (US-10 #110)"
log " Timestamp:   $TIMESTAMP"
log " Fixture URL: $FIXTURE_URL"
log "================================================================"

log ""
log "[*] Logging in as alice (staff) and admin (admin)..."
login "$JAR_ALICE" alice alicepw
login "$JAR_ADMIN" admin adminpw

log ""
log "=== BEFORE — orders_vulnerable.php (no server-side authz) ==="
log "H1 Horizontal: alice reads BOB's order 1002 (should be denied)"
log "    -> $(request "$JAR_ALICE" "$FIXTURE_URL/orders_vulnerable.php?action=read&order_id=1002")"
log "V1 Vertical:   alice deletes order 1001 by sending role=admin (should be denied)"
log "    -> $(request "$JAR_ALICE" "$FIXTURE_URL/orders_vulnerable.php?action=delete&order_id=1001&role=admin")"
log "U1 Unauth:     no session reads order 1001 (should be denied)"
log "    -> $(request "$JAR_NONE" "$FIXTURE_URL/orders_vulnerable.php?action=read&order_id=1001")"

log ""
log "=== AFTER — orders_secure.php (server-side ownership + role, deny-by-default) ==="
log "H1 Horizontal: alice reads BOB's order 1002 -> expect HTTP 403"
log "    -> $(request "$JAR_ALICE" "$FIXTURE_URL/orders_secure.php?action=read&order_id=1002")"
log "V1 Vertical:   alice deletes order 1001 with role=admin -> expect HTTP 403 (role ignored)"
log "    -> $(request "$JAR_ALICE" "$FIXTURE_URL/orders_secure.php?action=delete&order_id=1001&role=admin")"
log "U1 Unauth:     no session reads order 1001 -> expect HTTP 401"
log "    -> $(request "$JAR_NONE" "$FIXTURE_URL/orders_secure.php?action=read&order_id=1001")"

log ""
log "=== Positive controls — legitimate access must still work ==="
log "P1 Owner read: alice reads her OWN order 1001 -> expect HTTP 200 + record"
log "    -> $(request "$JAR_ALICE" "$FIXTURE_URL/orders_secure.php?action=read&order_id=1001")"
log "P2 Admin op:   admin deletes order 1002 -> expect HTTP 200"
log "    -> $(request "$JAR_ADMIN" "$FIXTURE_URL/orders_secure.php?action=delete&order_id=1002")"

log ""
log "Interpretation:"
log " - BEFORE leaks bob's record to alice and lets alice delete via role=admin."
log " - AFTER denies both (403) and unauth (401) with no protected data, while"
log "   the owner read and admin delete still succeed (200)."
log " - A 403/401 here is APPLICATION authorization, separate from any WAF/network"
log "   management-path block (#79); keep the route reachable when testing this."
log "Evidence saved to: $OUT"
