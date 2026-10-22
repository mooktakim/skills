# Sourced by the hooks. app_roots <project dir>: the Rails apps set up with
# rails-context in the project, one absolute path per line - the project
# directory itself, or else each directory up to three levels below it that has
# bin/audit_context (an app inside a larger repository, such as studio/ or
# apps/server/). The search does not look inside an app it found, hidden
# directories, symlinks, or dependency and build directories, so it stays cheap
# enough to run on every tool call. Keep in step with rails-design-system's copy.
app_roots() {
  if [ -x "$1/bin/audit_context" ]; then
    printf '%s\n' "$1"
    return
  fi
  _app_roots_below "$1" 3
  return 0
}

_app_roots_below() { # <dir> <levels left>
  local dir
  for dir in "$1"/*/; do
    dir=${dir%/}
    [ -d "$dir" ] && [ ! -L "$dir" ] || continue
    case "${dir##*/}" in node_modules|vendor|tmp|log|storage|coverage|dist|build|target) continue ;; esac
    if [ -x "$dir/bin/audit_context" ]; then
      printf '%s\n' "$dir"
    elif [ "$2" -gt 1 ]; then
      _app_roots_below "$dir" $(($2 - 1))
    fi
  done
}
