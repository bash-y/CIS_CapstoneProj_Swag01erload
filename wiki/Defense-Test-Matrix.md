# Defense Test Matrix — Verification Criteria & Metrics

> **User story:** US-2 (#43) — *Project Proposal, Topology & Defense Test Matrix* (M1: Proposal Approved).
> **Subtask:** *Define test verification criteria and metrics for each defense* (@bash-y).
> **Companion subtask (@bash-y):** *Draft scenario, brainstorm sentence, and problem statement* — **complete** in [`wiki/Proposal.md`](Proposal.md) §1; the problem statement is restated below for context.
>
> **Status of this document:** Started as a **proposal-stage test plan (M1)** defining *how each defense will be proven* and the *measurable pass criteria*. **Update 2026-10-27:** the first live run has been executed — **network segmentation (US-8) is now verified** (rows 1–2), with evidence under [`evidence/verification/`](../evidence/verification/). The remaining rows are still targets (planned or blocked on implementation), not results. See §4 for live-run findings.

---

## 1. Problem statement (context)

SwagPc Café runs free guest Wi-Fi on the **same flat network** as its employee workstation and Linux business server. With no segmentation, a guest-network attacker can enumerate internal hosts, exploit the café web application (DVWA), and pivot to business resources. The project replicates this flat-network café, demonstrates the attack on the undefended baseline, then applies four defenses and **re-runs each attack to prove it is blocked, denied, or alerted** — with captured logs and screenshots as evidence.

- **Authorized scope (unchanged):** the two local Docker subnets only — Guest `192.168.10.0/24` and Business `192.168.20.0/24`, defined in [`docker/docker-compose.yml`](../docker/docker-compose.yml). No public or out-of-scope targets.
- **Attacker position:** `swagpc-kali` on the Guest network (`192.168.10.50`).

---

## 2. Verification principle

Each defense is verified by **replaying the identical attack command** used against the undefended baseline and measuring the outcome against a **quantitative pass metric**. A defense is "Verified" only when the measured metric meets its threshold **and** a dated evidence artifact is captured. A before/after pair (baseline result vs. post-defense result) is required for every row.

---

## 3. Defense Test Matrix

| # | Defense (story) | Implemented in | Repeat-attack command (from Guest / Kali `192.168.10.50`) | Measurable pass criterion / metric | Evidence artifact | Status |
|---|---|---|---|---|---|---|
| **1** | **Network segmentation — Guest → Business blocked** (US-8) | [`defense/firewall/enable-segmentation.sh`](../defense/firewall/enable-segmentation.sh) | `ping`/`nmap` 192.168.20.10 & .25 from Kali | **100% packet loss to business hosts** (baseline: replies, 0% loss) | [`evidence/verification/segmentation-before-after.md`](../evidence/verification/segmentation-before-after.md) | ✅ **Verified 2026-10-27** — before: ping replies / hosts up; after: **100% packet loss** to .10 and .25 |
| **2** | **Segmentation — business service unreachable** (US-8) | same | `curl --max-time 4 http://192.168.20.10/` and `nc -z 192.168.20.10 80` from Kali | **Connection times out / RST**; **no HTTP status** (baseline: `HTTP/1.1 302`, Apache 2.4.25) | [`evidence/verification/segmentation-ground-truth.txt`](../evidence/verification/segmentation-ground-truth.txt) | ✅ **Verified 2026-10-27** — before: HTTP 302; after: **connection timed out** (curl -v & nc) |
| **3** | **Firewall denial is logged** (US-8 — *"denied **and** logged"*) | same | re-run rows 1–2, then inspect firewall log | **≥1 `DROP`/`DENY` log line** matching `192.168.10.50 -> 192.168.20.0/24` per blocked attempt | `evidence/defense/pfsense-drop-log.png` | ⛔ **Blocked — no `-j LOG` rule exists yet** (see §4) |
| **4** | **Application-layer hardening** (US-10) | `defense/application-security/` *(empty)* | DVWA command injection: `127.0.0.1; cat /etc/passwd` via the exploit path in [`attack/dvwa-exploit.sh`](../attack/dvwa-exploit.sh) | **0 bytes of `/etc/passwd` returned**; response is sanitized **or** HTTP `403` (baseline: file contents returned) | `evidence/defense/dvwa-sanitized.png` | ⛔ **Blocked — control not implemented yet** |
| **5** | **Endpoint hardening — workstation access blocked** (US-9) | `defense/endpoint-hardening/` *(empty)* | `nmap -p 445,139 192.168.20.25` and a direct service probe to the workstation | **Target ports `filtered`/`closed`; connection refused** (baseline: reachable) | `evidence/defense/endpoint-refused.png` | ⛔ **Blocked — not implemented; "Windows PC" is an Alpine container, so `smbclient`/Defender test must be re-scoped (see §4)** |
| **4b** | **WAF in front of DVWA** (US-10, #7) | `docker/docker-compose.yml` (`waf` service, `192.168.20.15`); routing in `defense/firewall/route-waf-only.sh` | `sh scripts/attack/sqli-exploit.sh` run through the WAF (`http://192.168.20.15:8080`), and `curl` command injection through the WAF | **Blocked (403) with 0 rows and no `/etc/passwd`**; benign lookup passes (200). Baseline: rows and `/etc/passwd` returned | `evidence/defense/waf-routed-verify-*.txt` (PR #75), `evidence/defense/waf-audit-matches-*.txt` (PR #73) | ✅ **Verified 2026-10-27**: 8 passed, 0 failed (`scripts/testing/verify-waf.sh`) |
| **6** | **IDS — Suricata alerts on recon & web attack** (US-11) | [`configs/monitoring/suricata.yaml`](../configs/monitoring/suricata.yaml) + `configs/monitoring/swagpc-custom.rules` | re-run row 1 scan **and** row 4 injection | **≥1 Suricata alert per attack** in `fast.log`, each with attacker IP `192.168.10.50` and a signature name/sid | `evidence/defense/suricata-fast-log.png` | ⚠️ **At risk — custom rules not mounted into the container yet (see §4)** |
| **7** | **SIEM — Wazuh records the alerts** (US-11) | `wazuh` + `dashboard` services | re-run rows 1 & 4 | **Alerts visible in Wazuh dashboard (`127.0.0.1:5601`)** within 60 s, showing timestamp + source IP + rule description | `evidence/defense/wazuh-alerts.png` | ⚠️ **At risk — manager only, no agents on endpoints yet** |

Status legend: ✅ verified · ⚠️ implemented-with-gap / at risk · ⛔ planned or blocked on implementation.

---

## 4. Implementation gaps that must close before these tests can pass

These are the preconditions for the matrix above, drawn from the verified repository baseline ([`BASELINE.md`](../BASELINE.md)). They are **not** test results — they are work items that gate the tests:

1. **Row 3 (firewall logging).** `enable-segmentation.sh` only `-j DROP`s; there is **no `-j LOG` rule**, so "denied and logged" cannot be proven. A matching `LOG` target must be added before row 3 can pass.
2. **Rows 6 (Suricata).** `suricata.yaml` references `swagpc-custom.rules`, but `docker-compose.yml` mounts only `suricata.yaml` — the custom rule file is **not mounted**, so the SWAGPC signatures won't load. Mount it (or the alerts rely on stock rules only).
3. **Row 5 (endpoint).** The business "Windows workstation" is an **Alpine container**, so Windows Defender Firewall / SMBv1 controls can't be demonstrated as written; the test is re-scoped here to a **port-reachability** check, or requires a real Windows VM.
4. **Row 4 (app hardening) and Row 5 (endpoint).** The `defense/application-security/` and `defense/endpoint-hardening/` directories are **empty** — no control exists to test yet.
5. **Live baseline captured for segmentation.** The first live run (2026-10-27, Docker Desktop 4.48.0 / engine 28.5.1) established the before/after for rows 1–2. Rows 3–7 remain gated on the items above and the findings below.

### Live-run findings (2026-10-27)

These surfaced when running the full attack → defend → verify cycle. They are in other members' stories and are **reported, not fixed here**:

- **L1 — Suricata service won't start (US-11).** `docker-compose.yml` sets both `hostname:` and `network_mode: "container:swagpc-firewall"` on the `suricata` service → Docker error *"conflicting options: hostname and the network mode."* Blocks rows 6–7. Fix: drop the `hostname:` line from that service.
- **L2 — Web-exploit attack produces no output (US-7).** `scripts/attack/run-full-attack.sh` command-injection step returns empty; it never sets DVWA's `security=low` cookie or ensures DVWA DB setup, so the payload doesn't fire. Row 4's baseline (`/etc/passwd` returned) could not be demonstrated.
- **L3 — `verify-defenses.sh` Test 2 false-negative (US-8/testing).** It uses `curl -s`, which silences the timeout; the grep check then misreads empty output as "not blocked" and reports FAIL even when traffic *is* blocked. Confirmed blocked by `curl -v`/`nc` (see `evidence/verification/segmentation-ground-truth.txt`). The ping-based tests are unaffected.

Raw captures: [`evidence/verification/`](../evidence/verification/) — `attack-undefended.txt` (before), `verify-defenses-after.txt` (after suite), `segmentation-ground-truth.txt`, and `segmentation-before-after.md` (summary).

---

## 5. Metric summary (acceptance thresholds)

| Dimension | Baseline (undefended) | Target (defended) | How measured |
|---|---|---|---|
| Business-host reachability from Guest | ≥2 hosts up, 0% loss | **0 hosts up, 100% loss** | `nmap -sn` host count |
| Café web service from Guest | `HTTP 200` | **timeout / no HTTP status** | `curl -I --max-time 5` |
| Command-injection data exfiltration | `/etc/passwd` returned | **0 bytes / 403 / sanitized** | response body inspection |
| Firewall denial logging | 0 log lines | **≥1 log line per blocked attempt** | firewall log grep |
| Detection latency (attack → alert) | no alert | **alert within 60 s** | Suricata `fast.log` / Wazuh timestamp |

---

*Segmentation evidence is under [`evidence/verification/`](../evidence/verification/) (captured 2026-10-27); remaining-defense evidence lands under `evidence/defense/` at M3. Verified rows assert only measured results; planned/blocked rows assert nothing that has not been run.*
