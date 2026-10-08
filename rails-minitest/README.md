# rails-minitest

One standard for Minitest suites in Rails apps, and an agent that works to it. Tests written to it prove behaviour, run fast, read clearly, and never flake.

Minitest only. RSpec apps are out of scope: the skill and the agent stop and say so.

## What it ships

- **The `rails-minitest` skill** - the rules for every test, plus references loaded on demand:
  - `test-kinds.md` - what each kind of test proves (models, concerns, integration, system, jobs, mailers, helpers, ViewComponent and Phlex components, channels, rake tasks) and which assertion to use.
  - `fixtures.md` - designing the fixture world: personas per role, a fixture per domain state, a foreign tenant for isolation tests, the fixture validity test, and speed rules for apps on factory_bot.
  - `shortcuts.md` - reaching a known state without running the app's flows: signing in (Rails 8.1 authentication, Devise, passwordless, system tests), roles, `Current` attributes, records in a given state, builders, time, jobs, external services, stubbing, and test-prof's `before_all`.
  - `organisation.md` - layout, `test_helper.rb`, helper modules in `test/test_helpers/`, domain assertions, block toggles, shared behaviour modules, base classes.
  - `speed.md`, `coverage.md` (SimpleCov 1.x with parallel workers, branch and view coverage, change coverage), `flaky.md` (reproduce, then a table of causes and fixes).
- **A suite mode** - set up, audit, speed up, or reorganise a whole suite: survey, plan, your approval, apply, verify (two seeds, time and coverage before and after).
- **`scripts/audit_tests`** - a read-only survey the suite mode runs from the skill's directory (plain Ruby, standard library, Ruby 2.6+). It reports the stack, tests per kind, app files with no test file, suite-level gaps (no parallel runs, no network guard, coverage set up wrong, no fixture validity test), smells with file and line (`sleep`, unconditional `skip`, `ActionController::TestCase`, Minitest 6 breakages, login through the form), and the files that create the most records. Nothing is copied into the app.
- **The `minitest-runner` agent** (`rails-minitest:minitest-runner`) - runs suites and returns a summary instead of a wall of output, writes tests for a finished change, and diagnoses failing, flaky, or slow tests. The skill is preloaded into it.
- **A `SessionStart` hook** - in Rails apps tested with Minitest only, it tells the main session to load the skill before test work and to delegate test runs to the agent.

## Where the standard comes from

The Rails testing guide and the Rails source, the test suite of 37signals' open-source Fizzy (fixtures only, helper modules in `test/test_helpers/`, 271 test files), the Rails 8.1 authentication generator's test helper, and the current documentation of SimpleCov, test-prof, and Minitest 6.

## Install

```
/plugin marketplace add mooktakim/skills
/plugin install rails-minitest@mooktakim
```

This plugin replaces the `rails-tester` agent that `rails-specialists` shipped before version 0.4.0; the agent is now `rails-minitest:minitest-runner`.

## How to use it

Work as usual: when you ask for tests or a change that needs them, the skill loads, and test runs go to the agent. For the whole suite, ask in plain words - "audit our test suite", "make the tests faster", "set up coverage" - or invoke the skill directly with `/rails-minitest:rails-minitest`.
