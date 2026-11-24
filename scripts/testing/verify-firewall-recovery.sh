#!/bin/sh
set -eu
export MSYS_NO_PATHCONV=1
ctl=defense/firewall/recovery-firewall.sh
tx=defense/firewall/recovery-transaction.sh
router=$(sh "$ctl" router identify)
ws=$(sh "$ctl" workstation identify)
guest=cafe-validation-kali
server=cafe-validation-business-server
workstation=cafe-validation-workstation
for service in kali business-server; do
    id=$(docker inspect --format '{{.State.Running}}|{{index .Config.Labels "com.docker.compose.project"}}|{{index .Config.Labels "com.docker.compose.service"}}|{{len .HostConfig.PortBindings}}|{{range $name, $net := .NetworkSettings.Networks}}{{$name}}={{$net.IPAddress}};{{end}}' "cafe-validation-$service")
    case "$service" in
        kali) address='cafe-validation-guest=192.168.10.50;' ;;
        business-server) address='cafe-validation-business=192.168.20.20;' ;;
    esac
    [ "$id" = "true|cafe-waf-validation|$service|0|$address" ]
done
[ "$(docker exec "$router" iptables -S FORWARD)" = '-P FORWARD ACCEPT' ]
[ "$(docker exec "$ws" iptables -S INPUT)" = '-P INPUT ACCEPT' ]

for service in "$router" "$ws" "$guest" "$server"; do
    docker exec "$service" sh -ec \
        'while ip route show default | grep -q .; do ip route del default; done'
done
docker exec "$server" ip route replace 192.168.10.0/24 via 192.168.20.254
docker exec "$ws" ip route replace 192.168.10.0/24 via 192.168.20.254
docker exec "$guest" ip -4 route get 192.168.20.25 | grep -F 'via 192.168.10.254' | grep -F 'src 192.168.10.50'
echo 'Test targets: disposable router FORWARD and workstation INPUT. No login or account modifications.'

seed_rule() {
    docker exec "$1" iptables "$2" "$3" -s 192.168.20.20 -d 192.168.20.25 -p icmp --icmp-type echo-request -m length --length 92 -j DROP
}
active=
cleanup() {
    if [ -n "$active" ]; then
        sh "$ctl" "$active" rollback || {
            echo "Recovery journal retained for $active. Inspect the validation container." >&2
            return 1
        }
        docker exec "$target" iptables -P "$chain" ACCEPT || true
        docker exec "$target" iptables -D "$chain" -j ACCEPT || true
        seed_rule "$target" -D "$chain" || true
    fi
}
trap cleanup EXIT
portal() {
    sh scripts/testing/verify-workstation-to-server.sh --validation-lab
}

guest_reply() {
    rc=0
    output=$(docker exec "$guest" ping -c 2 -W 2 "$1" 2>&1) || rc=$?
    printf 'Guest ICMP to %s, exit %s:\n%s\n' "$1" "$rc" "$output"
    case "$2" in
        allowed) [ "$rc" -eq 0 ] && printf '%s\n' "$output" | grep -Eq '^2 packets transmitted, 2 (packets )?received' ;;
        denied) [ "$rc" -eq 1 ] && printf '%s\n' "$output" | grep -Eq '^2 packets transmitted, 0 (packets )?received' ;;
    esac
}

interrupt_apply() {
    # Only this diagnostic docker exec uses the shim. It runs the real kernel
    # commit, then terminates the waiting shell before its post-commit check.
    target=$1
    control=$2
    shim=$(docker exec "$target" mktemp -d /tmp/cafe-interrupt.XXXXXX)
    docker exec -i "$target" sh -c 'cat > "$1/iptables-restore"; chmod 700 "$1/iptables-restore"' sh "$shim" <<'MOCK'
#!/bin/sh
set -e
real=$(PATH=/usr/sbin:/usr/bin:/sbin:/bin command -v iptables-restore)
"$real" "$@"
case " $* " in
    *' --test '*) ;;
    *) kill -TERM "$PPID" ;;
esac
MOCK
    rc=0
    docker exec -e "PATH=$shim:/usr/sbin:/usr/bin:/sbin:/bin" -i "$target" \
        sh -s -- "$control" apply < "$tx" || rc=$?
    docker exec "$target" sh -c 'rm -f "$1/iptables-restore"; rmdir "$1"' sh "$shim"
    [ "$rc" -ne 0 ] || { echo 'Expected apply to be interrupted.' >&2; return 1; }
    echo "Apply interrupted after the kernel commit, exit $rc."
}

for control in router workstation; do
    case "$control" in
        router) target=$router; chain=FORWARD; managed=CAFE150_GUEST; destination=192.168.20.20 ;;
        workstation) target=$ws; chain=INPUT; managed=CAFE150_WORKSTATION; destination=192.168.20.25 ;;
    esac
    active=$control
    seed_rule "$target" -A "$chain"
    docker exec "$target" iptables -A "$chain" -j ACCEPT
    docker exec "$target" iptables -P "$chain" DROP
    prior=$(docker exec "$target" iptables -S "$chain")
    printf '\n=== %s custom starting policy ===\n%s\n' "$control" "$prior"
    guest_reply "$destination" allowed
    sh "$ctl" "$control" apply
    current=$(docker exec "$target" iptables -S "$chain")
    printf '%s\n' "$current" | grep -F -- '-s 192.168.20.20/32 -d 192.168.20.25/32'
    sh "$ctl" "$control" apply
    [ "$(docker exec "$target" iptables -S "$chain")" = "$current" ]
    echo 'Repeated apply left the policy identical.'
    portal
    if [ "$control" = workstation ]; then
        docker exec "$server" ping -c 2 -W 2 192.168.20.25
        rc=0
        blocked=$(docker exec "$server" ping -s 64 -c 2 -W 2 192.168.20.25 2>&1) || rc=$?
        [ "$rc" -eq 1 ]
        printf '%s\n' "$blocked" | grep -Eq '^2 packets transmitted, 0 (packets )?received'
        echo 'Existing Business ICMP restriction still denies the seeded 64-byte ping.'
    fi
    guest_reply "$destination" denied
    docker exec "$target" iptables -nvxL "$managed" | awk '$3=="DROP" && $1>0 {print; seen=1} END {exit !seen}'
    sh "$ctl" "$control" rollback
    [ "$(docker exec "$target" iptables -S "$chain")" = "$prior" ]
    guest_reply "$destination" allowed
    interrupt_apply "$target" "$control"
    [ "$(docker exec "$target" iptables -S "$chain")" = "$current" ]
    sh "$ctl" "$control" rollback
    [ "$(docker exec "$target" iptables -S "$chain")" = "$prior" ]
    portal
    echo "PASS $control: custom starting rules restored exactly after both applies."
    docker exec "$target" iptables -P "$chain" ACCEPT
    docker exec "$target" iptables -D "$chain" -j ACCEPT
    seed_rule "$target" -D "$chain"
    active=
done
