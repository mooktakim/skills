#!/usr/bin/env bash
# SessionStart hook: tell the user when this project's design system is due a
# maintenance run, at most once a week per project. Checks every app with
# a design system and bin/audit_design, among the project's Rails apps. Silent in
# projects without one, and whenever nothing needs attention.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
. "$(dirname "$0")/rails-apps.sh"
apps=$(rails_apps "$root" fresh | while IFS= read -r app; do
  [ -f "$app/docs/design-system/README.md" ] && [ -x "$app/bin/audit_design" ] && printf '%s\n' "$app"
done)
[ -n "$apps" ] || exit 0

data=${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}
mkdir -p "$data" 2>/dev/null || exit 0
stamp="$data/nudge-$(printf '%s' "$root" | shasum | cut -c1-16)"
[ -n "$(find "$stamp" -mtime -7 2>/dev/null)" ] && exit 0

plugin="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
top=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null) || top=$root
reasons=()
while IFS= read -r app; do
  audit="$app/bin/audit_design"
  label=""
  [ "$app" = "$root" ] || label="${app#"$root"/}/: "
  out=$("$audit" 2>/dev/null) || continue
  findings=$(awk -F': ' '/^== / { n += $NF } END { print n + 0 }' <<<"$out")
  [ "$findings" -gt 0 ] && reasons+=("${label}bin/audit_design reports $findings finding(s)")
  [ -f "$plugin/scripts/audit_design" ] && ! cmp -s "$plugin/scripts/audit_design" "$audit" \
    && reasons+=("${label}bin/audit_design differs from the installed skill version")
  # The plugin ships the enforcement hooks now; entries an older skill version wrote
  # into the project settings would run the checks twice (or fail from subfolders).
  grep -qs 'audit_design' "$app/.claude/settings.json" "$root/.claude/settings.json" \
    && reasons+=("${label}old audit_design hooks in .claude/settings.json duplicate the plugin's own")
  # CI lives in the app (config/ci.rb) or at the top of the repository (.github/).
  grep -rqs 'audit_design' "$app/config/ci.rb" "$app/.github/workflows" "$top/.github/workflows" \
    || reasons+=("${label}bin/audit_design is not run in CI")
done <<<"$apps"
[ ${#reasons[@]} -eq 0 ] && exit 0

touch "$stamp"
summary=$(IFS=';'; printf '%s' "${reasons[*]}" | sed 's/;/; /g')
cat <<JSON
{
  "systemMessage": "Design-system maintenance is due: $summary. Run /rails-design-system:rails-design-system to review and fix (shown at most once a week).",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "rails-design-system: the design system in this project is due a maintenance run ($summary). The user has been told. Do not start a maintenance run unless the user asks for one."
  }
}
JSON
