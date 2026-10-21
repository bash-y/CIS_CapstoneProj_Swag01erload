#!/usr/bin/env bash
#
# firewall_dvwa.sh - Firewall rule manager to protect DVWA against Kali attacks
# Designed for CIS 3353 Capstone Lab (Cedar Valley Family Clinic)
#
# Usage:
#   sudo ./firewall_dvwa.sh block [KALI_IP]     Block Kali from accessing DVWA
#   sudo ./firewall_dvwa.sh unblock [KALI_IP]   Remove block rules (allow traffic for baseline demo)
#   sudo ./firewall_dvwa.sh status              Show active firewall rules and block state
#   sudo ./firewall_dvwa.sh test                Test connection from Kali to DVWA (Docker lab)
#   sudo ./firewall_dvwa.sh logs                Show kernel/firewall log of dropped Kali packets
#

set -e

RULE_COMMENT="CIS3353-BLOCK-KALI"
LOG_PREFIX="[DVWA-FW-BLOCKED] "
DVWA_CONTAINER="swagpc-dvwa"
KALI_CONTAINER="swagpc-kali"

# Ensure script is run with root/sudo privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "[✖] Error: This script must be run as root or with sudo:"
        echo "    sudo $0 $1"
        exit 1
    fi
}

# Auto-detect container IP addresses if Docker is present and running
get_container_ip() {
    local container="$1"
    if command -v docker >/dev/null 2>&1; then
        local ip
        ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null || true)
        echo "$ip"
    fi
}

resolve_ips() {
    local input_kali_ip="$1"

    if [ -n "$input_kali_ip" ]; then
        KALI_IP="$input_kali_ip"
    else
        KALI_IP=$(get_container_ip "$KALI_CONTAINER")
    fi

    DVWA_IP=$(get_container_ip "$DVWA_CONTAINER")

    # If still not found, prompt or fallback
    if [ -z "$KALI_IP" ]; then
        echo "[!] Kali IP could not be auto-detected from Docker."
        read -rp "    Enter Kali IP address to block: " KALI_IP
    fi

    if [ -z "$KALI_IP" ]; then
        echo "[✖] Error: No Kali IP specified."
        exit 1
    fi
}

block_kali() {
    check_root "block"
    resolve_ips "$1"

    echo "=========================================================="
    echo "  🛡️  Activating Firewall Rules Against Kali Attacker"
    echo "=========================================================="
    echo "  Target Kali IP : $KALI_IP"
    if [ -n "$DVWA_IP" ]; then
        echo "  Target DVWA IP : $DVWA_IP"
    fi
    echo "----------------------------------------------------------"

    # First, make sure old rules with this comment are purged to prevent duplicate entries
    unblock_kali_silent "$KALI_IP"

    # Check if Docker chains exist
    if iptables -L DOCKER-USER -n >/dev/null 2>&1; then
        echo "[*] Adding logging & drop rules to DOCKER-USER chain..."
        if [ -n "$DVWA_IP" ]; then
            iptables -I DOCKER-USER 1 -s "$KALI_IP" -d "$DVWA_IP" -m comment --comment "$RULE_COMMENT" -j DROP
            iptables -I DOCKER-USER 1 -s "$KALI_IP" -d "$DVWA_IP" -m comment --comment "$RULE_COMMENT" -j LOG --log-prefix "$LOG_PREFIX" --log-level 4
        else
            iptables -I DOCKER-USER 1 -s "$KALI_IP" -p tcp -m multiport --dports 80,8080,443 -m comment --comment "$RULE_COMMENT" -j DROP
            iptables -I DOCKER-USER 1 -s "$KALI_IP" -p tcp -m multiport --dports 80,8080,443 -m comment --comment "$RULE_COMMENT" -j LOG --log-prefix "$LOG_PREFIX" --log-level 4
        fi
    fi

    # Forward chain rule (covers bridge traffic between containers on cafe-lab network)
    echo "[*] Adding logging & drop rules to FORWARD chain..."
    if [ -n "$DVWA_IP" ]; then
        iptables -I FORWARD 1 -s "$KALI_IP" -d "$DVWA_IP" -m comment --comment "$RULE_COMMENT" -j DROP
        iptables -I FORWARD 1 -s "$KALI_IP" -d "$DVWA_IP" -m comment --comment "$RULE_COMMENT" -j LOG --log-prefix "$LOG_PREFIX" --log-level 4
    else
        iptables -I FORWARD 1 -s "$KALI_IP" -p tcp -m multiport --dports 80,8080,443 -m comment --comment "$RULE_COMMENT" -j DROP
        iptables -I FORWARD 1 -s "$KALI_IP" -p tcp -m multiport --dports 80,8080,443 -m comment --comment "$RULE_COMMENT" -j LOG --log-prefix "$LOG_PREFIX" --log-level 4
    fi

    # Host INPUT chain rule (in case DVWA is running directly on host port 80/8080)
    echo "[*] Adding drop rule to INPUT chain..."
    iptables -I INPUT 1 -s "$KALI_IP" -p tcp -m multiport --dports 80,8080,443 -m comment --comment "$RULE_COMMENT" -j DROP
    iptables -I INPUT 1 -s "$KALI_IP" -p tcp -m multiport --dports 80,8080,443 -m comment --comment "$RULE_COMMENT" -j LOG --log-prefix "$LOG_PREFIX" --log-level 4

    echo "----------------------------------------------------------"
    echo "[✔] SUCCESS: Kali ($KALI_IP) is now BLOCKED from accessing DVWA."
    echo "[*] Blocked packet attempts will be logged with prefix: '$LOG_PREFIX'"
    echo "    Run 'sudo $0 logs' to see blocked attack attempts."
    echo "=========================================================="
}

