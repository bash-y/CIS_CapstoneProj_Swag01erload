---
name: new-user-story
description: Add a new SwagPc Café user story when no existing story fits the work - the plan entry, the GitHub issue, and the README contribution table. Use before committing work that has no matching story or issue.
---

# New user story

Follow the root rules in `CLAUDE.md` (identical to `AGENTS.md` and `GEMINI.md`). First check that no existing story fits: read section 4 of `CIS3353_Capstone_Plan.md` and the open issues.

## Steps

1. **Number:** one more than the highest `US-<n>` in `CIS3353_Capstone_Plan.md`.
2. **Details:** confirm with the user, or use what they already gave:
   - Story points: 1, 2, 3 or 5.
   - Assignee: `UiwAntHuynhCIS`, `bash-y` or `joromanii`.
   - Milestone: `M1: Proposal Approved`, `M2: Environment Built & Attack Demonstrated`, `M3: Defenses Implemented & Verified` or `M4: Documentation & Presentation`.
3. **Issue:** create it with `gh`, passing every value explicitly. `scripts/new-user-story.ps1` defaults to another assignee and M2, so do not rely on its defaults.

   ```sh
   gh issue create --repo bash-y/CIS_CapstoneProj_Swag01erload \
     --title "US-<n>: <title>" --body-file <body.md> \
     --milestone "<milestone title>" --assignee <login> --label "user-story,points:<p>"
   ```

   Body: the story sentence in bold with its points, then `Assignee: ... · Milestone: ...`, then a `### Tasks` checklist and an `### Acceptance` list. Issue #100 is an example.
4. **Plan:** add the story under its milestone in section 4 of `CIS3353_Capstone_Plan.md` as `**US-<n> (#<issue>) (<p> pts) — <story sentence>**`. Size each task XS, S, M, L or XL and tag it with the assignee code (A = Ant Huynh, B = Sebastian Cadena, C = joromanii). Update the backlog note at the top of section 4 with the new team total.
5. **Totals:** update the table in section 5 of the plan and the Individual Contribution Summary Table in `README.md`: the member's points and stories, the team total, the story count, and every member's percentage (points divided by the team total, one decimal place). Check that the percentages add up to 100%.
6. **Commit:** `US-<n> #<issue>: <description>`. If the issue could not be created, use `US-<n>: <description>` and report why.
