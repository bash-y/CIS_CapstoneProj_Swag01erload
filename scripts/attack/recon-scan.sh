#!/bin/bash
# recon-scan.sh
# Guest-network reconnaissance from inside Kali against the café network (US-6, #47).
# Subtask (@joromanii): execute an ARP scan and Nmap discovery from Kali.
#
# Run from Kali on the undefended build:
#   docker exec swagpc-kali bash /scripts/attack/recon-scan.sh
# Re-run it after segmentation (US-8) to confirm business hosts are no longer found.

GUEST_IF="eth0"
BUSINESS_NET="192.168.20.0/24"
EVIDENCE_DIR="${EVIDENCE_DIR:-/evidence/attack}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$EVIDENCE_DIR" 2>/dev/null || true

echo "=== [ATTACK 1] Guest Network Reconnaissance ==="
echo "Attacker: Kali Linux (192.168.10.50) on Guest VLAN 10"
echo "Target:   Business Subnet ($BUSINESS_NET)"
echo ""

# Ensure a route to the business subnet via the firewall router exists in Kali.
ip route add "$BUSINESS_NET" via 192.168.10.254 2>/dev/null || true

# ─── Step 1: ARP scan (Layer 2 discovery of the local Guest segment) ──────────
# ARP is link-layer, so it only reveals hosts on the attacker's own segment —
# here the Guest subnet and the firewall's guest-side interface (192.168.10.254).
# Business hosts sit behind the router and will NOT appear in ARP; that is why
# Step 2 uses a routed Nmap sweep to reach them. Finding the .254 gateway is the
# pivot that makes the routed scan possible.
echo "1. ARP scan of the local Guest segment ($GUEST_IF)..."
if command -v arp-scan >/dev/null 2>&1; then
    arp-scan --interface="$GUEST_IF" --localnet 2>&1 \
        | tee "$EVIDENCE_DIR/arp-scan-$TIMESTAMP.txt"
else
    echo "[WARN] arp-scan not installed in this image; falling back to nmap ARP ping (-PR)."
    nmap -sn -PR 192.168.10.0/24 2>&1 \
        | tee "$EVIDENCE_DIR/arp-scan-$TIMESTAMP.txt"
fi

# ─── Step 2: Nmap host discovery across the routed Business subnet ────────────
echo ""
echo "2. Nmap host discovery (ping sweep) across the Business subnet..."
nmap -sn "$BUSINESS_NET" 2>&1 \
    | tee "$EVIDENCE_DIR/nmap-hostdiscovery-$TIMESTAMP.txt"

# ─── Step 3: Nmap service/version scan of the discovered Business hosts ───────
echo ""
echo "3. Nmap port & service scan of the Business subnet..."
nmap -sS -sV -p 22,80,443,445,3389,8080 -T4 "$BUSINESS_NET" 2>&1 \
    | tee "$EVIDENCE_DIR/nmap-services-$TIMESTAMP.txt"

echo ""
echo "=== Reconnaissance Completed. Evidence saved to $EVIDENCE_DIR ==="
