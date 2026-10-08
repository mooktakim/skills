# Shortcuts to a known state

Read this before arranging state for a test: signing in, roles, `Current`, records in a given state, time, jobs, or external services.

The principle: build the state directly, one layer below the layer under test. Only the test that covers a flow runs that flow. Every other test starts from the state the flow would leave behind.

Put each shortcut in a module under `test/test_helpers/` (see `references/organisation.md`), so every test uses the same one.

## Sign in

**Rails authentication generator** (`bin/rails generate authentication`). Rails 8.1's generator ships this helper; keep it. On an app generated with Rails 8.0, add it yourself (this is the 8.1 template) and require it from `test_helper.rb`:

```ruby
# test/test_helpers/session_test_helper.rb
module SessionTestHelper
  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
```

It creates the session row and writes the signed cookie the app reads. No request goes through the login form. Apps with their own cookie-based sessions use the same shape with their own cookie name and session model.

**Devise.** `include Devise::Test::IntegrationHelpers` in `ActionDispatch::IntegrationTest` and in `ApplicationSystemTestCase`, then `sign_in users(:admin)`. It uses Warden's test mode, so no form is submitted, in integration or system tests.

**Passwordless or third-party login** (magic links, OAuth, SSO). If the app has no direct session record to create, sign in through the shortest real path - one or two requests, as 37signals' Fizzy does with its magic-link code - inside a helper, and assert the session cookie is set so a broken helper fails loudly. For OAuth, use OmniAuth's test mode (`OmniAuth.config.test_mode = true` and `mock_auth`).

**System tests** cannot write a signed cookie before the first page loads. In order of preference:

1. Devise or Warden: `sign_in` / `login_as` works in system tests too.
2. A one-time sign-in link the app already has (magic link, session transfer): `visit` it from a `sign_in_as` helper in `ApplicationSystemTestCase`.
3. Fill in the login form inside `sign_in_as`. This is fine while system tests are few.
4. A test-only sign-in route, only when the profile shows login dominating system test time. Draw it inside `if Rails.env.test?` in `config/routes.rb`, so it can never exist in production, and say so in a comment.

**Roles.** Sign in a persona fixture: `sign_in_as users(:admin)`. For a class whose tests all run as one role, a class-level shortcut keeps the setup to one line:

```ruby
class ActiveSupport::TestCase
  def self.signed_in_as(persona)
    setup { sign_in_as users(persona) }
  end
end

class Admin::ReportsControllerTest < ActionDispatch::IntegrationTest
  signed_in_as :admin
end
```

For permission matrices, generate one test per role from a table, so each role shows up by name in the output:

```ruby
{ owner: :success, admin: :success, member: :forbidden, guest: :forbidden }.each do |persona, status|
  test "#{persona} gets #{status} on the billing page" do
    sign_in_as users(persona)
    get billing_path
    assert_response status
  end
end
```

## Current attributes

Model code that reads `Current.user` or `Current.account` needs them set. Set them in `setup` for the whole class (`Current.session = sessions(:david)`), or for one block:

```ruby
def with_current_user(user)
  previous = Current.session
  Current.session = Session.new(user: user)
  yield
ensure
  Current.session = previous
end
```

Rails resets every `Current` class after each test (through the executor wrap on current defaults, or `ActiveSupport::CurrentAttributes::TestHelper` on old ones), so a test never needs its own teardown for them. A multi-tenant app sets the home tenant once in `ActiveSupport::TestCase`'s `setup`.

## Records in a given state

From best to worst:

1. **A variant fixture** (`cards(:closed)`), when more than one test needs the state.
2. **A domain method on a fixture** (`cards(:open).close(user: users(:admin))`), when the state comes from a transition. It runs the real callbacks and side effects, so the state is one the app can really reach.
3. **`update!` on a fixture** for plain data with no transition behind it (`due_on: Date.yesterday`).
4. **A builder helper** for a new record, with defaults from fixtures, when the test needs a fresh record:

   ```ruby
   module RecordBuilders
     def create_card(board: boards(:main), creator: users(:member), **attributes)
       Card.create!(board: board, creator: creator, title: "Card", **attributes)
     end
   end
   ```

5. **`update_columns` or `insert_all`** only for data that skips callbacks on purpose (bulk rows for pagination, a legacy value the app can no longer write). They skip validations, so they can build states the app cannot reach; say why in the test.

Never drive a controller or a system flow to get a record into a state another test needs.

## Time

