#!/usr/bin/env bash
# SessionStart hook: tell the user when this project's design system is due a
# maintenance run, at most once a week per project. Silent in projects without
# bin/audit_design, and whenever nothing needs attention.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
audit="$root/bin/audit_design"
[ -x "$audit" ] || exit 0

data=${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}
mkdir -p "$data" 2>/dev/null || exit 0
stamp="$data/nudge-$(printf '%s' "$root" | shasum | cut -c1-16)"
[ -n "$(find "$stamp" -mtime -7 2>/dev/null)" ] && exit 0

out=$("$audit" 2>/dev/null) || exit 0
findings=$(awk -F': ' '/^== / { n += $NF } END { print n + 0 }' <<<"$out")
skill="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/SKILL.md"
script_outdated=0
if [ -f "$skill" ]; then
  current=$(awk '/^```bash$/ { b = ""; inb = 1; next }
    inb && /^```$/ { inb = 0; if (b ~ /Report design drift/) { printf "%s", b; exit } }
    inb { b = b $0 "\n" }' "$skill")
  [ -n "$current" ] && [ "$current" != "$(cat "$audit")" ] && script_outdated=1
fi
settings="$root/.claude/settings.json"
hooks_outdated=0
if [ ! -f "$settings" ] || ! grep -q 'CLAUDE_PROJECT_DIR.*audit_design --stop' "$settings" \
   || grep -q '"bin/audit_design --hook"' "$settings"; then
  hooks_outdated=1
fi

reasons=()
[ "$findings" -gt 0 ] && reasons+=("bin/audit_design reports $findings finding(s)")
[ "$script_outdated" -eq 1 ] && reasons+=("bin/audit_design differs from the installed skill version")
[ "$hooks_outdated" -eq 1 ] && reasons+=("the enforcement hooks in .claude/settings.json are missing or outdated")
[ ${#reasons[@]} -eq 0 ] && exit 0

touch "$stamp"
summary=$(IFS=';'; printf '%s' "${reasons[*]}" | sed 's/;/; /g')
cat <<EOF
{
  "systemMessage": "Design-system maintenance is due: $summary. Run /rails-design-system:rails-design-system to review and fix (shown at most once a week).",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "rails-design-system: the design system in this project is due a maintenance run ($summary). The user has been told. Do not start a maintenance run unless the user asks for one."
  }
}
EOF
