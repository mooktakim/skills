# Repo moved to ~/Workspace/skills and generalized beyond Rails

- Folder moved: ~/Workspace/skills/rails → ~/Workspace/skills (old parent held nothing else). Repo now holds ALL of the user's skills, not just Rails ones; each skill's own name/description conveys its domain.
- Renamed marketplace `rails-skills` → `skills` and plugin `rails` → `skills` (dir plugins/skills/). Skill namespace is now `skills:<skill-name>` (e.g. /skills:rails-context). Install: `/plugin marketplace add ~/Workspace/skills` then `/plugin install skills@skills`.
- CLAUDE.md purpose/structure/install sections updated to match. Manifests re-validated clean.
- Claude project memory copied to the new project key (-Users-mooktakim-Workspace-skills).
