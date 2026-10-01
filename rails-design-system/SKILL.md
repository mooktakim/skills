---
name: rails-design-system
description: Set up and maintain a design-system context repository at docs/design-system/ in a Rails app using Tailwind CSS v4. Detects the app's UI sections (admin, marketing, app...), then generates per-section role-token definitions, component specs, and page-pattern specs, plus a bin/audit_design drift script, edit-time enforcement hooks, and a CI check. Re-runnable, an app already set up gets maintenance - drift review, gap-fill - through the same approval gate. Use when asked to set up a design system, codify styles or UI conventions, keep views visually consistent, spec a component library, standardise a UI rule across every page, or audit design drift.
---

# Rails Design System

You are bootstrapping or maintaining a design-system context repository at `docs/design-system/` in this Rails application: the standard every view is built against. Follow this document exactly. Work through the phases in order and show me the plan after Phase 1 before writing anything.

This skill is re-runnable. The first run on an app sets everything up; every later run is maintenance - drift review, gap-fill - through the same phases and the same approval gate (see "Re-runs: maintenance mode" in Phase 1).

The approval gate is a hard stop. Write nothing, add no gem, and dispatch no generation agent until I approve this run's Phase 1 plan in a reply to that plan: "approve", "yes", "go", or edits to it. These are NOT approval: a reply about something else (handle it, then show the plan's open points again and wait); approval of an earlier, broader plan that only said this skill would run; your own decision to invoke this skill in the middle of other work. Every open question in the plan - the interview for sections with no views included - needs an answer, or my explicit "use your recommendation", before Phase 2 starts. Phase 4 is a second stop: show the changes and wait for my reply before committing, on first runs and maintenance runs alike.

## Sections and sharing

The design system is organised into *sections*: coherent UI contexts with their own audience, chrome, and visual voice - `admin`, `marketing`, `app`. Two sections are distinct when an element in one should be allowed to look different in the other.

How sections relate is the app's *sharing model*. It is decided once, in the Phase 1 plan, and recorded in `docs/design-system/README.md`:

- **Islands** (the default). Sections never share anything: no shared tokens, no shared components, no shared folder. A section's component library IS its shared code, shared only within that section. Duplication between sections is correct; coupling between them is the bug. Fits sections that genuinely differ in audience and voice.
- **Shared foundation.** One `docs/design-system/shared/` folder holds the tokens, and any components, that every section uses. Each section keeps its own `design.md`, its patterns, and only the components and extra tokens that are truly its own. Dependencies point one way: a section may use `shared/`; `shared/` never references a section. Fits an app whose sections are all built on one component library or one brand, where islands would only duplicate it.
- **External library** (per section). A section adopts a third-party component library as-is, in that library's own class vocabulary. Its `tokens.md` names the library and states that its palette classes are allowed, and the section's view paths are listed in `docs/design-system/vendor-paths` (one path prefix per line, e.g. `app/views/admin/`) so `bin/audit_design` skips the palette check there. Raw hex and arbitrary values are still drift. Only when I name a library as the standard for that section.

Recommend a model in the plan, with its evidence (one component library or theme behind every layout points to a shared foundation), but the choice is mine. An app with no recorded model is on islands. Never change a recorded model unless I ask; a decision record in the repo (an ADR, or the README itself) outranks this skill's default. If two islands genuinely converge, that is my call to make, not yours. One section named `app` is a valid outcome for a single-audience application - do not over-split.

Under every model, `docs/design-system/conventions.md` holds the rules all sections follow: text case, how each domain state is shown, money and date formats, icon use, action wording. These are rules about wording and representation, not styling, so they couple no code and do not break islands. A rule meant for every page lives there once, instead of being fixed one section at a time.

## Three tiers, one direction

Each section is built from three tiers, and dependencies point one way:

- **Tokens** - role-named values, one canonical scale per dimension (colour, type, spacing, radius, shadow, motion).
- **Components** - reusable elements (button, card, table...), each with a contract and a canonical recipe. Components consume only tokens.
- **Patterns** - page archetypes (index page, form page, app shell...) composed from components *by reference* ("uses `page-heading` with a primary `button`"), never restating a component's markup. The app shell owns the page frame - container width, side padding, top spacing, heading alignment - and every other pattern names its frame instead of restating those classes.

Nothing points upward, and no tier restates a lower one. This is what makes the system composable: small pieces with contracts build larger ones.

## Tokens or nothing

Colour tokens are role-named, never hue-named: `surface`, `on-surface`, `muted`, `muted-surface`, `border`, `primary`, `primary-hover`, `on-primary`, `danger`, `success`, `warning`. Role names survive a re-theme; `blue-500` does not. Tokens compile to a Tailwind v4 `@theme` block - the section's `tokens.md` is the source of truth and the CSS is its compiled form; they must agree.

