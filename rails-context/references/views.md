# app/views — generation guide

Read this before generating `app/views/CLAUDE.md` in the target app. Only generate this file when the view layer is genuinely non-trivial (multiple layouts/audiences, a component boundary, Turbo conventions, multi-domain rendering) — a conventional CRUD view tree gets nothing. Derive every statement from the app's code; skip questions the app has no answer to.

## Questions to answer from the code

- **The page/component boundary**: what renders as an ERB template vs a component — state the rule for where new markup goes.
- **Partials**: naming conventions, strict locals or not, where shared partials live (the principle, not the list).
- **Helpers**: what belongs in `app/helpers/` vs components vs presenters — most apps have an implicit rule; make it explicit.
- **Turbo**: frame id conventions, lazy-loaded frames, where turbo_stream templates live, broadcast targets.
- **Layouts**: which layout serves which audience (public, admin, mailer, bare), and the content_for slots each expects.
- **i18n**: enforced (`t` everywhere) or ad hoc — and lint/CI enforcement if any.
- **SEO/meta**: title/meta/OG conventions and structured-data patterns for public pages.
- **Multi-domain/theming**: if pages render differently per tenant/domain, how the view layer resolves that.

## Target shape (fictional excerpt — copy the density, never the content)

```markdown
## Purpose
ERB page templates and layouts. Reusable UI lives in `app/components/` —
a partial rendered from more than one page should become a component.

## Conventions
- Partials declare strict locals (`<%# locals: (invoice:) %>`); no ivars in
  partials.
- Three layouts: `application` (public), `admin`, `minimal` (auth flows).
  Public pages must set `content_for(:title)` and `:meta_description`.
- Turbo frame ids come from `dom_id(record, :section)` — never hand-written
  strings, broadcasts depend on them matching.
```
