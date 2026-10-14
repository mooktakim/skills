# rails-minitest 0.1.1: agent renamed minitest-runner

- User asked to rename the moved `rails-tester` agent to match its use; chose `minitest-runner` from three options (named for its main, proactive use: running suites and returning a summary; writing and diagnosing tests stay in its description).
- Renamed `rails-minitest/agents/rails-tester.md` to `minitest-runner.md` and every `rails-minitest:rails-tester` reference: SKILL.md, hook text, READMEs, manifests, and the rails-specialists model/jobs/debugger agents. Mentions of `rails-tester` that name the old agent stay. rails-minitest 0.1.1, rails-specialists 0.4.1.
- Also corrected the plugin README: the session test helper comes from the Rails 8.1 authentication generator, not 8.0.
- Checks: 113 tests green on Ruby 4.0 and /usr/bin/ruby 2.6 + bash 3.2; plugin validate passes; headless `claude -p --plugin-dir` run launched `rails-minitest:minitest-runner` and it quoted rule 9 from the preloaded skill.
