# docs/design-system/README.md - generation guide

Read this immediately before writing the top-level `README.md`. It is the router agents load first: the usage protocol plus the section index, and nothing else. No token values, no recipes, no aesthetic prose - link to the files that own those. If the README needs updating when a component is added, it contains something it should not.

## Questions to answer

- **Protocol**: the ordered steps for building or changing a view - identify the section, read `conventions.md` and the section's `tokens.md` and the relevant `components/` and `patterns/` specs before writing markup, compose token-only, spec missing pieces before hand-rolling, update the spec with the change, run `bin/audit_design`.
- **The one rule**: token utilities only - one line, since the root AGENTS.md block and the specs carry the detail.
- **Sharing model**: one line naming the model chosen in the Phase 1 plan - islands (sections share nothing), shared foundation (sections build on `shared/`), or which sections use an external library as-is (their paths are in `vendor-paths`). Maintenance runs and future agents read it from here.
- **Index**: one row per section - name, audience, layout(s) it owns, path.

## Target shape (fictional excerpt - copy the density, never the content)

```markdown
# Design system

The standard every view is built against.

## Building a view
1. Identify the section (by layout/namespace - see index below).
2. Read `conventions.md`, the section's `tokens.md`, then the specs for every
   component and pattern the view touches, before writing markup.
3. Compose from specced components using token utilities only - never raw
   hex, palette classes, or arbitrary values.
4. Missing component or pattern? Spec it first (re-run rails-design-system
   or write the spec by hand) - never hand-roll a one-off.
5. If the change alters a documented pattern, update the spec in the same
   commit. `bin/audit_design` reports drift.

Sharing model: islands - sections share nothing.

## Sections
| Section | Audience | Layouts | Docs |
|---------|----------|---------|------|
| admin | internal operators | admin | `admin/` |
| marketing | visitors | marketing, minimal | `marketing/` |
```
