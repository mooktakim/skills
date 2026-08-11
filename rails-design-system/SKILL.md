---
name: rails-design-system
description: Set up and maintain a design-system context repository at docs/design-system/ in a Rails app using Tailwind CSS v4. Detects the app's UI sections (admin, marketing, app...), then generates per-section role-token definitions, component specs, and page-pattern specs, plus a browsable HTML style guide and a bin/audit_design drift script. Re-runnable, an app already set up gets maintenance - drift review, gap-fill, preview sync - through the same approval gate. Use when asked to set up a design system, codify styles or UI conventions, keep views visually consistent, spec a component library, or audit design drift.
---

# Rails Design System

You are bootstrapping or maintaining a design-system context repository at `docs/design-system/` in this Rails application: the standard every view is built against, plus a browsable HTML style guide of it. Follow this document exactly. Work through the phases in order and show me the plan after Phase 1 before writing anything.

This skill is re-runnable. The first run on an app sets everything up; every later run is maintenance - drift review, gap-fill, preview sync - through the same phases and the same approval gate (see "Re-runs: maintenance mode" in Phase 1).

## Sections are islands

The design system is organised into *sections*: coherent UI contexts with their own audience, chrome, and visual voice - `admin`, `marketing`, `app`. Two sections are distinct when an element in one should be allowed to look different in the other.

Sections never share anything: no shared tokens, no shared components, no shared folder, ever. A section's component library IS its shared code, shared only within that section. Duplication between sections is correct; coupling between them is the bug. If two sections genuinely converge, that is my call to make, not yours. One section named `app` is a valid outcome for a single-audience application - do not over-split.

## Three tiers, one direction

Each section is built from three tiers, and dependencies point one way:

- **Tokens** - role-named values, one canonical scale per dimension (colour, type, spacing, radius, shadow, motion).
- **Components** - reusable elements (button, card, table...), each with a contract and a canonical recipe. Components consume only tokens.
- **Patterns** - page archetypes (index page, form page, app shell...) composed from components *by reference* ("uses `page-heading` with a primary `button`"), never restating a component's markup.

Nothing points upward, and no tier restates a lower one. This is what makes the system composable: small pieces with contracts build larger ones.

## Tokens or nothing

Colour tokens are role-named, never hue-named: `surface`, `on-surface`, `muted`, `muted-surface`, `border`, `primary`, `primary-hover`, `on-primary`, `danger`, `success`, `warning`. Role names survive a re-theme; `blue-500` does not. Tokens compile to a Tailwind v4 `@theme` block - the section's `tokens.md` is the source of truth and the CSS is its compiled form; they must agree.

All sections compile into the app's single Tailwind entry CSS, so role names must not collide across sections. With one section, use bare role names (`--color-primary` → `bg-primary`). With several, prefix each section's roles with its name (`--color-admin-primary` → `bg-admin-primary`); at most one section - typically the app's dominant surface - may keep the bare names. Propose the prefix assignment as part of the Phase 1 plan, and state each section's prefix at the top of its `tokens.md`.

Everything you write - specs, recipes, preview pages, proposed fixes - uses token-based Tailwind utilities only. Never a raw hex value, never a literal palette class (`bg-gray-100`, `text-indigo-600`), never an arbitrary `[...]` value. This is the rule the whole standard rests on: it makes drift mechanically detectable (`bin/audit_design` is three greps), so breaking it once makes every audit a lie. A value not on the section's scale is drift, by definition.

## Specs, not code

Canonical recipes are pure HTML plus Tailwind classes - view-layer neutral. Every component contract enumerates its axes (variant, size, tone - closed lists, never open-ended) and its states: default, hover, focus-visible, active, disabled, and loading where it submits. A component missing focus-visible is incomplete.

Realising a spec as an ERB partial, ViewComponent, or Phlex class happens during normal feature work, guided by the matching `adapters/` guide (chosen by Gemfile); this skill writes specs and previews, it never mass-generates components. Generated docs carry no YAML frontmatter - there is no machine consumer; the audit greps classes, not metadata.

