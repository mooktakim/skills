# Form page

The new/edit archetype: an error summary, titled form sections on a shared field grid, and one actions row with cancel and a single primary submit.

## Purpose

Collect or edit a record's attributes in logically grouped sections, with validation errors surfaced both in summary and at the field. Every Rails `new`/`edit` view is a variant of this page; both render the same form partial.

## Composition

1. `page-heading` - "New \<resource\>" or the record title; no action buttons (the submit lives in the actions row, nowhere else).
2. Error summary - a danger `alert` listing model errors, rendered above the first section only when validation failed; each entry names the field.
3. Form sections - one `<div>` per logical group, each with a section title and muted description, then a field grid of `form-group`s (`input`, `select`, `textarea`, `checkbox`, `radio`, `toggle`). Sections separate with a bottom hairline.
4. Actions row - right-aligned: a plain-link cancel `button` back to index or show, then exactly one primary submit `button`. A destructive action (Delete) is a separate form, left-aligned in the same row.

## Layout skeleton

```html
<div class="mx-auto max-w-3xl px-4 py-8 sm:px-6 lg:px-8">
  <!-- component: page-heading -->

  <div class="mt-6">
    <!-- component: alert (danger error summary; only when errors present) -->
  </div>

  <form class="mt-8">
    <div class="space-y-12">
      <div class="border-b border-border pb-12">
        <!-- section title (text-base/7 font-semibold) + muted description -->
        <div class="mt-10 grid grid-cols-1 gap-x-6 gap-y-8 sm:grid-cols-6">
          <div class="sm:col-span-4">
            <!-- component: form-group (label + input + help/error text) -->
          </div>
          <div class="sm:col-span-3">
            <!-- component: form-group -->
          </div>
          <div class="col-span-full">
            <!-- component: form-group (textarea, full-width control) -->
          </div>
        </div>
      </div>
      <!-- repeat section div; the last section drops border-b -->
    </div>

    <div class="mt-6 flex items-center justify-end gap-x-6">
      <!-- component: button (plain link style, "Cancel") -->
      <!-- component: button (primary, submit) -->
    </div>
  </form>
</div>
```

## Variants

| Variant | When to use |
|---------|-------------|
| Single column (above, `max-w-3xl`) | Default for create/edit forms; keeps line lengths readable |
| Two column (`md:grid md:grid-cols-3 md:gap-6`: title `md:col-span-1`, grid `md:col-span-2`, in `max-w-7xl`) | Settings pages with many sections; titles sit beside their fields |
| Sections as cards | Each section wrapped in a `card` on a `bg-muted-surface` page; drop the hairlines |
| Sticky actions bar (`sticky bottom-0 border-t border-border bg-surface px-4 py-4`) | Long forms where the submit would scroll far out of view; otherwise keep actions inline |

## Key patterns

- `mx-auto max-w-3xl` - forms use a narrower container than index/detail pages; controls should not stretch to 80-character widths.
- `space-y-12` on the section stack with `border-b border-border pb-12` per section - the hairline plus large gap is the section separator; no `<hr>`.
- `grid grid-cols-1 gap-x-6 gap-y-8 sm:grid-cols-6` - the shared field grid: every field stacks on mobile and takes `sm:col-span-N` (3 = half, 4 = medium, 2 = short code/date, `col-span-full` = full width) at `sm+`.
- `mt-6 flex items-center justify-end gap-x-6` - the actions row: cancel as a plain link button, one primary submit last.
- Field-level errors live in the `form-group` (danger border and message); the summary `alert` and the field messages appear together, not one or the other.
- Disable the submit and show its loading state while the form submits; never render two primary buttons.
