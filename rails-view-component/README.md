# rails-view-component

One standard for ViewComponent libraries in Rails apps: how to organise components, write them for maintainability, compose them, test them, and wire them into Hotwire. Components written to it are small, explicit about their inputs, safe to render in a page, a Turbo Stream, or a broadcast job, and tested through their output.

It sets no visual rules. How components look comes from the app's design system (`rails-design-system` when present) or the app's existing components.

## What it ships

- **The `rails-view-component` skill** - the rules for every component, plus references loaded on demand:
  - `design.md` - component, partial, or helper; the initializer; `render?` and the lifecycle; content and slots (component, lambda, polymorphic, default slots); collections; template styles; merging the caller's HTML attributes; naming, namespaces, and the base class.
  - `helpers.md` - what v4 components have, reaching other helpers, URLs, request-free components, sidecar translations.
  - `turbo.md` - components in Turbo Stream responses, Turbo Frames, stable ids, Turbo 8 morphing and `data-turbo-permanent`.
  - `broadcasting.md` - when to use a refresh broadcast, and the `TurboViewComponent` base class for components that replace themselves over Action Cable, with `changes_to` filters (exact, prefix, suffix) and `render_later` jobs; how to migrate the older frame-wrapped, synchronous version.
  - `stimulus.md` - generic or sidecar controllers, identifiers generated from the class name, loading controllers from `app/components` with importmap, esbuild, or Vite, values as the interface.
  - `forms.md` - forms with the app's own builder or Rails' default (no custom builder, no forms gem), components that receive the builder, errors and ids, Turbo re-renders.
  - `previews.md`, `testing.md` (component, preview, stream, and broadcast tests), `performance.md` (queries, caching, instrumentation), `upgrade.md` (v3 to v4, and the 4.14 security fix).
- **A library mode** - audit, set up, upgrade, or reorganise a component library: survey, plan, your approval, apply, verify.
- **`scripts/audit_components`** - a read-only survey the library mode runs from the skill's directory (plain Ruby, standard library, Ruby 2.6+). It reports the stack, components per namespace, base classes, template styles, components with no preview or test, and leads with file and line: old versions and v3 config, removed APIs, components that read request state or query the database, helpers in `initialize`, `html_safe`, random ids, blocks lost to `render Foo.new { }`, `_later` broadcasts that cannot serialize, frames used as broadcast targets, broadcasting components with `render?`, unloaded sidecar Stimulus controllers, and `:unprocessable_entity` on Rack 3.1+. Nothing is copied into the app.
- **The `component-builder` agent** (`rails-view-component:component-builder`) - builds or changes a component with its preview, its test, and the callers, Turbo, or Stimulus wiring, then returns a short report; also extracts repeated markup into components, makes components broadcast themselves, and runs library audits and upgrades (returning the plan for your approval first). The skill is preloaded into it. It makes no visual decisions, never adds gems on its own, and never commits.
- **A `SessionStart` hook** - in Rails apps that use ViewComponent only, it tells the main session to delegate component work to the agent, and to load the skill when it works on components itself.

## Where the standard comes from

The ViewComponent 4.x guide, API, and changelog (through 4.15), the turbo-rails and Stimulus source, the Turbo handbook and 37signals' writing on morphing, GitHub Primer's and GOV.UK's component libraries, Evil Martians' "ViewComponent in the wild" series, and the author's own `TurboViewComponent` base class, revised for `render_later` and plain-element targets.

## Install

```
/plugin marketplace add mooktakim/skills
/plugin install rails-view-component@mooktakim
```

## How to use it

Work as usual: when you ask for UI that the app builds with components, Claude hands it to the agent, or loads the skill for a small fix. For the whole library, ask in plain words - "audit our components", "upgrade ViewComponent", "set up previews" - or invoke the skill directly with `/rails-view-component:rails-view-component`.
