---
id: project-memory
type: architecture
status: active
summary: project-memory plugin (0.4.0, 2026-10-15) - replaced the global project history log; user decisions on migration, Rust command, opt-in CI
aliases: [project memory, docs/log, inbox, MEMORY.md, history log]
created: 2026-10-14
verified_at: 2026-10-15
citations: [project-memory/src/main.rs, project-memory/action.yml, project-memory/SKILL.md]
sources: [auto memory project-memory-status.md]
---

`project-memory` plugin built 2026-10-14/15 from the user's MEMORY.md protocol doc; it replaced the global "Project History Log" instructions (config_files commit 0e1974b removed claude/project-history-log.md).

User decisions:
- Name `project-memory`. One log file per unit of work, not per session.
- Context file layout (changed 2026-10-15, project-memory 0.5.0): AGENTS.md holds the content, for every agent; CLAUDE.md is the line `@AGENTS.md` plus any Claude-only rules. It replaced the earlier CLAUDE.md-canonical + AGENTS.md-symlink layout after a headless test showed Claude Code expands the import in directory CLAUDE.md files that load later in a session.
- No migration script: the user wants Claude to read each project's old log and decide the mapping (projects logged differently); no-loss is enforced by checks in SKILL.md.
- The `project-memory` command is Rust (user wanted speed: 0.09 s vs Ruby 0.32 s on a big project), on PATH through the plugin; not a toolsmith command (one job per tool rule).
- CI is opt-in per project, through the composite action `mooktakim/skills/project-memory@<sha>` (cached build). Committed binaries and a cross-platform binary were rejected.

The skills repo is private (2026-10-15); its project-type auto memories were copied into docs/inbox/ as proposals. config_files itself still has a legacy docs/history log.

**Why:** next sessions should not re-argue these choices.
**How to apply:** check the source first; skill and protocol live in project-memory/.
