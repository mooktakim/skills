---
id: rails-view-component
type: architecture
status: active
summary: rails-view-component plugin (2026-10-09) - user decisions behind it, what replaces what, and the open agent and old-skill questions
aliases: [viewcomponent, components, component-builder, audit_components]
created: 2026-10-09
verified_at: 2026-10-15
citations: [rails-view-component/agents/component-builder.md, rails-view-component/scripts/audit_components]
sources: [auto memory rails-view-component-status.md]
---

Built 2026-10-09 (0.1.0) from a research request modelled on [rails-minitest-status](rails-minitest.md). User decisions:
- It REPLACES the user's own skills `viewcomponent` and `turbo-view-component` in `config_files/claude/skills/` (symlinked into ~/.claude/skills; they are user-authored, not third-party). The TurboViewComponent pattern (channel, broadcast_on, changes_to prefix/suffix) was carried over, revised: render_later jobs, plain-element target instead of turbo_frame_tag, no render? on broadcasters.
- Forms: use the app's existing builder or Rails' default. Never introduce a custom FormBuilder or forms gem.
- No design standards in this skill: only organisation, maintainable code, composability, testing. Styling belongs to rails-design-system.
- Agent built same day (0.2.0): `rails-view-component:component-builder` (name chosen by me; user may rename), skill preloaded, hook tells the main session to delegate component work unprompted. rails-hotwire's description now hands ViewComponent work to it. Include it in the ~2026-10-22 delegation count in [rails-specialists-status](rails-specialists.md).

**Why:** the old skills had v3-era APIs and wrong Turbo advice (frames as broadcast targets, sync broadcasts).

**How to apply:** done 2026-10-09 - old skills deleted from config_files (a229e55), rails.md:7 points to this plugin; `turbo-hotwire` was deleted too on 2026-10-09 (config_files 96d2aa9), replaced by the rails-hotwire plugin. Add `rails-view-component:` to the count command's prefixes.
