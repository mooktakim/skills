# Phlex adapter - realising specs as Phlex components

Read this when the Gemfile includes `phlex-rails` and a spec needs realising, or when writing a spec's "Realized as" guidance. The unit of realisation is a Phlex class; the contract's axes become keyword arguments.

## Rules

- One class per component, inside the section's namespace: `app/components/admin/button.rb` (or wherever the app already keeps Phlex classes - match its structure, never introduce a second one). Sections never render another section's components - the namespace is the boundary.
- Axes are kwargs with defaults, resolved against frozen hashes with `fetch` so an off-contract value raises.
- The recipe's classes live in frozen constants: `BASE` plus one hash per axis. Callers pass axes only, never classes.
- Anatomy parts that accept caller markup become block parameters or dedicated methods; keep the public surface to what the spec's anatomy names.
- States: disabled/loading are kwargs adding contract classes and attributes; hover and focus-visible stay in the class strings.
- Patterns realise as page components composing the section's components; only an app shell earns a layout component.
- Link class to spec with a one-line comment; add the class path to the spec's "Realized as" line in the same commit.

## Worked example: button

```ruby
# app/components/admin/button.rb
# spec: docs/design-system/admin/components/button.md
class Admin::Button < Phlex::HTML
  BASE = "inline-flex items-center gap-x-1.5 rounded-md font-semibold shadow-xs " \
         "focus-visible:outline-2 focus-visible:outline-offset-2 " \
         "focus-visible:outline-primary disabled:opacity-50 disabled:pointer-events-none"
  VARIANTS = {
    primary:   "bg-primary text-on-primary hover:bg-primary-hover",
    secondary: "bg-surface text-on-surface ring-1 ring-inset ring-border hover:bg-muted-surface",
    danger:    "bg-danger text-on-danger hover:bg-danger-hover",
  }.freeze
  SIZES = { sm: "px-2 py-1 text-sm", md: "px-3 py-2 text-sm" }.freeze

  def initialize(variant: :primary, size: :md, type: "button", disabled: false)
    @variant = variant
    @size = size
    @type = type
    @disabled = disabled
  end

  def view_template(&block)
    button(
      type: @type,
      disabled: @disabled,
      class: [BASE, VARIANTS.fetch(@variant), SIZES.fetch(@size)],
      &block
    )
  end
end
```

Call site: `render Admin::Button.new(variant: :danger) { "Delete" }`. A call site needing its own class string means the contract is missing an axis - extend the spec first.
