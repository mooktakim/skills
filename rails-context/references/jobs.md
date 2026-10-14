# app/jobs - generation guide

Read this before generating `app/jobs/AGENTS.md` in the target app. Derive every statement from that app's code; skip any question the app has no answer to. Only generate the file if the directory qualified in Phase 1.

## Questions to answer from the code

- **Backend and execution model**: which queue backend, and where workers run (separate process, inside Puma) - plus the practical consequence of that choice.
- **Queues**: named queues and their latency expectations; how a new job picks one.
- **Global retry/discard**: what `ApplicationJob` declares, whether subclasses may add their own, and the non-obvious consequences (e.g. a global `retry_on` means `perform_now` re-enqueues instead of raising - which changes how tests must assert errors).
- **Idempotency**: is it expected, and how is it achieved (state guards, uniqueness keys)?
- **Concurrency limits**: which jobs are throttled and with what mechanism.
- **Enqueue sites**: who is allowed to enqueue - models, controllers, other jobs?
- **Arguments**: records vs ids, GlobalID reliance, deserialization-failure policy.
- **Organisation**: the principle behind the folder/namespace layout (by feature? by model?) - the principle, never the folder list. Note constant-resolution gotchas if job namespaces differ from service/model namespaces.
- **Pipelines**: orchestrator/step patterns, and what drives them (state machine on the parent model?).
- **Recurring work**: where scheduled/cron jobs are defined.

## Target shape (fictional excerpt - copy the density, never the content)

```markdown
# Background Jobs (Solid Queue)

Solid Queue, database-backed, runs inside Puma - a long job ties up web
capacity, so slow work is chunked into steps.

## Conventions
- Jobs live in plural feature namespaces (`Invoices::SendReminderJob`). Fully
  qualify constants inside a job - the singular model namespace is not resolved
  implicitly from a plural job namespace.
- `ApplicationJob` declares the global retry policy; never repeat `retry_on` in
  a subclass. Consequence: `perform_now` re-enqueues on error rather than
  raising - to assert a raise in tests, call `Job.new.perform(...)` directly.
- Jobs are idempotent via state guards: re-running a completed step is a no-op.
- LLM and image jobs declare `limits_concurrency` - copy the pattern from a
  sibling job in the same namespace.
```
