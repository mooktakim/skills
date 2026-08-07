# app/services — generation guide

Read this before generating `app/services/CLAUDE.md` in the target app. Derive every statement from that app's code; skip any question the app has no answer to. Only generate the file if the directory qualified in Phase 1 — if the app has no `app/services/`, no file (and never create the directory).

## Questions to answer from the code

- **The boundary**: what qualifies for `app/services/` versus logic nested under a model — state the rule. In apps where models own their verbs, services may be only cross-cutting utilities; say so explicitly, because agents default to dumping everything here.
- **Naming and structure**: `VerbNoun` vs `NounService`, one public method, class-level vs instance `call`.
- **Call signature**: positional vs kwargs, and what `call` accepts.
- **Return convention**: Result object, record-or-raise, nullable — show the shape exactly once.
- **Error handling**: which errors are rescued and converted, which propagate; custom error class hierarchy.
- **API clients**: where they live, one-class-per-provider conventions, how credentials are injected (Rails credentials? a `Creds` wrapper? ENV?), timeout/retry policy, and what test fakes exist.
- **Transactions**: who owns transaction boundaries — services, models, or callers.

## Target shape (fictional excerpt — copy the density, never the content)

```markdown
## Purpose
Cross-cutting utilities and third-party API clients only. Business operations
belong to their model (`app/models/<model>/` — see app/models/CLAUDE.md); if a
new class has an obvious owning model, it does not belong here.

## Conventions
- One class per provider under `app/services/<provider>/`; credentials come
  from `Rails.application.credentials.dig(:<provider>)` — never ENV directly.
- Clients expose narrow verb methods returning parsed hashes; they raise
  `Provider::Error` subclasses and never swallow HTTP failures.
- Every client has a test fake in `test/support/fakes/` — tests never hit the
  network (WebMock enforces this).
```
