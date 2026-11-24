#!/bin/sh
# Run from the repository root after starting the four validation services.
set -eu
export MSYS_NO_PATHCONV=1
router=cafe-validation-firewall
guest=cafe-validation-kali
tool=./security-tool/CafeSecurity.exe

for svc in firewall kali dvwa waf; do
    docker run --rm --pull never --network "container:cafe-validation-$svc" \
        --cap-add NET_ADMIN swagpc-waf-validation:local sh -ec \
        'if ip route show default | grep -q .; then ip route del default; fi'
done

return_route() {
    docker run --rm --pull never --network "container:cafe-validation-$1" \
        --cap-add NET_ADMIN swagpc-waf-validation:local \
        ip route "$2" 192.168.10.0/24 via 192.168.20.254
}

return_route dvwa replace
return_route waf replace

echo 'Test scope: café validation Compose project, four containers and no published ports.'
docker version --format 'Docker server {{.Server.Version}}'
for name in cafe-validation-firewall cafe-validation-kali cafe-validation-dvwa cafe-validation-waf; do
    docker inspect --format '{{.Name}} {{.Image}}' "$name"
done

"$tool" check-target --validation-lab
baseline=$(docker exec "$router" iptables -S FORWARD)
if [ "$baseline" != '-P FORWARD ACCEPT' ]; then
    echo 'Expected a fresh validation router with an empty FORWARD chain.' >&2
    exit 1
fi
docker exec "$router" iptables -A FORWARD -s 192.168.20.0/24 -d 192.168.20.0/24 -j ACCEPT
baseline=$(docker exec "$router" iptables -S FORWARD)
printf 'Custom starting policy:\n%s\n' "$baseline"
trap '"$tool" rollback-waf --validation-lab >/dev/null || true; return_route waf replace >/dev/null || true; docker exec "$router" iptables -D FORWARD -s 192.168.20.0/24 -d 192.168.20.0/24 -j ACCEPT >/dev/null || true' EXIT
probe() {
    docker exec "$guest" curl --noproxy '*' -fsS --max-time 5 -o /dev/null -w '%{http_code}' "$1"
}

origin=http://192.168.20.10/login.php
[ "$(probe "$origin")" = 200 ]
echo 'Baseline: Guest reached the direct origin with HTTP 200.'

"$tool" apply-waf --validation-lab
applied=$(docker exec "$router" iptables -S FORWARD)
"$tool" apply-waf --validation-lab
[ "$(docker exec "$router" iptables -S FORWARD)" = "$applied" ]
echo 'Repeated apply left the active policy identical.'
"$tool" verify-waf --validation-lab
"$tool" rollback-waf --validation-lab
[ "$(docker exec "$router" iptables -S FORWARD)" = "$baseline" ]
[ "$(probe "$origin")" = 200 ]
echo 'Rollback restored the complete prior FORWARD policy and direct HTTP 200.'

return_route waf del
if "$tool" apply-waf --validation-lab; then
    echo 'Expected apply to fail while the WAF return route is missing.' >&2
    exit 1
fi
[ "$(docker exec "$router" iptables -S FORWARD)" = "$baseline" ]
return_route waf replace
"$tool" check-target --validation-lab
echo 'Failed apply restored the complete prior FORWARD policy. DVWA default still Low.'
