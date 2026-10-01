---
name: rails-design-system
description: Set up and maintain a design-system context repository at docs/design-system/ in a Rails app using Tailwind CSS v4. Detects the app's UI sections (admin, marketing, app...), then generates per-section role-token definitions, component specs, and page-pattern specs, plus a bin/audit_design drift script and an edit-time enforcement hook. Re-runnable, an app already set up gets maintenance - drift review, gap-fill - through the same approval gate. Use when asked to set up a design system, codify styles or UI conventions, keep views visually consistent, spec a component library, or audit design drift.
---

# Rails Design System

You are bootstrapping or maintaining a design-system context repository at `docs/design-system/` in this Rails application: the standard every view is built against. Follow this document exactly. Work through the phases in order and show me the plan after Phase 1 before writing anything.

This skill is re-runnable. The first run on an app sets everything up; every later run is maintenance - drift review, gap-fill - through the same phases and the same approval gate (see "Re-runs: maintenance mode" in Phase 1).

The approval gate is a hard stop. Write nothing, add no gem, and dispatch no generation agent until I approve this run's Phase 1 plan in a reply to that plan: "approve", "yes", "go", or edits to it. These are NOT approval: a reply about something else (handle it, then show the plan's open points again and wait); approval of an earlier, broader plan that only said this skill would run; your own decision to invoke this skill in the middle of other work. Every open question in the plan - the interview for sections with no views included - needs an answer, or my explicit "use your recommendation", before Phase 2 starts. Phase 4 is a second stop: show the changes and wait for my reply before committing, on first runs and maintenance runs alike.

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

Everything you write - specs, recipes, proposed fixes - uses token-based Tailwind utilities only. Never a raw hex value, never a literal palette class (`bg-gray-100`, `text-indigo-600`), never an arbitrary `[...]` value. This is the rule the whole standard rests on: it makes drift mechanically detectable (`bin/audit_design` is three greps), so breaking it once makes every audit a lie. A value not on the section's scale is drift, by definition.

## Specs, not code

Canonical recipes are pure HTML plus Tailwind classes - view-layer neutral. Every component contract enumerates its axes (variant, size, tone - closed lists, never open-ended) and its states: default, hover, focus-visible, active, disabled, and loading where it submits. A component missing focus-visible is incomplete.

Realising a spec as an ERB partial, ViewComponent, or Phlex class happens during normal feature work, guided by the matching `adapters/` guide (chosen by Gemfile); this skill writes specs, it never mass-generates components. Generated docs carry no YAML frontmatter - there is no machine consumer; the audit greps classes, not metadata.

## Phase 1: Survey and plan

Delegate steps 1-4 to one read-only subagent when the environment provides subagents - fact-gathering only: it reports back Tailwind version, entry and compiled CSS paths, view layer, candidate sections with their evidence, representative-view observations, and any existing design docs. Build the plan from its report yourself: the plan, the approval conversation, and every decision stay in the main session. Run the survey inline if subagents are unavailable.

1. Read the `Gemfile` and lockfile: view layer (`phlex-rails`, `view_component`, or plain ERB) and Tailwind. **Tailwind CSS v4 is a hard requirement.** No Tailwind at all: stop and tell me this skill needs it. Tailwind v3 (a `tailwind.config.js` and a pre-4 version): stop and advise upgrading to v4 first. Confirm v4 by version number and by the `@import "tailwindcss"` / `@theme` entry-point CSS.
2. Locate the Tailwind entry CSS (where `@theme` lives or will live).
3. Detect candidate sections. Evidence, strongest first: layouts in `app/views/layouts/`, controller namespaces, route namespaces. An `Api::` namespace with no HTML views is not a section. Skim representative views per candidate to judge whether its look genuinely diverges.
4. Read `docs/design-system/` if it exists - that switches the run into maintenance mode (below).
5. Present the plan: sections found with their evidence, and per section every file that would be written or edited, one line each on what it would say. Flag the section split explicitly - it is the expensive-to-change decision - and state how many subagents the run will use (one survey agent plus one generation agent per section), so the fan-out is approved, never a surprise. Wait for my approval.

### Re-runs: maintenance mode

Re-running on an app that already has `docs/design-system/` is maintenance, not a rewrite. The survey then also covers the existing docs, and the Phase 1 plan proposes five kinds of work:

- **Gap-fill**: newly detected sections; components or patterns now in use but unspecced; missing or outdated enforcement wiring (the hooks in `.claude/settings.json` must match Phase 3 of this skill version - an older entry with the relative command `bin/audit_design --hook` fails from subfolders and gets replaced).
- **Drift review**: run `bin/audit_design` (if it is missing or differs from the script in Phase 3 of this skill version, create or update it first). Each finding becomes a proposed fix - retokenise the view, or add a missing token to the section's `tokens.md` - never a silent skip.
- **Promotion**: the same one-off markup repeated in a section's views becomes a proposed component spec in that section's library.
- **Spec-vs-realized drift**: read each spec's "Realized as" file; where code and spec contradict, propose which side changes - never let them disagree silently.
- **Divergences ledger**: record newly collapsed variants; mark migrated ones done.

