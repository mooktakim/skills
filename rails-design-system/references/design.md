# <section>/design.md - generation guide

Read this immediately before writing a section's `design.md`. This file carries the section's aesthetic direction - the judgment calls tokens and specs are too mechanical to hold. Derive it from the section's existing views; where the section has no views yet, interview the user. Never invent a design language the app does not imply.

## Questions to answer from the code (or the user)

- **Audience and job**: who uses this section and for what - the one-line brief every visual decision serves.
- **Density**: data-dense (tight spacing, small type, tables everywhere) or roomy (generous whitespace, large type)? Point at the evidence.
- **Tone**: how loud is colour? Is `primary` everywhere or reserved for the single main action per screen?
- **Depth**: flat borders or shadows-and-elevation? Which of the two does the section actually use?
- **Voice of chrome**: what does the persistent frame (nav, headers) look like relative to content - quiet or branded?
- **Do and don't**: the 3-6 concrete rules an agent would otherwise get wrong here, each one section-specific ("tables over card grids for collections", "no marketing gradients in admin").
- **Independence**: state that this section imports nothing from other sections - name them.

## Target shape (fictional excerpt - copy the density, never the content)

```markdown
# admin - Design

## Purpose & audience
Internal operators working through queues all day. Efficiency over delight;
every screen answers "what needs my action next".

## Aesthetic direction
Data-dense and quiet. Tight vertical rhythm, `text-sm` body, tables as the
default collection view. Colour is reserved: `primary` appears once per
screen on the main action; status communicates through badge tones, not
backgrounds. Flat depth - hairline `border` dividers, shadows only on
overlays.

## Do & don't
- Do: one primary button per view; everything else is the secondary variant.
- Do: empty states always name the next action.
- Don't: hero sections, gradients, or marketing type scale - this is a tool.

## Independence
Imports nothing from `marketing/`. A shared look with it is coincidence,
never a dependency.
```
