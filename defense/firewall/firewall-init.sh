#!/bin/sh
# firewall-init.sh: build the lab firewall's FORWARD rules for one explicit mode.
# US-17 (#127). Usage (inside the swagpc-firewall container):
#   sh /scripts/firewall/firewall-init.sh apply [defended|baseline]   rebuild the rules (default: $LAB_MODE, else defended)
#   sh /scripts/firewall/firewall-init.sh status                      print the mode the live rules match
#
# The container runs "apply" as its entrypoint, so the rules are rebuilt on every start, restart and
# recreation. It fails closed: FORWARD is set to DROP before anything else, and any error exits non-zero.
# That stops the container, and a stopped router forwards nothing.
#   defended   Guest -> WAF (tcp 8080) allowed; every other Guest -> Business packet is logged and dropped
#   baseline   the intentionally vulnerable flat network: all forwarding allowed
#
# The subnets and the WAF address default to the lab layout. The mode test overrides them.
set -eu

GUEST="${GUEST_NET:-192.168.10.0/24}"
BUSINESS="${BUSINESS_NET:-192.168.20.0/24}"
WAF_IP="${WAF_IP:-192.168.20.15}"
WAF_PORT="${WAF_PORT:-8080}"

apply() {
  mode=$1
  case "$mode" in
    defended|baseline) ;;
    *) echo "firewall-init: unknown LAB_MODE '$mode' (use defended or baseline); forwarding stays blocked" >&2; exit 2 ;;
  esac

  iptables -P FORWARD DROP
  iptables -F FORWARD
  iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  if [ "$mode" = defended ]; then
    iptables -A FORWARD -s "$GUEST" -d "$WAF_IP" -p tcp --dport "$WAF_PORT" -j ACCEPT
    iptables -A FORWARD -s "$GUEST" -d "$BUSINESS" -j LOG --log-prefix 'FW-DROP-GUEST: ' --log-level 4
    iptables -A FORWARD -s "$GUEST" -d "$BUSINESS" -j DROP
  fi
  iptables -A FORWARD -j ACCEPT
  echo "firewall-init: mode=$mode ($(status))"
}

status() {
  rules=$(iptables -S FORWARD)
  if printf '%s\n' "$rules" | grep -q -- "-s $GUEST -d $BUSINESS -j DROP"; then
    echo defended
  elif printf '%s\n' "$rules" | grep -qx -- '-A FORWARD -j ACCEPT'; then
    echo baseline
  else
    echo unknown
  fi
}

case "${1:-}" in
  apply)  apply "${2:-${LAB_MODE:-defended}}" ;;
  status) status ;;
  *)      echo "usage: sh firewall-init.sh apply [defended|baseline] | status" >&2; exit 2 ;;
esac
