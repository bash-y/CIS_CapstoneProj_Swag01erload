#!/bin/sh
# harden-workstation-firewall.sh
# US-9 (#50) — Endpoint hardening: restrict INBOUND connections to the employee
# workstation (swagpc-workstation / 192.168.20.25) to AUTHORIZED SUBNETS only.
#
# Policy: this is the host-based firewall on the business endpoint, layered on top
# of the pfSense/network segmentation (defense-in-depth). Even if a packet reaches
# the workstation, only traffic sourced from the Business subnet is accepted; the
# Guest subnet (where the attacker lives, 192.168.10.50) is dropped at the host.
#
# NOTE ON SIMULATION: the "Windows employee PC" is modeled by an Alpine container,
# so the Windows Defender Firewall ruleset is implemented here with its Linux
# equivalent (iptables). The exact Defender/PowerShell ruleset this mirrors is
# documented in README.md so it maps 1:1 to a real Windows host.

set -e

WS="swagpc-workstation"
BUSINESS_NET="192.168.20.0/24"   # authorized subnet
GUEST_NET="192.168.10.0/24"      # explicitly untrusted (café guest Wi-Fi)

echo "=== US-9: Hardening employee workstation host firewall ($WS) ==="

docker exec "$WS" sh -c "
  set -e

  # iptables is not in the base workstation image; install it on demand.
  if ! command -v iptables >/dev/null 2>&1; then
    apk add --no-cache iptables >/dev/null
  fi

  # Start from a clean INPUT chain so re-runs are idempotent.
  iptables -F INPUT

  # 1. Always allow loopback (local services, health checks).
  iptables -A INPUT -i lo -j ACCEPT

  # 2. Allow return traffic for connections the workstation itself initiated
  #    (e.g. its own request to the business server).
  iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

  # 3. AUTHORIZED SUBNET: accept inbound only from the Business network.
  iptables -A INPUT -s $BUSINESS_NET -j ACCEPT

  # 4. Explicit deny + LOG for the Guest subnet, so blocked lateral-movement
  #    attempts are recorded (US-8/US-9 require 'denied AND logged').
  iptables -A INPUT -s $GUEST_NET -j LOG --log-prefix 'WS-ENDPOINT-DROP-GUEST: ' --log-level 4
  iptables -A INPUT -s $GUEST_NET -j DROP

  # 5. Default-deny everything else inbound (anything not from an authorized subnet).
  iptables -A INPUT -j LOG --log-prefix 'WS-ENDPOINT-DROP-OTHER: ' --log-level 4
  iptables -A INPUT -j DROP
"

echo "[SUCCESS] Inbound to $WS now restricted to Business subnet ($BUSINESS_NET); Guest subnet dropped and logged."
echo "--- Active INPUT chain on $WS ---"
docker exec "$WS" iptables -L INPUT -v -n
