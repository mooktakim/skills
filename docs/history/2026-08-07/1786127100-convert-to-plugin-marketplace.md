# Converted repo to plugin marketplace

- Repo is now marketplace `rails-skills` (.claude-plugin/marketplace.json) hosting one plugin `rails` (plugins/rails/.claude-plugin/plugin.json, v0.1.0) bundling all skills; rails-context moved to plugins/rails/skills/rails-context/.
- Skills namespace as `rails:<skill-name>` when installed. Install: `/plugin marketplace add ~/Workspace/skills/rails` (or repo URL) then `/plugin install rails@rails-skills`.
- Gotcha: `claude plugin validate` rejects the docs' `metadata.pluginRoot` + bare `source` shorthand — plugin source must be an explicit relative path (`./plugins/rails`). Both manifests validate clean.
- CLAUDE.md structure + install sections updated; new skills just get a directory under plugins/rails/skills/, no manifest edits needed.
