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
     [Kali Linux Attacker]                           [WAF (ModSecurity)]
        (192.168.10.50)                                (192.168.20.15)
                                                              │
                                                        [DVWA Web App]
                                                        (192.168.20.10)
                                                              │
                                                 [Ubuntu Business Server]
                                                        (192.168.20.20)
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
| **Firewall (Business Interface)** | `swagpc-firewall` | VLAN 20 (`business-net`) | `192.168.20.254/24` | Gateway / Router for business hosts |
| **Firewall (Guest Interface)** | `swagpc-firewall` | VLAN 10 (`guest-net`) | `192.168.10.254/24` | Gateway / Router for guest clients |
| **WAF (reverse proxy)** | `swagpc-waf` | VLAN 20 (`business-net`) | `192.168.20.15/24` | ModSecurity + OWASP CRS in front of DVWA (port 8080) |
| **Business Web App (DVWA)** | `swagpc-dvwa` | VLAN 20 (`business-net`) | `192.168.20.10/24` | Café web app (port 80). Reachable only through the WAF once routing is applied |
| **Ubuntu Business Server** | `swagpc-business-server` | VLAN 20 (`business-net`) | `192.168.20.20/24` | Internal operations portal (port 80) |
| **Wazuh manager** | `swagpc-wazuh` | VLAN 20 (`business-net`) | `192.168.20.100/24` | SIEM manager (syslog 1514/udp, API 55000) |
| **Wazuh dashboard** | `swagpc-dashboard` | VLAN 20 (`business-net`) | `192.168.20.101/24` | SIEM web UI (port 5601, localhost only) |
| **Employee Workstation** | `swagpc-workstation` | VLAN 20 (`business-net`) | `192.168.20.25/24` | Contains simulated customer orders/records |
| **Kali Linux Attacker** | `swagpc-kali` | VLAN 10 (`guest-net`) | `192.168.10.50/24` | Simulates customer on guest Wi-Fi |


### Routing table

| Where | Destination | Next hop | Purpose |
|---|---|---|---|
| Kali (`swagpc-kali`) | `192.168.20.0/24` | `192.168.10.254` (firewall) | Reach the Business network through the router |
| Firewall (`swagpc-firewall`) | `192.168.10.0/24`, `192.168.20.0/24` | Connected | Forwards between the two networks (`ip_forward=1`) |

The workstation and business hosts sit on the Business subnet, so they reach each other directly without the firewall.

### Platform coverage for US-3

| Planned requirement | Implementation in the repository | Evidence needed for platform-specific credit |
|---|---|---|
| pfSense with WAN, Guest and Business interfaces | `docker/docker-compose.yml` configures an Alpine router on two networks. `defense/firewall/` contains its iptables policies. | A pfSense VM with interface assignments, the applied rules and traffic observations on the relevant interfaces. |
| Guest VLAN 10 and Business VLAN 20 | The base Compose file defines separate Docker bridges for the Guest and Business subnets. The subnet numbers identify the intended segments. | VLAN interface or switch configuration and evidence of 802.1Q tags if the rubric requires tagged VLANs. |
| Windows workstation hardening | The Compose workstation runs Alpine. `defense/endpoint-hardening/README.md` documents the Linux firewall policy and a proposed Windows Defender Firewall configuration. | A Windows endpoint with the applied policy and recorded results for allowed and denied connections. |

Instructor acceptance remains unresolved. Issues #44, #81 and #103 contain no approval in their comment histories. Record the instructor’s decision and applicable rubric criterion in #103. If native platforms are required, capture the evidence in the last column.

---

## 3. Firewall Access Rules

### Undefended State (Baseline Demo)
In the initial baseline, inter-VLAN routing is enabled or flat networking is in place without restrictive rules. Guest hosts are able to communicate directly with business hosts.

### Defended State (Secured Configuration)
The following table describes the planned pfSense Guest policy. The Docker router has no WAN interface.

| Rule Order | Action | Source | Port | Destination | Port | Description |
|---|---|---|---|---|---|---|
| 1 | **PASS** | Guest Subnet | Any | pfSense Guest IP | 53 (DNS), 67 (DHCP) | Allow local DNS resolution and DHCP |
| 2 | **BLOCK & LOG** | Guest Subnet | Any | Business Subnet | Any | **Deny all guest access into business network** |
| 3 | **BLOCK & LOG** | Guest Subnet | Any | pfSense WebConfig | 80, 443, 22 | Block guest access to firewall management |
| 4 | **PASS** | Guest Subnet | Any | `!RFC1918` (Internet) | Any | Allow isolated internet outbound access |
