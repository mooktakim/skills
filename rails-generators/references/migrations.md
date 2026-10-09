# Migrations

Every schema change goes through a generated migration, run with `bin/rails db:migrate`, which then rewrites the schema dump. Facts below are for Rails 8.0 and 8.1 (8.1.4 is current); differences are marked.

## Why the generator, always

The generator does three things a hand-written file gets wrong:

- **The timestamp.** It takes the later of the current UTC time and the highest existing version plus one, so a new migration always sorts after every existing one and never collides, even twice in one second. A hand-picked timestamp:
  - that repeats a version raises `DuplicateMigrationVersionError`;
  - more than a day in the future raises `InvalidMigrationTimestampError` (`validate_migration_timestamps`, on from `load_defaults 7.2`) - and if that check is off, it pushes every later generated migration after it;
  - in the past runs out of order on any database that has already migrated past it, so production and a fresh `db:prepare` build different schemas.
  Round values such as `20260930130000` are the sign of a hand-written migration. The API docs say plainly: timestamps should not be modified manually.
- **The version tag.** It writes `ActiveRecord::Migration[x.y]` for the running Rails. A version Rails does not know raises "Unknown migration version". An *older* version silently turns on compatibility shims (old index names, old `remove_foreign_key` matching), so the DDL differs with no error.
- **The body.** From the name and fields it writes the right `create_table`, `add_column`, `add_reference` (with `null: false, foreign_key: true`), indexes, and the type on `remove_column` that makes it reversible. `generate model` adds the model, its test, and its fixture too.

## Name patterns

The generator reads the snake_cased name, in this order:

| Name | Body |
|---|---|
| `AddXToTable` (`add_..._to_<table>`) | `add_column :table, :col, :type` per field; `add_index` for `:index` / `:uniq`; `add_reference` for references |
| `RemoveXFromTable` | `remove_column :table, :col, :type` per field (typed, so reversible); `remove_index` first for `:index`; `remove_reference` |
| any name containing `join_table`, with exactly two fields | `create_join_table :as, :bs` with the index lines commented out (uncommented for a field marked `:index` or `:uniq`). The tables come from the two fields, not the name: `CreateJoinTableArtistsMusics artists musics:uniq` |
| `CreateTable` | `create_table` with each field, `t.timestamps`, and its indexes |
| anything else | an empty `change` - fields are ignored |

The name may contain only letters, digits, and underscores. Table names are pluralised. There is no special "Ref" pattern: `AddUserRefToProducts user:references` works because it matches `add_..._to_products`.

## Field syntax

`name[:type[{options}][!]][:index|:uniq]`

- No type means `string`. An unknown type, or a name Active Record already defines (`save`, `type` on a non-STI model), raises an error.
- `!` means `null: false` - `email:string!`, `email_address:string!:uniq` (Rails 8.0+).
- Options in braces: `title:string{120}` (`limit`), `body:text{medium}` (`size`), `'price:decimal{10,2}'` (`precision`, `scale` - quote it for the shell), `subject:references{polymorphic}`.
- `user:references` (alias `belongs_to`) gives `null: false` (when `belongs_to_required_by_default` is on, as in new apps), `foreign_key: true`, and an index; `:uniq` makes the index unique. Polymorphic references get no foreign key.
- Special types: `password:digest` (`password_digest` + `has_secure_password`), `auth:token` (string, unique index, `has_secure_token`), and the virtual `body:rich_text`, `avatar:attachment`, `photos:attachments` (no column; the model gets `has_rich_text` / `has_one_attached` / `has_many_attached`).

Examples:

```sh
bin/rails generate model Post title:string! body:rich_text author:references published_at:datetime:index
bin/rails generate migration AddSlugToPosts slug:string!:uniq
bin/rails generate migration RemoveLegacyIdFromPosts legacy_id:integer:index
bin/rails generate migration AddStatusToOrders 'total:decimal{10,2}' status:integer
bin/rails generate migration BackfillPostSlugs        # empty change; write the body
```

## Options

- `--database NAME` (alias `--db`): write to that database's `migrations_paths` (`db/queue_migrate`, `db/cache_migrate`, ...). Required for any database other than the primary.
- `--primary-key-type uuid`: `create_table ..., id: :uuid`, references typed to match. Apps set this once in `config.generators` (`g.orm :active_record, primary_key_type: :uuid`) - then do not pass it.
- `--no-timestamps`; for `model`: `--no-migration`, `--no-fixture`, `--no-test-framework`, `--no-indexes`, `--parent Base` (STI, no migration).
- `-p` / `--pretend` shows what it would write. A name that already exists prints "Another migration is already named X" and writes nothing - **with exit status 0**, so read the output. Choose a better name, or pass `--force` only to replace a migration you just generated and have not run. `generate model` over existing files prompts to overwrite, and with no terminal it overwrites: pass `--skip` (see `generators.md`).
- `bin/rails destroy migration Name` (or `destroy model Name`) removes what the generator made - use it to undo a wrong generate, before running it.

## After generating

1. Read the generated file. Change only the body, never the class name, the file name, or the version tag. Add the column options the generator cannot express (`default:`, `comment:`, check constraints, composite indexes).
2. `bin/rails db:migrate` - it runs the migration and rewrites `db/schema.rb` (or `structure.sql`, or `db/<name>_schema.rb` for another database).
3. Prove it reverses: `bin/rails db:migrate:redo` (rolls back and runs it again). In a multi-database app use the namespaced tasks: `db:migrate:redo:primary`, `db:rollback:queue`.
4. Read the schema diff (`git diff db/schema.rb`): only your change should be there. Other changes mean the local database had drifted - find out why before committing.
5. Commit the migration and the schema dump together.

