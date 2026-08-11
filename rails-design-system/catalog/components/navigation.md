# Navigation

Components that orient the user and move them between pages: the top navbar, sidebar navigation, tabs, breadcrumbs, and the page heading that anchors each screen.

## navbar

Horizontal top bar for app-wide navigation in a stacked shell. Holds the brand mark, primary links, and right-side actions (search, notifications, profile).

### Variants
| Variant | When to use |
|---------|-------------|
| Pill links (default) | Links as rounded chips; current gets a muted fill |
| Underline links | Full-height links with a `border-b-2` current indicator; pairs with tab-heavy apps |
| Primary fill | Whole bar `bg-primary`, links `text-on-primary`; strong brand presence |

### Contract
- Axes: tone (`surface` bar with `border-b border-border`, or `primary` fill), link style (pill or underline).
- States: default, hover (`hover:bg-muted-surface hover:text-on-surface`), focus-visible, current (`bg-muted-surface text-primary` plus `aria-current="page"`). No disabled state - omit links the user cannot visit.
- Mobile: links collapse behind a menu button below `md:`; the panel markup stays static - wire open/close with a Stimulus controller.

### Canonical sample
```html
<nav class="border-b border-border bg-surface">
  <div class="mx-auto max-w-7xl px-6 lg:px-8">
    <div class="flex h-16 items-center justify-between">
      <div class="flex items-center gap-x-10">
        <a href="/" class="shrink-0 text-base font-semibold text-on-surface">Acme</a>
        <div class="hidden md:flex md:items-baseline md:gap-x-4">
          <a href="#" aria-current="page" class="rounded-md bg-muted-surface px-3 py-2 text-sm font-medium text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Dashboard</a>
          <a href="#" class="rounded-md px-3 py-2 text-sm font-medium text-muted hover:bg-muted-surface hover:text-on-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Projects</a>
          <a href="#" class="rounded-md px-3 py-2 text-sm font-medium text-muted hover:bg-muted-surface hover:text-on-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Team</a>
        </div>
      </div>
      <button type="button" class="rounded-md p-2 text-muted hover:bg-muted-surface hover:text-on-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary md:hidden">
        <span class="sr-only">Open main menu</span>
        <svg class="size-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"/></svg>
      </button>
    </div>
  </div>
</nav>
```

### Key patterns
- `mx-auto max-w-7xl px-6 lg:px-8` constrains the bar to the app content width; `h-16` is the standard bar height.
- Current link: `bg-muted-surface text-primary` plus `aria-current="page"` - one visual signal, one semantic signal, always together.
- Underline-link variant deltas: `inline-flex items-center border-b-2 px-1 pt-1`; current `border-primary text-on-surface`, others `border-transparent text-muted hover:border-border`.
- Primary-fill variant deltas: bar `bg-primary`, links `text-on-primary`, current and hover fills `bg-primary-hover`.
- Right-side icon buttons (notifications, profile) reuse the mobile-button classes; dropdown menus are separate `dropdown` components.

## sidebar-nav

Vertical navigation column for a sidebar shell. Grouped link lists with leading icons, optional section labels, and a bottom-pinned utility link.

### Variants
| Variant | When to use |
|---------|-------------|
| Full (default) | `lg:w-72` column with icon + label items |
| With section labels | A `text-xs/6 font-semibold text-muted` heading above each group |
| Narrow icon-only | `lg:w-20` rail; labels become `sr-only`, items center the icon |

### Contract
- Axes: width (full or narrow), grouping (flat list or labelled sections).
- States: default, hover (`hover:bg-muted-surface hover:text-primary`), focus-visible, current (`bg-muted-surface text-primary` plus `aria-current="page"`).
- Desktop: fixed column (`lg:fixed lg:inset-y-0 lg:w-72`) with page content offset `lg:pl-72`. Mobile: same `<nav>` rendered inside an off-canvas drawer - wire open/close with a Stimulus controller.

