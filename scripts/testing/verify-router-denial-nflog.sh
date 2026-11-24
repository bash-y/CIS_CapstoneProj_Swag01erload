#!/bin/sh
# The validation lab must already be running. This test restores its empty FORWARD policy.
set -eu
export MSYS_NO_PATHCONV=1
router=cafe-validation-firewall
guest=cafe-validation-kali
portal=cafe-validation-business-server

for service in firewall kali business-server; do
    identity=$(docker inspect --format '{{.State.Running}} {{index .Config.Labels "com.docker.compose.project"}} {{index .Config.Labels "com.docker.compose.service"}} {{len .HostConfig.PortBindings}} {{range .NetworkSettings.Networks}}{{.IPAddress}};{{end}}' "cafe-validation-$service")
    case "$service" in
        firewall) addresses='192.168.20.254;192.168.10.254;' ;;
        kali) addresses='192.168.10.50;' ;;
        business-server) addresses='192.168.20.20;' ;;
    esac
    [ "$identity" = "true cafe-waf-validation $service 0 $addresses" ] || exit 1
done
docker exec "$guest" ip -4 route get 192.168.20.20 | grep -F 'via 192.168.10.254' | grep -F 'src 192.168.10.50'
prior=$(docker exec "$router" iptables -S FORWARD)
[ "$prior" = '-P FORWARD ACCEPT' ] || {
    echo 'BLOCKED: the validation router must begin with an empty ACCEPT policy.' >&2
    exit 1
}
dir=$(docker exec "$router" mktemp -d /tmp/cafe-nflog.XXXXXX)
listener=
cleanup() {
    if [ -n "$listener" ]; then wait "$listener" || true; fi
    docker exec "$router" iptables -F FORWARD
    docker exec "$router" sh -c 'rm -f "$1/packet" "$1/listener"; rmdir "$1"' sh "$dir"
}
trap cleanup EXIT
sh defense/firewall/enable-segmentation.sh --validation-lab
# Mirror only the exact address/port tuple to NFLOG, immediately before its DROP.
docker exec "$router" iptables -I FORWARD 3 -s 192.168.10.50 -d 192.168.20.20 \
    -p tcp --sport 45104 --dport 80 -j NFLOG --nflog-group 104 --nflog-prefix 'FW-DROP-GUEST:'
echo 'NFLOG rule and following DROP rule:'
docker exec "$router" iptables -S FORWARD | grep -E 'NFLOG|DROP$'
docker exec "$router" sh -c '
    TZ=UTC timeout 15 tcpdump -i nflog:104 -nn -e -tttt -l -c 1 \
        > "$1/packet" 2> "$1/listener"
' sh "$dir" &
listener=$!
i=0
until docker exec "$router" grep -Fq 'listening on nflog:104' "$dir/listener" 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -ge 10 ]; then
        docker exec "$router" cat "$dir/listener"
        wait "$listener" || true
        exit 1
    fi
    docker exec "$router" sleep 1
done

echo 'Guest probe: HTTP to 192.168.20.20:80 using local TCP port 45104.'
docker exec "$portal" curl --noproxy '*' -fsS -o /dev/null --max-time 5 http://192.168.20.20/
echo 'Business portal healthy before Guest request.'
rc=0
status=$(docker exec "$guest" curl --noproxy '*' -sS --local-port 45104 --connect-timeout 3 \
    --max-time 5 -o /dev/null -w '%{http_code}' http://192.168.20.20/) || rc=$?
echo "Guest HTTP status / curl exit: $status $rc"
[ "$status $rc" = '000 28' ]
wait "$listener"
listener=
record=$(docker exec "$router" cat "$dir/packet")
printf '%s\n' "$record" | grep -E '192\.168\.10\.50\.45104 > 192\.168\.20\.20\.80: Flags \[S\]'
counts=$(docker exec "$router" iptables -nvxL FORWARD)
printf '%s\n' "$counts" | grep -E 'NFLOG|DROP'
printf '%s\n' "$counts" | awk '
    $3=="NFLOG" && $1>0 { logged=1 }
    $3=="DROP" && $8=="192.168.10.0/24" && $9=="192.168.20.0/24" && $1>0 { dropped=1 }
    END { exit !(logged && dropped) }'
cleanup
trap - EXIT
[ "$(docker exec "$router" iptables -S FORWARD)" = "$prior" ]
echo 'Original FORWARD policy restored.'
echo 'PASS: the Guest timed out and the router emitted the matching NFLOG packet record.'