`bin/rails db:migrate:status` shows each version up or down (`NO FILE` for a version with no file). `db:migrate:up VERSION=` / `db:migrate:down VERSION=` run one migration. `db:rollback STEP=n` undoes the last n. The test database follows the schema file on the next test run (`maintain_test_schema`); run `bin/rails db:test:prepare` only if it does not.

## Changing a migration

- **Generated, not yet run:** edit it freely.
- **Run locally, not committed:** `bin/rails db:migrate:down VERSION=<v>` (or `db:rollback`), edit, migrate again.
- **Committed and shared, or deployed:** never edit it. Every database that ran it will not run it again. Generate a new migration that makes the correction.

## The schema dump

`db/schema.rb` says it at the top: it is generated from the database; change the database with migrations, then regenerate. Never edit it, `structure.sql`, or `db/<name>_schema.rb` by hand.

- To regenerate without migrating: `bin/rails db:schema:dump` (namespaced per database: `db:schema:dump:queue`).
- **Merge conflict in schema.rb:** do not merge the `version:` line or column lines by hand. Take the base branch's copy (`git checkout <base> -- db/schema.rb`), make sure the local database has run both branches' migrations, then `bin/rails db:migrate` and commit the regenerated file. The other branch's migrations run even when their timestamps are older than yours - `db:migrate` runs every pending version.
- **Rails 8.1.0 to 8.1.3** sort `schema.rb` columns alphabetically; 8.1.4 reverted it. A re-dump on those versions reorders columns - commit it as it comes, do not reorder by hand.
- `schema_format :sql` (`structure.sql`) is for what `schema.rb` cannot hold: triggers, functions, some PostgreSQL types. Since 8.1 it can be set per database in `database.yml`.
- Production does not dump (`dump_schema_after_migration = false`). The dump you commit comes from development.

## Writing the body

`change` is reversible when every call in it is. These reverse as written: `create_table`, `create_join_table`, `add_column`, `add_reference`, `add_index`, `add_foreign_key`, `add_check_constraint`, `add_timestamps`, `rename_column`, `rename_table`, `rename_index`, `change_column_null`, `enable_extension`, `create_enum`, and their `remove_*` / `drop_*` partners when given enough to rebuild:

| Call | Reversible only with |
|---|---|
| `remove_column :t, :c` | the type: `remove_column :t, :c, :string` |
| `remove_columns` | `type:` |
| `remove_index :t, :c` | `column:` (or the column as the second argument) |
| `remove_foreign_key :a` | the other table: `remove_foreign_key :a, :b` |
| `change_column_default :t, :c, x` | `from:` and `to:` |
| `drop_table :t` | a block with the columns |
| `drop_enum` | its values |

Not reversible: `change_column`, `execute`, `add_enum_value`. Wrap them in `reversible do |dir| dir.up { ... }; dir.down { ... } end`, or write `up` and `down`. `raise ActiveRecord::IrreversibleMigration` in `down` when there is truly no way back. `revert SomeMigration` undoes an earlier migration.

`create_table` adds a `bigint` `id` (or `id: :uuid`, `id: false`, `primary_key: [...]`). `t.timestamps` adds `created_at` and `updated_at`, `null: false`. PostgreSQL enums: `create_enum :status, %w[draft published]` then `t.enum :status, enum_type: :status`.

Each migration runs in a transaction where the database supports transactional DDL (PostgreSQL, SQLite). `disable_ddl_transaction!` turns that off - required for `algorithm: :concurrently` and `ALTER TYPE ... ADD VALUE`.

## Data changes

The Rails guide advises against data changes in migration files. In order of preference:

1. **A one-off script**: `bin/rails generate script data/backfill_post_slugs` (Rails 8.0+, writes `script/data/backfill_post_slugs.rb`), run with `bin/rails runner script/data/backfill_post_slugs.rb`, or the `maintenance_tasks` gem when the app has it.
2. **In a migration, when the schema change cannot work without it** (a new NOT NULL column that needs values first): use `update_all` or SQL, or a model class defined inside the migration (`class Post < ActiveRecord::Base; self.table_name = "posts"; end`), never the app's model - the app's model changes later and the old migration breaks. Call `reset_column_information` before using a table the migration has just changed. Batch large tables (`in_batches(of: 10_000)`).

## Production safety

For apps that deploy to a live database with traffic. SQLite apps that deploy with a short stop can skip most of this; PostgreSQL and MySQL apps cannot. If the app has `strong_migrations`, follow its messages - they name the safe pattern.

- **Remove a column:** add `self.ignored_columns += ["col"]` to the model and deploy; then the migration that removes it; then remove the `ignored_columns` line.
- **Rename a column or table, or change a column's type:** add the new one, write to both, backfill, move reads, stop writing the old one, then drop it - several deploys. Do not `rename_column` a column the running code reads.
- **Add an index (PostgreSQL):** `disable_ddl_transaction!` and `add_index ..., algorithm: :concurrently` (for a reference: `add_reference ..., index: { algorithm: :concurrently }`).
- **Add a foreign key or check constraint:** `validate: false`, then `validate_foreign_key` / `validate_check_constraint` in a second migration.
- **NOT NULL on an existing column:** a check constraint `"col IS NOT NULL"` with `validate: false`, validate it, then `change_column_null`, then remove the check.
- **Defaults:** a constant default is safe on current PostgreSQL and MySQL; a volatile one (`gen_random_uuid()`, `now()`) rewrites the table - add the column, then `change_column_default`, then backfill.
- **Backfills:** their own migration (or script) with `disable_ddl_transaction!`, in batches, never in the same migration as the schema change.
- **Lock timeouts:** set `lock_timeout` (e.g. 10 s) so a migration waiting on a lock fails fast instead of blocking every query behind it.