Never regenerate an existing doc: every change is a surgical edit, listed in the plan and approved before writing. Section-scoped maintenance work (drift fixes, gap-fill) may be dispatched to per-section subagents exactly like Phase 2 generation, behind the same approved plan. If the app has HTML style-guide pages under `docs/design-system/` or a `docs/design-system` `@source` directive in its Tailwind entry CSS left over from an earlier version of this skill, propose deleting them - the style guide is no longer part of the system.

## Phase 2: Generate

Sections are islands, so they generate in parallel: dispatch one subagent per approved section (run inline when subagents are unavailable, or for a single small section). Before dispatching, resolve everything that needs my input - in particular the interview for sections with no views - so each agent's prompt already carries the answers; a generation agent never asks me anything. Each agent's prompt must scope it to its section only and include: the approved file list, the section's token prefix, the interview answers, the path to this skill's directory, and the instruction to follow this Phase's rules - reading the matching `references/` guide immediately before each file, and the `catalog/` map when speccing components. When every agent has returned, check the output against the doctrine (token purity, no cross-section references) before moving on.

Each section, whether dispatched or inline, is generated in dependency order: `design.md` → `tokens.md` → `components/*.md` → `patterns/*.md` → `divergences.md`. After all sections, write the shared router `docs/design-system/README.md` yourself - it is the only cross-section file.

Generation guides ship with this skill in `references/` next to this SKILL.md - they are part of the skill, NOT files in the target app, so resolve their paths from this skill's own directory. You MUST read the matching guide immediately before generating each file (per file, not once upfront):

- `references/design.md`, `references/tokens.md`, `references/component-spec.md`, `references/pattern-spec.md`, `references/divergences.md`, `references/readme-router.md`

Rules that govern all generation:

- Derive tokens and aesthetics from the section's existing views: collect the utilities actually used, canonicalise by frequency, and record every collapsed value in the divergences ledger. Where the section has no views yet, interview me instead of inventing a design language.
- When speccing a component, look it up in `catalog/README.md` (beside this SKILL.md) and load the mapped catalog file as raw material. Re-shape it to the section's tokens and the app's real markup; never paste an entry unadapted. A component with no catalog entry gets its spec derived from the app's own markup using `references/component-spec.md` alone.
- Only spec components and patterns the section actually uses or the approved plan listed. Never scaffold the whole catalog into an app.
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
in the same commit. If a needed
component has no spec, spec it first rather than hand-rolling a one-off.
bin/audit_design reports drift, and Claude Code hooks (bin/audit_design
--hook after each edit, --stop before each turn ends) block token violations
in new code; a periodic design-system maintenance run works through what the
audit flags.
```

2. Create `bin/audit_design` (chmod +x) with this content:

```bash
#!/usr/bin/env bash
# Report design drift: colours and utilities that bypass the design-system tokens.
# Works from any directory: paths always resolve from the repo root.
# Findings are drift signals to review, not proof of defects.
# Mark a deliberate exception by putting "design-ok" on the same line.
# Mailer templates are exempt: email clients require inline styles.
# Modes:
#   bin/audit_design         scan the app and report; always exits 0
#   bin/audit_design --hook  Claude Code PostToolUse hook (Write|Edit): reads the
#                            tool-call JSON from stdin and checks the edited file
#   bin/audit_design --stop  Claude Code Stop/SubagentStop hook: checks every view
#                            file changed in the working tree, which catches edits
#                            made through Bash, generators, or subagents
# Both hook modes check only lines added since HEAD (the whole file if untracked),
# so old drift elsewhere in a file never blocks an unrelated edit. They exit 2
# with findings on stderr so the agent fixes them before moving on.
set -euo pipefail
orig=$PWD
cd "$(dirname "$0")/.."
root=$PWD
# A hex colour never follows a letter, digit, "_", "-", "." or "&": "cart#add" is a
# Stimulus action, "this.#fade" a private JS field, "&#123;" an HTML entity.
HEX='(^|[^0-9a-zA-Z_.&-])#([0-9a-fA-F]{6}|[0-9a-fA-F]{8}|[0-9a-fA-F]{3,4})([^0-9a-zA-Z_-]|$)'
# Arbitrary values: w-[260px], bg-[var(--x)], and the v4 shorthand bg-(--x). A
# bracket followed by ":" (or "/name:") is a variant selector such as
# data-[state=open]: - Tailwind grammar, not a value - and passes.
ARB='[a-z][a-z0-9:-]*-(\[[^]]+\]|\(--[^)]+\))([^:/]|/[0-9]|$)'
PAL='(bg|text|border|ring|divide|outline|fill|stroke|from|via|to|accent|decoration|placeholder|caret|shadow)-(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-[0-9]{2,3}'

