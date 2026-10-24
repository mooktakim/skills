#!/usr/bin/env bash
# PostToolUse hook (Bash, Write, Edit, Grep): hand Claude the directory context
# files for the code a tool call touched, when the Read tool's automatic loading
# was bypassed. The logic lives in scripts/inject_context. Silent, never blocks,
# and only active for the project's Rails apps set up with rails-context
# (bin/audit_context), from the list hooks/rails-apps.sh keeps.
root=${CLAUDE_PROJECT_DIR:-}
[ -n "$root" ] || exit 0
input=$(cat)
. "$(dirname "$0")/rails-apps.sh"
apps=$(rails_apps "$root" "$input" | while IFS= read -r app; do [ -x "$app/bin/audit_context" ] && printf '%s\n' "$app"; done)
[ -n "$apps" ] || exit 0
plugin=${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}

# Version-manager shims (asdf, rbenv) cost ~150 ms per call, on every tool call.
# Resolve the project's Ruby binary through the shim once and cache it; a cached
# binary that has since been removed is resolved again.
data=${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}
cache="$data/ruby-$(printf '%s' "$root" | cksum | cut -d' ' -f1)"
ruby=$(cat "$cache" 2>/dev/null)
if [ ! -x "$ruby" ]; then
  ruby=$(cd "$root" && ruby -e 'print RbConfig.ruby' 2>/dev/null) || exit 0
  mkdir -p "$data" 2>/dev/null && printf '%s' "$ruby" > "$cache"
fi
printf '%s' "$input" | APP_ROOTS="$apps" "$ruby" --disable-gems "$plugin/scripts/inject_context" 2>/dev/null
exit 0
