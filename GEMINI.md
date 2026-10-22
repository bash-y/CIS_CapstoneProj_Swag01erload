# Repository Guidelines

## In-Chat Git Commit Workflow
- The active development branch for the user is `sync-joromanii`. Direct pushes to `main` or `master` are protected.
- Whenever the user asks to commit, push, save, or micro-commit in chat (e.g., `commit: <message>`, `push`, `save my changes`, `micro-commit`):
  1. Check `git status`.
  2. Stage modified and new files (`git add -A`).
  3. Create a commit using the user's message (or auto-generate a descriptive micro-commit summary if no message is provided).
  4. Push to `origin sync-joromanii`.
  5. Confirm the commit hash and pushed status back to the user.
