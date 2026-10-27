# Endpoint Hardening — Least Privilege & Password Policy (US-9)

> **User story:** US-9 (#50) — *Windows Workstation & Server Endpoint Hardening* (M3).
> **Subtask (@bash-y):** *Implement local account least-privilege and password policies.*
> Implements the control claimed in [`wiki/Defense.md`](../../wiki/Defense.md) §2.3.

## Goal

The café employee must operate under a **non-privileged local account** with an enforced **password policy**, so that a compromised employee session cannot gain administrative control of the workstation (`swagpc-workstation`, `192.168.20.25`).

## Policy

| Control | Setting | Why |
|---|---|---|
| Employee account | non-privileged `employee`, **not** in `wheel`/`sudo`/`adm` | least privilege — no escalation path |
| Direct root login | **locked** (`passwd -l root`) | no shared root password; admin via controlled channels only |
| Unused accounts | locked (`games`, `ftp`, …) | reduce attack surface |
| Password max age | **90 days** | forced rotation |
| Password min age | 1 day | prevents instant re-cycling to reuse an old password |
| Password warn age | 7 days | user warned before expiry |
| Password min length | **12** | resist brute force |
| Default umask | `027` | new files not readable by "other" |

## File

| File | Purpose |
|---|---|
| `harden-workstation-accounts.sh` | Applies the policy inside `swagpc-workstation` (creates the account, locks root, sets aging). Idempotent. |

Run from the project root with the lab started (`bash lab.sh start`):

```bash
sh defense/endpoint-hardening/harden-workstation-accounts.sh
```

## Simulation note (honest scope)

The "Windows PC" is an **Alpine container**, so controls are applied with `shadow`/`login.defs`. These are **really applied and inspectable** (`id employee`, `chage -l employee`, `passwd -S root`). However:

- **Password *complexity* rules and account *lockout*** need PAM + `pwquality`/`faillock`, which Alpine does not ship by default. This script enforces **length and aging** (what busybox + `shadow` support) and does **not** fake complexity/lockout — those are specified below for the real Windows host.

### Windows equivalent (run as Administrator on the real Windows PC)

```cmd
:: Password policy
net accounts /minpwlen:12 /maxpwage:90 /minpwage:1 /uniquepw:5

:: Account lockout (needs PAM equivalent on Linux)
net accounts /lockoutthreshold:5 /lockoutduration:15 /lockoutwindow:15
```

```powershell
# Complexity + least privilege (Local Security Policy / local groups)
secedit /export /cfg C:\secpol.cfg
(Get-Content C:\secpol.cfg) -replace 'PasswordComplexity = 0','PasswordComplexity = 1' |
  Set-Content C:\secpol.cfg
secedit /configure /db C:\Windows\security\local.sdb /cfg C:\secpol.cfg /areas SECURITYPOLICY

# Employee must be a Standard user, not a local Administrator
Remove-LocalGroupMember -Group "Administrators" -Member "employee" -ErrorAction SilentlyContinue

# Disable the built-in Guest account
Disable-LocalUser -Name "Guest"
```

## Verification

```bash
docker exec swagpc-workstation id employee            # no wheel/sudo groups
docker exec swagpc-workstation chage -l employee      # Max 90, Min 1, Warn 7
docker exec swagpc-workstation passwd -S root         # root: L (locked)
```

**Pass criterion:** `employee` has no admin group membership, password aging shows Max 90 / Min 1 / Warn 7, and root is reported locked (`L`).
