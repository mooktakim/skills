# Flaky tests

Read this when a test fails only sometimes, only in CI, or only in parallel. A flaky test is a real bug - in the test or in the app - and it gets fixed, never retried away.

## Reproduce first

1. Take the seed from the failing run (`Run options: --seed 12345`) and repeat it: `bin/rails test --seed 12345`.
2. Run the failing test alone: `bin/rails test test/models/card_test.rb:42`. Passes alone but fails with the seed: the cause is order or shared state. Fails alone too: the cause is inside the test (time, randomness, ordering of results).
3. Remove parallelism: `PARALLEL_WORKERS=1 bin/rails test --seed 12345`. Fails only with workers: the cause is a resource shared between workers.
4. Run it many times: `for i in $(seq 1 30); do bin/rails test test/models/card_test.rb:42 || break; done`.
5. To find which earlier test leaks state, bisect the files that ran before it in the failing order: run half of them with the failing test and the same seed, and halve again until one file remains (the `minitest-bisect` gem automates this on Minitest 5; Minitest 6's own `minitest` runner has `--bisect`).

## Causes and fixes

| Symptom | Cause | Fix |
|---|---|---|
| Fails near midnight, month end, or a DST change; or only in CI's time zone | the test reads the real clock | `travel_to` a fixed time; build expected values from the same clock; set the zone with `Time.use_zone` |
| A time comparison is off by microseconds | the database stores less precision than Ruby | `freeze_time`, or compare with `assert_in_delta`, or round both sides |
| A list comes back in a different order | the query has no `order`, or `.first`/`.last` on UUID keys | add an explicit `order` to the code, or sort both sides when order is not the behaviour |
| Fails only after some other test | global state left changed: config, `ENV`, class attributes, a memoised constant, a stub without a block | restore through a block helper with `ensure`; use stubs only in block form |
| Fails only in parallel | workers share a file path, cache, Redis database, search index, or port | one resource per worker in `parallelize_setup` (`references/speed.md`) |
| Fails when a new fixture is added | the test counts or lists the whole table | `assert_difference` and scoped queries (`references/fixtures.md`) |
| Random data sometimes hits an edge | `Faker` or `rand` in the test | fixed values; a test for each edge on purpose |
| System test sometimes misses an element | an assertion ran before the page settled | Capybara waiting matchers (`assert_selector`, `assert_no_selector`, `assert_current_path`), never `sleep` or `page.has_x?` inside `assert`/`refute` |
| System test expects mail or a broadcast that never comes | the work runs in a job, and jobs stay enqueued in tests | wrap the action in `perform_enqueued_jobs { ... }` |
| System test fails after a Turbo navigation | the old page was still on screen | assert on something only the new page has before the next action |
| Fails only in CI | missing service, different locale or time zone, eager loading on, slower machine | reproduce with `CI=1`; make the test set what it depends on |

## Rules

- Never add `sleep`, raise a timeout, or wrap a test in a retry to make it pass. A retry gem is acceptable only as a short quarantine while the real fix is tracked, and only with the user's agreement.
- Never use `i_suck_and_my_tests_are_order_dependent!` or a fixed seed to hide order dependence.
- When the flake is in the app (a race, a missing `order`, a time zone bug), report it as an app bug with the evidence; the test that exposed it stays.
