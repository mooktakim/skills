# App shells

Page-level layout frames that every screen of the app renders inside. Pick one shell per app (or per major area); components from the catalog slot into its regions.

## sidebar-shell

Persistent left navigation for apps with many top-level sections; the workhorse layout for admin and dashboard products.

### Variants

| Variant | When to use |
|---------|-------------|
| standard | Fixed 18rem sidebar plus sticky top bar; the default |
| narrow | Icon-only rail (`lg:w-20`, content `lg:pl-20`) when labels are not needed |
| contrast | Same structure with the sidebar's section tokens remapped to a darker theme |

### Composition

- Sidebar region hosts `sidebar-nav` (logo block at top, nav list, `mt-auto` footer items such as settings).
- Top bar hosts the mobile menu trigger, a search field, and a `dropdown` for the profile menu; on mobile the same `sidebar-nav` renders inside a `drawer`-style `<dialog>` opened from that trigger.
- Main region hosts `page-heading` followed by page content (an index-page or detail-page pattern).

### Layout skeleton

```html
<div>
  <!-- mobile off-canvas <dialog>; component: sidebar-nav -->
  <div class="hidden lg:fixed lg:inset-y-0 lg:z-50 lg:flex lg:w-72 lg:flex-col">
    <div class="flex grow flex-col gap-y-5 overflow-y-auto border-r border-border bg-surface px-6 pb-4">
      <!-- component: sidebar-nav -->
    </div>
  </div>
  <div class="lg:pl-72">
    <div class="sticky top-0 z-40 flex h-16 shrink-0 items-center gap-x-4 border-b border-border bg-surface px-4 shadow-xs sm:gap-x-6 sm:px-6 lg:px-8">
      <!-- mobile sidebar trigger (lg:hidden); search field -->
      <!-- component: dropdown (profile menu) -->
    </div>
    <main class="py-10">
      <div class="px-4 sm:px-6 lg:px-8">
        <!-- component: page-heading -->
        <!-- page content -->
      </div>
    </main>
  </div>
</div>
```

### Key patterns

- Sidebar is `lg:fixed lg:inset-y-0 lg:w-72` and the content column offsets by the same width with `lg:pl-72` - the two values must move together.
- Sidebar inner column: `flex grow flex-col gap-y-5 overflow-y-auto` so long nav lists scroll independently of the page.
- Top bar is `sticky top-0 z-40 h-16` with `border-b border-border bg-surface` so content scrolls beneath it; the sidebar's `lg:z-50` keeps it above.
- Mobile: the fixed sidebar is `hidden` below `lg`; navigation moves into an off-canvas `<dialog>` opened from the top bar, one behaviour swap and zero duplicated nav structure.

## stacked-shell

Horizontal top navigation with a constrained content column; suits apps with few top-level sections and content-first pages.

### Variants

| Variant | When to use |
|---------|-------------|
| with-page-header | Nav plus a distinct page header band; the default |
| plain | Nav directly above content, page heading inside main |
| two-row | Primary nav row plus a secondary `tabs` row for dense products |

### Composition

- Nav region hosts `navbar` (logo, horizontal links, notification button) with a `dropdown` for the profile menu; on mobile the links collapse into a `<dialog>` menu opened from a hamburger trigger inside `navbar`.
- Page header band hosts `page-heading`.
- Main region hosts page content; two-row variant places `tabs` in the second nav row.

### Layout skeleton

```html
<div class="min-h-full">
  <nav class="border-b border-border bg-surface">
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="flex h-16 items-center justify-between">
        <!-- component: navbar -->
        <!-- component: dropdown (profile menu); mobile menu trigger (md:hidden) -->
      </div>
    </div>
    <!-- mobile menu <dialog> hosting the nav links -->
  </nav>
  <header class="bg-surface shadow-xs">
    <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
      <!-- component: page-heading -->
    </div>
  </header>
  <main>
    <div class="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
      <!-- page content -->
    </div>
  </main>
</div>
```

### Key patterns

- Every band repeats the same constrained column: `mx-auto max-w-7xl px-4 sm:px-6 lg:px-8` - nav, header, and main all align on it.
- Nav row is `flex h-16 items-center justify-between`; the active link gets `bg-muted-surface text-on-surface` (or a `border-b-2 border-primary` underline in the plain variant), inactive links `text-muted hover:text-on-surface`.
- `min-h-full` on the root lets a `muted-surface` page background fill the viewport when content is short.
- Mobile: horizontal links are `hidden md:flex`; below `md` they render inside a `<dialog>` menu, one line of behaviour on the same link markup.

## minimal-shell

Bare frame for focused flows - sign-in, onboarding, error pages - where navigation would distract from a single task.

### Variants

| Variant | When to use |
|---------|-------------|
| logo-header | Slim logo-only header above the content column; the default |
| centered-card | Vertically centered narrow card for auth forms |
| bare | No header at all; full-bleed single-purpose page |

### Composition

- Header region hosts a logo link only - no `navbar`, no `dropdown`.
- Main region hosts one narrow content block: a `card` with a `form-page` pattern (auth, onboarding) or an `empty-state` (errors).
- No sidebar, no page header band; the page heading lives inside the content block.

### Layout skeleton

```html
<div class="flex min-h-full flex-col">
  <header class="border-b border-border bg-surface">
    <div class="mx-auto flex h-16 max-w-7xl items-center px-4 sm:px-6 lg:px-8">
      <!-- logo link -->
    </div>
  </header>

  <main class="flex flex-1 flex-col justify-center py-12 sm:px-6 lg:px-8">
    <div class="mx-auto w-full max-w-md px-4 sm:px-0">
      <!-- component: card (hosting the form or message) -->
    </div>
  </main>
</div>
```

### Key patterns

- Root is `flex min-h-full flex-col` with `flex-1` on main so short content still centers vertically in the viewport.
- Content column is deliberately narrow: `max-w-md` for forms, up to `max-w-3xl` for text-heavy pages - never the app's `max-w-7xl`.
- `justify-center` on main gives the centered-card variant; drop it (and use `py-12` alone) for top-aligned flows.
- Mobile: the shell is already single-column, so nothing collapses - the card just loses its horizontal padding via `px-4 sm:px-0`.
- Keep the logo a plain link to the app root; this shell must not grow navigation.
