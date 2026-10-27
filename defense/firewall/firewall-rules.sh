#!/bin/sh
# firewall-rules.sh
# One script to set up the lab firewall rules (issue #26).
#
#   sh defense/firewall/firewall-rules.sh status    show the current rules
#   sh defense/firewall/firewall-rules.sh apply     segmentation: block Guest -> Business
#   sh defense/firewall/firewall-rules.sh revert    undefended: allow all forwarding
#
# Runs the rules inside the swagpc-firewall container (the pfSense stand-in).
# The rules are the same ones in enable-segmentation.sh and disable-segmentation.sh;
# this script just gives one place to apply, revert and check them.

set -e

FW="swagpc-firewall"
GUEST="192.168.10.0/24"
BUSINESS="192.168.20.0/24"

usage() {
  echo "Usage: sh defense/firewall/firewall-rules.sh [status|apply|revert]"
  exit 1
}

require_running() {
  if ! docker ps --format '{{.Names}}' | grep -qx "$FW"; then
    echo "[ERROR] $FW is not running. Start it with: docker compose -f docker/docker-compose.yml up -d firewall" >&2
    exit 1
  fi
}

show() {
  echo "--- FORWARD (routing between Guest and Business) ---"
  docker exec "$FW" iptables -L FORWARD -n -v
  echo "--- INPUT (traffic to the firewall itself) ---"
  docker exec "$FW" iptables -L INPUT -n -v
  echo "--- ip_forward ---"
  docker exec "$FW" cat /proc/sys/net/ipv4/ip_forward
}

apply() {
  echo "=== Applying segmentation: block $GUEST -> $BUSINESS ==="
  docker exec "$FW" sh -c "
    iptables -F FORWARD
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -s $GUEST -d $BUSINESS -j DROP
    iptables -A FORWARD -j ACCEPT
  "
  echo "[OK] Guest -> Business is now dropped. Everything else is forwarded."
  show
}

revert() {
  echo "=== Reverting to undefended: allow all forwarding ==="
  docker exec "$FW" sh -c "
    iptables -F FORWARD
    iptables -P FORWARD ACCEPT
  "
  echo "[OK] Forwarding is open again (undefended baseline)."
  show
}

[ $# -eq 1 ] || usage
require_running

case "$1" in
  status) show ;;
  apply)  apply ;;
  revert) revert ;;
  *)      usage ;;
esac
