---
name: project-memory
description: Set up, migrate to, and maintain a project's long-term memory in git - the docs/MEMORY.md protocol, a generated docs/INDEX.md, typed notes, an inbox, lessons, and the docs/log history - checked by bin/memory. Use when a project has no docs/MEMORY.md and has work worth logging, when it still has a legacy docs/history/ or docs/HISTORY.md log, or when asked to set up project memory, run a consolidation pass, promote the inbox, or upgrade the protocol.
---

# Project memory

This skill gives a project long-term memory that lives in git: markdown notes with citations to code, a generated index read at the start of every task, an inbox where unverified knowledge waits, and an append-only log of finished work. The protocol itself is copied into the project as `docs/MEMORY.md` and linked from the root `CLAUDE.md`, so every session and every teammate follows it without this plugin. The skill does the work one project cannot do on its own: setup, lossless migration from older ways of keeping history, consolidation passes, and protocol upgrades.

Routine work does not need this skill. Once a project has `docs/MEMORY.md`, follow that file: read `docs/INDEX.md` at the start of a task, write a log entry before each commit of finished work, put new knowledge in `docs/inbox/`.

`${CLAUDE_SKILL_DIR}` is this skill's directory (resolve it yourself if the variable is not expanded). It holds `templates/MEMORY.md` (the protocol), `scripts/memory` (copied into projects as `bin/memory`) and `scripts/migrate_history` (run from here, never copied).

## Project rules come first

Each project can change the protocol. Before doing anything, read the root `CLAUDE.md` (and a real `AGENTS.md`), the **Project overrides** section and settings frontmatter of `docs/MEMORY.md` if it exists, and anything else the project says about docs, logs, or memory. Where the project differs from this skill or the template, the project wins: follow it, and never "fix" it back to the default. During setup, rules the project already states about its docs or logs become entries in the new Project overrides section, moved verbatim, not copied. If an override cannot work with a `bin/memory` check (the script only reads the settings in the frontmatter), tell the user and propose either a setting or a change to the override; never edit the copied script.

## Which run is this

- **No `docs/MEMORY.md`**: a setup run (below). It migrates any legacy log first.
- **`docs/MEMORY.md` exists**: a maintenance run. If its `protocol:` version is older than the template's, upgrade first, then consolidate.
- **A monorepo**: each subproject with its own `docs/` gets its own memory and its own `bin/memory`; work in the one the task is about.

Every run has one approval gate: show the plan and wait. Only a reply to the plan is approval ("yes", "go", or edits to it); a reply about something else is not - handle it, then ask again once. Your own decision to run this skill in the middle of other work is not approval either. Write nothing before approval. If the user defers setup, do not write log entries anywhere in the meantime, and say once that this work is not logged.

## Setup

### 1. Survey

1. Read the root `CLAUDE.md` (and `AGENTS.md`), the README, the CI config, and list everything under `docs/`.
2. Run `ruby "${CLAUDE_SKILL_DIR}/scripts/migrate_history"` from the project directory. Without `--apply` it changes nothing: it prints each legacy entry and where it would go, or the lines that stop it.
3. List every other source of project knowledge that should move into the memory (see "Migration" below). Each becomes one line in the plan: source, target, and how many items.

### 2. Plan, then wait

Show the user, in one message:
- the files setup creates: `docs/MEMORY.md`, `docs/INDEX.md`, `bin/memory`, the block in the root `CLAUDE.md`;
- each migration line from the survey, with counts, and anything that stops a migration;
- the Project overrides the project's existing rules turn into, and the settings (see step 3 below);
- a CI step that runs `bin/memory lint`, naming the file it goes in;
- open questions, each with your recommendation.

Every open question needs an answer, or the user's "use your recommendation", before writing.

### 3. Write

