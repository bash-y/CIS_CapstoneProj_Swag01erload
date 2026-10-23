#!/bin/bash
# recon-scan.sh
# Executes network reconnaissance from inside Kali against the Business Network.

echo "=== [ATTACK 1] Guest Network Reconnaissance ==="
echo "Attacker: Kali Linux (192.168.10.50)"
echo "Target: Business Subnet (192.168.20.0/24)"
echo ""

# Ensure route to business subnet via firewall router exists in Kali
ip route add 192.168.20.0/24 via 192.168.10.254 2>/dev/null || true

echo "1. Testing ping to business server (192.168.20.10)..."
ping -c 3 192.168.20.10

echo ""
echo "2. Running Nmap port scan against business subnet..."
nmap -sS -p 80,8080,22,445,3389 -T4 192.168.20.0/24

echo ""
echo "=== Reconnaissance Completed ==="
