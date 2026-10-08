# Organising the suite

Read this before adding a helper, a shared test module, a base class, or a test file in a new place.

## Layout mirrors the app

```
test/
  test_helper.rb                     # the one place global setup lives
  application_system_test_case.rb
  test_helpers/                      # one module per concern (below)
  fixtures/                          # one YAML file per table; files/ for uploads
  models/card_test.rb                # app/models/card.rb
  models/card/closeable_test.rb      # app/models/card/closeable.rb (a concern)
  controllers/cards_controller_test.rb   # integration tests, one file per controller
  integration/checkout_flow_test.rb  # only flows that cross several controllers
  system/                            # few, JavaScript flows only
  jobs/  mailers/  mailers/previews/  helpers/  components/  channels/  lib/
```

A test file's path and class name follow the code under test (`Card::CloseableTest` for `Card::Closeable`), so anyone can find the test from the code and back.

## test_helper.rb

Global setup lives here and nowhere else:

```ruby
ENV["RAILS_ENV"] ||= "test"
# SimpleCov.start goes above this line, when the app measures coverage (references/coverage.md)
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
WebMock.disable_net_connect!(allow_localhost: true)   # localhost for the system test server and browser driver

Dir[File.expand_path("test_helpers/**/*.rb", __dir__)].sort.each { |file| require file }

module ActiveSupport
  class TestCase
    parallelize workers: :number_of_processors
    fixtures :all

    include ActiveJob::TestHelper
    include RecordBuilders, CachingTestHelper   # the app's own modules from test/test_helpers/

    setup { Current.account = accounts(:acme) }   # multi-tenant apps only
  end
end
```

Keep it short: anything longer than a line or two becomes a module in `test/test_helpers/`.

## Helper modules

One file per concern in `test/test_helpers/`, named `<topic>_test_helper.rb` (the convention of the Rails 8 authentication generator and of 37signals' Fizzy). Include each where it belongs:

- Every test: `include` in `ActiveSupport::TestCase` (record builders, `with_current_user`, block toggles).
- HTTP tests only: `ActiveSupport.on_load(:action_dispatch_integration_test) { include SessionTestHelper }` at the bottom of the helper file.
- Browser tests only: private methods in `ApplicationSystemTestCase`. A system `sign_in_as` differs from the integration one, so keep them apart.

Four kinds of helper earn their place:

1. **State shortcuts** - `sign_in_as`, `with_current_user`, `create_card` (see `references/shortcuts.md`).
2. **Domain assertions** - wrap a selector or a multi-step check in a name, so a markup change breaks one helper instead of forty tests:

   ```ruby
   module CardTestHelper
     def assert_card_container_rerendered(card)
       assert_turbo_stream action: :replace, target: dom_id(card, :card_container)
     end
   end
   ```

3. **Block toggles** - change a global setting and restore it, always with `ensure`:

   ```ruby
   module CachingTestHelper
     def with_partial_caching
       previous = ApplicationController.perform_caching
       ApplicationController.perform_caching = true
       yield
     ensure
       ApplicationController.perform_caching = previous
     end
   end
   ```

4. **Boundary stubs** - one named helper per external service (`stub_stripe_charge`), so the service's shape lives in one place.

A helper that is used by one test file stays a private method in that file, at the bottom under `private`.

## Shared behaviour across classes

When several models include the same concern and the concern's behaviour does not depend on the model, test the concern once, in its own file, against one representative model. Then each model's test covers only its own configuration of the concern.

When each includer must keep the same contract with its own data, write the tests once in a module and include it:

```ruby
# test/test_helpers/archivable_tests.rb
module ArchivableTests
  extend ActiveSupport::Concern

  included do
    test "archiving hides the record from active" do
      archivable.archive
      assert_not_includes archivable.class.active, archivable
    end
  end

  private
    def archivable
      raise NotImplementedError, "#{self.class} must define archivable"
    end
end

class ProjectTest < ActiveSupport::TestCase
  include ArchivableTests

  private
    def archivable
      projects(:alpha)
    end
end
```

The abstract method makes a missing piece fail with a clear message instead of a `NoMethodError` deep in a test.

## Base classes

One level of base class per area is the most a suite needs, for a shared role or setup:

```ruby
class AdminIntegrationTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }
end
```

Put it in `test/test_helpers/`. A deeper hierarchy hides where a test's state comes from.

## Readability rules

- Prefer clear and repeated over clever and shared (DAMP over DRY) inside the test body. A reader must understand a failing test without opening three helpers.
- `setup` holds what every test in the class needs, nothing more. A value only one test uses belongs in that test.
- No conditionals in a test. A loop is fine only to generate named tests from a table (`{ owner: :success, ... }.each { |persona, status| test "..." }`), with a unique name per test.
- One assertion style per suite: Minitest assertions (`assert_*`), not the `_(x).must_equal` spec style mixed in.
- Name tests for the behaviour, not the method: `test "overdue invoices are listed first"`, not `test "test_sort"`.
