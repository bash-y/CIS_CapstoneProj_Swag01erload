# Web Application Firewall (WAF)

> Issue #25: *Document WAF*. Status as of 2026-10-27.

## Status: not implemented

The project has **no web application firewall**. Nothing in the repository deploys one, configures one, or mentions one as part of the design. A search of the repo for `WAF`, `web application firewall` and `ModSecurity` finds no references.

So this page does not document a working WAF. It records what the project does instead, and what a WAF would involve, so the team can decide whether to add one.

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
| Test | Re-run `scripts/attack/sqli-exploit.sh` and the command-injection step through it | Expect no injected rows and no `/etc/passwd` |

This would be a new service in `docker/docker-compose.yml`. It is **not** built here.

## Decision needed

The WAF is not in the course plan or the milestone scope. Before M3, the team should choose one of:

1. **Drop the WAF from scope.** Document that web-layer protection is the US-10 input validation and access restriction, and leave this page as the record of the decision.
2. **Add a WAF as an extension.** Build the reverse-proxy service above and add a matrix row for it. This adds work to M3.

Until that decision is made, the WAF is not a control the project relies on, and no result should be reported as "WAF blocks X."
