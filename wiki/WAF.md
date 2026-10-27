# Web Application Firewall (WAF)

> Issue #25: *Document WAF*. Status as of 2026-10-27.

## Status: planned, not implemented

The project **has no working WAF**. Nothing in the repository deploys one yet. A WAF is planned as a milestone M3 story, tracked in these issues:

| Issue | Title | Milestone | Assignee |
|---|---|---|---|
| [#7](https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/7) | WAF (ModSecurity+CRS) + verification | M3: Defenses Implemented & Verified | **none** |
| [#23](https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/23) | Add Web Application Firewall (WAF) | none | **none** |
| [#24](https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/24) | Verify WAF capabilities | none | **none** |
| [#25](https://github.com/bash-y/CIS_CapstoneProj_Swag01erload/issues/25) | Document WAF (this page) | none | bash-y |

So this page documents the WAF's status and design. It does not document a working control. Issue #7 defines the acceptance criteria: the WAF proxies to DVWA, the exact SQL injection from #2 returns 403 with no data, and a ModSecurity rule match is logged.

## What protects the web app today

The closest planned control is **application-layer hardening**, US-10 (#51), described in [`wiki/Defense.md`](Defense.md) §3:

- Raise DVWA's security level so input is validated and sanitized.
- Restrict the web management interface to localhost or an authorized admin subnet.

Neither is built. `defense/application-security/` is empty, and the live DVWA is still at `security=low` (the default). The matrix row for this control, row 4 in [`wiki/Defense-Test-Matrix.md`](Defense-Test-Matrix.md), is still planned.

## What a WAF would add

A WAF is a reverse proxy in front of the web app that inspects each HTTP request and blocks known attack patterns, such as SQL injection and command injection, before they reach the application. It is different from US-10. US-10 fixes the application code or its settings; a WAF filters traffic without changing the app.

If the team adds one, it would look like this:

| Part | Choice | Note |
|---|---|---|
| Position | Reverse proxy between Guest and DVWA | Traffic to `192.168.20.10:80` goes through it |
| Engine | ModSecurity with the OWASP Core Rule Set | Common, free, and has rules for both attacks in this lab |
| Mode | Blocking, with logs | Blocked requests are logged, which also meets US-8/US-11 logging |
| Test | Re-run `scripts/attack/sqli-exploit.sh` and the command-injection step through it | Expect 403 and no injected rows or `/etc/passwd` (per #7) |

This would be a new service in `docker/docker-compose.yml`. It is **not** built here.

## Open items

1. **Nobody is assigned to build the WAF.** #7 (M3) has no assignee, and #23 and #24 have none either. The team needs to assign an owner before M3.
2. **#23 and #7 overlap.** #23 is the build and #7 is the build plus verification. One should be closed as a duplicate of the other, which is the team's call.
3. **Matrix row.** The Defense Test Matrix has no WAF row yet. Once #7 is owned, add one that re-runs `scripts/attack/sqli-exploit.sh` through the WAF and expects no injected rows.

Until the WAF is built and verified, no result should be reported as "WAF blocks X."
