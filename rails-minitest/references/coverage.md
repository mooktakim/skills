# Coverage

Read this before setting up or reading coverage. Coverage shows which code no test runs. It does not show that the code that runs is checked: a test with no assertion still "covers" every line it touches. Use it to find gaps, never as a score to reach with weak tests.

## Setup with SimpleCov

`SimpleCov.start` must run before any application code loads, so it goes at the very top of `test/test_helper.rb`:

```ruby
# test/test_helper.rb
if ENV["COVERAGE"] || ENV["CI"]
  require "simplecov"
  SimpleCov.start "rails" do
    enable_coverage :branch
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
```

Add `gem "simplecov", require: false` to the `test` group. Gating on `COVERAGE` keeps local single-file runs fast; CI always measures.

**Branch coverage** is the number to watch. Line coverage counts `x = a ? b : c` as covered when only one side ever ran.

### Parallel runs

- **SimpleCov 1.0.1 and later:** the `rails` profile merges the coverage of every `parallelize` worker on its own. Add nothing. If an older setup has `parallelize_setup`/`parallelize_teardown` hooks that set `SimpleCov.command_name` or call `SimpleCov.result`, remove them: they were the workaround for 0.22, and on Rails 8.1.4 they interfere with the report (fixed in SimpleCov 1.3.2).
- **SimpleCov 0.22:** each worker needs its own name and result:

  ```ruby
  class ActiveSupport::TestCase
    parallelize_setup { |worker| SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}" }
    parallelize_teardown { |_worker| SimpleCov.result }
  end
  ```

Check the setup once: run the suite with `PARALLEL_WORKERS=1` and with parallel workers, and compare the totals. They must match.

SimpleCov 1.x requires a recent Ruby (1.3 needs Ruby 3.3 or later). On an older Ruby, stay on the newest version that installs, and use the hooks above if it is 0.22.

### Useful SimpleCov 1.2+ features

- **Views:** `cover_views` in the start block measures ERB, Haml, and Slim templates too. Expect the total to drop the first time.
- **Coverage of a change:** `simplecov patch --base main --minimum 100` scores only the lines a branch touches. This is the most useful CI gate on an existing app: every new line is tested, without first raising the old total.
- **Thresholds:** in the start block, `coverage(:line) { minimum 90 }` and `coverage :branch, minimum: 80`. Set them at today's level, so coverage can only rise. `simplecov ratchet` writes a per-file baseline for a legacy app.
- **Which test covers a line:** `track_tests` records it; `simplecov tests app/models/card.rb:42` lists the tests. It costs run time, so turn it on only when you need it.

## Reading the report

- Start with uncovered branches in code where a bug costs most: money, authorisation, data deletion, external calls, background jobs.
- An uncovered line is a question, not an order. Config, generated code, and defensive branches for "cannot happen" cases may stay uncovered; skip them with a reason (`# simplecov:disable` ... `# simplecov:enable`) rather than writing a test that asserts nothing.
- Code covered only by a system test is weakly covered: system tests assert little about each step. Add the model or integration test.
- Each gap you close gets a real test with a real assertion of the behaviour, at the right level (`SKILL.md`, rule 4).
