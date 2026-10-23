# Environment Build Guide (100% Docker Architecture)

This document provides complete instructions for standing up the entire **SwagPc Café** capstone environment using Docker.

---

## 1. Prerequisites

* **Docker Desktop:** Version 24+ with Compose v2 enabled.
* **Operating System:** Windows, macOS, or Linux.

---

## 2. Network Topology & Container Map

The lab deploys two isolated Docker bridge networks bridged by a dual-homed firewall/router:

| Container | Hostname | IP Address | Subnet / Role |
|---|---|---|---|
| **swagpc-kali** | `kali` | `192.168.10.50` | **Guest Network (VLAN 10)**: Simulates customer on guest Wi-Fi |
| **swagpc-firewall** | `firewall` | `192.168.10.254` & `192.168.20.254` | **Router / Firewall**: Simulates pfSense routing & packet filtering |
| **swagpc-dvwa** | `dvwa` | `192.168.20.10` | **Business Network (VLAN 20)**: Café web ordering portal |
| **swagpc-workstation**| `workstation` | `192.168.20.25` | **Business Network (VLAN 20)**: Simulated employee PC with orders/records |

---

## 3. Starting the Lab

To launch the complete environment:

```powershell
# Navigate to the docker directory
cd docker

# Start all containers in the background
docker compose up -d
```

### Verifying Container Health
```powershell
docker compose ps
```
You should see all 4 containers in `Up` status.

---

## 4. Execution Workflow

### A. Undefended Attack Phase (Baseline Demonstration)
1. Ensure the firewall is in undefended mode (default on start):
   ```bash
   sh ./defense/firewall/disable-segmentation.sh
   ```
2. Run reconnaissance scan from Kali:
   ```bash
   docker exec -it swagpc-kali /bin/bash /scripts/attack/recon-scan.sh
   ```
3. Run DVWA web exploit from Kali:
   ```bash
   docker exec -it swagpc-kali /bin/bash /scripts/attack/dvwa-exploit.sh
   ```
4. Run lateral movement test toward employee PC:
   ```bash
   docker exec -it swagpc-kali /bin/bash /scripts/attack/lateral-test.sh
   ```
   *(All tests will succeed, confirming the undefended vulnerability).*

### B. Defended Phase (Applying Controls)
1. Apply the firewall segmentation block rule:
   ```bash
   sh ./defense/firewall/enable-segmentation.sh
   ```
2. Re-run the attack scripts from Kali:
   ```bash
   docker exec -it swagpc-kali /bin/bash /scripts/attack/recon-scan.sh
   ```
   *(Packets will drop with 100% loss, confirming defense verification).*
