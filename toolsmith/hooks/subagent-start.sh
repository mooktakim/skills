#!/usr/bin/env bash
# SubagentStart hook: give a subagent the toolsmith command list. A subagent never
# sees the SessionStart note, so without this it does not know the commands exist.
# Skipped in a Bridge agent session (BRIDGE_SESSION_TOKEN is set), like pre-bash.sh.
# Prefers the system Ruby, which starts fastest. Never fails the hook.
[ -n "${BRIDGE_SESSION_TOKEN:-}" ] && exit 0
ruby=/usr/bin/ruby
[ -x "$ruby" ] || ruby=$(command -v ruby) || exit 0
"$ruby" --disable-gems "$(dirname "${BASH_SOURCE[0]}")/../scripts/registry" subagent 2>/dev/null
exit 0
