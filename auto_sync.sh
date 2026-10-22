#!/usr/bin/env bash
#
# auto_sync.sh - Manager script for GitHub Auto-Sync
# Usage:
#   ./auto_sync.sh start     Start auto-sync daemon in background
#   ./auto_sync.sh stop      Stop background auto-sync
#   ./auto_sync.sh status    Check if auto-sync is currently running
#   ./auto_sync.sh logs      Follow sync log in real-time
#   ./auto_sync.sh now       Perform an immediate one-time sync
#   ./auto_sync.sh run       Run auto-sync in foreground (interactive)
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

PID_FILE="$SCRIPT_DIR/.auto_sync.pid"
LOG_FILE="$SCRIPT_DIR/auto_sync.log"
PYTHON_BIN="/usr/bin/python3"

# Fallback to python in PATH if /usr/bin/python3 is not available
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    PYTHON_BIN="python3"
fi

is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

start_sync() {
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo "[!] Auto-sync is already running (PID: $pid)."
        echo "    Run './auto_sync.sh status' or './auto_sync.sh logs' to inspect."
        return 0
    fi

    echo "[*] Starting Auto-Sync background service..."
    nohup "$PYTHON_BIN" "$SCRIPT_DIR/auto_sync.py" "$@" >> "$LOG_FILE" 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$PID_FILE"

    # Give it a second to initialize
    sleep 1
    if kill -0 "$new_pid" 2>/dev/null; then
        echo "[✔] Auto-sync started successfully (PID: $new_pid)."
        echo "    Logging to: $LOG_FILE"
        echo "    Run './auto_sync.sh logs' to follow activity."
    else
        echo "[✖] Auto-sync failed to start. Last log lines:"
        tail -n 10 "$LOG_FILE"
        rm -f "$PID_FILE"
    fi
}

stop_sync() {
    if ! is_running; then
        echo "[*] Auto-sync is not running."
        rm -f "$PID_FILE"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE")
    echo "[*] Stopping Auto-Sync (PID: $pid)..."
    kill "$pid" 2>/dev/null

    # Wait up to 5 seconds for clean exit
    for i in {1..5}; do
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        sleep 1
    done

    if kill -0 "$pid" 2>/dev/null; then
        echo "[*] Process did not terminate; forcing kill..."
        kill -9 "$pid" 2>/dev/null
    fi

    rm -f "$PID_FILE"
    echo "[✔] Auto-sync stopped."
}

status_sync() {
    echo "================================================"
    echo "            GitHub Auto-Sync Status             "
    echo "================================================"
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo " State : RUNNING (PID: $pid)"
    else
        echo " State : STOPPED"
    fi

    local curr_branch
    curr_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    echo " Current Branch : $curr_branch"
    echo " Log File       : $LOG_FILE"
    echo "------------------------------------------------"

    if [ -f "$LOG_FILE" ]; then
        echo "Recent Activity (last 10 lines):"
        tail -n 10 "$LOG_FILE"
    else
        echo "No log file found yet."
    fi
    echo "================================================"
}

logs_sync() {
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
    fi
    echo "[*] Streaming $LOG_FILE (Press Ctrl+C to exit)..."
    tail -f "$LOG_FILE"
}

now_sync() {
    echo "[*] Running immediate one-time sync..."
    "$PYTHON_BIN" "$SCRIPT_DIR/auto_sync.py" --once "$@"
}

run_sync() {
    echo "[*] Running Auto-Sync in foreground..."
    "$PYTHON_BIN" "$SCRIPT_DIR/auto_sync.py" "$@"
}

case "$1" in
    start)
        shift
        start_sync "$@"
        ;;
    stop)
        stop_sync
        ;;
    status)
        status_sync
        ;;
    logs)
        logs_sync
        ;;
    now)
        shift
        now_sync "$@"
        ;;
    run)
        shift
        run_sync "$@"
        ;;
    *)
        echo "Usage: $0 {start|stop|status|logs|now|run}"
        echo ""
        echo "Commands:"
        echo "  start   - Launch auto-sync in the background"
        echo "  stop    - Stop the running background auto-sync"
        echo "  status  - View current status and recent sync activity"
        echo "  logs    - Watch live log output"
        echo "  now     - Trigger a single sync right now"
        echo "  run     - Run interactively in the terminal foreground"
        exit 1
        ;;
esac
