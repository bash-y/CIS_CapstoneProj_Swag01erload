# Defense — Broken Access Control (US-10, #110)

> **User story:** US-10 (#51) — *Web Application Security Hardening* (M3).
> **Task (@joromanii):** Demonstrate and fix broken access control in the café web app.
> **Lifecycle:** Build → Attack → Defend → Verify.

## Café scenario

A regular café staff user tries to read another staff member's order record (with card
data) and to perform an administrator-only operation (deleting an order). We demonstrate the
missing authorization checks, then enforce permissions on the server.

## Why a lab fixture (honest scope)

The deployed DVWA image does **not** include an authorization-bypass module with distinct
user-A / user-B records, so — as issue #110 permits — this clearly labeled local fixture
represents the scenario instead of claiming DVWA functionality that does not exist. The fixture
is a minimal PHP app with two versions of one endpoint:

| File | Role |
|---|---|
| `fixture_data.php` | Synthetic users (alice/bob = staff, admin) and orders (1001=alice, 1002=bob). Lab-only, no real data. |
| `login.php` | Establishes a trusted server-side session (`$_SESSION['user']`, `$_SESSION['role']`). |
| `orders_vulnerable.php` | **Broken**: no ownership check; trusts a client-supplied `role` param. |
| `orders_secure.php` | **Fixed**: deny-by-default; ownership + role derived from the session only. |

Attack driver: [`scripts/attack/broken-access-control.sh`](../../../scripts/attack/broken-access-control.sh).

## Authorization matrix

Protected **read** = an order record (owner-only). State-changing **delete** = admin-only.

| Actor | Read own order | Read other's order | Delete (admin op) |
|---|---|---|---|
| Unauthenticated | deny (401) | deny (401) | deny (401) |
| alice (staff) | **allow** | deny (403) | deny (403) |
| bob (staff) | **allow** | deny (403) | deny (403) |
| admin | allow | allow | **allow** |

## Attack (BEFORE — `orders_vulnerable.php`)

- **Horizontal (IDOR):** alice requests `?action=read&order_id=1002` and receives **bob's**
  record directly, including `card_last4` — no ownership check.
- **Vertical:** alice requests `?action=delete&order_id=1001&role=admin`; privilege is read from
  the **client-supplied** `role`, so the admin-only delete runs.
- Direct requests to the endpoint are used, not visible navigation links.

## Defend (AFTER — `orders_secure.php`)

- **Deny-by-default:** unauthenticated requests get 401 before anything else.
- **Server-side ownership:** staff may read only records where `owner == $_SESSION['user']`;
  admin may read any. Otherwise 403.
- **Server-side role:** delete requires `$_SESSION['role'] === 'admin'`. The request `role`
  param is ignored entirely.
- **No leakage / no state change on denial:** denied requests return a short status only and
  change nothing. Denials are logged via `error_log` as `[AUTHZ-DENY] user=… action=… reason=…`
  with **no** card data or passwords.

## Separation from the WAF management-path control (#79)

#79 restricts *network* reach to admin pages at the WAF (Guest subnet blocked from
`setup.php`/`phpinfo.php`). That is a network/location control. This task is **per-user
application authorization** — who may act on which record, decided inside the app from session
identity. They are complementary: keep the fixture route reachable during this test so a WAF
block is not mistaken for fixed authorization.

## Verify

1. **Before:** run the attack script against `orders_vulnerable.php` — horizontal read leaks
   bob's record, vertical delete succeeds. Save dated output.
2. **After:** same requests against `orders_secure.php` — expect 403 (horizontal, vertical) and
   401 (unauthenticated), with no protected data returned and no deletion.
3. **Positive controls:** alice reads her own order (200), admin deletes (200) — legitimate
   access still works.
4. Treat a hidden button or a generic error page as **insufficient**; the evidence is the actual
   before/after HTTP status and body.
5. Add a Defense Test Matrix row and a café-impact note (exposure of customer card data and
   unauthorized deletion of order records).

## Deployment prerequisite (for live-lab runs)

The fixture is not yet wired into `docker/docker-compose.yml`. To run it in the lab, serve this
directory from a PHP-capable host on the Business network (e.g. mount it into the DVWA/PHP
container under a `/bac` path, or run `php -S` in a sidecar), then set `FIXTURE_URL` for the
attack script. This prerequisite is recorded here per the issue rather than assumed.

## Status

Fixture (vulnerable + secure), attack driver, and this authorization matrix are implemented.
PHP was not lintable in the authoring environment (no PHP/Docker) and nothing was run live; the
bash driver was syntax-checked and its HTTP parsing unit-tested. Run the Verify steps to capture
before/after evidence.
