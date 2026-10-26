"""Shared logic for the project dashboard: config rules, label names, data shaping.

Standard library only, so the scripts run on any machine with Python 3.9 or later.
"""

from __future__ import annotations

import json
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / "dashboard.config.json"

# The stack tiers a layer may belong to, listed top of the stack first.
# Every layer a team defines must name one of these, which is what ties the
# team's layers to a real software stack.
STACK_TIERS = {
    "presentation": "What the user sees and touches: web pages, mobile screens, CLI output.",
    "application": "Business rules and services: APIs, controllers, background jobs.",
    "integration": "Connections to other systems: message queues, webhooks, third-party APIs.",
    "data": "Where information lives: databases, files, caches, data pipelines.",
    "security": "Identity, access control, secrets, encryption, hardening.",
    "platform": "Where the software runs: servers, containers, cloud, network.",
    "delivery": "How changes ship: build scripts, CI/CD workflows, releases.",
    "quality": "How the team knows it works: test suites, linters, scanners.",
    "observability": "How the team sees it running: logs, metrics, alerts, dashboards.",
}
TIER_ORDER = list(STACK_TIERS)

GITHUB_LOGIN = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$")
LAYER_ID = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
MIN_LAYERS, MAX_LAYERS, MIN_TIERS = 3, 12, 3

LAYER_LABEL_PREFIX = "layer:"
STORY_LABEL = "type:story"
PRIORITY_LABELS = ("priority:P1", "priority:P2", "priority:P3")


def load_config(path: Path = CONFIG_PATH) -> dict:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def validate_config(cfg: dict) -> list[str]:
    """Return a list of human-readable problems; an empty list means the config is valid."""
    errors: list[str] = []
    project = cfg.get("project")
    if not isinstance(project, dict) or not str(project.get("name", "")).strip():
        errors.append('"project.name" is required.')

    layers = cfg.get("layers")
    if not isinstance(layers, list):
        return errors + ['"layers" must be a list.']
    if not MIN_LAYERS <= len(layers) <= MAX_LAYERS:
        errors.append(f"Define between {MIN_LAYERS} and {MAX_LAYERS} layers (found {len(layers)}).")

    seen: set[str] = set()
    tiers: set[str] = set()
    for i, layer in enumerate(layers):
        where = f"layers[{i}]"
        if not isinstance(layer, dict):
            errors.append(f"{where} must be an object.")
            continue
        lid = layer.get("id", "")
        where = f'layer "{lid}"' if lid else where
        if not isinstance(lid, str) or not LAYER_ID.match(lid):
            errors.append(f"{where}: id must be lowercase letters, digits and single hyphens, like \"web-ui\".")
        elif lid in seen:
            errors.append(f"{where}: id is used twice.")
        seen.add(lid)
        if not str(layer.get("name", "")).strip():
            errors.append(f"{where}: name is required.")
        tier = layer.get("stack_tier")
        if tier not in STACK_TIERS:
            errors.append(f"{where}: stack_tier must be one of {', '.join(TIER_ORDER)} (found {tier!r}).")
        else:
            tiers.add(tier)
        techs = layer.get("technologies")
        if not isinstance(techs, list) or not [t for t in techs if str(t).strip()]:
            errors.append(f"{where}: list at least one technology this layer is built with.")
        for key in ("path", "build", "test"):
            if key in layer and not isinstance(layer[key], str):
                errors.append(f"{where}: {key} must be a string.")
        if layer.get("build") and not layer.get("test"):
            errors.append(f"{where}: a layer with a build command also needs a test command.")

    members = cfg.get("members", [])
    if not isinstance(members, list):
        errors.append('"members" must be a list.')
    else:
        logins: set[str] = set()
        for i, m in enumerate(members):
            login = m.get("github", "") if isinstance(m, dict) else ""
            if not isinstance(login, str) or not GITHUB_LOGIN.match(login):
                errors.append(f"members[{i}]: github must be the member's GitHub username.")
            elif login.lower() in logins:
                errors.append(f"members[{i}]: {login} is listed twice.")
            logins.add(str(login).lower())

    if len(tiers) < MIN_TIERS:
        errors.append(
            f"Your layers cover {len(tiers)} stack tier(s); a software stack needs at least {MIN_TIERS} "
            "(for example presentation, application and data)."
        )
    return errors


def layer_label(layer_id: str) -> str:
    return f"{LAYER_LABEL_PREFIX}{layer_id}"


def label_names(item: dict) -> list[str]:
    return [lab["name"] if isinstance(lab, dict) else str(lab) for lab in item.get("labels", [])]


def layer_of(item: dict, layer_ids: set[str]) -> str | None:
    """First configured layer label on an issue or PR, or None if it has none."""
    for name in label_names(item):
        if name.startswith(LAYER_LABEL_PREFIX) and name[len(LAYER_LABEL_PREFIX):] in layer_ids:
            return name[len(LAYER_LABEL_PREFIX):]
    return None


def priority_of(item: dict) -> str:
    for name in label_names(item):
        if name in PRIORITY_LABELS:
            return name.split(":", 1)[1]
    return ""


def pr_severity(checks: dict, review: str, draft: bool) -> str:
    """green = ready to merge, red = needs attention, amber = still in progress."""
    if checks.get("failed", 0) > 0 or review == "CHANGES_REQUESTED":
        return "red"
    if not draft and review == "APPROVED" and checks.get("pending", 0) == 0:
        return "green"
    return "amber"


