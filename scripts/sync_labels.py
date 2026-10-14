#!/usr/bin/env python3
"""Create or update the labels the dashboard reads: one layer:<id> per layer, plus
type:story, type:task, type:bug and priority:P1 to P3. Existing labels are updated, never deleted.

Usage: python3 scripts/sync_labels.py [--repo OWNER/NAME] [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dashboard_lib as lib  # noqa: E402
from generate_dashboard import API, find_repo, find_token  # noqa: E402

TIER_COLORS = {
    "presentation": "1d76db", "application": "5319e7", "integration": "0e8a16", "data": "fbca04",
    "security": "b60205", "platform": "006b75", "delivery": "c5def5", "quality": "d4c5f9",
    "observability": "bfdadc",
}
FIXED = [
    ("type:story", "0052cc", "A user-visible goal, broken into sub-issues"),
    ("type:task", "c2e0c6", "One piece of work that fits in a single pull request"),
    ("type:bug", "d73a4a", "Something that worked and now does not"),
    ("priority:P1", "b60205", "Must be done this sprint"),
    ("priority:P2", "fbca04", "Should be done this sprint"),
    ("priority:P3", "c5def5", "Nice to have"),
]


def wanted(cfg: dict) -> list[tuple[str, str, str]]:
    labels = [(lib.layer_label(layer["id"]), TIER_COLORS[layer["stack_tier"]],
               f"{layer['stack_tier']} tier: {layer['name']}"[:100]) for layer in cfg["layers"]]
    return labels + FIXED


def call(method: str, url: str, token: str, body: dict | None = None) -> int:
    req = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body else None, headers={
        "Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json",
        "User-Agent": "project-dashboard", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status
    except urllib.error.HTTPError as exc:
        return exc.code


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    cfg = lib.load_config()
    errors = lib.validate_config(cfg)
    if errors:
        print("Fix dashboard.config.json first:\n  - " + "\n  - ".join(errors), file=sys.stderr)
        return 1
    labels = wanted(cfg)
    if args.dry_run:
        for name, color, desc in labels:
            print(f"{name:28} #{color}  {desc}")
        return 0
    repo, token = find_repo(args.repo), find_token()
    base = f"{API}/repos/{repo}/labels"
    for name, color, desc in labels:
        body = {"color": color, "description": desc}
        status = call("PATCH", f"{base}/{urllib.parse.quote(name, safe='')}", token, body)
        if status == 404:
            status = call("POST", base, token, {"name": name, **body})
        verb = "ok" if status in (200, 201) else f"failed ({status})"
        print(f"{name:28} {verb}")
        if status not in (200, 201):
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
