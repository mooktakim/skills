---
id: rails-minitest
type: architecture
status: active
summary: rails-minitest plugin (2026-10-08) - user decisions behind it, how it was verified, and the open fixtures-vs-factory_bot question
aliases: [minitest, tests, fixtures, minitest-runner, audit_tests]
created: 2026-10-08
verified_at: 2026-10-15
citations: [rails-minitest/agents/minitest-runner.md, rails-minitest/scripts/audit_tests]
sources: [auto memory rails-minitest-status.md]
---

Built 2026-10-08 from a research request ("best standards for Rails Minitest, every kind"). User decisions: a separate skill plugin with the tester agent inside it, removed from rails-specialists (user proposed this over my "skill + one-line pointer" plan); **Minitest only** - no RSpec support, by explicit choice; "specialise it and make sure it's done the best way possible".

Design: lean SKILL.md (writing mode + approval-gated suite mode), seven references loaded on demand, `scripts/audit_tests` run from the skill dir (not copied into apps), SessionStart hook only in Rails+Minitest apps. Agent is `minitest-runner` (renamed from `rails-tester` on the user's request, 0.1.1). It preloads the skill with `skills: [rails-minitest:rails-minitest]` - verified in a headless `claude -p --plugin-dir` run that the namespaced name works and `${CLAUDE_SKILL_DIR}` is expanded in the preloaded text.

**Why:** the agent alone was never delegated to (see [rails-specialists-status](rails-specialists.md)); a skill also reaches the main session, where most tests get written.

**How to apply:** resolved 2026-10-08 - the user chose fixtures for new apps; `config_files/claude/rails.md` now says "minitest with fixtures (no factory_bot)" (commit 8eda874). The skill still follows whatever an existing app uses. SimpleCov 1.x (2026) merges `parallelize` workers itself via the `rails` profile - old manual parallelize hooks are only for 0.22.

Model/effort decision (2026-10-08): user chose to keep minitest-runner with no `model` or `effort` (inherits the session). Revisit only with data at the ~2026-10-22 count: if runs are frequent and slow because of the model, not the tests, try `effort: medium` first (no model pin); a cheap-runner/full-model split only with usage numbers.