unblock_kali_silent() {
    local kali_ip="$1"
    for chain in DOCKER-USER FORWARD INPUT; do
        if iptables -L "$chain" -n >/dev/null 2>&1; then
            # Delete any rule matching our comment or source IP
            while iptables -D "$chain" -m comment --comment "$RULE_COMMENT" 2>/dev/null; do :; done
            if [ -n "$kali_ip" ]; then
                while iptables -D "$chain" -s "$kali_ip" -j DROP 2>/dev/null; do :; done
                while iptables -D "$chain" -s "$kali_ip" -j LOG --log-prefix "$LOG_PREFIX" --log-level 4 2>/dev/null; do :; done
            fi
        fi
    done
}

unblock_kali() {
    check_root "unblock"
    resolve_ips "$1"

    echo "=========================================================="
    echo "  🔓  Removing Firewall Rules (Permit Traffic)"
    echo "=========================================================="
    echo "  Unblocking Kali IP : $KALI_IP"

    unblock_kali_silent "$KALI_IP"

    echo "[✔] SUCCESS: All block rules removed."
    echo "    Kali ($KALI_IP) can now reach DVWA (ready for baseline attack demo)."
    echo "=========================================================="
}

status_firewall() {
    echo "=========================================================="
    echo "  🔍  Active Firewall Rules for DVWA Protection"
    echo "=========================================================="

    local found=0
    for chain in DOCKER-USER FORWARD INPUT; do
        if iptables -L "$chain" -n >/dev/null 2>&1; then
            local rules
            rules=$(iptables -L "$chain" -v -n --line-numbers 2>/dev/null | grep "$RULE_COMMENT" || true)
            if [ -n "$rules" ]; then
                echo ""
                echo "Chain: $chain"
                echo "$rules"
                found=1
            fi
        fi
    done

    echo "----------------------------------------------------------"
    if [ "$found" -eq 1 ]; then
        echo "  STATUS: 🛡️  ACTIVE (Kali is currently BLOCKED)"
    else
        echo "  STATUS: 🔓  INACTIVE (No Kali blocking rules detected)"
    fi

    if command -v docker >/dev/null 2>&1; then
        local kali_ip dvwa_ip
        kali_ip=$(get_container_ip "$KALI_CONTAINER")
        dvwa_ip=$(get_container_ip "$DVWA_CONTAINER")
        echo "  Docker Containers detected:"
        echo "    - $KALI_CONTAINER : ${kali_ip:-not running}"
        echo "    - $DVWA_CONTAINER : ${dvwa_ip:-not running}"
    fi
    echo "=========================================================="
}

