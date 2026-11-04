#!/bin/sh
# skill-scan.sh: scan every agent skill (a folder with a SKILL.md) in the repo with SkillSpector.
# US-15 (#122). Static analysis only (--no-llm): no API keys and no LLM calls.
# Exit: 0 = all skills pass, or there are none; 1 = a skill is rated DO NOT INSTALL or coverage was incomplete;
# 2 = scanner error. SARIF reports go to $SKILL_SCAN_OUT (default: skill-scan-results/).
set -u

OUT="${SKILL_SCAN_OUT:-skill-scan-results}"
mkdir -p "$OUT"

worst=0
found=0
while IFS= read -r dir; do
  [ -n "$dir" ] || continue
  found=1
  name=$(printf '%s' "$dir" | tr '/' '_')
  [ "$name" = "." ] && name=root_skill
  code=0
  skillspector scan "$dir" --no-llm --fail-on-incomplete --format sarif --output "$OUT/$name.sarif" || code=$?
  [ "$code" -gt "$worst" ] && worst=$code
done <<EOF
$(git ls-files '*SKILL.md' | sed -e 's|/[^/]*$||' -e 's|^SKILL.md$|.|' | sort -u)
EOF

if [ "$found" -eq 0 ]; then
  echo "skill-scan: no SKILL.md files in the repo; nothing to scan."
  exit 0
fi
echo "skill-scan: SARIF reports in $OUT/"
exit "$worst"
