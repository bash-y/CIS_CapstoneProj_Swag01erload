---
name: docs-sync
description: Find SwagPc Café documentation whose status claims contradict the evidence folder or each other, and check that AGENTS.md, CLAUDE.md and GEMINI.md are identical. Use after a verification run, after adding evidence, or before a milestone review.
---

# Documentation sync

Only observed, recorded behavior counts as verified (`CLAUDE.md`, "Verification and Evidence"). This skill finds places where the documentation and the evidence disagree.

## Steps

1. **Rule files:** `AGENTS.md`, `CLAUDE.md` and `GEMINI.md` must be identical.

   ```sh
   cmp AGENTS.md CLAUDE.md && cmp AGENTS.md GEMINI.md && echo "rule files identical"
   ```

   If they differ, report the difference and ask the user which version is correct.
2. **Status claims:** list the claims to check.

   ```sh
   grep -rn -E "NOT been executed|Not verified|Verified|PASS|FAIL|Blocked|⛔|✅|⚠️" wiki build defense CIS3353_Capstone_Plan.md README.md
   ```

3. **Evidence:** list what has been recorded with `ls -R evidence`. Each evidence file states its date, host, command and exit code.
4. Compare each claim with the evidence:
   - Marked verified with no evidence file behind it: report it.
   - Marked not run or blocked, but a passing evidence file exists: update the claim and link the file, as in the Verification status section of `build/server/README.md`.
   - Evidence shows a failure the documentation doesn't mention: report it.
5. Check that the points, story counts and percentages in section 5 of `CIS3353_Capstone_Plan.md` match the Individual Contribution Summary Table in `README.md`.
6. Make only the edits the evidence supports, and list each one with its evidence path. Keep plans and TODOs labeled as plans.
7. Commit under the story the documentation belongs to: `US-<n> #<issue>: <description>`.
