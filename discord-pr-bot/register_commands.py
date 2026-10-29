#!/usr/bin/env python3
"""Register the SwagPc PR Bot slash commands (/link, /unlink, /whoami, /pr, /prs) in one Discord server.

Usage:
  python3 discord-pr-bot/register_commands.py              # prompts for the ids and the bot token
  python3 discord-pr-bot/register_commands.py --dry-run    # print the commands, send nothing
  python3 discord-pr-bot/register_commands.py --token-from-clipboard   # macOS: token from pbpaste

Server commands show up instantly (global ones can take up to an hour). Re-running is safe:
Discord replaces the server's command list with this one. The bot token is read with a hidden
prompt and only used for this one request; it is never saved. Standard library only.
"""

from __future__ import annotations

import argparse
import getpass
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request

API = "https://discord.com/api/v10"
INTEGER = 4
BOT_TOKEN = re.compile(r"^[\w-]{20,}\.[\w-]{5,}\.[\w-]{20,}$")

COMMANDS = [
    {"name": "link", "description": "Link your GitHub account so Approve and Merge act as you"},
    {"name": "unlink", "description": "Forget your linked GitHub account"},
    {"name": "whoami", "description": "Show which GitHub account you have linked"},
    {"name": "pr", "description": "Show a pull request with Approve and Merge buttons",
     "options": [{"type": INTEGER, "name": "number", "description": "Pull request number, e.g. 91",
                  "required": True, "min_value": 1}]},
    {"name": "prs", "description": "List open pull requests"},
]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--application-id", help="Discord application id (General Information page)")
    ap.add_argument("--guild-id", help="Discord server id (Developer Mode -> right-click server -> Copy Server ID)")
    ap.add_argument("--dry-run", action="store_true", help="print the commands instead of registering them")
    ap.add_argument("--token-from-clipboard", action="store_true",
                    help="read the bot token from the macOS clipboard (pbpaste) instead of a prompt")
    args = ap.parse_args(argv)

    if args.dry_run:
        print(json.dumps(COMMANDS, indent=2))
        return 0

    app_id = (args.application_id or input("Discord application id: ")).strip()
    guild_id = (args.guild_id or input("Discord server id: ")).strip()
    if not (app_id.isdigit() and guild_id.isdigit()):
        sys.exit("Both ids are long numbers; copy them from Discord again.")
    if args.token_from_clipboard:
        token = subprocess.run(["pbpaste"], capture_output=True, text=True).stdout.strip()
    else:
        token = getpass.getpass("Bot token (hidden): ").strip()
    if not token:
        sys.exit("No bot token given.")
    # Never echo the value: a wrong paste may still contain something sensitive.
    if not BOT_TOKEN.match(token):
        sys.exit("That isn't a Discord bot token (expected three dot-separated parts). "
                 "Copy it again from the Bot page and retry.")

    req = urllib.request.Request(
        f"{API}/applications/{app_id}/guilds/{guild_id}/commands",
        data=json.dumps(COMMANDS).encode(), method="PUT",
        headers={"Authorization": f"Bot {token}", "Content-Type": "application/json",
                 "User-Agent": "DiscordBot (swagpc-pr-bot, 1.0)"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            names = [c["name"] for c in json.load(resp)]
    except urllib.error.HTTPError as err:
        hint = {401: " The bot token is wrong; reset it on the Bot page and try again.",
                403: " Invite the app to the server with the applications.commands scope first.",
                404: " Check the application id and server id."}.get(err.code, "")
        sys.exit(f"Discord refused: HTTP {err.code} {err.read()[:300]!r}.{hint}")
    print("Registered: " + ", ".join(f"/{n}" for n in names))
    return 0


if __name__ == "__main__":
    sys.exit(main())
