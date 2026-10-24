---
id: project-log
type: architecture
status: active
summary: project-log plugin (0.1.0, 2026-10-24) - the work log split out of project-memory as its base layer; user decisions on the split
aliases: [project log, docs/log, LOG.md, history log, work log, legacy log migration]
created: 2026-10-24
verified_at: 2026-10-24
citations: [project-log/src/main.rs, project-log/templates/LOG.md, project-log/SKILL.md, project-memory/.claude-plugin/plugin.json]
links: [architecture/project-memory.md]
---

The work log (`docs/LOG.md` protocol, `docs/log/` entries, legacy history migration) was split out of `project-memory` on 2026-10-24 into its own plugin, so a project with its own knowledge system can still keep the log.

User decisions:
- The log is the base layer; memory builds on it, never the other way. `project-memory` declares `"dependencies": ["project-log"]` in plugin.json, and `project-memory lint` fails when `docs/LOG.md` is missing.
- Every project gets the log; every project also gets memory by default, except the ones the global CLAUDE.md lists.
- `oasis-kids` keeps its own log and knowledge records: no project-log there either.
- Two crates, not a shared workspace: an installed plugin has only its own directory. `date.rs` and `scan.rs` are byte-identical copies, checked by a test.

**Why:** next sessions should not re-argue the split or merge the plugins back.
**How to apply:** log rules change in `project-log/templates/LOG.md`, memory rules in `project-memory/templates/MEMORY.md`; never restate one protocol in the other.
