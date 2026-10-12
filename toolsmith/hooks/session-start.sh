#!/usr/bin/env bash
# SessionStart hook: list the toolsmith commands for Claude, and say when a history scan is due.
# Prefers the system Ruby, which starts fastest. Never fails the hook.
ruby=/usr/bin/ruby
[ -x "$ruby" ] || ruby=$(command -v ruby) || exit 0
"$ruby" --disable-gems "$(dirname "${BASH_SOURCE[0]}")/../scripts/registry" context 2>/dev/null
exit 0
