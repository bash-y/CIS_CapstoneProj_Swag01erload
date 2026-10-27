#!/bin/sh
# route-waf-only.sh
# Makes the WAF the only path from the Guest network to the café web app (issue #7).
#
#   sh defense/firewall/route-waf-only.sh apply    Guest -> WAF only; Guest -> DVWA and Business blocked
#   sh defense/firewall/route-waf-only.sh revert   Undefended: allow all forwarding
#
# After apply, a Guest host can reach the WAF at 192.168.20.15:8080 but not DVWA
# at 192.168.20.10, and not any other Business address. The WAF reaches DVWA
# directly on the Business network, which the firewall does not route, so the
# proxy path still works.

set -e

FW="swagpc-firewall"
GUEST="192.168.10.0/24"
BUSINESS="192.168.20.0/24"
WAF_IP="192.168.20.15"
DVWA_IP="192.168.20.10"

require_running() {
  if ! docker ps --format '{{.Names}}' | grep -qx "$FW"; then
    echo "[ERROR] $FW is not running. Start it with: docker compose -f docker/docker-compose.yml up -d firewall" >&2
    exit 1
  fi
}

apply() {
  echo "=== Routing Guest traffic through the WAF only ==="
  docker exec "$FW" sh -c "
    iptables -F FORWARD
    iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -s $GUEST -d $WAF_IP -p tcp --dport 8080 -j ACCEPT
    iptables -A FORWARD -s $GUEST -d $DVWA_IP -j DROP
    iptables -A FORWARD -s $GUEST -d $BUSINESS -j DROP
    iptables -A FORWARD -j ACCEPT
  "
  echo "[OK] Guest -> WAF ($WAF_IP:8080) allowed. Guest -> DVWA and other Business hosts dropped."
  docker exec "$FW" iptables -L FORWARD -n -v
}

revert() {
  echo "=== Reverting to undefended: allow all forwarding ==="
  docker exec "$FW" sh -c "
    iptables -F FORWARD
    iptables -P FORWARD ACCEPT
  "
  echo "[OK] Forwarding is open again (undefended baseline)."
}

[ $# -eq 1 ] || { echo "Usage: sh defense/firewall/route-waf-only.sh [apply|revert]"; exit 1; }
require_running

case "$1" in
  apply)  apply ;;
  revert) revert ;;
  *)      echo "Usage: sh defense/firewall/route-waf-only.sh [apply|revert]"; exit 1 ;;
esac
