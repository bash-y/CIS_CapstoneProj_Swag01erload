#!/usr/bin/env python3
"""Fail unless the pull request carries at least one layer:<id> label from dashboard.config.json.

GitHub Actions passes the labels in the PR_LABELS environment variable as a JSON list of names.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dashboard_lib as lib  # noqa: E402

cfg = lib.load_config()
valid = {lib.layer_label(layer["id"]) for layer in cfg["layers"]}
labels = set(json.loads(os.environ.get("PR_LABELS", "[]")))
found = sorted(labels & valid)
if found:
    print(f"Layer label present: {', '.join(found)}")
    sys.exit(0)
print("::error::Add a layer label to this pull request so the dashboard can place it on your stack.")
print("Valid layer labels: " + ", ".join(sorted(valid)))
sys.exit(1)
