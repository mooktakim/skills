#!/usr/bin/env bash
# SessionStart hook: in a Rails app that uses turbo-rails or stimulus-rails (at
# the project root or one level down), tell the main session when to load the
# rails-hotwire skill. Silent everywhere else.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
found=0
for app in "$root" "$root"/*; do
  [ -f "$app/config/application.rb" ] || continue
  grep -q 'Rails::Application' "$app/config/application.rb" 2>/dev/null || continue
  grep -qsE '^ *(turbo-rails|stimulus-rails) \(' "$app/Gemfile.lock" || grep -qsE "^[[:space:]]*gem[[:space:]]+[\"'](turbo-rails|stimulus-rails)[\"']" "$app/Gemfile" || continue
  found=1
  break
done
[ "$found" -eq 1 ] || exit 0

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "This Rails app uses Hotwire and the rails-hotwire plugin is installed.\n- Before building or changing anything interactive - links and redirects, form responses, Turbo Frames, Turbo Stream responses, broadcasts, page refreshes and morphing, or a Stimulus controller - load the rails-hotwire:rails-hotwire skill and follow it.\n- Also load it when a Turbo navigation, frame, stream, broadcast, or form does nothing or behaves oddly, and before auditing or upgrading the app's Hotwire setup.\nPrefer it over other Turbo or Hotwire skills for this work."
  }
}
JSON
