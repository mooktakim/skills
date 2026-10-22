# Sourced by the hooks. design_roots <project dir>: the apps with a design system
# (docs/design-system/README.md), one absolute path per line - the project
# directory itself, or else each directory up to three levels below it that has
# one (an app inside a larger repository, such as studio/ or apps/server/). The
# search does not look inside an app it found, hidden directories, symlinks, or
# dependency and build directories, so it stays cheap enough to run on every
# edit. Keep in step with rails-context's copy.
design_roots() {
  if [ -f "$1/docs/design-system/README.md" ]; then
    printf '%s\n' "$1"
    return
  fi
  _design_roots_below "$1" 3
  return 0
}

_design_roots_below() { # <dir> <levels left>
  local dir
  for dir in "$1"/*/; do
    dir=${dir%/}
    [ -d "$dir" ] && [ ! -L "$dir" ] || continue
    case "${dir##*/}" in node_modules|vendor|tmp|log|storage|coverage|dist|build|target) continue ;; esac
    if [ -f "$dir/docs/design-system/README.md" ]; then
      printf '%s\n' "$dir"
    elif [ "$2" -gt 1 ]; then
      _design_roots_below "$dir" $(($2 - 1))
    fi
  done
}
