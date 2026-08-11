# Feedback

Components that report outcomes and states to the user: inline alerts, empty states for zero-data screens, and transient notification toasts.

## alert

Inline banner embedded in the page flow that reports the outcome or status of an action: flash messages, validation summaries, account warnings.

### Variants
| Variant | When to use |
|---------|-------------|
| Tinted (default) | `bg-{tone}/10` rounded panel with icon, title, optional body |
| Accent border | `border-l-4 border-{tone} bg-muted-surface` for lower-key notices |
| With list | Validation summary: `ul.list-disc.space-y-1.pl-5` of errors in the body |
| With actions | Inline text buttons under the body (`View status`, `Dismiss`) |
| Dismissible | Trailing icon button removes the alert |

### Contract
- Axes: tone (`success`, `danger`, `warning`, `primary` for informational), density (title only, or title + body), dismissible or not.
- States: static by default; dismiss button carries hover, focus-visible. Dismissal removes the element - wire with a Stimulus controller.
- Semantics: carry `role="alert"` when inserted after an action (flash rendered via redirect or Turbo Stream); content present on initial page load may omit it.

### Canonical sample
```html
<div role="alert" class="rounded-md bg-success/10 p-4">
  <div class="flex">
    <div class="shrink-0">
      <svg class="size-5 text-success" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16Zm3.7-9.4-4.2 5.5-2.5-2.5 1.06-1.06 1.34 1.34 3.2-4.18 1.12.9Z" clip-rule="evenodd"/></svg>
    </div>
    <div class="ml-3">
      <h3 class="text-sm font-medium text-success">Changes saved</h3>
      <p class="mt-2 text-sm text-muted">Your profile has been updated.</p>
    </div>
    <div class="ml-auto pl-3">
      <button type="button" class="-m-1.5 rounded-md p-1.5 text-muted hover:text-on-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">
        <span class="sr-only">Dismiss</span>
        <svg class="size-5" viewBox="0 0 20 20" fill="currentColor"><path d="M6.28 5.22 10 8.94l3.72-3.72 1.06 1.06L11.06 10l3.72 3.72-1.06 1.06L10 11.06l-3.72 3.72-1.06-1.06L8.94 10 5.22 6.28l1.06-1.06Z"/></svg>
      </button>
    </div>
  </div>
</div>
```

### Key patterns
- Layout is a single flex row: `shrink-0` icon, `ml-3` body, `ml-auto pl-3` dismiss slot.
- Tone drives colour in exactly two places: `bg-{tone}/10` on the container, `text-{tone}` on icon and title; body text stays `text-muted`.
- Container is `rounded-md p-4`; the accent-border variant swaps the tint for `border-l-4 border-{tone} bg-muted-surface` and drops the radius on the left.
- Danger alerts with field errors put a `ul role="list" class="list-disc space-y-1 pl-5"` in the body and link each item to its field.
- The dismiss button uses negative margin (`-m-1.5 p-1.5`) so its hit area does not stretch the panel.

## empty-state

Centered placeholder for a screen or panel whose collection has no records yet. Names the missing thing and leads with the action that creates the first one.

### Variants
| Variant | When to use |
|---------|-------------|
| With action (default) | Icon, title, description, primary create button |
| Text only | Title + description; use when the user cannot create the record |
| Dashed action tile | The whole state is one large dashed-border button that starts creation |
| With starter grid | Description followed by a grid of template choices, then a secondary link |

### Contract
- Axes: leading visual (outline icon or none), call to action (primary button, dashed tile, or none).
- States: the embedded button or tile carries the standard states - hover, focus-visible, disabled; the state itself is static.
- Placement: render where the collection would be (inside the card or table region), never as a page of its own; keep the page heading and filters above it.

### Canonical sample
```html
<div class="text-center">
  <svg class="mx-auto size-12 text-muted" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M3 7.5V18a2.25 2.25 0 0 0 2.25 2.25h13.5A2.25 2.25 0 0 0 21 18V9.75a2.25 2.25 0 0 0-2.25-2.25H12L9.75 5.25H5.25A2.25 2.25 0 0 0 3 7.5Z"/></svg>
  <h3 class="mt-2 text-sm font-semibold text-on-surface">No projects</h3>
  <p class="mt-1 text-sm text-muted">Get started by creating a new project.</p>
  <div class="mt-6">
    <a href="#" class="inline-flex items-center rounded-md bg-primary px-3 py-2 text-sm font-semibold text-on-primary shadow-xs hover:bg-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">
      <svg class="-ml-0.5 mr-1.5 size-5" viewBox="0 0 20 20" fill="currentColor"><path d="M10.75 4.75a.75.75 0 0 0-1.5 0v4.5h-4.5a.75.75 0 0 0 0 1.5h4.5v4.5a.75.75 0 0 0 1.5 0v-4.5h4.5a.75.75 0 0 0 0-1.5h-4.5v-4.5Z"/></svg>
      New project
    </a>
  </div>
</div>
```

