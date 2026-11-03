# Research: DVWA and SQL Injection

**Course:** CIS 3353 Computer Systems Security
**Project:** SwagPc Café — Build → Attack → Defend
**Author:** joromanii (Security-Documentation Lead)
**Issue:** #17 (Research and Create Documentation) · Milestone M1
**Related stories:** US-5 (DVWA deployment), US-7 (web exploitation), US-10 (app hardening)

---

## 1. Purpose

This document is the research backing for the web-application attack in the SwagPc Café lab.
It explains what DVWA is, how SQL injection works, and exactly how both appear in our
environment, so the attack we demonstrate is understood rather than just copied. It is the
written proof for issue #17 and the baseline reference for the SQL injection scenario (S3) in
[`wiki/Attack.md`](../wiki/Attack.md).

---

## 2. What is DVWA?

**DVWA (Damn Vulnerable Web Application)** is a PHP/MySQL web application built on purpose to be
insecure. It is a standard, legal training target used to practice web attacks in a controlled
lab. In our project it stands in for the café's internal web portal, running as the
`swagpc-dvwa` container on the Business network at `192.168.20.10` (published to the host at
`http://localhost:8080`).

Key points for our scenario:

- **Default credentials:** `admin` / `password`.
- **One-time setup:** DVWA needs its database created once via `setup.php` ("Create / Reset
  Database") before any attack page returns data.
- **Security levels:** DVWA has four levels — **Low, Medium, High, Impossible**. The level is
  stored in a cookie and changes how much the code sanitizes input. We run the undefended
  baseline at **Low**, where there is effectively no input filtering, and later raise the level
  to show mitigation (US-10).

Why it fits the café story: a small café running a cheap or outdated web portal with no input
validation is a realistic version of exactly what DVWA simulates.

---

## 3. What is SQL Injection?

**SQL injection (SQLi)** is a vulnerability where attacker-supplied input is placed directly into
a database query instead of being treated as plain data. Because the input is concatenated into
the SQL string, an attacker can change the meaning of the query — read data they should not see,
bypass authentication, or dump entire tables.

DVWA's Low-level SQLi page builds its query roughly like this:

```php
$query = "SELECT first_name, last_name FROM users WHERE user_id = '$id';";
```

The `$id` value comes straight from the user with no escaping or parameterization. Whatever the
attacker types becomes part of the query.

### 3.1 Boolean / authentication-bypass style

Submitting the `id` value:

```text
1' OR '1'='1
```

turns the query into:

```sql
SELECT first_name, last_name FROM users WHERE user_id = '1' OR '1'='1';
```

`'1'='1'` is always true, so the `WHERE` clause matches **every row** and the page returns all
users instead of one. This is the classic proof that the input is not being treated as data.

### 3.2 UNION data-exfiltration style

A `UNION SELECT` appends a second query whose columns line up with the first, letting the
attacker pull data from other columns/tables into the same output:

```text
1' UNION SELECT user, password FROM users#
```

This returns usernames and their stored password hashes from the `users` table. The `#`
comments out the rest of the original query so it stays valid. This is the high-impact proof:
the café's customer/employee data would be readable by anyone on the guest network.

---

## 4. How it maps to our lab

| Item | Where it lives in this repo |
|---|---|
| Vulnerable app | `swagpc-dvwa` container — [`docker/docker-compose.yml`](../docker/docker-compose.yml) |
| Repeatable SQLi script | [`scripts/attack/sqli-exploit.sh`](../scripts/attack/sqli-exploit.sh) |
| Attack scenario register (S3) | [`wiki/Attack.md`](../wiki/Attack.md) |
| Captured evidence (screenshots) | [`BasicSQLinjection.png`](BasicSQLinjection.png), [`BasicSQLinjection-2.png`](BasicSQLinjection-2.png) |

Our [`sqli-exploit.sh`](../scripts/attack/sqli-exploit.sh) automates the research above against the
live lab: it logs in as `admin`, runs a baseline `id=1` query (one row), then the boolean
injection `1' OR '1'='1` (all rows), then the UNION injection to dump `user` and `password` from
the `users` table — saving each result to the evidence directory. It is written to be re-run after
defenses so we can show the same payloads no longer return rows.

> **Note on the evidence screenshots:** `BasicSQLinjection.png` and `BasicSQLinjection-2.png` in
> this folder show the injection returning data in the DVWA browser. These are the manual
> captures that back up the scripted run.

---

## 5. How SQL injection is prevented (defense preview — US-10)

The research also sets up the defensive side we demonstrate later:

1. **Parameterized queries / prepared statements** — the real fix. The query structure is fixed
   and user input is bound as a parameter, so it can never change the query's meaning.
2. **Input validation** — e.g. the `id` field should accept only an integer.
3. **Least privilege on the DB account** — the web app's database user should not be able to
   read unrelated tables or administer the database.
4. **Raising the DVWA security level** — moving Low → High shows DVWA's own progressively
   stronger sanitization, which is how we verify mitigation in the lab (US-10, re-run the same
   `sqli-exploit.sh` and confirm no rows come back).

---

## 6. References

- DVWA project (Damn Vulnerable Web Application) — standard security-training target.
- OWASP Top 10 — SQL injection falls under the **Injection** category.
- Internal: [`wiki/Attack.md`](../wiki/Attack.md), [`scripts/attack/sqli-exploit.sh`](../scripts/attack/sqli-exploit.sh).
