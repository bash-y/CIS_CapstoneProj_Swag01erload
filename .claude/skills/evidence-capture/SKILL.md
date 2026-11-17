---
name: evidence-capture
description: Save the output of a SwagPc Café lab check or command as a dated evidence file under evidence/, using scripts/capture-evidence.sh. Use when a test result, scan or verification run needs to become project evidence.
---

# Evidence capture

Use this when a command's result should become project evidence for the wiki, the Defense Test Matrix or a user story. Follow the root rules in `CLAUDE.md`.

## Steps

1. Pick the folder for the lifecycle phase: `build`, `attack`, `defense`, `verification`, `test-results` or `logs`.
2. Pick a short lowercase name with hyphens that starts with the story, for example `us4-workstation-to-server`.
3. Run the command through the helper from the repo root:

   ```sh
   sh scripts/capture-evidence.sh build us4-workstation-to-server "US-4 (#45) - Workstation to business server connectivity" sh scripts/testing/verify-workstation-to-server.sh
   ```

   The helper writes `evidence/<folder>/<name>-<UTC timestamp>.txt` with the title, date, host, command, full output and exit code, and exits with the command's own exit code.
4. Read the saved file before committing it. Remove or mask any password, token, session cookie or personal data, including lab default credentials.
5. Report the result exactly as recorded. A non-zero exit code is a failure, even if part of the output looks good.
6. Link the file from the document that makes the claim, such as `wiki/Defense-Test-Matrix.md` or the component README.

## Rules

- Never edit the output section of an evidence file to change a result. Rerun the command instead.
- Do not overwrite or delete existing evidence files. Each run gets its own timestamped file.
- Screenshots go in `evidence/screenshots/` by hand. This helper is for text output only.
