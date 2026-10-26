# Project Rules for SwagPc Café Capstone

## Automatic Git Commits & Issue Association
Whenever you create, modify, or delete project files to complete a task or user request, you must automatically commit the changes before concluding your turn:
1. Review `git status` to verify modified and untracked files.
2. Determine which **User Story (US-1 through US-13)** and/or GitHub issue number relates to the work.
3. If the work does not fit any existing User Story or issue:
   - Create a new User Story entry in `CIS3353_Capstone_Plan.md` with story points (1, 2, 3, or 5), an assignee, and an associated milestone.
   - Create the corresponding GitHub issue (using `gh issue create` or `scripts/new-user-story.ps1`).
   - Synchronize the points in `README.md`'s Individual Contribution Summary Table.
4. Format the commit message as:
   `US-<number> #<issue_number>: <concise, descriptive commit message>`
   *(If issue number is not yet created on remote, use `US-<number>: <concise description>`)*.
5. Stage modified files using `git add <files>` (or `git add .`).
6. Commit the changes using `git commit -m "<formatted message>"`.
7. Do not push to the remote repository unless explicitly asked by the user or when requested to publish changes.

## Rule File Synchronization
Whenever you create, modify, or update any workspace rule file (`GEMINI.md`, `CLAUDE.md`, or `AGENTS.md`), you must immediately replicate and synchronize the identical changes across all three files (`GEMINI.md`, `CLAUDE.md`, `AGENTS.md`) so that all AI agents and tools maintain 100% parity.

## Capstone Standards
- Maintain strict alignment with the **SwagPc Café** scenario (Guest VLAN 10 vs. Business VLAN 20, DVWA, pfSense, Wazuh/Suricata).
- Follow the course **Build → Attack → Defend** lifecycle.
- Keep user stories, tasks, story points, and wiki documentation synchronized with `CIS3353_Capstone_Plan.md` and `README.md`.