## Phase 1: Survey and plan

Delegate steps 1-4 to one read-only subagent when the environment provides subagents - fact-gathering only: it reports back Tailwind version, entry and compiled CSS paths, view layer, candidate sections with their evidence, representative-view observations, and any existing design docs. Build the plan from its report yourself: the plan, the approval conversation, and every decision stay in the main session. Run the survey inline if subagents are unavailable.

1. Read the `Gemfile` and lockfile: view layer (`phlex-rails`, `view_component`, or plain ERB) and Tailwind. **Tailwind CSS v4 is a hard requirement.** No Tailwind at all: stop and tell me this skill needs it. Tailwind v3 (a `tailwind.config.js` and a pre-4 version): stop and advise upgrading to v4 first. Confirm v4 by version number and by the `@import "tailwindcss"` / `@theme` entry-point CSS.
2. Locate the Tailwind entry CSS (where `@theme` lives or will live) and the compiled CSS the app serves (e.g. `app/assets/builds/tailwind.css`) - the preview pages link the compiled file by relative path.
3. Detect candidate sections. Evidence, strongest first: layouts in `app/views/layouts/`, controller namespaces, route namespaces. An `Api::` namespace with no HTML views is not a section. Skim representative views per candidate to judge whether its look genuinely diverges.
4. Read `docs/design-system/` if it exists - that switches the run into maintenance mode (below).
5. Present the plan: sections found with their evidence, and per section every file that would be written or edited, one line each on what it would say. Flag the section split explicitly - it is the expensive-to-change decision - and state how many subagents the run will use (one survey agent plus one generation agent per section), so the fan-out is approved, never a surprise. Wait for my approval.

### Re-runs: maintenance mode

Re-running on an app that already has `docs/design-system/` is maintenance, not a rewrite. The survey then also covers the existing docs, and the Phase 1 plan proposes six kinds of work:

- **Gap-fill**: newly detected sections; components or patterns now in use but unspecced; missing enforcement wiring (the PostToolUse hook in `.claude/settings.json`).
- **Drift review**: run `bin/audit_design` (if it is missing or differs from the script in Phase 3 of this skill version, create or update it first). Each finding becomes a proposed fix - retokenise the view, or add a missing token to the section's `tokens.md` - never a silent skip.
- **Promotion**: the same one-off markup repeated in a section's views becomes a proposed component spec in that section's library.
- **Spec-vs-realized drift**: read each spec's "Realized as" file; where code and spec contradict, propose which side changes - never let them disagree silently.
- **Divergences ledger**: record newly collapsed variants; mark migrated ones done.
- **Preview sync**: for each spec added or changed since the last run, verify the matching block in the section's preview pages still matches - same recipe markup, every variant rendered - and propose the edits to bring it current.

Never regenerate an existing doc or preview page: every change is a surgical edit, listed in the plan and approved before writing. Section-scoped maintenance work (drift fixes, gap-fill, preview sync) may be dispatched to per-section subagents exactly like Phase 2 generation, behind the same approved plan.

## Phase 2: Generate

Sections are islands, so they generate in parallel: dispatch one subagent per approved section (run inline when subagents are unavailable, or for a single small section). Before dispatching, resolve everything that needs my input - in particular the interview for sections with no views - so each agent's prompt already carries the answers; a generation agent never asks me anything. Each agent's prompt must scope it to its section only and include: the approved file list, the section's token prefix, the interview answers, the path to this skill's directory, and the instruction to follow this Phase's rules - reading the matching `references/` guide immediately before each file, and the `catalog/` map when speccing components. When every agent has returned, check the output against the doctrine (token purity, no cross-section references, spec-preview sync) before moving on.

Each section, whether dispatched or inline, is generated in dependency order: `design.md` → `tokens.md` → `components/*.md` → `patterns/*.md` → `divergences.md` → the section's preview pages (`tokens.html`, `components.html`, `patterns.html`). After all sections, write the shared router `docs/design-system/README.md` and the style-guide entry page `docs/design-system/index.html` yourself - they are the only cross-section files.

