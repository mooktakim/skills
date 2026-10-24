#!/usr/bin/env bash
# SessionStart hook: tell the user when this project's context files are due a
# maintenance run, at most once a week per project. Checks every Rails app in the
# project set up with rails-context (bin/audit_context). Silent in projects
# without one, and whenever nothing needs attention.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
. "$(dirname "$0")/rails-apps.sh"
apps=$(rails_apps "$root" fresh | while IFS= read -r app; do [ -x "$app/bin/audit_context" ] && printf '%s\n' "$app"; done)
[ -n "$apps" ] || exit 0

data=${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}
mkdir -p "$data" 2>/dev/null || exit 0
stamp="$data/nudge-$(printf '%s' "$root" | shasum | cut -c1-16)"
[ -n "$(find "$stamp" -mtime -7 2>/dev/null)" ] && exit 0

plugin="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
reasons=()
while IFS= read -r app; do
  audit="$app/bin/audit_context"
  label=""
  [ "$app" = "$root" ] || label="${app#"$root"/}/: "
  out=$("$audit" 2>/dev/null) || continue
  oversized=$(grep -c 'oversized:' <<<"$out")
  flagged=$(grep -c '^== ' <<<"$out")
  candidates=$(grep -cE '^     - .* \([0-9]+ files\)$' <<<"$out")
  [ "$oversized" -gt 0 ] && reasons+=("$label$oversized context file(s) over the size limit")
  [ "$flagged" -ge 5 ] && reasons+=("$label$flagged context file(s) flagged by bin/audit_context")
  [ "$candidates" -gt 0 ] && reasons+=("$label$candidates director(ies) may need a context file")
  [ -f "$plugin/scripts/audit_context" ] && ! cmp -s "$plugin/scripts/audit_context" "$audit" \
    && reasons+=("${label}bin/audit_context differs from the installed skill version")
done <<<"$apps"
[ ${#reasons[@]} -eq 0 ] && exit 0

touch "$stamp"
summary=$(IFS=';'; printf '%s' "${reasons[*]}" | sed 's/;/; /g')
cat <<JSON
{
  "systemMessage": "MVC Context maintenance is due: $summary. Run /rails-context:rails-context to review and fix (shown at most once a week).",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "rails-context: the context files in this project are due a maintenance run ($summary). The user has been told. Do not start a maintenance run unless the user asks for one."
  }
}
JSON
