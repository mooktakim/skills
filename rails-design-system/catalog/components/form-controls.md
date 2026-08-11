# Form controls

The form input primitives - input, textarea, select, checkbox, radio, toggle - and the form-group wrapper that binds a control to its label, help text, and error. Entries follow the catalog entry shape and use role tokens only.

## input
Single-line text entry. Always rendered inside a form-group with an associated `<label>`; never rely on placeholder text as the label.

### Variants
| Variant | When to use |
|---------|-------------|
| default | Plain text entry (canonical below). |
| with leading icon | An icon clarifies the value type (search, email). |
| with add-on | A fixed prefix or suffix (`https://`, `.com`, currency). |
| with trailing button | An action bound to the value (copy, search submit). |

### Contract
- Axes: `type` (text | email | password | search | number | url | tel | date); variant as above; full width of its form-group by default.
- States: default, focus-visible, invalid (via `aria-invalid` - see form-group), disabled (`disabled:cursor-not-allowed disabled:opacity-50`), read-only (`read-only:bg-muted-surface`).

### Canonical sample
```html
<div>
  <label for="email" class="block text-sm/6 font-medium text-on-surface">Email</label>
  <div class="mt-2">
    <input id="email" name="email" type="email" placeholder="you@example.com" class="block w-full rounded-md bg-surface px-3 py-1.5 text-base text-on-surface outline-1 -outline-offset-1 outline-border placeholder:text-muted focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50 sm:text-sm/6">
  </div>
</div>
```

### Key patterns
- The border is an inset outline, not a border: `outline-1 -outline-offset-1 outline-border` at rest, thickening to `outline-2 -outline-offset-2 outline-primary` on focus. No layout shift, no double border with add-ons.
- `text-base` with `sm:text-sm/6` keeps mobile browsers from zooming the field while rendering compact text on larger screens.
- Placeholder colour is `placeholder:text-muted`, never the control's text role.
- Leading icon: wrap icon and input in `flex items-center rounded-md bg-surface pl-3` carrying the outline classes with `focus-within:` in place of `focus-visible:`; the icon is `size-5 shrink-0 text-muted`; the inner input drops its own outline and becomes `block min-w-0 grow py-1.5 pl-1 pr-3`.
- Add-on: `flex items-stretch` wrapper; prefix `<span class="inline-flex items-center rounded-l-md border border-r-0 border-border px-3 text-muted sm:text-sm">`; the input flattens the joined corner with `rounded-none rounded-r-md` (mirror for suffixes).
- Trailing button: a secondary button with `relative -ml-px rounded-l-none` sharing the input's hairline, as in button-group.
- Set `autocomplete` wherever a token exists (`email`, `name`, `current-password`, `postal-code`); browsers reward it and audits check it.
- Invalid state is wired through form-group: `aria-invalid="true"` on the input plus `aria-invalid:outline-danger` baked into the base classes.

## textarea
Multi-line text entry for descriptions, comments, and messages. Same visual language as input, stretched over several rows.

### Variants
| Variant | When to use |
|---------|-------------|
| default | Free-form text in a form (canonical below). |
| comment box | Framed composer with an action row inside the frame. |
| auto-growing | Height follows content instead of a fixed row count. |
| with character count | A corner hint tracks remaining characters against a limit. |

### Contract
- Axes: `rows` (default 4; 2-3 for compact comment boxes); resize behaviour (default vertical; `resize-none` inside a framed composer); sizing (fixed rows | auto-growing).
- States: default, focus-visible, invalid (via `aria-invalid` - see form-group), disabled (`disabled:cursor-not-allowed disabled:opacity-50`).

### Canonical sample
```html
<div>
  <label for="description" class="block text-sm/6 font-medium text-on-surface">Description</label>
  <div class="mt-2">
    <textarea id="description" name="description" rows="4" class="block w-full rounded-md bg-surface px-3 py-1.5 text-base text-on-surface outline-1 -outline-offset-1 outline-border placeholder:text-muted focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50 sm:text-sm/6"></textarea>
  </div>
</div>
```

