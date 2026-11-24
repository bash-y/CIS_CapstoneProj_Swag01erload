#!/bin/bash
# Makefile-style lab runner for SwagPc Café
# Usage: bash lab.sh [start [defended|baseline]|stop|status|mode|defend|undefend|attack|verify|logs|reset]
#
# Modes (US-17, #127): the lab starts "defended" unless you ask for "baseline", the intentionally
# vulnerable flat network. The firewall rebuilds its rules from LAB_MODE on every start, restart
# and recreation, so restarting the lab cannot silently remove the defense.

set -e
# LAB_COMPOSE replaces the compose command; scripts/testing/test-lab-switch.sh uses it to add an override file.
COMPOSE="${LAB_COMPOSE:-docker compose -f docker/docker-compose.yml}"
FW="swagpc-firewall"
INIT="/scripts/firewall/firewall-init.sh"

mode_arg() {
  case "${1:-defended}" in
    defended|baseline) echo "${1:-defended}" ;;
    *) echo "Unknown mode '$1'. Use defended (default) or baseline." >&2; exit 2 ;;
  esac
}

live_mode() { docker exec "$FW" sh "$INIT" status 2>/dev/null || echo "not running"; }

configured_mode() {
  docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$FW" 2>/dev/null | sed -n 's/^LAB_MODE=//p'
}

wait_for_mode() {
  for _ in $(seq 1 30); do
    [ "$(live_mode)" = "$1" ] && return 0
    sleep 1
  done
  echo "[ERROR] $FW did not reach mode '$1' within 30 s (live: $(live_mode)). A stopped firewall forwards nothing." >&2
  docker logs --tail 20 "$FW" >&2 || true
  exit 1
}

show_mode() {
  local live
  live=$(live_mode)
  echo "Lab mode: configured=$(configured_mode) live=$live"
  if [ "$live" = baseline ]; then
    echo "WARNING: baseline is the intentionally vulnerable flat network; the firewall lets Guest reach Business." >&2
  fi
}

up_in_mode() {  # up_in_mode <mode> [docker compose up arguments...]
  local mode=$1
  shift
  if [ "$mode" = baseline ]; then
    echo "!!! Entering BASELINE: intentionally vulnerable flat network, all forwarding allowed !!!"
  fi
  LAB_MODE=$mode $COMPOSE up -d "$@"
  wait_for_mode "$mode"
  show_mode
}

case "$1" in
  start)
    mode=$(mode_arg "${2:-}")
    echo "=== Starting SwagPc Café Lab (mode: $mode) ==="
    up_in_mode "$mode" --build
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
  mode)
    show_mode
    ;;
  attack)
    if [ "$(live_mode)" != baseline ]; then
      echo "[ERROR] The attack sequence targets the undefended baseline, but the firewall mode is '$(live_mode)'." >&2
      echo "        Run: bash lab.sh undefend   (or: bash lab.sh start baseline)" >&2
      exit 1
    fi
    echo "=== Running Full Undefended Attack Sequence ==="
    docker exec -it swagpc-kali bash /scripts/attack/run-full-attack.sh
    ;;
  defend)
    echo "=== Switching to DEFENDED mode (recreates the firewall and Suricata; volumes are kept) ==="
    up_in_mode defended --force-recreate --no-deps firewall suricata
    ;;
  undefend)
    echo "=== Switching to BASELINE mode (recreates the firewall and Suricata; volumes are kept) ==="
    up_in_mode baseline --force-recreate --no-deps firewall suricata
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
    echo "Usage: bash lab.sh [start [defended|baseline]|stop|reset|status|mode|attack|defend|undefend|verify|logs]"
    ;;
esac
