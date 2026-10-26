#!/usr/bin/env python3
"""Build the project dashboard from your GitHub repository.

Usage:
  python3 scripts/generate_dashboard.py            # read GitHub, write the site to _site/
  python3 scripts/generate_dashboard.py --check    # only validate dashboard.config.json
  python3 scripts/generate_dashboard.py --demo     # write the site with made-up sample data
  python3 scripts/generate_dashboard.py --out DIR  # write the site somewhere else

Authentication, first match wins: the GH_TOKEN or GITHUB_TOKEN environment variable,
then the token of the GitHub CLI (run "gh auth login" once). The repository comes from
--repo OWNER/NAME, then GITHUB_REPOSITORY, then your "origin" git remote.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dashboard_lib as lib  # noqa: E402

API = "https://api.github.com"
PAGE_FILES = ("index.html", "guide.html")
MAX_PAGES = 20


# ----------------------------------------------------------------------------- GitHub access

def find_token() -> str:
    for var in ("GH_TOKEN", "GITHUB_TOKEN"):
        if os.environ.get(var):
            return os.environ[var]
    try:
        out = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, check=True)
        return out.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        sys.exit("No GitHub token found. Run \"gh auth login\" once, or set GH_TOKEN.")


def find_repo(arg: str | None) -> str:
    if arg:
        return arg
    if os.environ.get("GITHUB_REPOSITORY"):
        return os.environ["GITHUB_REPOSITORY"]
    try:
        url = subprocess.run(["git", "remote", "get-url", "origin"], capture_output=True,
                             text=True, check=True, cwd=lib.ROOT).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        sys.exit("Cannot tell which repository to read. Pass --repo OWNER/NAME.")
    m = re.search(r"github\.com[:/]([^/]+/[^/]+?)(\.git)?$", url)
    if not m:
        sys.exit(f"The origin remote is not a GitHub URL: {url}")
    return m.group(1)


class GitHub:
    def __init__(self, repo: str, token: str):
        self.repo, self.token = repo, token

    def _request(self, url: str) -> tuple[object, str]:
        req = urllib.request.Request(url, headers={
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "project-dashboard",
        })
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.load(resp), resp.headers.get("Link", "")

    def get(self, path: str, **params) -> object:
        query = "&".join(f"{k}={v}" for k, v in params.items())
        url = f"{API}/repos/{self.repo}{path}" + (f"?{query}" if query else "")
        return self._request(url)[0]

    def get_all(self, path: str, key: str | None = None, **params) -> list:
        """Follow GitHub's Link headers. key names the list inside an object response."""
        params.setdefault("per_page", 100)
        query = "&".join(f"{k}={v}" for k, v in params.items())
        url, items = f"{API}/repos/{self.repo}{path}?{query}", []
        for _ in range(MAX_PAGES):
            body, link = self._request(url)
            items.extend(body[key] if key else body)
            m = re.search(r'<([^>]+)>;\s*rel="next"', link)
            if not m:
                break
            url = m.group(1)
        return items


# ----------------------------------------------------------------------------- collection

