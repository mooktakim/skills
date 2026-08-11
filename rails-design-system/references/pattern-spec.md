# <section>/patterns/<name>.md - generation guide

Read this immediately before writing each pattern spec. A pattern is a page archetype - what lets an agent build a *whole view* to standard, not a stray element. Patterns compose components by reference and own only the layout between them: restating a component's markup inside a pattern is the defect this tier exists to prevent. Look the pattern up in `catalog/README.md` for raw material; adapt to the section. Filenames are kebab-case singular (`index-page.md`, `app-shell.md`).

## Questions to answer from the code

- **Purpose**: which controller actions / page types this archetype serves in this section.
- **Composition**: the regions top-to-bottom, each naming the component it hosts and the axes it uses ("`page-heading` with one primary `button`", "`table`, or `stacked-list` on mobile-heavy views").
- **Layout skeleton**: the containers, grid, and spacing classes between regions - with `<!-- component: table -->` slot comments where components mount, never their internals.
- **Variants**: the archetype's real alternates (table vs card collection, single vs two-column form) as deltas.
- **Rules**: the invariants an agent would break - "filters never wrap onto a second row", "empty collections render `empty-state`, never a bare table".
- **Realized as**: a representative view that follows the pattern (relative path), once one exists.

## Target shape (fictional excerpt - copy the density, never the content)

```markdown
# index-page

## Purpose
Every admin collection screen: list, filter, act.

## Composition
1. `page-heading` - title, count badge, one primary `button`.
2. Filter row - `select` and `input` components, right-aligned.
3. Collection - `table`; `empty-state` when blank.
4. `pagination` - only when more than one page exists.

## Layout skeleton
```html
<div class="px-4 sm:px-6 lg:px-8">
  <!-- component: page-heading -->
  <div class="mt-4 flex items-center justify-end gap-x-3">
    <!-- component: select, input -->
  </div>
  <div class="mt-8 flow-root">
    <!-- component: table -->
  </div>
  <!-- component: pagination -->
</div>
```

## Rules
- One primary button per screen, and it lives in the heading.
- The table scrolls inside its own container; the page never scrolls sideways.
```
