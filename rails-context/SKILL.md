---
name: rails-context
description: Set up and maintain per-directory CLAUDE.md context files in a Rails application (MVC Context — Model, View, Controller, plus Context). Surveys app/, lib/, and the test suite, proposes which directories deserve a context file, generates intent-focused CLAUDE.md files with AGENTS.md symlinks, and wires up drift auditing via bin/audit_context. Re-runnable: on an app already set up, a run audits existing context files for drift, fills gaps, and slims ancestors that repeat what deeper files own. Use when asked to set up MVC context, add per-directory agent context files, bootstrap CLAUDE.md/AGENTS.md files in a Rails app, or audit/refresh existing context files.
---

# MVC Context

You are setting up per-directory agent context files in this Rails application. Rails is MVC; this adds a fourth letter: Context. Follow this document exactly. Work through the phases in order and show me the plan after Phase 1 before writing anything.

This skill is re-runnable. The first run on an app sets everything up; every later run is maintenance — audit, gap-fill, repair — through the same phases and the same approval gate (see "Re-runs: maintenance mode" in Phase 1).

The approval gate is a hard stop. Write nothing until I approve this run's Phase 1 plan in a reply to that plan: "approve", "yes", "go", or edits to it. These are NOT approval: a reply about something else (handle it, then show the plan's open points again and wait); approval of an earlier, broader plan that only said this skill would run; your own decision to invoke this skill in the middle of other work. Every open question in the plan needs an answer, or my explicit "use your recommendation", before Phase 2 starts. Phase 4 is a second stop: show the changes and wait for my reply before committing, on first runs and maintenance runs alike.

## File naming convention

- The canonical context file is `CLAUDE.md`.
- `AGENTS.md` is a relative symlink to it, created inside the directory: `ln -s CLAUDE.md AGENTS.md`.
- All edits go to `CLAUDE.md`. Never write to `AGENTS.md` directly. Never use absolute paths in symlinks.
- If a directory already has a real (non-symlink) `AGENTS.md`, migrate it first:

```bash
git mv AGENTS.md CLAUDE.md
ln -s CLAUDE.md AGENTS.md
git add AGENTS.md
```

Move content unchanged in the migration commit. If a directory has BOTH a real `CLAUDE.md` and a real `AGENTS.md`, do not run the `mv` — show me the diff and ask how to merge before converting `AGENTS.md` into the symlink. Do not migrate the root `AGENTS.md` without asking me first.

## The one rule that matters: intent, not inventory

Context files describe the *shape* of a directory, never its *contents*.

- ALLOWED: "Services are single-purpose command objects named `VerbNoun`, exposing `.call` and returning a `Result`. API clients live under `app/services/clients/`, one class per provider."
- FORBIDDEN: file lists, class inventories, method listings, counts, "the main models are X, Y, Z".

Inventory goes stale the moment anyone adds a file, and a stale context file is worse than none. The code is the inventory; you can glob and grep. Context files answer what grep cannot: why it is structured this way, what a correct new addition looks like, what mistakes to avoid. If a sentence would need editing when someone adds one more file of the same kind, delete the sentence. One short illustrative code example per pattern is fine; copies of real classes are not. Never explain standard Rails behaviour, only what is specific to this app.

## Size discipline

Aim for 30-100 lines per `CLAUDE.md`. The limit is a density check, not a token budget: a directory file loads only when a file inside that directory is read, so length is cheap - but every line competes for the agent's attention, so padding is not, and growth is usually the first sign of inventory creep.

A file may grow past 100 lines only after passing this checklist:

1. No inventory and no generic Rails knowledge has crept in - cut those first.
2. No single namespace owns the growth - if one does, give it a nested context file and slim the parent to a pointer.
3. Everything that remains is app-specific intent an agent would otherwise get wrong.

150 lines or 10 KB, whichever comes first, is the review trigger: maintenance-mode size repair flags anything past it for a restructuring proposal. A file that big almost always contains a nested file waiting to be split out. Count bytes as well as lines: a file written in paragraph-long lines can hold 30 KB in 100 lines and never trip a line count.

