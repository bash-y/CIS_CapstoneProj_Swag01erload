#!/bin/sh
# capture-evidence.sh: run a command and save its output as a dated evidence file.
# US-16 (#124). Usage:
#   sh scripts/capture-evidence.sh <folder> <name> "<title>" <command> [args...]
# Writes evidence/<folder>/<name>-<UTC timestamp>.txt with a title, date, host, command and
# exit-code header, prints it, and exits with the command's own exit code.
set -u

if [ $# -lt 4 ]; then
  echo "usage: sh scripts/capture-evidence.sh <folder> <name> \"<title>\" <command> [args...]" >&2
  exit 2
fi
folder=$1 name=$2 title=$3
shift 3

case "$folder" in
  attack|build|defense|logs|test-results|verification) ;;
  *) echo "capture-evidence: folder must be one of attack, build, defense, logs, test-results, verification" >&2; exit 2 ;;
esac
case "$name" in
  ''|.*|*[!A-Za-z0-9._-]*) echo "capture-evidence: name may use only letters, digits, '.', '_' and '-', and may not start with '.'" >&2; exit 2 ;;
esac

root=$(git rev-parse --show-toplevel) || exit 2
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
file="$root/evidence/$folder/$name-$(printf '%s' "$now" | tr -d ':-').txt"
mkdir -p "$root/evidence/$folder"

engine=$(docker version --format '{{.Server.Version}}' 2>/dev/null) || engine="not reachable"
{
  echo "$title"
  echo "Date: $now"
  echo "Host: $(uname -sr), Docker engine $engine"
  echo "Command: $*"
  echo "----------------------------------------------------------------"
} > "$file"

code=0
"$@" >> "$file" 2>&1 || code=$?
echo "Exit code: $code" >> "$file"

cat "$file"
echo "capture-evidence: saved ${file#"$root"/}"
exit "$code"
