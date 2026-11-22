#!/usr/bin/env python3
"""Scope and configuration checks for the ZAP runner (US-19, #130).

  zap_check.py allowlist [file]         validate the target allowlist
  zap_check.py target <url> [file]      exit 0 if the URL is covered by the allowlist, 2 if it is refused
  zap_check.py regexes [file]           print one ZAP context include regex per allowlist entry
  zap_check.py config [compose] [file]  validate the zap service in the compose file and the allowlist

Standard library only. "config" runs `docker compose config`, which needs the Docker CLI but not the daemon.
Exit codes: 0 ok, 1 a check failed, 2 a target was refused or the command was misused.
"""
import ipaddress
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
ALLOWLIST = ROOT / "configs/zap/targets.allowlist"
COMPOSE = ROOT / "docker/docker-compose.yml"
LAB_SUBNETS = [ipaddress.ip_network(n) for n in ("192.168.10.0/24", "192.168.20.0/24", "192.168.30.0/24")]
GUEST = ipaddress.ip_network("192.168.10.0/24")
SCANNER_IP = ipaddress.ip_address("192.168.10.60")
ALLOWED_CAPS = {"CHOWN", "NET_ADMIN", "SETUID", "SETGID", "SETPCAP"}
IMAGE = re.compile(r"zaproxy/[\w.-]+:[\w.-]+@sha256:[0-9a-f]{64}")


def parse_url(text, where, entry=True):
    """Return ((scheme, ip, port, path), None) or (None, error) for a URL that names a lab IPv4 address.

    An allowlist entry (entry=True) may not carry a query or fragment. A target being checked may.
    """
    try:
        u = urlsplit(text)
        port = u.port
    except ValueError as err:
        return None, f"{where}: invalid URL ({err})"
    if u.scheme not in ("http", "https"):
        return None, f"{where}: scheme must be http or https"
    if u.username or u.password:
        return None, f"{where}: credentials in a URL are not allowed"
    if entry and (u.query or u.fragment):
        return None, f"{where}: an allowlist entry may not have a query or fragment"
    try:
        ip = ipaddress.IPv4Address(u.hostname or "")
    except ValueError:
        return None, f"{where}: host must be an IPv4 address, not a name or wildcard"
    if not any(ip in net for net in LAB_SUBNETS):
        return None, f"{where}: {ip} is outside the lab subnets"
    if ip == SCANNER_IP:
        return None, f"{where}: {ip} is the scanner itself"
    return (u.scheme, str(ip), port or (443 if u.scheme == "https" else 80), u.path or "/"), None


def parse_allowlist(path):
    """Return (entries, errors) for an allowlist file."""
    entries, errors = [], []
    for n, raw in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if line:
            entry, err = parse_url(line, f"{path}:{n}")
            entries.append(entry) if entry else errors.append(err)
    return entries, errors


def covers(entries, url):
    """True if the URL has the same scheme, host and port as an entry and a path under it."""
    target, err = parse_url(url, "target", entry=False)
    if err:
        return False
    return any(target[:3] == e[:3] and target[3].startswith(e[3]) for e in entries)


def regexes(entries):
    return [f"^{re.escape(f'{s}://{h}:{p}{path}')}.*$" for s, h, p, path in entries]


def check_compose(cfg):
    """Return the problems found in the zap service of a `docker compose config --format json` dict."""
    svc = cfg.get("services", {}).get("zap")
    if not svc:
        return ["compose: there is no zap service"]
    errs = []
    if "zap" not in (svc.get("profiles") or []):
        errs.append("zap must be opt-in: its profiles must include 'zap'")
    if not IMAGE.fullmatch(svc.get("image", "")):
        errs.append("zap image must be a zaproxy image pinned by version tag and sha256 digest")
    nets = svc.get("networks") or {}
    if set(nets) != {"guest-net"}:
        errs.append(f"zap must be on guest-net only, not {sorted(nets)}")
    else:
        addr = (nets["guest-net"] or {}).get("ipv4_address", "")
        if not addr or ipaddress.ip_address(addr) not in GUEST:
            errs.append("zap needs a fixed address inside the Guest subnet 192.168.10.0/24")
    if svc.get("ports"):
        errs.append("zap must not publish ports")
    if svc.get("network_mode"):
        errs.append("zap must not set network_mode")
    for key in ("privileged", "pid", "ipc", "userns_mode"):
        if svc.get(key) in (True, "host"):
            errs.append(f"zap must not set {key}")
    if "ALL" not in (svc.get("cap_drop") or []):
        errs.append("zap must drop ALL capabilities")
    extra = set(svc.get("cap_add") or []) - ALLOWED_CAPS
    if extra:
        errs.append(f"zap may add only {sorted(ALLOWED_CAPS)}, not {sorted(extra)}")
    if "no-new-privileges:true" not in (svc.get("security_opt") or []):
        errs.append("zap must set security_opt no-new-privileges:true")
    if svc.get("restart", "no") != "no":
        errs.append("zap must not restart on its own")
    for vol in svc.get("volumes") or []:
        if vol.get("type") == "bind" and not vol.get("read_only"):
            errs.append(f"zap bind mount {vol.get('target')} must be read-only")
        if "docker.sock" in str(vol.get("source", "")):
            errs.append("zap must not mount the Docker socket")
    if not any(v.get("target") == "/zap/wrk" and v.get("type") == "volume" for v in svc.get("volumes") or []):
        errs.append("zap needs a named volume at /zap/wrk for persistent reports")
    return errs


def compose_config(compose):
    out = subprocess.run(["docker", "compose", "-f", str(compose), "--profile", "zap", "config", "--format", "json"],
                         capture_output=True, text=True, check=False)
    if out.returncode != 0:
        sys.exit(f"zap_check: docker compose config failed: {out.stderr.strip()}")
    return json.loads(out.stdout)


def main(argv):
    cmd, args = (argv[0] if argv else ""), argv[1:]
    if cmd == "allowlist":
        entries, errs = parse_allowlist(args[0] if args else ALLOWLIST)
    elif cmd in ("target", "regexes") and (args or cmd == "regexes"):
        path = args[1] if cmd == "target" and len(args) > 1 else (args[0] if cmd == "regexes" and args else ALLOWLIST)
        entries, errs = parse_allowlist(path)
        if errs:
            print("\n".join(f"FAIL: {e}" for e in errs))
            return 1
        if cmd == "regexes":
            print("\n".join(regexes(entries)))
            return 0
        if covers(entries, args[0]):
            print(f"OK: {args[0]} is on the allowlist")
            return 0
        print(f"REFUSED: {args[0]} is not covered by the allowlist ({path})")
        return 2
    elif cmd == "config":
        compose = args[0] if args else COMPOSE
        entries, list_errs = parse_allowlist(args[1] if len(args) > 1 else ALLOWLIST)
        errs = check_compose(compose_config(compose)) + list_errs
    else:
        print(__doc__)
        return 2
    for e in errs:
        print(f"FAIL: {e}")
    if not errs:
        print(f"OK: {cmd} ({len(entries)} allowlist entries)" if cmd == "allowlist" else f"OK: {cmd}")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
