# <section>/components/<name>.md - generation guide

Read this immediately before writing each component spec. A spec is prescriptive - the rule every future instance follows - and must fit one screen; if it is longer than the component it describes, cut. Look the component up in `catalog/README.md` first and load the mapped catalog file as raw material; re-shape it to this section's tokens and the app's real markup - catalog samples use bare role names, so apply the section's token prefix (`bg-primary` → `bg-admin-primary`) while adapting. No catalog entry means derive everything from the app's own markup. Filenames are kebab-case singular (`button.md`, `page-heading.md`).

## Questions to answer from the code

- **Purpose**: the one job this component does, and the near-neighbour to reach for when it is the wrong choice.
- **Anatomy**: the named parts (icon slot, label, meta row) - only parts that exist.
- **Contract**: every axis as a closed list - `variant`, `size`, `tone` with their allowed values. An open-ended axis ("any colour that fits") is a defect.
- **States**: default, hover, focus-visible, active, disabled, loading (where it submits). Missing focus-visible means the spec is incomplete. Which states does the app's markup already handle; which must be added?
- **Recipe**: the canonical class string per part, token utilities only. This is the copy-paste source of truth.
- **Variants**: each non-canonical variant as a class *delta* from the recipe, never a second full recipe.
- **Anti-patterns**: the specific one-offs found in the views that this spec replaces (cite them - they feed the divergences ledger).
- **Realized as**: relative path to the ERB partial / ViewComponent / Phlex class, once one exists; omit the line until then.

## Target shape (fictional excerpt - copy the density, never the content)

```markdown
# button

## Purpose
Triggers an action. For navigation styled as a button, still use an `<a>`
with these classes; for plain navigation use a link, not this.

## Contract
| Axis | Values |
|------|--------|
| variant | primary, secondary, danger |
| size | sm, md |
States: default, hover, focus-visible, disabled, loading.

## Recipe
```html
<button type="button" class="inline-flex items-center gap-x-1.5 rounded-md
  bg-primary px-3 py-2 text-sm font-semibold text-on-primary shadow-xs
  hover:bg-primary-hover focus-visible:outline-2
  focus-visible:outline-offset-2 focus-visible:outline-primary
  disabled:opacity-50 disabled:pointer-events-none">Save</button>
```

## Variants
- secondary: `bg-surface text-on-surface ring-1 ring-inset ring-border
  hover:bg-muted-surface` replaces the primary fill classes.
- sm: `px-2 py-1` replaces `px-3 py-2`.

## Realized as
`app/views/admin/shared/_button.html.erb`
```

Every line above survives someone adding another button to the app - that is the test your output must pass.
