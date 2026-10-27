#!/usr/bin/env python3
"""Post project updates to Discord: live GitHub events and daily/weekly digests.

Usage:
  python3 scripts/discord_notify.py event                   # in Actions: post the current GitHub event
  python3 scripts/discord_notify.py digest daily|weekly     # post an insight digest
  python3 scripts/discord_notify.py test                    # post a hello message to check a webhook
  Add --dry-run to print the Discord payload instead of sending it.

Webhooks come from secrets, never from the repository:
  DISCORD_WEBHOOK_URL         live updates (commits, pull requests, issues, CI failures)
  DISCORD_DIGEST_WEBHOOK_URL  digests; falls back to DISCORD_WEBHOOK_URL
With no webhook set the script prints a notice and exits 0, so workflows stay green
until the channel is set up.

Event mode reads GITHUB_EVENT_NAME and GITHUB_EVENT_PATH (or --event-name / --event-file).
Digest mode reads GitHub the same way the dashboard does (see generate_dashboard.py).
Standard library only.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

BOT_NAME = "SwagPc Bot"
REPO_URL = "https://github.com/bash-y/CIS_CapstoneProj_Swag01erload"

# Legal names for every document and message; GitHub handles stay in brackets.
MEMBERS = {
    "UiwAntHuynhCIS": "Anthony Huynh",
    "bash-y": "Sebastian Cadena",
    "joromanii": "Jomar Rodriguez Canales",
}

GREEN, PURPLE, RED, BLUE, AMBER, GREY, LIME = 0x2ECC71, 0x8957E5, 0xE74C3C, 0x3498DB, 0xF1C40F, 0x95A5A6, 0xDCF5A4

# Same rule as .github/workflows/verify-commit-issues.yml.
LINK = re.compile(r"US-[0-9]+|#[0-9]+")
SKIP = re.compile(r"Merge|Revert")
WEBHOOK = re.compile(r"^https://(?:ptb\.|canary\.)?discord(?:app)?\.com/api/webhooks/\d+/[\w-]+$")

MAX_LINES = 10
STALE_DAYS = 3
REVIEW_WAIT_DAYS = 2


# ----------------------------------------------------------------------------- helpers

def who(login: str | None, fallback: str = "someone") -> str:
    if not login:
        return fallback
    return f"{MEMBERS[login]} (@{login})" if login in MEMBERS else f"@{login}"


def short(text: str | None, limit: int) -> str:
    text = (text or "").strip()
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def first_line(text: str | None) -> str:
    return (text or "").strip().splitlines()[0] if (text or "").strip() else ""


def linked(message: str) -> bool:
    return bool(LINK.search(first_line(message)))


def refs(*texts: str | None) -> list[str]:
    seen: list[str] = []
    for text in texts:
        for ref in LINK.findall(text or ""):
            if ref not in seen:
                seen.append(ref)
    return seen


def parse_time(stamp: str | None) -> datetime | None:
    return datetime.fromisoformat(stamp.replace("Z", "+00:00")) if stamp else None


def age(stamp: str | None, now: datetime) -> str:
    when = parse_time(stamp)
    if not when:
        return "?"
    hours = int((now - when).total_seconds() // 3600)
    return f"{hours}h" if hours < 48 else f"{hours // 24}d"


def bar(done: int, total: int, width: int = 10) -> str:
    filled = round(width * done / total) if total else 0
    return "▰" * filled + "▱" * (width - filled)


def embed(title: str, url: str | None = None, color: int = LIME, description: str = "",
          fields: list[tuple[str, str, bool]] | None = None, footer: str | None = None) -> dict:
    """Build one Discord embed, trimmed to Discord's size limits."""
    out: dict = {"title": short(title, 256), "color": color}
    if url:
        out["url"] = url
    if description:
        out["description"] = short(description, 4000)
    if fields:
        out["fields"] = [{"name": short(n, 256), "value": short(v, 1024) or "—", "inline": i}
                         for n, v, i in fields[:25]]
    if footer:
        out["footer"] = {"text": short(footer, 2048)}
    return out


