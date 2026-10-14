# Re-runnable maintenance mode, /context-audit removed (0.6.0)

Driven by the first real test run on dinehere (Aug 7), which exposed three issues; user directed folding in findings 1+2 and proposed killing the second command.

- Phase 1 gap-fill paragraph → "Re-runs: maintenance mode" subsection: re-run proposes gap-fill, drift review (run bin/audit_context, surgical edits or "checked, still accurate" per flagged file), one-fact-one-level repair (ancestors shed facts deeper files own — resolves the conflict between "keep existing untouched" and the shed rule), and size repair.
- Phase 2: creating a file whose facts an ancestor states ⇒ slim ancestor in same commit; shed-edits are exempt from the no-regenerate rule but must be in the plan.
- Phase 3: .claude/commands/context-audit.md no longer created (re-running the skill IS the audit; leftover copies get a delete proposal in maintenance mode). Root template block gains audit_context + periodic-maintenance sentence.
- Phase 4: reviews generated OR edited files; every run closes with bin/audit_context + report of leftovers.
- Rationale for dropping the command: bin/audit_context + root maintenance section stay in the target repo, so plugin-less agents keep the signal.
- Known limitation (unfixed): audit script is git-date based, so "checked, still accurate" files stay flagged forever — flagged to user, not engineered around.
- dinehere run itself still uncommitted in that repo (finding 3) — user's to finish.