in_scope() { # in_scope <repo-relative path>
  case "$1" in
    *_mailer/*|*layouts/mailer*|*tokens*.css|*theme*.css) return 1 ;;
    app/views/*|app/components/*|app/frontend/*|app/javascript/*|app/assets/stylesheets/*) ;;
    *) return 1 ;;
  esac
  case "$1" in
    *.erb|*.haml|*.slim|*.html|*.rb|*.css|*.js) return 0 ;;
    *) return 1 ;;
  esac
}

added_findings() { # added_findings <repo-relative path>: violating lines added since HEAD
  if git rev-parse -q --verify HEAD >/dev/null 2>&1 && git cat-file -e "HEAD:$1" 2>/dev/null; then
    git diff -U0 HEAD -- "$1" | awk '
      /^@@/ { split($3, a, ","); n = substr(a[1], 2) + 0; hunk = 1; next }
      hunk && /^\+/ { print n ": " substr($0, 2); n++ }'
  else
    grep -n '' -- "$1" | sed 's/:/: /'
  fi | grep -E "($HEX|$ARB|$PAL)" | grep -v 'design-ok' | sed "s|^|  $1:|" || true
}

block() { # block <findings>
  {
    echo "Design-system drift - token utilities only (no raw hex, no literal palette classes, no arbitrary [...] values):"
    printf '%s\n' "$1"
    echo "Use the section's role tokens instead (see docs/design-system/). For a deliberate exception, put design-ok on that line."
  } >&2
  exit 2
}

if [ "${1:-}" = "--hook" ]; then
  file=$(ruby -rjson -e 'puts JSON.parse($stdin.read).dig("tool_input", "file_path").to_s' 2>/dev/null || true)
  [ -n "$file" ] || exit 0
  case "$file" in /*) ;; *) file="$orig/$file" ;; esac
  rel=${file#"$root"/}
  [ "$rel" = "$file" ] && rel=${file#"$(pwd -P)"/}
  { [ -f "$rel" ] && in_scope "$rel"; } || exit 0
  out=$(added_findings "$rel")
  [ -z "$out" ] || block "$out"
  exit 0
fi

if [ "${1:-}" = "--stop" ]; then
  # stop_hook_active means the agent was already sent back once: never loop.
  if grep -qE '"stop_hook_active" *: *true'; then exit 0; fi
  out=""
  while IFS= read -r rel; do
    { [ -f "$rel" ] && in_scope "$rel"; } || continue
    found=$(added_findings "$rel")
    [ -z "$found" ] || out+="$found"$'\n'
  done < <({ git diff --name-only HEAD 2>/dev/null || true; git ls-files --others --exclude-standard; } | sort -u)
  [ -z "$out" ] || block "${out%$'\n'}"
  exit 0
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

3. Wire generation-time enforcement: add these hooks to the app's `.claude/settings.json` (create the file if missing; if it exists, merge the entries without duplicating them and without touching unrelated hooks; replace any older `bin/audit_design --hook` entry that uses a relative command):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/bin/audit_design --hook" }]
      }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/bin/audit_design --stop" }] }
    ],
    "SubagentStop": [
      { "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/bin/audit_design --stop" }] }
    ]
  }
}
```

The harness runs hooks in the session's current directory, which moves whenever the agent `cd`s, so the command must be anchored on `$CLAUDE_PROJECT_DIR` - a relative `bin/audit_design` fails from any subfolder. The PostToolUse hook checks each Write/Edit the moment it lands. Agents also write views through Bash (heredocs, `sed -i`, scripts) and generators, which no tool matcher sees, so the Stop and SubagentStop hooks check every changed view file in the working tree before a turn ends. Both modes check only lines added since HEAD, and a violation is fed back to the agent as a blocking error, so it gets fixed before the work is handed back - even by an agent that never read the context files.

Do not create any slash command for auditing: re-running this skill IS the audit (see "Re-runs: maintenance mode").

## Phase 4: Review

Show me every generated or edited file grouped in one message. I will correct anything that misstates the design intent; my stated intent always outranks what you inferred from the views. Wait for my reply. Fold corrections in, then commit everything with a clear message once I approve. If I move on without answering, tell me once that the run's files are still uncommitted.

Close every run - first run or maintenance - by running `bin/audit_design` and reporting what it still flags: items I chose to defer, plus anything the run didn't cover. Nothing flagged gets silently ignored.

## Never do

- Share tokens, components, or code across sections, or create any shared folder.
- Emit a raw hex value, a literal palette class, or an arbitrary `[...]` value in any spec or recipe.
- Restate a component's markup inside a pattern - patterns compose by reference.
- Paste a catalog entry into an app unadapted, or spec a component the section does not use.
- Write per-directory `CLAUDE.md` files - that is the rails-context skill's job, not this one's.
- Regenerate an existing doc when a surgical edit will do.
- Let a spec and its realized component contradict silently - one of them is the bug; flag it.
- Restyle existing views beyond fixes I approved from the drift review.
