# rails-design-system 0.2.0: fixes from first real run (dinehere)

- First end-to-end run on dinehere surfaced two gaps; both fixed.
- Multi-section token prefixing now specified: all sections share one Tailwind entry CSS, so with several sections each prefixes its roles (`bg-admin-primary`); at most one section keeps bare names; prefix assignment is proposed in the Phase 1 plan. Codifies what the dinehere run improvised (marketing bare, `app-*`, `admin-*`). Touched: SKILL.md doctrine, references/tokens.md, references/component-spec.md, catalog/README.md.
- bin/audit_design now exempts mailer views (`_mailer/`, `layouts/mailer*`) - email clients require inline styles; on dinehere 318 of 413 hex findings were mailer noise that would re-flag every run.
- Run quality otherwise good: specs role-tokenized and shaped correctly, previews linked to compiled CSS with correct relative paths, anti-pattern prose correctly cites literal classes (allowed), ledger carries the var(--color-*) backlog (~1,125 items).
