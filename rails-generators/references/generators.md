# Generators

Checked against Rails 8.1.4 with every generator run under `--pretend`. `bin/rails generate` with no arguments lists the generators this app has - built-ins plus whatever its gems register. `bin/rails generate NAME --help` lists a generator's options.

## Run them safely

- **Look first.** `bin/rails generate model Post title:string --pretend` prints every file it would create or change and writes nothing.
- **Always pass `--skip` (or `--force`) when a file might exist.** When a file exists with different content, the generator asks `Overwrite ...? [Ynaqdhm]`. Claude's commands have no terminal, so the answer defaults to **Y and the file is overwritten**. `--skip` keeps existing files; `--force` is for replacing your own just-generated output only.
- **Read the output, not the exit code.** A class name that is already taken ("The name 'PagesController' is either already used ...") and a duplicate migration name ("Another migration is already named ...") both exit 0 having written nothing. Only an unknown generator exits non-zero.
- **Undo with `bin/rails destroy <generator> <same args>`.** It removes what the generator made and takes back its route and file edits. Roll a migration back (`db:migrate:down`) before destroying it.
- **Spring** has not been a default since Rails 7.0. If the app still has `bin/spring`, run `bin/spring stop` after changing generator config or templates.
- **Docker or a devcontainer**: run the command where the app runs - `docker compose exec <service> bin/rails generate ...` (the Rails devcontainer service is `rails-app`). Check that generated files are not owned by root on the host.

## The app's own settings come for free

Generators read the app's choices, so their output already matches the app without Claude having to find each choice:

- `config.generators` in `config/application.rb`: UUID primary keys (`g.orm :active_record, primary_key_type: :uuid`), the test framework and whether it makes fixtures (`g.test_framework :test_unit, fixture: false`), no helpers (`g.helper false`), the template engine, `g.system_tests nil`.
- Template overrides in `lib/templates/<namespace>/<generator>/<file>.tt` (e.g. `lib/templates/erb/scaffold/index.html.erb.tt`) replace the built-in templates.
- Custom generators in `lib/generators/`.

Read these before generating, so you know what will come out; never pass options that fight them (no `--primary-key-type` in a UUID app - it is already set).

## What each one writes

| Command | Writes |
|---|---|
| `model Post title:string user:references` | migration, model (with `belongs_to`), model test, fixture |
| `migration AddBodyToPosts body:text` | the migration only (see `migrations.md`) |
| `controller Pages home about` | controller, one view per action, a `get` route per action, controller test, helper |
| `resource Comment body:text` | everything `model` writes, plus an empty controller, views directory, controller test, helper, and `resources :comments` |
| `scaffold Article title:string` | everything `resource` writes, plus the seven actions, six views (with `_form` and `_article`), jbuilder views; no system test since 8.1 (`--system-tests=true` adds one) |
| `scaffold_controller Widget name` | controller, views, route, tests, helper - no model |
| `job ProcessUpload` | job and job test; `ApplicationJob` if missing. `--queue NAME` |
| `mailer Notifier welcome` | mailer, html and text views per action, mailer test, preview; `ApplicationMailer` if missing |
| `mailbox Replies` | mailbox, `ApplicationMailbox`, mailbox test |
| `channel Chat speak` | channel, `ApplicationCable` connection and channel, channel test; the first one in a JS app also writes `channels/index.js` and `consumer.js`, imports them in `application.js`, and pins Action Cable (importmap) or adds the package (node/bun), then writes `chat_channel.js` |
| `helper`, `integration_test`, `system_test` | the file and its test; `system_test` adds `ApplicationSystemTestCase` if missing |
| `task maintenance cleanup` | `lib/tasks/maintenance.rake` |
| `script data/backfill_slugs` | `script/data/backfill_slugs.rb` (8.0+) - one-off code, run with `bin/rails runner` |
| `authentication` | User, Session, Current; sessions and passwords controllers; the `Authentication` concern in ApplicationController; routes; passwords mailer and views; bcrypt enabled and `bundle install`; two migrations; fixtures; tests |
| `generator thing` | a custom generator skeleton in `lib/generators/thing/` and its test |

Generators from gems (present only when the app has the gem):

- **stimulus-rails** - `bin/rails generate stimulus admin/hello` writes `app/javascript/controllers/admin/hello_controller.js`. In an importmap app nothing else is needed (`eagerLoadControllersFrom` finds it). In a jsbundling app the generator also runs `stimulus:manifest:update`, which registers it in `controllers/index.js`; a hand-made controller there stays unregistered until you run `bin/rails stimulus:manifest:update`.
- **view_component 4.x** - `bin/rails generate view_component:component Name title body`, with `--preview`, `--stimulus`, `--sidecar`, `--inline`, `--parent`. The old `generate component` name is gone.
- **Installers** - `bin/rails solid_queue:install`, `solid_cache:install`, `solid_cable:install`, `active_storage:install`, `action_text:install`, `action_mailbox:install`, `turbo:install`, `stimulus:install`, a gem's `rails generate <gem>:install` (e.g. `devise:install`). They write config, schema files, migrations, binstubs, and JavaScript wiring together. `solid_queue:update` / `solid_cable:update` copy a new gem version's migrations; `bin/rails railties:install:migrations` copies an engine's.

## When there is no generator

Some files have no generator and are written by hand: concerns, service or form objects, POROs in `app/models`, policies (unless the gem has a generator), Stimulus controllers' bodies, views for an existing action, and the body of everything a generator made. Write those following the app's existing files. "No generator" means checked with `bin/rails generate` - not assumed.
