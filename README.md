# Claude Code Skills

A hand-authored collection of skills for [Claude Code](https://code.claude.com), packaged as a plugin marketplace. Each skill is its own plugin, so you install only the ones you want. Skills cover any domain — each skill's name and description tell you what it's for.

## Install

Add the marketplace once:

```
/plugin marketplace add mooktakim/skills
```

Then install skills individually:

```
/plugin install rails-context@mooktakim
```

Browse everything interactively with `/plugin`.

## Skills

| Skill | Domain | What it does |
|-------|--------|--------------|
| [`rails-context`](rails-context/) | Rails | Sets up per-directory `CLAUDE.md` context files across a Rails app (MVC Context — Model, View, Controller, plus Context), with `AGENTS.md` symlinks and drift-audit tooling. |
| [`rails-design-system`](rails-design-system/) | Rails | Codifies a Rails app's UI into per-section design-system docs (role tokens, component specs, page patterns) on Tailwind v4, with drift auditing and edit-time enforcement. |

Each skill directory has its own README with full details.
