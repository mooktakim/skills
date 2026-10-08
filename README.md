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
| [`rails-design-system`](rails-design-system/) | Rails | Codifies a Rails app's UI into per-section design-system docs (role tokens, component specs, page patterns) on Tailwind v4, with drift auditing, edit-time enforcement, and a design-reviewer agent. |
| [`rails-specialists`](rails-specialists/) | Rails | Ships a team of nine Rails specialist agents (models, Hotwire, jobs, debugging, review, security, performance, deploy, upgrades) that detect the project's stack and follow its conventions. |
| [`rails-minitest`](rails-minitest/) | Rails | Sets one standard for Minitest suites in Rails apps - every kind of test, fixtures, shared helpers, shortcuts to a known state, speed, coverage, and flaky tests - with a suite audit and a `rails-tester` agent that runs and writes tests. |
| [`capture`](capture/) | Any | Records a rule you state, or a correction you make, into the one checked-in context file where it belongs (a directory's `CLAUDE.md`, the root, the design system, or your global file), so you never have to say it again. |
| [`toolsmith`](toolsmith/) | Any | Scans your Claude Code history for shell patterns Claude repeats (inline edit scripts, hand-built log entries, CI polling) and replaces them with small single-purpose Rust commands, each with an LLM guide that the tests run, plus hooks that tell Claude about them and a log that shows whether they are used. |

Each skill directory has its own README with full details.
