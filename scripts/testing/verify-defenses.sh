#!/bin/sh
# Check active segmentation against a healthy business service.
set -u
export MSYS_NO_PATHCONV=1
case "$#:$*" in
    0:) prefix=swagpc; project=docker; mode= ;;
    1:--validation-lab) prefix=cafe-validation; project=cafe-waf-validation; mode=--validation-lab ;;
    *) echo 'Usage: verify-defenses.sh [--validation-lab]' >&2; exit 2 ;;
esac

guest=$prefix-kali
router=$prefix-firewall
sensor=$prefix-suricata
server=192.168.20.20
bad=0

result() {
    printf '[%s] %s\n' "$1" "$2"
    case "$1" in FAIL|BLOCKED/ERROR) bad=1 ;; esac
}

# Scope every service before contacting the business portal.
for service in kali firewall workstation business-server; do
    identity=$(docker inspect --format '{{.State.Running}} {{index .Config.Labels "com.docker.compose.project"}} {{index .Config.Labels "com.docker.compose.service"}} {{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' "$prefix-$service") || identity=
    case "$service" in
        kali) address='192.168.10.50 ' ;;
        firewall) address='192.168.20.254 192.168.10.254 ' ;;
        workstation) address='192.168.20.25 ' ;;
        business-server) address="$server " ;;
    esac
    if [ "$identity" != "true $project $service $address" ]; then
        result BLOCKED/ERROR "Unexpected or missing lab container: $prefix-$service."
        exit 1
    fi
done

drops() {
    listing=$(docker exec "$router" iptables -nvxL FORWARD) || return 1
    printf '%s\n' "$listing" | awk '
        $3=="DROP" && $8=="192.168.10.0/24" && $9=="192.168.20.0/24" { print $1; n++ }
        END { if (n != 1) exit 1 }'
}

http_denial() {
    if ! before=$(drops); then
        result BLOCKED/ERROR "Expected router DROP counter is unavailable."
        return
    fi
    reply=$(docker exec "$guest" sh -c '
        code=$(curl --noproxy "*" -sS -o /dev/null -w "%{http_code}" \
            --connect-timeout 3 --max-time 5 "$1")
        rc=$?
        printf "%s %s\n" "$code" "$rc"
    ' sh "http://$server/") || {
        result BLOCKED/ERROR "Could not execute the Guest HTTP probe."
        return
    }
    printf 'Guest HTTP status / curl exit: %s\n' "$reply"
    if ! after=$(drops); then
        result BLOCKED/ERROR "Router counter unavailable after request."
        return
    fi
    printf 'Guest DROP packets: %s -> %s\n' "$before" "$after"
    case "$reply" in
        '000 28') if [ "$after" -gt "$before" ]; then
                      result PASS "Guest HTTP timed out and the DROP counter increased."
                  else
                      result BLOCKED/ERROR "Timed out without a matching counter increase."
                  fi ;;
        [1-5][0-9][0-9]' 0') result FAIL "Guest reached the business HTTP service." ;;
        *) result BLOCKED/ERROR "Inconclusive Guest HTTP result." ;;
    esac
}

fresh_alert() {
    if [ "$(docker inspect --format '{{.State.Running}} {{index .Config.Labels "com.docker.compose.project"}} {{index .Config.Labels "com.docker.compose.service"}}' "$sensor" 2>/dev/null)" != "true $project suricata" ]; then
        result BLOCKED/ERROR "Suricata is missing or outside the selected lab."
        return
    fi
    log=/var/log/suricata/fast.log
    if ! cursor=$(docker exec "$sensor" stat -c '%i %s' "$log") ||
       ! start=$(docker exec "$sensor" date '+%m/%d/%Y-%H:%M:%S'); then
        result BLOCKED/ERROR "Cannot read the Suricata log cursor and clock."
        return
    fi
    inode=${cursor% *}
    bytes=${cursor#* }
    # Five bounded ICMP requests exercise the existing lab ICMP signature.
    probe=$(docker exec "$guest" ping -c 5 -i 0.4 -W 2 "$server" 2>&1)
    rc=$?
    printf 'Guest ICMP exit %s\n%s\n' "$rc" "$probe"
    if ! printf '%s\n' "$probe" | grep -q '^5 packets transmitted'; then
        result BLOCKED/ERROR "Could not send the expected five ICMP requests."
        return
    fi
    if ! appended=$(docker exec "$sensor" sh -ec '
        [ "$(stat -c %i "$1")" = "$2" ] && [ "$(stat -c %s "$1")" -ge "$3" ] || exit 1
        tail -c "+$(($3 + 1))" "$1"
    ' sh "$log" "$inode" "$bytes") ||
       ! finish=$(docker exec "$sensor" date '+%m/%d/%Y-%H:%M:%S'); then
        result BLOCKED/ERROR "Suricata log rotated or could not be read."
        return
    fi
    if printf '%s\n' "$appended" | awk -v start="$start" -v finish="$finish" '
        substr($1,1,19) >= start && substr($1,1,19) <= finish &&
        /\[1:9000002:[0-9]+\]/ && /\{ICMP\} 192\.168\.10\.50 -> 192\.168\.20\.20$/ { found=1 }
        END { exit !found }
    '; then
        result PASS "Fresh Suricata ICMP alert (SID 9000002), Guest to business server."
    else
        result FAIL "No fresh matching Suricata ICMP alert."
    fi
}

if sh scripts/testing/verify-workstation-to-server.sh ${mode:+"$mode"}; then
    result PASS "Workstation to business portal."
    http_denial
else
    result FAIL "Workstation to business portal."
    result BLOCKED/ERROR "Guest denial requires a healthy business service."
fi
result 'NOT RUN' "Internet access. The lab has no modeled WAN."
fresh_alert
exit "$bad"
