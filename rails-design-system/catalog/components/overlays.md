# Overlays

Layered surfaces that sit above the page: blocking dialogs, edge panels, and anchored menus. All three keep static, framework-neutral markup; behaviour is native `<dialog>` where possible, Stimulus otherwise.

## modal

Blocking dialog for a focused task or confirmation that must be resolved before the user returns to the page.

### Variants

| Variant | When to use |
|---------|-------------|
| confirm | Destructive or irreversible action; primary button uses the danger role |
| simple | Short message with a single acknowledge action |
| form | Small create/edit form that does not warrant its own page |

### Contract

- Axes: variant (confirm, simple, form); width (`sm:max-w-sm`, `sm:max-w-lg`, `sm:max-w-2xl`).
- States: closed (no `open` attribute), open (via `showModal()`); every control carries focus-visible; buttons inside follow the `button` contract including disabled and loading on submit.
- Accessibility: `aria-modal="true"` and `aria-labelledby` pointing at the title id; `showModal()` provides focus trapping and Escape-to-close natively.

### Canonical sample

```html
<dialog id="deactivate-modal" aria-modal="true" aria-labelledby="deactivate-modal-title"
        class="fixed inset-0 z-10 w-screen overflow-y-auto bg-transparent backdrop:bg-on-surface/50">
  <div class="flex min-h-full items-end justify-center p-4 sm:items-center sm:p-0">
    <div class="w-full rounded-lg bg-surface p-6 text-left shadow-xl sm:my-8 sm:max-w-lg">
      <h3 id="deactivate-modal-title" class="text-base font-semibold text-on-surface">Deactivate account</h3>
      <p class="mt-2 text-sm text-muted">All account data will be permanently removed. This action cannot be undone.</p>
      <div class="mt-5 sm:flex sm:flex-row-reverse">
        <button type="button" class="inline-flex w-full justify-center rounded-md bg-danger px-3 py-2 text-sm font-semibold text-on-danger shadow-xs hover:bg-danger-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary sm:ml-3 sm:w-auto">Deactivate</button>
        <button type="button" class="mt-3 inline-flex w-full justify-center rounded-md bg-surface px-3 py-2 text-sm font-semibold text-on-surface shadow-xs ring-1 ring-border ring-inset hover:bg-muted-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary sm:mt-0 sm:w-auto">Cancel</button>
      </div>
    </div>
  </div>
</dialog>
```

### Key patterns

- Native `<dialog>` opened with `showModal()`; the backdrop is the `::backdrop` pseudo-element, styled with the `backdrop:` variant (`backdrop:bg-on-surface/50`).
- The dialog element itself is reset to a full-screen scroll container (`fixed inset-0 w-screen overflow-y-auto bg-transparent`); the visible panel is an inner div.
- Panel: `rounded-lg bg-surface shadow-xl p-6 sm:max-w-lg` with `w-full` so it fills small screens.
- Centering wrapper: `flex min-h-full items-end justify-center p-4 sm:items-center sm:p-0` - bottom sheet on mobile, centered on desktop.
- `sm:flex sm:flex-row-reverse` puts the primary action on the right on desktop while buttons stack full width on mobile.

## drawer

Edge panel that slides in from the right for detail views or side forms while the page stays visible behind the backdrop.

### Variants

| Variant | When to use |
|---------|-------------|
| detail | Read-only record detail; body only, no footer |
| form | Create/edit form with a sticky footer action row |
| wide | Two-column or dense content; `max-w-2xl` panel |

### Contract

- Axes: variant (detail, form, wide); width (`max-w-md` default, `max-w-2xl` wide).
- States: closed, open (via `showModal()`); close button and footer buttons carry focus-visible; form variant submits, so its primary button needs a loading treatment.
- Accessibility: `aria-modal="true"`, `aria-labelledby` on the panel title; close button has an `sr-only` label.

### Canonical sample

