# Collections

Components that present many records: tables, stacked lists, and the pagination that navigates them. All colour comes from the role-token vocabulary in the catalog README.

## table

Columnar display for homogeneous records where users compare fields across rows. Prefer a stacked-list when rows are identity-led rather than true columns.

### Variants

| Variant | When to use |
|---------|-------------|
| Simple | Default; borderless, `divide-y` rows, transparent background |
| Striped | Long tables without strong row anchors; `even:bg-muted-surface` on `tr` |
| In card with header fill | Table inside a card shell; `thead` gets `bg-muted-surface` |
| Sticky header | Tall scrolling tables; each `th` gets `sticky top-0 z-10 bg-surface` |
| With row actions | Trailing right-aligned cell of `text-primary` links, header `sr-only` |

### Contract

- Axes: row treatment (divided, striped); container (bare, card shell); header (static, sticky); trailing actions (none, links).
- States: rows are static by default; hoverable rows take `hover:bg-muted-surface`. Action links carry `hover:text-primary-hover` and `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary`.

### Canonical sample

```html
<div class="overflow-x-auto">
  <table class="min-w-full divide-y divide-border">
    <thead>
      <tr>
        <th scope="col" class="py-3.5 pr-3 pl-4 text-left text-sm font-semibold text-on-surface sm:pl-0">Name</th>
        <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-on-surface">Role</th>
        <th scope="col" class="relative py-3.5 pr-4 pl-3 sm:pr-0"><span class="sr-only">Edit</span></th>
      </tr>
    </thead>
    <tbody class="divide-y divide-border">
      <tr>
        <td class="py-4 pr-3 pl-4 text-sm font-medium whitespace-nowrap text-on-surface sm:pl-0">Lindsay Walton</td>
        <td class="px-3 py-4 text-sm whitespace-nowrap text-muted">Member</td>
        <td class="relative py-4 pr-4 pl-3 text-right text-sm whitespace-nowrap sm:pr-0"><a href="#" class="font-medium text-primary hover:text-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Edit<span class="sr-only">, Lindsay Walton</span></a></td>
      </tr>
    </tbody>
  </table>
</div>
```

### Key patterns

- `min-w-full divide-y divide-border` on the table, inside an `overflow-x-auto` wrapper - the table scrolls horizontally on narrow screens instead of wrapping.
- First cell `pl-4 sm:pl-0`, middle cells `px-3`, last cell `pr-4 sm:pr-0`: gutters exist only where a page container has not already inset the table. Identity column is `font-medium text-on-surface`; secondary columns are `text-muted`; `whitespace-nowrap` on cells with short values.
- Action column header is `<span class="sr-only">Edit</span>`; each action link appends an `sr-only` row identifier for screen readers.
- Card-contained variant wraps the scroll wrapper in `overflow-hidden rounded-lg bg-surface shadow-sm ring-1 ring-border` and fills `thead` with `bg-muted-surface`.

## stacked-list

A vertical `ul` of rows for heterogeneous or identity-led records: people, projects, activity. Each row leads with a title and carries metadata, avatars, or badges.

### Variants

| Variant | When to use |
|---------|-------------|
| Simple | Default; avatar, title, and metadata split left/right |
| With badges | Status inline with the title as a badge |
| With actions | Trailing secondary button or overflow menu per row |
| Clickable rows | The whole row navigates; link wrapper with hover fill and chevron |

### Contract

- Axes: leading media (none, avatar); trailing content (metadata, badge, actions, chevron); interactivity (static, clickable row).
- States: static rows have no hover. Clickable rows take `hover:bg-muted-surface` and the link carries `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary`; per-row buttons keep their own states and sit outside the row link.

### Canonical sample

