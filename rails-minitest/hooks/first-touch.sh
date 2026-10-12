#!/usr/bin/env bash
# PreToolUse hook (Write, Edit, Bash): the first time in a session that a tool
# call touches Minitest tests, tell Claude to load the
# rails-minitest skill. The SessionStart note misses sessions where the
# app appears later (built in the session) or started before the plugin was
# installed. Once per session; silent in subagents. Never blocks.
input=$(cat)
case "$input" in *test/*_test.rb*|*test/fixtures/*|*test/test_helper*|*test/test_helpers/*) ;; *) exit 0 ;; esac
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
    "additionalContext": "This is the first time in this session you touch Minitest tests. If you have not loaded the rails-minitest:rails-minitest skill in this session, load it now and follow it before writing or changing tests. Run suites with toolsmith-check-run when it is on PATH; delegate writing tests for a finished change, or a failing or flaky test, to rails-minitest:minitest-runner when subagents are available."
  }
}
JSON
exit 0
