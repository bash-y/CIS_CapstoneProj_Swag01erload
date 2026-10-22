# 🔄 Automated GitHub Repository Sync

This repository includes a hands-free auto-sync service designed for team members to collaborate without needing to run manual Git commands or upload files via GitHub's web interface.

---

## 💡 How It Works

1. **Monitors Changes**: The script watches for file changes (edits, new files, deletes) in the project folder.
2. **Debounce Protection**: Waits 5 seconds after file edits stop to ensure work is saved before committing.
3. **Dedicated Member Branch**: Automatically switches to and pushes to your own member branch (e.g., `sync-joromanii`), **strictly protecting `main`**.
4. **Auto Commit & Push**: Automatically stages files, creates a timestamped commit message, and pushes to GitHub.
5. **Conflict Prevention**: Because each teammate pushes to their own `sync-<name>` branch, members never overwrite each other's work or collide on `main`.

---

## 🚀 Quick Start (Mac Users)

### Option 1: Double-Click Launcher (No Terminal Commands Required)
1. In Finder, open the project folder.
2. Double-click **`AutoSync.command`**.
3. Select option **1** to start auto-sync in the background!
4. You can close the terminal or keep working normally. Any changes you save will automatically sync to GitHub.

---

### Option 2: Command Line (`auto_sync.sh`)

Open your terminal in this repository folder and run:

| Command | Action |
|---|---|
| `./auto_sync.sh start` | Starts auto-sync as a background service |
| `./auto_sync.sh stop` | Stops the background service |
| `./auto_sync.sh status` | Checks if auto-sync is currently running & shows latest log |
| `./auto_sync.sh logs` | Streams live logs of file detections and commits |
| `./auto_sync.sh now` | Runs an immediate one-time sync right now |
| `./auto_sync.sh run` | Runs auto-sync in foreground terminal window |

---

## 🌿 Branching Strategy & Merging to `main`

- **Every contributor gets their own branch**:
  - `joromanii` ➔ pushes to `sync-joromanii`
  - `aphuynh` ➔ pushes to `sync-aphuynh`
  - `bashcadena` ➔ pushes to `sync-bashcadena`
- **Merging into `main`**:
  When a feature or milestone is completed, simply go to GitHub and open a **Pull Request** from your `sync-<name>` branch into `main`, or merge locally:
  ```bash
  git checkout main
  git merge sync-joromanii
  git push origin main
  ```

---

## 🔑 One-Time GitHub Sign-In (Mac)

If you have never pushed to GitHub from your Mac's terminal, you only need to sign in **once** so macOS Keychain remembers you:

### Recommended: Using GitHub CLI (Easiest)
In your terminal, run:
```bash
brew install gh
gh auth login
```
1. Choose **GitHub.com**
2. Choose **HTTPS**
3. Choose **Yes** to authenticate Git with your credentials
4. Choose **Login with a web browser** and press Enter
5. Your browser will open. Confirm the 8-character one-time code and click **Authorize**.

Once done, all Git pushes work automatically without ever prompting for passwords!

---

## ⚙️ Customizing the Branch Name (Optional)

If you want to use a custom branch name instead of the auto-generated `sync-<username>`, create a file called `.sync_branch` in the root of the project with your desired branch name:

```bash
echo "feature-login" > .sync_branch
```
*(Note: `main` and `master` are forbidden as auto-sync targets to protect the production branch.)*
