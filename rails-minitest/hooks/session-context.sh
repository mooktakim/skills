#!/usr/bin/env bash
# SessionStart hook: in a Rails app tested with Minitest (at the project root or
# one level down), tell the main session when to load the rails-minitest skill
# and when to delegate to its minitest-runner agent. Silent everywhere else,
# including RSpec apps.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
minitest=0
for app in "$root" "$root"/*; do
  [ -f "$app/config/application.rb" ] && [ -f "$app/test/test_helper.rb" ] || continue
  grep -q 'Rails::Application' "$app/config/application.rb" 2>/dev/null || continue
  grep -qs 'rspec-rails' "$app/Gemfile" && continue
  minitest=1
  break
done
[ "$minitest" -eq 1 ] || exit 0

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "This Rails app is tested with Minitest and the rails-minitest plugin is installed.\n- Before writing, changing, or reorganising tests, or fixtures and test helpers, load the rails-minitest:rails-minitest skill and follow it.\n- Delegate a test run that covers more than one test file to rails-minitest:minitest-runner without being asked, so suite output stays out of this conversation, and pass it the exact files or path:line to run. Run a single test file directly. Also delegate diagnosing a failing or flaky test to it.\n- Skip the run when only docs, comments, or files the app never loads (CI, editor settings) changed since the last green run; config/ changes do count.\nPrefer it over general-purpose agents for test work."
  }
}
JSON
