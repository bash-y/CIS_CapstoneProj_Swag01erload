# Discord PR Bot (approve and merge from Discord)

**SwagPc PR Bot** lets teammates review, approve and merge pull requests from the team's Discord server. It complements the [[Discord Update Bot|Discord-Bot]], which only posts notifications.

Each teammate links their **own** GitHub account once. After that, an approval or merge made in Discord is recorded on GitHub under that person's name, exactly as if they had clicked on GitHub. `main`'s ruleset still applies: every PR needs 1 approval from someone other than its author, and nobody can approve their own PR.

| Command | What it does |
|---|---|
| `/link` | Private button to sign in with GitHub and link your account (once per person) |
| `/whoami` | Shows which GitHub account you linked |
| `/unlink` | Forgets your GitHub account |
| `/prs` | Lists open pull requests, with a picker to open one |
| `/pr <number>` | Posts a PR card with **Approve**, **Merge**, **Refresh** and **Review changes** buttons |

**How the buttons behave**

- **Review changes** opens the PR's file diff on GitHub. Read it before approving.
- **Approve** files an approving review as you, pinned to the commit shown on the card. If someone pushed since the card was posted, nothing is approved: the card refreshes and you're asked to review the new commits.
- **Merge** first asks you privately to confirm. The merge only goes through if the PR head is still the commit on the card and GitHub's rules are met (an approval, no conflicts). The channel is then told who merged it.
- If GitHub refuses something, such as approving your own PR or merging without an approval, only you see the reason.

## How it works

The bot is a single-file Cloudflare Worker (`discord-pr-bot/worker.js`, no dependencies) on Cloudflare's free plan.

- Discord sends every command and button click to the Worker. The Worker rejects anything without a valid Discord signature.
- GitHub sign-in uses a GitHub App with short-lived user tokens (8 hours, refreshed automatically).
- Tokens are stored in Cloudflare KV, encrypted with AES-GCM and bound to the Discord user.
- The Worker only answers in the team's Discord server.

## Setup (repo owner, about 20 minutes)

You need: admin on the GitHub repo, the **Manage Server** permission in Discord, and a free Cloudflare account. Keep every secret below out of chat, issues and commits. Paste each one only into the field named.

### 1. Create the Cloudflare Worker (to get its URL)

1. Sign in at <https://dash.cloudflare.com> → **Workers & Pages** → **Create** → **Create Worker**. Name it `swagpc-pr-bot` → **Deploy**.
2. Note its URL, e.g. `https://swagpc-pr-bot.<your-subdomain>.workers.dev`. Below, this is called `WORKER_URL`.

### 2. Create the GitHub App

1. GitHub → **Settings** → **Developer settings** → **GitHub Apps** → **New GitHub App**.
   - **Name:** `SwagPc PR Bot` (add a suffix if the name is taken)
   - **Homepage URL:** `https://github.com/bash-y/CIS_CapstoneProj_Swag01erload`
   - **Callback URL:** `WORKER_URL/github/callback`
   - ✅ **Expire user authorization tokens**
   - ☐ **Request user authorization (OAuth) during installation** (leave unchecked)
   - **Webhook:** uncheck **Active**
   - **Repository permissions:** Pull requests **Read and write** · Contents **Read and write** (needed to merge) · Checks **Read-only** · Metadata **Read-only**
   - **Where can this GitHub App be installed?** Only on this account
2. **Create GitHub App**. Copy the **Client ID**, then **Generate a new client secret** and keep it for step 4.
3. **Install App** (left menu) → your account → **Only select repositories** → `CIS_CapstoneProj_Swag01erload` → **Install**.

Teammates don't install anything. They only sign in through `/link`.

### 3. Create the Discord application

