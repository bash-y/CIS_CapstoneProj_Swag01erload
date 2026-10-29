#!/usr/bin/env python3
"""Export a snapshot of this repository's project data for the project dashboard.

Writes project-data.json in the shape dashboard/project-dashboard.html reads from
GitHub, so the page shows the repo's current state without a token or a manual reload.
The Pages workflow (.github/workflows/dashboard.yml) runs it on every deploy.

Usage:
  python3 scripts/export_project_snapshot.py                 # write _site/project-data.json
  python3 scripts/export_project_snapshot.py --out dashboard # write dashboard/project-data.json

Authentication and repository lookup are the same as generate_dashboard.py.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_dashboard import GitHub, find_repo, find_token  # noqa: E402

MAX_COMMITS = 300   # the dashboard shows recent activity; a year of history is more than the page needs


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def build(gh: GitHub) -> dict:
    repo = gh.get("")
    milestones = gh.get_all("/milestones", state="all")
    issues = gh.get_all("/issues", state="all")
    pulls = gh.get_all("/pulls", state="closed")
    since = (datetime.now(timezone.utc) - timedelta(days=365)).strftime("%Y-%m-%dT%H:%M:%SZ")
    commits = gh.get_all("/commits", since=since)[:MAX_COMMITS]

    return {
        "title": repo["full_name"],
        "sub": repo.get("description") or "GitHub repository",
        "url": repo["html_url"],
        "branch": repo["default_branch"],
        "mrPrefix": "#",
        "milestones": [{
            "id": m["number"], "title": m["title"],
            "due": (m.get("due_on") or "")[:10] or None, "description": m.get("description") or "",
        } for m in milestones],
        "issues": [{
            "id": i["number"], "title": i["title"], "description": i.get("body") or "",
            "assignee": (i.get("assignee") or {}).get("login"),
            "author": (i.get("user") or {}).get("login"),
            "msId": (i.get("milestone") or {}).get("number"),
            "labels": [label["name"] for label in i["labels"]],
            "closed": i["state"] == "closed", "createdAt": i["created_at"], "closedAt": i.get("closed_at"),
        } for i in issues if "pull_request" not in i],
        "merges": [{
            "id": p["number"], "title": p["title"], "ts": p["merged_at"],
            "actor": (p.get("assignee") or {}).get("login") or (p.get("user") or {}).get("login"),
        } for p in pulls if p.get("merged_at")],
        "commits": [{
            "ts": c["commit"]["author"]["date"],
            "actor": (c.get("author") or {}).get("login") or c["commit"]["author"]["name"],
            "msg": c["commit"]["message"].split("\n")[0], "sha": c["sha"][:7],
        } for c in commits],
        "generatedAt": utc_now(),
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Write the project dashboard's repo snapshot.")
    ap.add_argument("--repo", help="OWNER/NAME (default: GITHUB_REPOSITORY or the origin remote)")
    ap.add_argument("--out", default="_site", help="output folder (default: _site)")
    args = ap.parse_args(argv)

    data = build(GitHub(find_repo(args.repo), find_token()))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    (out / "project-data.json").write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Snapshot: {len(data['milestones'])} milestones, {len(data['issues'])} issues, "
          f"{len(data['merges'])} merged PRs, {len(data['commits'])} commits -> {out / 'project-data.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