Generation guides ship with this skill in `references/` next to this SKILL.md - they are part of the skill, NOT files in the target app, so resolve their paths from this skill's own directory. You MUST read the matching guide immediately before generating each file (per file, not once upfront):

- `references/design.md`, `references/tokens.md`, `references/component-spec.md`, `references/pattern-spec.md`, `references/divergences.md`, `references/preview.md`, `references/readme-router.md`

Rules that govern all generation:

- Derive tokens and aesthetics from the section's existing views: collect the utilities actually used, canonicalise by frequency, and record every collapsed value in the divergences ledger. Where the section has no views yet, interview me instead of inventing a design language.
- When speccing a component, look it up in `catalog/README.md` (beside this SKILL.md) and load the mapped catalog file as raw material. Re-shape it to the section's tokens and the app's real markup; never paste an entry unadapted. A component with no catalog entry gets its spec derived from the app's own markup using `references/component-spec.md` alone.
- Only spec components and patterns the section actually uses or the approved plan listed. Never scaffold the whole catalog into an app.
- Preview pages embed the same canonical recipe HTML as the specs - one source of truth. A spec and its preview block are edited together or not at all.
- When the Gemfile shows Phlex or ViewComponent, read the matching `adapters/` guide before writing any "Realized as" guidance, so spec contracts translate into that library's idiom.

## Phase 3: Wire up maintenance

1. Append this block to the root `CLAUDE.md` (adapt wording to fit, keep the substance; create the file if the app has none):

```markdown
## Design system

This app has a codified design system at docs/design-system/. Before building
or changing any view, read docs/design-system/README.md, then the target
section's tokens.md and the relevant components/ and patterns/ specs. Use
token-based Tailwind utilities only - never raw hex, literal palette classes
(bg-gray-100), or arbitrary [...] values. Sections never share tokens or code.
When a change adds or alters a documented pattern, update the affected spec
AND its block in the section's preview pages, in the same commit. If a needed
component has no spec, spec it first rather than hand-rolling a one-off.
bin/audit_design reports drift, and a PostToolUse hook (bin/audit_design
--hook) blocks token violations at edit time; a periodic design-system
maintenance run works through what the audit flags.
```

2. Wire the preview's CSS: add an `@source "../../docs/design-system"` directive (path relative to the entry CSS) to the Tailwind entry file so classes used only in preview pages survive purging, and confirm each preview page's relative `<link>` to the compiled CSS resolves.

3. Create `bin/audit_design` (chmod +x) with this content:

