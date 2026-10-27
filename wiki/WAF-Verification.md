# WAF: Build and Verification

> Issues #23 (build the WAF), #24 (verify its capabilities), and the acceptance criteria of #7 (M3).
> Verified live on 2026-10-27 (Docker Desktop 4.48.0, macOS 13.7.8). Design background is in `wiki/WAF.md` (PR #72).

## What was built

A **ModSecurity + OWASP Core Rule Set** reverse proxy, `swagpc-waf`, in front of DVWA.

| Part | Setting |
|---|---|
| Image | `owasp/modsecurity-crs:nginx` (pinned to the image's default tag) |
| Address | `192.168.20.15` on the Business network |
| Backend | `BACKEND=http://dvwa:80` (DVWA stays at `192.168.20.10`) |
| Mode | Blocking, anomaly threshold 5 (image default), paranoia level 1 (image default) |
| Host access | `127.0.0.1:8081` only |
| Audit log | JSON to the container's stdout (`docker logs swagpc-waf`) |

It is defined in [`docker/docker-compose.yml`](../docker/docker-compose.yml). DVWA's own address is unchanged, so the undefended baseline and every script that targets `192.168.20.10` still work.

## Verification

Run from Kali, with requests going through the WAF at `192.168.20.15`: [`scripts/testing/verify-waf.sh`](../scripts/testing/verify-waf.sh).

| # | Check | Result |
|---|---|---|
| 1 | Login through the WAF is proxied to DVWA (302) and creates a session | **PASS** |
| 2 | Normal lookup `id=1` passes (200, one row). No false positive | **PASS** |
| 3 | UNION SQL injection from #2 is blocked: 403, 0 rows returned | **PASS** |
| 4 | Command injection `ip=127.0.0.1;cat /etc/passwd` is blocked: 403, no `/etc/passwd` | **PASS** |
| 5 | Rule matches are logged, including SQLi rule `942100` and command-injection rule `932160` | **PASS** |
| 6 | DVWA is reachable directly on `192.168.20.10`, bypassing the WAF | **KNOWN GAP** |

**Result: 7 passed, 0 failed, 1 known gap.** Output: [`evidence/defense/waf-verify-20261027T133314Z.txt`](../evidence/defense/waf-verify-20261027T133314Z.txt).

### Rules that fired

Taken from the WAF's JSON audit log, saved in [`evidence/defense/waf-audit-matches-20261027T133314Z.txt`](../evidence/defense/waf-audit-matches-20261027T133314Z.txt):

| Rule ID | Category | Matched on |
|---|---|---|
| `942100` | SQL injection (libinjection) | UNION SQLi |
| `942190` | SQL code execution and information gathering | UNION SQLi |
| `942270` | Basic SQL injection patterns | UNION SQLi |
| `942360` | Concatenated SQL injection | UNION SQLi |
| `932160` | Remote command execution, Unix shell | Command injection |
| `930120` | OS file access (`/etc/passwd`) | Command injection |
| `949110` | Inbound anomaly score exceeded. This is the rule that blocks the request | Both attacks |
| `920350` | Host header is a numeric IP address. Informational, fires on every request | All requests |

A blocked request logs `Access denied with code 403 (phase 2)`. Six such entries appear across the attacks run during this verification.

## Known gap: the WAF can be bypassed

Nothing stops a Guest host from talking to DVWA directly on `192.168.20.10:80`. In the check, a direct UNION SQL injection returned 200 with the user table, so the WAF was skipped entirely.

This is a **segmentation** problem, not a WAF problem. Fixing it means the firewall must allow Guest traffic only to the WAF's address (`192.168.20.15:8080`) and drop Guest traffic to DVWA. That is #7's task "Route attacker -> WAF -> DVWA". Until it is done, the WAF is an option, not an enforced control, and no result should be reported as "the WAF protects DVWA."

## Open items

1. **Route Guest traffic through the WAF only.** Add firewall rules in `defense/firewall/` so Guest reaches `192.168.20.15:8080` but not `192.168.20.10`. Owner: #7.
2. **Defense Test Matrix row.** Add a WAF row, re-running `scripts/attack/sqli-exploit.sh` through the WAF and expecting 403.
3. **Duplicate issues.** #23 (build) and #7 (build and verify) overlap. Close one as a duplicate; #24 covers verification.

## Reproduce

```bash
docker compose -f docker/docker-compose.yml up -d firewall dvwa kali waf
bash scripts/testing/verify-waf.sh
docker logs swagpc-waf 2>&1 | grep '"ruleId"'
```
