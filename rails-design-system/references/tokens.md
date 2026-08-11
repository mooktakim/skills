# <section>/tokens.md - generation guide

Read this immediately before writing a section's `tokens.md`. This file is the section's source of truth for every design value; the Tailwind v4 `@theme` block is its compiled form and the two must agree. Derive tokens from the utilities the section's views actually use - collect them, count occurrences, canonicalise by frequency (accessibility-passing values win over frequent ones; state which rule decided each call). Record every collapsed value in the section's divergences ledger - never drop one silently.

## Questions to answer from the code

- **Colour roles**: which concrete values back `surface`, `muted-surface`, `on-surface`, `muted`, `border`, `primary`, `primary-hover`, `on-primary`, and the status roles (`danger`, `success`, `warning`) in this section? Check contrast for every on-role pairing and note the ratio where it matters.
- **Type scale**: which text steps are canonical (usually 4-6 of them, with line-height, e.g. `text-sm/6`), and what is body default?
- **Spacing**: which gap/padding steps recur - the rhythm, not every value ever used.
- **Radius**: one default (`rounded-md`?), one for cards/overlays, one for pills. Three steps is usually the whole scale.
- **Shadow**: which elevations exist and what each means (e.g. `shadow-xs` on controls, `shadow-lg` only on overlays).
- **Motion**: transition duration/easing if the section has a convention; omit the dimension if it does not.
- **Dark mode**: does the section re-map roles in dark? If not, say so in one line.

## Compilation

Close the file with the single `@theme` block the app's Tailwind entry CSS must contain for this section's roles:

```css
@theme {
  --color-surface: oklch(1 0 0);
  --color-on-surface: oklch(0.21 0.03 264);
  --color-primary: oklch(0.55 0.22 263);
  /* ...one line per role... */
}
```

The doc's tables are the source; the `@theme` block is the compiled form; a change to one is a change to both, in the same commit. Values live ONLY here - specs and views refer to roles.

## Target shape (fictional excerpt - copy the density, never the content)

```markdown
# admin - Tokens

Tailwind v4. Roles compile to the `@theme` block below; views use role
utilities only (`bg-surface`, `text-muted`), never palette classes.

## Colour
| Role | Value | Notes |
|------|-------|-------|
| surface | white | page and card background |
| on-surface | oklch(0.21 0.03 264) | body text (contrast 15.8:1) |
| primary | oklch(0.55 0.22 263) | one main action per screen |

## Type
| Step | Usage |
|------|-------|
| text-sm/6 | body default |
| text-base/7 | section titles |

## Adding a token
Extend the role set here and recompile the @theme block - never inline a
value in a view. A value used once is a divergence, not a token.
```
