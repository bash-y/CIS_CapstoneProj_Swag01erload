# Live Verification Runbook — Attack & Defense Evidence (joromanii US-5/6/7/10/11)

> **Owner:** @joromanii (Security-Documentation Lead).
> **Purpose:** the exact commands to run **on a machine with Docker** to capture the
> before/after evidence for my issues. Everything here needs the live lab; it is the
> checklist to work through once `lab.sh start` is available.
> **Scope:** US-5 (#46), US-6 (#47), US-7 (#48, #63), US-10 (#51, #109, #110), US-11 (#52).

Each step says **what to run**, **what proves it**, and **where to save** the artifact. Save
terminal output under `evidence/attack/` or `evidence/defense/`, screenshots under
`evidence/screenshots/`. Capture the **baseline (undefended) first**, then apply the defense and
re-run the identical command for the "after".

---

## 0. Prerequisites (once per session)

```bash
bash lab.sh start                         # build + start all containers
docker compose -f docker/docker-compose.yml ps   # confirm every container is Up
```

DVWA needs its database created once (fixes the empty-output class of bug, #63):

```bash
# One-time: open http://localhost:8080/setup.php and click "Create / Reset Database",
# OR let the attack scripts do it:
docker exec -e DVWA_SETUP_DB=1 swagpc-kali bash /scripts/attack/run-full-attack.sh | head -5
```

---

## 1. US-5 (#46) — Kali can reach DVWA (undefended)

```bash
docker exec swagpc-kali curl -s -o /dev/null -w 'DVWA HTTP %{http_code}\n' http://192.168.20.10/login.php
```

- **Proves:** attacker on Guest reaches the café web app across the undefended network.
- **Expect:** `DVWA HTTP 302` (or 200). **Save:** `evidence/attack/us5-kali-reaches-dvwa.txt`.

## 2. US-6 (#47) — Guest→Business reconnaissance

```bash
docker exec swagpc-kali bash /scripts/attack/recon-scan.sh
```

- **Proves:** ARP scan of the local Guest segment + routed Nmap discovery/service scan of the
  Business subnet.
- **Expect (undefended):** `192.168.20.10/.25/.254` discovered; port 80 open on `.10`.
- **Save:** the script already writes `evidence/attack/arp-scan-*.txt`,
  `nmap-hostdiscovery-*.txt`, `nmap-services-*.txt`. Add a screenshot of the run.

## 3. US-7 (#48, #63) — DVWA web exploitation

```bash
# Command injection (standalone)
docker exec swagpc-kali bash /scripts/attack/dvwa-exploit.sh
# SQL injection
docker exec swagpc-kali bash /scripts/attack/sqli-exploit.sh
# Or the full chained sequence
docker exec swagpc-kali bash /scripts/attack/run-full-attack.sh
```

- **Proves:** `/etc/passwd` leaks via command injection; SQLi dumps user rows (undefended).
- **Expect:** `RESULT: VULNERABLE` and a `root:x:0:0:` line; SQLi returns multiple users.
- **Save:** scripts write `evidence/attack/dvwa-exploit-*.txt` (+ raw `.html`), `sqli-*.txt`.
  Screenshot the leaked `/etc/passwd`.

## 4. US-10 (#51) — Application hardening (before/after)

```bash
# BEFORE already captured in step 3 (payloads succeed)
sh defense/application-security/harden-dvwa-security-level.sh apply
docker exec swagpc-kali bash /scripts/attack/dvwa-exploit.sh      # AFTER
sh defense/application-security/harden-dvwa-security-level.sh status
```

- **Proves:** at security=impossible the command injection no longer returns `/etc/passwd`.
- **Expect (after):** `RESULT: no /etc/passwd content returned`.
- **Save:** before vs after `dvwa-exploit-*.txt`. Revert with `... revert` when done.

## 5. US-10 (#109) — Brute-force (before/after)

```bash
docker exec swagpc-kali bash /scripts/attack/dvwa-bruteforce.sh   # BEFORE: succeeds
# Apply the throttling/lockout control per defense/application-security/dvwa-bruteforce-defense.md
docker exec swagpc-kali bash /scripts/attack/dvwa-bruteforce.sh   # AFTER: 429, no auth
```

- **Proves:** undefended guessing finds the known password; after the control the run hits
  HTTP 429 after 5 failures and does not authenticate.
- **Also confirm:** a separate legit login works before threshold and after the 60s recovery.
- **Save:** before/after `evidence/attack/bruteforce-*.txt`.

## 6. US-10 (#110) — Broken access control (before/after)

```bash
# Deploy the fixture on a PHP host on the Business net, then set FIXTURE_URL.
# Quick review option: php -S 127.0.0.1:8090 -t defense/application-security/broken-access-control
FIXTURE_URL=http://192.168.20.10/bac docker exec -e FIXTURE_URL \
    swagpc-kali bash /scripts/attack/broken-access-control.sh
```

- **Proves:** vulnerable endpoint leaks another user's record and allows a client `role=admin`
  delete; the secure endpoint denies both (403) and unauthenticated (401), while owner read and
  admin op still return 200.
- **Save:** `evidence/attack/broken-access-control-*.txt` (before/after sections).

## 7. US-11 (#52) — Monitoring: Suricata + Wazuh

```bash
# Re-run an attack, then inspect detections
docker exec swagpc-kali bash /scripts/attack/recon-scan.sh
bash lab.sh logs                                   # Suricata fast.log + Wazuh alerts
docker exec swagpc-wazuh /var/ossec/bin/agent_control -l   # enrolled agents
```

- **Proves:** recon/web/brute attacks raise Suricata alerts (incl. custom sids 9000001–9000030)
  that reach Wazuh; the business-server agent (and, on a real Windows PC, the agent config in
  `configs/monitoring/windows-agent/`) are Active.
- **Expect:** alert lines with source `192.168.10.50`; agents listed Active.
- **Save:** `evidence/defense/suricata-fast-log.*`, `wazuh-alerts.*`.

### Known gap to resolve first (US-11 dashboard)

The `dashboard` service targets `https://wazuh:9200`, but the stack has **no `wazuh-indexer`
(OpenSearch) service**, so the dashboard UI cannot load until an indexer is added. The manager,
agents, and `alerts.log` still work for CLI evidence via `bash lab.sh logs`. Adding the indexer
is the dashboard-verification subtask — coordinate before relying on the `5601` UI for evidence.

---

## Evidence hygiene

- Name files with the date, e.g. `evidence/attack/dvwa-exploit-20261103_1200.txt`.
- Keep the **undefended baseline** and the **after-defense** artifact as a pair per control.
- A denial is only valid evidence if the route is reachable (so a WAF/network block is not
  mistaken for a fixed application control) — see the per-issue notes.
- Do **not** count a firewall denial, missing endpoint, CSRF error, or service failure as a
  successful defense.
