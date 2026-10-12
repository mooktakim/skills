#!/usr/bin/env bash
# PreToolUse hook (Write, Edit, Bash): the first time in a session that a tool
# call touches Stimulus controllers, Turbo Streams, or broadcasts, tell Claude to load the
# rails-hotwire skill. The SessionStart note misses sessions where the
# app appears later (built in the session) or started before the plugin was
# installed. Once per session; silent in subagents. Never blocks.
input=$(cat)
case "$input" in *app/javascript/controllers/*|*.turbo_stream.erb*|*turbo_stream_from*|*broadcasts_refreshes*|*broadcast_*_to*) ;; *) exit 0 ;; esac
case "$input" in *'"agent_id"'*) exit 0 ;; esac
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
    "additionalContext": "This is the first time in this session you touch Stimulus controllers, Turbo Streams, or broadcasts. If you have not loaded the rails-hotwire:rails-hotwire skill in this session, load it now and follow it. To build interactive UI (frames, streams, broadcasts, Stimulus) with its views and tests, delegate to rails-hotwire:hotwire-builder when subagents are available."
  }
}
JSON
exit 0
