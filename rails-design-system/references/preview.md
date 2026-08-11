# Preview pages - generation guide

Read this immediately before writing `docs/design-system/index.html` or a section's `tokens.html` / `components.html` / `patterns.html`. The preview is the human-viewable style guide: a person opens it in a browser and sees the design system as it actually renders. It must stay truthful - it uses the app's own compiled Tailwind CSS and embeds the same canonical recipes as the specs. A preview block and its spec are one fact in two files: edit them together, in the same commit.

## Rules

- Plain static HTML, no build step, no JavaScript required to view, no external CDNs. Openable via `file://`.
- Each page links the app's compiled CSS by relative path (located in Phase 1, e.g. `<link rel="stylesheet" href="../../app/assets/builds/tailwind.css">`). Never inline a copied stylesheet - a copy goes stale.
- The `@source` directive for `docs/design-system/` must be in the Tailwind entry CSS (Phase 3) so preview-only classes survive purging; without it the preview silently unstyles.
- Page chrome (the guide's own nav, headings, labels) uses the same role tokens as everything else - the style guide is itself on-system.
- Every block is labelled and links back to its spec markdown (`<a href="components/button.md">spec</a>`).

## Per page

- **`index.html`** (top level): the system's one-paragraph intro, then a card per section linking to its three pages. No design content of its own.
- **`tokens.html`**: render the tokens, don't describe them - colour swatches per role (a filled square, the role name, the value), type-scale specimens set in each step, spacing/radius/shadow samples as boxes. One region per dimension, in the order of `tokens.md`.
- **`components.html`**: one region per specced component, in spec order. Render the canonical recipe verbatim from the spec, then each variant delta applied, then the states: hover and focus-visible shown by forcing classes on a static copy (label them "forced"), disabled and loading rendered directly. Every variant in the contract appears - a variant with no preview is a gap.
- **`patterns.html`**: each pattern's layout skeleton rendered with the section's real components filling the slots and greeked placeholder content. One instance per pattern, full-width.

## Target shape (fictional excerpt - copy the density, never the content)

```html
<section id="button" class="border-b border-border pb-12">
  <div class="flex items-baseline justify-between">
    <h2 class="text-base/7 font-semibold text-on-surface">button</h2>
    <a class="text-sm text-primary" href="components/button.md">spec</a>
  </div>
  <div class="mt-6 flex flex-wrap items-center gap-4 rounded-lg bg-surface p-6 ring-1 ring-border">
    <button type="button" class="...canonical recipe classes...">Save</button>
    <button type="button" class="...secondary delta applied...">Cancel</button>
    <button type="button" disabled class="...">Disabled</button>
  </div>
</section>
```
