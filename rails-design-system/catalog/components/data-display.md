# Data display

Components that present a single record or a small set of values: cards, badges, avatars, description lists, and stats. All colour comes from the role-token vocabulary in the catalog README.

## card

A bounded surface that groups related content. The default container for panels, form sections, and summary blocks.

### Variants

| Variant | When to use |
|---------|-------------|
| Body only | Default panel; just the shell and the padded body |
| With header | Titled section; header row separated by `border-b border-border` |
| With footer | Actions or meta under the body; `border-t border-border`, often `bg-muted-surface` |
| Muted well | De-emphasised inset area; `bg-muted-surface`, no shadow or ring |
| Edge-to-edge on mobile | Full-bleed below `sm`; `rounded-none sm:rounded-lg` on the shell |

### Contract

- Axes: sections (body / header + body / body + footer / all three); emphasis (surface card, muted well); mobile bleed (rounded, edge-to-edge).
- States: static container - the card itself has no hover, focus, or disabled states; interactive children carry their own.

### Canonical sample

```html
<div class="overflow-hidden rounded-lg bg-surface shadow-sm ring-1 ring-border">
  <div class="border-b border-border px-4 py-4 sm:px-6">
    <h3 class="text-base font-semibold text-on-surface">Section title</h3>
  </div>
  <div class="px-4 py-5 sm:p-6">
    <p class="text-sm text-muted">Card body content.</p>
  </div>
  <div class="border-t border-border bg-muted-surface px-4 py-4 sm:px-6">
    <p class="text-sm text-muted">Footer content.</p>
  </div>
</div>
```

### Key patterns

- Shell is `rounded-lg bg-surface shadow-sm ring-1 ring-border`; the ring, not a border, draws the hairline so the radius stays crisp.
- Body padding is `px-4 py-5 sm:p-6`; header and footer rows use `px-4 py-4 sm:px-6`.
- `overflow-hidden` on the shell clips flush children (tables, images, list rows) to the radius.
- Muted well is `rounded-lg bg-muted-surface px-4 py-5 sm:p-6` - a fill change only, never a shadow.

## badge

A small inline label for status, category, or count. Reads as metadata, never as an action.

### Variants

| Variant | When to use |
|---------|-------------|
| Flat neutral | Default label; `bg-muted-surface text-muted ring-border` |
| Tone (success / warning / danger / primary) | Status meaning; same shape with soft role fills, e.g. `bg-success/10 text-success ring-success/20` |
| Pill | Swap `rounded-md` for `rounded-full`; softer, tag-like feel |
| With dot | Leading `size-1.5` dot filled with the tone role; state at a glance |
| Removable | Trailing icon button with `sr-only` label; only in editable tag lists |

### Contract

- Axes: tone (neutral, success, warning, danger, primary); shape (rounded, pill); adornment (none, dot, remove button).
- States: static by default. The remove button is the only interactive part: hover fill plus `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary`.

### Canonical sample

```html
<span class="inline-flex items-center rounded-md bg-muted-surface px-2 py-1 text-xs font-medium text-muted ring-1 ring-inset ring-border">Draft</span>

<span class="inline-flex items-center rounded-md bg-success/10 px-2 py-1 text-xs font-medium text-success ring-1 ring-inset ring-success/20">Active</span>

<span class="inline-flex items-center gap-x-1.5 rounded-md bg-muted-surface px-2 py-1 text-xs font-medium text-muted ring-1 ring-inset ring-border">
  <svg class="size-1.5 fill-success" viewBox="0 0 6 6" aria-hidden="true"><circle cx="3" cy="3" r="3"/></svg>
  Online
</span>
```

### Key patterns

- Base recipe: `inline-flex items-center rounded-md px-2 py-1 text-xs font-medium` plus a soft fill and `ring-1 ring-inset`.
- Tone comes from soft role fills, not solid ones: fill at low opacity (`bg-danger/10`), text in the full role (`text-danger`), ring slightly stronger than the fill (`ring-danger/20`). Solid `bg-primary text-on-primary` badges are reserved for counts on dark chrome.
- `gap-x-1.5` spaces the dot or icon; the dot is a `size-1.5` filled circle, `aria-hidden`.
- Never attach click handlers to the badge itself; wrap it in a link or add an inner button instead.

## avatar

A user or entity image with fixed square dimensions, with deterministic fallbacks when no image exists.

### Variants

| Variant | When to use |
|---------|-------------|
| Circular | Default for people; `rounded-full` |
| Rounded | Organisations, projects, files; `rounded-md` |
| Initials placeholder | No image; initials on `bg-muted-surface` |
| With status dot | Presence or state; absolutely positioned dot ringed in `ring-surface` |
| Group | Overlapping stack of members; `-space-x-2` |

### Contract

- Axes: size (`size-6`, `size-8`, `size-10`, `size-12`); shape (circular, rounded); fallback (image, initials); adornment (none, status dot); grouping (single, stacked).
- States: static image. When wrapped in a profile link, the wrapper carries hover text shifts and `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary`.

### Canonical sample

```html
<img src="/avatars/lw.jpg" alt="" class="size-8 rounded-full">

<span class="inline-flex size-8 items-center justify-center rounded-full bg-muted-surface">
  <span class="text-sm font-medium text-muted">LW</span>
</span>

<span class="relative inline-block">
  <img src="/avatars/lw.jpg" alt="" class="size-8 rounded-full">
  <span class="absolute right-0 bottom-0 block size-2 rounded-full bg-success ring-2 ring-surface"></span>
</span>

<div class="flex -space-x-2 overflow-hidden">
  <img src="/avatars/a.jpg" alt="" class="inline-block size-8 rounded-full ring-2 ring-surface">
  <img src="/avatars/b.jpg" alt="" class="inline-block size-8 rounded-full ring-2 ring-surface">
</div>
```

