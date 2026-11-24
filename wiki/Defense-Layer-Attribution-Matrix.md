# Defense Layer Attribution Matrix (US-18, #128)

> **Owner:** @joromanii. **Milestone:** M3. **Status:** **test definition / plan — no runtime
> results claimed.** This defines *how* each defense layer is tested in isolation and in
> combination, and how we prove which layer actually handled a request. Running it needs the live
> Docker lab; capture results with `scripts/capture-evidence.sh` and the `lab-verify` skill, then
> fill the Result column and update [`Defense-Test-Matrix.md`](Defense-Test-Matrix.md) and
> [`Testing-and-Verification.md`](Testing-and-Verification.md).

## Purpose

Prove each control on its own merit so that **a network denial is never mistaken for a working
application or endpoint control** (and vice versa). Every row names the exact source, route, and
active controls, and — crucially — **the layer's own log/counter that proves it did the blocking**.

## Principle: attribution, not just outcome

A blocked request (timeout, 403, filtered port, or a lower alert count) is **not** proof on its
own. For each defended row we require:

1. The **intended layer's own evidence** (its log line or counter) shows it handled the request.
2. The **route stays reachable** when testing an application/endpoint control, so a segmentation
   block cannot masquerade as an app fix.
3. A **benign/allowed request** in the same run still succeeds (no false "everything blocked").
4. Infrastructure failures (service down, CSRF/DB error, missing endpoint) are recorded as
   **BLOCKED/ERROR**, never counted as a successful defense.

## Lab modes used per row

| Mode | How to set | Active controls |
|---|---|---|
| Baseline | `bash lab.sh undefend` | none |
| Segmentation-only | `bash lab.sh defend` (iptables FORWARD drop) | network segmentation (US-8) |
| WAF/application-only | baseline network + `sh defense/firewall/route-waf-only.sh apply` + `sh defense/application-security/harden-dvwa-security-level.sh apply` | WAF + DVWA hardening (US-10) |
| Endpoint-only | baseline network + `sh defense/endpoint-hardening/harden-workstation-firewall.sh` | workstation host firewall (US-9) |
| Combined | segmentation + WAF/app + endpoint all applied | all |

> Restore the prior mode after testing (`lab.sh undefend`, `route-waf-only.sh revert`,
> `harden-dvwa-security-level.sh revert`, `unharden-workstation-firewall.sh`) **without**
> resetting volumes.

## The matrix

Attacker is `swagpc-kali` (`192.168.10.50`, Guest) unless noted. Each probe is bounded and uses
synthetic data.

| # | Layer under test | Source → dest (route) | Bounded probe | Expected outcome | **Attribution evidence (proves THIS layer)** | Result |
|---|---|---|---|---|---|---|
| B | Baseline | Kali → DVWA `192.168.20.10`, workstation `.25` | `recon-scan.sh`; `dvwa-exploit.sh`; `sqli-exploit.sh` | hosts reachable; `/etc/passwd` + SQL rows returned | n/a (shows exposure) | _pending_ |
| S | Segmentation-only | Kali → Business `192.168.20.0/24` | `bash scripts/testing/verify-defenses.sh` | 100% packet loss / connection timeout to `.10`,`.25` | firewall `FW-DROP-GUEST` log line + FORWARD DROP counter rising for `192.168.10.50` | _pending_ |
| W | WAF/app-only (route reachable) | Kali → WAF `192.168.20.15:8080` → DVWA | `sqli-exploit.sh` and cmd-injection **through the WAF**; benign lookup | malicious → 403; **benign → 200**; at DVWA-hardened level payload sanitized | ModSecurity audit log 403 with matched rule IDs (see `Detection-Mapping.md`); DVWA response sanitized while host is pingable | _pending_ |
| E | Endpoint-only | Kali → workstation `192.168.20.25` (route up) | `nmap -Pn -p 22,445 192.168.20.25`; `nc -vz 192.168.20.25 445` | ports filtered / connection refused while host is routable | workstation `WS-ENDPOINT-DROP-GUEST` INPUT drop log for `192.168.10.50` | _pending_ |
| A | Allowed-flow control | workstation/employee → business-server | `sh scripts/testing/verify-workstation-to-server.sh` | authorized op **succeeds** under every defended mode | success output + server access log entry | _pending_ |
| C | Combined | Kali → all; plus benign + allowed-flow | all probes above in one run | each attack blocked **by its own layer**; benign + allowed-flow still work | each layer's evidence present and attributed to the right control | _pending_ |

## How to run and capture

Use the evidence helper so each result is dated and self-describing:

```sh
# Example: segmentation-only row
bash lab.sh defend
sh scripts/capture-evidence.sh verification seg-only "US-18 segmentation-only" \
   bash scripts/testing/verify-defenses.sh
# then inspect the firewall's own log for attribution
sh scripts/capture-evidence.sh verification seg-only-fwlog "US-18 segmentation drop log" \
   docker exec swagpc-firewall dmesg
```

Repeat per row, capturing both the **probe result** and the **attribution log/counter**. Keep a
timestamped index (commit, mode, command, expected vs actual, attributed control) as #128 requires.

## Acceptance (when this can be marked verified)

- Every row has a dated probe artifact **and** its attribution evidence.
- No row relies on outcome alone; each defended block is tied to its own layer's log/counter.
- Benign (row W) and allowed-flow (row A) pass under the defended modes.
- Combined run shows no cross-attribution (e.g. a segmentation drop is not credited to the WAF).
- `Defense-Test-Matrix.md` and `Testing-and-Verification.md` updated from the captured evidence.

## Scope

Local SwagPc Café lab only (Guest `192.168.10.0/24`, Business `192.168.20.0/24`, and
`192.168.30.0/24` in the segmented layout). No public targets, no volume resets, no host security
changes. Alpine stand-ins for the Windows PC and pfSense are labeled as simulations. This file
reuses the existing controls (#50 endpoint, #51 application, segmentation, WAF) and adds only
cross-layer attribution — it does not reimplement them, and #109/#110 keep their own criteria.
