# Project Rules for SwagPc Café Capstone

## Automatic Git Commits
Whenever you create, modify, or delete project files to complete a task or user request, you must automatically commit the changes before concluding your turn:
1. Review `git status` to verify modified and untracked files.
2. Stage modified files using `git add <files>` (or `git add .`).
3. Commit the changes using `git commit -m "<concise, descriptive commit message>"`.
4. Do not push to the remote repository unless explicitly asked by the user or when requested to publish changes.

## Capstone Standards
- Maintain strict alignment with the **SwagPc Café** scenario (Guest VLAN 10 vs. Business VLAN 20, DVWA, pfSense, Wazuh/Suricata).
- Follow the course **Build → Attack → Defend** lifecycle.
- Keep user stories, tasks, story points, and wiki documentation synchronized with `CIS3353_Capstone_Plan.md` and `README.md`.
