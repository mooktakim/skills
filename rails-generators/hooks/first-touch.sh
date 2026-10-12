#!/usr/bin/env bash
# PreToolUse hook (Write, Edit, Bash): the first time in a session that a tool
# call touches migrations, the schema, or generators, tell Claude to load the
# rails-generators skill. The SessionStart note misses sessions where the
# app appears later (built in the session) or started before the plugin was
# installed. Once per session; silent in subagents. Never blocks.
input=$(cat)
case "$input" in *db/migrate/*|*db/schema.rb*|*'rails g '*|*'rails generate '*) ;; *) exit 0 ;; esac
case "$input" in *'"agent_id"'*) exit 0 ;; esac
# Only in a Rails app: the project directory, or an app directly below it.
root=${CLAUDE_PROJECT_DIR:-$PWD}
for app in "$root" "$root"/*; do
  [ -f "$app/config/application.rb" ] && break
  app=""
done
[ -n "$app" ] || exit 0
session=$(printf '%s' "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
[ -n "$session" ] || exit 0
dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}/first-touch"
mkdir -p "$dir" 2>/dev/null || exit 0
stamp="$dir/$(printf '%s' "$session" | tr -c 'A-Za-z0-9_-' '_')"
[ -e "$stamp" ] && exit 0
touch "$stamp"
find "$dir" -type f -mtime +7 -delete 2>/dev/null
cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "This is the first time in this session you touch migrations, the schema, or a Rails generator. If you have not loaded the rails-generators:rails-generators skill in this session, load it now and follow it: generate every migration and file kind a generator makes, put the fields in the generator command so it writes the body, read its output, and edit what it wrote - never silence it and replace the whole file."
  }
}
JSON
exit 0
