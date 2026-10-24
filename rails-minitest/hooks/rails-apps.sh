# Sourced by the hooks of every Rails plugin. Keep this file byte-identical in
# all of them (test/hooks_test.rb checks): the plugins share one list of the
# project's Rails apps, so the search runs once per session, not on every tool
# call, and each hook acts only for the apps in the list.
#
# rails_apps <project dir> [fresh | <hook input>]: the Rails apps in the project,
#   one absolute path per line. An app is a directory whose
#   config/application.rb defines a Rails::Application, at any depth git sees
#   (files it ignores are skipped; outside git, dependency and build
#   directories are), plus a symlinked app one level down. Hidden directories,
#   an engine's test/dummy or spec/dummy, and an app inside another app are not
#   apps. The list is cached for every plugin in $TMPDIR/claude-rails-apps/;
#   "fresh" searches again and rewrites it (the SessionStart hooks pass it). A
#   hook input that may create or remove an app (rails new, or a path ending in
#   config/application.rb) drops the list and searches without caching, so the
#   first hook after that tool call searches again. Cached apps that no longer
#   exist are left out.
# rails_apps_forget <project dir> <hook input>: only the drop, for a hook that
#   exits early on most tool calls; call it before that early exit.
# rails_app_of <hook input> <apps>: the app a tool call works in - the one that
#   holds its file_path, else the one its cwd is in, else the first one its
#   command names - or nothing.

_rails_apps_cache() { # <project dir>
  printf '%s/claude-rails-apps/%s\n' "${TMPDIR:-/tmp}" "$(printf '%s' "$1" | cksum | cut -d' ' -f1)"
}

rails_apps_forget() {
  case "${2:-}" in *'rails new'*|*config/application.rb*) rm -f "$(_rails_apps_cache "$1")" ;; esac
  return 0
}

rails_apps() {
  local root=$1 cache list app
  cache=$(_rails_apps_cache "$root")
  case "${2:-}" in
    fresh) ;;
    *'rails new'*|*config/application.rb*)
      rails_apps_forget "$root" "$2"
      _rails_apps_search "$root"
      return 0
      ;;
    *)
      if [ -f "$cache" ]; then
        while IFS= read -r app; do
          [ -f "$app/config/application.rb" ] && printf '%s\n' "$app"
        done < "$cache"
        return 0
      fi
      ;;
  esac
  list=$(_rails_apps_search "$root")
  mkdir -p "${cache%/*}" 2>/dev/null && printf '%s\n' "$list" | sed '/^$/d' > "$cache.$$" && mv -f "$cache.$$" "$cache"
  [ -n "$list" ] && printf '%s\n' "$list"
  return 0
}

_rails_apps_search() { # <project dir>
  local root=$1 file dir
  {
    if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git -C "$root" ls-files -z --cached --others --exclude-standard -- ':(glob)**/config/application.rb' 2>/dev/null \
        | while IFS= read -r -d '' file; do printf '%s/%s\n' "$root" "$file"; done
    else
      find "$root" -path "$root/*" \( -name '.*' -o -name node_modules -o -name vendor -o -name tmp -o -name log -o -name storage \
        -o -name coverage -o -name dist -o -name build -o -name target \) -prune -o -path '*/config/application.rb' -print 2>/dev/null
    fi
    for dir in "$root"/*/; do
      [ -L "${dir%/}" ] && [ -f "${dir}config/application.rb" ] && printf '%s\n' "${dir}config/application.rb"
    done
  } | sort -u | while IFS= read -r file; do
    dir=${file%/config/application.rb}
    [ "$file" = "$root/config/application.rb" ] && dir=$root
    case "/${dir#"$root"}/" in */.*/*|*/node_modules/*|*/vendor/*|*/tmp/*|*/test/dummy/*|*/spec/dummy/*) continue ;; esac
    grep -q 'Rails::Application' "$file" 2>/dev/null || continue
    printf '%s\n' "$dir"
  done | _rails_apps_outermost
}

_rails_apps_outermost() { # stdin: app paths; stdout: those not inside another
  local apps app other inside
  apps=$(cat)
  while IFS= read -r app; do
    [ -n "$app" ] || continue
    inside=""
    while IFS= read -r other; do
      [ "$other" = "$app" ] && continue
      case "$app/" in "$other"/*) inside=1 ;; esac
    done <<LIST
$apps
LIST
    [ -n "$inside" ] || printf '%s\n' "$app"
  done <<LIST
$apps
LIST
}

_rails_apps_field() { # <hook input> <name>: the first string value of "name"
  printf '%s' "$1" | grep -o "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 \
    | sed 's/^"[^"]*"[[:space:]]*:[[:space:]]*"//; s/"$//'
}

rails_app_of() {
  local input=$1 apps=$2 root=${CLAUDE_PROJECT_DIR:-$PWD} file cwd app words best=""
  [ -n "$apps" ] || return 0
  cwd=$(_rails_apps_field "$input" cwd)
  [ -n "$cwd" ] || cwd=$root
  file=$(_rails_apps_field "$input" file_path)
  if [ -n "$file" ]; then
    case "$file" in /*) ;; *) file="$cwd/$file" ;; esac
  else
    file=$cwd
  fi
  while IFS= read -r app; do
    case "$file/" in "$app"/*) [ ${#app} -gt ${#best} ] && best=$app ;; esac
  done <<EOF
$apps
EOF
  if [ -z "$best" ] && [ -z "$(_rails_apps_field "$input" file_path)" ]; then
    # The words of the command: an app is named by its path, absolute or from
    # the cwd or the project, alone (cd web) or before a slash (web/app/x.rb).
    words=$(printf '%s' "$input" | sed 's/\\[nt]/ /g' | tr " \t;&|()<>'\"=\\\\" '\n' | sed 's|^\./||')
    while IFS= read -r app; do
      if printf '%s\n' "$words" | awk -v a="$app" -v c="${app#"$cwd"/}" -v r="${app#"$root"/}" '
        $0 == a || $0 == c || $0 == r || index($0, a "/") == 1 || index($0, c "/") == 1 || index($0, r "/") == 1 { found = 1 }
        END { exit !found }'; then
        best=$app
        break
      fi
    done <<EOF
$apps
EOF
  fi
  [ -n "$best" ] && printf '%s\n' "$best"
  return 0
}
