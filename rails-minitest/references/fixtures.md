# Fixtures and test data

Read this before adding or changing fixtures, or before creating records in a test.

## Why fixtures are the default

Rails loads every fixture once per run (once per parallel worker), then wraps each test in a transaction and rolls it back. A test that only reads fixture data inserts nothing. Factories insert rows in every test that calls them, and in a slow suite those inserts are most of the time. Fixtures also give the whole team one shared, named world to talk about: `users(:admin)` means the same record in every test.

## Design the world

Build one small, coherent world, like a demo account, not a pile of unrelated rows:

- **One home tenant** (`accounts(:acme)`) that almost everything belongs to, and **one foreign tenant** (`accounts(:globex)`) with a few records, so isolation tests ("another account's card returns 404") need no setup.
- **One persona per role**, named for the role or as a recurring character whose role everyone knows: `users(:owner)`, `users(:admin)`, `users(:member)`, `users(:guest)`, plus edge personas the domain has (`users(:unverified)`, `users(:suspended)`).
- **One fixture per state the domain cares about:** `cards(:open)`, `cards(:closed)`, `invoices(:paid)`, `invoices(:overdue)`, `subscriptions(:trialing)`. A test that needs a closed card uses `cards(:closed)` instead of closing one.
- **Few rows per table.** Two records exercise "many" as well as two hundred do. Each new row loads for every test and can change every assertion about counts and lists.
- **Only the columns that matter,** plus required ones. A fixture that sets every column hides which values a test depends on.

When you add a fixture row, run the whole suite, not only your test: other tests may count or list that table.

## Syntax that keeps fixtures small and correct

```yaml
# test/fixtures/users.yml
DEFAULTS: &DEFAULTS                       # any row labelled DEFAULTS is not loaded
  account: acme                           # association by label, never by id
  verified_at: <%= 1.week.ago.to_fs(:db) %>
  password_digest: <%= password_digest("secret") %>

owner:
  <<: *DEFAULTS
  name: Olivia
  role: owner

unverified:
  <<: *DEFAULTS
  name: Una
  role: member
  verified_at: null
```

- **Associations by label.** `account: acme` lets Rails compute the id (`ActiveRecord::FixtureSet.identify`). UUID primary keys need nothing extra: Rails derives a stable UUID from the label. Use `ActiveRecord::FixtureSet.identify(:owner, :uuid)` only where ERB needs the id as a value. Never write a literal id.
- **Polymorphic:** `eventable: logo (Card)`. **Join tables:** a fixture file for the join model, or `tags: web, mobile` on a `has_and_belongs_to_many`.
- **Relative dates in ERB** (`<%= 3.days.from_now.to_fs(:db) %>`), so fixtures never go stale. Leave `created_at`/`updated_at` out unless a test depends on them; Rails fills them with the load time.
- **Ignore template rows** with `DEFAULTS`, or list them under `_fixture: { ignore: [base] }`. Set `_fixture: { model_class: Admin::Report }` when the file name does not map to the class.
- **Helper methods** for fixture ERB go in a module included into `ActiveRecord::FixtureSet.context_class`, in `test_helper.rb` before fixtures load:

  ```ruby
  module FixtureHelpers
    def password_digest(password)
      BCrypt::Password.create(password, cost: BCrypt::Engine::MIN_COST)
    end
  end
  ActiveRecord::FixtureSet.context_class.include FixtureHelpers
  ```

- **Files:** Active Storage fixtures live in `test/fixtures/active_storage/attachments.yml` (`record: david (User)`, `name: avatar`, `blob: david_avatar_blob`) and `blobs.yml` (`david_avatar_blob: <%= ActiveStorage::FixtureSet.blob filename: "david.png", service_name: "test_fixtures" %>`), with the file in `test/fixtures/files/` and a `test_fixtures` Disk service in `config/storage.yml`. Action Text bodies live in `test/fixtures/action_text/rich_texts.yml` (`record: logo (Card)`, `name: description`, `body: <p>...</p>`).
- **Bulk rows** for pagination: an ERB loop in the fixture file only when many tests need them; otherwise `insert_all` inside the one test that does.

## Fixtures skip validations and callbacks

Fixtures are inserted straight into the database. Nothing runs: no validation, no callback, no counter cache, no derived column.

- Set counter caches and denormalised columns by hand (`comments_count: 2`) and keep them true to the rows.
- Rows that a callback would create (an audit event, a membership) must exist as their own fixtures.
- A fixture can be invalid without anyone noticing. Guard against it with one test:

```ruby
# test/models/fixtures_test.rb
require "test_helper"

class FixturesTest < ActiveSupport::TestCase
  test "every fixture is valid" do
    Rails.application.eager_load!
    ApplicationRecord.descendants.reject(&:abstract_class?).each do |model|
      model.find_each do |record|
        assert record.valid?, "#{model.name} #{record.id}: #{record.errors.full_messages.to_sentence}"
      end
    end
  end
end
```

Exclude a model only with a comment saying why its rows are allowed to be invalid.

Fixtures also skip foreign key checks while they load, so a misspelt label leaves a row pointing at nothing. On Rails 7.1+, add a second test to the same class:

```ruby
test "every fixture reference points at a row" do
  ActiveRecord::Base.connection.check_all_foreign_keys_valid!
end
```

It needs real foreign keys in the schema; for associations without one, the validity test above catches a missing `belongs_to` target.

Apps with several databases (Rails 8's Solid Queue, Cache, and Cable, or a separate primary) load each fixture file into the database its model's connection uses. Keep fixtures only for the app's own tables; Solid Queue, Cache, and Cable tables need none.

## Tests that survive new fixtures

- Assert change, not totals: `assert_difference -> { account.cards.count }, +1`, not `assert_equal 4, Card.count`.
- Scope queries to a fixture parent (`boards(:main).cards.open`) instead of the whole table.
- Compare collections with a defined order: `assert_equal [cards(:b), cards(:a)], board.cards.by_recency`, or sort both sides when order is not the behaviour.
- Never rely on `.first` or `.last` without an `order`. With UUID keys their order is random.

## When a test should create a record

- Creating it is the behaviour under test (`Card.create!` assigns a number).
- The state is a one-off combination that no other test needs. Make it from the nearest fixture: `cards(:open).update!(due_on: Date.yesterday)`, or with a small builder helper (`references/shortcuts.md`).
- Use `create!` (it raises), never `create` (it returns an invalid record silently). Pass only the attributes the test is about; the builder or fixture fills the rest.

If three or more tests create the same shape, it is a missing fixture or a missing builder.

## Apps on factory_bot

Follow the app: do not add fixtures to a factory app, or factories to a fixture app, unless the user asks. Inside a factory app, the speed rules are:

- `build` or `build_stubbed` whenever the test does not need the row in the database (validations, pure methods, presenters).
- Each factory defines the minimum valid record; variants are traits (`create(:invoice, :overdue)`). A factory that builds a large graph by default makes every test pay for it.
- Watch for association cascades: one `create(:comment)` that builds a card, a board, an account, and three users. Find them with test-prof (`FPROF=1 bin/rails test` lists factories by count; `FPROF=flamegraph` shows cascades; `FDOC=1` finds tests that create records they never needed to save). Fix them with `association :board, strategy: :build`, explicit parents passed in, or test-prof's `create_default`.
- Never `create_list` more rows than the behaviour needs.

In suite mode, when the profile shows the same base records (account, users per role) created in most tests, propose a hybrid: fixtures for that shared base world, factories kept for variants. This keeps factory flexibility and removes the repeated inserts. It is a proposal for the user, never a silent switch.
