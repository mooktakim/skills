# Speed

Read this when tests are slow, or when setting up parallel runs. Measure before you change anything, and measure again after.

## Measure

- **Slowest tests:** `bin/rails test --profile 20` (add `test:all` for system tests). Record the total wall time too.
- **Where the time goes per kind:** test-prof's TagProf groups time by test directory: `TAG_PROF=type bin/rails test`.
- **Queries and factories:** test-prof's EventProf (`EVENT_PROF=sql.active_record bin/rails test`) shows the tests that spend the most time in SQL; FactoryProf (`FPROF=1`) counts records created per factory; FactoryDoctor (`FDOC=1`) finds tests that save records they never needed to save.
- **CPU profile of a sample:** `SAMPLE=100 bin/rails test` with `require "test_prof/recipes/minitest/sample"` in `test_helper.rb`, combined with `TEST_STACK_PROF=1`.

Minitest 6 no longer loads plugins on its own: test-prof's profilers need `Minitest.load :test_prof` in `test_helper.rb`, and other plugins (minitest-reporters and the like) need an explicit `require` or `Minitest.load`. test-prof is a development tool: add it to the `test` group, and keep the profiler lines out of the default run unless the user wants them there.

## The levers, biggest first

1. **Test data.** Inserts are the usual cost. Use fixtures for the shared world, create only what the test is about, and in factory apps use `build`/`build_stubbed` and break association cascades (`references/fixtures.md`). For a graph one file needs in every test, `before_all` (`references/shortcuts.md`).
2. **Parallel runs** (below).
3. **System tests.** Move every system test that does not need JavaScript to an integration test. Keep the rest few, and run them in their own CI job.
4. **Waiting.** Remove every `sleep`, every real network call, and every real timeout. A `travel_to` replaces waiting for time to pass.
5. **Jobs and mail.** Jobs only run inside `perform_enqueued_jobs`, so tests that do not need a job's effect do not pay for it. Use `perform_enqueued_jobs(only: SomeJob)` to run one job, not all of them.
6. **Expensive work in the code under test.** bcrypt is already cheap in tests (Rails sets `ActiveModel::SecurePassword.min_cost`). Image variants, PDF rendering, and similar work run only in the tests about them; elsewhere, stub the boundary.
7. **Boot.** Rails eager-loads in test only on CI (`config.eager_load = ENV["CI"].present?` in the default config), which keeps a single-file run fast locally. Keep `bootsnap` on.

## Parallel runs

```ruby
class ActiveSupport::TestCase
  parallelize workers: :number_of_processors
end
```

- Rails forks one process per worker, each with its own database (`app_test-0`, `app_test-1`, ...), created and loaded with fixtures on start.
- Runs with fewer than 50 tests stay serial (`parallelize threshold: 100`, or `config.active_support.test_parallelization_threshold`), because forking costs more than it saves there.
- `PARALLEL_WORKERS=1 bin/rails test` turns it off for one run, which is the first step when debugging an odd failure.
- Anything shared outside the database needs one copy per worker. Set it in `parallelize_setup`:

  ```ruby
  parallelize_setup do |worker|
    SearchClient.index_prefix = "test-#{worker}"                                     # an external search index
    Rails.application.config.x.export_dir = Rails.root.join("tmp/exports-#{worker}") # files the app writes
  end
  ```

  The names are the app's own; the point is one index, key prefix, Redis database, or directory per worker.

  `parallelize_before_fork` (Rails 8.1+) runs once in the parent before forking, for work every worker shares.
- Rails creates a worker copy of every database in `config/database.yml` that the tests use, including secondary ones. Rails 8.1 adds `parallelize_databases: false` for apps that set up worker databases themselves.
- `with: :threads` is for JRuby or code that cannot fork; on MRI, processes are faster.
- Newer Rails (on `main` after 8.1) assigns tests to workers in a fixed round-robin order so a seed reproduces a run, and adds `work_stealing: true` to even out workers when one gets the slow tests. Use `work_stealing` only on a Rails version that has it.

## CI

- Run `bin/rails test` and `bin/rails test:system` as separate jobs, so the fast job reports first.
- Split a large suite across machines only after parallel workers on one machine are used fully.
- Keep the database schema loaded from `db/schema.rb` (`bin/rails db:test:prepare`), not migrations.
- Precompile assets once before system tests (for example `bin/rails tailwindcss:build`), not per test.
