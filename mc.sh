#!/usr/bin/env bash
#
# mc.sh - Ultra-fast Micro-Commit & Push Tool
#
# Usage:
#   ./mc.sh "your commit message"
#   ./mc.sh                          (auto-generates message from changed files)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [ -z "$CURRENT_BRANCH" ]; then
    echo "[✖] Error: Not a git repository."
    exit 1
fi

if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    echo "[!] CAUTION: You are on '$CURRENT_BRANCH'. Auto-pushes directly to main/master are blocked."
    echo "    Switch to your member branch first (e.g. 'git checkout sync-$(git config user.name)')."
    exit 1
fi

# Check if there are changes
CHANGES=$(git status --porcelain)
if [ -z "$CHANGES" ]; then
    echo "[*] Working directory clean. No changes to commit."
    exit 0
fi

# Determine commit message
MESSAGE="$*"
if [ -z "$MESSAGE" ]; then
    # Auto-generate a descriptive micro-commit message
    FILES_COUNT=$(echo "$CHANGES" | wc -l | tr -d ' ')
    FIRST_FILE=$(echo "$CHANGES" | head -n 1 | awk '{print $NF}')
    BASENAME=$(basename "$FIRST_FILE")
    
    if [ "$FILES_COUNT" -eq 1 ]; then
        MESSAGE="micro: update $BASENAME"
    else
        MESSAGE="micro: update $BASENAME and $((FILES_COUNT - 1)) other file(s)"
    fi
fi

# Prefix with micro if not already present
if [[ ! "$MESSAGE" =~ ^(micro:|feat:|fix:|docs:|test:|chore:|refactor:) ]]; then
    MESSAGE="micro: $MESSAGE"
fi

echo "=========================================================="
echo "  🚀 Fast Micro-Commit"
echo "  Branch  : $CURRENT_BRANCH"
echo "  Message : $MESSAGE"
echo "=========================================================="

# Stage all changes
git add -A

# Commit
git commit -m "$MESSAGE"

# Push
echo "[*] Pushing to origin/$CURRENT_BRANCH..."
if git push -u origin "$CURRENT_BRANCH"; then
    echo "[✔] Successfully pushed micro-commit!"
else
    echo "[!] Push failed. Trying pull --rebase before re-pushing..."
    git pull --rebase origin "$CURRENT_BRANCH"
    git push -u origin "$CURRENT_BRANCH"
    echo "[✔] Rebased and pushed micro-commit!"
fi
