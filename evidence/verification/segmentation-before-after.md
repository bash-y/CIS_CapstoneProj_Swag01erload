# Attack / Defense Verification — Before vs After (Segmentation)

- **Date:** 2026-10-27
- **Host:** macOS 13.7.8, Docker Desktop 4.48.0 (engine 28.5.1)
- **Scope run:** firewall, DVWA, workstation, Kali (+ attempted Suricata). Wazuh SIEM stack intentionally skipped (not used by the attack/verify scripts; too heavy for the 8 GB Docker VM).
- **Defense exercised:** Network segmentation (US-8) via `defense/firewall/enable-segmentation.sh`.

## Before vs After (measured)

| Attack (Guest/Kali 192.168.10.50 → Business) | Before (undefended) | After (segmentation) | Verdict |
|---|---|---|---|
| ICMP ping → DVWA 192.168.20.10 | replies, 0% loss | **100% packet loss** | ✅ blocked |
| ICMP ping → workstation 192.168.20.25 | host up | **100% packet loss** | ✅ blocked |
| TCP/HTTP → DVWA 192.168.20.10:80 | HTTP 302 (Apache 2.4.25) | **connection timed out** (curl -v / nc) | ✅ blocked |
| Nmap enumeration of 192.168.20.0/24 | discovers .10/.25/.254, DVWA:80 open | n/a (traffic dropped) | ✅ |

**Headline result:** the core segmentation control works — after `enable-segmentation.sh`, *all* new Guest→Business traffic (ICMP and TCP) is dropped at the firewall, while the undefended baseline was fully reachable.

## Honest gaps & findings (NOT bash-y's stories — reported, not fixed here)

1. **Suricata service won't start (US-11).** `docker-compose.yml` sets both `hostname:` and `network_mode: "container:swagpc-firewall"` on `suricata` → Docker error: *"conflicting options: hostname and the network mode."* Blocks Test 5 (IDS alerting). Fix: remove the `hostname:` line from the `suricata` service.
2. **Web-exploit attack produces no output (US-7).** `run-full-attack.sh` command-injection step returned empty — it doesn't set DVWA's `security=low` cookie or ensure DVWA DB setup, so the `;cat /etc/passwd` payload doesn't fire. Recon and lateral reachability did work.
3. **`verify-defenses.sh` Test 2 false-negative (US-8/testing).** It uses `curl -s`, which silences the timeout message; the grep check then misreads the empty output as "not blocked" and reports FAIL even though the connection is genuinely blocked (confirmed by `curl -v`/`nc` timing out). Ping tests are unaffected because `ping` always prints "100% packet loss."

## Known BASELINE gaps confirmed live

- **No firewall `LOG` rule** — the segmentation rule is `-j DROP` only, so "denied **and logged**" (US-8 requirement) is not met; no deny log is produced.
- **Suricata custom rules not mounted** — compounds finding #1; even if Suricata started, the SWAGPC signatures wouldn't load.

## Not verified this run

- Suricata/Wazuh detection (Test 5) — blocked by finding #1.
- Application-layer hardening (US-10) and endpoint hardening (US-9) — no controls on `main` yet (US-9 is in open PRs #58/#59, not merged).
