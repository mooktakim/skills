#!/usr/bin/env bash
# Logs when context files reach Claude, and which files each session changed, so
# scripts/context_report can measure whether a directory's CLAUDE.md reaches
# Claude in the sessions that change code there. Local only: one JSONL file in
# the repo's git directory (shared by worktrees, never committed). Silent, never
# blocks, and only active in projects set up with rails-context (bin/audit_context
# in the project directory or in an app directly below it). Paths are logged
# relative to the top of the git repository, so apps in one repository never mix.
# Modes (one per hook event):
#   start  SessionStart                 the HEAD the session started from
#   compact SessionStart (compact)      context compacted: earlier loads are gone
#   load   InstructionsLoaded           a CLAUDE.md or rule file loaded into context
#   read   PostToolUse (Read)           Claude read a CLAUDE.md or AGENTS.md itself
#   stop   Stop                         files changed since the session started,
#                                       by any tool - Bash edits included
root=${CLAUDE_PROJECT_DIR:-}
[ -n "$root" ] || exit 0
. "$(dirname "$0")/app-roots.sh"
[ -n "$(app_roots "$root")" ] || exit 0
top=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null) || exit 0
prefix=$(git -C "$root" rev-parse --show-prefix 2>/dev/null)
gitdir=$(git -C "$root" rev-parse --git-common-dir 2>/dev/null) || exit 0
case "$gitdir" in /*) ;; *) gitdir="$root/$gitdir" ;; esac
log="$gitdir/claude-context-log.jsonl"
input=$(cat)

field() { # field <name>: the first string value of "name" in the hook input
  printf '%s' "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 \
    | sed 's/^"[^"]*"[[:space:]]*:[[:space:]]*"//; s/"$//'
}
esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
rel() { # a path relative to the top of the repository
  local p=$1
  case "$p" in "$top"/*) p=${p#"$top"/} ;; "$root"/*) p="$prefix${p#"$root"/}" ;; esac
  esc "$p"
}
emit() { printf '{"t":"%s","s":"%s",%s}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(esc "$(field session_id)")" "$1" >> "$log"; }

case "${1:-}" in
  start)
    emit "\"e\":\"start\",\"head\":\"$(git -C "$top" rev-parse -q --verify HEAD 2>/dev/null)\""
    ;;
  compact)
    emit "\"e\":\"compact\""
    ;;
  load)
    file=$(field file_path)
    [ -n "$file" ] || exit 0
    emit "\"e\":\"load\",\"f\":\"$(rel "$file")\",\"r\":\"$(esc "$(field load_reason)")\",\"by\":\"$(rel "$(field trigger_file_path)")\""
    ;;
  read)
    file=$(field file_path)
    case "$file" in */CLAUDE.md|*/AGENTS.md|CLAUDE.md|AGENTS.md) ;; *) exit 0 ;; esac
    emit "\"e\":\"read\",\"f\":\"$(rel "$file")\""
    ;;
  stop)
    sid=$(esc "$(field session_id)")
    head=$(grep -F "\"s\":\"$sid\",\"e\":\"start\"" "$log" 2>/dev/null | tail -1 | sed -n 's/.*"head":"\([0-9a-f]*\)".*/\1/p')
    [ -n "$head" ] || head=HEAD
    files=$( { git -C "$top" diff --name-only "$head" 2>/dev/null; git -C "$top" ls-files --others --exclude-standard 2>/dev/null; } \
      | sort -u | while IFS= read -r f; do printf '"%s",' "$(esc "$f")"; done)
    [ -n "$files" ] || exit 0
    list="[${files%,}]"
    last=$(grep -F "\"s\":\"$sid\",\"e\":\"changed\"" "$log" 2>/dev/null | tail -1 | sed 's/.*"files"://; s/}$//')
    [ "$last" = "$list" ] && exit 0 # unchanged since the last turn
    emit "\"e\":\"changed\",\"files\":$list"
    ;;
esac

# Keep the log bounded: past ~5 MB, keep the newest 10,000 events.
if [ "$(wc -c < "$log" 2>/dev/null || echo 0)" -gt 5000000 ]; then
  tail -n 10000 "$log" > "$log.tmp" && mv "$log.tmp" "$log"
fi
exit 0
