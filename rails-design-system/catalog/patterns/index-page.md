# Index page

The list/table archetype: a heading with the primary action, an optional filter bar, one collection, pagination, and an empty-state fallback.

## Purpose

Present a resource collection and route the user to the two things that matter: creating a new record and opening an existing one. Every Rails `index` view is a variant of this page.

## Composition

1. `page-heading` - resource name (plus one line of context as muted text) with exactly one primary `button` ("New \<resource\>") on the right.
2. Filter bar (optional) - a row of `input` (search) and `select` (scope) controls; render only when the collection is realistically filtered.
3. Collection - a `table` for scannable, multi-attribute rows; a `stacked-list` for narrow content or mobile-first sections. When the collection is empty, render `empty-state` here instead, with the same primary action.
4. `pagination` - directly under the collection; omit when the collection cannot exceed one page.

## Layout skeleton

```html
<div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
  <div class="sm:flex sm:items-center sm:justify-between">
    <div class="sm:flex-auto">
      <!-- component: page-heading (title + optional muted context line) -->
    </div>
    <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
      <!-- component: button (primary, "New <resource>") -->
    </div>
  </div>

  <div class="mt-6 sm:flex sm:items-center sm:gap-x-4">
    <!-- component: input (search) + select (filters) - optional row -->
  </div>

  <div class="mt-8 flow-root">
    <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
      <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
        <!-- component: table (or stacked-list; empty-state when no records) -->
      </div>
    </div>
  </div>

  <div class="mt-4">
    <!-- component: pagination -->
  </div>
</div>
```

## Variants

| Variant | When to use |
|---------|-------------|
| Table | Records with 3+ comparable attributes; admin and back-office lists |
| Stacked list | 1-2 attributes per record, avatar/title/subtitle shape, narrow columns |
| Card grid (`grid gap-6 sm:grid-cols-2 lg:grid-cols-3` of `card`) | Visual records (projects, media) where each item needs room |
| With filter bar | Collections users search or scope; skip for short, stable lists |
| Empty | No records match: `empty-state` replaces the collection, pagination omitted |

## Key patterns

- `mx-auto max-w-7xl px-4 sm:px-6 lg:px-8` - the page container; every full page shares it.
- `sm:flex sm:items-center sm:justify-between` - heading row: title grows (`sm:flex-auto`), action stays fixed (`sm:flex-none`), stacking vertically on mobile via `mt-4 sm:mt-0`.
- `mt-8 flow-root` plus the negative-margin `overflow-x-auto` wrapper - lets a wide table scroll edge-to-edge on mobile while staying inside the container at `sm+`.
- `inline-block min-w-full align-middle` - keeps the table full width inside the scroll wrapper.
- One primary action per page. Secondary bulk actions (export, import) become secondary buttons or a dropdown next to it.
- The empty state repeats the same primary action so the page is never a dead end.
