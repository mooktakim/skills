# rails-context: flipped canonical file to CLAUDE.md

- User changed their mind on the MVCC naming convention: canonical per-directory context file is now `CLAUDE.md`; `AGENTS.md` is the relative symlink (`ln -s CLAUDE.md AGENTS.md`).
- Updated `rails-context/SKILL.md` throughout: frontmatter description, naming/migration section (legacy real `AGENTS.md` now migrates to `CLAUDE.md`), size discipline, Phase 2 symlink step, Phase 3 maintenance block + `bin/audit_context` (legacy finder scans real AGENTS.md, main loop scans CLAUDE.md, symlink checks expect AGENTS.md → CLAUDE.md), context-audit command, Phase 4.
