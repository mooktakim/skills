# Commands that replace hand edits

Each section names files Claude must not write directly, and the command that writes them.

## Credentials

`config/credentials.yml.enc` and `config/credentials/<env>.yml.enc` are encrypted; a direct write corrupts them. `bin/rails credentials:edit` decrypts to a temporary file, opens `$VISUAL` (or `$EDITOR`), and encrypts the result.

- Read: `bin/rails credentials:show` (add `-e production` for an environment file), or one value with `bin/rails credentials:fetch stripe.secret_key` (8.1+). Do not print secrets into the conversation unless the task needs the value; prefer checking that a key exists.
- Change without an interactive editor - the editor command is split like a shell command but not run by a shell, so pass a Ruby one-liner that loads the YAML, changes it, and writes it back:

  ```sh
  VISUAL="ruby -ryaml -e 'p = ARGV[0]; h = YAML.load_file(p) || {}; (h[%q(stripe)] ||= {})[%q(secret_key)] = %q(sk_test_123); File.write(p, h.to_yaml)'" bin/rails credentials:edit
  ```

  Ask the user for the secret value; never invent one or copy one from another environment. Note that `to_yaml` drops comments in the file.
- **Check the output for "Invalid YAML".** Invalid YAML is still encrypted and saved, the command exits 0, and then every `bin/rails` command fails with `InvalidContentError`. Run `bin/rails credentials:show` afterwards to prove it still decrypts.
- Never write, print, or commit `config/master.key` or `config/credentials/*.key`.
- Related: `bin/rails encrypted:edit config/<file>.yml.enc` for other encrypted files; `bin/rails db:encryption:init` prints keys to add to credentials (it writes nothing); `bin/rails secret` prints a random secret.

## Gems

`Gemfile.lock` is written by Bundler only.

- Add: `bundle add NAME` (`--group development`, `--require false`, `--version`). It appends the line at the end of the Gemfile; moving it into the right group block afterwards is a normal Gemfile edit. Editing the Gemfile and running `bundle install` is equally fine.
- Remove: `bundle remove NAME`.
- Update one gem without moving others: `bundle update NAME --conservative`.
- Follow the app's rule on version constraints (many apps pin only Rails).
- Then run the gem's installer if it has one, rather than copying its setup by hand.

## JavaScript packages

- **importmap apps** (`config/importmap.rb`): `bin/importmap pin NAME` downloads the package to `vendor/javascript/` and adds the pin; `bin/importmap unpin NAME` removes both. Hand-written pins leave the vendored file missing or stale. Also `bin/importmap outdated`, `update`, `audit`. Local files under `app/javascript` are pinned by the existing `pin_all_from` lines - no new pin needed.
- **jsbundling apps** (`package.json`): the package manager whose lockfile the app has - `yarn add`, `npm install`, `bun add`, `pnpm add`. Never edit the lockfile.

## Rails upgrades

`bin/rails app:update` writes the new framework defaults (`config/initializers/new_framework_defaults_X_Y.rb`) and updated config files and binstubs. It prompts for each changed file, and with no terminal it overwrites, so run it on a clean tree with `--force`, then go through `git diff` file by file and restore the app's own customisations. Upgrade work belongs to the `rails-specialists:rails-upgrade` agent when it is installed.

## Routes

A generator adds the routes it needs. For anything else, edit `config/routes.rb` by hand, then check with `bin/rails routes -g NAME` (or `-c Controller`); `bin/rails routes --unused` finds routes with no action.

## Database tasks

- `bin/rails db:prepare` - create, load the schema, and seed a new database, or migrate an existing one. The first command in a new worktree or checkout.
- `bin/rails db:migrate`, `db:rollback`, `db:migrate:redo`, `db:migrate:status` - see `migrations.md`.
- `bin/rails db:seed`; `db:seed:replant` empties the tables first (development only).
- `bin/rails db:system:change --to=postgresql` switches the database adapter's config files.
- Never drop, reset, or replant a database other than local development without the user's go-ahead.

## Checks and one-offs

- `bin/rails runner 'code'` or `bin/rails runner script/x.rb` - run code in the app (prefer it over a console session Claude cannot drive).
- `bin/rails boot` (7.2+) - boots the app and exits; a quick check after config changes. `bin/rails zeitwerk:check` - every file autoloads under the expected constant.
- `bin/rails about`, `initializers`, `middleware`, `stats`, `notes` - read the app's setup instead of guessing.
- `bin/rails restart` (touches `tmp/restart.txt`), `dev:cache` (toggle caching in development), `tmp:clear`, `log:clear`.