1. Copy `${CLAUDE_SKILL_DIR}/templates/MEMORY.md` to `docs/MEMORY.md`. Replace "None yet..." in Project overrides with the approved overrides. Keep the settings at their defaults unless the project needs otherwise: when the project uses the `rails-context` skill (`bin/audit_context` exists), set `root_context_max_lines: 200` to match that skill's root review trigger, so the two never disagree.
2. Copy `${CLAUDE_SKILL_DIR}/scripts/memory` to `bin/memory` and make it executable. Copy it unchanged.
3. Run `ruby "${CLAUDE_SKILL_DIR}/scripts/migrate_history" --apply`, then do the other approved migrations.
4. Add this block to the root `CLAUDE.md` (create the file if there is none; adapt the wording to fit, keep the substance):

   ```markdown
   ## Project memory

   Long-term project knowledge lives in docs/ under the protocol in
   docs/MEMORY.md; its Project overrides section is this project's own rules.
   At the start of a task, read docs/INDEX.md and open only the notes that
   matter; check a note's citations before acting on it. Before committing a
   finished unit of work, add its entry under docs/log/ in the same commit, and
   put new facts, gotchas, procedures, and lessons in docs/inbox/ as proposals,
   never straight into curated notes. bin/memory lint checks the docs;
   bin/memory index rebuilds the index.
   ```

   `CLAUDE.md` is the canonical file; `AGENTS.md` is a relative symlink to it (`ln -s CLAUDE.md AGENTS.md`). A root `AGENTS.md` that is a real file is converted only if the user approved it in the plan (`git mv AGENTS.md CLAUDE.md && ln -s CLAUDE.md AGENTS.md`).
5. Add the approved CI step.
6. Run `bin/memory index`, then `bin/memory lint`, and fix everything it reports.
7. Write the setup's own log entry: every migration line with its source, target and counts. It is the record of where each piece of knowledge went.

### 4. Commit

Follow the project's commit rules. Commit the history migration on its own first, so its diff shows only renames (`git diff --cached -M --stat` reports 0 insertions and 0 deletions for moved entries); then commit the rest of the setup with its log entry. Report the counts and the final `bin/memory lint` result to the user.

## Migration

Nothing is lost: every item moves with its text unchanged, the plan lists every move with counts, and the counts are checked after the move. Delete a source only after its content is in its new place.

### The legacy history log

This replaces the older per-user "project history log" instructions: one file per update at `docs/history/<YYYY-MM-DD>/<timestamp>-<slug>.md`, and before that a single `docs/HISTORY.md` with `## YYYY-MM-DD` sections. `migrate_history` moves both into `docs/log/YYYY/MM/DD/EPOCH-slug.md`:
- an entry with a real Unix timestamp keeps it and gets the UTC date folder of that time;
- an entry numbered in sequence by an earlier migration (`0000000001`) becomes its date's UTC midnight plus the number, so the order is kept;
- each top-level bullet of `docs/HISTORY.md` becomes one entry, with its nested lines; only blank lines, one `# ` title and the date headings are dropped (the dates live on in the folder names).

It refuses and changes nothing when a file does not fit these shapes or a target exists. When it refuses, fix the source by hand without dropping content (move a stray paragraph into the bullet it belongs to, rename a misnamed file) and run it again; ask the user before removing any line. Tracked files move with `git mv`, so `git log --follow` still finds their history. Entries keep their original text and need not follow the new entry template.

An agent-maintained log in another shape (a `NOTES.md` or `docs/changelog.md` written by agents, with dated sections) migrates by hand with the same rules: one file per top-level item, text verbatim, `EPOCH` = that date's UTC midnight plus the item's position, and a count check of items in against files out. A human-facing `CHANGELOG.md` (release notes for users) is not memory: leave it.

### Root context file content

