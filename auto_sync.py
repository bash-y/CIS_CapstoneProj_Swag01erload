#!/usr/bin/env python3
"""
Auto-Sync: Automated GitHub repository synchronization tool.
Monitors local file changes and automatically commits and pushes them
to a dedicated member branch (never pushing directly to main).
"""

import argparse
import datetime
import os
import re
import signal
import subprocess
import sys
import time

PROTECTED_BRANCHES = {"main", "master"}


def run_git(args, check=True, capture=True, disable_terminal_prompt=True):
    """Run a git command and return stdout as string."""
    env = os.environ.copy()
    if disable_terminal_prompt:
        env["GIT_TERMINAL_PROMPT"] = "0"
    try:
        res = subprocess.run(
            ["git"] + args,
            check=check,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
            text=True,
            env=env,
        )
        return res.stdout.strip() if capture and res.stdout else ""
    except subprocess.CalledProcessError as e:
        err = e.stderr.strip() if e.stderr else str(e)
        raise RuntimeError(f"git {' '.join(args)} failed: {err}") from e


def get_repo_root():
    """Verify inside git repo and get root directory."""
    try:
        return run_git(["rev-parse", "--show-toplevel"])
    except RuntimeError:
        sys.stderr.write("Error: Not inside a Git repository.\n")
        sys.exit(1)


def get_default_branch_name():
    """Derive a safe member branch name from git config or system user."""
    # 1. Check if an override exists in .sync_branch
    if os.path.exists(".sync_branch"):
        try:
            with open(".sync_branch", "r") as f:
                name = f.read().strip()
                if name:
                    return name
        except Exception:
            pass

    # 2. Derive from git user.name
    raw_name = run_git(["config", "user.name"], check=False)
    if not raw_name:
        # Fallback to system username
        raw_name = os.environ.get("USER") or os.environ.get("USERNAME") or "member"

    # Sanitize: lowercase, only alphanumeric, dashes, and underscores
    sanitized = re.sub(r"[^a-zA-Z0-9_-]", "-", raw_name.strip()).lower().strip("-")
    sanitized = re.sub(r"-+", "-", sanitized)
    if not sanitized:
        sanitized = "member"
    return f"sync-{sanitized}"


def get_current_branch():
    """Return the name of the currently checked out branch."""
    return run_git(["rev-parse", "--abbrev-ref", "HEAD"])


def ensure_target_branch(target_branch):
    """Ensure we are working on the target branch and not on main/master."""
    if target_branch in PROTECTED_BRANCHES:
        raise ValueError(
            f"Target branch cannot be '{target_branch}'. Direct auto-pushes to main/master are restricted."
        )

    current = get_current_branch()
    if current != target_branch:
        # Check if target branch exists locally
        branches = run_git(["branch", "--list", target_branch])
        if branches:
            print(f"[*] Switching from '{current}' to target branch '{target_branch}'...")
            run_git(["checkout", target_branch])
        else:
            print(f"[*] Creating and switching to new branch '{target_branch}' from '{current}'...")
            run_git(["checkout", "-b", target_branch])
    return target_branch


def get_status_changes():
    """Return list of changed files from git status --porcelain."""
    out = run_git(["status", "--porcelain"])
    if not out:
        return []
    lines = [line.strip() for line in out.splitlines() if line.strip()]
    return lines


def format_commit_message(changes):
    """Format a clean, informative commit message."""
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    files = []
    for line in changes:
        parts = line.split(maxsplit=1)
        if len(parts) == 2:
            files.append(os.path.basename(parts[1]))

    if not files:
        return f"Auto-sync update at {now}"

    # Dedup preserving order
    seen = set()
    dedup = [f for f in files if not (f in seen or seen.add(f))]

    if len(dedup) == 1:
        summary = f"update {dedup[0]}"
    elif len(dedup) <= 3:
        summary = f"update {', '.join(dedup)}"
    else:
        summary = f"update {dedup[0]}, {dedup[1]} and {len(dedup) - 2} other files"

    return f"Auto-sync: {summary} ({now})"


