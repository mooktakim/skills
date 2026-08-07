# skills

A hand-authored collection of [Claude Code](https://code.claude.com) skills, packaged as a plugin marketplace. Each skill is its own plugin, so you install only the ones you want. Skills cover any domain — each skill's name and description tell you what it's for.

## Install

Add the marketplace once:

```
/plugin marketplace add mooktakim/skills
```

(or from a local checkout: `/plugin marketplace add ~/Workspace/skills`)

Then install skills individually:

```
/plugin install rails-context@mooktakim
```

Browse everything interactively with `/plugin`.

## Skills

| Skill | Domain | What it does |
|-------|--------|--------------|
| [`rails-context`](rails-context/) | Rails | Sets up per-directory `CLAUDE.md` context files across a Rails app (MVC Context — Model, View, Controller, plus Context), with `AGENTS.md` symlinks and drift-audit tooling. |

Each skill directory has its own README with full details.

## Repository layout

```
.claude-plugin/marketplace.json    # marketplace manifest; one plugins[] entry per skill
<skill-name>/
  .claude-plugin/plugin.json       # plugin manifest
  SKILL.md                         # the skill itself: frontmatter + instructions
  README.md                        # human-facing description
```

## Adding a new skill

1. Create `<skill-name>/SKILL.md` — YAML frontmatter (`name` matching the directory, a trigger-oriented `description`), then the instructions.
2. Add `<skill-name>/.claude-plugin/plugin.json` (`name`, `version`, `description`, `author`).
3. Add a matching entry to the `plugins` array in `.claude-plugin/marketplace.json` (`source: "./<skill-name>"`).
4. Add a `README.md` for the skill and a row to the table above.
5. Validate: `claude plugin validate .` and `claude plugin validate <skill-name>`.
