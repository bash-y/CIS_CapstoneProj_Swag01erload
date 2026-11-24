# ZAP Active Scan — Before vs Through the WAF (US-21, #132)

> **Owner:** @joromanii. **Status:** runbook + plan authored; **not yet executed** (needs the
> US-19 #130 ZAP runner, still open, and a running lab). No scan results claimed.

## Goal

Run comparable bounded **active** scans against the undefended DVWA path and the defended WAF
path, so we can show **which requests the WAF stops and which application risks remain**. Pairs
with the passive baseline (#131).

## Setup

- Plan: [`configs/zap/dvwa-active-compare.yaml`](../configs/zap/dvwa-active-compare.yaml) — two
  contexts (`dvwa-direct` → `192.168.20.10`, `dvwa-waf` → `192.168.20.15:8080`), one shared
  bounded scan policy, same authenticated user and seed endpoints.
- Credentials: `configs/zap/.env` (gitignored) — synthetic lab account only.
- Lab mode: start the lab and ensure the WAF is in the request path
  (`sh defense/firewall/route-waf-only.sh apply` for the defended run). Record the exact mode.

## Run

```sh
# Shape only — align with the #130 runner.
#   docker exec <zap-runner> zap.sh -cmd -autorun /zap/plans/dvwa-active-compare.yaml
```

This produces four reports: `dvwa-active-direct.{json,html}` and `dvwa-active-waf.{json,html}`.

## Interpret — attribution, not alert count

A lower alert count or an HTTP 403 **alone is not proof**. For each notable finding, classify it:

| Observation (direct → WAF) | Meaning |
|---|---|
| Finding present direct, **403 at WAF with a matched ModSecurity rule** | **WAF-enforced mitigation** (cite the audit-log rule ID — see `Detection-Mapping.md`) |
| Finding gone because the app sanitized it (DVWA hardened) | **application remediation**, not the WAF |
| Finding absent because the endpoint wasn't reached / scanned | **missing coverage** — fix scope, do not credit a defense |
| Scan errored / service down / auth failed | **infrastructure failure (BLOCKED/ERROR)** — not a defense |

Then **manually validate** selected SQLi/command-injection findings with the existing probes
(`scripts/attack/sqli-exploit.sh`, `scripts/attack/dvwa-exploit.sh`) so the comparison rests on
confirmed behavior, not just ZAP's alert list. Confirm a benign request and login still work on
both paths.

## Capture & restore

```sh
sh scripts/capture-evidence.sh test-results zap-active-direct "US-21 active direct" \
   cat /zap/reports/dvwa-active-direct.json    # redact creds/cookies first
sh scripts/capture-evidence.sh test-results zap-active-waf "US-21 active through WAF" \
   cat /zap/reports/dvwa-active-waf.json
```

Record ZAP image digest, add-on versions, scan settings, elapsed time and exit status. Restore
the prior lab mode (`route-waf-only.sh revert`) **without resetting volumes**. Hand sanitized
reports + metadata to #133 (request-to-alert correlation) and #135 (findings report).

## Scope

Local lab only (`192.168.20.10`, `192.168.20.15`). Bounded scan policy and finite timeouts.
Reuses #51 application controls and #128 layer-attribution principles; does not re-count existing
manual verification. Keep credentials/tokens out of committed reports.