### Canonical sample
```html
<nav class="flex h-full flex-col overflow-y-auto border-r border-border bg-surface px-6 pb-4" aria-label="Sidebar">
  <ul role="list" class="flex flex-1 flex-col gap-y-7 pt-5">
    <li>
      <ul role="list" class="-mx-2 space-y-1">
        <li>
          <a href="#" aria-current="page" class="group flex gap-x-3 rounded-md bg-muted-surface p-2 text-sm/6 font-semibold text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">
            <svg class="size-6 shrink-0" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="m2.25 12 9.75-9.75L21.75 12M4.5 9.75V21h5.25v-6h4.5v6h5.25V9.75"/></svg>
            Dashboard
          </a>
        </li>
        <li>
          <a href="#" class="group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-muted hover:bg-muted-surface hover:text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">
            <svg class="size-6 shrink-0" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M15 19.5a4.5 4.5 0 0 0-6 0M12 11.25a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z"/></svg>
            Team
          </a>
        </li>
      </ul>
    </li>
    <li class="mt-auto">
      <a href="#" class="group -mx-2 flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold text-muted hover:bg-muted-surface hover:text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Settings</a>
    </li>
  </ul>
</nav>
```

### Key patterns
- Item shape is fixed: `group flex gap-x-3 rounded-md p-2 text-sm/6 font-semibold` with a `size-6 shrink-0` leading icon.
- `-mx-2` bleeds item fills past the `px-6` column padding so text stays on the column grid.
- `mt-auto` on the last `<li>` pins utility links (Settings, Help) to the bottom of the column.
- Nested `ul role="list"` groups with `gap-y-7` between groups, `space-y-1` between items.
- Narrow-rail deltas: column `lg:w-20`, items `justify-center p-3`, label wrapped in `sr-only`.

## tabs

In-page section switcher rendered as a row of links under a shared hairline. Each tab is a real link to a route (or query param) so the browser back button works.

### Variants
| Variant | When to use |
|---------|-------------|
| Underline (default) | Section navigation inside a page or record |
| Pill | Softer look for filters and dense toolbars |
| With badge | Append a count to a tab label |
| Mobile select | Replace the row with a `<select>` below `sm:` when tabs overflow |

### Contract
- Axes: style (underline or pill), optional badge per tab.
- States: default, hover (`hover:border-border hover:text-on-surface`), focus-visible, current (`border-primary text-primary` plus `aria-current="page"`), disabled (`pointer-events-none opacity-50`).
- Tabs that swap in-page panels without navigation are buttons with `role="tab"` and `aria-selected` instead - wire the switching with a Stimulus controller.

### Canonical sample
```html
<div class="border-b border-border">
  <nav class="-mb-px flex gap-x-8" aria-label="Tabs">
    <a href="#" aria-current="page" class="whitespace-nowrap border-b-2 border-primary px-1 py-4 text-sm font-medium text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Account</a>
    <a href="#" class="whitespace-nowrap border-b-2 border-transparent px-1 py-4 text-sm font-medium text-muted hover:border-border hover:text-on-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Members</a>
    <a href="#" class="inline-flex items-center whitespace-nowrap border-b-2 border-transparent px-1 py-4 text-sm font-medium text-muted hover:border-border hover:text-on-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">
      Billing
      <span class="ml-3 rounded-full bg-muted-surface px-2.5 py-0.5 text-xs font-medium text-on-surface">4</span>
    </a>
  </nav>
</div>
```

### Key patterns
- Active indicator is `border-b-2 border-primary`; inactive tabs keep `border-transparent` so labels never shift on selection.
- `-mb-px` pulls the tab borders down to overlap the container's `border-b border-border` hairline.
- Pill variant deltas: drop the wrapper border and `-mb-px`; tabs become `rounded-md px-3 py-2`, current `bg-muted-surface text-primary`.
- Mobile select: wrap the row in `hidden sm:block` and render a `<select>` mirror of the tabs inside `sm:hidden`.
- `whitespace-nowrap` plus `gap-x-8` keeps a scrollable single row when space is tight.

## breadcrumb

Hierarchy trail above a page heading. Home icon, ancestor links, and the current page as plain text.

### Variants
| Variant | When to use |
|---------|-------------|
| Chevron separators (default) | Standard trail above a page heading |
| Slash separators | Denser, text-only look: `<span class="text-muted">/</span>` between items |
| Full-width bar | Trail in its own `border-b border-border bg-surface` bar spanning the app container |
| Mobile back link | Below `sm:`, collapse to a single "Back" link to the parent |

### Contract
- Axes: separator (chevron or slash), placement (inline or full-width bar).
- States: link default, hover (`hover:text-on-surface`), focus-visible; current item is a non-interactive `<span>` with `aria-current="page"`.
- Structure: `<nav aria-label="Breadcrumb">` wrapping `<ol role="list">`; one `<li>` per level.

