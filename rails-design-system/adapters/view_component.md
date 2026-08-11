# ViewComponent adapter - realising specs as components

Read this when the Gemfile includes `view_component` and a spec needs realising, or when writing a spec's "Realized as" guidance. The unit of realisation is a component class with a sidecar template; the contract's axes become keyword arguments.

## Rules

- One class per component, inside the section's namespace: `app/components/admin/button_component.rb` + `button_component.html.erb`. Sections never render another section's components - the namespace is the boundary.
- Axes are kwargs with defaults, validated in the initializer against the contract's closed lists (`fetch` on a frozen hash raises on an off-contract value - keep that loudness).
- The recipe's classes live in frozen constants: `BASE` for the shared string, one hash per axis for the deltas. The template interpolates them; call sites pass axes only, never classes.
- Anatomy parts that accept caller markup become slots (`renders_one :icon`); don't add slots the spec's anatomy doesn't name.
- States: disabled/loading are kwargs that add contract classes and attributes (`disabled`, `aria-busy`); hover and focus-visible stay in the class strings.
- Patterns realise as templates composing components; only an app shell earns its own component.
- Link component to spec with a one-line comment; add the class path to the spec's "Realized as" line in the same commit.

## Worked example: button

```ruby
# app/components/admin/button_component.rb
# spec: docs/design-system/admin/components/button.md
class Admin::ButtonComponent < ViewComponent::Base
  BASE = "inline-flex items-center gap-x-1.5 rounded-md font-semibold shadow-xs
          focus-visible:outline-2 focus-visible:outline-offset-2
          focus-visible:outline-primary disabled:opacity-50
          disabled:pointer-events-none".squish.freeze
  VARIANTS = {
    primary:   "bg-primary text-on-primary hover:bg-primary-hover",
    secondary: "bg-surface text-on-surface ring-1 ring-inset ring-border hover:bg-muted-surface",
    danger:    "bg-danger text-on-danger hover:bg-danger-hover",
  }.freeze
  SIZES = { sm: "px-2 py-1 text-sm", md: "px-3 py-2 text-sm" }.freeze

  def initialize(variant: :primary, size: :md, type: "button", disabled: false)
    @classes = [BASE, VARIANTS.fetch(variant), SIZES.fetch(size)].join(" ")
    @type = type
    @disabled = disabled
  end
end
```

```erb
<%# app/components/admin/button_component.html.erb %>
<button type="<%= @type %>" class="<%= @classes %>" <%= "disabled" if @disabled %>>
  <%= content %>
</button>
```

Call site: `<%= render Admin::ButtonComponent.new(variant: :danger) { "Delete" } %>`. A call site needing its own class string means the contract is missing an axis - extend the spec first.
