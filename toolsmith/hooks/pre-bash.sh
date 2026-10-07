#!/usr/bin/env bash
# PreToolUse hook (Bash): remind Claude of a toolsmith command when the Bash command matches a pattern one replaces.
# Prefers the system Ruby, which starts fastest. Never fails the hook.
ruby=/usr/bin/ruby
[ -x "$ruby" ] || ruby=$(command -v ruby) || exit 0
"$ruby" "$(dirname "${BASH_SOURCE[0]}")/../scripts/registry" check 2>/dev/null
exit 0
