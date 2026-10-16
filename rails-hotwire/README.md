# rails-hotwire

One standard for Hotwire in Rails apps: the server renders HTML, Turbo moves it to the browser, and Stimulus adds only the behaviour HTML cannot express. UI built to it works as plain HTML first, keeps working through the page cache, the back button, and live refreshes, and has the right test at the right level.

It sets no visual rules (that is the app's design system), and leaves ViewComponent-specific wiring to `rails-view-component`.

## Install

```
/plugin marketplace add mooktakim/skills
/plugin install rails-hotwire@mooktakim
```

## What it ships

- **The `rails-hotwire` skill** - 20 rules for every change, plus references loaded on demand:
  - `drive.md` - visits, redirects and status codes, state-changing links and hover prefetch, the page cache and previews, progress and busy states, `<head>` and assets, permanent elements, meta tags, view transitions, turning Drive off, `Turbo.config`.
  - `frames.md` - when a frame earns its place (and when it does not), ids, targeting `_top` / `_parent` / other frames, the frame layout, "Content missing", lazy and morphing frames.
  - `streams.md` - the eight actions, stream templates vs inline, targets, GET streams, flash after a stream, custom stream actions, request ids.
  - `broadcasting.md` - refresh vs targeted broadcasts, the `broadcasts_*` macros, `_later` and after-commit rules, request-free broadcast markup, subscribing, signed names vs authorisation (with an authorised channel), adapters, catching up after a disconnect, debugging.
  - `morphing.md` - page refresh setup, how idiomorph matches, protecting open dialogs, unsubmitted edits, and library DOM, the morph events, pitfalls.
  - `stimulus.md` - controller design, state in the DOM, the full API, lifecycle and cleanup, third-party libraries, shared code, loading with importmap, jsbundling, or Vite, accessibility, outdated syntax.
  - `forms.md`, `patterns.md` (dialogs, inline editing, search, pagination, tabs, flash, optimistic UI, sorting, confirm, live updates, counters, wizards, accessible updates), `testing.md`, `native.md`, `upgrade.md` (rails-ujs, Turbolinks, Turbo 7, Stimulus 1.x).
- **An app mode** - audit, upgrade, or reorganise an app's Hotwire setup: survey, plan, your approval, apply, verify.
- **`scripts/audit_hotwire`** - a read-only survey the app mode runs from the skill's directory (plain Ruby, standard library, Ruby 2.6+). It reports the stack, the layouts' Turbo setup, an inventory (controllers, stream templates, frames, broadcasts, subscriptions, system tests), and leads with file and line: Turbo 7, rails-ujs and Turbolinks leftovers, form renders with no status, `:unprocessable_entity` on Rack 3.1+, synchronous broadcasts in models, removed Turbo attributes and APIs, `form.submit()`, page-ready handlers, Stimulus 1.x syntax, listener leaks, global queries, unregistered controllers, scripts in `<body>`, and `turbo_stream_from` in `<head>`. Nothing is copied into the app.
- **The `hotwire-builder` agent** (`rails-hotwire:hotwire-builder`) - builds interactive UI (frames, stream responses, broadcasts, morph-safe pages, Stimulus controllers) with the views, controller responses, and tests, checks it in a browser, and returns a short report; also fixes Turbo behaviour that misbehaves and runs Hotwire audits and upgrades (returning the plan for your approval first). The skill is preloaded into it. It replaces the `rails-hotwire` agent that `rails-specialists` shipped before 0.5.0. It makes no visual decisions, leaves components to `rails-view-component:component-builder`, never adds gems on its own, and never commits.
- **A `SessionStart` hook** - in Rails apps that use turbo-rails or stimulus-rails only, it tells the main session to delegate Hotwire work to the agent, and to load the skill when it works on Hotwire itself.

## Where the standard comes from

The Turbo and Stimulus handbooks and source (Turbo 8.0.23, turbo-rails 2.0.23, Stimulus 3.2.2, stimulus-rails 1.3.4, importmap-rails 2.2), 37signals' open-source Fizzy, Campfire, and Writebook (how the authors of Hotwire use it), the 37signals dev blog on morphing, thoughtbot's Hotwire examples and morphing write-ups, Better Stimulus, the Hotwire Native docs, and the conventions in the author's own apps.

## Usage

Work as usual: when you ask for interactive UI in a Hotwire app, Claude hands it to the agent, or loads the skill for a small fix. For the whole app, ask in plain words - "audit our Hotwire setup", "move us off rails-ujs", "turn on morph refreshes" - or invoke the skill directly with `/rails-hotwire:rails-hotwire`.

## Requirements

- A Rails application that uses turbo-rails or stimulus-rails.
- Ruby 2.6 or later for `scripts/audit_hotwire`. The macOS system Ruby is enough.

---

Part of [mooktakim/skills](../README.md), a plugin marketplace for Claude Code. MIT licensed.