All sections compile into the app's single Tailwind entry CSS, so role names must not collide across sections. With one section, use bare role names (`--color-primary` → `bg-primary`). With several, prefix each section's roles with its name (`--color-admin-primary` → `bg-admin-primary`); at most one section - typically the app's dominant surface - may keep the bare names. Under a shared foundation, the shared tokens take the bare names and a section's own additions take its prefix. Propose the prefix assignment as part of the Phase 1 plan, and state each section's prefix at the top of its `tokens.md`.

Everything you write - specs, recipes, proposed fixes - uses token-based Tailwind utilities only. Never a raw hex value, never a literal palette class (`bg-gray-100`, `text-indigo-600`), never an arbitrary `[...]` value. This is the rule the whole standard rests on: it makes drift mechanically detectable (`bin/audit_design` is three regular expressions), so breaking it once makes every audit a lie. A value not on the section's scale is drift, by definition. The one exception is a section on the External library model, whose specs use the library's own palette classes inside its recorded vendor paths.

## Specs, not code

Canonical recipes are pure HTML plus Tailwind classes - view-layer neutral. Every component contract enumerates its axes (variant, size, tone - closed lists, never open-ended) and its states: default, hover, focus-visible, active, disabled, and loading where it submits. A component missing focus-visible is incomplete.

Realising a spec as an ERB partial, ViewComponent, or Phlex class happens during normal feature work, guided by the matching `adapters/` guide (chosen by Gemfile); this skill writes specs, it never mass-generates components. Generated docs carry no YAML frontmatter - there is no machine consumer; the audit greps classes, not metadata.

## Phase 1: Survey and plan

Delegate steps 1-4 to one read-only subagent when the environment provides subagents - fact-gathering only: it reports back Tailwind version, entry and compiled CSS paths, view layer, candidate sections with their evidence, representative-view observations, and any existing design docs. Build the plan from its report yourself: the plan, the approval conversation, and every decision stay in the main session. Run the survey inline if subagents are unavailable.

1. Read the `Gemfile` and lockfile: view layer (`phlex-rails`, `view_component`, or plain ERB) and Tailwind. **Tailwind CSS v4 is a hard requirement.** No Tailwind at all: stop and tell me this skill needs it. Tailwind v3 (a `tailwind.config.js` and a pre-4 version): stop and advise upgrading to v4 first. Confirm v4 by version number and by the `@import "tailwindcss"` / `@theme` entry-point CSS.
2. Locate the Tailwind entry CSS (where `@theme` lives or will live).
3. Detect candidate sections. Evidence, strongest first: layouts in `app/views/layouts/`, controller namespaces, route namespaces. An `Api::` namespace with no HTML views is not a section. Skim representative views per candidate to judge whether its look genuinely diverges.
4. Read `docs/design-system/` if it exists - that switches the run into maintenance mode (below).
5. Present the plan: sections found with their evidence, the proposed sharing model with its evidence (in maintenance mode, the recorded one), the conventions you found or that are still open questions for me, and per section every file that would be written or edited, one line each on what it would say. Flag the section split explicitly - it is the expensive-to-change decision - and state how many subagents the run will use (one survey agent plus one generation agent per section), so the fan-out is approved, never a surprise. Wait for my approval.

### Re-runs: maintenance mode

Re-running on an app that already has `docs/design-system/` is maintenance, not a rewrite. The survey then also covers the existing docs, and the Phase 1 plan proposes six kinds of work:

- **Gap-fill**: newly detected sections; components or patterns now in use but unspecced; missing or outdated enforcement wiring: `audit_design` entries an older version of this skill wrote into `.claude/settings.json` get removed (the plugin ships the hooks now, so they would run twice), and a missing CI step gets added as in Phase 3.
- **Drift review**: run `bin/audit_design` (if it is missing or differs from `scripts/audit_design` in this skill, copy it over first, then run the Phase 3 smoke test; an older copy that someone customised by hand gets its customisations moved into `vendor-paths` or `audit-rules`, and I approve that move). Each finding becomes a proposed fix - retokenise the view, or add a missing token to the section's `tokens.md` - never a silent skip.
- **Promotion**: the same one-off markup repeated in a section's views becomes a proposed component spec in that section's library; a design-reviewer finding that recurs and that a regular expression catches reliably becomes a proposed `docs/design-system/audit-rules` line (the agent reports these under "Promote to the audit").
- **Conventions and frames**: rules the views now follow consistently, or that I stated since the last run (look for repeated corrections in recent commits), but `conventions.md` lacks; views that break a recorded convention; page patterns that restate the frame instead of naming it. Find them with the `design-reviewer` agent this plugin ships: one agent per section in sweep mode, dispatched during the survey and counted in the plan's fan-out. Propose each fix across every section at once.
- **Spec-vs-realized drift**: read each spec's "Realized as" file; where code and spec contradict, propose which side changes - never let them disagree silently.
- **Divergences ledger**: record newly collapsed variants; mark migrated ones done.