The root `CLAUDE.md` is different: it loads in every session, so its size is a real token cost. Aim for under 8 KB; 200 lines or 12 KB is its review trigger. The root also collects content from other tools (`/init`, other skills, the user), so root size repair never cuts what this skill did not write without asking - it proposes moving directory-specific sections down into the directory file that owns them ("one fact, one level") and flags the rest for me.

## One fact, one level

Context files form a chain - root → `app/<dir>/` → nested namespace - and an agent working deep in the tree ends up with every file on that path in context. So every fact lives at exactly one level: the most specific level it applies to. A directory file never repeats the root; a nested file never repeats its parent. And it works upward too: when a more specific file exists (or gets created), the parent sheds whatever it covers, keeping only a one-line pointer ("`cloudflare/` — Cloudflare API wrapper; see its CLAUDE.md"). Deeper means more specific and shorter. A file restating something from another level is duplicate context, and duplicates drift.

How the chain loads matters. Claude Code loads the root `CLAUDE.md` at session start, but a directory's `CLAUDE.md` only when Claude reads a file in that directory with its Read tool. Shell reads (`cat`, `grep`), shell edits (`sed -i`, heredocs, scripts), and a new file written into a directory nothing was read from do not load it - and agents do much of their work through the shell. So the root block (Phase 3) tells agents to read the directory's context files before changing code there; never rely on automatic loading alone.

## Phase 1: Survey and plan

1. Read the `Gemfile`, the root `CLAUDE.md`/`AGENTS.md` if present, and list directories under `app/`, `lib/`, and `test/` (or `spec/`). `test/` qualifies only when the suite has non-obvious infrastructure (stub helpers, factory conventions, job-testing quirks), not merely because tests exist.
2. For each candidate directory, skim several representative files.
3. A directory qualifies for a context file when at least one is true:
   - 5+ files following a local convention (services, components, jobs).
   - Namespacing that encodes domain knowledge (e.g. `app/models/billing/`).
   - Code an agent would plausibly get wrong without guidance (API clients, state machines, money, multi-tenancy).
   Skip near-empty, purely generated, or entirely conventional directories (a vanilla `app/helpers/` gets nothing). Fewer, denser files beat blanket coverage.
4. A nested namespace gets its own file in two cases: its conventions differ from its parent's, or it encapsulates deep domain knowledge that would bloat the parent file — an external-provider wrapper (`app/services/cloudflare/`), a subsystem with its own vocabulary (`app/models/billing/`). Otherwise cover it in a short "Namespaces" section of the parent file.
5. Present me the list of directories you propose to cover, with one line each on what the file would say. Wait for my approval.

### Re-runs: maintenance mode

Re-running on an app that already has context files is maintenance, not a rewrite. The survey then also covers the existing context files, and the Phase 1 plan proposes four kinds of work:

