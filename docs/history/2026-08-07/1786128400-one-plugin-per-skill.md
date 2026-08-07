# Restructured: one plugin per skill, skills at repo root

- Dropped the single bundled `skills` plugin. Each skill is now its own plugin in a root directory: `<skill>/SKILL.md` + `<skill>/.claude-plugin/plugin.json`, listed in marketplace.json plugins[] with source `./<skill>`.
- rails-context moved plugins/skills/skills/rails-context → ./rails-context; plugins/ tree deleted.
- SKILL.md sits at plugin root (no skills/ subdir) — Claude Code ≥2.1.142 auto-loads a single root SKILL.md, no `skills` manifest field needed.
- Consequence vs bundled design: adding a new skill now REQUIRES a new marketplace.json entry + plugin.json; install is per skill (`/plugin install rails-context@skills`).
- CLAUDE.md structure/install sections updated; marketplace + plugin both validate clean.