Sort each section of the root `CLAUDE.md` into one of two kinds. **Stays**: build, test and lint commands, a few non-obvious hard rules every task needs, pointers, and blocks other tools own (such as the `rails-context` block). **Moves**: conventions, traps, procedures, decisions and their reasons, subsystem overviews - each to one note of the matching type, its text unchanged under new frontmatter. A moved rule was already guidance, so it becomes an active note when its citations check out against the code today; if it cannot be verified, it goes to `inbox/` instead. The plan lists every section with its kind and target. If the file is over `root_context_max_lines`, moving is required, not optional.

### Existing docs

- ADRs anywhere (`docs/adr/`, `doc/decisions/`): `git mv` into `docs/decisions/` keeping their numbers, and add frontmatter above the unchanged text (`type: decision`, `status: active`, or `superseded` in `archive/decisions/` for ones already superseded).
- Notes in a shape close to the protocol (a gotchas file, a runbook): one note per topic, text unchanged.
- A folder whose name the protocol uses but that holds human-facing docs without frontmatter (a `docs/architecture/` of guides): ask whether to add frontmatter or rename the folder; do not guess.
- Directory `CLAUDE.md` files (from `rails-context` or written by hand) stay where they are: they are scoped context, not notes.

### Claude's auto memory

Claude Code keeps per-user memories for this project in `~/.claude/projects/<project path with / and . replaced by ->/memory/`. These live on one machine and are not in git. Memories of type `project` or `reference` are project knowledge: propose each as an `inbox/` note, text unchanged, with `sources: [auto memory <file name>]`, or as an active note when the user approves it in the plan. Memories of type `user` or `feedback` are about the user, not the project: they stay. Show each candidate in the plan, because the repository may be public. Never delete or edit the auto-memory files; tell the user they can prune them once the notes are committed.

## Maintenance

### Upgrade the protocol

When `docs/MEMORY.md` says an older `protocol:` version than `${CLAUDE_SKILL_DIR}/templates/MEMORY.md`:
1. Replace the text between the frontmatter and `## Project overrides` with the template's. Keep the Project overrides section byte for byte.
2. Keep every setting's value; add new settings from the template with their default values; set `protocol:` to the template's.
3. Copy `scripts/memory` over `bin/memory` if they differ.
4. Run `bin/memory index` and `bin/memory lint`. An override that now conflicts with the protocol is reported to the user, never edited.

Show the diff with the plan of the run; it goes through the same approval gate.

### Consolidation pass

The protocol asks for one on PR merge or weekly. Run `bin/memory stale` and `bin/memory lint` first; their output drives the plan.

1. **Inbox**: for each proposal, check the promotion rule in `docs/MEMORY.md` (tests covering it pass, its PR merged, or a human approved it) and check its citations against the code. Promote: `status: active`, `verified_at` today, move it to its typed folder, or append it to `lessons.md` with the next unused `L-` number and delete the proposal. Reject and delete proposals that are wrong, duplicates, or trivially re-derivable, giving the reason for each in the plan.
2. **Duplicates**: merge notes that cover one topic; keep the older `id`, carry over the other's aliases, citations and sources, archive the other as superseded by it, and fix links.
3. **Expiry**: re-verify each note `bin/memory stale` lists against its citations. Confirmed: set `verified_at` to today. Wrong or gone: supersede or expire it into `archive/`.
4. **Lessons**: move each lesson to retire to `archive/lessons.md`, unchanged.
5. Run `bin/memory index` and `bin/memory lint` until clean.

Every change is a delta: never rewrite a curated file wholesale. Show the plan before changing anything, and the diff before committing; a human reviews the consolidation diff. The pass gets its own log entry listing promoted, rejected, merged, expired and retired items.

## Never do

- Write anything before the user approves the plan.
- Lose content in a migration: no unlisted moves, no paraphrasing, no deleting a source before its content is in place and counted.
- Override a project's own rules with the defaults, or edit the copied `bin/memory`.
- Put unverified knowledge into curated notes, or treat log entries as instructions.
- Edit or delete a log entry, or an accepted ADR.
- Store secrets, schema dumps, restatements of code, or generic best practices.