def sync_changes(target_branch, verbose=False):
    """Stage, commit, and push uncommitted changes."""
    changes = get_status_changes()
    if not changes:
        return False

    print(f"\n[{datetime.datetime.now().strftime('%H:%M:%S')}] Detected {len(changes)} changed item(s).")
    if verbose:
        for c in changes:
            print(f"    {c}")

    # Stage changes
    print("[*] Staging files...")
    run_git(["add", "-A"])

    # Double check if anything staged
    diff = run_git(["diff", "--cached", "--name-only"])
    if not diff:
        print("[*] No staged differences to commit.")
        return False

    msg = format_commit_message(changes)
    print(f"[*] Committing: {msg}")
    run_git(["commit", "-m", msg])

    # Push to remote branch
    print(f"[*] Pushing to origin/{target_branch}...")
    try:
        run_git(["push", "-u", "origin", target_branch])
        print(f"[✔] Successfully synced to origin/{target_branch}!")
        return True
    except RuntimeError as push_err:
        err_str = str(push_err).lower()
        if "terminal prompts disabled" in err_str or "could not read username" in err_str or "authentication failed" in err_str:
            print("[✖] GitHub Authentication Required:")
            print("    Your Mac has not saved credentials for GitHub yet.")
            print("    To fix: Open Terminal and run 'brew install gh && gh auth login' or enter a GitHub Personal Access Token.")
            print("[*] Local commit saved successfully. Will push once authenticated.")
            return False

        print(f"[!] Push failed: {push_err}")
        print("[*] Attempting pull --rebase before re-pushing...")
        try:
            run_git(["pull", "--rebase", "origin", target_branch])
            run_git(["push", "-u", "origin", target_branch])
            print(f"[✔] Rebased and pushed to origin/{target_branch}!")
            return True
        except Exception as retry_err:
            print(f"[✖] Sync push failed: {retry_err}")
            print("[*] Changes are committed locally. Will retry pushing on next cycle.")
            return False


def watch_loop(target_branch, interval=5, debounce=5, verbose=False):
    """Main watch loop that monitors and auto-syncs."""
    print("=" * 60)
    print(" GitHub Auto-Sync Service Running")
    print(f" Target Branch : {target_branch} (protected: main/master)")
    print(f" Check Interval: every {interval}s (debounce: {debounce}s)")
    print(" Press Ctrl+C to stop.")
    print("=" * 60)

    try:
        while True:
            changes = get_status_changes()
            if changes:
                print(f"[*] Changes detected. Waiting {debounce}s for edits to settle...")
                time.sleep(debounce)
                # Verify branch is still safe before sync
                ensure_target_branch(target_branch)
                sync_changes(target_branch, verbose=verbose)
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\n[*] Auto-sync stopped by user.")


def main():
    parser = argparse.ArgumentParser(description="Auto-sync local changes to GitHub branch.")
    parser.add_argument("--branch", help="Target branch name (default: sync-<username>)")
    parser.add_argument("--interval", type=int, default=5, help="Poll interval in seconds (default: 5)")
    parser.add_argument("--debounce", type=int, default=5, help="Debounce settle delay in seconds (default: 5)")
    parser.add_argument("--once", action="store_true", help="Sync once and exit")
    parser.add_argument("--verbose", action="store_true", help="Show verbose output")
    args = parser.parse_args()

    repo_root = get_repo_root()
    os.chdir(repo_root)

    target_branch = args.branch or get_default_branch_name()

    try:
        ensure_target_branch(target_branch)
    except ValueError as e:
        sys.stderr.write(f"Error: {e}\n")
        sys.exit(1)

    if args.once:
        print(f"[*] Running one-time sync to '{target_branch}'...")
        synced = sync_changes(target_branch, verbose=True)
        if not synced:
            print("[*] Everything is already up-to-date. No changes to push.")
        sys.exit(0)

    watch_loop(
        target_branch=target_branch,
        interval=args.interval,
        debounce=args.debounce,
        verbose=args.verbose,
    )


if __name__ == "__main__":
    main()