def review_decision(reviews: list[dict]) -> str:
    """Collapse a PR's review list to one state, keeping each reviewer's latest verdict."""
    latest: dict[str, str] = {}
    for rv in reviews:
        state = rv.get("state", "")
        if state in ("APPROVED", "CHANGES_REQUESTED", "DISMISSED"):
            latest[(rv.get("user") or {}).get("login", "")] = state
    states = set(latest.values())
    if "CHANGES_REQUESTED" in states:
        return "CHANGES_REQUESTED"
    if "APPROVED" in states:
        return "APPROVED"
    return "REVIEW_REQUIRED"


def activity_days(now: datetime, days: int = 90) -> dict[str, int]:
    start = (now - timedelta(days=days - 1)).date()
    return {(start + timedelta(days=i)).isoformat(): 0 for i in range(days)}


def bump(activity: dict[str, int], stamp: str | None) -> None:
    if stamp:
        day = stamp[:10]
        if day in activity:
            activity[day] += 1


def summarize_layers(cfg: dict, issues: list[dict], prs: list[dict]) -> tuple[list[dict], dict]:
    """Per-layer counts, in stack order, plus an "unassigned" bucket for unlabeled work."""
    ids = {layer["id"] for layer in cfg["layers"]}
    rows = []
    for layer in cfg["layers"]:
        rows.append({
            "id": layer["id"], "name": layer["name"], "stack_tier": layer["stack_tier"],
            "description": layer.get("description", ""), "technologies": layer.get("technologies", []),
            "open_issues": 0, "closed_issues": 0, "open_prs": [], "pct": 0,
        })
    by_id = {r["id"]: r for r in rows}
    unassigned = {"open_issues": 0, "open_prs": 0}
    for issue in issues:
        lid = layer_of(issue, ids)
        if lid is None:
            if issue["state"] == "open":
                unassigned["open_issues"] += 1
            continue
        key = "open_issues" if issue["state"] == "open" else "closed_issues"
        by_id[lid][key] += 1
    for pr in prs:
        lid = pr.get("layer")
        if lid in by_id:
            by_id[lid]["open_prs"].append({"number": pr["number"], "title": pr["title"],
                                           "url": pr["url"], "severity": pr["severity"]})
        else:
            unassigned["open_prs"] += 1
    for r in rows:
        total = r["open_issues"] + r["closed_issues"]
        r["pct"] = round(100 * r["closed_issues"] / total) if total else 0
    rows.sort(key=lambda r: TIER_ORDER.index(r["stack_tier"]))
    return rows, unassigned


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def week_starts(now: datetime, weeks: int = 12) -> list[str]:
    """Monday of each of the last `weeks` weeks, oldest first."""
    monday = now.date() - timedelta(days=now.weekday())
    return [(monday - timedelta(weeks=weeks - 1 - i)).isoformat() for i in range(weeks)]


def summarize_members(cfg: dict, contributors: list[dict], commits: list[dict],
                      items: list[dict], now: datetime) -> list[dict]:
    """Per-member commit counts, lines changed and pull requests.

    contributors: GitHub's /stats/contributors (all-time totals, linked accounts only).
    commits: default-branch commits from the last 90 days (also catches unlinked authors).
    items: every issue and pull request in the repository.
    Email addresses are never copied into the output.
    """
    weeks = week_starts(now)
    first_week = weeks[0]
    people: dict[str, dict] = {}

    def person(key: str, login: str, name: str, linked: bool) -> dict:
        if key not in people:
            people[key] = {"login": login, "name": name or login, "role": "", "linked": linked,
                           "on_roster": False, "commits_total": 0, "commits_90d": 0,
                           "additions": 0, "deletions": 0, "prs_opened": 0, "prs_merged": 0,
                           "issues_closed": 0, "last_commit": None,
                           "weekly": {w: 0 for w in weeks}}
        return people[key]

    for m in cfg.get("members", []):
        p = person(m["github"].lower(), m["github"], m.get("name", ""), True)
        p.update(role=m.get("role", ""), on_roster=True)

    for c in contributors:
        login = (c.get("author") or {}).get("login", "")
        if not login or login.endswith("[bot]"):
            continue
        p = person(login.lower(), login, "", True)
        p["commits_total"] = c.get("total", 0)
        p["additions"] = sum(w.get("a", 0) for w in c.get("weeks", []))
        p["deletions"] = sum(w.get("d", 0) for w in c.get("weeks", []))

    for c in commits:
        login = (c.get("author") or {}).get("login", "")
        if login.endswith("[bot]"):
            continue
        git_name = c["commit"]["author"].get("name", "unknown")
        p = person(login.lower(), login, "", True) if login else person(f"git:{git_name}", "", git_name, False)
        stamp = c["commit"]["author"]["date"]
        p["commits_90d"] += 1
        if not login:
            p["commits_total"] += 1
        if p["last_commit"] is None or stamp > p["last_commit"]:
            p["last_commit"] = stamp
        day = datetime.fromisoformat(stamp.replace("Z", "+00:00")).date()
        week = (day - timedelta(days=day.weekday())).isoformat()
        if week >= first_week and week in p["weekly"]:
            p["weekly"][week] += 1

    for item in items:
        login = (item.get("user") or {}).get("login", "")
        if "pull_request" in item and login.lower() in people:
            people[login.lower()]["prs_opened"] += 1
            if (item["pull_request"] or {}).get("merged_at"):
                people[login.lower()]["prs_merged"] += 1
        elif "pull_request" not in item and item.get("state") == "closed":
            for a in item.get("assignees", []):
                if a["login"].lower() in people:
                    people[a["login"].lower()]["issues_closed"] += 1

    out = []
    for p in people.values():
        p["weekly"] = [{"week": w, "commits": n} for w, n in p["weekly"].items()]
        out.append(p)
    out.sort(key=lambda p: (-p["commits_total"], p["name"].lower()))
    return out
