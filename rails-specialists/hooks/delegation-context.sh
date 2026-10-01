#!/usr/bin/env bash
# SessionStart hook: in a Rails project, tell the main session the moments at
# which to delegate to the specialists. Agent descriptions alone rarely won
# against the built-in general-purpose agent, so the workflow moments are
# stated up front. Silent outside Rails projects.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
rails=0
for app in "$root/config/application.rb" "$root"/*/config/application.rb; do
  [ -f "$app" ] && grep -q 'Rails::Application' "$app" 2>/dev/null && { rails=1; break; }
done
[ "$rails" -eq 1 ] || exit 0

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "This is a Rails project with the rails-specialists agents installed. Delegate at these moments without being asked:\n- rails-specialists:rails-reviewer: after implementing a feature or fix, before committing or opening a PR (skip trivial copy, docs, or config-only changes).\n- rails-specialists:rails-security: also, when the change touches authentication, authorization, payments or money, file uploads, or secrets, and before a production deploy.\n- rails-specialists:rails-tester: to run a test suite or subset, so suite output stays out of this conversation.\n- rails-specialists:rails-debugger: when a bug report or exception arrives and the root cause is not yet proven.\nPrefer these over general-purpose agents for this work. Fix what they find, or tell the user which findings you deferred and why."
  }
}
EOF
