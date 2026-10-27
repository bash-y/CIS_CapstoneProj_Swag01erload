# US-9 (#50) Endpoint Hardening — Live Verification (Before vs After)

- **Date:** 2026-10-27
- **Host:** macOS 13.7.8, Docker Desktop 4.48.0 (engine 28.5.1)
- **Scope:** firewall (undefended routing), workstation (192.168.20.25), Kali attacker (192.168.10.50)
- **Controls tested:** `defense/endpoint-hardening/harden-workstation-firewall.sh` (PR #58) and `harden-workstation-accounts.sh` (PR #59)

## Subtask 1 — host inbound firewall (restrict to authorized subnets)

| Check (Kali 192.168.10.50 → workstation .25) | Before | After |
|---|---|---|
| ICMP ping | 3/3 replies, **0% loss** | **100% packet loss** |
| TCP connect (:22) | reachable (host up) | **connection timed out** |
| Workstation INPUT chain | none (default ACCEPT) | allow lo/established/business; **LOG+DROP guest**; default-deny+log |

**Denied AND logged:** after the attack, the workstation's guest rules show **LOG matched 6 packets / DROP dropped 6** — the endpoint firewall both blocks and logs guest traffic. (The business subnet 192.168.20.0/24 remains allowed.)

## Subtask 2 — least-privilege & password policy

- `employee` account: `uid=1000(employee) groups=1000(employee)` — **no wheel/sudo/adm** (no escalation path).
- Password aging: **max 90 days / min 1 / warn 7**, min length 12 (login.defs).
- **root login Locked** (`passwd -S root` → `root L`).

## Result
Both US-9 @bash-y subtasks verified live: unauthorized (guest) access to the workstation is blocked and logged, authorized business-subnet access is preserved, and the employee operates under a non-privileged, password-policied account with root locked.
