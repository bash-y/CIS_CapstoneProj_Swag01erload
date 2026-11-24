"""Tests for the ZAP runner's scope and configuration checks (US-19, #130).

Run with: python3 -m unittest discover -s tests -v
The test against the real compose file is skipped when the Docker CLI is missing.
"""

import copy
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts" / "zap"))
import zap_check as zc  # noqa: E402

DIGEST = "sha256:" + "a" * 64
GOOD = {
    "services": {
        "zap": {
            "profiles": ["zap"],
            "image": f"zaproxy/zap-stable:2.17.0@{DIGEST}",
            "networks": {"guest-net": {"ipv4_address": "192.168.10.60"}},
            "cap_drop": ["ALL"],
            "cap_add": ["CHOWN", "NET_ADMIN", "SETUID", "SETGID", "SETPCAP"],
            "security_opt": ["no-new-privileges:true"],
            "restart": "no",
            "volumes": [
                {"type": "bind", "source": "/repo/scripts/zap", "target": "/scripts/zap", "read_only": True},
                {"type": "volume", "source": "zap_reports", "target": "/zap/wrk"},
            ],
        }
    }
}


def allowlist(*lines):
    f = tempfile.NamedTemporaryFile("w", suffix=".allowlist", delete=False, encoding="utf-8")
    f.write("\n".join(lines) + "\n")
    f.close()
    return f.name


class Allowlist(unittest.TestCase):
    def test_shipped_allowlist_is_valid_and_not_empty(self):
        entries, errs = zc.parse_allowlist(zc.ALLOWLIST)
        self.assertEqual(errs, [])
        self.assertGreater(len(entries), 0)

    def test_comments_and_blank_lines_are_ignored(self):
        entries, errs = zc.parse_allowlist(allowlist("# note", "", "http://192.168.20.15:8080/  # waf"))
        self.assertEqual((len(entries), errs), (1, []))

    def test_bad_entries_are_rejected(self):
        bad = {
            "public address": "http://8.8.8.8/",
            "hostname": "http://example.com/",
            "localhost name": "http://localhost:8080/",
            "wildcard": "http://192.168.20.*/",
            "scanner itself": "http://192.168.10.60/",
            "other private range": "http://10.0.0.5/",
            "bad scheme": "ftp://192.168.20.10/",
            "credentials": "http://user:pw@192.168.20.10/",
            "query": "http://192.168.20.10/?x=1",
            "bad port": "http://192.168.20.10:99999/",
            "no host": "http:///path",
        }
        for why, line in bad.items():
            with self.subTest(why):
                entries, errs = zc.parse_allowlist(allowlist(line))
                self.assertEqual(entries, [])
                self.assertEqual(len(errs), 1)


class Targets(unittest.TestCase):
    def setUp(self):
        self.entries, _ = zc.parse_allowlist(allowlist("http://192.168.20.15:8080/", "http://192.168.20.10/app/"))

    def test_covered_targets(self):
        for url in ("http://192.168.20.15:8080/", "http://192.168.20.15:8080/login.php?x=1", "http://192.168.20.10/app/a/b"):
            with self.subTest(url):
                self.assertTrue(zc.covers(self.entries, url))

    def test_refused_targets(self):
        for url in (
            "http://192.168.20.15:8081/",             # another port
            "https://192.168.20.15:8080/",            # another scheme
            "http://192.168.20.10/",                  # outside the entry's path
            "http://192.168.20.11/app/",              # another host
            "http://8.8.8.8/",                        # public
            "http://example.com/",                    # a name
            "http://192.168.20.15:8080@8.8.8.8/",     # credentials trick
            "http://192.168.20.15:8080.evil.test/",   # host lookalike
            "not a url",
        ):
            with self.subTest(url):
                self.assertFalse(zc.covers(self.entries, url))

    def test_regexes_match_only_allowed_urls(self):
        import re
        rx = [re.compile(r) for r in zc.regexes(self.entries)]
        match = lambda url: any(r.match(url) for r in rx)  # noqa: E731
        self.assertTrue(match("http://192.168.20.15:8080/dvwa/login.php"))
        self.assertFalse(match("http://192.168.20.150:8080/"))   # the dots are escaped
        self.assertFalse(match("http://8.8.8.8:8080/"))


class ComposeService(unittest.TestCase):
    def mutate(self, fn):
        cfg = copy.deepcopy(GOOD)
        fn(cfg["services"]["zap"])
        return zc.check_compose(cfg)

    def test_good_config_passes(self):
        self.assertEqual(zc.check_compose(GOOD), [])

    def test_missing_service_fails(self):
        self.assertEqual(len(zc.check_compose({"services": {}})), 1)

    def test_each_unsafe_change_is_caught(self):
        cases = {
            "not opt-in": lambda s: s.update(profiles=[]),
            "unpinned image": lambda s: s.update(image="zaproxy/zap-stable:latest"),
            "other repository": lambda s: s.update(image=f"evil/zap:1@{DIGEST}"),
            "also on business-net": lambda s: s["networks"].update({"business-net": {}}),
            "wrong network": lambda s: s.update(networks={"business-net": {"ipv4_address": "192.168.20.60"}}),
            "address outside Guest": lambda s: s["networks"]["guest-net"].update(ipv4_address="192.168.20.60"),
            "no fixed address": lambda s: s["networks"].update({"guest-net": {}}),
            "published port": lambda s: s.update(ports=[{"target": 8090, "published": "8090"}]),
            "host network": lambda s: s.update(network_mode="host"),
            "privileged": lambda s: s.update(privileged=True),
            "host pid": lambda s: s.update(pid="host"),
            "no cap_drop": lambda s: s.pop("cap_drop"),
            "extra capability": lambda s: s["cap_add"].append("SYS_ADMIN"),
            "no no-new-privileges": lambda s: s.update(security_opt=[]),
            "restarts itself": lambda s: s.update(restart="always"),
            "writable bind": lambda s: s["volumes"][0].update(read_only=False),
            "docker socket": lambda s: s["volumes"].append({"type": "bind", "source": "/var/run/docker.sock", "target": "/x", "read_only": True}),
            "no report volume": lambda s: s.update(volumes=[s["volumes"][0]]),
        }
        for why, fn in cases.items():
            with self.subTest(why):
                self.assertGreaterEqual(len(self.mutate(fn)), 1, f"not caught: {why}")

    @unittest.skipUnless(shutil.which("docker"), "Docker CLI not installed")
    def test_real_compose_file_passes(self):
        self.assertEqual(zc.check_compose(zc.compose_config(zc.COMPOSE)), [])


if __name__ == "__main__":
    unittest.main()
