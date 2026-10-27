"""Tests for the Discord notifier. Run with: python3 -m unittest discover -s tests -v"""

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import discord_notify as dn  # noqa: E402

NOW = datetime(2026, 10, 27, 13, 0, tzinfo=timezone.utc)


def iso(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def pr(number=7, **extra):
    base = {"number": number, "title": "US-9 #50: endpoint firewall", "html_url": f"https://x/pull/{number}",
            "body": "Closes #50", "user": {"login": "bash-y"}, "draft": False, "merged": False,
            "head": {"ref": "us9-endpoint-firewall"}, "base": {"ref": "main"},
            "additions": 40, "deletions": 3, "changed_files": 4}
    base.update(extra)
    return base


def issue(**extra):
    base = {"number": 45, "title": "Deploy business server", "html_url": "https://x/issues/45", "body": "",
            "user": {"login": "UiwAntHuynhCIS"}, "assignees": [{"login": "UiwAntHuynhCIS"}],
            "milestone": {"title": "M2"}, "labels": [{"name": "type:story"}],
            "created_at": "2026-10-20T10:00:00Z", "updated_at": "2026-10-27T10:00:00Z"}
    base.update(extra)
    return base


def size_ok(testcase, body):
    testcase.assertLessEqual(len(body["embeds"]), 10)
    testcase.assertLessEqual(len(json.dumps(body["embeds"])), 6000)
    testcase.assertEqual(body["allowed_mentions"], {"parse": []})


class Helpers(unittest.TestCase):
    def test_link_rule_matches_ci_check(self):
        self.assertTrue(dn.linked("US-1 #42: add bot"))
        self.assertTrue(dn.linked("#26: firewall script"))
        self.assertFalse(dn.linked("dockerworkv1"))
        self.assertFalse(dn.linked("fix typo\n\nsee #12"))  # only the subject line counts

    def test_who_uses_legal_names(self):
        self.assertEqual(dn.who("joromanii"), "Jomar Rodriguez Canales (@joromanii)")
        self.assertEqual(dn.who("UiwAntHuynhCIS"), "Anthony Huynh (@UiwAntHuynhCIS)")
        self.assertEqual(dn.who("stranger"), "@stranger")
        self.assertEqual(dn.who(None, "Bash"), "Bash")

    def test_embed_is_trimmed_to_discord_limits(self):
        e = dn.embed("t" * 400, description="d" * 9000, fields=[("n", "v" * 2000, True)] * 30)
        self.assertEqual(len(e["title"]), 256)
        self.assertLessEqual(len(e["description"]), 4000)
        self.assertEqual(len(e["fields"]), 25)
        self.assertLessEqual(len(e["fields"][0]["value"]), 1024)

    def test_bar(self):
        self.assertEqual(dn.bar(3, 6), "▰▰▰▰▰▱▱▱▱▱")
        self.assertEqual(dn.bar(0, 0), "▱" * 10)


class Events(unittest.TestCase):
    def test_push_lists_commits_and_flags_unlinked(self):
        ev = {"ref": "refs/heads/us1-discord-bot", "compare": "https://x/compare", "forced": False,
              "commits": [
                  {"id": "a" * 40, "url": "u1", "message": "US-1 #42: add bot", "author": {"username": "bash-y"}},
                  {"id": "b" * 40, "url": "u2", "message": "wip", "author": {"name": "Bash Cadena"}},
                  {"id": "c" * 40, "url": "u3", "message": "Merge branch 'main'", "author": {"username": "bash-y"}},
              ]}
        body = dn.build_event("push", ev)
        e = body["embeds"][0]
        self.assertIn("2 new commits on us1-discord-bot", e["title"])
        self.assertIn("Sebastian Cadena (@bash-y)", e["description"])
        self.assertIn("Bash Cadena  ⚠️ no US/issue", e["description"])
        self.assertNotIn("Merge", e["description"])
        self.assertEqual(e["color"], dn.AMBER)
        self.assertIn("1 not linked", e["footer"]["text"])
        size_ok(self, body)

    def test_push_with_only_merges_or_deleted_branch_posts_nothing(self):
        merges = {"ref": "refs/heads/main", "commits": [{"id": "a" * 40, "message": "Merge pull request #1"}]}
        self.assertIsNone(dn.build_event("push", merges))
        self.assertIsNone(dn.build_event("push", {"ref": "refs/heads/x", "deleted": True, "commits": []}))
        self.assertIsNone(dn.build_event("push", {"ref": "refs/tags/v1", "commits": [{"id": "a" * 40, "message": "x"}]}))

    def test_push_caps_long_lists(self):
        commits = [{"id": f"{i:040d}", "message": f"#1 change {i}", "author": {"username": "bash-y"}} for i in range(25)]
        e = dn.build_event("push", {"ref": "refs/heads/main", "commits": commits})["embeds"][0]
        self.assertIn("…and 15 more", e["description"])

    def test_pull_request_lifecycle(self):
        opened = dn.build_event("pull_request", {"action": "opened", "pull_request": pr()})["embeds"][0]
        self.assertIn("Opened — PR #7", opened["title"])
        fields = {f["name"]: f["value"] for f in opened["fields"]}
        self.assertEqual(fields["Branch"], "`us9-endpoint-firewall` → `main`")
        self.assertEqual(fields["Changes"], "+40 / −3 in 4 files")
        self.assertEqual(fields["Linked"], "US-9 #50")

        merged = dn.build_event("pull_request", {"action": "closed",
                                                 "pull_request": pr(merged=True, merged_by={"login": "UiwAntHuynhCIS"})})
        self.assertIn("Merged", merged["embeds"][0]["title"])
        self.assertIn("Anthony Huynh", merged["embeds"][0]["description"])

        closed = dn.build_event("pull_request", {"action": "closed", "pull_request": pr()})
        self.assertIn("Closed without merging", closed["embeds"][0]["title"])

        asked = dn.build_event("pull_request", {"action": "review_requested", "pull_request": pr(),
                                                "requested_reviewer": {"login": "joromanii"}})
        self.assertIn("Jomar Rodriguez Canales", asked["embeds"][0]["description"])

        self.assertIsNone(dn.build_event("pull_request", {"action": "labeled", "pull_request": pr()}))

    def test_reviews(self):
        def review(state, body=""):
            return dn.build_event("pull_request_review", {"action": "submitted", "pull_request": pr(),
                                  "review": {"state": state, "body": body, "user": {"login": "UiwAntHuynhCIS"}}})
        self.assertEqual(review("approved")["embeds"][0]["color"], dn.GREEN)
        self.assertEqual(review("changes_requested", "fix the rule")["embeds"][0]["color"], dn.RED)
        self.assertIsNone(review("commented"))  # empty comment reviews are noise
        self.assertIsNotNone(review("commented", "looks good so far"))

    def test_issues(self):
        opened = dn.build_event("issues", {"action": "opened", "issue": issue()})
        self.assertIn("Issue #45", opened["embeds"][0]["title"])
        closed = dn.build_event("issues", {"action": "closed", "issue": issue(state_reason="completed")})
        self.assertIn("✅ Closed", closed["embeds"][0]["title"])
        dropped = dn.build_event("issues", {"action": "closed", "issue": issue(state_reason="not_planned")})
        self.assertIn("not planned", dropped["embeds"][0]["title"])
        assigned = dn.build_event("issues", {"action": "assigned", "issue": issue(),
                                             "assignee": {"login": "joromanii"}})
        self.assertIn("Assigned to Jomar Rodriguez Canales", assigned["embeds"][0]["title"])

    def test_assignment_at_creation_is_not_repeated(self):
        fresh = issue(created_at="2026-10-27T10:00:00Z", updated_at="2026-10-27T10:00:05Z")
        self.assertIsNone(dn.build_event("issues", {"action": "assigned", "issue": fresh,
                                                    "assignee": {"login": "bash-y"}}))
        self.assertIsNone(dn.build_event("issues", {"action": "milestoned", "issue": fresh}))

    def test_workflow_run_only_reports_failures(self):
        run = {"name": "Verify Commit Issues & Stories", "html_url": "https://x/run", "head_branch": "main",
               "head_commit": {"message": "dockerworkv1"}, "actor": {"login": "UiwAntHuynhCIS"}}
        self.assertIsNone(dn.build_event("workflow_run", {"workflow_run": dict(run, conclusion="success")}))
        failed = dn.build_event("workflow_run", {"workflow_run": dict(run, conclusion="failure")})
        self.assertEqual(failed["embeds"][0]["color"], dn.RED)

    def test_text_cannot_ping_everyone(self):
        body = dn.build_event("issues", {"action": "opened", "issue": issue(title="@everyone look")})
        self.assertEqual(body["allowed_mentions"], {"parse": []})

    def test_unknown_event_posts_nothing(self):
        self.assertIsNone(dn.build_event("star", {}))


def digest_data(weekly=False):
    return {
        "now": NOW.isoformat(), "days": 7 if weekly else 1, "weekly": weekly, "default_branch": "main",
        "commits": [
            {"sha": "1", "branch": "main", "login": "bash-y", "message": "US-1 #42: bot", "url": "u"},
            {"sha": "2", "branch": "x", "login": "UiwAntHuynhCIS", "message": "dockerworkv1", "url": "u"},
        ],
        "open_prs": [
            {"number": 58, "title": "Endpoint firewall", "url": "u", "login": "bash-y", "draft": False,
             "created_at": iso(NOW - timedelta(days=5)), "updated_at": iso(NOW - timedelta(days=4)),
             "reviewers": ["UiwAntHuynhCIS"], "decision": "REVIEW_REQUIRED"},
            {"number": 60, "title": "Business server", "url": "u", "login": "bash-y", "draft": False,
             "created_at": iso(NOW - timedelta(hours=5)), "updated_at": iso(NOW - timedelta(hours=1)),
             "reviewers": [], "decision": "CHANGES_REQUESTED"},
        ],
        "merged": [{"number": 61, "title": "Deck", "login": "bash-y"}],
        "unassigned": [{"number": 9, "title": "x"}], "no_milestone": [], "open_issues": 20,
        "closed": [{"number": 45, "title": "x", "logins": ["UiwAntHuynhCIS"]}],
        "milestones": [{"title": "M2", "open": 2, "closed": 6, "due_on": "2026-10-20T07:00:00Z", "url": "u"},
                       {"title": "M3", "open": 16, "closed": 0, "due_on": None, "url": "u"}],
        "branches": [{"name": "us9-endpoint-firewall", "ahead": 2, "behind": 1, "login": "bash-y",
                      "date": iso(NOW - timedelta(days=1))}] if weekly else [],
        "ci": {"Verify Commit Issues & Stories": {"success": 4, "failure": 1, "other": 0}} if weekly else {},
    }


class Digest(unittest.TestCase):
    def test_daily_digest_highlights(self):
        body = dn.build_digest(digest_data())
        size_ok(self, body)
        top = body["embeds"][0]["description"]
        self.assertIn("**2** commits, **1** PRs merged and **1** issues closed", top)
        self.assertIn("1 PR(s) waiting 2+ days", top)
        self.assertIn("1 PR(s) have changes requested", top)
        self.assertIn("1 PR(s) with no activity for 3+ days", top)
        self.assertIn("1 commit(s) not linked", top)
        self.assertIn("Overdue milestone(s): M2", top)
        self.assertIn("No commits in the last 24 hours from: Jomar Rodriguez Canales", top)
        self.assertEqual(len(body["embeds"]), 4)

    def test_team_activity_per_member(self):
        fields = {f["name"]: f["value"] for f in dn.build_digest(digest_data())["embeds"][1]["fields"]}
        self.assertEqual(set(fields), {"Anthony Huynh", "Sebastian Cadena", "Jomar Rodriguez Canales"})
        self.assertIn("1 commits · 1 PRs merged", fields["Sebastian Cadena"])
        self.assertIn("1 issues closed", fields["Anthony Huynh"])

    def test_open_prs_and_milestones(self):
        embeds = dn.build_digest(digest_data())["embeds"]
        self.assertIn("reviewer: Anthony Huynh", embeds[2]["description"])
        self.assertIn("5d", embeds[2]["description"])
        self.assertIn("75% (6/8)", embeds[3]["description"])
        self.assertIn("🚨", embeds[3]["description"])

    def test_weekly_adds_branches_and_ci(self):
        body = dn.build_digest(digest_data(weekly=True))
        size_ok(self, body)
        titles = [e["title"] for e in body["embeds"]]
        self.assertTrue(any("Branches not merged" in t for t in titles))
        self.assertTrue(any("CI health" in t for t in titles))
        self.assertIn("Weekly digest", titles[0])

    def test_quiet_week_still_renders(self):
        data = digest_data()
        data.update(commits=[], open_prs=[], merged=[], closed=[], milestones=[])
        body = dn.build_digest(data)
        self.assertIn("No open pull requests", body["embeds"][2]["description"])


class Delivery(unittest.TestCase):
    def run_main(self, argv, env):
        out = io.StringIO()
        with mock.patch.dict(os.environ, env, clear=True), redirect_stdout(out), \
                mock.patch.object(dn, "send") as send:
            code = dn.main(argv)
        return code, out.getvalue(), send

    def test_missing_webhook_is_a_clean_no_op(self):
        code, out, send = self.run_main(["test"], {})
        self.assertEqual(code, 0)
        self.assertIn("No Discord webhook configured", out)
        send.assert_not_called()

    def test_malformed_webhook_fails_clearly_without_echoing_it(self):
        bad = 'read -rsp "Paste the DIGEST webhook'
        with self.assertRaises(SystemExit) as stop:
            self.run_main(["test"], {"DISCORD_WEBHOOK_URL": bad})
        self.assertIn("not a Discord webhook URL", str(stop.exception))
        self.assertNotIn(bad, str(stop.exception))

    def test_real_webhook_shape_is_accepted(self):
        _, _, send = self.run_main(["test"], {"DISCORD_WEBHOOK_URL": " https://discord.com/api/webhooks/123/abc-DEF_9 "})
        self.assertEqual(send.call_args[0][0], "https://discord.com/api/webhooks/123/abc-DEF_9")

    def test_dry_run_prints_and_never_sends(self):
        code, out, send = self.run_main(["test", "--dry-run"], {"DISCORD_WEBHOOK_URL": "https://example.invalid/hook"})
        self.assertEqual(json.loads(out)["username"], dn.BOT_NAME)
        send.assert_not_called()

    def test_event_mode_reads_event_file(self):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as fh:
            json.dump({"action": "opened", "issue": issue()}, fh)
        try:
            code, _, send = self.run_main(["event"], {"GITHUB_EVENT_NAME": "issues", "GITHUB_EVENT_PATH": fh.name,
                                                      "DISCORD_WEBHOOK_URL": "https://discord.com/api/webhooks/1/x"})
        finally:
            os.unlink(fh.name)
        self.assertEqual(code, 0)
        send.assert_called_once()
        self.assertEqual(send.call_args[0][0], "https://discord.com/api/webhooks/1/x")


if __name__ == "__main__":
    unittest.main()
