# Endpoint Hardening — Workstation Inbound Firewall (US-9)

> **User story:** US-9 (#50) — *Windows Workstation & Server Endpoint Hardening* (M3).
> **Subtask (@bash-y):** *Configure Windows Defender Firewall rules to restrict incoming connections to authorized subnets.*

## Goal

Restrict **inbound** connections to the employee workstation (`swagpc-workstation`, `192.168.20.25`) so that only the **authorized Business subnet (`192.168.20.0/24`)** can reach it. This is a host-based firewall layered **on top of** the pfSense network segmentation (US-8) — defense-in-depth: even if a packet reaches the endpoint, the host rejects anything not sourced from an authorized subnet, and in particular drops the café **Guest subnet (`192.168.10.0/24`)** where the attacker (`192.168.10.50`) operates.

## Authorized-subnet policy

| Source | Decision | Rationale |
|---|---|---|
| Loopback (`lo`) | **Allow** | Local services / health checks |
| Established/related | **Allow** | Return traffic for connections the workstation initiated |
| Business subnet `192.168.20.0/24` | **Allow** | Authorized business network (server, SIEM, admin) |
| Guest subnet `192.168.10.0/24` | **Drop + log** | Untrusted café guest Wi-Fi — blocks lateral movement |
| Anything else | **Drop + log** (default-deny) | Nothing outside an authorized subnet may connect in |

> To tighten further to specific hosts (e.g. only the business server `192.168.20.10` and Wazuh `192.168.20.100`), replace the `192.168.20.0/24` source with individual `-s <host>` ACCEPT rules.

## Files

| File | Purpose |
|---|---|
| `harden-workstation-firewall.sh` | Apply the inbound restriction (installs `iptables` in the workstation, sets the INPUT chain). |
| `unharden-workstation-firewall.sh` | Revert to the undefended baseline (flush INPUT, default ACCEPT) for before/after demos. |

Run from the project root with the lab already started (`bash lab.sh start`):

```bash
sh defense/endpoint-hardening/harden-workstation-firewall.sh
```

## Simulation note (honest scope)

The project models the "Windows employee PC" with an **Alpine container**, so the firewall is implemented with **iptables** — the Linux equivalent of the Windows Defender Firewall ruleset. The container is granted `NET_ADMIN`, so these rules apply for real and are testable. The equivalent **Windows Defender Firewall** configuration (for a real Windows endpoint) is below; it maps 1:1 to the iptables policy above.

```powershell
# Windows Defender Firewall equivalent (run as Administrator on the real Windows PC)

# Default-deny all inbound
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultInboundAction Block -DefaultOutboundAction Allow

# Allow inbound only from the authorized Business subnet
New-NetFirewallRule -DisplayName "Allow Business Subnet Inbound" `
  -Direction Inbound -Action Allow -RemoteAddress 192.168.20.0/24

# Explicitly block the Guest subnet (café guest Wi-Fi)
New-NetFirewallRule -DisplayName "Block Guest Subnet Inbound" `
  -Direction Inbound -Action Block -RemoteAddress 192.168.10.0/24

# Log dropped inbound packets (denied AND logged)
Set-NetFirewallProfile -Profile Domain,Private,Public `
  -LogBlocked True -LogFileName "%systemroot%\system32\LogFiles\Firewall\pfirewall.log"
```

## Verification (owned by @joromanii per US-9)

With the defense applied, re-run the lateral-movement probe from Kali (`192.168.10.50`):

```bash
# From the attacker on the Guest subnet — expected to be refused/filtered after hardening
docker exec swagpc-kali nmap -Pn -p 445,139,22 192.168.20.25
docker exec swagpc-kali nc -vz -w 3 192.168.20.25 445
```

**Pass criterion:** ports report `filtered`/`closed` and the connection is refused, while the workstation host log shows a `WS-ENDPOINT-DROP-GUEST` entry for `192.168.10.50`. See the Defense Test Matrix (`wiki/Defense-Test-Matrix.md`, row 5) for the measurable metric.
