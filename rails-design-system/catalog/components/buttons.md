# Buttons

Action elements: the single button and the segmented button-group. Entries follow the catalog entry shape and use role tokens only.

## button
The single action element for forms, toolbars, and page headings. Renders as `<button>` with an explicit `type`; an `<a>` may carry the same classes when a navigation link must look like an action.

### Variants
| Variant | When to use |
|---------|-------------|
| primary | The one main action of a view or form. At most one per context. |
| secondary | Supporting actions beside a primary; the default for everything else. |
| danger | Destructive actions: delete, revoke, remove. |
| text | Low-emphasis inline actions; no fill, no shadow, no padding box. |
| icon | Icon-only circular action; must have a visually hidden label. |

### Contract
- Axes: variant (primary | secondary | danger | text | icon); size (xs | sm | md | lg | xl); optional leading or trailing icon.
- States: default, hover, focus-visible, active, disabled (`disabled:opacity-50 disabled:pointer-events-none`), loading where the button submits (disable it and swap the leading icon for a spinner; keep the label visible).
- Cursor: the pointer on hover comes from the app's base rule (`button`, `a[href]`, `[role="button"]`), so the classes never repeat `cursor-pointer`; a disabled button shows no pointer.

### Canonical sample
Primary, md size, leading icon:

```html
<button type="submit" class="inline-flex items-center gap-x-1.5 rounded-md bg-primary px-2.5 py-1.5 text-sm font-semibold text-on-primary shadow-xs hover:bg-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:opacity-50 disabled:pointer-events-none">
  <svg class="-ml-0.5 size-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
    <path fill-rule="evenodd" d="M16.7 4.15a.75.75 0 0 1 .14 1.05l-8 10.5a.75.75 0 0 1-1.12.08l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.9 3.89 7.48-9.82a.75.75 0 0 1 1.04-.14Z" clip-rule="evenodd"/>
  </svg>
  Save changes
</button>
```

### Key patterns
- Size ladder (padding, type, radius): xs `rounded px-2 py-1 text-xs`; sm `rounded px-2 py-1 text-sm`; md `rounded-md px-2.5 py-1.5 text-sm`; lg `rounded-md px-3 py-2 text-sm`; xl `rounded-md px-3.5 py-2.5 text-sm`. Every size uses `font-semibold`.
- Variant deltas from the canonical classes: secondary `bg-surface text-on-surface ring-1 ring-inset ring-border hover:bg-muted-surface` (keeps `shadow-xs`); danger `bg-danger text-on-danger hover:bg-danger-hover`; text drops fill, shadow, and padding entirely - `text-sm font-semibold text-primary hover:text-primary-hover`; icon `rounded-full p-1` (or `p-1.5` for a larger hit area) around a `size-5` icon plus `<span class="sr-only">` naming the action.
- `inline-flex items-center gap-x-1.5` aligns label and icon; `-ml-0.5` on a leading icon and `-mr-0.5` on a trailing icon optically correct the icon against the padding box.
- `shadow-xs` belongs on filled and secondary variants only, never on text buttons.
- Icons are `fill="currentColor"` with `aria-hidden="true"`, so they inherit the variant's text role automatically.

## button-group
A segmented row of related buttons sharing one continuous border, for switching between peer options (view modes, time ranges) or grouping a split action with its menu trigger.

### Variants
| Variant | When to use |
|---------|-------------|
| default | Two or more equal text segments. |
| with selected segment | One segment reflects the current choice; mark it `aria-pressed="true"`. |
| icon segments | Icon-only segments, e.g. previous/next paging; each needs an `sr-only` label. |
| split action | A primary segment plus a chevron menu-trigger segment sharing the border. |

### Contract
- Axes: segment count (2 or more); segment content (text | icon); at most one selected segment.
- States per segment: default, hover, focus-visible (the focused segment must rise above its neighbours), selected (`bg-muted-surface` + `aria-pressed="true"`), disabled (`disabled:opacity-50 disabled:pointer-events-none`).
- Semantics: an exclusive choice is a set of `aria-pressed` toggle buttons; do not fake a tab list or a radio group with plain buttons.

### Canonical sample
```html
<span class="isolate inline-flex rounded-md shadow-xs">
  <button type="button" class="relative inline-flex items-center rounded-l-md bg-surface px-3 py-2 text-sm font-semibold text-on-surface ring-1 ring-inset ring-border hover:bg-muted-surface focus-visible:z-10 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:opacity-50 disabled:pointer-events-none">Years</button>
  <button type="button" class="relative -ml-px inline-flex items-center bg-surface px-3 py-2 text-sm font-semibold text-on-surface ring-1 ring-inset ring-border hover:bg-muted-surface focus-visible:z-10 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:opacity-50 disabled:pointer-events-none">Months</button>
  <button type="button" class="relative -ml-px inline-flex items-center rounded-r-md bg-surface px-3 py-2 text-sm font-semibold text-on-surface ring-1 ring-inset ring-border hover:bg-muted-surface focus-visible:z-10 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:opacity-50 disabled:pointer-events-none">Days</button>
</span>
```

### Key patterns
- `isolate` on the wrapper creates a stacking context, so `focus-visible:z-10` can lift the focused segment's outline above adjacent segments without leaking z-index into the page.
- `-ml-px` on every segment after the first overlaps the 1px rings into a single shared hairline.
- Rounding lives only on the outer corners: `rounded-l-md` on the first segment, `rounded-r-md` on the last, none in between; `rounded-md shadow-xs` sit on the wrapper.
- Segments are styled as secondary buttons (`bg-surface ring-1 ring-inset ring-border hover:bg-muted-surface`); the selected segment swaps its fill to `bg-muted-surface`.
- Each segment stays `relative` so ring overlap and z-index ordering behave predictably.
- Icon segments tighten padding to `px-2 py-2` around a `size-5` icon (`fill="currentColor"`, `aria-hidden="true"`) and carry `<span class="sr-only">` naming the action.
- Disabled segments keep their ring so the group's shared border stays continuous.
- Segment labels stay short (one word or a tight pair); the group never wraps to a second line.
- Split action: the first segment is a full button (often primary classes); the trigger segment is icon-only with a chevron and owns the dropdown wiring.
