# Sourced by the hooks. design_roots <project dir>: the apps with a design system
# (docs/design-system/README.md), one absolute path per line - the project
# directory itself, or else each direct subdirectory that has one (an app inside
# a larger repository, such as studio/ or hub/).
design_roots() {
  if [ -f "$1/docs/design-system/README.md" ]; then
    printf '%s\n' "$1"
    return
  fi
  for dir in "$1"/*/; do
    [ -f "${dir}docs/design-system/README.md" ] && printf '%s\n' "${dir%/}"
  done
  return 0
}
