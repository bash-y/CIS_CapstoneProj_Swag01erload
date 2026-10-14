#!/bin/bash
# docker-net-setup.sh
# Description: Sets up Docker networks to simulate Guest (VLAN 10) and Business (VLAN 20) segmentation.

set -e # Exit immediately if a command exits with a non-zero status.

echo "--- Starting Docker Network Setup ---"

# 1. Create the Guest Network (Simulates Guest VLAN 10)
echo "Creating 'guest-net' network..."
docker network create --driver bridge guest-net

# 2. Create the Business Network (Simulates Business VLAN 20)
echo "Creating 'business-net' network..."
docker network create --driver bridge business-net

echo "--- Network Setup Complete ---"
echo "Networks created: guest-net, business-net"
echo ""
echo "Next Steps:"
echo "1. Run your containers on the 'guest-net' if they represent guest access points."
echo "2. Run your core services (e.g., DVWA, Ubuntu server) on the 'business-net'."
echo "3. To enforce the DENY rule (Guest -> Business), you must configure the external firewall (like pfSense) to block traffic between these subnet IPs."