### Key patterns
- Identical outline, radius, padding, and type classes to input - a textarea is an input that grows rows, nothing more.
- `rows="4"` is the default; do not set a height class, let rows drive it.
- Comment box variant: a wrapper `<div class="overflow-hidden rounded-lg bg-surface pb-12 shadow-xs outline-1 -outline-offset-1 outline-border focus-within:outline-2 focus-within:-outline-offset-2 focus-within:outline-primary">` owns the frame; the textarea inside becomes borderless and fixed - `block w-full resize-none bg-transparent py-1.5 px-3 text-on-surface placeholder:text-muted focus-visible:outline-none` - and the action row (submit button, attachment icons) is absolutely positioned in the reserved `pb-12` band.
- Auto-growing variant: add `field-sizing-content` and cap with a `max-h-` step so long input scrolls instead of pushing the page; keep `rows` as the minimum height.
- When the visible label would be redundant (a lone comment composer), keep the `<label>` and hide it with `sr-only`.
- Invalid state is wired through form-group: `aria-invalid="true"` plus `aria-invalid:outline-danger` in the base classes, error text below the frame.
- Character count renders as a form-group corner hint (`text-sm/6 text-muted`) updated by a small Stimulus controller; it turns `text-danger` past the limit.
- `text-base` with `sm:text-sm/6` mirrors input and keeps mobile browsers from zooming on focus.

## select
Choice from a fixed list. The native `<select>` is the default; it is keyboard- and mobile-correct for free.

### Variants
| Variant | When to use |
|---------|-------------|
| native | Plain text options - always the default (canonical below). |
| custom listbox | Only when options need rich content (avatars, status dots); requires JS and full ARIA listbox semantics. |

### Contract
- Axes: option content (text for native; rich content forces the custom variant); optional disabled options.
- States: default, focus-visible, invalid (via `aria-invalid` - see form-group), disabled (`disabled:cursor-not-allowed disabled:opacity-50`).

### Canonical sample
```html
<div>
  <label for="country" class="block text-sm/6 font-medium text-on-surface">Country</label>
  <div class="mt-2 grid grid-cols-1">
    <select id="country" name="country" class="col-start-1 row-start-1 w-full appearance-none rounded-md bg-surface py-1.5 pl-3 pr-8 text-base text-on-surface outline-1 -outline-offset-1 outline-border focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50 sm:text-sm/6">
      <option>United Kingdom</option>
      <option>United States</option>
      <option>Canada</option>
    </select>
    <svg class="pointer-events-none col-start-1 row-start-1 mr-2 size-5 self-center justify-self-end text-muted sm:size-4" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
      <path fill-rule="evenodd" d="M4.22 6.22a.75.75 0 0 1 1.06 0L8 8.94l2.72-2.72a.75.75 0 1 1 1.06 1.06l-3.25 3.25a.75.75 0 0 1-1.06 0L4.22 7.28a.75.75 0 0 1 0-1.06Z" clip-rule="evenodd"/>
    </svg>
  </div>
</div>
```

### Key patterns
- `appearance-none` strips the native chrome; the outline, radius, padding, and type classes then match input exactly.
- The chevron is overlaid by stacking select and icon in the same grid cell (`grid grid-cols-1` wrapper, `col-start-1 row-start-1` on both) with `pointer-events-none self-center justify-self-end` on the icon - no absolute positioning.
- `pr-8` reserves room for the chevron so option text never runs under it.
- Custom listbox variant: the trigger button reuses these exact classes; the popup is `absolute z-10 mt-1 max-h-60 w-full overflow-auto rounded-md bg-surface py-1 shadow-lg ring-1 ring-border`; the focused option gets `bg-primary text-on-primary`, the selected option `font-semibold` plus a trailing `text-primary` check icon.

## checkbox
Boolean or multi-select choice. One checkbox toggles one independent option; a group of related checkboxes lives in a `<fieldset>` with a `<legend>`.

### Variants
| Variant | When to use |
|---------|-------------|
| default | Checkbox with label (canonical below, with description). |
| list in fieldset | Several related options under one `<legend>`. |
| checkbox on right | Row-style pickers (member lists); label left, control right. |

### Contract
- Axes: with or without description; label side (right of control by default, control on right for row lists).
- States: default, checked, indeterminate (parent of a partly checked list), focus-visible, disabled (`disabled:cursor-not-allowed disabled:opacity-50`).

### Canonical sample
```html
<div class="flex gap-3">
  <div class="flex h-6 shrink-0 items-center">
    <div class="grid size-4 grid-cols-1">
      <input id="comments" name="comments" type="checkbox" aria-describedby="comments-description" class="peer col-start-1 row-start-1 appearance-none rounded-sm border border-border bg-surface checked:border-primary checked:bg-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50">
      <svg class="pointer-events-none col-start-1 row-start-1 hidden size-3 self-center justify-self-center text-on-primary peer-checked:block" viewBox="0 0 14 14" fill="none" aria-hidden="true">
        <path d="M11.67 3.5 5.25 9.92 2.33 7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    </div>
  </div>
  <div class="text-sm/6">
    <label for="comments" class="font-medium text-on-surface">Comments</label>
    <p id="comments-description" class="text-muted">Get notified when someone comments on a posting.</p>
  </div>
</div>
```

