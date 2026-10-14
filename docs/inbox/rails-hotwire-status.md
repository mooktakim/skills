---
id: rails-hotwire-status
type: decision
status: proposed
summary: rails-hotwire skill plugin (2026-10-09) - scope, user conventions it encodes, and the open agent and old-skill questions
created: 2026-10-09
sources: [auto memory rails-hotwire-status.md]
---

Built 2026-10-09 (0.1.0) on request ("deep research on hotwire ... create the best skill"), same method as [[rails-view-component-status]]. Skill only; no agent was asked for.

User conventions it encodes (from maynard `app/javascript/CLAUDE.md`, the user's own app): Stimulus state as aria/data/hidden styled by CSS variants, server HTML never JSON, never `data-turbo-permanent` to keep state (use before-morph events), valueChanged with a last-seen value.

**Why:** the user's old `turbo-hotwire` skill (config_files) taught frames as broadcast targets and sync broadcasts.

**How to apply:** turbo-hotwire deleted and rails.md:7 updated on 2026-10-09 (config_files 96d2aa9). User chose to keep all five audit scripts (2026-10-09); at the ~2026-10-22 count also count audit-mode runs per skill and delete a script whose mode never ran. Agent moved 2026-10-09 (user's request): rails-specialists' rails-hotwire is now `rails-hotwire:hotwire-builder` (0.2.0), skill preloaded, rails-specialists 0.5.0 has eight agents. Old note, now done: the rails-specialists `rails-hotwire` agent now loads this skill when available; whether to move it into this plugin (like minitest-runner) waits on the user and the ~2026-10-22 delegation count in [[rails-specialists-status]] - add `rails-hotwire:` to the count prefixes. Plugin and agent share the name "rails-hotwire" (namespaces differ).