def collect(gh: GitHub, cfg: dict) -> dict:
    now = lib.utc_now()
    warnings: list[str] = []
    layer_ids = {layer["id"] for layer in cfg["layers"]}
    activity = lib.activity_days(now)
    since_90 = (now - timedelta(days=90)).strftime("%Y-%m-%dT%H:%M:%SZ")

    # Issues and pull requests come back together from the issues endpoint.
    everything = gh.get_all("/issues", state="all", sort="created", direction="asc")
    issues = [i for i in everything if "pull_request" not in i]
    for item in everything:
        if "pull_request" in item:
            bump(activity, (item["pull_request"] or {}).get("merged_at"))
        else:
            bump(activity, item.get("closed_at"))

    # Open pull requests with their checks and reviews.
    prs = []
    for pr in gh.get_all("/pulls", state="open"):
        detail = gh.get(f"/pulls/{pr['number']}")
        try:
            runs = gh.get_all(f"/commits/{pr['head']['sha']}/check-runs", key="check_runs")
        except urllib.error.HTTPError:
            runs = []
        checks = {"passed": 0, "failed": 0, "pending": 0, "runs": []}
        for run in runs:
            if run["status"] != "completed":
                state = "pending"
            elif run["conclusion"] in ("success", "neutral", "skipped"):
                state = "passed"
            else:
                state = "failed"
            checks[state] += 1
            checks["runs"].append({"name": run["name"], "state": state})
        review = lib.review_decision(gh.get_all(f"/pulls/{pr['number']}/reviews"))
        prs.append({
            "number": pr["number"], "title": pr["title"], "url": pr["html_url"],
            "author": (pr.get("user") or {}).get("login", ""), "draft": pr.get("draft", False),
            "created_at": pr["created_at"], "layer": lib.layer_of(pr, layer_ids),
            "additions": detail.get("additions", 0), "deletions": detail.get("deletions", 0),
            "checks": checks, "review": review,
            "severity": lib.pr_severity(checks, review, pr.get("draft", False)),
        })

    # Milestones.
    milestones = []
    for ms in gh.get_all("/milestones", state="all", sort="due_on"):
        total = ms["open_issues"] + ms["closed_issues"]
        milestones.append({
            "title": ms["title"], "description": ms.get("description") or "", "url": ms["html_url"],
            "state": ms["state"], "due_on": ms.get("due_on"), "open": ms["open_issues"],
            "closed": ms["closed_issues"], "total": total,
            "pct": round(100 * ms["closed_issues"] / total) if total else 0,
        })

    # Open stories (issues labeled type:story) with their native sub-issues.
    stories, other_open = [], []
    for issue in issues:
        if issue["state"] != "open":
            continue
        base = {
            "number": issue["number"], "title": issue["title"], "url": issue["html_url"],
            "layer": lib.layer_of(issue, layer_ids), "priority": lib.priority_of(issue),
            "milestone": (issue.get("milestone") or {}).get("title", ""),
            "assignees": [a["login"] for a in issue.get("assignees", [])],
        }
        if lib.STORY_LABEL not in lib.label_names(issue):
            other_open.append(base)
            continue
        subs = []
        summary = issue.get("sub_issues_summary") or {}
        if summary.get("total"):
            try:
                for sub in gh.get_all(f"/issues/{issue['number']}/sub_issues"):
                    subs.append({"number": sub["number"], "title": sub["title"],
                                 "url": sub["html_url"], "done": sub["state"] == "closed"})
            except urllib.error.HTTPError as exc:
                warnings.append(f"Sub-issues for #{issue['number']} could not be read ({exc.code}).")
        done = sum(1 for s in subs if s["done"])
        stories.append({**base, "subs": subs, "sub_total": len(subs), "sub_closed": done,
                        "pct": round(100 * done / len(subs)) if subs else 0})

    # Failed workflow runs in the last 72 hours.
    failures = []
    since_72 = (now - timedelta(hours=72)).strftime("%Y-%m-%dT%H:%M:%SZ")
    try:
        runs = gh.get("/actions/runs", status="failure", per_page=50, created=f">={since_72}")
        for run in runs.get("workflow_runs", []):
            failures.append({
                "workflow": run["name"], "branch": run.get("head_branch") or "",
                "event": run["event"], "url": run["html_url"], "created_at": run["created_at"],
                "prs": [p["number"] for p in run.get("pull_requests", [])],
            })
    except urllib.error.HTTPError as exc:
        warnings.append(f"Workflow runs could not be read ({exc.code}); give the token actions: read.")

    # Commits on the default branch in the last 90 days.
    commits = []
    try:
        commits = gh.get_all("/commits", since=since_90)
    except urllib.error.HTTPError as exc:
        if exc.code != 409:  # 409 means the repository is still empty
            raise
    for commit in commits:
        bump(activity, commit["commit"]["committer"]["date"])

    contributors = contributor_stats(gh, warnings)
    members = lib.summarize_members(cfg, contributors, commits, everything, now)
    if any(not m["linked"] for m in members):
        warnings.append("Some commits use an email that is not linked to a GitHub account; "
                        "see the guide, section \"Commits by member\".")

    layers, unassigned = lib.summarize_layers(cfg, issues, prs)
    return assemble(cfg, gh.repo, now, demo=False, layers=layers, unassigned=unassigned,
                    prs=prs, milestones=milestones, stories=stories, other_open=other_open,
                    failures=failures, activity=activity, members=members, warnings=warnings)


def contributor_stats(gh: GitHub, warnings: list[str]) -> list:
    """GitHub computes these numbers lazily and answers 202 until they are ready."""
    import time
    for _ in range(6):
        try:
            req_body = gh.get("/stats/contributors")
        except urllib.error.HTTPError as exc:
            warnings.append(f"Contributor statistics could not be read ({exc.code}).")
            return []
        if isinstance(req_body, list):
            return req_body
        time.sleep(5)
    warnings.append("GitHub was still computing contributor statistics; lines changed will fill in next refresh.")
    return []


def bump(activity: dict, stamp: str | None) -> None:
    lib.bump(activity, stamp)


