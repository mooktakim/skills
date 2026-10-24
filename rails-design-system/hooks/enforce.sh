#!/usr/bin/env bash
# PostToolUse / Stop / SubagentStop hook: run this plugin's own audit_design
# against each app with a design system, so every app gets the current checks the
# moment the plugin updates - no per-app wiring, no maintenance run needed.
# Only for the project's Rails apps with a design system
# (docs/design-system/README.md), from the list hooks/rails-apps.sh keeps.
root=${CLAUDE_PROJECT_DIR:-}
[ -n "$root" ] || exit 0
input=$(cat)
. "$(dirname "$0")/rails-apps.sh"
apps=$(rails_apps "$root" "$input" | while IFS= read -r app; do [ -f "$app/docs/design-system/README.md" ] && printf '%s\n' "$app"; done)
[ -n "$apps" ] || exit 0
plugin=${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}

# Version-manager shims (asdf, rbenv) cost ~150 ms per call, on every edit. Resolve
# the project's Ruby binary through the shim once and cache it; a cached binary
# that has since been removed is resolved again.
data=${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}
cache="$data/ruby-$(printf '%s' "$root" | cksum | cut -d' ' -f1)"
ruby=$(cat "$cache" 2>/dev/null)
if [ ! -x "$ruby" ]; then
  ruby=$(cd "$root" && ruby -e 'print RbConfig.ruby' 2>/dev/null) || exit 0
  mkdir -p "$data" 2>/dev/null && printf '%s' "$ruby" > "$cache"
fi

# The worst exit status of the apps' runs: 2 sends the findings back to Claude.
status=0
while IFS= read -r app; do
  printf '%s' "$input" | AUDIT_ROOT="$app" "$ruby" --disable-gems "$plugin/scripts/audit_design" "$@"
  code=$?
  [ "$code" -gt "$status" ] && status=$code
done <<<"$apps"
exit "$status"
