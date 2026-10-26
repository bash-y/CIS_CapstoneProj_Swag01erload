#!/usr/bin/env python3
"""Print the build-test matrix for GitHub Actions: one entry per layer that has a test command.

Writes "matrix=<json>" and "count=<n>" to $GITHUB_OUTPUT when it is set, otherwise prints them.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dashboard_lib as lib  # noqa: E402

cfg = lib.load_config()
include = [
    {"id": layer["id"], "name": layer["name"], "path": layer.get("path") or ".",
     "build": layer.get("build", ""), "test": layer["test"]}
    for layer in cfg["layers"] if layer.get("test", "").strip()
]
lines = [f"matrix={json.dumps({'include': include})}", f"count={len(include)}"]
out = os.environ.get("GITHUB_OUTPUT")
if out:
    with open(out, "a", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
print("\n".join(lines))
