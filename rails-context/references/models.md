# app/models - generation guide

Read this before generating `app/models/CLAUDE.md` in the target app. Every statement you write must be derived from that app's code - this guide only tells you what to look for and how dense the result should be. Only generate the file if the directory qualified in Phase 1; skip any question below that the app has no answer to.

## Questions to answer from the code

- **Concerns**: for each concern in `app/models/concerns/`, what is it *for* and when must a model include it? Which are mandatory for certain behaviours (auditing, tenancy, logging)? Describe purpose per concern, never its method list.
- **The noun/verb boundary**: where does business logic live - nested classes under `app/models/<model>/`, service objects, or the model itself? State the placement rule explicitly; this is the single thing an agent most often gets wrong.
- **Namespaces**: which domain does each model namespace own, and what makes a new model belong there?
- **ApplicationRecord**: customisations (default scopes, id strategy, normalization helpers, connection switching)?
- **Callback philosophy**: embraced, tolerated narrowly, or banned in favour of explicit orchestration?
- **Validation strategy**: model validations, form objects, DB constraints - which combination, and when is double enforcement (model AND DB) required?
- **Cross-cutting conventions**: soft delete, multi-tenancy scoping, money representation, time zones, encrypted attributes.
- **Query logic**: scopes on the model, query objects, or where-chains at call sites?
- **State machines**: which gem, where transitions live, timestamp/audit expectations.
- **External calls from models**: if models or their nested classes call APIs/LLMs, what wrapping, logging, or cost-tracking is mandatory?
- **Load-bearing constants**: constants other layers depend on that must not change silently.
- **Migrations**: app-specific rules only (FK indexing, reversibility, DB-engine constraints such as SQLite locking).

## Target shape (fictional excerpt - copy the density, never the content)

```markdown
## Conventions
- The model is the noun, nested classes are the verbs: `Invoice::Finalize` and
  `Invoice::SendReminder` live in `app/models/invoice/`, expose one public
  `call`, and return the record or raise. `app/services/` is only for
  cross-cutting utilities with no owning model.
- Any model with a lifecycle includes `Concerns::StateTimestamped` (state
  machine + per-transition timestamps). Don't hand-roll status columns.
- Money is integer cents + a `currency` column, never floats.
- Critical constraints are enforced twice: model validation AND a DB constraint.

## Gotchas
- `Account` is the multi-tenant root: every new model belongs to an account and
  includes `Concerns::AccountScoped`. An unscoped query is a bug, not a choice.
```

Every line in that excerpt survives someone adding another model - that's the test your output must pass.
