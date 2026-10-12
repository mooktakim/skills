#!/usr/bin/env bash
# PreToolUse hook (Bash): remind Claude of a toolsmith command when the Bash command matches a pattern one replaces.
# Prefers the system Ruby, which starts fastest. Never fails the hook.
ruby=/usr/bin/ruby
[ -x "$ruby" ] || ruby=$(command -v ruby) || exit 0
# --disable-gems: the registry needs only the standard library, and loading
# RubyGems would add ~40 ms to every Bash call.
"$ruby" --disable-gems "$(dirname "${BASH_SOURCE[0]}")/../scripts/registry" check 2>/dev/null
exit 0
