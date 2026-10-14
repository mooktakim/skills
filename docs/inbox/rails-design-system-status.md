---
id: rails-design-system-status
type: decision
status: proposed
summary: rails-design-system - standing constraints and user decisions to respect in every edit (as of 2026-10-01)
created: 2026-10-01
sources: [auto memory rails-design-system-status.md]
---

Hard constraint: never mention the catalog's source material (Tailwind Plus / Tailwind UI) anywhere in committed files or commit messages.

User decisions (2026-10-01) to respect:
- Keep `bin/audit_design` (deterministic, 0 tokens, hooks + CI) and the `design-reviewer` agent (judgment) as separate layers; the user chose NOT to replace the script with the agent. Recurring reviewer findings a regex can catch get promoted into `docs/design-system/audit-rules`.
- design-reviewer: code review by default, screenshots only on request; runs before commit/PR; sweep mode in maintenance runs.
- Islands is the default sharing model, but shared foundation and external library are valid choices the user makes in the Phase 1 plan; never push a project back to islands.
- Project-specific audit behaviour lives in data files (`vendor-paths`, `audit-rules`), never in edits to the copied script, so every app runs an identical script.

Pending: the first real maintenance run after the 2026-10-01 overhaul (maynard is the planned first) - it is the only test of the text-only changes (approval gate, conventions.md and frames, gem rule, settings.json cleanup, CI wiring). Related: [[usage-review-2026-10]].

**Why:** these were explicit user choices or constraints; drifting from them would undo decisions already made.
**How to apply:** check new edits against this list; when the user reports results from the maynard run, fold fixes into the skill with a version bump.
