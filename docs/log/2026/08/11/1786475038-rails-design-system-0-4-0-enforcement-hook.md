# rails-design-system 0.4.0: generation-time enforcement hook

- bin/audit_design gains a --hook mode: reads Claude Code PostToolUse JSON from stdin, checks only the edited file (view paths only; mailers/token CSS exempt; fails safe on bad input), exits 2 with findings on stderr so the agent must fix immediately. Regexes hoisted into shared HEX/ARB/PAL vars used by both modes.
- Phase 3 gains step 4: wire the hook into the target app's .claude/settings.json (PostToolUse, matcher Write|Edit, command "bin/audit_design --hook"), idempotent merge. Gap-fill in maintenance mode now checks the hook wiring; root CLAUDE.md block mentions it.
- Rationale: enforcement decision from user - chose the hook layer (harness-executed, catches generated code at write time) over CI ratchet / lint cops for now. Structural (non-greppable) conformance stays with maintenance runs.
- Hook script extracted from SKILL.md and tested end-to-end in scratchpad: violation/clean/mailer/non-view/garbage-stdin paths all correct.
