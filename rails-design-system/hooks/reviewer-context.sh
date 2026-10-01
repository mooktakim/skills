#!/usr/bin/env bash
# SessionStart hook: in an app with a design system, tell the main session when
# to delegate to the design-reviewer agent. Silent everywhere else.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
[ -f "$root/docs/design-system/README.md" ] || exit 0

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "This app has a design system in docs/design-system/ and the rails-design-system:design-reviewer agent is installed. After changing views, components, or view CSS, and before committing or opening a PR, delegate a review of the change to rails-design-system:design-reviewer without being asked (skip copy-only edits). It reviews code by default; ask it for a visual check with screenshots only when the user wants one, and give it the running dev server URL. Fix what it finds, or tell the user which findings you deferred and why."
  }
}
EOF
