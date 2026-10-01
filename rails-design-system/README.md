# rails-design-system

Codifies a Rails app's UI into a design system that every future view is built against - so the whole application stays visually consistent as it grows. It generates agent-facing specs under `docs/design-system/`, then keeps them maintained and enforced as the views change.

Requires Tailwind CSS v4.

## What it creates

In the target app, under `docs/design-system/`:

- **`README.md`** - the router: the protocol agents follow before building any view, the sharing model, plus the section index.
- **`conventions.md`** - the rules every section follows: text case, how each state is shown, money and date formats, icons, action wording.
- **One directory per section** (`admin/`, `marketing/`, `app/`...) - independent UI contexts detected from layouts, controller namespaces, and routes. Each holds:
  - `design.md` - the section's aesthetic direction and do/don't rules.
  - `tokens.md` - role-named tokens (`surface`, `primary`, `border`...) per dimension, compiled to a Tailwind v4 `@theme` block.
  - `components/<name>.md` - one spec per component: a closed contract (variant/size/tone axes, six mandatory states) and a canonical HTML recipe in token utilities.
  - `patterns/<name>.md` - page archetypes (index page, form page, app shell...) composing components by reference; `app-shell.md` defines the page frames the others name.
  - `divergences.md` - the migration backlog: every off-system value found, and what it should become.

Plus, outside `docs/`: a design-system block in the root `CLAUDE.md` so agents load the standard before any view work; `bin/audit_design` - a grep-based drift script that flags raw hex, arbitrary `[...]` values, and literal palette classes; and Claude Code hooks that run the same checks on new view code - a `PostToolUse` hook on every Write/Edit, plus `Stop`/`SubagentStop` hooks that catch edits made through Bash or generators - and feed violations back as blocking errors, so generated code is enforced before the work is handed back. Only lines added since the last commit are checked, so old drift never blocks an unrelated edit.

## Philosophy

- **Sections share only what you choose.** By default sections are islands: admin and marketing never share tokens or components, and duplication between them is fine - coupling is the bug. When every section is built on one component library or brand, the plan can instead propose a *shared foundation* (`shared/` tokens and components that sections build on), and a single section can adopt an *external library* as-is (its palette classes allowed on its paths only). The choice is made once in the plan and recorded in the design system's README; maintenance runs respect it.
- **One place for rules that cross sections.** `conventions.md` holds what every section must agree on - text case, how each status is shown, money and date formats - and each section's app shell owns its page frame (width, padding, top spacing), so a rule like "status tags never show a dot" or "same top margin on every page" is one edit, not one per section.
- **Three tiers, one direction.** Tokens feed components; components compose into patterns; patterns build views. Small pieces with closed contracts build larger ones.
- **Tokens or nothing.** Views use role-token utilities only - never raw hex, palette classes, or arbitrary values. That one rule makes drift mechanically detectable: the audit is three greps.
- **Specs, not code.** Recipes are pure HTML + Tailwind, view-layer neutral. Bundled adapter guides translate contracts into ERB partials, ViewComponents, or Phlex classes when the app uses them.

A curated component catalog ships with the skill (buttons, forms, tables, navigation, overlays, page patterns...) as role-tokenized raw material - specs are adapted from it to each section's tokens, never pasted.

## How it runs

1. **Survey and plan** - detects Tailwind v4 (hard requirement), the view layer, and the candidate sections, then proposes the section split and every file it would write. Nothing is written until you approve.
2. **Generate** - derives each section's tokens and aesthetics from its actual views (interviewing you where none exist) and specs the components and patterns in use. Sections are independent, so they generate in parallel - one subagent per section, with the agent count declared in the plan you approved.
3. **Wire up maintenance** - root `CLAUDE.md` block, `bin/audit_design`, and the enforcement hooks.
4. **Review** - shows you everything; your stated design intent outranks anything inferred. Commits after corrections, and closes with an audit report.

Re-running later is how you maintain it: drift review, gap-fill for new sections and components, and promotion of repeated one-offs into specs - all behind the same approval gate. Existing docs are never regenerated, only surgically edited.

## The design-reviewer agent

`bin/audit_design` catches token violations; it cannot see a button rebuilt by hand, a page with the wrong width, or a status shown two different ways. The plugin ships a read-only agent for that: `rails-design-system:design-reviewer`. It loads the router, `conventions.md`, the section's specs and frames, and checks a change against them - hand-rolled markup where a component is specced, pages off their pattern or frame, broken conventions (text case, status representation, formats, icons), `design.md` rules, and specs left stale. Every finding cites the spec line it breaks; anything without a written rule is treated as taste and not reported as a defect.

- **When:** a `SessionStart` note (only in apps with `docs/design-system/`) tells the main session to delegate a review after view changes, before committing or opening a PR.
- **Code by default, screenshots on request:** give it a running dev server URL and ask for a visual check, and it screenshots the affected pages at desktop and phone width with `agent-browser` to compare frames and spacing.
- **Sweep mode:** maintenance runs dispatch it per section to find convention and frame drift across the whole app.
- **Promote to the audit:** when a finding recurs and a regular expression can catch it (a forbidden gradient class, money formatted without the helper), the agent proposes a rule for `docs/design-system/audit-rules`, tested against the current code. `bin/audit_design` and its hooks enforce those rules from then on, at no token cost. The agent finds new kinds of drift; the script stops them for free.

## Install

```
/plugin marketplace add mooktakim/skills
/plugin install rails-design-system@mooktakim
```

## How to use it

Open a Claude Code session inside your Rails app and ask in plain words - "set up a design system" / "audit design drift" - or invoke it directly: `/rails-design-system:rails-design-system`.

Afterwards, day to day:

- The root `CLAUDE.md` block makes agents read the standard before touching views, and update affected specs in the same commit as the change.
- Re-run the skill periodically - or after a big UI push - to catch drift; `bin/audit_design` gives the same signal from the shell.
- You don't have to remember: the plugin ships a `SessionStart` hook that runs `bin/audit_design` quietly when a session starts and, at most once a week per project, tells you when a maintenance run is due (audit findings, an audit script that differs from the installed skill, or missing/outdated enforcement hooks). It stays silent in projects without `bin/audit_design` and never starts a run on its own.
