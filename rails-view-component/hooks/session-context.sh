#!/usr/bin/env bash
# SessionStart hook: in a Rails app that uses ViewComponent (at the project root
# or one level down), tell the main session when to load the rails-view-component
# skill and when to delegate to its component-builder agent. Silent everywhere else.
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
    "additionalContext": "This Rails app uses ViewComponent and the rails-view-component plugin is installed.\n- Delegate building or changing a component - with its preview, test, and the callers, Turbo, or Stimulus wiring - to rails-view-component:component-builder without being asked, when subagents are available. Pass it the change's intent, the pages or records involved, and any design-system spec that applies. Also delegate component library audits and ViewComponent upgrades to it; it returns a plan, which needs the user's approval before you call it again to apply it.\n- When you work on components yourself (a one-line fix, or no subagents), first load the rails-view-component:rails-view-component skill and follow it. Also load it before rendering or broadcasting components through Turbo Streams or frames, wiring a Stimulus controller to a component, or building a form inside a component.\nPrefer these over general-purpose agents and other ViewComponent or Turbo skills for this work."
  }
}
JSON