Never regenerate an existing doc: every change is a surgical edit, listed in the plan and approved before writing. Read the recorded sharing model first and work within it; never propose undoing a shared foundation or an External library section that I chose. Section-scoped maintenance work (drift fixes, gap-fill) may be dispatched to per-section subagents exactly like Phase 2 generation, behind the same approved plan. If the app has HTML style-guide pages under `docs/design-system/` or a `docs/design-system` `@source` directive in its Tailwind entry CSS left over from an earlier version of this skill, propose deleting them - the style guide is no longer part of the system.

## Phase 2: Generate

First write `docs/design-system/conventions.md` yourself, from the survey and my answers, and give its path to every section agent: section specs follow it. Under a shared foundation, then generate `shared/` (`tokens.md`, then any shared components), inline or with one agent, and give its path to every section agent. Sections then generate in parallel: dispatch one subagent per approved section (run inline when subagents are unavailable, or for a single small section). Before dispatching, resolve everything that needs my input - in particular the interview for sections with no views - so each agent's prompt already carries the answers; a generation agent never asks me anything. Each agent's prompt must scope it to its section only and include: the approved file list, the section's token prefix, the interview answers, the path to this skill's directory, and the instruction to follow this Phase's rules - reading the matching `references/` guide immediately before each file, and the `catalog/` map when speccing components. When every agent has returned, check the output against the doctrine (token purity, no reference the sharing model does not allow) before moving on.

Each section, whether dispatched or inline, is generated in dependency order: `design.md` → `tokens.md` → `components/*.md` → `patterns/*.md` → `divergences.md`. After all sections, write the router `docs/design-system/README.md` yourself, recording the sharing model. It and `conventions.md` (plus `shared/` under a shared foundation) are the only cross-section files. For any External library section, also write `docs/design-system/vendor-paths`.

Generation guides ship with this skill in `references/` next to this SKILL.md - they are part of the skill, NOT files in the target app, so resolve their paths from this skill's own directory. You MUST read the matching guide immediately before generating each file (per file, not once upfront):

- `references/conventions.md`, `references/design.md`, `references/tokens.md`, `references/component-spec.md`, `references/pattern-spec.md`, `references/divergences.md`, `references/readme-router.md`

Rules that govern all generation:

- Derive tokens and aesthetics from the section's existing views: collect the utilities actually used, canonicalise by frequency, and record every collapsed value in the divergences ledger. Where the section has no views yet, interview me instead of inventing a design language.
- When speccing a component, look it up in `catalog/README.md` (beside this SKILL.md) and load the mapped catalog file as raw material. Re-shape it to the section's tokens and the app's real markup; never paste an entry unadapted. A component with no catalog entry gets its spec derived from the app's own markup using `references/component-spec.md` alone.
- Only spec components and patterns the section actually uses or the approved plan listed. Never scaffold the whole catalog into an app. The one standing exception: every section with page patterns gets `patterns/app-shell.md`, because it defines the frames the other patterns name.
- When the Gemfile shows Phlex or ViewComponent, read the matching `adapters/` guide before writing any "Realized as" guidance, so spec contracts translate into that library's idiom.
- A new gem (a component library, say) is added only when the approved plan lists it, with `bundle add <gem>`. Then confirm `Gemfile.lock` changed and `bundle check` passes before going on. Never hand-edit a version in the `Gemfile` without running `bundle install` after it: a stale lockfile fails every CI job.

## Phase 3: Wire up maintenance

1. Append this block to the root `CLAUDE.md` (adapt wording to fit, keep the substance; create the file if the app has none):

```markdown
## Design system

This app has a codified design system at docs/design-system/. Before building
or changing any view, read docs/design-system/README.md, then the target
section's tokens.md and the relevant components/ and patterns/ specs. Use
token-based Tailwind utilities only - never raw hex, literal palette classes
(bg-gray-100), or arbitrary [...] values. Sections share only what the
sharing model in docs/design-system/README.md allows. Every section follows
docs/design-system/conventions.md: when the user states a rule for every page
("standardise X everywhere"), record it there and fix every section in the
same change, not only the one in view. Page width, padding, and top spacing
come from the app shell's named frames - never restate them in a page. When
a design review finds the same violation again and a grep could catch it, propose
a rule for docs/design-system/audit-rules so the hooks enforce it from then on.
When a change adds or alters a documented pattern, update the affected spec
in the same commit. If a needed
component has no spec, spec it first rather than hand-rolling a one-off.
bin/audit_design reports drift. The rails-design-system plugin's hooks block
violations in new code after each edit and before each turn ends, and CI runs
the audit too; a periodic design-system maintenance run works through what the
audit flags.
```

