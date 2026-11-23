#!/bin/sh
# enable-segmentation.sh
# Enforces pfSense-style firewall segmentation: Block all Guest -> Business traffic.

set -e
FW="swagpc-firewall"
case "$#" in
  0) ;;
  1) [ "$1" = "--validation-lab" ] || exit 2; FW="cafe-validation-firewall" ;;
  *) exit 2 ;;
esac

echo "=== Applying Firewall Segmentation Rules ==="
docker exec "$FW" sh -ec "
  # Flush existing FORWARD rules
  iptables -F FORWARD

  # Allow established/related return traffic
  iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

  # BLOCK & LOG: Guest Subnet (192.168.10.0/24) to Business Subnet (192.168.20.0/24)
  # LOG first, so every denied attempt is recorded before it is dropped (US-8, #76).
  iptables -A FORWARD -s 192.168.10.0/24 -d 192.168.20.0/24 -j LOG --log-prefix 'FW-DROP-GUEST: ' --log-level 4
  iptables -A FORWARD -s 192.168.10.0/24 -d 192.168.20.0/24 -j DROP

  # Allow other forward traffic
  iptables -A FORWARD -j ACCEPT
"

echo "[SUCCESS] Guest-to-Business traffic is now BLOCKED by swagpc-firewall."
docker exec "$FW" iptables -L FORWARD -v -n