```html
<ul role="list" class="divide-y divide-border">
  <li class="flex justify-between gap-x-6 py-5">
    <div class="flex min-w-0 gap-x-4">
      <img class="size-12 flex-none rounded-full bg-muted-surface" src="/avatars/la.jpg" alt="">
      <div class="min-w-0 flex-auto">
        <p class="text-sm/6 font-semibold text-on-surface">Leslie Alexander</p>
        <p class="mt-1 truncate text-xs/5 text-muted">leslie@example.com</p>
      </div>
    </div>
    <div class="hidden shrink-0 sm:flex sm:flex-col sm:items-end">
      <p class="text-sm/6 text-on-surface">Co-Founder</p>
      <p class="mt-1 text-xs/5 text-muted">Last seen <time datetime="2026-08-11T09:00Z">3h ago</time></p>
    </div>
  </li>
</ul>
```

### Key patterns

- `ul role="list"` with `divide-y divide-border`; rows are `flex justify-between gap-x-6 py-5` with no horizontal padding when the list sits in a padded container.
- Left cluster is `flex min-w-0 gap-x-4` with `min-w-0 flex-auto` on the text block so `truncate` can work; right cluster is `shrink-0`, hidden below `sm` when it is secondary.
- Title is `text-sm/6 font-semibold text-on-surface`; metadata is `text-xs/5 text-muted`; separate inline metadata with a tiny `fill-current` dot, not punctuation.
- Clickable rows: a single link fills the row (`relative` row, stretched link or full-row `a`), `hover:bg-muted-surface` on the row, `size-5 text-muted` chevron at the end.
- Inside a card shell, give rows `px-4 sm:px-6` and let the shell's `overflow-hidden` clip the dividers.

## pagination

Page navigation for a collection, rendered as real links so every page is crawlable and shareable. Sits directly under the table or list it controls.

### Variants

| Variant | When to use |
|---------|-------------|
| Simple | Default; result summary plus Previous/Next, in a card footer or under a list |
| Numbered group | Direct access to nearby pages; joined button group with a current page |
| Top-border tabs | Minimal look on bare pages; `border-t-2` markers, no boxes |

### Contract

- Axes: style (simple, numbered, top-border); summary (with "Showing x to y of z", without).
- States: links take `hover:bg-muted-surface` and `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary`; the current page carries `aria-current="page"` with `bg-primary text-on-primary`; a disabled edge (first/last page) renders as a muted `span`, never a dead link.

### Canonical sample

```html
<nav class="flex items-center justify-between border-t border-border px-4 py-3 sm:px-6" aria-label="Pagination">
  <div class="hidden sm:block">
    <p class="text-sm text-muted">
      Showing <span class="font-medium text-on-surface">1</span> to <span class="font-medium text-on-surface">10</span>
      of <span class="font-medium text-on-surface">97</span> results
    </p>
  </div>
  <div class="flex flex-1 justify-between gap-x-3 sm:justify-end">
    <span class="inline-flex cursor-default items-center rounded-md bg-surface px-3 py-2 text-sm font-semibold text-muted ring-1 ring-inset ring-border">Previous</span>
    <a href="?page=2" class="inline-flex items-center rounded-md bg-surface px-3 py-2 text-sm font-semibold text-on-surface ring-1 ring-inset ring-border hover:bg-muted-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Next</a>
  </div>
</nav>
```

### Key patterns

- Always a `nav` with `aria-label="Pagination"`; `border-t border-border` visually attaches it to the collection above.
- Buttons are the secondary-button recipe: `rounded-md bg-surface px-3 py-2 text-sm font-semibold ring-1 ring-inset ring-border hover:bg-muted-surface`.
- Numbered group: `isolate inline-flex -space-x-px rounded-md shadow-xs`, each link `ring-1 ring-inset ring-border` with `focus:z-20` so the focused ring paints on top; end links get `rounded-l-md`/`rounded-r-md`; current page is `z-10 bg-primary text-on-primary` with `aria-current="page"`.
- Truncated ranges render an ellipsis as a non-interactive `span` in the same box style.
- Icon-only previous/next need an `sr-only` text label; the summary sentence hides below `sm` while Previous/Next spread with `flex-1 justify-between`.