```html
<dialog id="record-drawer" aria-modal="true" aria-labelledby="record-drawer-title"
        class="fixed inset-y-0 right-0 m-0 h-full max-h-none w-screen max-w-md bg-surface p-0 shadow-xl backdrop:bg-on-surface/50">
  <form class="flex h-full flex-col divide-y divide-border">
    <div class="flex items-start justify-between px-4 py-6 sm:px-6">
      <h2 id="record-drawer-title" class="text-base font-semibold text-on-surface">Edit record</h2>
      <button type="button" class="rounded-md text-muted hover:text-on-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">
        <span class="sr-only">Close panel</span>
        <svg class="size-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12"/></svg>
      </button>
    </div>
    <div class="flex-1 overflow-y-auto px-4 py-6 sm:px-6">
      <!-- body: form-group fields or description-list -->
    </div>
    <div class="flex shrink-0 justify-end gap-x-3 px-4 py-4 sm:px-6">
      <button type="button" class="rounded-md bg-surface px-3 py-2 text-sm font-semibold text-on-surface shadow-xs ring-1 ring-border ring-inset hover:bg-muted-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Cancel</button>
      <button type="submit" class="rounded-md bg-primary px-3 py-2 text-sm font-semibold text-on-primary shadow-xs hover:bg-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Save</button>
    </div>
  </form>
</dialog>
```

### Key patterns

- Same native `<dialog>` mechanics as `modal` (`showModal()`, `backdrop:bg-on-surface/50` on `::backdrop`), but the dialog is pinned to the edge: `fixed inset-y-0 right-0 h-full max-h-none w-screen max-w-md shadow-xl` with margins and padding zeroed to override user-agent centering.
- Full-height column stack: `flex h-full flex-col` with header, `flex-1 overflow-y-auto` body, and `shrink-0` footer.
- `divide-y divide-border` separates header, body, and footer without extra border rules.
- Detail variant drops the `<form>` and footer; the body then holds a `description-list`.
- Slide-in motion, if wanted, is a transition on `translate-x` toggled by the open state - never required for function.

## dropdown

Anchored action menu opened from a trigger button, for row actions and profile menus.

### Variants

| Variant | When to use |
|---------|-------------|
| simple | Flat list of 3-6 actions |
| grouped | Related actions separated by dividers |
| with-danger | Destructive action isolated in its own last group |

### Contract

- Axes: variant (simple, grouped, with-danger); alignment (`right-0 origin-top-right` default, `left-0 origin-top-left`).
- States: closed (`hidden` on the panel, `aria-expanded="false"`), open; items get `hover:bg-muted-surface` and focus-visible; a disabled item uses `text-muted pointer-events-none`.
- Accessibility: trigger carries `aria-haspopup="menu"` and `aria-expanded`; panel is `role="menu"`, items `role="menuitem"`.

### Canonical sample

```html
<div class="relative inline-block text-left">
  <button type="button" aria-haspopup="menu" aria-expanded="false"
          class="inline-flex items-center gap-x-1.5 rounded-md bg-surface px-3 py-2 text-sm font-semibold text-on-surface shadow-xs ring-1 ring-border ring-inset hover:bg-muted-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">
    Options
    <svg class="-mr-1 size-5 text-muted" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M5.22 8.22a.75.75 0 0 1 1.06 0L10 11.94l3.72-3.72a.75.75 0 1 1 1.06 1.06l-4.25 4.25a.75.75 0 0 1-1.06 0L5.22 9.28a.75.75 0 0 1 0-1.06Z" clip-rule="evenodd"/></svg>
  </button>
  <div role="menu" hidden
       class="absolute right-0 z-10 mt-2 w-56 origin-top-right divide-y divide-border rounded-md bg-surface shadow-lg ring-1 ring-border focus:outline-none">
    <div class="py-1" role="none">
      <a href="#" role="menuitem" class="block px-4 py-2 text-sm text-on-surface hover:bg-muted-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Edit</a>
      <a href="#" role="menuitem" class="block px-4 py-2 text-sm text-on-surface hover:bg-muted-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Duplicate</a>
    </div>
    <div class="py-1" role="none">
      <button type="submit" role="menuitem" class="block w-full px-4 py-2 text-left text-sm text-danger hover:bg-muted-surface focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary">Delete</button>
    </div>
  </div>
</div>
```

Wire open/close, Escape, and focus trap with a Stimulus controller (toggle `hidden` and `aria-expanded`).

### Key patterns

- Anchor: `relative inline-block text-left` on the wrapper; the panel positions against it.
- Panel: `absolute right-0 mt-2 w-56 origin-top-right rounded-md bg-surface shadow-lg ring-1 ring-border focus:outline-none`.
- Items are plain `block px-4 py-2 text-sm` links or buttons; a form-wrapped `<button type="submit">` handles non-GET actions such as sign-out or delete.
- `divide-y divide-border` groups actions; the destructive item sits alone in the last group with `text-danger`.
- Markup ships closed (`hidden`, `aria-expanded="false"`); all behaviour lives in the Stimulus controller, none in the markup.
