#!/usr/bin/env bash
# SessionStart hook: in an app with a design system, tell the main session when
# to delegate to the design-reviewer agent. Silent everywhere else.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
. "$(dirname "$0")/app-roots.sh"
[ -n "$(design_roots "$root")" ] || exit 0

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "This app has a design system in docs/design-system/ (in the app's directory) and the rails-design-system:design-reviewer agent is installed. After changing views, components, or view CSS, and before committing or opening a PR, delegate a review of the change to rails-design-system:design-reviewer without being asked (skip copy-only edits). When other reviews apply to the same change, such as rails-specialists:rails-reviewer, launch them in the same message so they run in parallel. In the prompt, name the changed files or the commit range and state the intent of the change, so it starts reviewing instead of rediscovering the scope. It reviews code by default; ask it for a visual check with screenshots only when the user wants one, and give it the running dev server URL. Fix what it finds, or tell the user which findings you deferred and why."
  }
}
EOF
