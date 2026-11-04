# Defense — DVWA Brute-Force Login (US-10, #109)

> **User story:** US-10 (#51) — *Web Application Security Hardening* (M3).
> **Task (@joromanii):** Demonstrate and mitigate brute-force login against the café web app.
> **Lifecycle:** Build → Attack → Defend → Verify.

## Café scenario

An attacker on the authorized Guest lab network repeatedly guesses a synthetic staff
account's password against the café web portal. We demonstrate the undefended behavior,
apply a login-protection control, and prove that valid staff access still works.

## What is attacked (and what is not)

- **Target:** DVWA's **Brute Force module** at `/vulnerabilities/brute/` — a *simulated* staff
  login. This is deliberately distinct from DVWA's own `/login.php` admin login.
- **Attack script:** [`scripts/attack/dvwa-bruteforce.sh`](../../scripts/attack/dvwa-bruteforce.sh).
  It authenticates to DVWA once for a session, forces `security=low`, then guesses a small
  fixed candidate list (including the known lab password) for `admin`. Success is detected by
  the module's **"Welcome to the password protected area"** marker — i.e. *actual* authenticated
  success, not an HTTP 200. Failed guesses, accepted credentials, and infrastructure errors are
  recorded separately, with attempt counts and elapsed time, to `evidence/attack/`.

## Undefended baseline (Attack)

With no protection, every guess is accepted for processing at the same speed, so the known lab
password is found within the candidate list. The run is bounded by `MAX_ATTEMPTS` and
`REQUEST_DELAY` and records the attempt number at which guessing succeeded.

## Defense — throttling / temporary lockout

The control is **rate limiting with a temporary lockout** applied at the login path, enforced
in front of DVWA at the WAF (the reverse proxy is the single point every Guest request passes
through), with DVWA's own higher security levels as a second layer.

**Declared policy (tested values):**

| Parameter | Value |
|---|---|
| Failure threshold | **5 failed attempts** |
| Time window | **30 seconds** per source |
| Lockout / recovery | **60-second** block (HTTP 429), then automatic recovery |
| Scope | per source IP **and** per account where supported |

**WAF enforcement (nginx `limit_req`) — design to wire into the shared WAF config:**

```nginx
# http{} context
limit_req_zone $binary_remote_addr zone=login:10m rate=10r/m;   # ~1 attempt / 6s sustained

# server{} — the DVWA brute-force login path
location /vulnerabilities/brute/ {
    limit_req zone=login burst=5 nodelay;   # allow a short burst, then 429
    limit_req_status 429;
    include includes/proxy_backend.conf;
}
```

> This snippet is the defense design for the reverse proxy owned under US-10's proxy subtask
> (`configs/waf/default.conf.template`, @bash-y). It is documented here rather than edited into
> that shared file directly, so the two US-10 subtasks don't collide. Coordinate on merge.

**DVWA second layer:** running the app at a higher security level
([`harden-dvwa-security-level.sh`](harden-dvwa-security-level.sh)) adds the application's own
progressive login delay, so even requests that reach DVWA are slowed.

## Limitations (honest scope)

- `limit_req` keyed on source IP throttles **per source**. To protect a single account across
  *different* sources/sessions, a true account-lockout counter is needed (stateful, in the app
  or an auth proxy). The WAF rate limit is the per-source control; the DVWA security-level delay
  is the per-app control. Neither stores submitted passwords.
- The attacker cannot trivially bypass the per-source limit by rotating the DVWA session cookie,
  because `limit_req` keys on the client IP, not the cookie.

## Monitoring integration

A Suricata rule fires on repeated brute-force requests from the Guest network and feeds Wazuh:

- `configs/monitoring/swagpc-custom.rules` — **sid 9000030**
  *"SWAGPC WEB Brute-force login attempts from Guest (DVWA brute module)"*, threshold 5 requests
  to `/vulnerabilities/brute/` in 30s per source. This records the authentication *events*
  (source, count, timing) without logging the guessed passwords.

## Verify

1. **Before:** run `dvwa-bruteforce.sh` undefended — guessing succeeds; save dated output.
2. **After:** apply the WAF rate limit, re-run with the same candidate list and pace — the run
   hits HTTP 429 after 5 failures and does **not** authenticate within the window; the Suricata
   rule (9000030) alerts in Wazuh.
3. **Legitimacy:** confirm correct credentials work *before* the threshold and *after* the
   60-second recovery, and that a separate legitimate account remains usable.
4. Do **not** count a firewall denial, missing endpoint, CSRF error, or service failure as
   successful mitigation — the attack script flags those as `ERROR`, separate from rejections.
5. Add a row to the Defense Test Matrix and the café-impact note.

## Status

Attack script and Suricata rule are implemented. The WAF `limit_req` policy is documented for
integration into the shared proxy config. Nothing here was run against the live lab in the
authoring environment (no Docker); run the Verify steps above to capture before/after evidence.
