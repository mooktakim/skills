---
name: rails-minitest
description: Write, organise, speed up, and audit Minitest test suites in Rails apps. Covers every kind of test (models, concerns, integration, system, jobs, mailers, components), fixture design, shared test helpers, shortcuts that put users, roles, and records into a known state without running the app's flows, parallel runs, coverage, and flaky tests. Use when writing or changing tests in a Rails app that uses Minitest, when tests are slow, flaky, or full of duplicated setup, when designing fixtures or test helpers, when setting up coverage or parallel testing, or when asked to audit, speed up, or reorganise a Rails test suite. Not for RSpec suites.
---

# Rails Minitest

You write and maintain Minitest suites in Rails apps to one standard: tests that prove behaviour, run fast, read clearly, and never flake. This file holds the rules for every test. The `references/` files beside it hold the detail - they ship with this skill, so resolve their paths from this skill's directory (`${CLAUDE_SKILL_DIR}`), not the app. Read the matching one before you write that kind of code:

| Read | Before |
|---|---|
| `references/test-kinds.md` | writing a kind of test you have not written in this session: what each kind proves, and the assertion to use |
| `references/fixtures.md` | adding or changing fixtures, or creating records in a test |
| `references/shortcuts.md` | arranging state: signing in, roles, `Current`, records in a given state, time, jobs, external services |
| `references/organisation.md` | adding a helper, a shared test module, a base class, or a test file in a new place |
| `references/speed.md` | working on slow tests, or setting up parallel runs |
| `references/coverage.md` | setting up or reading coverage |
| `references/flaky.md` | a test that fails only sometimes, only in CI, or only in parallel |

## Two modes

- **Writing mode** - tests that belong to a change, or tests the user asks for. Follow the rules below. Test files that belong to the change need no approval step.
- **Suite mode** - the user asks to set up, audit, speed up, or reorganise the suite. Follow "Suite mode" at the end: survey, plan, approval, apply, verify.

## Detect first

1. Confirm the app uses Minitest: `test/test_helper.rb` exists and the Gemfile has no `rspec-rails`. On an RSpec app, stop and say this skill covers Minitest only.
2. Read `Gemfile.lock`: the Rails and Minitest versions, and whether the app has `factory_bot_rails`, `mocha` or `minitest-mock`, `webmock`, `vcr`, `simplecov`, `test-prof`, and `capybara` with its driver.
3. Read `test/test_helper.rb`, everything in `test/test_helpers/` (or `test/support/`), `test/application_system_test_case.rb`, and `test/CLAUDE.md` if it exists.
4. Read two or three existing tests of the kind you are about to write.

The app's settled conventions win on style: naming, assertion style, helper names, fixtures or factories. The rules marked **hard** below win over the app. In writing mode, follow them in new code and report the old violations you saw; fix old ones only in suite mode.

## Rules for every test

**Behaviour**

1. Test behaviour through the public interface. Assert outcomes - state, response, enqueued job, sent email - not which methods ran. A refactor that keeps the behaviour must not break a test.
2. One behaviour per test, named as a sentence about that behaviour: `test "closing a card records who closed it"`.
3. Cover every branch: the main path, each edge case, and each failure path - invalid input, signed out, wrong role, another tenant's record, missing record. For authorisation, test at least one role that is allowed and one that is denied.
4. Test at the lowest level that proves the behaviour. A controller test proves the wiring; it does not repeat the model's branch tests.

| Behaviour | Kind and place | Base class |
|---|---|---|
| Domain rule, calculation, scope, state change | model or PORO, `test/models/` | `ActiveSupport::TestCase` |
| A concern | its own file, mirroring the app: `test/models/card/closeable_test.rb` | `ActiveSupport::TestCase` |
| HTTP: status, redirect, authorisation, params, Turbo Stream, JSON | integration, `test/controllers/` | `ActionDispatch::IntegrationTest` |
| A flow that needs JavaScript, or a critical journey end to end | system, `test/system/` | `ApplicationSystemTestCase` |
| Job, mailer, component, helper, channel, rake task | its own kind | see `references/test-kinds.md` |

Never use `ActionController::TestCase`. Keep system tests few: one costs as much as tens of integration tests, and Rails 8.1 no longer generates them with scaffolds.

**Data and state**