### Canonical sample
```html
<nav class="flex" aria-label="Breadcrumb">
  <ol role="list" class="flex items-center gap-x-4">
    <li>
      <a href="/" class="text-muted hover:text-on-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">
        <svg class="size-5 shrink-0" viewBox="0 0 20 20" fill="currentColor"><path d="M10 2 2 9h2v8h5v-5h2v5h5V9h2l-8-7Z"/></svg>
        <span class="sr-only">Home</span>
      </a>
    </li>
    <li class="flex items-center gap-x-4">
      <svg class="size-5 shrink-0 text-muted" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="m8.3 4.9 5.1 5.1-5.1 5.1-1.1-1.1 4-4-4-4 1.1-1.1Z"/></svg>
      <a href="#" class="text-sm font-medium text-muted hover:text-on-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Projects</a>
    </li>
    <li class="flex items-center gap-x-4">
      <svg class="size-5 shrink-0 text-muted" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="m8.3 4.9 5.1 5.1-5.1 5.1-1.1-1.1 4-4-4-4 1.1-1.1Z"/></svg>
      <span class="text-sm font-medium text-on-surface" aria-current="page">Project Nero</span>
    </li>
  </ol>
</nav>
```

### Key patterns
- Separators are tiny inline chevron SVGs (`size-5 shrink-0 text-muted`, `aria-hidden="true"`) inside each `<li>`, not pseudo-elements.
- The current page is never a link: `text-on-surface font-medium` against `text-muted` ancestors, marked `aria-current="page"`.
- Home is an icon-only link with an `sr-only` label.
- `gap-x-4` spaces both the separator and the label inside each item.
- Full-width bar variant: wrap the `<ol>` in `mx-auto flex w-full max-w-7xl px-6 lg:px-8` inside the bordered bar.

## page-heading

Title block at the top of every page: h1, optional meta row, and right-aligned action buttons. Sits below the breadcrumb, above filters and content.

### Variants
| Variant | When to use |
|---------|-------------|
| Simple | Title only, no actions |
| With actions (default) | Title plus secondary and primary buttons |
| With meta | Icon + text facts under the title (status, location, dates) |
| With breadcrumb | Breadcrumb rendered directly above, `mt-2` before the title row |

### Contract
- Axes: actions (none, one primary, secondary + primary), meta row (present or absent).
- States: buttons carry the standard button states - hover, focus-visible, disabled (`disabled:opacity-50 disabled:pointer-events-none`), loading on submit.
- Responsive: single column with actions below the title on mobile; `md:` puts actions on the same row. On `sm:` and below, demote extra secondary buttons into a dropdown.

### Canonical sample
```html
<div class="md:flex md:items-center md:justify-between">
  <div class="min-w-0 flex-1">
    <h1 class="text-2xl/7 font-bold text-on-surface sm:truncate sm:text-3xl sm:tracking-tight">Back End Developer</h1>
    <div class="mt-1 flex flex-wrap gap-x-6">
      <div class="mt-2 flex items-center text-sm text-muted">
        <svg class="mr-1.5 size-5 shrink-0" viewBox="0 0 20 20" fill="currentColor"><path d="M10 2a6 6 0 0 0-6 6c0 4.5 6 10 6 10s6-5.5 6-10a6 6 0 0 0-6-6Zm0 8a2 2 0 1 1 0-4 2 2 0 0 1 0 4Z"/></svg>
        Remote
      </div>
      <div class="mt-2 flex items-center text-sm text-muted">Full-time</div>
    </div>
  </div>
  <div class="mt-4 flex gap-x-3 md:ml-4 md:mt-0">
    <button type="button" class="rounded-md bg-surface px-3 py-2 text-sm font-semibold text-on-surface shadow-xs ring-1 ring-inset ring-border hover:bg-muted-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Edit</button>
    <button type="button" class="rounded-md bg-primary px-3 py-2 text-sm font-semibold text-on-primary shadow-xs hover:bg-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Publish</button>
  </div>
</div>
```

### Key patterns
- `min-w-0 flex-1` on the title wrapper plus `sm:truncate` lets long titles ellipsize instead of wrapping the action row.
- Title scale: `text-2xl/7 font-bold` stepping up to `sm:text-3xl sm:tracking-tight` - the only h1 on the page.
- Meta items: `mt-2 flex items-center text-sm text-muted` with an `mr-1.5 size-5 shrink-0` icon; `gap-x-6` between facts.
- `md:flex md:items-center md:justify-between` is the responsive pivot; actions get `mt-4 md:mt-0 md:ml-4`.
- Exactly one primary button per heading; everything else is the outline secondary style.