### Key patterns

- `size-*` sets both dimensions; pick one size per context and keep it consistent.
- Fallback initials use `inline-flex items-center justify-center` on the same `size-*` so image and placeholder are interchangeable.
- Status dot needs `relative inline-block` on the wrapper; `ring-2 ring-surface` separates the dot from the image.
- Groups overlap with `-space-x-2`, each avatar ringed `ring-2 ring-surface`; add `isolate` plus descending `z-*` to flip the stacking direction.
- `alt` is empty when a visible name sits beside the avatar; otherwise it names the person.

## description-list

Semantic key-value pairs (`dl`/`dt`/`dd`) for a single record's attributes - the core of a detail page.

### Variants

| Variant | When to use |
|---------|-------------|
| Left-aligned | Default; label and value share a row via `sm:grid sm:grid-cols-3` |
| Stacked | Narrow columns or short values; drop the grid so `dd` sits under `dt` |
| Striped | Long lists; `even:bg-muted-surface` on rows instead of dividers |
| In card | Wrap in the card shell with a header row naming the record |

### Contract

- Axes: alignment (left-aligned, stacked); row treatment (divided, striped); container (bare, card).
- States: static. Value cells may contain links (`text-primary hover:text-primary-hover` with the focus-visible outline) or action buttons; the list itself is inert.

### Canonical sample

```html
<dl class="divide-y divide-border">
  <div class="px-4 py-4 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
    <dt class="text-sm font-medium text-on-surface">Full name</dt>
    <dd class="mt-1 text-sm text-muted sm:col-span-2 sm:mt-0">Margot Foster</dd>
  </div>
  <div class="px-4 py-4 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
    <dt class="text-sm font-medium text-on-surface">Email address</dt>
    <dd class="mt-1 text-sm text-muted sm:col-span-2 sm:mt-0">margot@example.com</dd>
  </div>
  <div class="px-4 py-4 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
    <dt class="text-sm font-medium text-on-surface">Role</dt>
    <dd class="mt-1 text-sm text-muted sm:col-span-2 sm:mt-0">Admin</dd>
  </div>
</dl>
```

### Key patterns

- Always `dl`/`dt`/`dd`; each pair wrapped in a `div` row so dividers and grids apply per pair.
- `divide-y divide-border` separates rows; striped variant replaces it with `even:bg-muted-surface`.
- The 1:2 split (`sm:grid-cols-3` with `dd` spanning `sm:col-span-2`) keeps labels in a single scannable column; below `sm` the pair stacks with `mt-1`.
- `dt` is `font-medium text-on-surface`, `dd` is `text-muted` - the value is quieter than the label.
- In-card variant puts the `dl` under a card header and drops `sm:px-0` in favour of the card's `px-4 sm:px-6` gutters.

## stat

A single headline metric with a label, usually laid out as a responsive grid of stat cards on a dashboard.

### Variants

| Variant | When to use |
|---------|-------------|
| Simple card | Default; label over a large value in a card shell |
| With delta | Trend context; `text-success` or `text-danger` change beside the value |
| Shared borders | Dense dashboards; one card shell, cells split by `divide-x`/`divide-y` |

### Contract

- Axes: layout (separate cards, shared borders); delta (none, positive, negative); grid columns (`sm:grid-cols-2`, `sm:grid-cols-3`).
- States: static. A "View all" style footer link carries `text-primary hover:text-primary-hover` and the focus-visible outline.

### Canonical sample

```html
<dl class="grid grid-cols-1 gap-5 sm:grid-cols-3">
  <div class="overflow-hidden rounded-lg bg-surface px-4 py-5 shadow-sm ring-1 ring-border sm:p-6">
    <dt class="truncate text-sm font-medium text-muted">Total subscribers</dt>
    <dd class="mt-1 text-3xl font-semibold tracking-tight text-on-surface tabular-nums">71,897</dd>
  </div>
  <div class="overflow-hidden rounded-lg bg-surface px-4 py-5 shadow-sm ring-1 ring-border sm:p-6">
    <dt class="truncate text-sm font-medium text-muted">Open rate</dt>
    <dd class="mt-1 flex items-baseline gap-x-2">
      <span class="text-3xl font-semibold tracking-tight text-on-surface tabular-nums">58.16%</span>
      <span class="text-sm font-medium text-success">+5.4%</span>
    </dd>
  </div>
  <div class="overflow-hidden rounded-lg bg-surface px-4 py-5 shadow-sm ring-1 ring-border sm:p-6">
    <dt class="truncate text-sm font-medium text-muted">Churn</dt>
    <dd class="mt-1 flex items-baseline gap-x-2">
      <span class="text-3xl font-semibold tracking-tight text-on-surface tabular-nums">1.2%</span>
      <span class="text-sm font-medium text-danger">+0.3%</span>
    </dd>
  </div>
</dl>
```

### Key patterns

- The group is a `dl` grid; each stat is one `dt` (label) plus one `dd` (value) so the metric stays semantic.
- Values always take `tabular-nums` so figures align and do not shift as they update.
- Value scale is `text-3xl font-semibold tracking-tight text-on-surface`; the label is `text-sm font-medium text-muted truncate`.
- Delta colour encodes direction of the number, not desirability - pick `text-success`/`text-danger` per metric (rising churn is `text-danger`).
- Shared-borders variant: one card shell around a `grid divide-y divide-border sm:grid-cols-3 sm:divide-x sm:divide-y-0`, cells padded `px-4 py-5 sm:p-6`.
