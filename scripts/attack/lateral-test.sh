#!/bin/bash
# lateral-test.sh
# Tests lateral movement from Guest position to Employee Workstation (192.168.20.25).

TARGET="192.168.20.25"
echo "=== [ATTACK 3] Lateral Movement & Workstation Reachability ==="
echo "Target Employee PC: $TARGET"

# Ensure route to business subnet via firewall router exists
ip route add 192.168.20.0/24 via 192.168.10.254 2>/dev/null || true

echo "1. Pinging employee workstation ($TARGET)..."
ping -c 3 "$TARGET"

echo ""
echo "2. Testing TCP connect to internal ports..."
nc -z -v -w 3 "$TARGET" 22 80 445 2>&1 || true

echo ""
echo "=== Lateral Movement Test Completed ==="
