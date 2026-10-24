#!/usr/bin/env bash
# PreToolUse hook (Write, Edit, MultiEdit, Bash): refuse hand-written migrations
# and hand edits to files Rails or Bundler generate, naming the command to use
# instead. The logic lives in scripts/guard_files; this wrapper skips every call
# that names none of those files, and every project without a Rails app
# (hooks/rails-apps.sh), so most tool calls never start Ruby.
input=$(cat)
# A call that may create or remove a Rails app drops the shared list first.
root=${CLAUDE_PROJECT_DIR:-$PWD}
. "$(dirname "$0")/rails-apps.sh"
rails_apps_forget "$root" "$input"
case "$input" in
  *db/*|*.enc*|*Gemfile.lock*|*gems.locked*) ;;
  *) exit 0 ;;
esac
plugin=${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}
[ -n "$(rails_apps "$root" "$input")" ] || exit 0

# Version-manager shims (asdf, rbenv) cost ~150 ms per call. Resolve the
# project's Ruby binary through the shim once and cache it; a cached binary that
# has since been removed is resolved again.
data=${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}
cache="$data/ruby-$(printf '%s' "$root" | cksum | cut -d' ' -f1)"
ruby=$(cat "$cache" 2>/dev/null)
if [ ! -x "$ruby" ]; then
  ruby=$(cd "$root" && ruby -e 'print RbConfig.ruby' 2>/dev/null) || exit 0
  mkdir -p "$data" 2>/dev/null && printf '%s' "$ruby" > "$cache"
fi
printf '%s' "$input" | "$ruby" --disable-gems "$plugin/scripts/guard_files" 2>/dev/null
exit 0
