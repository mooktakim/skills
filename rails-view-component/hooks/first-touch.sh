#!/usr/bin/env bash
# PreToolUse hook (Write, Edit, Bash): the first time in a session that a tool
# call touches ViewComponent components, tell Claude to load the
# rails-view-component skill. The SessionStart note misses sessions where the
# app appears later (built in the session) or started before the plugin was
# installed. Once per session; silent in subagents. Never blocks.
input=$(cat)
# A call that may create or remove a Rails app drops the shared list first.
root=${CLAUDE_PROJECT_DIR:-$PWD}
. "$(dirname "$0")/rails-apps.sh"
rails_apps_forget "$root" "$input"
case "$input" in *app/components/*_component.rb*|*app/components/*_component.html*|*/components/previews/*) ;; *) exit 0 ;; esac
case "$input" in *'"agent_id"'*) exit 0 ;; esac
# Only for a tool call in one of the project's Rails apps (hooks/rails-apps.sh).
[ -n "$(rails_app_of "$input" "$(rails_apps "$root" "$input")")" ] || exit 0
session=$(printf '%s' "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
[ -n "$session" ] || exit 0
dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}/first-touch"
mkdir -p "$dir" 2>/dev/null || exit 0
stamp="$dir/$(printf '%s' "$session" | tr -c 'A-Za-z0-9_-' '_')"
[ -e "$stamp" ] && exit 0
touch "$stamp"
find "$dir" -type f -mtime +7 -delete 2>/dev/null
cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "This is the first time in this session you touch a ViewComponent component. If you have not loaded the rails-view-component:rails-view-component skill in this session, load it now and follow it. To build or change a component with its preview, test, and wiring, delegate to rails-view-component:component-builder when subagents are available."
  }
}
JSON
exit 0
