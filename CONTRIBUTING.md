# SwagPc Café — Team Contribution & Commit Guidelines

To comply with the CIS 3353 Capstone requirements and maintain 100% alignment between git commits, user stories, and the project board, all contributors (team members and agents) must follow these rules.

---

## 1. Commit Message Standard

Every commit must be explicitly linked to a **User Story** and/or a **GitHub Issue Number**:

```text
US-<StoryNumber> #<IssueNumber>: <Imperative summary of work>
```

### Examples:
* `US-1 #1: Configure repository structure and initialize wiki templates`
* `US-6 #6: Add Nmap scan output and reconnaissance logs`
* `US-7 #7: Add SQL injection proof and screenshots`
* `US-8 #8: Configure pfSense firewall block rule for Guest to Business`

### Why this is required:
* Including `#<IssueNumber>` automatically links your commit to the GitHub issue timeline and project board card.
* When a commit resolves a task or story, using keywords like `Closes #<IssueNumber>` or `Fixes #<IssueNumber>` automatically moves the card to "Done" on the GitHub Project board.

---

## 2. What If There Is No Matching User Story or Issue?

If you are doing work that does not fit into the existing 13 User Stories (`US-1` through `US-13`):

1. **Do not commit unlinked work.**
2. **Create a new User Story or Task Issue**:
   * Option A: Run `.\scripts\new-user-story.ps1` in PowerShell.
   * Option B: Go to the GitHub repository **Issues** tab and click **New Issue**.
3. **Assign Metadata**:
   * **Title:** `US-<NextNumber>: <Title>`
   * **Milestone:** Link to `M1`, `M2`, `M3`, or `M4`.
   * **Assignee:** Tag the team member doing the work (`@UiwAntHuynhCIS`, `@bash-y`, or `@joromanii`).
   * **Story Points:** Assign points (1, 2, 3, or 5).
   * **Project Board:** Add the issue to the connected Project.
4. **Update Planning Docs**:
   * Add the new story into `CIS3353_Capstone_Plan.md`.
   * Update the member's total points in `README.md` (`Individual Contribution Summary Table`) to maintain parity with the board.

---

## 3. Automatic Commit-Message Git Hook (Recommended)

To prevent anyone from accidentally committing without an issue link, enable our local git hook:

```powershell
# Run once in PowerShell to activate the commit-msg hook:
git config core.hooksPath scripts/hooks
```

This hook validates every commit message before it is accepted.

---

## 4. Agent Skill Security Scan (US-15)

Any agent skill in the repo (a folder with a `SKILL.md`) is scanned with [NVIDIA SkillSpector](https://github.com/NVIDIA/SkillSpector) on every pull request and push to `main` (`.github/workflows/skill-scan.yml`).

* **Static analysis only:** the gate runs with `--no-llm`, so it needs no API keys and makes no LLM calls.
* **Pinned:** the workflow installs SkillSpector `v2.13.3`. Upgrading means changing that tag in the workflow and reviewing the new release.
* **Gate:** the job fails if SkillSpector rates a skill *DO NOT INSTALL* (the exit code is 1), or if the scanner errors. A skill rated *CAUTION* does not fail the job. A repo with no `SKILL.md` files passes.
* **Partial coverage does not fail the job:** project skills point to repo files outside their own folder (scripts, the plan, `CLAUDE.md`), which SkillSpector cannot inspect, so it marks those scans partial. The note stays in the SARIF report. Those repo files are covered by normal pull-request review instead.
* **Reports:** SARIF reports are uploaded as the `skill-scan-sarif` artifact on each run.

To run the same check locally, install the pinned release and run the script from the repo root:

```bash
uv tool install "git+https://github.com/NVIDIA/SkillSpector.git@v2.13.3"
sh scripts/skill-scan.sh        # reports go to skill-scan-results/
```
