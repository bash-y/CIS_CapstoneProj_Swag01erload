#!/bin/sh
# All docker calls go to the fixture on PATH. No daemon is contacted.
set -eu
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export CAFE_MOCK="$work"
cat > "$work/docker" <<'MOCK'
#!/bin/sh
set -eu
if [ "$1" = inspect ]; then
    case "$4" in
        swagpc-kali) service=kali; ip='192.168.10.50 ' ;;
        swagpc-firewall) service=firewall; ip='192.168.20.254 192.168.10.254 ' ;;
        swagpc-workstation) service=workstation; ip='192.168.20.25 ' ;;
        swagpc-business-server) service=business-server; ip='192.168.20.20 ' ;;
        swagpc-suricata) echo 'true docker suricata'; exit ;;
        *) exit 1 ;;
    esac
    [ "$SCENARIO" != missing-container ] || exit 1
    printf 'true docker %s %s\n' "$service" "$ip"
    exit
fi
case "$2:$3" in
    swagpc-workstation:ping|swagpc-workstation:nc) exit 0 ;;
    swagpc-workstation:curl)
        [ "$SCENARIO" != empty ] && printf 'Business Operations\n200\n'
        exit 0 ;;
    swagpc-firewall:iptables)
        count=0
        if [ -f "$CAFE_MOCK/probed" ]; then count=3; fi
        echo "$count 0 DROP all -- * * 192.168.10.0/24 192.168.20.0/24" ;;
    swagpc-kali:sh)
        touch "$CAFE_MOCK/probed"
        case "$SCENARIO" in
            refused) echo '000 7' ;;
            missing-tool) echo ' 127' ;;
            bypass) echo '200 0' ;;
            *) echo '000 28' ;;
        esac ;;
    swagpc-kali:ping) echo '5 packets transmitted, 0 packets received'; exit 1 ;;
    swagpc-suricata:stat) [ "$SCENARIO" != missing-log ] && echo '123 0' ;;
    swagpc-suricata:date) echo '11/22/2026-18:00:00' ;;
    swagpc-suricata:sh)
        stamp='11/22/2026-18:00:00'
        [ "$SCENARIO" != stale ] || stamp='11/22/2026-17:59:59'
        echo "$stamp.123456 [**] [1:9000002:1] Test [**] {ICMP} 192.168.10.50:8 -> 192.168.20.20:0" ;;
    *) exit 1 ;;
esac
MOCK
if command -v chmod >/dev/null; then chmod +x "$work/docker"; fi
[ -x "$work/docker" ]
export PATH="$work:$PATH"
check() {
    export SCENARIO="$1"
    rm -f "$work/probed"
    rc=0
    output=$(sh scripts/testing/verify-defenses.sh 2>&1) || rc=$?
    if [ "$rc" -ne "$2" ] || ! printf '%s\n' "$output" | grep -Fq "$3"; then
        printf 'FAIL %s (exit %s)\n%s\n' "$1" "$rc" "$output"
        exit 1
    fi
    printf 'PASS %s\n' "$1"
}
check defended 0 '[PASS] Guest HTTP timed out and the DROP counter increased.'
check refused 1 '[BLOCKED/ERROR] Inconclusive Guest HTTP result.'
check missing-tool 1 '[BLOCKED/ERROR] Inconclusive Guest HTTP result.'
check missing-log 1 '[BLOCKED/ERROR] Cannot read the Suricata log cursor'
check empty 1 '[FAIL] Workstation to business portal.'
check missing-container 1 '[BLOCKED/ERROR] Unexpected or missing lab container'
check stale 1 '[FAIL] No fresh matching Suricata ICMP alert.'
check bypass 1 '[FAIL] Guest reached the business HTTP service.'
