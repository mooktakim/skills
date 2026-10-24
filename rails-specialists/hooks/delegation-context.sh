#!/usr/bin/env bash
# SessionStart hook: in a Rails project, tell the main session the moments at
# which to delegate to the specialists. Agent descriptions alone rarely won
# against the built-in general-purpose agent, so the workflow moments are
# stated up front. Silent in projects without a Rails app (hooks/rails-apps.sh).
# It also searches for the apps again, for every hook.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
. "$(dirname "$0")/rails-apps.sh"
[ -n "$(rails_apps "$root" fresh)" ] || exit 0

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "This is a Rails project with the rails-specialists agents installed. Delegate at these moments without being asked:\n- rails-specialists:rails-reviewer: after implementing a feature or fix, before committing or opening a PR (skip trivial copy, docs, or config-only changes).\n- rails-specialists:rails-security: also, when the change touches authentication, authorization, payments or money, file uploads, or secrets, and before a production deploy.\n- rails-specialists:rails-debugger: when a bug report or exception arrives and the root cause is not yet proven.\nWhen more than one review applies to the same change - rails-reviewer, rails-security, and rails-design-system:design-reviewer if installed - launch them all in one message so they run in parallel, not one after another. In each review prompt, name the changed files or the commit range and state the intent of the change in a sentence or two, so the agent starts reviewing instead of rediscovering the scope.\nPrefer these over general-purpose agents for this work. Fix what they find, or tell the user which findings you deferred and why."
  }
}
EOF
