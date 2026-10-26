#!/bin/bash
# Makefile-style lab runner for SwagPc Café
# Usage: bash lab.sh [start|stop|attack|defend|verify|logs|reset]

set -e
COMPOSE="docker compose -f docker/docker-compose.yml"

case "$1" in
  start)
    echo "=== Starting SwagPc Café Lab ==="
    $COMPOSE up -d --build
    echo "Lab running. DVWA: http://localhost:8080  |  Wazuh: http://localhost:5601"
    ;;
  stop)
    echo "=== Stopping SwagPc Café Lab ==="
    $COMPOSE down
    ;;
  reset)
    echo "=== Resetting Lab (removes all volumes) ==="
    $COMPOSE down -v
    ;;
  status)
    $COMPOSE ps
    ;;
  attack)
    echo "=== Running Full Undefended Attack Sequence ==="
    docker exec -it swagpc-kali bash /scripts/attack/run-full-attack.sh
    ;;
  defend)
    echo "=== Applying pfSense Firewall Segmentation Rules ==="
    bash defense/firewall/enable-segmentation.sh
    ;;
  undefend)
    echo "=== Removing Firewall Rules (back to undefended) ==="
    bash defense/firewall/disable-segmentation.sh
    ;;
  verify)
    echo "=== Running Defense Verification Tests ==="
    bash scripts/testing/verify-defenses.sh
    ;;
  logs)
    echo "=== Suricata Alerts (last 20) ==="
    docker exec swagpc-suricata tail -n 20 /var/log/suricata/fast.log 2>/dev/null || echo "No Suricata alerts yet."
    echo ""
    echo "=== Wazuh Manager Logs ==="
    docker exec swagpc-wazuh tail -n 20 /var/ossec/logs/alerts/alerts.log 2>/dev/null || echo "No Wazuh alerts yet."
    ;;
  *)
    echo "Usage: bash lab.sh [start|stop|reset|status|attack|defend|undefend|verify|logs]"
    ;;
esac
