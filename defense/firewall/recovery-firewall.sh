#!/bin/sh
# Scope a recovery operation to the disposable café Compose fixture.
set -eu
export MSYS_NO_PATHCONV=1
case "$#:$*" in
    '2:router apply'|'2:router rollback'|'2:router identify') service=firewall ;;
    '2:workstation apply'|'2:workstation rollback'|'2:workstation identify') service=workstation ;;
    *) echo 'Usage: recovery-firewall.sh router|workstation apply|rollback|identify' >&2; exit 2 ;;
esac
project=cafe-waf-validation
name=cafe-validation-$service
identity='{{.Id}}|{{.Name}}|{{.State.Running}}|{{index .Config.Labels "com.docker.compose.project"}}|{{index .Config.Labels "com.docker.compose.service"}}|{{len .HostConfig.PortBindings}}|{{range $name, $net := .NetworkSettings.Networks}}{{$name}}={{$net.IPAddress}}/{{$net.IPPrefixLen}};{{end}}'
record=$(docker inspect --format "$identity" "$name")
id=${record%%|*}
printf '%s\n' "$id" | grep -Eq '^[[:xdigit:]]{64}$' || exit 1
business='cafe-validation-business=192.168.20.25/24;'
if [ "$service" = firewall ]; then
    business='cafe-validation-business=192.168.20.254/24;cafe-validation-guest=192.168.10.254/24;'
fi
[ "$record" = "$id|/$name|true|$project|$service|0|$business" ] || {
    echo 'Unexpected café fixture container identity or interface addresses.' >&2
    exit 1
}
for zone in business guest; do
    subnet=192.168.20.0/24
    [ "$zone" != guest ] || subnet=192.168.10.0/24
    network=$(docker network inspect --format '{{.Driver}}|{{index .Labels "com.docker.compose.project"}}|{{range .IPAM.Config}}{{.Subnet}};{{end}}' "cafe-validation-$zone")
    [ "$network" = "bridge|$project|$subnet;" ] || {
        echo "Unexpected café $zone bridge." >&2
        exit 1
    }
done
if [ "$2" = identify ]; then
    printf '%s\n' "$id"
else
    if [ "$1:$2" = router:apply ]; then
        [ "$(docker exec "$id" cat /proc/sys/net/ipv4/ip_forward)" = 1 ] || {
            echo 'IPv4 forwarding is disabled on the café router.' >&2
            exit 1
        }
    fi
    docker exec -i "$id" sh -s -- "$1" "$2" < defense/firewall/recovery-transaction.sh
fi
