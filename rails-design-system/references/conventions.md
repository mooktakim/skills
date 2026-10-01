# docs/design-system/conventions.md - generation guide

Read this immediately before writing or editing `conventions.md`. It holds the consistency rules that apply to every section, under every sharing model: how things are worded, formatted, and represented, never how they are styled. Tokens, recipes, and markup stay in each section; this file couples no code, so it does not break islands. It exists because a rule like "status badges never show a dot" is otherwise fixed one section at a time, and the next section breaks it again.

## Questions to answer from the code

- **Text case**: button labels, headings, table headers, navigation, badges - Title Case or Sentence case? Find the dominant form per element; a mix is a finding, not a rule.
- **States**: each domain state the UI shows (draft, live, closed, failed...) - which component represents it (`badge`?) and which tone (`success`, `warning`...), with any shape rule ("no dot", "no icon"). One state, one representation, everywhere.
- **Formats**: money (symbol or code, decimals, placement), dates and times (relative or absolute, which format, which zone), numbers (separators, units). Name the helper that produces each one, if the app has it.
- **Icons**: the one icon set in use, the standard sizes, and when an icon accompanies a label.
- **Actions**: one primary action per view; how destructive actions are worded and confirmed.
- **Empty and error states**: what an empty collection says (always names the next action?), how form errors are summarised.

Record only rules the app's views already follow or that I state. Never invent a convention to fill a heading; omit a heading with nothing to say.

## Target shape (fictional excerpt - copy the density, never the content)

```markdown
# Conventions

Rules every section follows. Styling lives in each section's specs; these
rules govern wording, formats, and how states are shown. When a rule is meant
for every page, it goes here, and every section is fixed in the same change.

## Text case
- Buttons and badges: Title Case ("Save Draft"). Headings: Sentence case.

## States
| State | Component | Tone | Shape |
|-------|-----------|------|-------|
| draft | `badge` | `muted` | no dot |
| live | `badge` | `success` | no dot |
| failed | `badge` | `danger` | no dot |

## Formats
- Money: `format_money` helper - symbol before the amount, two decimals.
- Dates: absolute in tables (`12 Mar 2026`), relative in activity feeds.

## Actions
- One primary button per view. Destructive actions say what they destroy
  ("Delete Invoice") and always confirm.
```
