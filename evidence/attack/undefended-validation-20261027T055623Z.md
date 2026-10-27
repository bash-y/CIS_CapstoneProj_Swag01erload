# Undefended attack sequence: validation (issue #3)

- **Run:** 20261027T055623Z (UTC)
- **Host:** macOS 13.7.8, Docker Desktop 4.48.0 (engine 28.5.1)
- **Command:** `docker exec swagpc-kali bash /scripts/attack/run-full-attack.sh`
- **Raw output:** `undefended-run-20261027T055623Z.txt` (same folder)
- **Pre-check:** firewall FORWARD policy ACCEPT, no DROP rules. Kali reached DVWA (HTTP 302) and the workstation (ping 0% loss).

## Per-step result

| Step | Check | Result | Evidence |
|---|---|---|---|
| Recon | Ping DVWA (.10) | PASS: 3/3 replies | raw output |
| Recon | Ping workstation (.25) | PASS: 3/3 replies | raw output |
| Recon | Nmap sweep of 192.168.20.0/24 | PASS: .10, .25, .254 up; port 80 open on .10 | raw output |
| Web | HTTP reachability to DVWA | PASS: HTTP 302 to login | raw output |
| Web | Command injection `ip=127.0.0.1;cat /etc/passwd` | **FAIL: no output.** Login redirects to `setup.php`, so the DVWA database is not initialized (see below) | raw output; diagnostic below |
| Lateral | Ping workstation | PASS: 3/3 replies | raw output |
| Lateral | Nmap of workstation ports 22, 80, 445, 3389 | Host up. All four ports **closed** (no listener), not open | raw output |

## Command-injection diagnostic

- The DVWA response sets `security=low`. The security level is **not** the problem.
- A logged-in test (CSRF token extracted correctly) still redirects to `setup.php`. The page reads "database already exists", but login is blocked, which points to an uninitialized or partial database.
- The fix is to run DVWA's own "Create / Reset Database" step once in the lab. We did not run it here, because it changes the lab state.
- Issue #63 suggested the security cookie was the cause. That was wrong: the cookie is already low. The database setup is the likely fix, and #63 should be updated.

## Corrections to `wiki/Attack.md`

- The workstation has **no open SMB port** on the lab build. Port 445 is closed, not open, so the Attack 1 claim does not hold. This matches discrepancy 3 in issue #2.
- DVWA is at `192.168.20.10`, port 80 on the lab network.

## Verdict

Recon, web reachability and lateral ping are validated on the undefended build. Command injection is **not validated**: the step runs but returns nothing because the DVWA database is not initialized.

## Update: command injection validated after DVWA database reset

- Ran DVWA's own "Create / Reset Database" step once in the lab (`setup.php`, POST `create_db`). It returned 302.
- Login with `admin` / `password` then succeeded (302 to `index.php`, logout link present).
- Same payload as the attack script, `ip=127.0.0.1;cat+/etc/passwd`, from the logged-in session returned HTTP 200 with `root:x:0:0:root:/root:/bin/bash` in the response.
- **Result: PASS.** Command injection works on the undefended build once the database is initialized.
- **Gap that remains:** `run-full-attack.sh` does not reset the database or log in with the DVWA token, so on a fresh lab its web step will still return nothing. Fix this in US-7 (#48), or add the reset as a lab setup step.
