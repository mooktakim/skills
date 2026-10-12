# Sourced by the hooks. app_roots <project dir>: the Rails apps set up with
# rails-context in the project, one absolute path per line - the project
# directory itself, or else each direct subdirectory that has bin/audit_context
# (an app inside a larger repository, such as studio/ or hub/).
app_roots() {
  if [ -x "$1/bin/audit_context" ]; then
    printf '%s\n' "$1"
    return
  fi
  for dir in "$1"/*/; do
    [ -x "${dir}bin/audit_context" ] && printf '%s\n' "${dir%/}"
  done
  return 0
}
