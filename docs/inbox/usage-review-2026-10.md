---
id: usage-review-2026-10
type: decision
status: proposed
summary: 2026-10-01 field review of all 3 plugins across 7 Rails projects - verdicts, top defects, report link
created: 2026-10-01
sources: [auto memory usage-review-2026-10.md]
---

On 2026-10-01 a usage review of transcripts and prompt history found: rails-context and rails-design-system "partly work"; rails-reviewer found 12 real bugs in 2 runs but no specialist was ever auto-delegated. Report: https://claude.ai/artifact/B6DQVPwp9WisR7fZqKhnf5

All 21 defects from the review were fixed on 2026-10-01 (rails-context 0.10.2, rails-design-system 0.9.1, rails-specialists 0.2.1): hook path/silent pass/Bash writes (Stop hook), changed-lines checks, hard approval gate, KB size limits + root budget, weekly SessionStart maintenance nudge, proactive delegation hook, regex false positives, sharing models (islands/shared foundation/external library + vendor-paths), conventions.md + app-shell frames, reviewed marker/deleted files/candidate dirs, loading model, Phase 3 smoke test, gem re-lock, gitignore check, small agent fixes, no em dashes.

Built after: design-reviewer agent (0.10.0), promote-to-audit rules (0.11.0), plugin-shipped hooks + CI --strict/--changed (0.12.0); both audit scripts rewritten in Ruby stdlib 2.6+ as scripts/ files + Minitest suite bin/test (design 0.13.0, context 0.11.0). Also built: repo CI (.github/workflows/test.yml, Linux 2.6/3.3/4.0 + macOS system Ruby/bash 3.2), section-scoped audit-rules (design 0.14.0), new `capture` plugin 0.1.0 (record stated rules/corrections; hint hook tuned to 1.5% of real prompts). Also: context reach log + report (context 0.12.0; .git/claude-context-log.jsonl). Not done: A/B evals (user said ignore for now), path-scoped .claude/rules (decide from reach data after the maynard run), cutting the specialist roster. Real projects still run old scripts until a maintenance run in each; several text-only changes (gate, conventions, gem rule) are untested until a real run.

**Why:** these findings drive the next versions of all three plugins.
**How to apply:** check whether a defect is already fixed in the source before acting on it. Related: [[rails-design-system-status]], [[rails-specialists-status]].
