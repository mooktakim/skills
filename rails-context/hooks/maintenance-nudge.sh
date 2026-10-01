#!/usr/bin/env bash
# SessionStart hook: tell the user when this project's context files are due a
# maintenance run, at most once a week per project. Silent in projects without
# bin/audit_context, and whenever nothing needs attention.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
audit="$root/bin/audit_context"
[ -x "$audit" ] || exit 0

data=${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}
mkdir -p "$data" 2>/dev/null || exit 0
stamp="$data/nudge-$(printf '%s' "$root" | shasum | cut -c1-16)"
[ -n "$(find "$stamp" -mtime -7 2>/dev/null)" ] && exit 0

out=$("$audit" 2>/dev/null) || exit 0
oversized=$(grep -c 'oversized:' <<<"$out")
flagged=$(grep -c '^== ' <<<"$out")
candidates=$(grep -cE '^     - .* \([0-9]+ files\)$' <<<"$out")
plugin="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
outdated=0
[ -f "$plugin/scripts/audit_context" ] && ! cmp -s "$plugin/scripts/audit_context" "$audit" && outdated=1

reasons=()
[ "$oversized" -gt 0 ] && reasons+=("$oversized context file(s) over the size limit")
[ "$flagged" -ge 5 ] && reasons+=("$flagged context file(s) flagged by bin/audit_context")
[ "$candidates" -gt 0 ] && reasons+=("$candidates director(ies) may need a context file")
[ "$outdated" -eq 1 ] && reasons+=("bin/audit_context differs from the installed skill version")
[ ${#reasons[@]} -eq 0 ] && exit 0

touch "$stamp"
summary=$(IFS=';'; printf '%s' "${reasons[*]}" | sed 's/;/; /g')
cat <<EOF
{
  "systemMessage": "MVC Context maintenance is due: $summary. Run /rails-context:rails-context to review and fix (shown at most once a week).",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "rails-context: the context files in this project are due a maintenance run ($summary). The user has been told. Do not start a maintenance run unless the user asks for one."
  }
}
EOF