### Key patterns
- `appearance-none` + `size-4 rounded-sm border border-border bg-surface`, filling with `checked:border-primary checked:bg-primary` - the box is styled entirely by state variants.
- The check glyph is a sibling SVG stacked in the same grid cell, revealed with `peer` on the input and `peer-checked:block`; it inherits `text-on-primary` via `stroke="currentColor"`. An indeterminate dash uses the same stacking with `peer-indeterminate:block` and `indeterminate:border-primary indeterminate:bg-primary` on the input.
- `flex h-6 shrink-0 items-center` around the control aligns it with the first line of `text-sm/6` label text.
- `aria-describedby` links the description; a bare checkbox drops the description `<p>` and uses `flex items-center gap-x-3` instead.
- Right-aligned list rows: `divide-y divide-border` between rows, label `min-w-0 flex-1`, control wrapped in `ml-3 flex h-6 items-center`.

## radio
Choice of exactly one option from a small visible set. Radios always come as a named group inside a `<fieldset>`; for more than roughly six options use select instead.

### Variants
| Variant | When to use |
|---------|-------------|
| stacked list | Default vertical group (canonical below). |
| inline list | Two or three short options on one line. |
| with description | Each option needs secondary text. |
| cards | Options are substantial enough to be tiles (plans, tiers). |

### Contract
- Axes: layout (stacked | inline | cards); with or without per-option description; shared `name` is mandatory.
- States: default, checked, focus-visible, disabled (`disabled:cursor-not-allowed disabled:opacity-50`).

### Canonical sample
```html
<fieldset>
  <legend class="text-sm/6 font-semibold text-on-surface">Notifications</legend>
  <p class="mt-1 text-sm/6 text-muted">How do you prefer to be notified?</p>
  <div class="mt-6 space-y-4">
    <div class="flex items-center">
      <input id="notify-email" name="notify" type="radio" checked class="relative size-4 appearance-none rounded-full border border-border bg-surface before:absolute before:inset-1 before:rounded-full before:bg-surface checked:border-primary checked:bg-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50">
      <label for="notify-email" class="ml-3 block text-sm/6 font-medium text-on-surface">Email</label>
    </div>
    <div class="flex items-center">
      <input id="notify-sms" name="notify" type="radio" class="relative size-4 appearance-none rounded-full border border-border bg-surface before:absolute before:inset-1 before:rounded-full before:bg-surface checked:border-primary checked:bg-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:cursor-not-allowed disabled:opacity-50">
      <label for="notify-sms" class="ml-3 block text-sm/6 font-medium text-on-surface">SMS</label>
    </div>
  </div>
</fieldset>
```

### Key patterns
- `appearance-none size-4 rounded-full` with the inner dot drawn by `before:absolute before:inset-1 before:rounded-full before:bg-surface` - when checked, `checked:bg-primary` fills the ring and the surface-coloured dot appears against it. No images, no extra markup.
- The group is a `<fieldset>` with a `<legend>`; an optional group description sits directly under the legend as `mt-1 text-sm/6 text-muted`.
- Stacked spacing is `space-y-4`; the inline variant swaps the wrapper for `flex items-center gap-x-6`.
- With descriptions: wrap the input in `flex h-6 items-center` and put label + `text-muted` description in an `ml-3 text-sm/6` block, linked with `aria-describedby`.
- Card variant: hide the input with `sr-only`, style the wrapping `<label>` as a `relative flex cursor-pointer rounded-lg border border-border bg-surface p-4 shadow-xs`, and mark selection with `has-checked:border-primary has-checked:ring-2 has-checked:ring-primary`.

## toggle
Binary on/off switch whose effect is immediate (a setting), unlike a checkbox that is submitted with the form. Requires JS (a Stimulus controller in Rails) to flip state and persist it.

### Variants
| Variant | When to use |
|---------|-------------|
| with label and description | Settings rows (canonical below). |
| bare | Inside a table row or card where context labels it; keep an `sr-only` label. |
| short | Dense UIs: `h-5 w-10` track with a `size-4` knob. |

