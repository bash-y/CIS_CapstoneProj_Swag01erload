#!/bin/sh
# Repeat the same allowed and denied flow checks on a fresh validation router.
set -eu
export MSYS_NO_PATHCONV=1
project=cafe-waf-validation
router=cafe-validation-firewall
guest=cafe-validation-kali
server=192.168.20.20

identity='{{.State.Running}}|{{index .Config.Labels "com.docker.compose.project"}}|{{index .Config.Labels "com.docker.compose.service"}}|{{len .HostConfig.PortBindings}}|{{range $name, $net := .NetworkSettings.Networks}}{{$name}}={{$net.IPAddress}};{{end}}'
for service in firewall kali workstation business-server; do
    case "$service" in
        firewall) network='cafe-validation-business=192.168.20.254;cafe-validation-guest=192.168.10.254;' ;;
        kali) network='cafe-validation-guest=192.168.10.50;' ;;
        workstation) network='cafe-validation-business=192.168.20.25;' ;;
        business-server) network='cafe-validation-business=192.168.20.20;' ;;
    esac
    actual=$(docker inspect --format "$identity" "cafe-validation-$service")
    [ "$actual" = "true|$project|$service|0|$network" ] || {
        echo "BLOCKED: unexpected identity, networks or published ports for $service." >&2
        exit 1
    }
    docker inspect --format '{{.Name}} {{.Image}}' "cafe-validation-$service"
done

echo 'Allowed: workstation 192.168.20.25 to business server 192.168.20.20 (ICMP, TCP/80 and HTTP).'
echo 'Negative control: Guest 192.168.10.50 to the same HTTP service.'
echo 'WAN: NOT RUN. The router has no modeled WAN and this fixture uses no default routes.'
prior=$(docker exec "$router" iptables -S FORWARD)
[ "$prior" = '-P FORWARD ACCEPT' ] || {
    echo 'BLOCKED: expected an empty FORWARD chain with ACCEPT policy in the disposable router.' >&2
    exit 1
}

for service in firewall kali workstation business-server; do
    docker exec "cafe-validation-$service" sh -ec \
        'while ip route show default | grep -q .; do ip route del default; done'
done
docker exec cafe-validation-business-server ip route replace 192.168.10.0/24 via 192.168.20.254
docker exec "$guest" ip -4 route get "$server" | grep -F 'via 192.168.10.254'
docker exec cafe-validation-business-server ip -4 route get 192.168.10.50 | grep -F 'via 192.168.20.254'


portal() {
    sh scripts/testing/verify-workstation-to-server.sh --validation-lab
}

guest_http() {
    echo "Guest probe: curl --noproxy '*' --connect-timeout 3 --max-time 5 http://$server/" >&2
    docker exec "$guest" sh -c '
        curl --noproxy "*" -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "$1"
        printf " %s\n" "$?"
    ' sh "http://$server/"
}

drops() {
    docker exec "$router" iptables -nvxL FORWARD | awk '
        $3=="DROP" && $8=="192.168.10.0/24" && $9=="192.168.20.0/24" { print $1; n++ }
        END { if (n != 1) exit 1 }
    '
}

echo '=== Baseline ==='
portal
baseline=$(guest_http)
echo "Guest HTTP status / curl exit: $baseline"
[ "$baseline" = '200 0' ]

trap 'docker exec "$router" iptables -F FORWARD' EXIT
echo '=== Defended with the project segmentation script ==='
sh defense/firewall/enable-segmentation.sh --validation-lab
portal
before=$(drops)
defended=$(guest_http)
after=$(drops)
echo "Guest HTTP status / curl exit: $defended"
echo "Guest-to-Business DROP packets: $before -> $after"
[ "$defended" = '000 28' ]
[ "$after" -gt "$before" ]

docker exec "$router" iptables -F FORWARD
[ "$(docker exec "$router" iptables -S FORWARD)" = "$prior" ]
trap - EXIT
echo 'PASS: employee service stayed reachable, Guest HTTP was denied, and the starting policy was restored.'
