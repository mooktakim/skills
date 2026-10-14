---
id: usage-review-2026-10-12
type: decision
status: proposed
summary: Second field review (all 9 plugins, 89 sessions since 2026-10-01) - findings, what was fixed same day, what was left and why
created: 2026-10-12
sources: [auto memory usage-review-2026-10-12.md]
---

2026-10-12 review of transcripts since 2026-10-01 (4 parallel analysis agents). Fixed the same day, all committed on main, NOT pushed at the time:
- capture 0.1.1: hint fired on 319/352 task-notifications ("each time" in boilerplate); now skips harness-tag prompts and bare "no".
- toolsmith 0.2.2-0.2.5: reminders once per session/tool, none in subagents (agent_id), tighter families; json-set edits text in place; ci-wait bare commit arg.
- rails-context 0.14.x and rails-design-system 0.16-0.17: apps in a repo subdirectory (rihlo/studio, runner/hub) - hooks were silent, git paths were repo-top relative. Design `--bash` hook mode (1,133/1,164 view edits went through Bash). Reviewer runs `--changed`; rules with path prefixes reach controllers; reach report counts only touched changes.
- All skill descriptions <= 500 chars (repo test): when over the listing budget, Claude Code drops descriptions of least-invoked skills first, so new skills were bare names and never invoked.
- view-component/hotwire/minitest/generators: first-touch PreToolUse notes (SessionStart notes missed apps built mid-session). Minitest suite runs via toolsmith-check-run.

Left on purpose: text-replace output size, pr-land method error, file-lines comma ranges (rare); Rails SessionStart notes in mixed workspaces (maynard holds Rails + Phoenix); reviewer cost on copy-only changes (user prefers quality). Not done (user config): `skillListingBudgetFraction` / name-only `skillOverrides` for unused skill packs.

**Why:** next review should start from these, not re-find them.
**How to apply:** check the source before acting; rihlo's .claude/settings.json audit_design workaround hooks become duplicates once rails-design-system 0.16+ is installed. Earlier review: [[usage-review-2026-10]].
