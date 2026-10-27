# Discord Update Bot

**SwagPc Bot** posts project activity to the team's Discord server so nobody has to check GitHub to know what changed. It runs entirely on GitHub Actions (no server to host) and posts through Discord webhooks.

| Channel | What appears | Workflow |
|---|---|---|
| `#swagpc-updates` | Commits on any branch, pull requests opened / review requested / approved / changes requested / merged / closed, issues opened / assigned / moved to a milestone / closed, and CI failures | `.github/workflows/discord-notify.yml` |
| `#swagpc-digest` | **Daily** (Tue–Sun, 8am Central): commits, merges and closed issues per teammate, PRs waiting on review, stale PRs, commits not linked to a user story or issue, overdue milestones, issues with no assignee or milestone. **Weekly** (Mondays): the same for 7 days, plus branches not merged into `main` and CI pass/fail counts | `.github/workflows/discord-digest.yml` |

Commits whose subject line has no `US-<n>` or `#<n>` are flagged with ⚠️, using the same rule as the *Verify Commit Issues & Stories* check. Teammates are shown by legal name with their GitHub handle.

## Setup (one time, about 5 minutes)

Only someone with **Manage Webhooks** on the Discord server and **admin** on the repository can do this.

1. **Create the channels.** In the team's Discord server, create two text channels: `#swagpc-updates` and `#swagpc-digest`. (One channel also works; skip step 4.)
2. **Create a webhook for each channel.** Channel → *Edit Channel* → *Integrations* → *Webhooks* → *New Webhook*. Name it `SwagPc Bot`, then *Copy Webhook URL*.
3. **Store the updates webhook as a repository secret** (the URL is a password: never paste it in a file, commit, issue or chat):

   ```bash
   gh secret set DISCORD_WEBHOOK_URL -R bash-y/CIS_CapstoneProj_Swag01erload
   ```

   `gh` prompts for the value, so it never lands in shell history.
4. **Store the digest webhook** the same way (optional; without it, digests go to the updates channel):

   ```bash
   gh secret set DISCORD_DIGEST_WEBHOOK_URL -R bash-y/CIS_CapstoneProj_Swag01erload
   ```

5. **Check it works.** After this branch is merged into `main`, run *Actions → Discord Digest → Run workflow* (or `gh workflow run discord-digest.yml -f period=daily`). A digest should appear in `#swagpc-digest` within a minute.

Until the secrets exist, both workflows run and exit cleanly without posting.

## Trying it locally

`--dry-run` prints the exact Discord message instead of sending it, so it needs no webhook:

```bash
python3 scripts/discord_notify.py digest weekly --dry-run      # reads live GitHub data via gh auth
python3 scripts/discord_notify.py test --dry-run
python3 -m unittest tests.test_discord_notify -v
```

To fill a new or quiet `#swagpc-updates` channel with recent work (last 24 hours, or `weekly` for 7 days), export the webhook in your terminal and run:

```bash
python3 scripts/discord_notify.py catchup
```

## Safety notes

- The notify workflow always runs the notifier code from `main`, so a branch or pull request cannot change the code that receives the webhook secret.
- Every message disables Discord mentions, so text like `@everyone` in a commit or issue title cannot ping the server.
- Workflows use read-only GitHub permissions.
- If a webhook URL leaks, delete that webhook in Discord, create a new one, and run `gh secret set` again.

## Changing it

- **Who counts as a teammate:** `MEMBERS` in `scripts/discord_notify.py` (GitHub handle → legal name).
- **Digest timing:** the `cron` lines in `discord-digest.yml` (times are UTC; 13:00 UTC is 8am CDT / 7am CST).
- **Thresholds:** `REVIEW_WAIT_DAYS` and `STALE_DAYS` in `scripts/discord_notify.py`.
- **Which CI workflows report failures:** the `workflow_run.workflows` list in `discord-notify.yml`.
