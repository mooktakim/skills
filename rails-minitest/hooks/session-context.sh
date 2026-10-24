#!/usr/bin/env bash
# SessionStart hook: when one of the project's Rails apps (hooks/rails-apps.sh)
# is tested with Minitest, tell the main session when to load the rails-minitest
# skill and when to delegate to its minitest-runner agent. Silent everywhere
# else, including RSpec apps. It also searches for the apps again, for every hook.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
. "$(dirname "$0")/rails-apps.sh"
minitest=0
while IFS= read -r app; do
  [ -n "$app" ] && [ -f "$app/test/test_helper.rb" ] || continue
  grep -qs 'rspec-rails' "$app/Gemfile" && continue
  minitest=1
  break
done <<EOF
$(rails_apps "$root" fresh)
EOF
[ "$minitest" -eq 1 ] || exit 0

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "This Rails app is tested with Minitest and the rails-minitest plugin is installed.\n- Before writing, changing, or reorganising tests, or fixtures and test helpers, load the rails-minitest:rails-minitest skill and follow it.\n- Run a single test file directly. For a run that covers more than one test file, use toolsmith-check-run when it is on PATH (it prints only the outcome and failures); otherwise delegate the run to rails-minitest:minitest-runner, passing the exact files or path:line, so suite output stays out of this conversation.\n- Delegate writing tests for a finished change, and diagnosing a failing or flaky test, to rails-minitest:minitest-runner without being asked.\n- Skip the run when only docs, comments, or files the app never loads (CI, editor settings) changed since the last green run; config/ changes do count.\nPrefer it over general-purpose agents for test work."
  }
}
JSON
