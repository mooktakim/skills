---
id: project-memory-status
type: decision
status: proposed
summary: project-memory plugin (0.4.0, 2026-10-15) - replaced the global project history log; user decisions on migration, Rust command, opt-in CI
created: 2026-10-14
sources: [auto memory project-memory-status.md]
---

`project-memory` plugin built 2026-10-14/15 from the user's MEMORY.md protocol doc; it replaced the global "Project History Log" instructions (config_files commit 0e1974b removed claude/project-history-log.md).

User decisions:
- Name `project-memory`. CLAUDE.md canonical, AGENTS.md symlink ([[claude-md-canonical-agents-md-symlink]]). One log file per unit of work, not per session.
- No migration script: the user wants Claude to read each project's old log and decide the mapping (projects logged differently); no-loss is enforced by checks in SKILL.md.
- The `project-memory` command is Rust (user wanted speed: 0.09 s vs Ruby 0.32 s on a big project), on PATH through the plugin; not a toolsmith command (one job per tool rule).
- CI is opt-in per project, through the composite action `mooktakim/skills/project-memory@<sha>` (cached build). Committed binaries and a cross-platform binary were rejected.

The skills repo is private (2026-10-15); its project-type auto memories were copied into docs/inbox/ as proposals. config_files itself still has a legacy docs/history log.

**Why:** next sessions should not re-argue these choices.
**How to apply:** check the source first; skill and protocol live in project-memory/.
