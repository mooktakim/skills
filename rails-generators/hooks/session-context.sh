#!/usr/bin/env bash
# SessionStart hook: in a Rails app (at the project root or one level down), tell
# the main session to use the framework's generators and commands instead of
# writing the files they write, and when to load the rails-generators skill.
# Silent everywhere else.
set -uo pipefail
root=${CLAUDE_PROJECT_DIR:-$PWD}
found=0
for app in "$root" "$root"/*; do
  [ -f "$app/config/application.rb" ] || continue
  grep -q 'Rails::Application' "$app/config/application.rb" 2>/dev/null || continue
  found=1
  break
done
[ "$found" -eq 1 ] || exit 0

cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "This is a Rails app and the rails-generators plugin is installed. When Rails, Bundler, or a gem has a command that writes or changes a file, run the command instead of writing the file yourself, then edit what it wrote: `bin/rails generate migration` or `generate model` for every schema change (never hand-pick a migration timestamp), `bin/rails db:migrate` to change db/schema.rb, `bin/rails generate` for models, controllers, jobs, mailers, channels, Stimulus controllers, and components, `bin/rails credentials:edit` for credentials, `bundle add` / `bundle install` for gems, `bin/importmap pin` for importmap packages, and the gems' own installers. Load the rails-generators:rails-generators skill before you create a migration or a new model, job, mailer, channel, controller, or other file a generator makes, and before you change the schema, credentials, gems, or JavaScript pins. A hook refuses hand-written migrations and hand edits to schema dumps, encrypted credentials, and Gemfile.lock."
  }
}
JSON
