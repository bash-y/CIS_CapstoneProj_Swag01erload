#!/bin/sh
# disable-segmentation.sh
# Returns firewall to the undefended flat-network state (all forwarding allowed).

echo "=== Disabling Firewall Segmentation (Undefended Baseline) ==="
docker exec swagpc-firewall sh -c "
  iptables -F FORWARD
  iptables -P FORWARD ACCEPT
"

echo "[SUCCESS] Firewall rules flushed. Network is now UNDEFENDED."
docker exec swagpc-firewall iptables -L FORWARD -v -n
