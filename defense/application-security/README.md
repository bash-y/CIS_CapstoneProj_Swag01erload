# Application Security — DVWA Hardening (US-10)

> **User story:** US-10 (#51) — *Web Application Security Hardening* (M3).
> **Subtask (@joromanii):** *Harden DVWA security settings (increase security level / input sanitization).*

## Goal

Mitigate the web-application exploits demonstrated in the attack phase (SQL injection and
command injection against the café web portal, `swagpc-dvwa`, `192.168.20.10`) by enforcing
**input sanitization** at the application layer. This is the app-layer control in the
defense-in-depth stack, layered on top of network segmentation (US-8) and the WAF path control.

## How DVWA security levels map to the defense

DVWA exposes four levels. They model increasingly strong application-security coding practices:

| Level | Coding practice modeled | Effect on our payloads |
|---|---|---|
| **Low** | No validation; input concatenated into SQL / shell | `1' OR '1'='1`, `UNION SELECT`, `;cat /etc/passwd` all succeed |
| **Medium** | Weak blocklist filtering | Some payloads blocked, bypasses exist |
| **High** | Stronger filtering / tokens | Most trivial payloads blocked |
| **Impossible** | **Prepared statements + strict validation** | Injection returns no data — the correct fix |

We run the **undefended baseline at Low** and harden to **Impossible** to show mitigation.

## Files

| File | Purpose |
|---|---|
| `harden-dvwa-security-level.sh` | `apply` sets the default security level to **impossible**; `revert` sets it back to **low**; `status` prints the current level. |

Run from the project root with the lab started (`bash lab.sh start`):

```bash
sh defense/application-security/harden-dvwa-security-level.sh apply
```

## Honest scope

DVWA's **live** security level is stored in a per-session cookie, so this script hardens the
**default** level that new sessions start from (via `default_security_level` in the container's
`config/config.inc.php`). An attacker with a direct path to DVWA could still set their own cookie
back to `low`. That is why this control is paired with the WAF path restriction
(`defense/firewall/route-waf-only.sh`), which forces Guest traffic through the WAF instead of
reaching DVWA directly. Together they represent the realistic app-layer defense: fix the
application's default behavior **and** restrict who can reach the raw app.

The script edits the DVWA container config to match the repo's apply/revert defense pattern. It
has not been executed in the authoring environment — run it against the live lab to verify.

## Verification (owned by @UiwAntHuynhCIS per US-10)

With the defense applied, re-run the web-exploit payloads from Kali (`192.168.10.50`):

```bash
# SQL injection — expected: no user rows returned after hardening
docker exec swagpc-kali bash /scripts/attack/sqli-exploit.sh

# Command injection step of the full attack — expected: no /etc/passwd contents
docker exec swagpc-kali bash /scripts/attack/run-full-attack.sh
```

**Pass criterion:** the injection payloads return sanitized output or no rows (HTTP 403 when the
WAF path control is also active), compared against the undefended baseline evidence in
`evidence/attack/`.
