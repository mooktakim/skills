# Size limit becomes a density check (0.7.0)

User challenged the 120-line hard cap: per-directory files load only in their own directory, so length is cheap and only adds local context. Agreed, with the caveat that the limit's real job is density, not token budget.

- Size discipline rewritten: 30-100 target kept; hard cap 120 dropped. Growth past 100 allowed only after a 3-point checklist (no inventory/generic Rails; no single namespace owning the growth - split to nested file instead; remainder is app-specific intent).
- 150 lines = review trigger: maintenance-mode size repair proposes restructuring (usually nested-file split), never a quality cut.
- Size-repair bullet in maintenance mode updated to match (150 trigger / 30 floor).
- Nested-file 10-60 guidance unchanged.
- README litmus-test paragraph updated.