def assemble(cfg, repo, now, *, demo, layers, unassigned, prs, milestones, stories,
             other_open, failures, activity, members, warnings) -> dict:
    total_closed = sum(layer["closed_issues"] for layer in layers)
    total = total_closed + sum(layer["open_issues"] for layer in layers) + unassigned["open_issues"]
    return {
        "schema": 1,
        "demo": demo,
        "generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "repo": repo,
        "repo_url": f"https://github.com/{repo}",
        "refresh_url": f"https://github.com/{repo}/actions/workflows/dashboard-refresh.yml",
        "project": cfg["project"],
        "stack_tiers": lib.STACK_TIERS,
        "layers": layers,
        "unassigned": unassigned,
        "open_prs": prs,
        "milestones": milestones,
        "stories": stories,
        "open_issues": other_open,
        "recent_failures": failures,
        "activity": activity,
        "members": members,
        "totals": {
            "open_prs": len(prs),
            "ready_prs": sum(1 for p in prs if p["severity"] == "green"),
            "attention_prs": sum(1 for p in prs if p["severity"] == "red"),
            "open_stories": len(stories),
            "open_issues": len(other_open) + len(stories),
            "failures_72h": len(failures),
            "pct_complete": round(100 * total_closed / total) if total else 0,
            "commits_90d": sum(m["commits_90d"] for m in members),
        },
        "warnings": warnings,
    }


# ----------------------------------------------------------------------------- demo data