2. Copy the audit script this skill ships into the app: `cp "${CLAUDE_SKILL_DIR}/scripts/audit_design" bin/audit_design` (`${CLAUDE_SKILL_DIR}` is this skill's directory; resolve it yourself if the variable is not expanded). Copy it unchanged - project-specific behaviour lives in data files the script reads (`docs/design-system/vendor-paths`, `docs/design-system/audit-rules`), never in edits to the script, so every app runs the same checks and an outdated copy is a plain file difference. Read the script's header comment: it documents the modes.

3. Make the script executable and prove it works. Run this from the repo root; it exercises both hook modes from a subfolder, the way the harness calls them, and removes its test file:

```bash
chmod +x bin/audit_design
f="$PWD/app/views/audit_smoke_test.html.erb"
printf '<p class="bg-gray-100">x</p>\n' > "$f"
(cd app && printf '{"tool_input":{"file_path":"%s"}}' "$f" | "$OLDPWD/bin/audit_design" --hook 2>/dev/null); echo "hook, violation: $? (expect 2)"
(cd app && printf '{}' | "$OLDPWD/bin/audit_design" --stop 2>/dev/null); echo "stop, violation: $? (expect 2)"
printf '<p class="bg-surface">x</p>\n' > "$f"
(cd app && printf '{"tool_input":{"file_path":"%s"}}' "$f" | "$OLDPWD/bin/audit_design" --hook); echo "hook, clean: $? (expect 0)"
rm "$f"
```

Any result other than the expected one: stop, find the cause, and fix it before step 4. Report the three results in Phase 4.

4. Enforcement needs no wiring: this plugin ships the hooks. In every session, in any app with `docs/design-system/README.md`, the plugin runs its own copy of `audit_design` against the project - after each Write/Edit (`--hook`), and before each turn and subagent ends (`--stop`), which catches views written through Bash, heredocs, `sed -i`, or generators that no tool matcher sees. Both modes check only lines added since HEAD, and a violation goes back to the agent as a blocking error, so it gets fixed before the work is handed back - even by an agent that never read the context files. Because the plugin runs its own copy, a fix to the checks reaches every app when the plugin updates. Do not add audit hooks to `.claude/settings.json`; if an older version of this skill put `audit_design` entries there, remove them (and only them), or the checks run twice.

5. Wire the audit into CI, so drift from people and other tools is caught too, and teammates without the plugin are covered. Pick the mode from the full audit result:
   - Audit clean (0 findings): `bin/audit_design --strict` - any drift anywhere fails.
   - Old drift remains: `bin/audit_design --changed <default branch>` - only lines a branch adds must be clean, so the backlog never blocks a merge while it shrinks. Switch to `--strict` once the audit reaches 0.

   Add it as a step in `config/ci.rb` (`step "Design: token audit", "bin/audit_design --strict"`) when the app has one, and as a step in the GitHub Actions `lint` job (or the closest equivalent) when the app has `.github/workflows/`; `--changed` there needs `fetch-depth: 0` on the checkout step. Other CI systems: propose the step and let me place it. List the CI edits in the Phase 1 plan like any other file.

`bin/audit_design` also enforces project rules from `docs/design-system/audit-rules`, one per line as `<label> :: <regular expression>` (Ruby syntax; ordinary `grep -E` patterns work unchanged) - for example `no gradients (app/design.md) :: (^|[^a-z-])bg-(gradient|linear|radial|conic)-`. Do not create the file on a first run; rules arrive by promotion, from design-reviewer findings that recur. Only add a rule whose regex matches the violations and nothing legitimate in the current code, and name the spec rule it enforces in its label.

Do not create any slash command for auditing: re-running this skill IS the audit (see "Re-runs: maintenance mode").

## Phase 4: Review

Show me every generated or edited file grouped in one message. I will correct anything that misstates the design intent; my stated intent always outranks what you inferred from the views. Wait for my reply. Fold corrections in, then commit everything with a clear message once I approve. If I move on without answering, tell me once that the run's files are still uncommitted.

Close every run - first run or maintenance - by running `bin/audit_design` and reporting what it still flags: items I chose to defer, plus anything the run didn't cover. Nothing flagged gets silently ignored.

## Never do

- Share tokens, components, or code across sections beyond what the recorded sharing model allows, or change that model without my request.
- Emit a raw hex value, a literal palette class, or an arbitrary `[...]` value in any spec or recipe.
- Restate a component's markup inside a pattern - patterns compose by reference.
- Paste a catalog entry into an app unadapted, or spec a component the section does not use.
- Write per-directory `CLAUDE.md` files - that is the rails-context skill's job, not this one's.
- Regenerate an existing doc when a surgical edit will do.
- Let a spec and its realized component contradict silently - one of them is the bug; flag it.
- Restyle existing views beyond fixes I approved from the drift review.
