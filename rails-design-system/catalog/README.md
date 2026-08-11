# Catalog - curated component and pattern reference

Raw material for speccing a section's components and patterns. Every sample here is written against the role-token vocabulary below, not any concrete palette, so it can be dropped into any section and inherit that section's theme. When speccing a component for a target app, adapt the relevant entry to the section's tokens and the app's real markup - never paste an entry unadapted, and never spec a component the section does not use.

## Role-token vocabulary

All colour classes in catalog samples use these roles. A target app defines them in each section's `tokens.md` (compiled to a Tailwind v4 `@theme` block); the catalog never assumes what they resolve to.

| Role | Utility examples | Used for |
|------|------------------|----------|
| `surface` | `bg-surface` | Page and card backgrounds |
| `muted-surface` | `bg-muted-surface` | Subtle fills: table headers, wells, hover rows |
| `on-surface` | `text-on-surface` | Primary text on surface |
| `muted` | `text-muted` | Secondary text, placeholders, icons |
| `border` | `border-border`, `ring-border`, `divide-border` | Hairlines, input borders, dividers |
| `primary` | `bg-primary`, `text-primary` | Brand actions, active states, links |
| `primary-hover` | `hover:bg-primary-hover` | Hover shade of primary |
| `on-primary` | `text-on-primary` | Text/icons on primary fills |
| `danger` | `bg-danger`, `text-danger` | Destructive actions, errors |
| `danger-hover` | `hover:bg-danger-hover` | Hover shade of danger |
| `on-danger` | `text-on-danger` | Text/icons on danger fills |
| `success` | `text-success`, `bg-success` | Positive status |
| `warning` | `text-warning`, `bg-warning` | Cautionary status |

Rules that make the catalog usable:

- Colour comes only from roles. No raw hex, no named palette classes (`bg-indigo-600`, `text-gray-900`), no `[...]` arbitrary values, anywhere in a sample.
- Samples use bare role names. A section whose tokens carry a prefix (`admin-*`) gets the prefix applied during adaptation: `bg-primary` becomes `bg-admin-primary`.
- Non-colour utilities (type, spacing, radius, shadow) use the standard Tailwind scale (`text-sm/6`, `px-3 py-2`, `rounded-md`, `shadow-xs`). A section's `tokens.md` declares which steps are canonical for that section; adapt samples to those steps when speccing.
- No dark-mode variants in samples: dark theming is a section-level remap of the roles, not per-component classes.
- Interactive samples always carry `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary` and a disabled treatment. A component without its states is not done.

## Entry shape

Every catalog entry follows this fixed shape, 35-50 lines:

```markdown
## <component>
One or two sentences: what it is for.

### Variants
| Variant | When to use |

### Contract
- Axes: the allowed values per axis (variant, size, tone...).
- States: default, hover, focus-visible, active, disabled, loading (where it submits).

### Canonical sample
One HTML block, role tokens only.

### Key patterns
The idiomatic utilities and structures that make it work, as bullets.
```

## Map

| Component / pattern | File |
|---------------------|------|
| button, button-group | `components/buttons.md` |
| input, textarea, select, checkbox, radio, toggle, form-group | `components/form-controls.md` |
| card, badge, avatar, description-list, stat | `components/data-display.md` |
| table, stacked-list, pagination | `components/collections.md` |
| alert, empty-state, notification | `components/feedback.md` |
| navbar, sidebar-nav, tabs, breadcrumb, page-heading | `components/navigation.md` |
| modal, drawer, dropdown | `components/overlays.md` |
| sidebar shell, stacked shell, minimal shell | `patterns/app-shells.md` |
| index page (heading + filters + collection + pagination) | `patterns/index-page.md` |
| detail page (heading + description-list + related sections) | `patterns/detail-page.md` |
| form page (sections, actions bar, error summary) | `patterns/form-page.md` |

A component with no catalog entry is not a gap in the target app: derive its spec from the app's own markup instead.
