# ERB adapter - realising specs as partials

Read this when the app renders views with plain ERB (no Phlex, no ViewComponent) and a spec needs realising, or when writing a spec's "Realized as" guidance. The unit of realisation is a partial with strict locals; the contract's axes become the locals.

## Rules

- One partial per component, inside the section's namespace: `app/views/admin/shared/_button.html.erb`. Sections never render another section's partials - the path is the boundary.
- Declare strict locals with defaults for every axis: `<%# locals: (label:, variant: :primary, size: :md, href: nil) %>`. An axis value outside the contract should fail loudly - `fetch` from a hash raises, so use hashes, not `case` with a silent else.
- Class strings live in the partial as frozen hashes keyed by axis value - the recipe's classes verbatim, base classes in one string, axis deltas in the hashes. Never rebuild classes at call sites; call sites pass axes only.
- The pattern tier realises as regular templates that render component partials - a pattern partial is rarely needed.
- Put a one-line comment linking back to the spec at the top of the partial; add the partial's path to the spec's "Realized as" line in the same commit.

## Worked example: button

```erb
<%# locals: (label:, variant: :primary, size: :md, type: "button") %>
<%# spec: docs/design-system/admin/components/button.md %>
<%
  base = "inline-flex items-center gap-x-1.5 rounded-md font-semibold shadow-xs
          focus-visible:outline-2 focus-visible:outline-offset-2
          focus-visible:outline-primary disabled:opacity-50
          disabled:pointer-events-none".squish
  variants = {
    primary:   "bg-primary text-on-primary hover:bg-primary-hover",
    secondary: "bg-surface text-on-surface ring-1 ring-inset ring-border hover:bg-muted-surface",
    danger:    "bg-danger text-on-danger hover:bg-danger-hover",
  }.freeze
  sizes = { sm: "px-2 py-1 text-sm", md: "px-3 py-2 text-sm" }.freeze
%>
<button type="<%= type %>"
        class="<%= base %> <%= variants.fetch(variant) %> <%= sizes.fetch(size) %>">
  <%= label %>
</button>
```

Call site: `<%= render "admin/shared/button", label: "Save", variant: :primary %>`. The call site never carries a class string; if it needs one, the contract is missing an axis - extend the spec first.