### Contract
- Axes: size (default `h-6 w-11` | short `h-5 w-10`); label placement (right block, left inline, or `sr-only`).
- States: off, on (`aria-checked` drives all styling), focus-visible, disabled (`disabled:opacity-50 disabled:pointer-events-none`).

### Canonical sample
```html
<div class="flex items-center justify-between gap-x-6">
  <span class="flex grow flex-col">
    <span class="text-sm/6 font-medium text-on-surface" id="digest-label">Weekly digest</span>
    <span class="text-sm text-muted" id="digest-description">One summary email every Monday morning.</span>
  </span>
  <button type="button" role="switch" aria-checked="false" aria-labelledby="digest-label" aria-describedby="digest-description" class="group relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent bg-muted-surface transition-colors duration-200 ease-in-out aria-checked:bg-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:opacity-50 disabled:pointer-events-none">
    <span class="pointer-events-none relative inline-block size-5 transform rounded-full bg-surface shadow ring-1 ring-border transition duration-200 ease-in-out group-aria-checked:translate-x-5"></span>
  </button>
</div>
```

### Key patterns
- The control is a `<button role="switch">`; `aria-checked` is the single source of truth, styled with `aria-checked:bg-primary` on the track and `group` + `group-aria-checked:translate-x-5` on the knob - flipping one attribute animates everything.
- Track geometry: `h-6 w-11 rounded-full border-2 border-transparent`; the transparent border keeps the knob inset without extra math. Knob: `size-5 rounded-full bg-surface shadow ring-1 ring-border` - the hairline ring separates it from the subtle `bg-muted-surface` off-track.
- `transition-colors duration-200 ease-in-out` on the track and `transition duration-200 ease-in-out` on the knob give the slide.
- `shrink-0` on the button and `grow` on the label block keep the switch pinned right in settings rows.
- Wire `aria-labelledby`/`aria-describedby` to the visible label block; a bare toggle carries `<span class="sr-only">` inside the button instead.
- If the value must submit with a form rather than persist immediately, use a checkbox styled as a switch (`sr-only peer` input, track and knob as siblings driven by `peer-checked:`) - the button-based switch does not post.

## form-group
The wrapper that binds one control to its label, help text, and error message. Every input, textarea, and select in a form renders inside one; it owns vertical rhythm and error wiring.

### Variants
| Variant | When to use |
|---------|-------------|
| default | Label + control. |
| with help text | Guidance shown below the control. |
| with error | Invalid state after server validation (canonical below). |
| with corner hint | A right-aligned hint ("Optional", character limit) beside the label. |

### Contract
- Axes: descriptor (none | help | error | corner hint) - error replaces help, never both at once.
- States: valid, invalid. Invalid means all three together: `aria-invalid="true"` on the control, the error `<p>` rendered with an id, and that id listed in `aria-describedby`. Control-level states (focus, disabled) belong to the control entries.

### Canonical sample
```html
<div>
  <div class="flex justify-between">
    <label for="email" class="block text-sm/6 font-medium text-on-surface">Email</label>
    <span class="text-sm/6 text-muted" id="email-hint">Required</span>
  </div>
  <div class="mt-2">
    <input id="email" name="email" type="email" aria-invalid="true" aria-describedby="email-error email-hint" class="block w-full rounded-md bg-surface px-3 py-1.5 text-base text-on-surface outline-1 -outline-offset-1 outline-border placeholder:text-muted aria-invalid:outline-danger focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-primary focus-visible:aria-invalid:outline-danger disabled:cursor-not-allowed disabled:opacity-50 sm:text-sm/6">
  </div>
  <p class="mt-2 text-sm text-danger" id="email-error">Enter a valid email address.</p>
</div>
```

### Key patterns
- Rhythm is `mt-2` twice: label to control, control to help or error text. Between form-groups, the parent form uses `space-y-6` (or a grid) - the group itself adds no outer margin.
- `aria-invalid:outline-danger` (plus `focus-visible:aria-invalid:outline-danger`) is baked into the base control classes, so error styling is driven entirely by the `aria-invalid` attribute the server sets when the record has errors on that attribute - no class swapping in views.
- Help text is `mt-2 text-sm text-muted`; the error is `mt-2 text-sm text-danger` and replaces the help text while keeping its own id.
- `aria-describedby` lists every visible descriptor id for the control, error first.
- Corner hint: wrap label and hint in `flex justify-between`; the hint is `text-sm/6 text-muted` and its id also joins `aria-describedby`.
- For checkbox, radio, and toggle, the group role is played by their `<fieldset>`/row structures from those entries; this wrapper is for text-like controls.
