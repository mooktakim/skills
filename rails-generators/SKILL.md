---
name: rails-generators
description: Run the Rails, Bundler, and gem commands that write files instead of writing those files by hand. Use before creating a migration or changing the schema; before creating a model, controller, job, mailer, channel, Stimulus controller, component, rake task, or script; before changing credentials, gems, or importmap pins; when a migration fails or schema.rb has a merge conflict; or when asked which Rails command does something.
---

# Rails generators and commands

When Rails, Bundler, or a gem has a command that writes a file, you run the command and then edit what it wrote. You never write that file from scratch, and never edit a file the framework owns. Commands get the details right that hand-written files get wrong: migration timestamps and version tags, the test and fixture beside a model, routes, Stimulus and Action Cable registration, vendored JavaScript, encrypted credentials, and the app's own generator settings.

The `references/` files beside this file hold the detail. They ship with this skill, so resolve their paths from this skill's directory (`${CLAUDE_SKILL_DIR}`), not the app. Read the matching one first:

| Read | Before |
|---|---|
| `references/migrations.md` | any schema change: generating, the name patterns and field syntax, running and reversing, editing a migration, schema.rb and its merge conflicts, data changes, production-safe patterns |
| `references/generators.md` | any other generator: what each one writes, the app's generator settings, gem generators and installers, what has no generator |
| `references/commands.md` | credentials, gems, JavaScript packages, `app:update`, routes, database tasks, `runner` and the other checks |

## Detect first

1. Read `Gemfile.lock` for the Rails version, the database adapter, and the gems that bring generators (stimulus-rails, view_component, importmap-rails or jsbundling-rails, strong_migrations, devise...).
2. Read `config.generators` in `config/application.rb`, and list `lib/templates/` and `lib/generators/` if they exist. The generator follows them; know what it will produce.
3. Read `config/database.yml` for other databases (`migrations_paths`) and `db/` for the schema format (`schema.rb` or `structure.sql`).
4. Find how the app runs: `bin/rails` directly, or inside Docker or a devcontainer (`docker compose exec <service> bin/rails ...`). If `bin/rails` cannot boot, fix that first or tell the user - do not fall back to writing the files.

## Rules

1. **Every schema change starts with `bin/rails generate migration` or `bin/rails generate model`.** Never create a file in `db/migrate/` (or `db/<name>_migrate/`) yourself, never pick or change a timestamp, never type the `Migration[x.y]` tag. Name it so the generator writes the body (`AddSlugToPosts slug:string!:uniq`, `RemoveLegacyIdFromPosts legacy_id:integer`, `CreateJoinTableArtistsMusics artists musics`); a name it cannot read gives an empty `change` for you to fill. Then edit the body it wrote - never silence the generator (`> /dev/null`) and overwrite the whole file.
2. **Use the generator for every file kind it makes** - model, controller, resource, scaffold, job, mailer, mailbox, channel, helper, task, script, system or integration test, Stimulus controller, component, a gem's installer. It writes the test, fixture, route, base class, and JavaScript registration that a hand-written file misses. Then edit the generated files to do the job.
3. **Look before you generate, and never let a generator overwrite.** Run with `--pretend` when unsure what it writes. Pass `--skip` whenever a file might already exist: with no terminal to answer its overwrite prompt, a generator overwrites. Read the output - a name clash prints a message and exits 0 having written nothing.
4. **Do not fight the app's generator settings.** No `--primary-key-type` in an app that sets it, no `--no-fixture` in an app that uses fixtures. Pass an option only to differ from the app on purpose, and say why.
5. **Never edit a generated dump or lockfile:** `db/schema.rb`, `db/structure.sql`, `db/<name>_schema.rb`, `Gemfile.lock`, and package lockfiles. Change their source and run the command - `db:migrate`, `bundle install`, the package manager. A schema.rb merge conflict is resolved by migrating, not by merging lines (`migrations.md`).
6. **After a migration:** read it, migrate, prove it reverses with `bin/rails db:migrate:redo`, and check that `git diff db/schema.rb` shows only your change. Commit the migration and the schema dump together.
7. **Never edit a migration that is committed and shared, or deployed.** Generate a new one. A migration that has run only locally is rolled back (`db:migrate:down VERSION=`) before you edit it.
8. **Keep data changes out of schema migrations** where you can: a `bin/rails generate script` script run with `bin/rails runner`, or a separate migration that uses `update_all`, SQL, or a model class defined inside it - never the app's own model classes.
9. **Write migrations safe for the app's database and deploys.** On PostgreSQL or MySQL with live traffic, follow the safe patterns in `migrations.md` (concurrent indexes, constraints validated later, columns ignored before removal) and any `strong_migrations` message.
10. **Credentials only through `bin/rails credentials:edit`.** Never write `.yml.enc` files or keys, never invent a secret, and check the command's output for "Invalid YAML" (`commands.md`).
11. **Gems with `bundle add` / `bundle remove` / `bundle update NAME --conservative`, importmap packages with `bin/importmap pin`, node packages with the app's package manager.** A Gemfile edit followed by `bundle install` is fine; a hand-written pin or lockfile edit is not.
12. **When a command fails, fix the cause** (the app does not boot, a pending migration, a missing gem) and run it again. Writing the file by hand is not a fallback; if you cannot fix it, stop and tell the user what failed.
13. **Hand-write only what has no generator** - concerns, service and form objects, policies without a gem generator, views for existing actions, and the bodies of generated files - after checking `bin/rails generate` for one.

## The guard

This plugin ships a hook that refuses, before they happen, a new migration written with Write or a shell redirect, and any write to a schema dump, an encrypted credentials file, or `Gemfile.lock`, in any directory that has `bin/rails`. Its message names the command to run. Editing a migration that has already run - with Edit, or in the shell (`sed -i`, `perl -pi`, a glob such as `db/migrate/*_create_users.rb`) - gets a note, not a refusal. When the hook refuses, run the command it names; do not look for another way to write the file.
