# Defense Test Matrix — Verification Criteria & Metrics

> **User story:** US-2 (#43) — *Project Proposal, Topology & Defense Test Matrix* (M1: Proposal Approved).
> **Subtask:** *Define test verification criteria and metrics for each defense* (@bash-y).
> **Companion subtask (@bash-y):** *Draft scenario, brainstorm sentence, and problem statement* — **complete** in [`wiki/Proposal.md`](Proposal.md) §1; the problem statement is restated below for context.
>
> **Status of this document:** This is a **proposal-stage test plan (M1)**. It defines *how each defense will be proven* and the *measurable pass criteria*, so the instructor can sign off on the verification approach before the build. **No test has been executed yet** — every "Status" is a target, not a result. Actual pass/fail evidence is recorded at **M3 (Defenses Implemented & Verified)**.

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
| **1** | **Network segmentation — Guest → Business blocked** (US-8) | [`defense/firewall/enable-segmentation.sh`](../defense/firewall/enable-segmentation.sh) | `nmap -sn 192.168.20.0/24` | **100% packet loss; 0 of 3 business hosts reported "up"** (baseline: ≥2 hosts up) | `evidence/defense/pfsense-drop-log.png` | ⛔ Planned |
| **2** | **Segmentation — business service unreachable** (US-8) | same | `curl -I --max-time 5 http://192.168.20.10:8080` | **Connection times out / RST** within 5 s; **HTTP status = none** (baseline: `HTTP/1.1 200`) | `evidence/defense/firewall-block.png` | ⛔ Planned |
| **3** | **Firewall denial is logged** (US-8 — *"denied **and** logged"*) | same | re-run rows 1–2, then inspect firewall log | **≥1 `DROP`/`DENY` log line** matching `192.168.10.50 -> 192.168.20.0/24` per blocked attempt | `evidence/defense/pfsense-drop-log.png` | ⛔ **Blocked — no `-j LOG` rule exists yet** (see §4) |
| **4** | **Application-layer hardening** (US-10) | `defense/application-security/` *(empty)* | DVWA command injection: `127.0.0.1; cat /etc/passwd` via the exploit path in [`attack/dvwa-exploit.sh`](../attack/dvwa-exploit.sh) | **0 bytes of `/etc/passwd` returned**; response is sanitized **or** HTTP `403` (baseline: file contents returned) | `evidence/defense/dvwa-sanitized.png` | ⛔ **Blocked — control not implemented yet** |
| **5** | **Endpoint hardening — workstation access blocked** (US-9) | `defense/endpoint-hardening/` *(empty)* | `nmap -p 445,139 192.168.20.25` and a direct service probe to the workstation | **Target ports `filtered`/`closed`; connection refused** (baseline: reachable) | `evidence/defense/endpoint-refused.png` | ⛔ **Blocked — not implemented; "Windows PC" is an Alpine container, so `smbclient`/Defender test must be re-scoped (see §4)** |
| **6** | **IDS — Suricata alerts on recon & web attack** (US-11) | [`configs/monitoring/suricata.yaml`](../configs/monitoring/suricata.yaml) + `configs/monitoring/swagpc-custom.rules` | re-run row 1 scan **and** row 4 injection | **≥1 Suricata alert per attack** in `fast.log`, each with attacker IP `192.168.10.50` and a signature name/sid | `evidence/defense/suricata-fast-log.png` | ⚠️ **At risk — custom rules not mounted into the container yet (see §4)** |
| **7** | **SIEM — Wazuh records the alerts** (US-11) | `wazuh` + `dashboard` services | re-run rows 1 & 4 | **Alerts visible in Wazuh dashboard (`127.0.0.1:5601`)** within 60 s, showing timestamp + source IP + rule description | `evidence/defense/wazuh-alerts.png` | ⚠️ **At risk — manager only, no agents on endpoints yet** |

Status legend: ✅ verified at M3 · ⚠️ implemented-with-gap / at risk · ⛔ planned or blocked on implementation.

---

## 4. Implementation gaps that must close before these tests can pass

These are the preconditions for the matrix above, drawn from the verified repository baseline ([`BASELINE.md`](../BASELINE.md)). They are **not** test results — they are work items that gate the tests:

1. **Row 3 (firewall logging).** `enable-segmentation.sh` only `-j DROP`s; there is **no `-j LOG` rule**, so "denied and logged" cannot be proven. A matching `LOG` target must be added before row 3 can pass.
2. **Rows 6 (Suricata).** `suricata.yaml` references `swagpc-custom.rules`, but `docker-compose.yml` mounts only `suricata.yaml` — the custom rule file is **not mounted**, so the SWAGPC signatures won't load. Mount it (or the alerts rely on stock rules only).
3. **Row 5 (endpoint).** The business "Windows workstation" is an **Alpine container**, so Windows Defender Firewall / SMBv1 controls can't be demonstrated as written; the test is re-scoped here to a **port-reachability** check, or requires a real Windows VM.
4. **Row 4 (app hardening) and Row 5 (endpoint).** The `defense/application-security/` and `defense/endpoint-hardening/` directories are **empty** — no control exists to test yet.
5. **All rows.** No container has been built or started; a live `lab.sh start` baseline is the prerequisite for capturing any before/after evidence.

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

*Evidence artifacts are stored under `evidence/defense/` and captured at M3. This document defines the plan; it asserts no result that has not been run.*
