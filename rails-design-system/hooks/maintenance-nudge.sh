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
plugin="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
script_outdated=0
[ -f "$plugin/scripts/audit_design" ] && ! cmp -s "$plugin/scripts/audit_design" "$audit" && script_outdated=1
# The plugin ships the enforcement hooks now; entries an older skill version wrote
# into the project settings would run the checks twice (or fail from subfolders).
legacy_hooks=0
grep -qs 'audit_design' "$root/.claude/settings.json" && legacy_hooks=1
no_ci=0
grep -rqs 'audit_design' "$root/config/ci.rb" "$root/.github/workflows" || no_ci=1

reasons=()
[ "$findings" -gt 0 ] && reasons+=("bin/audit_design reports $findings finding(s)")
[ "$script_outdated" -eq 1 ] && reasons+=("bin/audit_design differs from the installed skill version")
[ "$legacy_hooks" -eq 1 ] && reasons+=("old audit_design hooks in .claude/settings.json duplicate the plugin's own")
[ "$no_ci" -eq 1 ] && reasons+=("bin/audit_design is not run in CI")
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