test_attack() {
    echo "=========================================================="
    echo "  🧪  Testing Attack Connection (Kali -> DVWA)"
    echo "=========================================================="

    if ! command -v docker >/dev/null 2>&1; then
        echo "[✖] Docker CLI not found. Run this test directly from Kali."
        exit 1
    fi

    local kali_ip dvwa_ip
    kali_ip=$(get_container_ip "$KALI_CONTAINER")
    dvwa_ip=$(get_container_ip "$DVWA_CONTAINER")

    if [ -z "$kali_ip" ] || [ -z "$dvwa_ip" ]; then
        echo "[✖] Containers are not running. Run: docker-compose up -d in docker/"
        exit 1
    fi

    echo "  Testing HTTP request from $KALI_CONTAINER ($kali_ip) to $DVWA_CONTAINER ($dvwa_ip:80)..."
    echo ""

    if docker exec "$KALI_CONTAINER" curl -s -m 3 "http://$dvwa_ip:80" >/dev/null 2>&1 || \
       docker exec "$KALI_CONTAINER" nc -z -w 3 "$dvwa_ip" 80 >/dev/null 2>&1; then
        echo "  🚨 RESULT: ATTACK SUCCEEDED!"
        echo "     Kali was able to reach DVWA on port 80."
        echo "     Firewall is NOT currently blocking Kali."
    else
        echo "  🛡️ RESULT: BLOCKED / CONNECTION TIMED OUT!"
        echo "     Kali cannot reach DVWA on port 80."
        echo "     The firewall is successfully defending DVWA."
    fi
    echo "=========================================================="
}

view_logs() {
    check_root "logs"
    echo "=========================================================="
    echo "  📜  Firewall Dropped Packet Evidence Log"
    echo "=========================================================="
    echo "Scanning dmesg and syslog for '$LOG_PREFIX'..."
    echo ""

    local found=0
    if dmesg 2>/dev/null | grep -q "$LOG_PREFIX"; then
        dmesg -T 2>/dev/null | grep "$LOG_PREFIX" | tail -n 20 || dmesg | grep "$LOG_PREFIX" | tail -n 20
        found=1
    elif [ -f /var/log/kern.log ] && grep -q "$LOG_PREFIX" /var/log/kern.log 2>/dev/null; then
        grep "$LOG_PREFIX" /var/log/kern.log | tail -n 20
        found=1
    elif [ -f /var/log/syslog ] && grep -q "$LOG_PREFIX" /var/log/syslog 2>/dev/null; then
        grep "$LOG_PREFIX" /var/log/syslog | tail -n 20
        found=1
    fi

    if [ "$found" -eq 0 ]; then
        echo "No dropped packet logs found yet."
        echo "(Logs will appear once Kali attempts to connect while rules are active)."
    fi
    echo "=========================================================="
}

case "$1" in
    block)
        shift
        block_kali "$@"
        ;;
    unblock)
        shift
        unblock_kali "$@"
        ;;
    status)
        status_firewall
        ;;
    test)
        test_attack
        ;;
    logs)
        view_logs
        ;;
    *)
        echo "Usage: sudo $0 {block|unblock|status|test|logs} [KALI_IP]"
        echo ""
        echo "Commands:"
        echo "  block   [IP]  - Block Kali from attacking DVWA (auto-detects Kali IP if in Docker)"
        echo "  unblock [IP]  - Remove block rules to allow baseline attack demonstration"
        echo "  status        - Check current firewall rules and blocking status"
        echo "  test          - Test connection from Kali to DVWA to verify if attack succeeds or drops"
        echo "  logs          - Display logged evidence of blocked attack attempts"
        exit 1
        ;;
esac
