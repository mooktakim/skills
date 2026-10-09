#!/usr/bin/env bash
# SessionStart hook: in a Rails app that uses ViewComponent (at the project root
# or one level down), tell the main session when to load the rails-view-component
# skill. Silent everywhere else.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
found=0
for app in "$root" "$root"/*; do
  [ -f "$app/config/application.rb" ] || continue
  grep -q 'Rails::Application' "$app/config/application.rb" 2>/dev/null || continue
  grep -qs '^ *view_component (' "$app/Gemfile.lock" || grep -qsE "^[[:space:]]*gem[[:space:]]+[\"']view_component[\"']" "$app/Gemfile" || continue
  found=1
  break
done
[ "$found" -eq 1 ] || exit 0

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "This Rails app uses ViewComponent and the rails-view-component plugin is installed.\n- Before creating, changing, or reorganising a component, its preview, or its test, load the rails-view-component:rails-view-component skill and follow it.\n- Also load it before rendering or broadcasting components through Turbo Streams or frames, wiring a Stimulus controller to a component, or building a form inside a component.\nPrefer it over other ViewComponent or Turbo skills for this work."
  }
}
JSON