def demo_data(cfg: dict) -> dict:
    """Made-up data shaped like the real thing, so the page renders before the first refresh."""
    now = lib.utc_now()
    repo = "your-org/your-repo"
    url = f"https://github.com/{repo}"
    layer_ids = [layer["id"] for layer in cfg["layers"]]
    pick = lambda i: layer_ids[i % len(layer_ids)]  # noqa: E731

    issues, n = [], 1
    for i, lid in enumerate(layer_ids):
        for j in range(3 + i % 3):
            state = "closed" if j < 2 + i % 2 else "open"
            issues.append({"number": n, "state": state, "labels": [{"name": lib.layer_label(lid)}]})
            n += 1
    issues.append({"number": n, "state": "open", "labels": []})

    def pr(num, title, layer, checks, review, draft=False):
        sev = lib.pr_severity(checks, review, draft)
        return {"number": num, "title": title, "url": f"{url}/pull/{num}", "author": "student-a",
                "draft": draft, "created_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"), "layer": layer,
                "additions": 120, "deletions": 14, "checks": checks, "review": review, "severity": sev}

    ok = {"passed": 3, "failed": 0, "pending": 0,
          "runs": [{"name": n, "state": "passed"} for n in ("dashboard-checks", "layer-tests", "all-green")]}
    bad = {"passed": 1, "failed": 1, "pending": 0,
           "runs": [{"name": "dashboard-checks", "state": "passed"}, {"name": "layer-tests", "state": "failed"}]}
    wait = {"passed": 1, "failed": 0, "pending": 1,
            "runs": [{"name": "dashboard-checks", "state": "passed"}, {"name": "layer-tests", "state": "pending"}]}
    prs = [
        pr(41, "Add sign-in form and session handling", pick(0), ok, "APPROVED"),
        pr(43, "Create records table and seed script", pick(2), bad, "CHANGES_REQUESTED"),
        pr(44, "Return 404 for unknown record IDs", pick(1), wait, "REVIEW_REQUIRED"),
        pr(45, "Draft: container health checks", None, wait, "REVIEW_REQUIRED", draft=True),
    ]
    milestones = [
        {"title": "Sprint 1: Walking skeleton", "description": "Every layer exists and talks to the next one.",
         "url": f"{url}/milestone/1", "state": "closed", "due_on": None, "open": 0, "closed": 8, "total": 8, "pct": 100},
        {"title": "Sprint 2: Core features", "description": "The three user stories the project is graded on.",
         "url": f"{url}/milestone/2", "state": "open", "due_on": None, "open": 5, "closed": 7, "total": 12, "pct": 58},
        {"title": "Sprint 3: Hardening and demo", "description": "Security review, tests and the final demo.",
         "url": f"{url}/milestone/3", "state": "open", "due_on": None, "open": 9, "closed": 1, "total": 10, "pct": 10},
    ]

    def sub(num, title, done):
        return {"number": num, "title": title, "url": f"{url}/issues/{num}", "done": done}

    stories = [
        {"number": 30, "title": "As a user I can sign in and see only my own records", "url": f"{url}/issues/30",
         "layer": pick(3), "priority": "P1", "milestone": "Sprint 2: Core features", "assignees": ["student-a"],
         "subs": [sub(31, "Login form", True), sub(32, "Password hashing", True), sub(33, "Role check on every endpoint", False)]},
        {"number": 34, "title": "As a user I can search records by keyword", "url": f"{url}/issues/34",
         "layer": pick(1), "priority": "P2", "milestone": "Sprint 2: Core features", "assignees": ["student-b"],
         "subs": [sub(35, "Search endpoint", True), sub(36, "Search box on the page", False)]},
        {"number": 37, "title": "As the team we can deploy with one command", "url": f"{url}/issues/37",
         "layer": pick(4), "priority": "P2", "milestone": "Sprint 3: Hardening and demo", "assignees": [],
         "subs": []},
    ]
    for s in stories:
        done = sum(1 for x in s["subs"] if x["done"])
        s.update(sub_total=len(s["subs"]), sub_closed=done, pct=round(100 * done / len(s["subs"])) if s["subs"] else 0)
    other_open = [
        {"number": 38, "title": "Error page shows a stack trace", "url": f"{url}/issues/38", "layer": pick(1),
         "priority": "P1", "milestone": "Sprint 3: Hardening and demo", "assignees": ["student-c"]},
        {"number": 39, "title": "Write the README setup steps", "url": f"{url}/issues/39", "layer": None,
         "priority": "", "milestone": "", "assignees": []},
    ]
    failures = [{"workflow": "Build tests", "branch": "feature/records-table", "event": "pull_request",
                 "url": f"{url}/actions", "created_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"), "prs": [43]}]

    activity = lib.activity_days(now)
    for i, day in enumerate(sorted(activity)):
        if i > 20:
            activity[day] = (i * 7 + i // 3) % 9 if (i % 7) not in (5, 6) else (i % 2)

    members = demo_members(cfg, now)
    layers, unassigned = lib.summarize_layers(cfg, issues, prs)
    return assemble(cfg, repo, now, demo=True, layers=layers, unassigned=unassigned, prs=prs,
                    milestones=milestones, stories=stories, other_open=other_open,
                    failures=failures, activity=activity, members=members, warnings=[])


def demo_members(cfg: dict, now) -> list[dict]:
    roster = cfg.get("members") or []
    people = [(m.get("github", ""), m.get("name", ""), m.get("role", "")) for m in roster] or [
        ("student-a", "Student A", "Frontend"), ("student-b", "Student B", "Backend"),
        ("student-c", "Student C", "Data and security"), ("student-d", "Student D", "DevOps")]
    # The last sample member has no commits, to show the "No commits in 90 days" flag.
    shape = [(42, 1810, 420), (35, 2210, 690), (19, 640, 110), (0, 0, 0)]
    weeks = lib.week_starts(now)
    out = []
    for i, (login, name, role) in enumerate(people):
        c, a, d = shape[i % len(shape)]
        recent = round(c * 0.7)  # most of the commits fall inside the last 12 weeks
        raw = [1 + (w * (i + 3)) % 5 for w in range(len(weeks))]
        weekly = [recent * r // sum(raw) for r in raw]
        weekly[-1] += recent - sum(weekly)
        out.append({"login": login, "name": name or login, "role": role, "linked": True, "on_roster": True,
                    "commits_total": c, "commits_90d": sum(weekly), "additions": a, "deletions": d,
                    "prs_opened": c // 8, "prs_merged": c // 10, "issues_closed": c // 6,
                    "last_commit": now.strftime("%Y-%m-%dT%H:%M:%SZ") if c else None,
                    "weekly": [{"week": wk, "commits": n} for wk, n in zip(weeks, weekly)]})
    return out


# ----------------------------------------------------------------------------- output

def write_site(data: dict, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    src = lib.ROOT / "dashboard"
    if out.resolve() != src.resolve():
        for name in PAGE_FILES:
            shutil.copyfile(src / name, out / name)
    text = json.dumps(data, indent=2, ensure_ascii=False)
    (out / "data.json").write_text(text + "\n", encoding="utf-8")
    # data.js lets index.html load the data straight from disk (file://), where fetch() is blocked.
    (out / "data.js").write_text(f"window.DASHBOARD_DATA = {text};\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="validate dashboard.config.json and stop")
    ap.add_argument("--demo", action="store_true", help="use made-up sample data instead of GitHub")
    ap.add_argument("--out", default="_site", help="output folder (default: _site)")
    ap.add_argument("--repo", help="OWNER/NAME of the repository to read")
    args = ap.parse_args(argv)

    cfg = lib.load_config()
    errors = lib.validate_config(cfg)
    if errors:
        print("dashboard.config.json has problems:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    if args.check:
        print(f"dashboard.config.json is valid: {len(cfg['layers'])} layers across "
              f"{len({layer['stack_tier'] for layer in cfg['layers']})} stack tiers.")
        return 0

    out = (lib.ROOT / args.out) if not Path(args.out).is_absolute() else Path(args.out)
    data = demo_data(cfg) if args.demo else collect(GitHub(find_repo(args.repo), find_token()), cfg)
    write_site(data, out)
    print(f"Dashboard written to {out / 'index.html'}")
    for w in data["warnings"]:
        print(f"warning: {w}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
