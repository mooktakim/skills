# rails-generators

Makes Claude use the Rails framework's own generators and commands instead of writing their files by hand. Left alone, Claude writes migrations directly - with hand-picked timestamps such as `20260930130000`, a typed `Migration[x.y]` tag, and no test or fixture beside a new model - and edits files the framework owns, like `db/schema.rb`. This plugin tells it the right command, and stops the worst cases before they happen.

## What it ships

- **The `rails-generators` skill** - 13 rules, plus references loaded on demand:
  - `migrations.md` - why the generator (timestamps, version tags and their compatibility shims, generated bodies), the name patterns and field syntax (`string!`, `:uniq`, `{10,2}`, references, `digest`, `token`, rich text and attachments), options and multiple databases, the migrate-redo-diff routine, changing a migration safely, schema.rb and its merge conflicts, reversible bodies, data changes, and production-safe patterns.
  - `generators.md` - running generators safely (`--pretend`, `--skip`, why a generator with no terminal overwrites, exit codes that lie), the app's generator settings and template overrides, what each generator writes, gem generators and installers (Stimulus, ViewComponent, Solid Queue/Cache/Cable, Active Storage, Action Text), and what has no generator.
  - `commands.md` - credentials without an interactive editor, gems, importmap pins and node packages, `app:update`, routes, database tasks, and `runner`, `boot`, `zeitwerk:check`.
- **A `PreToolUse` guard** - in any directory with `bin/rails`, it refuses a new migration written with Write, Edit, or a shell command, and any write to `db/schema.rb`, `db/structure.sql`, `db/<name>_schema.rb`, encrypted credentials, or `Gemfile.lock`, and tells Claude the command to run instead. Editing a migration that has already run gets a note on how to change it safely. Tool calls that name none of those files never start Ruby.
- **A `SessionStart` hook** - in Rails apps only, it tells the main session to use the commands and when to load the skill.

## Where the standard comes from

The Rails source and CHANGELOGs (8.0, 8.1.4, and `main`), the Active Record migrations, generators, and configuring guides, every generator run under `--pretend` on a fresh Rails 8.1.4 app, the strong_migrations README (2.8.0), and the importmap-rails, stimulus-rails, view_component, and Solid gems' source.

## Install

```
/plugin marketplace add mooktakim/skills
/plugin install rails-generators@mooktakim
```

## How to use it

Nothing to do: in a Rails app, Claude gets the rules at session start and loads the skill when it changes the schema or creates a file a generator makes. The guard catches the rest. To ask directly - "which command adds a polymorphic reference?", "fix the schema.rb conflict" - invoke `/rails-generators:rails-generators`.

If the guard ever blocks something it should not, disable the plugin for that session with `/plugin disable rails-generators@mooktakim` and tell the author.
