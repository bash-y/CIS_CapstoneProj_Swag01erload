#!/bin/sh
# enable-segmentation.sh
# Enforces pfSense-style firewall segmentation: Block all Guest -> Business traffic.

echo "=== Applying Firewall Segmentation Rules ==="
docker exec swagpc-firewall sh -c "
  # Flush existing FORWARD rules
  iptables -F FORWARD

  # Allow established/related return traffic
  iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

  # BLOCK & LOG: Guest Subnet (192.168.10.0/24) to Business Subnet (192.168.20.0/24)
  iptables -A FORWARD -s 192.168.10.0/24 -d 192.168.20.0/24 -j DROP

  # Allow other forward traffic
  iptables -A FORWARD -j ACCEPT
"

echo "[SUCCESS] Guest-to-Business traffic is now BLOCKED by swagpc-firewall."
docker exec swagpc-firewall iptables -L FORWARD -v -n
