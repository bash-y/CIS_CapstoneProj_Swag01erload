"""Tests for the dashboard tooling. Run with: python3 -m unittest discover -s tests -v

When DASHBOARD_SITE points at a built site folder, the site is checked as well.
"""

import copy
import json
import os
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import dashboard_lib as lib  # noqa: E402
import generate_dashboard as gen  # noqa: E402


class ConfigRules(unittest.TestCase):
    def setUp(self):
        self.cfg = lib.load_config()

    def test_shipped_config_is_valid(self):
        self.assertEqual(lib.validate_config(self.cfg), [])

    def test_unknown_stack_tier_is_rejected(self):
        cfg = copy.deepcopy(self.cfg)
        cfg["layers"][0]["stack_tier"] = "frontend-stuff"
        self.assertTrue(any("stack_tier" in e for e in lib.validate_config(cfg)))

    def test_layers_must_span_three_tiers(self):
        cfg = copy.deepcopy(self.cfg)
        for layer in cfg["layers"]:
            layer["stack_tier"] = "application"
        self.assertTrue(any("stack tier" in e for e in lib.validate_config(cfg)))

    def test_layer_needs_a_technology(self):
        cfg = copy.deepcopy(self.cfg)
        cfg["layers"][0]["technologies"] = []
        self.assertTrue(any("technology" in e for e in lib.validate_config(cfg)))

    def test_duplicate_layer_id_is_rejected(self):
        cfg = copy.deepcopy(self.cfg)
        cfg["layers"][1]["id"] = cfg["layers"][0]["id"]
        self.assertTrue(any("twice" in e for e in lib.validate_config(cfg)))

    def test_bad_member_login_is_rejected(self):
        cfg = copy.deepcopy(self.cfg)
        cfg["members"] = [{"github": "has spaces"}]
        self.assertTrue(any("members[0]" in e for e in lib.validate_config(cfg)))


class Shaping(unittest.TestCase):
    def test_review_decision_keeps_latest_per_reviewer(self):
        reviews = [{"user": {"login": "a"}, "state": "CHANGES_REQUESTED"},
                   {"user": {"login": "a"}, "state": "APPROVED"}]
        self.assertEqual(lib.review_decision(reviews), "APPROVED")

    def test_failed_check_makes_pr_red(self):
        self.assertEqual(lib.pr_severity({"failed": 1, "pending": 0}, "APPROVED", False), "red")
        self.assertEqual(lib.pr_severity({"failed": 0, "pending": 0}, "APPROVED", False), "green")
        self.assertEqual(lib.pr_severity({"failed": 0, "pending": 0}, "APPROVED", True), "amber")

    def test_members_count_commits_and_flag_unlinked_authors(self):
        now = datetime(2030, 3, 6, tzinfo=timezone.utc)
        cfg = {"members": [{"github": "ana", "name": "Ana"}, {"github": "ben", "name": "Ben"}]}
        stamp = "2030-03-04T10:00:00Z"
        commits = [
            {"author": {"login": "ana"}, "commit": {"author": {"name": "Ana", "date": stamp}}},
            {"author": {"login": "ana"}, "commit": {"author": {"name": "Ana", "date": stamp}}},
            {"author": None, "commit": {"author": {"name": "laptop-user", "date": stamp}}},
        ]
        contributors = [{"author": {"login": "ana"}, "total": 9, "weeks": [{"a": 50, "d": 5, "c": 9}]}]
        items = [{"user": {"login": "ana"}, "pull_request": {"merged_at": stamp}, "state": "closed"}]
        out = {m["name"]: m for m in lib.summarize_members(cfg, contributors, commits, items, now)}
        self.assertEqual(out["Ana"]["commits_total"], 9)
        self.assertEqual(out["Ana"]["commits_90d"], 2)
        self.assertEqual(out["Ana"]["prs_merged"], 1)
        self.assertEqual(out["Ana"]["weekly"][-1]["commits"], 2)
        self.assertEqual(out["Ben"]["commits_90d"], 0)          # roster member with no commits still listed
        self.assertFalse(out["laptop-user"]["linked"])         # unlinked git email is surfaced
        self.assertNotIn("email", json.dumps(out))


class DemoBuild(unittest.TestCase):
    def test_demo_data_has_every_panel(self):
        data = gen.demo_data(lib.load_config())
        for key in ("project", "layers", "open_prs", "milestones", "stories", "open_issues",
                    "recent_failures", "activity", "members", "totals"):
            self.assertIn(key, data)
        tiers = [layer["stack_tier"] for layer in data["layers"]]
        self.assertEqual(tiers, sorted(tiers, key=lib.TIER_ORDER.index))


@unittest.skipUnless(os.environ.get("DASHBOARD_SITE"), "set DASHBOARD_SITE to check a built site")
class BuiltSite(unittest.TestCase):
    def setUp(self):
        self.site = ROOT / os.environ["DASHBOARD_SITE"]

    def test_files_exist(self):
        for name in ("index.html", "guide.html", "data.js", "data.json"):
            self.assertTrue((self.site / name).is_file(), name)

    def test_data_js_matches_data_json(self):
        js = (self.site / "data.js").read_text(encoding="utf-8")
        prefix = "window.DASHBOARD_DATA = "
        self.assertTrue(js.startswith(prefix))
        self.assertEqual(json.loads(js[len(prefix):].rstrip().rstrip(";")),
                         json.loads((self.site / "data.json").read_text(encoding="utf-8")))


if __name__ == "__main__":
    unittest.main()
