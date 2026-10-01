#!/usr/bin/env bash
# PostToolUse / Stop / SubagentStop hook: run this plugin's own audit_design
# against the project, so every app with a design system gets the current checks
# the moment the plugin updates - no per-app wiring, no maintenance run needed.
# Silent in projects without docs/design-system/.
root=${CLAUDE_PROJECT_DIR:-}
[ -n "$root" ] && [ -f "$root/docs/design-system/README.md" ] || exit 0
AUDIT_ROOT="$root" exec bash "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/scripts/audit_design" "$@"
