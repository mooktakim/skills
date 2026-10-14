---
id: rails-view-component-status
type: decision
status: proposed
summary: rails-view-component plugin (2026-10-09) - user decisions behind it, what replaces what, and the open agent and old-skill questions
created: 2026-10-09
sources: [auto memory rails-view-component-status.md]
---

Built 2026-10-09 (0.1.0) from a research request modelled on [[rails-minitest-status]]. User decisions:
- It REPLACES the user's own skills `viewcomponent` and `turbo-view-component` in `config_files/claude/skills/` (symlinked into ~/.claude/skills; they are user-authored, not third-party). The TurboViewComponent pattern (channel, broadcast_on, changes_to prefix/suffix) was carried over, revised: render_later jobs, plain-element target instead of turbo_frame_tag, no render? on broadcasters.
- Forms: use the app's existing builder or Rails' default. Never introduce a custom FormBuilder or forms gem.
- No design standards in this skill: only organisation, maintainable code, composability, testing. Styling belongs to rails-design-system.
- Agent built same day (0.2.0): `rails-view-component:component-builder` (name chosen by me; user may rename), skill preloaded, hook tells the main session to delegate component work unprompted. rails-hotwire's description now hands ViewComponent work to it. Include it in the ~2026-10-22 delegation count in [[rails-specialists-status]].

**Why:** the old skills had v3-era APIs and wrong Turbo advice (frames as broadcast targets, sync broadcasts).

**How to apply:** done 2026-10-09 - old skills deleted from config_files (a229e55), rails.md:7 points to this plugin; `turbo-hotwire` kept until the rails-hotwire agent-vs-skill decision. Add `rails-view-component:` to the count command's prefixes.
