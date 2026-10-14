# Nested context files guidance (0.4.0)

- Phase 1 step 4: second nesting criterion — deep domain knowledge that would bloat the parent (external-provider wrappers like app/services/cloudflare/, subsystems like app/models/billing/).
- New Phase 2 subsection 'Nested context files': delta-only (agents load the full chain, never repeat ancestors), 10-60 lines, content = what code can't show (auth, rate limits, env differences, invariants, failure modes); symlink + audit apply as usual.
- references/services.md: provider-namespace question added, pointing specifics to the nested file.
