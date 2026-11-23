# Verification Evidence Index (US-18 #128)

> **Owner:** @joromanii. One row per captured artifact. Fill this in **as evidence is captured**
> during a live run of the [Defense Layer Attribution Matrix](../../wiki/Defense-Layer-Attribution-Matrix.md).
> **Status:** template — rows below the header are examples showing the format; replace them with
> real captures. No runtime results are claimed here.

Each row ties an artifact to the exact context so a reviewer can reproduce it and confirm which
layer handled the request. "Attributed control" is the layer whose own log/counter proves the
outcome — **not** merely what was running.

| Date (UTC) | Commit | Lab mode | Layer row | Command | Expected | Actual | Attributed control | Evidence file |
|---|---|---|---|---|---|---|---|---|
| _example_ `2026-01-01T00:00:00Z` | `abc1234` | segmentation-only | S | `bash scripts/testing/verify-defenses.sh` | 100% loss to .10/.25 | _tbd_ | firewall FW-DROP-GUEST | `evidence/verification/seg-only-<ts>.txt` |
| _example_ `2026-01-01T00:00:00Z` | `abc1234` | WAF/app-only | W | sqli through WAF + benign | malicious 403 / benign 200 | _tbd_ | ModSecurity rule 942100 | `evidence/defense/waf-<ts>.txt` |

## How to add a row

1. Capture with the helper so the file is dated and self-describing:
   ```sh
   sh scripts/capture-evidence.sh verification <name> "<title>" <command>
   ```
2. Add a row above with: capture timestamp, the `git rev-parse --short HEAD` at capture time, the
   lab mode, the matrix row letter (B/S/W/E/A/C), the exact command, expected vs actual, the
   attributed control (its log/counter), and the evidence file path.
3. For a defended row, also capture the **attribution log/counter** as its own artifact and link
   both — outcome alone is not accepted (#128).

## Rules

- Record BLOCKED/ERROR for infrastructure failures (service down, CSRF/DB error, missing
  endpoint); never count them as a successful defense.
- Redact credentials, cookies and sensitive response data before committing an artifact.
- Keep this index consistent with `Defense-Test-Matrix.md` and `Testing-and-Verification.md`.