5. Arrange from fixtures. A test creates a record only when creating it is the behaviour under test, or when no fixture can express the state - then once, in that test, with the fewest attributes. Apps on factory_bot follow the factory rules in `references/fixtures.md`.
6. Reach a state directly, one layer below the one under test: sign in with a helper, not the login form; put a record in a state with a variant fixture or a domain method, not by driving controllers. Drive the real flow only in the test of that flow.
7. Do not assert global counts or unordered results that a new fixture can change. Use `assert_difference` and scoped queries, and order or sort before you compare collections.

**Isolation (hard)**

8. No network. WebMock blocks real HTTP; each external service is stubbed at its boundary by a named helper.
9. No `sleep`. Use `travel_to` or `freeze_time` for time, and Capybara's waiting matchers in system tests.
10. Each test passes alone, in any order, in any worker. A test that changes global state - config, `ENV`, class attributes, feature flags - restores it through a block helper with `ensure`. Rails already resets `Current` attributes and time travel after each test.
11. Never weaken a test to make it pass: no deleted assertion, no looser match, no `skip`. If a test must change because the behaviour changed, say why.

**Readability**

12. The test body shows arrange, act, and assert. Helpers remove noise - sign-in, stubs, record builders - and never hide the subject or the assertion.
13. Use the precise assertion: `assert_difference`, `assert_changes` with `from:`/`to:`, `assert_enqueued_with`, `assert_emails`, `assert_turbo_stream`, `assert_dom`, `assert_nil` (never `assert_equal nil`). Give a bare `assert` a message when its failure would not explain itself.
14. Prove each new test of non-trivial behaviour can fail: break the expectation or the code once, see the test fail for the right reason, then restore it.

## Running tests

- Narrowest first: `bin/rails test test/models/card_test.rb:42`, then the file, the directory, `bin/rails test` (everything except system tests), and `bin/rails test:all` when system tests are affected.
- Flags: `-n "/closing/"` selects by name, `--fail-fast` stops at the first failure, `--seed N` repeats an order, `--profile 20` lists the slowest tests, and `PARALLEL_WORKERS=1` runs one process for debugging.
- When subagents are available and a run covers more than one file, delegate it to `rails-minitest:rails-tester`, so suite output stays out of the conversation.

## Suite mode

The approval gate is a hard stop. Change nothing until the user approves the Phase 1 plan in a reply to that plan ("approve", "yes", "go", or edits to it). A reply about something else is not approval.

### Phase 1: survey and plan

1. From the app root, run `ruby "${CLAUDE_SKILL_DIR}/scripts/audit_tests"`. It reports the stack, tests per kind, app files with no test file, suite-level gaps (no parallel runs, no network guard, coverage set up wrong), smells with file and line, and the files that create the most records. Its header comment explains each check. Its findings are leads: confirm each one in the code before it goes into the plan.
2. Run the full suite once with `--profile 20` (`bin/rails test:all` when there are system tests), delegated to `rails-minitest:rails-tester`, for the baseline: wall time, test count, slowest tests, failures. If SimpleCov is set up, record line and branch coverage.
3. Read the slowest files and the files that create the most records, to find why they are slow (`references/speed.md`).
4. Present the plan, grouped, each item with its files and a one-line reason:
   - **Infrastructure:** `test_helper.rb` (parallel runs, network guard, coverage), and gems to add.
   - **Helpers:** duplicated setup to extract into `test/test_helpers/` - sign-in, stubs, builders, domain assertions.
   - **Fixtures:** missing personas or state variants, the fixture validity test, wrong counter caches.
   - **Speed:** each slow file with its cause and fix.
   - **Gaps:** untested files ranked by risk (money, authorisation, data loss first) and the kind of test each needs.
   - **Smells and flaky tests,** each with its fix.

   Say what you will not change and why, and the effect you expect where it can be measured (time, coverage). Then wait for approval.

### Phase 2: apply

Work in this order: infrastructure, helpers, fixtures, then test changes. Add gems with `bundle add <gem> --group test` and confirm `Gemfile.lock` changed. Run the affected tests after each group. Never change application code: when a test exposes an app bug, stop that item and report the bug with file, line, and cause.

### Phase 3: verify and report

1. Run the full suite twice, with two different seeds. Both runs must pass.
2. Compare with the baseline - wall time, test count, slowest tests, coverage - and run the audit again.
3. If the app has `test/CLAUDE.md`, update it with the conventions this run set up: the helpers and what each is for, the personas, the stubbing policy.
4. Report what changed, the numbers before and after, and what is left. Commit only when the user or the project's rules say so.