```bash
#!/usr/bin/env bash
# Report design drift: colours and utilities that bypass the design-system tokens.
# Run from the repo root. Findings are drift signals to review, not proof of defects.
# Mark a deliberate exception by putting "design-ok" on the same line.
# Mailer templates are exempt: email clients require inline styles.
# Modes:
#   bin/audit_design         scan the app and report; always exits 0
#   bin/audit_design --hook  Claude Code PostToolUse hook: reads the tool-call JSON
#                            from stdin, checks only the edited file, exits 2 with
#                            findings on stderr so the agent fixes them immediately
set -euo pipefail
HEX='#([0-9a-fA-F]{6}|[0-9a-fA-F]{8}|[0-9a-fA-F]{3,4})([^0-9a-zA-Z]|$)'
ARB='[a-z][a-z0-9:-]*-\[[^]]+\]'
PAL='(bg|text|border|ring|divide|outline|fill|stroke|from|via|to|accent|decoration|placeholder|caret|shadow)-(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-[0-9]{2,3}'

if [ "${1:-}" = "--hook" ]; then
  file=$(ruby -rjson -e 'puts JSON.parse($stdin.read).dig("tool_input", "file_path").to_s' 2>/dev/null || true)
  { [ -n "$file" ] && [ -f "$file" ]; } || exit 0
  rel=${file#"$PWD"/}
  case "$rel" in
    *_mailer/*|*layouts/mailer*|*tokens*.css|*theme*.css) exit 0 ;;
    app/views/*|app/components/*|app/frontend/*|app/javascript/*|app/assets/stylesheets/*) ;;
    *) exit 0 ;;
  esac
  case "$rel" in
    *.erb|*.haml|*.slim|*.html|*.rb|*.css|*.js) ;;
    *) exit 0 ;;
  esac
  out=$(grep -nE "($HEX|$ARB|$PAL)" "$file" | grep -v 'design-ok' || true)
  [ -z "$out" ] && exit 0
  {
    echo "Design-system drift in $rel - token utilities only (no raw hex, no literal palette classes, no arbitrary [...] values):"
    printf '%s\n' "$out" | sed 's/^/  /'
    echo "Use the section's role tokens instead (see docs/design-system/). For a deliberate exception, put design-ok on that line."
  } >&2
  exit 2
fi

dirs=()
for d in app/views app/components app/frontend app/javascript app/assets/stylesheets; do
  [ -d "$d" ] && dirs+=("$d")
done
[ ${#dirs[@]} -eq 0 ] && { echo "No view directories found."; exit 0; }
total=0
scan() { # scan <label> <extended-regex>
  local label=$1 re=$2 out count=0
  out=$(grep -rInE \
        --include='*.erb' --include='*.haml' --include='*.slim' --include='*.html' \
        --include='*.rb' --include='*.css' --include='*.js' \
        "$re" "${dirs[@]}" 2>/dev/null \
        | grep -v 'design-ok' \
        | grep -vE '_mailer/|/layouts/mailer' \
        | grep -vE '(^|/)(tokens|theme)[^/]*\.css:' || true)
  [ -n "$out" ] && count=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
  total=$((total + count))
  echo "== $label: $count"
  [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/   /'
  echo
}
scan "raw hex colours" "$HEX"
scan "arbitrary values" "$ARB"
scan "literal palette classes" "$PAL"
if [ "$total" -eq 0 ]; then
  echo "No drift detected."
else
  echo "Fix findings by retokenising the view or adding a token to the section's tokens.md."
  echo "Never quiet a finding by weakening this script; mark deliberate exceptions with design-ok."
fi
```

4. Wire generation-time enforcement: add this hook to the app's `.claude/settings.json` (create the file if missing; if it exists, merge the entry without duplicating it and without touching existing hooks):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "bin/audit_design --hook" }]
      }
    ]
  }
}
```

The harness runs the hook after every agent file edit. Non-view files exit instantly; a token violation in view code is fed back to the agent as a blocking error, so it gets fixed the moment it is written - even by an agent that never read the context files.

Do not create any slash command for auditing: re-running this skill IS the audit (see "Re-runs: maintenance mode").

## Phase 4: Review

Show me every generated or edited file grouped in one message - docs and preview pages both. I will correct anything that misstates the design intent; my stated intent always outranks what you inferred from the views. Fold corrections in, then commit everything with a clear message.

Close every run - first run or maintenance - by running `bin/audit_design` and reporting what it still flags: items I chose to defer, plus anything the run didn't cover. Nothing flagged gets silently ignored. Suggest I open `docs/design-system/index.html` in a browser to review the style guide visually.

## Never do

- Share tokens, components, or code across sections, or create any shared folder.
- Emit a raw hex value, a literal palette class, or an arbitrary `[...]` value in any spec, recipe, or preview page.
- Restate a component's markup inside a pattern - patterns compose by reference.
- Paste a catalog entry into an app unadapted, or spec a component the section does not use.
- Write per-directory `CLAUDE.md` files - that is the rails-context skill's job, not this one's.
- Regenerate an existing doc or preview page when a surgical edit will do.
- Let a spec and its preview block, or a spec and its realized component, contradict silently - one of them is the bug; flag it.
- Restyle existing views beyond fixes I approved from the drift review.