def payload(embeds: list[dict]) -> dict:
    """Wrap embeds in a webhook message. Mentions are disabled so text can never ping @everyone."""
    embeds = embeds[:10]
    while embeds and len(json.dumps(embeds)) > 5800 and embeds[-1].get("description"):
        embeds[-1]["description"] = short(embeds[-1]["description"], len(embeds[-1]["description"]) // 2)
    return {"username": BOT_NAME, "embeds": embeds, "allowed_mentions": {"parse": []}}


# ----------------------------------------------------------------------------- live events

def on_push(ev: dict) -> list[dict]:
    ref = ev.get("ref", "")
    if ev.get("deleted") or not ref.startswith("refs/heads/"):
        return []
    branch = ref.removeprefix("refs/heads/")
    commits = [c for c in ev.get("commits", []) if not SKIP.search(first_line(c.get("message")))]
    if not commits:
        return []
    lines, unlinked = [], 0
    for c in commits[:MAX_LINES]:
        author = c.get("author") or {}
        flag = "" if linked(c["message"]) else "  ⚠️ no US/issue"
        unlinked += 0 if flag == "" else 1
        lines.append(f"[`{c['id'][:7]}`]({c.get('url', '')}) {short(first_line(c['message']), 70)}"
                     f" — {who(author.get('username'), author.get('name', 'someone'))}{flag}")
    if len(commits) > MAX_LINES:
        unlinked += sum(1 for c in commits[MAX_LINES:] if not linked(c["message"]))
        lines.append(f"…and {len(commits) - MAX_LINES} more")
    noun = "commit" if len(commits) == 1 else "commits"
    footer = "Force-pushed" if ev.get("forced") else None
    if unlinked:
        footer = (footer + " · " if footer else "") + f"{unlinked} not linked to a user story or issue"
    return [embed(f"📦 {len(commits)} new {noun} on {branch}", ev.get("compare"),
                  AMBER if unlinked else GREEN, "\n".join(lines), footer=footer)]


def _pr_fields(pr: dict) -> list[tuple[str, str, bool]]:
    links = refs(pr.get("title"), pr.get("body"), pr.get("head", {}).get("ref"))
    fields = [
        ("Author", who((pr.get("user") or {}).get("login")), True),
        ("Branch", f"`{pr['head']['ref']}` → `{pr['base']['ref']}`", True),
    ]
    if pr.get("changed_files") is not None:
        fields.append(("Changes", f"+{pr.get('additions', 0)} / −{pr.get('deletions', 0)} "
                                  f"in {pr['changed_files']} files", True))
    if links:
        fields.append(("Linked", " ".join(links), True))
    return fields


def on_pull_request(ev: dict) -> list[dict]:
    pr, action = ev["pull_request"], ev.get("action")
    head = f"PR #{pr['number']}: {pr['title']}"
    if action in ("opened", "reopened", "ready_for_review"):
        label = {"opened": "🆕 Opened", "reopened": "♻️ Reopened", "ready_for_review": "👀 Ready for review"}[action]
        if action == "opened" and pr.get("draft"):
            label = "📝 Draft opened"
        return [embed(f"{label} — {head}", pr["html_url"], BLUE, short(pr.get("body"), 300), _pr_fields(pr))]
    if action == "closed":
        if pr.get("merged"):
            return [embed(f"🟣 Merged — {head}", pr["html_url"], PURPLE,
                          f"Merged by {who((pr.get('merged_by') or {}).get('login'))}", _pr_fields(pr))]
        return [embed(f"⚪ Closed without merging — {head}", pr["html_url"], GREY, fields=_pr_fields(pr))]
    if action == "review_requested":
        reviewer = (ev.get("requested_reviewer") or {}).get("login") or (ev.get("requested_team") or {}).get("name")
        return [embed(f"🙋 Review requested — {head}", pr["html_url"], AMBER,
                      f"{who(reviewer)} was asked to review this pull request.", _pr_fields(pr))]
    return []


def on_review(ev: dict) -> list[dict]:
    if ev.get("action") != "submitted":
        return []
    rv, pr = ev["review"], ev["pull_request"]
    state = (rv.get("state") or "").lower()
    body = short(rv.get("body"), 400)
    looks = {"approved": ("✅ Approved", GREEN), "changes_requested": ("🛑 Changes requested", RED),
             "commented": ("💬 Review comment", GREY)}
    if state not in looks or (state == "commented" and not body):
        return []
    label, color = looks[state]
    return [embed(f"{label} — PR #{pr['number']}: {pr['title']}", rv.get("html_url") or pr["html_url"], color,
                  body, [("Reviewer", who((rv.get("user") or {}).get("login")), True),
                         ("Author", who((pr.get("user") or {}).get("login")), True)])]


def _set_at_creation(issue: dict) -> bool:
    """GitHub sends assigned/milestoned right after opened; skip those duplicates."""
    created, updated = parse_time(issue.get("created_at")), parse_time(issue.get("updated_at"))
    return bool(created and updated and (updated - created) < timedelta(seconds=60))


def on_issue(ev: dict) -> list[dict]:
    issue, action = ev["issue"], ev.get("action")
    head = f"Issue #{issue['number']}: {issue['title']}"
    assignees = ", ".join(who(a.get("login")) for a in issue.get("assignees") or []) or "Unassigned"
    milestone = (issue.get("milestone") or {}).get("title") or "No milestone"
    labels = ", ".join(lb["name"] for lb in issue.get("labels") or []) or "—"
    fields = [("Assignees", assignees, True), ("Milestone", milestone, True), ("Labels", labels, True)]
    if action == "opened":
        return [embed(f"🆕 {head}", issue["html_url"], BLUE, short(issue.get("body"), 300),
                      [("Opened by", who((issue.get("user") or {}).get("login")), True)] + fields)]
    if action == "closed":
        done = issue.get("state_reason") != "not_planned"
        return [embed(f"{'✅ Closed' if done else '⚪ Closed as not planned'} — {head}", issue["html_url"],
                      GREEN if done else GREY, fields=fields)]
    if action == "reopened":
        return [embed(f"♻️ Reopened — {head}", issue["html_url"], AMBER, fields=fields)]
    if action == "assigned" and not _set_at_creation(issue):
        return [embed(f"👤 Assigned to {who((ev.get('assignee') or {}).get('login'))} — {head}",
                      issue["html_url"], BLUE, fields=fields)]
    if action == "milestoned" and not _set_at_creation(issue):
        return [embed(f"🏁 Moved to {milestone} — {head}", issue["html_url"], BLUE, fields=fields)]
    return []


def on_workflow_run(ev: dict) -> list[dict]:
    run = ev["workflow_run"]
    if run.get("conclusion") != "failure":
        return []
    commit = run.get("head_commit") or {}
    return [embed(f"❌ CI failed: {run.get('name')}", run.get("html_url"), RED,
                  short(first_line(commit.get("message")), 200),
                  [("Branch", f"`{run.get('head_branch')}`", True),
                   ("Triggered by", who((run.get("actor") or {}).get("login")), True)])]


HANDLERS = {
    "push": on_push,
    "pull_request": on_pull_request,
    "pull_request_review": on_review,
    "issues": on_issue,
    "workflow_run": on_workflow_run,
}


def build_event(name: str, ev: dict) -> dict | None:
    handler = HANDLERS.get(name)
    embeds = handler(ev) if handler else []
    return payload(embeds) if embeds else None


# ----------------------------------------------------------------------------- digests

def collect(gh, now: datetime, days: int, weekly: bool) -> dict:
    """Read everything a digest needs from GitHub. Kept apart from formatting so it can be tested."""
    import dashboard_lib as lib

    since = now - timedelta(days=days)
    stamp = since.strftime("%Y-%m-%dT%H:%M:%SZ")
    default = gh.get("")["default_branch"]
    branches = [b["name"] for b in gh.get_all("/branches")]

    commits: dict[str, dict] = {}
    for name in branches:
        for c in gh.get_all("/commits", sha=name, since=stamp):
            if len(c.get("parents", [])) < 2:
                commits.setdefault(c["sha"], {"sha": c["sha"], "branch": name,
                                              "login": (c.get("author") or {}).get("login"),
                                              "message": c["commit"]["message"], "url": c["html_url"]})

    open_prs = []
    for pr in gh.get_all("/pulls", state="open"):
        decision = lib.review_decision(gh.get(f"/pulls/{pr['number']}/reviews"))
        open_prs.append({"number": pr["number"], "title": pr["title"], "url": pr["html_url"],
                         "login": pr["user"]["login"], "draft": pr.get("draft", False),
                         "created_at": pr["created_at"], "updated_at": pr["updated_at"],
                         "reviewers": [r["login"] for r in pr.get("requested_reviewers", [])],
                         "decision": decision})

    merged = [{"number": p["number"], "title": p["title"], "login": p["user"]["login"]}
              for p in gh.get("/pulls", state="closed", sort="updated", direction="desc", per_page=100)
              if p.get("merged_at") and parse_time(p["merged_at"]) >= since]

    issues = [i for i in gh.get_all("/issues", state="open") if "pull_request" not in i]
    closed = [{"number": i["number"], "title": i["title"],
               "logins": [a["login"] for a in i.get("assignees") or []]}
              for i in gh.get_all("/issues", state="closed", since=stamp)
              if "pull_request" not in i and parse_time(i.get("closed_at")) and parse_time(i["closed_at"]) >= since]

    milestones = [{"title": m["title"], "open": m["open_issues"], "closed": m["closed_issues"],
                   "due_on": m.get("due_on"), "url": m["html_url"]}
                  for m in gh.get_all("/milestones", state="open", sort="due_on")]

    data = {"now": now.isoformat(), "days": days, "weekly": weekly, "default_branch": default,
            "commits": list(commits.values()), "open_prs": open_prs, "merged": merged,
            "unassigned": [{"number": i["number"], "title": i["title"]} for i in issues if not i.get("assignees")],
            "no_milestone": [{"number": i["number"], "title": i["title"]} for i in issues if not i.get("milestone")],
            "open_issues": len(issues), "closed": closed, "milestones": milestones,
            "branches": [], "ci": {}}

    if weekly:
        for name in branches:
            if name == default:
                continue
            try:
                cmp = gh.get(f"/compare/{default}...{name}")
            except urllib.error.HTTPError:
                continue
            if cmp.get("ahead_by", 0) > 0:
                last = (cmp.get("commits") or [{}])[-1]
                data["branches"].append({"name": name, "ahead": cmp["ahead_by"], "behind": cmp.get("behind_by", 0),
                                         "login": (last.get("author") or {}).get("login"),
                                         "date": ((last.get("commit") or {}).get("author") or {}).get("date")})
        runs = gh.get("/actions/runs", created=f"%3E%3D{since.date().isoformat()}", per_page=100)  # ">="
        for run in runs.get("workflow_runs", []):
            tally = data["ci"].setdefault(run["name"], {"success": 0, "failure": 0, "other": 0})
            key = run.get("conclusion") if run.get("conclusion") in ("success", "failure") else "other"
            tally[key] += 1
    return data


def build_digest(data: dict) -> dict:
    now = parse_time(data["now"])
    weekly = data["weekly"]
    span = "this week" if weekly else "in the last 24 hours"
    title = (f"📊 Weekly digest — week ending {now:%b %d}" if weekly else f"📊 Daily digest — {now:%a %b %d}")

    # Highlights: the few things worth acting on today.
    unlinked = [c for c in data["commits"] if not linked(c["message"])]
    waiting = [p for p in data["open_prs"] if not p["draft"] and p["decision"] == "REVIEW_REQUIRED"
               and (now - parse_time(p["created_at"])) >= timedelta(days=REVIEW_WAIT_DAYS)]
    stale = [p for p in data["open_prs"] if (now - parse_time(p["updated_at"])) >= timedelta(days=STALE_DAYS)]
    changes = [p for p in data["open_prs"] if p["decision"] == "CHANGES_REQUESTED"]
    overdue = [m for m in data["milestones"] if m["open"] and m["due_on"] and parse_time(m["due_on"]) < now]
    counts = {login: 0 for login in MEMBERS}
    for c in data["commits"]:
        if c["login"] in counts:
            counts[c["login"]] += 1
    quiet = [who(login) for login, n in counts.items() if n == 0]

    highlights = [f"**{len(data['commits'])}** commits, **{len(data['merged'])}** PRs merged and "
                  f"**{len(data['closed'])}** issues closed {span}."]
    if waiting:
        highlights.append(f"⏳ {len(waiting)} PR(s) waiting {REVIEW_WAIT_DAYS}+ days for a first review.")
    if changes:
        highlights.append(f"🛑 {len(changes)} PR(s) have changes requested.")
    if stale:
        highlights.append(f"🧊 {len(stale)} PR(s) with no activity for {STALE_DAYS}+ days.")
    if unlinked:
        highlights.append(f"⚠️ {len(unlinked)} commit(s) not linked to a user story or issue.")
    if overdue:
        highlights.append("🚨 Overdue milestone(s): " + ", ".join(m["title"] for m in overdue))
    if data["unassigned"]:
        highlights.append(f"👤 {len(data['unassigned'])} open issue(s) have no assignee.")
    if data["no_milestone"]:
        highlights.append(f"🏁 {len(data['no_milestone'])} open issue(s) have no milestone.")
    if quiet:
        highlights.append(f"💤 No commits {span} from: " + ", ".join(quiet))
    embeds = [embed(title, REPO_URL, LIME, "\n".join(highlights))]

    # Who did what.
    fields = []
    for login, name in MEMBERS.items():
        prs = sum(1 for p in data["merged"] if p["login"] == login)
        done = sum(1 for i in data["closed"] if login in i["logins"])
        mine = sum(1 for p in data["open_prs"] if p["login"] == login)
        fields.append((name, f"{counts[login]} commits · {prs} PRs merged\n{done} issues closed · {mine} PRs open", True))
    embeds.append(embed(f"👥 Team activity {span}", color=BLUE, fields=fields))

    # Open pull requests, oldest first.
    looks = {"APPROVED": "✅ approved", "CHANGES_REQUESTED": "🛑 changes requested", "REVIEW_REQUIRED": "⏳ awaiting review"}
    prs = sorted(data["open_prs"], key=lambda p: p["created_at"])
    lines = [f"[#{p['number']}]({p['url']}) {short(p['title'], 55)} — {MEMBERS.get(p['login'], '@' + p['login'])}"
             f" · {age(p['created_at'], now)} · {'📝 draft' if p['draft'] else looks[p['decision']]}"
             + (f" · reviewer: {', '.join(MEMBERS.get(r, '@' + r) for r in p['reviewers'])}" if p["reviewers"] else "")
             for p in prs[:MAX_LINES]]
    if len(prs) > MAX_LINES:
        lines.append(f"…and {len(prs) - MAX_LINES} more")
    embeds.append(embed(f"🔀 Open pull requests ({len(prs)})", f"{REPO_URL}/pulls", AMBER if prs else GREEN,
                        "\n".join(lines) or "No open pull requests. 🎉"))

    # Milestone progress.
    lines = []
    for m in data["milestones"]:
        total = m["open"] + m["closed"]
        pct = round(100 * m["closed"] / total) if total else 0
        due = parse_time(m["due_on"])
        when = f" · due {due:%b %d}" + (" 🚨" if due < now and m["open"] else "") if due else ""
        lines.append(f"**[{m['title']}]({m['url']})**\n{bar(m['closed'], total)} {pct}% ({m['closed']}/{total}){when}")
    embeds.append(embed("🏁 Milestones", f"{REPO_URL}/milestones", PURPLE, "\n".join(lines) or "No open milestones."))

    if weekly:
        rows = sorted(data["branches"], key=lambda b: b["date"] or "", reverse=True)
        lines = [f"`{b['name']}` — {b['ahead']} ahead, {b['behind']} behind · "
                 f"{MEMBERS.get(b['login'], b['login'] or '?')} · last commit {age(b['date'], now)} ago"
                 for b in rows[:15]]
        if len(rows) > 15:
            lines.append(f"…and {len(rows) - 15} more")
        embeds.append(embed(f"🌿 Branches not merged into {data['default_branch']} ({len(rows)})",
                            f"{REPO_URL}/branches", GREY, "\n".join(lines) or "Every branch is merged."))
        lines = [f"{'✅' if t['failure'] == 0 else '❌'} **{name}** — {t['success']} passed, {t['failure']} failed"
                 for name, t in sorted(data["ci"].items())]
        embeds.append(embed("🧪 CI health this week", f"{REPO_URL}/actions",
                            RED if any(t["failure"] for t in data["ci"].values()) else GREEN,
                            "\n".join(lines) or "No workflow runs this week."))
    return payload(embeds)


# ----------------------------------------------------------------------------- sending

def send(url: str, body: dict) -> None:
    data = json.dumps(body).encode()
    for attempt in range(3):
        req = urllib.request.Request(url, data=data, method="POST", headers={
            "Content-Type": "application/json",
            "User-Agent": f"DiscordBot ({REPO_URL}, 1.0)",
        })
        try:
            with urllib.request.urlopen(req, timeout=30):
                return
        except urllib.error.HTTPError as err:
            if err.code == 429 and attempt < 2:
                time.sleep(float(json.loads(err.read() or b"{}").get("retry_after", 1)))
                continue
            hint = {401: " The webhook token is wrong; copy the URL again from Discord.",
                    404: " Discord has no such webhook: it was deleted, or the URL is incomplete."
                         " Copy it again with Discord's 'Copy Webhook URL' button."}.get(err.code, "")
            sys.exit(f"Discord rejected the message: HTTP {err.code} {err.read()[:300]!r}.{hint}")


def deliver(body: dict | None, webhook: str | None, dry_run: bool) -> int:
    if body is None:
        print("Nothing to post for this event.")
        return 0
    if dry_run:
        print(json.dumps(body, indent=2, ensure_ascii=False))
        return 0
    if not webhook:
        print("No Discord webhook configured (set the DISCORD_WEBHOOK_URL secret); skipping.")
        return 0
    if not WEBHOOK.match(webhook.strip()):
        # Never echo the value: it may be a real webhook pasted with stray text.
        sys.exit("The Discord webhook setting is not a Discord webhook URL "
                 "(expected https://discord.com/api/webhooks/...). Set it again.")
    send(webhook.strip(), body)
    print(f"Posted {len(body['embeds'])} embed(s) to Discord.")
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", choices=("event", "digest", "test"))
    ap.add_argument("period", nargs="?", choices=("daily", "weekly"), default="daily")
    ap.add_argument("--dry-run", action="store_true", help="print the payload instead of sending it")
    ap.add_argument("--event-name", default=os.environ.get("GITHUB_EVENT_NAME"))
    ap.add_argument("--event-file", default=os.environ.get("GITHUB_EVENT_PATH"))
    ap.add_argument("--repo", help="OWNER/NAME for digests (default: GITHUB_REPOSITORY or origin)")
    args = ap.parse_args(argv)

    live = os.environ.get("DISCORD_WEBHOOK_URL")
    digest_hook = os.environ.get("DISCORD_DIGEST_WEBHOOK_URL") or live

    if args.mode == "test":
        body = payload([embed("👋 SwagPc Bot is connected", REPO_URL, LIME,
                              "Commits, pull requests, issues and CI failures will show up here.")])
        return deliver(body, live, args.dry_run)

    if args.mode == "event":
        if not args.event_name or not args.event_file:
            sys.exit("Event mode needs GITHUB_EVENT_NAME and GITHUB_EVENT_PATH (or --event-name/--event-file).")
        event = json.loads(Path(args.event_file).read_text())
        return deliver(build_event(args.event_name, event), live, args.dry_run)

    import generate_dashboard as gen
    gh = gen.GitHub(gen.find_repo(args.repo), gen.find_token())
    weekly = args.period == "weekly"
    data = collect(gh, datetime.now(timezone.utc), 7 if weekly else 1, weekly)
    return deliver(build_digest(data), digest_hook, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