- **Gap-fill**: new files for newly qualifying directories (start from the candidates `bin/audit_context` lists), missing `AGENTS.md` symlinks added, real `AGENTS.md` files migrated. A candidate that does not qualify gets added to the root `<!-- context-skip: ... -->` line instead, so it is not proposed again.
- **Drift review**: run `bin/audit_context` (if it doesn't exist yet, create it first — Phase 3). For each flagged pre-existing file, read the changed files and the current `CLAUDE.md`, then propose a surgical edit only where a documented pattern is now false or a new convention has emerged. Deleted files are the strongest signal: remove anything that still describes them. A flagged file that is still accurate gets reported as "checked, still accurate", and its `<!-- reviewed: YYYY-MM-DD -->` line (last line of the file; add it if missing) is set to today, so committing it resets the audit baseline and the flag clears — never edit content to look busy, and never silently skip a file.
- **One fact, one level repair**: where an existing file (the root included) states a fact that a deeper file owns — or will own after this run's gap-fill — propose slimming the ancestor to a one-line pointer.
- **Size repair**: flag files outside the size discipline (`bin/audit_context` reports them) - past the review trigger (150 lines or 10 KB; the root 200 lines or 12 KB), propose a restructuring (usually a nested-file split, or moving root content down); under the 30-line floor, note whether the file is legitimately short or missing its layer's substance.

Never regenerate an existing context file: every change to one is a surgical edit, listed in the plan and approved before writing. Phase 4 then reviews only what was newly written or changed. If the app has a `.claude/commands/context-audit.md` left over from an earlier version of this skill, propose deleting it — re-running this skill is now the audit.

## Phase 2: Generate

For each approved directory, read enough files to genuinely extract the conventions: naming, base classes, call signatures, return types, error handling, namespacing. Do not guess patterns; derive them from code. If files contradict each other, document the dominant pattern and flag the exceptions to me rather than inventing a rule.

Use this skeleton, omitting any section that would be empty or would restate Rails defaults:

```markdown
# app/<dir> - Context

## Purpose
One or two sentences: what belongs here and what does not.

## Conventions
Naming, base classes, file placement, call signatures.

## Patterns
The recurring shapes, each with at most one minimal example.

## Adding new code here
What a correct new addition looks like.

## Gotchas
Non-obvious constraints, deliberate deviations from Rails norms.
```

Per-layer generation guides ship with this skill in the `references/` directory that sits next to this SKILL.md — they are part of the skill, NOT files in the target app, so resolve their paths from this skill's own directory. You MUST read the matching guide immediately before generating each directory's context file (per file, not once upfront) — it lists the questions to answer from the app's code and shows the target density:

- `references/models.md`, `references/controllers.md`, `references/services.md`, `references/components.md`, `references/jobs.md`, `references/views.md`, `references/test.md`

The guides are prompts, not content: every statement in a generated file must still be derived from the target app's code, and their exemplar excerpts exist to show density and tone, never to be copied. A guide existing for a layer does NOT mean the app gets that file — only directories that already exist and qualified in Phase 1 get one. Never create a directory, and never write a context file for a layer the app doesn't use (no `app/services/` means no services file; the guide is simply irrelevant there).

For `lib/` and anything without a guide: use the skeleton; if you cannot fill Purpose and Conventions with app-specific content, tell me the directory does not need a file instead of writing filler.

After writing each `CLAUDE.md`, create the `AGENTS.md` symlink beside it.

If an ancestor file (the root included) already states a fact the new file now owns, slim the ancestor to a one-line pointer in the same commit. "One fact, one level" applies to pre-existing content too — the maintenance-mode rule against regenerating existing files does not forbid these surgical shed-edits; it requires them to be listed in the plan.

### Nested context files

An agent working in a nested directory gets the full chain of context files down to it (root → `app/services/` → `app/services/cloudflare/`), so a nested file contains ONLY the delta from its ancestors — never repeat a parent or root convention; duplication is drift waiting to happen. Keep nested files shorter (10-60 lines). Their value is the knowledge the code cannot show: the external system's auth model and rate limits, environment differences (sandbox vs live), invariants ("zone ids are cached at boot; never fetch per request"), known failure modes and how the app expects them handled. The same rules apply as everywhere else: intent not inventory, `AGENTS.md` symlink beside it, and the audit script picks nested files up automatically.

"One fact, one level" applies with force here: creating a nested file where the parent already covers the namespace means moving that content down and slimming the parent to a one-line pointer, in the same commit.

## Phase 3: Wire up maintenance

Append this block to the root context file (adapt wording to fit, keep the substance). If the app has no root `CLAUDE.md`, create one with this block as its content, plus the root `AGENTS.md` symlink if no `AGENTS.md` exists:

```markdown
## Context files (MVC Context)

Directories under app/, lib/, and the test suite carry their own CLAUDE.md
(symlinked as AGENTS.md) describing local conventions. Before changing code
in a directory, read its CLAUDE.md and those of its parents up to app/ - they
load automatically only when a file there is read with the Read tool, not
through shell commands. After changing code, before finishing the task,
check each directory you touched that has a CLAUDE.md and ask: did this change
introduce a new pattern, break a documented one, or add a new namespace or
convention? If yes, update that CLAUDE.md surgically - edit the affected lines
only, never regenerate the file. Routine changes that follow documented
patterns need no update. If a change deliberately contradicts a CLAUDE.md,
update the file to match the new reality and mention it. Context files
describe intent and patterns, never file inventories. Keep each directory
CLAUDE.md under 150 lines and 10 KB, and this root file under 200 lines and
12 KB: when an update would push a file past that, cut inventory or move the
growing part into a deeper CLAUDE.md instead of appending. Context file edits
ship in the same commit as the code change that caused them.
bin/audit_context reports drift; a periodic MVC Context maintenance run
works through what it flags.
```

Below the block, on its own line, record the directories you considered in Phase 1 and decided need no file, so the audit does not keep proposing them (Claude Code strips HTML comments from loaded context, so the line costs no tokens):

```markdown
<!-- context-skip: app/helpers app/mailers -->
```

Then create `bin/audit_context` (chmod +x) with this content:

```bash
#!/usr/bin/env bash
# Report drift between CLAUDE.md context files and the code they describe.
# Works from any directory: paths always resolve from the repo root.
# Output is a drift SIGNAL, not proof of staleness.
set -euo pipefail
cd "$(dirname "$0")/.."
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 1; }
found=0; drift=0
size_note() { # size_note <file> <max-lines> <max-bytes>: prints a note when over the review trigger
  local lines bytes
  lines=$(wc -l < "$1" | tr -d ' '); bytes=$(wc -c < "$1" | tr -d ' ')
  if [ "$lines" -gt "$2" ] || [ "$bytes" -gt "$3" ]; then
    echo "oversized: $lines lines, $((bytes / 1024)) KB (review trigger: $2 lines or $(($3 / 1024)) KB)"
  fi
}
if [ -f CLAUDE.md ]; then
  size=$(size_note CLAUDE.md 200 12288)
  [ -n "$size" ] && { drift=1; echo "== CLAUDE.md (root)"; echo "   $size"; echo; }
fi
while IFS= read -r legacy; do
  found=1; drift=1
  echo "== $legacy"
  echo "   real AGENTS.md - migrate: git mv AGENTS.md CLAUDE.md && ln -s CLAUDE.md AGENTS.md"
  echo
done < <(find app lib test spec -name AGENTS.md -type f 2>/dev/null | sort)
while IFS= read -r ctx; do
  found=1
  dir=$(dirname "$ctx")
  size=$(size_note "$ctx" 150 10240)
  last=$(git log -1 --format=%H -- "$ctx" 2>/dev/null || true)
  if [ -z "$last" ]; then
    echo "== $ctx"; echo "   never committed - commit it or review now"
    [ -n "$size" ] && echo "   $size"
    echo; drift=1; continue
  fi
  # "<status><TAB><path>" for every change since the file was last committed
  changes=$( { git diff --name-status "$last"..HEAD -- "$dir" 2>/dev/null \
                 | awk -F'\t' '{ print substr($1, 1, 1) "\t" $NF }' || true
               git status --porcelain -- "$dir" 2>/dev/null \
                 | awk '{ s = substr($0, 1, 2); gsub(/ /, "", s); print substr(s, 1, 1) "\t" $NF }' || true; } \
    | grep -v -e '/AGENTS\.md$' -e '/CLAUDE\.md$' || true)
  deleted=$(printf '%s\n' "$changes" | awk -F'\t' '$1 == "D" { print $2 }' | sort -u)
  all=$(printf '%s\n' "$changes" | awk -F'\t' '$1 != "D" && $2 != "" { print $2 }' | sort -u)
  note=""
  if [ ! -e "$dir/AGENTS.md" ] && [ ! -L "$dir/AGENTS.md" ]; then
    note="missing AGENTS.md symlink - run: (cd $dir && ln -s CLAUDE.md AGENTS.md)"
  elif [ -L "$dir/AGENTS.md" ] && [ "$(readlink "$dir/AGENTS.md")" != "CLAUDE.md" ]; then
    note="AGENTS.md symlink points to $(readlink "$dir/AGENTS.md"), expected CLAUDE.md"
  fi
  if [ -n "$all" ] || [ -n "$deleted" ] || [ -n "$note" ] || [ -n "$size" ]; then
    drift=1
    echo "== $ctx (last updated $(git log -1 --format=%cs -- "$ctx"))"
    [ -n "$note" ] && echo "   $note"
    [ -n "$size" ] && echo "   $size"
    if [ -n "$deleted" ]; then
      echo "   $(printf "%s\n" "$deleted" | wc -l | tr -d ' ') file(s) deleted since - remove anything that still describes them:"
      printf "%s\n" "$deleted" | sed 's/^/     - /'
    fi
    if [ -n "$all" ]; then
      echo "   $(printf "%s\n" "$all" | wc -l | tr -d ' ') file(s) changed since:"
      printf "%s\n" "$all" | sed 's/^/     - /'
    fi
    echo
  fi
done < <(find app lib test spec -name CLAUDE.md -type f 2>/dev/null | sort)
# Directories that may deserve a context file: 5+ source files, no CLAUDE.md in
# their tree, not covered by name in the parent's CLAUDE.md, and not listed in a
# "<!-- context-skip: app/helpers app/models/concerns -->" line in the root CLAUDE.md.
skip=" $( { sed -n 's/.*<!-- *context-skip: *\(.*\)-->.*/\1/p' CLAUDE.md 2>/dev/null || true; } | tr '\n' ' ' | sed 's#/ # #g') "
candidates=""
while IFS= read -r d; do
  [ -n "$(find "$d" -name CLAUDE.md -print -quit)" ] && continue
  case "$skip" in *" $d "*) continue ;; esac
  parent=$(dirname "$d")
  [ -f "$parent/CLAUDE.md" ] && grep -qF "$(basename "$d")/" "$parent/CLAUDE.md" && continue
  n=$(find "$d" -type f \( -name '*.rb' -o -name '*.erb' -o -name '*.js' -o -name '*.ts' -o -name '*.rake' \) | wc -l | tr -d ' ')
  [ "$n" -ge 5 ] && candidates+="     - $d ($n files)"$'\n'
done < <( { find app lib -mindepth 1 -maxdepth 1 -type d || true
            find app/models app/services app/controllers app/components app/jobs \
              -mindepth 1 -maxdepth 1 -type d || true
          } 2>/dev/null | grep -v '^app/assets' | sort -u)
if [ -n "$candidates" ]; then
  echo "Directories with 5+ files and no context file - give each one a CLAUDE.md, or"
  echo "list it in a <!-- context-skip: ... --> line in the root CLAUDE.md if it needs none:"
  printf '%s\n' "$candidates"
fi
[ "$found" -eq 0 ] && { echo "No context files found under app/, lib/, test/, or spec/."; exit 0; }
if [ "$drift" -eq 0 ]; then
  echo "No drift detected."
else
  echo "Review flagged directories: most changes are routine and need nothing."
  echo "Edit CLAUDE.md surgically only where a documented pattern changed."
  echo "Oversized files: cut inventory, or move a growing namespace into a nested CLAUDE.md."
fi
```

Do not create any slash command for auditing: re-running this skill IS the audit (see "Re-runs: maintenance mode").

## Phase 4: Review

Show me every generated or edited `CLAUDE.md` grouped in one message. I will correct anything that misstates intent; my stated intent always outranks what you inferred from code. Wait for my reply. Fold corrections in, then commit everything with a clear message once I approve. If I move on without answering, tell me once that the run's files are still uncommitted.

Close every run — first run or maintenance — by running `bin/audit_context` and reporting what it still flags: items I chose to defer, plus anything the run didn't cover. Nothing flagged gets silently ignored.

## Never do

- Put file or class inventories in context files.
- Create a directory, or write a context file for a directory the app doesn't have or barely uses — context files document what exists, they never scaffold.
- Duplicate content across levels: root content (setup, test commands, deploy) in subdirectory files, or parent conventions restated in nested files — every fact lives at exactly one level.
- Create files for directories with nothing non-obvious to say.
- Regenerate an existing context file when a surgical edit will do.
- Let a context file state something the code contradicts; the code is the truth and the context file is the bug.