1. <https://discord.com/developers/applications> → **New Application** → `SwagPc PR Bot`.
2. **General Information**: copy the **Application ID** and **Public Key**.
3. **Bot** → **Reset Token** → copy the token. It's only used once, in step 6.
4. **Installation** → under Guild Install, scopes: `applications.commands`. Open the **Install Link** and add the app to the SwagPc server.
5. In Discord, turn on **User Settings → Advanced → Developer Mode**, then right-click the server icon → **Copy Server ID**.

### 4. Configure and deploy the Worker

1. In the Cloudflare dashboard, open **Storage & Databases** → **KV** → **Create** a namespace called `swagpc-pr-bot-links`.
2. Open the `swagpc-pr-bot` Worker → **Settings** → **Bindings** → **Add** → **KV namespace**. Variable name `LINKS`, namespace `swagpc-pr-bot-links`.
3. **Settings** → **Variables and Secrets** → add:

   | Name | Type | Value |
   |---|---|---|
   | `DISCORD_APPLICATION_ID` | Text | Application ID from step 3 |
   | `DISCORD_PUBLIC_KEY` | Text | Public Key from step 3 |
   | `GITHUB_CLIENT_ID` | Text | Client ID from step 2 |
   | `GITHUB_REPO` | Text | `bash-y/CIS_CapstoneProj_Swag01erload` |
   | `ALLOWED_GUILD_ID` | Text | Server ID from step 3 |
   | `ALLOWED_CHANNEL_ID` | Text | Optional: the one channel the bot answers in (right-click channel → **Copy Channel ID**) |
   | `MERGE_METHOD` | Text | `merge` (or `squash` / `rebase`) |
   | `GITHUB_CLIENT_SECRET` | **Secret** | Client secret from step 2 |
   | `SECRET_KEY` | **Secret** | Output of the command below |

   Generate `SECRET_KEY` in your own terminal (32 random bytes):

   ```bash
   openssl rand -base64 32
   ```

4. **Edit code** → replace everything with the contents of `discord-pr-bot/worker.js` → **Deploy**.
5. Open `WORKER_URL` in a browser. It should say *SwagPc PR Bot is running.*

### 5. Connect Discord to the Worker

Discord Developer Portal → your app → **General Information** → **Interactions Endpoint URL** = `WORKER_URL/interactions` → **Save Changes**. Discord checks the URL straight away. If saving fails, recheck `DISCORD_PUBLIC_KEY`.

### 6. Register the slash commands

From the repo folder:

```bash
python3 discord-pr-bot/register_commands.py
```

It asks for the Application ID, the Server ID and the bot token (hidden). Expected output: `Registered: /link, /unlink, /whoami, /pr, /prs`.

### 7. Each teammate

Type `/link` in the server and click the button. Sign in with GitHub and authorize **SwagPc PR Bot**. You'll see *GitHub account linked*. Then try `/prs`.

## Updating the bot

Paste the new `worker.js` into **Edit code** → **Deploy**. Linked accounts are kept.

## Testing

The tests run the Worker end to end with real Ed25519 signatures and mocked GitHub/Discord. They need Node 22+, or run them in Docker without installing Node:

```bash
docker run --rm -v "$PWD/discord-pr-bot":/app:ro -w /app node:22-alpine node --test
```

## Safety notes

- **Accountability:** approvals and merges are always made with the clicking person's own GitHub account. The bot has no GitHub identity of its own, so it can't approve or merge anything by itself.
- **Signatures:** every Discord request is signature-checked; requests more than 5 minutes old are refused.
- **Pinned commits:** Approve and Merge are tied to the exact commit shown on the card.
- **Stored tokens:** GitHub tokens never appear in Discord messages or logs. They are stored encrypted, and unreadable without `SECRET_KEY`.
- **Revoking access:** `/unlink` deletes your stored tokens. To fully revoke, go to GitHub → **Settings** → **Applications** → **Authorized GitHub Apps** → **SwagPc PR Bot** → **Revoke**.
- **Leaked secrets:** if the client secret, `SECRET_KEY` or the bot token leaks, regenerate it where it was created and update the Worker. Changing `SECRET_KEY` means everyone runs `/link` again.
