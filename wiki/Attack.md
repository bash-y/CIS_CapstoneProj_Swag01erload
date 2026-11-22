# Undefended demonstration

## Observations from October 27, 2026

| Scenario | Recorded outcome |
|---|---|
| Guest network discovery | The scan found DVWA (.10), the workstation (.25) and the router (.254) on the Business subnet. DVWA answered on TCP 80 and redirected to login. [baseline validation and follow-up](../evidence/attack/undefended-validation-20261027T055623Z.md) |
| Workstation reachability | All three pings succeeded. Ports 22, 80, 445 and 3389 were closed in the recorded scan. An SMB share listing or authenticated lateral session remains unverified. [baseline validation and follow-up](../evidence/attack/undefended-validation-20261027T055623Z.md) |
| DVWA command injection | The automated sequence returned no command output. A separate authenticated check after database initialization returned the expected file content. The validation record identifies the original command and documents both attempts. [baseline validation and follow-up](../evidence/attack/undefended-validation-20261027T055623Z.md) |
| SQL injection | A separate baseline capture records the query results. The later WAF captures measure how the proxied application responded. [SQL result](../evidence/attack/sqli-run-20261027T060230Z.txt) |

The baseline addresses are internal Docker addresses. DVWA used `192.168.20.10:80`. The business server used `192.168.20.20`. See the [defense matrix](Defense-Test-Matrix.md) for the corresponding controls, checks and evidence gaps.
