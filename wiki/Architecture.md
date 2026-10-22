# Network Architecture & IP Plan

## 1. Network Topology Overview

The target topology replicates a realistic small business network consisting of two isolated segments separated by a pfSense firewall router.

```text
                                 INTERNET (WAN)
                                       │
                                   [pfSense]
                                       │
                ┌──────────────────────┴──────────────────────┐
                │                                             │
          GUEST NETWORK                                 BUSINESS NETWORK
       VLAN 10 (192.168.10.0/24)                     VLAN 20 (192.168.20.0/24)
                │                                             │
     [Kali Linux Attacker]                           [Ubuntu Business Server]
        (192.168.10.50)                                (192.168.20.10)
                                                              │
                                                        [DVWA Web App]
                                                        (Port 80/8080)
                                                              │
                                                     [Windows Employee PC]
                                                        (192.168.20.25)
                                                              │
                                                     [Wazuh / Monitoring]
```

---

## 2. IP Addressing Scheme

| Host / Interface | Role | Subnet / VLAN | Assigned IP | Notes |
|---|---|---|---|---|
| **pfSense WAN** | Upstream Internet Gateway | WAN | DHCP / Bridged | Outbound NAT |
| **pfSense LAN (Business)** | Gateway for Business Segment | VLAN 20 | `192.168.20.1/24` | Default Gateway for business hosts |
| **pfSense OPT1 (Guest)** | Gateway for Public Wi-Fi | VLAN 10 | `192.168.10.1/24` | Default Gateway for guest clients |
| **Ubuntu Business Server** | Web & Core Services Host | VLAN 20 | `192.168.20.10/24` | Runs Docker / DVWA |
| **Windows Workstation** | Employee Office PC | VLAN 20 | `192.168.20.25/24` | Contains simulated customer orders/records |
| **Kali Linux Attacker** | Untrusted Guest Client | VLAN 10 | `192.168.10.50/24` | Simulates customer on guest Wi-Fi |

---

## 3. Firewall Access Rules

### Undefended State (Baseline Demo)
In the initial baseline, inter-VLAN routing is enabled or flat networking is in place without restrictive rules. Guest hosts are able to communicate directly with business hosts.

### Defended State (Secured Configuration)
Strict firewall rules enforced on the pfSense `GUEST` interface:

| Rule Order | Action | Source | Port | Destination | Port | Description |
|---|---|---|---|---|---|---|
| 1 | **PASS** | Guest Subnet | Any | pfSense Guest IP | 53 (DNS), 67 (DHCP) | Allow local DNS resolution and DHCP |
| 2 | **BLOCK & LOG** | Guest Subnet | Any | Business Subnet | Any | **Deny all guest access into business network** |
| 3 | **BLOCK & LOG** | Guest Subnet | Any | pfSense WebConfig | 80, 443, 22 | Block guest access to firewall management |
| 4 | **PASS** | Guest Subnet | Any | `!RFC1918` (Internet) | Any | Allow isolated internet outbound access |
