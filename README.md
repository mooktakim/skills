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
| [`rails-context`](rails-context/) | Rails | Sets up per-directory `AGENTS.md` context files across a Rails app (MVC Context — Model, View, Controller, plus Context), each imported by a one-line `CLAUDE.md`, with drift-audit tooling and a migration from the old symlink layout. |
| [`rails-design-system`](rails-design-system/) | Rails | Codifies a Rails app's UI into per-section design-system docs (role tokens, component specs, page patterns) on Tailwind v4, with drift auditing, edit-time enforcement, and a design-reviewer agent. |
| [`rails-specialists`](rails-specialists/) | Rails | Ships a team of eight Rails specialist agents (models, jobs, debugging, review, security, performance, deploy, upgrades) that detect the project's stack and follow its conventions. |
| [`rails-minitest`](rails-minitest/) | Rails | Sets one standard for Minitest suites in Rails apps - every kind of test, fixtures, shared helpers, shortcuts to a known state, speed, coverage, and flaky tests - with a suite audit and a `minitest-runner` agent that runs and writes tests. |
| [`rails-view-component`](rails-view-component/) | Rails | Sets one standard for ViewComponent libraries in Rails apps - organising, writing, composing, and testing components, Turbo Streams, frames, morphing, self-broadcasting `TurboViewComponent`s, Stimulus beside components, forms with the app's own builder, previews, and the v4 upgrade - with a library audit and a `component-builder` agent that builds components to it. |
| [`rails-hotwire`](rails-hotwire/) | Rails | Sets one standard for Hotwire in Rails apps - Turbo Drive, Frames, Streams, broadcasts, Turbo 8 morphing, and Stimulus - with form responses, secure streams, state through morphs, UI patterns, accessibility, testing, and upgrades from rails-ujs or Turbolinks, plus an app audit and a `hotwire-builder` agent that builds to it. |
| [`rails-generators`](rails-generators/) | Rails | Makes Claude use Rails generators and commands instead of hand-writing their files - migrations above all (name patterns, field syntax, reversing, schema.rb conflicts, data changes, production safety), every other generator and installer, credentials, gems, and importmap pins - with a guard that refuses hand-written migrations and edits to schema dumps, encrypted credentials, and `Gemfile.lock`. |
| [`capture`](capture/) | Any | Records a rule you state, or a correction you make, into the one checked-in context file where it belongs (a directory's `CLAUDE.md`, the root, the design system, or your global file), so you never have to say it again. |
| [`toolsmith`](toolsmith/) | Any | Scans your Claude Code history for shell patterns Claude repeats (inline edit scripts, hand-built log entries, CI polling) and replaces them with small single-purpose Rust commands, each with an LLM guide that the tests run, plus hooks that tell Claude about them and a log that shows whether they are used. |
| [`project-memory`](project-memory/) | Any | Gives a project long-term memory in git - a protocol for typed notes with citations, a generated index read at task start, an inbox where unverified knowledge waits, lessons with usage counts, and an append-only log of finished work - with a fast `project-memory` command (lint for CI, index, stale), consolidation passes, and lossless migration from older history logs. |

Each skill directory has its own README with full details.
