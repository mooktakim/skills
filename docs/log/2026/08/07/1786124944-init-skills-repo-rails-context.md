# Initialised skills repo with rails-context skill

- Repo purpose: hand-maintained collection of Claude Code skills for Rails; each skill = `<name>/SKILL.md` at repo root, frontmatter `name` + `description` (description = trigger criteria, only part loaded pre-invocation).
- Created `rails-context/SKILL.md`: the MVCC ("Context" as fourth letter of MVC) setup procedure — surveys app/ and lib/, proposes directories, generates per-dir AGENTS.md (intent-not-inventory, 30-120 lines) with relative `CLAUDE.md` symlinks, wires `bin/audit_context` drift script + `.claude/commands/context-audit.md`. Body kept verbatim from user's source doc; only frontmatter added.
- Created root `CLAUDE.md` documenting repo structure + authoring conventions + install path (`~/.claude/skills/` or project `.claude/skills/`).
- Not yet a git repo at time of writing.
