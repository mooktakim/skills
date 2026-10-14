# rails-design-system 0.7.1: audit regex false positives

- Review defect 10. HEX now requires the `#` not follow [0-9a-zA-Z_.&-] (Stimulus `cart#add`, JS `this.#fade`, `&#123;` entities passed as hex before); trailing class excludes `_`/`-`. Adopted from yardnote's in-project fix.
- ARB: a bracket followed by `:` or `/name:` is a variant selector (data-/aria-/has-/group-*/min-[..]:) and passes; `/digit` opacity suffix still flags. Added Tailwind v4 shorthand `bg-(--x)` - flagged like `bg-[var(--x)]` (bypasses the token utility; kept var() flagged deliberately, not treated as a false positive).
- Tested: 25-case flag/pass table with /usr/bin/grep; old vs new full scan on real projects removed 7 findings (yardnote 4, maynard 2, dinehere 1), all variant selectors or a Stimulus action; added none; no true finding lost.
