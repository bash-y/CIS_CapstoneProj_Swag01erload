#!/usr/bin/env bash
#
# AutoSync.command - Double-clickable macOS launcher for GitHub Auto-Sync
#

cd "$(dirname "$0")" || exit 1

clear
while true; do
    echo "=========================================================="
    echo "            🚀 GitHub Auto-Sync Control Center             "
    echo "=========================================================="

    if ./auto_sync.sh status | grep -q "RUNNING"; then
        echo "  STATUS: 🟢 RUNNING IN BACKGROUND"
    else
        echo "  STATUS: 🔴 STOPPED"
    fi

    echo "  BRANCH: $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    echo "=========================================================="
    echo "  1) Start background auto-sync"
    echo "  2) Stop background auto-sync"
    echo "  3) Sync once right now"
    echo "  4) View live sync logs"
    echo "  5) Check status"
    echo "  6) Exit"
    echo "=========================================================="
    read -rp "Select an option [1-6]: " choice

    case "$choice" in
        1)
            echo ""
            ./auto_sync.sh start
            echo ""
            read -rp "Press Enter to continue..."
            ;;
        2)
            echo ""
            ./auto_sync.sh stop
            echo ""
            read -rp "Press Enter to continue..."
            ;;
        3)
            echo ""
            ./auto_sync.sh now
            echo ""
            read -rp "Press Enter to continue..."
            ;;
        4)
            echo ""
            ./auto_sync.sh logs
            ;;
        5)
            echo ""
            ./auto_sync.sh status
            echo ""
            read -rp "Press Enter to continue..."
            ;;
        6)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose between 1 and 6."
            sleep 1
            ;;
    esac
    clear
done
