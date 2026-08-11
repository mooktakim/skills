# <section>/divergences.md - generation guide

Read this immediately before writing or updating a section's `divergences.md`. Every value collapsed during canonicalisation and every off-system one-off found in the views lands here - never dropped silently. The ledger is the section's migration backlog; it is as valuable as the canonical values themselves, because it turns "make the app consistent" into a checklist.

## Questions to answer from the code

- **What was collapsed**: each variant folded into a canonical token or spec during generation - the losing value, where it occurs (`file:line`), what it collapsed to.
- **What the audit flags**: `bin/audit_design` findings reviewed but deferred, one row each.
- **What was accepted**: deliberate exceptions (marked `design-ok` in code) with the reason - so a future run doesn't re-litigate them.
- **Status**: every row is `backlog`, `migrated`, or `accepted`. Re-runs move rows forward; a row never disappears without becoming `migrated` or `accepted`.

## Target shape (fictional excerpt - copy the density, never the content)

```markdown
# admin - Divergences

Migration backlog: off-system values found in views, and what they should
become. Rows leave only by migration or explicit acceptance.

| Where | What | Target | Status |
|-------|------|--------|--------|
| app/views/admin/users/index.html.erb:34 | bg-gray-50 row stripe | bg-muted-surface | backlog |
| app/views/admin/orders/show.html.erb:12 | hand-rolled status pill | badge (tone=success) | backlog |
| app/views/admin/reports/index.html.erb:8 | chart palette hexes | design-ok: charting lib owns colour | accepted |
```
