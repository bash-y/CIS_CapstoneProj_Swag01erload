# ZAP Automation Plans (US-20 #131 / US-21 #132)

> **Owner:** @joromanii. **Status:** automation plans authored; **not yet executed** — they run
> on the ZAP runner from **US-19 (#130, @bash-y), which is still open**. Runtime-specific
> invocation is pending that runner. No scan results are claimed here.

Version-controlled ZAP Automation Framework plans for scanning the café web app along the
attacker path (Guest VLAN 10 → through the simulated firewall → DVWA `192.168.20.10`, and the
WAF path `192.168.20.15:8080`).

| File | Issue | What it does |
|---|---|---|
| `dvwa-passive-baseline.yaml` | #131 | Authenticated crawl + **passive** analysis (no attacks). Establishes protected-endpoint coverage. |
| `dvwa-active-compare.yaml` | #132 | Bounded **active** scan, run twice: direct DVWA vs through the WAF, for a before/after comparison. |
| `.env.example` | both | Template for the synthetic lab credentials — copy to `.env` (gitignored), never commit real secrets. |

## Credentials stay out of git

The plans reference `${DVWA_USER}` / `${DVWA_PASS}` from the environment. Supply them via
`configs/zap/.env` (copied from `.env.example`), which is gitignored. The values here are DVWA's
default **lab-only** accounts — no real secrets. Redact credentials, cookies and session tokens
from any report before committing it as evidence.

## Anti-CSRF note (verify on the runtime)

DVWA's `login.php` includes a per-request anti-CSRF field, `user_token`. ZAP form authentication
must be configured to extract and resend that token, or login will fail and the crawl will only
see the login page. On the #130 runner, enable ZAP's anti-CSRF handling for `user_token` (ZAP
tracks configured anti-CSRF tokens automatically once the field name is registered). The
`requestor` coverage-guard job in each plan fails the run if an authenticated page is not
reachable, so a silent auth failure is caught rather than passed off as "clean".

## Running (once #130 provides the runner)

```sh
# Shape only — align flags with the #130 runner when it lands.
#   docker exec <zap-runner> zap.sh -cmd -autorun /zap/plans/dvwa-passive-baseline.yaml
# Reports are written to the runner's persistent /zap/reports volume.
```

Capture the HTML/JSON report, endpoint coverage, scan settings, elapsed time, ZAP image digest
and add-on versions, and exit status with `scripts/capture-evidence.sh` (folder `test-results`).
Repeat the passive baseline once to confirm reproducibility (#131 acceptance).

## Scope

Local lab only: DVWA `192.168.20.10` and the WAF `192.168.20.15`. External navigation and
redirects are excluded in each context. This is **not** an active vulnerability scan for #131
(passive only); #132 is the bounded active scan. Neither replaces the purpose-built auth/authz
tests in #109/#110.
