#!/usr/bin/env bash
# Build the dashboard on your own computer (macOS or Linux).
#   bash refresh.sh          read your GitHub repository (needs "gh auth login" once)
#   bash refresh.sh --demo   use made-up sample data, no GitHub access needed
# Then open _site/index.html in your browser.
set -euo pipefail
cd "$(dirname "$0")"

PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(sys.version_info < (3, 9))' 2>/dev/null; then
    PY="$c"; break
  fi
done
if [ -z "$PY" ]; then
  echo "Python 3.9 or later is required. Install it from https://www.python.org/downloads/" >&2
  exit 1
fi

if [ "${1:-}" != "--demo" ] && [ -z "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
  if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
    echo "Sign in to GitHub first: install the GitHub CLI (https://cli.github.com) and run: gh auth login" >&2
    exit 1
  fi
fi

"$PY" scripts/generate_dashboard.py "$@"
echo "Open this file in your browser: $(pwd)/_site/index.html"
