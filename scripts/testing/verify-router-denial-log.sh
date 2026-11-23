#!/bin/sh
set -eu
export MSYS_NO_PATHCONV=1
router=cafe-validation-firewall
for service in firewall kali business-server; do
    actual=$(docker inspect --format '{{.State.Running}} {{index .Config.Labels "com.docker.compose.project"}} {{index .Config.Labels "com.docker.compose.service"}}' "cafe-validation-$service")
    [ "$actual" = "true cafe-waf-validation $service" ] || exit 1
done
docker exec cafe-validation-kali ip -4 route get 192.168.20.20 | grep -F 'via 192.168.10.254' | grep -F 'src 192.168.10.50'
echo 'Checking existing FW-DROP-GUEST LOG rule for Guest 192.168.10.50 to business portal 192.168.20.20:80/TCP.'
docker exec "$router" iptables -nvxL FORWARD | grep -E 'FW-DROP-GUEST|DROP'
read_matching() {
    docker run --rm --pull never --network none --cap-add SYSLOG swagpc-waf-validation:local sh -ec '
        dmesg -r >/dev/null
        dmesg -r | awk "/FW-DROP-GUEST: .*SRC=192[.]168[.]10[.]50 DST=192[.]168[.]20[.]20 .*PROTO=TCP SPT=45104 DPT=80 / {print; found=1} "
    '
}
before=$(read_matching) || exit 1
rc=0
docker exec cafe-validation-kali curl --noproxy '*' -sS --local-port 45104 \
    --connect-timeout 3 --max-time 5 -o /dev/null -w 'HTTP %{http_code}\n' http://192.168.20.20/ || rc=$?
echo "curl exit: $rc"
docker exec "$router" iptables -nvxL FORWARD | grep -E 'FW-DROP-GUEST|DROP'
after=$(read_matching) || exit 1
if [ "$after" = "$before" ] || [ -z "$after" ]; then
    echo 'BLOCKED: the kernel log returned no new matching record for the scoped TCP request.'
    exit 1
fi
printf '%s\n' "$after" | tail -n 1
[ "$rc" -eq 28 ]