### Key patterns
- Everything hangs off `text-center`: `mx-auto size-12 text-muted` outline icon, `mt-2` title, `mt-1` description, `mt-6` action.
- Title is `text-sm font-semibold text-on-surface`; description `text-sm text-muted` - deliberately quiet next to the primary button.
- The action names the record ("New project"), matches the page heading's create button, and carries a leading plus icon (`-ml-0.5 mr-1.5 size-5`).
- Dashed tile variant: `relative block w-full rounded-lg border-2 border-dashed border-border p-12 text-center hover:border-muted focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary` wrapping the icon and title.
- Copy formula: what is missing, then how to get the first one - two short sentences maximum.

## notification

Transient toast confirming a background or asynchronous outcome. Floats over the page in a fixed region, top-right on desktop, bottom on mobile.

### Variants
| Variant | When to use |
|---------|-------------|
| Simple (default) | Icon, title, supporting line, close button |
| Condensed | Single line, icon + title + close; quick confirmations |
| With actions | Text buttons under the body (`Undo`, `Dismiss`) |
| With avatar | Person-initiated events; avatar replaces the icon, buttons below |

### Contract
- Axes: tone via icon colour (`success`, `danger`, `warning`, `primary`), density (simple, condensed), optional action row.
- States: close and action buttons carry hover, focus-visible. Auto-dismiss after a few seconds with enter/leave transitions - wire with a Stimulus controller; pause the timer on hover.
- Semantics: the fixed region carries `aria-live="polite"` and stays mounted; toasts are appended inside it (a Turbo Stream target works well) so screen readers announce them.

### Canonical sample
```html
<div aria-live="polite" class="pointer-events-none fixed inset-0 z-50 flex items-end px-4 py-6 sm:items-start sm:p-6">
  <div class="flex w-full flex-col items-center gap-y-4 sm:items-end">
    <div class="pointer-events-auto w-full max-w-sm overflow-hidden rounded-lg bg-surface shadow-lg ring-1 ring-border">
      <div class="p-4">
        <div class="flex items-start">
          <div class="shrink-0">
            <svg class="size-6 text-success" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/></svg>
          </div>
          <div class="ml-3 w-0 flex-1 pt-0.5">
            <p class="text-sm font-medium text-on-surface">Successfully saved</p>
            <p class="mt-1 text-sm text-muted">Anyone with the link can now view this file.</p>
          </div>
          <div class="ml-4 flex shrink-0">
            <button type="button" class="inline-flex rounded-md text-muted hover:text-on-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">
              <span class="sr-only">Close</span>
              <svg class="size-5" viewBox="0 0 20 20" fill="currentColor"><path d="M6.28 5.22 10 8.94l3.72-3.72 1.06 1.06L11.06 10l3.72 3.72-1.06 1.06L10 11.06l-3.72 3.72-1.06-1.06L8.94 10 5.22 6.28l1.06-1.06Z"/></svg>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
```

### Key patterns
- The region is `pointer-events-none fixed inset-0 z-50`; each toast restores `pointer-events-auto`, so the page stays clickable around it.
- Card recipe: `w-full max-w-sm rounded-lg bg-surface shadow-lg ring-1 ring-border` - elevation comes from shadow plus hairline ring, not a border utility.
- Body layout mirrors the alert: `flex items-start`, `shrink-0` icon, `ml-3 w-0 flex-1` text (the `w-0` forces wrapping), `ml-4 shrink-0` close button.
- `items-end sm:items-start` stacks toasts bottom-center on mobile and top-right on desktop; new toasts append with `gap-y-4`.
- Action-row variant: `mt-3 flex gap-x-3` of text buttons - primary action `text-primary hover:text-primary-hover`, secondary `text-muted hover:text-on-surface`.
