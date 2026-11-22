#!/bin/sh
# zap-init.sh: entrypoint of the swagpc-zap container. US-19 (#130).
# Starts as root with only the capabilities this step needs (CHOWN, NET_ADMIN, SETUID, SETGID, SETPCAP),
# then drops to the unprivileged "zap" user with no capabilities for everything that follows:
#   1. make the persistent report folder writable by zap (a new volume is root-owned)
#   2. add the route to the Business subnet through the firewall (the Guest path), which the image cannot do alone
#   3. idle. Scans are started on purpose with "docker exec" (US-20, US-21). No ZAP API is started or published.
set -eu

BUSINESS_NET="${ZAP_BUSINESS_NET:-192.168.20.0/24}"
FIREWALL_IP="${ZAP_FIREWALL_IP:-192.168.10.254}"

chown zap:zap /zap/wrk
python3 /scripts/zap/add-route.py "$BUSINESS_NET" "$FIREWALL_IP"
echo "swagpc-zap ready: Guest network only, route to $BUSINESS_NET via $FIREWALL_IP, no scan running"
exec setpriv --reuid=zap --regid=zap --init-groups --inh-caps=-all --bounding-set=-all --no-new-privs sleep infinity
