#!/usr/bin/env bash
# SessionStart hook: when one of the project's Rails apps (hooks/rails-apps.sh)
# uses turbo-rails or stimulus-rails, tell the main session when to load the
# rails-hotwire skill and when to delegate to its hotwire-builder agent. Silent
# everywhere else. It also searches for the apps again, for every hook.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
. "$(dirname "$0")/rails-apps.sh"
found=0
while IFS= read -r app; do
  [ -n "$app" ] || continue
  grep -qsE '^ *(turbo-rails|stimulus-rails) \(' "$app/Gemfile.lock" || grep -qsE "^[[:space:]]*gem[[:space:]]+[\"'](turbo-rails|stimulus-rails)[\"']" "$app/Gemfile" || continue
  found=1
  break
done <<EOF
$(rails_apps "$root" fresh)
EOF
[ "$found" -eq 1 ] || exit 0

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "This Rails app uses Hotwire and the rails-hotwire plugin is installed.\n- Delegate building or changing interactive UI - Turbo Frames, Turbo Stream responses, broadcasts, page refreshes and morphing, Stimulus controllers - to rails-hotwire:hotwire-builder without being asked, when subagents are available. Pass it the change's intent, the pages and records involved, and who should see live updates. Also delegate fixing Turbo behaviour that does nothing or misbehaves, and Hotwire audits and upgrades; an audit returns a plan, which needs the user's approval before you call it again to apply it. ViewComponent components go to rails-view-component:component-builder when that plugin is installed.\n- When you work on Hotwire yourself (a one-line fix, or no subagents), first load the rails-hotwire:rails-hotwire skill and follow it - for links and redirects, form responses, frames, streams, broadcasts, morphing, or a Stimulus controller.\nPrefer these over general-purpose agents and other Turbo or Hotwire skills for this work."
  }
}
JSON