- `travel_to Time.zone.local(2026, 3, 31, 23, 59)` with a block, or `freeze_time`, for anything that reads the clock. Rails travels back after each test.
- Fixture dates are computed once, when fixtures load (`<%= 3.days.ago %>`). Assert with dates (`3.days.ago.to_date`), with `assert_in_delta`, or by relative order - never compare a fixture timestamp for equality with a freshly computed `3.days.ago`, and never with a literal date.
- Test the edges the domain has: end of day, end of month, daylight saving change, the user's time zone (`Time.use_zone`).

## Jobs and mail

`ActiveJob::TestHelper` (include it in `ActiveSupport::TestCase`) uses the test adapter: jobs are enqueued, not run.

- Assert the enqueue where the code enqueues: `assert_enqueued_with(job: ReindexJob, args: [card])`.
- Run jobs only in the tests that need their effect: `perform_enqueued_jobs(only: ReindexJob) { ... }`.
- Mail: `assert_emails(1) { ... }`, `assert_enqueued_email_with UserMailer, :welcome, params: { user: user }`.
- System tests: the app server runs in the test process, so jobs it enqueues stay enqueued too. Mail, broadcasts, and other work done in jobs never happens unless the test wraps the action in `perform_enqueued_jobs { ... }`.

## External services

- **WebMock** blocks all real HTTP (`require "webmock/minitest"`). Never call `WebMock.allow_net_connect!` (or its alias `enable_net_connect!`): with or without arguments it turns the guard off. Allow specific hosts with `WebMock.disable_net_connect!(allow_localhost: true, allow: [...])`.
- Wrap each service's stubs in a named helper (`stub_stripe_charge(amount: 1000)`, `stub_geocoder("London")`), so a change to the service's API is one edit.
- Prefer a fake adapter chosen by config (`config.x.payments = FakePayments` in `config/environments/test.rb`) for services the app calls in many places. Tests then assert on the fake's recorded calls.
- VCR for complex third-party APIs, with secrets filtered (`filter_sensitive_data`). Re-record on purpose, never by accident.

## Stubbing

- Stub only at boundaries you do not own: HTTP, payment gateways, the clock, randomness. Never stub the object under test, and avoid stubbing your own models.
- Minitest: `Object#stub` with a block (`SecureRandom.stub(:hex, "abc") { ... }`). On Minitest 6 this needs the `minitest-mock` gem. Mocha (`stubs`, `expects`) is fine if the app already uses it; do not mix both styles in one suite.
- Constants: `stub_const(Billing, :TRIAL_DAYS, 3) { ... }` (Active Support).
- Avoid `any_instance` stubs; they usually mean the dependency should be passed in.

## Global settings

Change config, `ENV`, feature flags, or class attributes only through a block helper that restores the old value in `ensure`:

```ruby
def with_env(changes)
  previous = changes.keys.to_h { |key| [key, ENV[key]] }
  changes.each { |key, value| ENV[key] = value }
  yield
ensure
  previous.each { |key, value| ENV[key] = value }
end
```

A test that sets global state without restoring it breaks other tests in random order.

## Expensive setup shared by one file

When a test class needs a large graph that fixtures cannot express and every test rebuilds it, create it once per class with test-prof's `before_all`. Include the module once, in `test_helper.rb`, on the line before `parallelize` - test-prof hooks into that call to roll back each class's data in parallel workers - and call `parallelize` with only `workers:` (and `with:`), because test-prof's version takes no other keywords (`threshold:`, `parallelize_databases:` raise):

```ruby
# test/test_helper.rb
require "test_prof/recipes/minitest/before_all"

class ActiveSupport::TestCase
  include TestProf::BeforeAll::Minitest
  parallelize workers: :number_of_processors
end

# test/models/report_test.rb
class ReportTest < ActiveSupport::TestCase
  before_all do
    @account = create_account_with_year_of_activity
  end

  setup { @account = Account.find(@account.id) }   # reload, so one test's changes cannot leak into the next
end
```

It runs inside an outer transaction that is rolled back after the class. Prefer a fixture when more than one file needs the same data.

## Transactions, threads, and other connections

Each test runs in a transaction that is rolled back, and `after_commit` callbacks still fire (Rails runs them when the test's own savepoint commits). Code that opens its own database connection or thread - some background libraries, `Thread.new` with database work - cannot see the test's uncommitted rows. Test that code with `self.use_transactional_tests = false` in its class, and delete what the test created in `teardown`; keep such classes rare, because they are slow and can leak rows.
