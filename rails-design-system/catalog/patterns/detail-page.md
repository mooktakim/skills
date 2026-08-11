# Detail page

The show archetype: a heading with secondary actions, a description-list of the record's attributes, then one section per related collection.

## Purpose

Present a single record in full: its identity and status up top, its attributes as labelled pairs, and its associations as their own titled sections. Every Rails `show` view is a variant of this page.

## Composition

1. `breadcrumb` (optional) - back to the index; render when the page sits more than one level deep.
2. `page-heading` - record title (with an optional `badge` for status and muted meta line), plus secondary `button`s on the right (Edit, and at most one more). Destructive actions use the danger button and sit last.
3. `description-list` - the record's own attributes as label/value pairs. Wrap in a `card` when the page has multiple sections, so each section reads as one block.
4. Related-item sections - one per association, each a section title (`text-base font-semibold text-on-surface`, optional muted description) followed by a `table`, `stacked-list`, or grid of `card`s, plus a "View all" link or "Add" `button` in the section title row.

## Layout skeleton

```html
<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
  <!-- component: breadcrumb (optional) -->

  <div class="mt-2 md:flex md:items-center md:justify-between">
    <div class="min-w-0 flex-1">
      <!-- component: page-heading (title + badge + muted meta) -->
    </div>
    <div class="mt-4 flex shrink-0 gap-x-3 md:ml-4 md:mt-0">
      <!-- component: button (secondary, e.g. "Edit"; danger last) -->
    </div>
  </div>

  <div class="mt-8">
    <!-- component: description-list (record attributes, in a card) -->
  </div>

  <section class="mt-12">
    <div class="sm:flex sm:items-center sm:justify-between">
      <!-- section title + muted description -->
      <!-- component: button or link ("Add" / "View all") -->
    </div>
    <div class="mt-4">
      <!-- component: table / stacked-list / card grid (related records) -->
    </div>
  </section>
  <!-- repeat <section> per association -->
</div>
```

## Variants

| Variant | When to use |
|---------|-------------|
| Single column (above) | Default; attributes then related sections, top to bottom |
| Two column (`lg:grid lg:grid-cols-3 lg:gap-8`: main `lg:col-span-2`, aside `lg:col-span-1`) | A dominant association (activity, comments) beside the attributes |
| Description-list only | Leaf records with no associations; heading + attributes, nothing else |
| Related as cards | Few, rich associated records; otherwise prefer a table or stacked list |

## Key patterns

- `mx-auto max-w-7xl px-4 sm:px-6 lg:px-8` - same page container as every other page.
- `md:flex md:items-center md:justify-between` heading row with `min-w-0 flex-1` on the title side so long titles truncate (`sm:truncate`) instead of pushing the actions off-screen.
- `shrink-0` + `gap-x-3` on the actions group - buttons keep their size and spacing at all widths.
- `mt-12` between sections, `mt-4`/`mt-8` inside them - section gaps are visibly larger than intra-section gaps.
- Section title rows reuse the `sm:flex sm:items-center sm:justify-between` idiom at a smaller type size; the page has exactly one `h1`.
- Related tables reuse the index page's `flow-root` + `overflow-x-auto` wrapper when they can grow wide.
- An empty association renders a one-line muted message or a compact `empty-state`, never a bare heading over nothing.
