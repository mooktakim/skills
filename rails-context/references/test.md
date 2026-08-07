# test/ — generation guide

Read this before generating `test/CLAUDE.md` (or `spec/CLAUDE.md`) in the target app. This directory qualifies when the suite has non-obvious infrastructure — stubbing helpers, factory conventions, job-testing quirks — not merely because tests exist. Derive every statement from the app's code; skip questions the app has no answer to.

## Questions to answer from the code

- **Framework and layout**: minitest or RSpec; parallelization settings and their gotchas (shared state, DB handling).
- **Test data**: fixtures vs factories, and the conventions for whichever is used (naming, traits, association defaults).
- **External calls**: the stubbing policy (WebMock/VCR), and any app-specific stub helpers — especially for expensive dependencies (LLM mocks, payment fakes). State the rule ("tests never hit the network") and where the helpers live.
- **Job testing**: how the queue adapter is configured in tests, enqueued-vs-performed assertion style, and interactions with global retry config (e.g. if `perform_now` re-enqueues instead of raising, document how to assert an error).
- **System tests**: driver, JS support, auth sign-in helpers, screenshot/artifact conventions.
- **What to test where**: the app's actual emphasis — model-heavy unit tests, controller tests, system tests for flows — so new tests land at the right layer.
- **CI quirks**: anything that passes locally but fails in CI (time zones, ordering, headless browser limits) that the suite already guards against.

## Target shape (fictional excerpt — copy the density, never the content)

```markdown
## Conventions
- factory_bot everywhere; fixtures are not used. Factories define the minimum
  valid record — add traits rather than fattening the default.
- WebMock blocks all network. LLM calls are stubbed with `LLMTestHelper`
  (`mock_llm_chat`, `stub_llm_message`) — a test that hits a real provider is
  a bug regardless of outcome.
- Jobs: assert behaviour with `perform_now` + state checks. The global retry
  policy swallows errors in `perform_now`; to assert a raise, call
  `Job.new.perform(...)` directly.
- System tests sign in via `sign_in_as(user)` (test/support) — never drive the
  login form except in the auth system tests themselves.
```
