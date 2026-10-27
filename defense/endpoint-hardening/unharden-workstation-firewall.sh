#!/bin/sh
# unharden-workstation-firewall.sh
# US-9 (#50) — Revert the employee workstation host firewall back to the
# undefended baseline (accept all inbound). Used to re-establish the "before"
# state when demonstrating/verifying the defense.

set -e
WS="swagpc-workstation"

echo "=== US-9: Reverting employee workstation host firewall ($WS) to undefended ==="
docker exec "$WS" sh -c "
  if command -v iptables >/dev/null 2>&1; then
    iptables -F INPUT
    iptables -P INPUT ACCEPT
  fi
"
echo "[DONE] $WS INPUT chain flushed; all inbound accepted again (baseline)."
docker exec "$WS" iptables -L INPUT -v -n 2>/dev/null || true
