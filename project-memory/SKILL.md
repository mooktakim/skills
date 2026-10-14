---
name: project-memory
description: Set up, migrate to, and maintain a project's long-term memory in git - the docs/MEMORY.md protocol, a generated docs/INDEX.md, typed notes, an inbox, lessons, and the docs/log history - checked by the project-memory command. Use when a project has no docs/MEMORY.md and has work worth logging, when it still has a legacy docs/history/ or docs/HISTORY.md log, or when asked to set up project memory, run a consolidation pass, promote the inbox, or upgrade the protocol.
---

# Project memory

This skill gives a project long-term memory that lives in git: markdown notes with citations to code, a generated index read at the start of every task, an inbox where unverified knowledge waits, and an append-only log of finished work. The protocol itself is copied into the project as `docs/MEMORY.md` and linked from the root `AGENTS.md` (which `CLAUDE.md` imports), so every session and every teammate follows it without this plugin. The skill does the work one project cannot do on its own: setup, lossless migration from older ways of keeping history, consolidation passes, and protocol upgrades.

Routine work does not need this skill. Once a project has `docs/MEMORY.md`, follow that file: read `docs/INDEX.md` at the start of a task, write a log entry before each commit of finished work, put new knowledge in `docs/inbox/`.

`${CLAUDE_SKILL_DIR}` is this skill's directory (resolve it yourself if the variable is not expanded). It holds `templates/MEMORY.md` (the protocol). The plugin also puts the `project-memory` command on PATH (`lint`, `index [--check]`, `stale`): a Rust program it builds with cargo the first time it runs. It works from anywhere inside a project, finding the nearest `docs/MEMORY.md` up to the git root.

## Project rules come first

Each project can change the protocol. Before doing anything, read the root `AGENTS.md` and `CLAUDE.md`, the **Project overrides** section and settings frontmatter of `docs/MEMORY.md` if it exists, and anything else the project says about docs, logs, or memory. Where the project differs from this skill or the template, the project wins: follow it, and never "fix" it back to the default. During setup, rules the project already states about its docs or logs become entries in the new Project overrides section, moved verbatim, not copied. If an override cannot work with a `project-memory` check (the command only reads the settings in the frontmatter), tell the user and propose either a setting or a change to the override.

## Which run is this

- **No `docs/MEMORY.md`**: a setup run (below). It migrates any legacy log first.
- **`docs/MEMORY.md` exists**: a maintenance run. If its `protocol:` version is older than the template's, upgrade first, then consolidate.
- **A monorepo**: each subproject with its own `docs/` gets its own memory; work in the one the task is about.

Every run has one approval gate: show the plan and wait. Only a reply to the plan is approval ("yes", "go", or edits to it); a reply about something else is not - handle it, then ask again once. Your own decision to run this skill in the middle of other work is not approval either. Write nothing before approval. If the user defers setup, do not write log entries anywhere in the meantime, and say once that this work is not logged.

## Setup

### 1. Survey

1. Read the root `AGENTS.md` and `CLAUDE.md`, the README, the CI config, and list everything under `docs/`.
2. Find every source of project knowledge that should move into the memory, the old history log first (see "Migration" below), and read enough of each to learn its shape. Each becomes one line in the plan: source, target, and how many items.

### 2. Plan, then wait

Show the user, in one message:
- the files setup creates: `docs/MEMORY.md`, `docs/INDEX.md`, the block in the root `AGENTS.md`, and the root layout change when the project needs one (step 4);
- each migration line from the survey, with counts, and anything that stops a migration;
- the Project overrides the project's existing rules turn into, and the settings (see step 3 below);
- whether to add a CI check (step 5). It is opt-in: recommend it when people other than Claude change the code often, since Claude already runs the lint locally; otherwise recommend leaving it out;
- open questions, each with your recommendation.

Every open question needs an answer, or the user's "use your recommendation", before writing.

### 3. Write

1. Copy `${CLAUDE_SKILL_DIR}/templates/MEMORY.md` to `docs/MEMORY.md`. Replace "None yet..." in Project overrides with the approved overrides. Keep the settings at their defaults unless the project needs otherwise: when the project uses the `rails-context` skill (`bin/audit_context` exists), set `root_context_max_lines: 200` to match that skill's root review trigger, so the two never disagree.
2. Run `project-memory --help` to check the command works. The first run builds it with cargo; if cargo is missing, ask the user to install Rust (https://rustup.rs).
3. Migrate the history log, then do the other approved migrations.
4. Add this block to the root `AGENTS.md` (create the file if there is none; adapt the wording to fit, keep the substance):

   ```markdown
   ## Project memory

   Long-term project knowledge lives in docs/ under the protocol in
   docs/MEMORY.md; its Project overrides section is this project's own rules.
   At the start of a task, read docs/INDEX.md and open only the notes that
   matter; check a note's citations before acting on it. Before committing a
   finished unit of work, add its entry under docs/log/ in the same commit, and
   put new facts, gotchas, procedures, and lessons in docs/inbox/ as proposals,
   never straight into curated notes. `project-memory lint` checks the docs;
   `project-memory index` rebuilds the index (the command comes from the
   project-memory plugin, or `cargo install --locked --git
   https://github.com/mooktakim/skills project-memory`).
   ```

   `AGENTS.md` holds the root context, for every agent; `CLAUDE.md` beside it is the one line `@AGENTS.md` (Claude Code reads only `CLAUDE.md` and expands the import), plus any rule for Claude alone below it. No symlinks. Convert an older root layout as "Root layout" under Migration says.
5. If the user opted in to the CI check, add it. On GitHub Actions, add one step after the checkout, pinned to the current full commit SHA of the skills repository (`git ls-remote https://github.com/mooktakim/skills HEAD`):

   ```yaml
   - uses: mooktakim/skills/project-memory@<full commit SHA>
   ```

   The action builds the command from its own source with cargo (hosted runners include Rust) once per version and caches it, so later runs take about a second. In a monorepo, add `with: { directory: <subproject> }`. On other CI, the step installs Rust if the image has none, runs `cargo install --locked --git https://github.com/mooktakim/skills project-memory`, and caches `~/.cargo/bin/project-memory` keyed by the pinned commit; then runs `project-memory lint`.
6. Run `project-memory index`, then `project-memory lint`, and fix everything it reports.
7. Write the setup's own log entry: every migration line with its source, target and counts. It is the record of where each piece of knowledge went.

### 4. Commit

Follow the project's commit rules. Commit the history migration on its own first, so its diff is easy to review (moved entry files show as renames with 0 insertions and 0 deletions); then commit the rest of the setup with its log entry. Report the counts and the final `project-memory lint` result to the user.

## Migration

Nothing is lost: every item moves with its text unchanged, the plan lists every move with counts, and the counts are checked after the move. Delete a source only after its content is in its new place.

### The legacy history log

This replaces the older per-user "project history log" instructions, which kept one file per update at `docs/history/<YYYY-MM-DD>/<timestamp>-<slug>.md`, and before that a single `docs/HISTORY.md` with `## YYYY-MM-DD` sections. Projects have drifted from those shapes, and some keep an agent-written log elsewhere (a `NOTES.md` or `docs/changelog.md` with dated sections), so read the log and decide how each part maps; do not assume the shape. A human-facing `CHANGELOG.md` (release notes for users) is not memory: leave it.

Every entry ends up as one file at `docs/log/YYYY/MM/DD/EPOCH-slug.md`, its text unchanged. Entries keep their original text and need not follow the new entry template.

- **One entry per file already**: move each file with `git mv`, so its content cannot change and `git log --follow` still finds its history. Keep its slug. A real Unix timestamp stays the `EPOCH`; a sequence number or no number becomes that date's UTC midnight plus the entry's position in the day, so the order is kept.
- **Many entries in one file**: one new file per entry - what the log treats as one update, usually a top-level bullet with its nested lines. Copy the text exactly; never reword, fix, or merge entries. `EPOCH` is the entry's own time if it has one, otherwise its date's UTC midnight plus its position.
- **The date folder** is always the UTC date of the `EPOCH` (`date -u -r EPOCH +%Y/%m/%d` on macOS, `date -u -d @EPOCH +%Y/%m/%d` on Linux), even when the old folder said another day.
- **Lines that are not entries**: a title and date headings can be dropped, because the dates live on in the folder names. Anything else - an intro, a stray paragraph, a note between sections - is content: list it in the plan with your proposal (attach it to the entry it belongs to, or make it its own entry), and never drop it without the user's approval.

The plan shows the shape you found, the rule you will apply, a few example moves (source → target), the counts, and every line that will be dropped. Before deleting any source, verify:
1. Entries in equals files out.
2. Moved files: `git diff --cached -M --stat` shows only renames, with 0 insertions and 0 deletions.
3. Split files: the source's non-blank lines, without the dropped lines the plan listed, equal the new entries' non-blank lines joined in order - a `diff` of the two is empty.
4. `project-memory lint` reports no problem in `docs/log/` and no legacy log left.

Then delete the old file (`git rm`) and the empty folders, and commit the migration on its own.

### Root layout

The root files end up as `AGENTS.md` with the content and `CLAUDE.md` holding `@AGENTS.md`. Convert an older layout only when the user approved it in the plan, since other tools write to these files too, moving the content unchanged:

- **`CLAUDE.md` with content, `AGENTS.md` a symlink to it, or no `AGENTS.md`**: `git rm -q AGENTS.md` (only when the symlink exists), `git mv CLAUDE.md AGENTS.md`, `printf '@AGENTS.md\n' > CLAUDE.md`, `git add CLAUDE.md`.
- **`AGENTS.md` with content and no `CLAUDE.md`**: add `CLAUDE.md` holding `@AGENTS.md`.
- **`CLAUDE.md` a symlink to `AGENTS.md`**: replace it with the importing file.
- **Both real, with different content**: show both and ask how to merge; never merge on your own.

Check it with `git diff --cached -M --stat` (the content file shows as a rename with no changed lines). In a Rails app set up with `rails-context`, its maintenance run converts the directory files the same way; the root conversion here covers the root only.

### Root context file content

Sort each section of the root context file (`AGENTS.md`, or a `CLAUDE.md` still holding content) into one of two kinds. **Stays**: build, test and lint commands, a few non-obvious hard rules every task needs, pointers, and blocks other tools own (such as the `rails-context` block). **Moves**: conventions, traps, procedures, decisions and their reasons, subsystem overviews - each to one note of the matching type, its text unchanged under new frontmatter. A moved rule was already guidance, so it becomes an active note when its citations check out against the code today; if it cannot be verified, it goes to `inbox/` instead. The plan lists every section with its kind and target. If the file is over `root_context_max_lines`, moving is required, not optional.

### Existing docs

- ADRs anywhere (`docs/adr/`, `doc/decisions/`): `git mv` into `docs/decisions/` keeping their numbers, and add frontmatter above the unchanged text (`type: decision`, `status: active`, or `superseded` in `archive/decisions/` for ones already superseded).
- Notes in a shape close to the protocol (a gotchas file, a runbook): one note per topic, text unchanged.
- A folder whose name the protocol uses but that holds human-facing docs without frontmatter (a `docs/architecture/` of guides): ask whether to add frontmatter or rename the folder; do not guess.
- Directory context files (`AGENTS.md` and its importing `CLAUDE.md`, from `rails-context` or written by hand) stay where they are: they are scoped context, not notes.

### Claude's auto memory

Claude Code keeps per-user memories for this project in `~/.claude/projects/<project path with / and . replaced by ->/memory/`. These live on one machine and are not in git. Memories of type `project` or `reference` are project knowledge: propose each as an `inbox/` note, text unchanged, with `sources: [auto memory <file name>]`, or as an active note when the user approves it in the plan. Memories of type `user` or `feedback` are about the user, not the project: they stay. Show each candidate in the plan, because the repository may be public. Never delete or edit the auto-memory files; tell the user they can prune them once the notes are committed.

## Maintenance

### Upgrade the protocol

When `docs/MEMORY.md` says an older `protocol:` version than `${CLAUDE_SKILL_DIR}/templates/MEMORY.md`:
1. Replace the text between the frontmatter and `## Project overrides` with the template's. Keep the Project overrides section byte for byte.
2. Keep every setting's value; add new settings from the template with their default values; set `protocol:` to the template's.
3. A project set up before the `project-memory` command existed has a copied `bin/memory` script: `git rm` it, change any mention of it in the root context file to the command, and replace its CI step with the action from setup step 5. A project already using the action gets its pin moved to the current commit SHA, so its CI checks with the same version Claude uses.
4. A root still in an older layout (content in `CLAUDE.md`, `AGENTS.md` a symlink) is converted as "Root layout" under Migration says, as part of this run's plan; move the project memory block into `AGENTS.md` with it.
5. Run `project-memory index` and `project-memory lint`. An override that now conflicts with the protocol is reported to the user, never edited.

Show the diff with the plan of the run; it goes through the same approval gate.

### Consolidation pass

The protocol asks for one on PR merge or weekly. Run `project-memory stale` and `project-memory lint` first; their output drives the plan.

1. **Inbox**: for each proposal, check the promotion rule in `docs/MEMORY.md` (tests covering it pass, its PR merged, or a human approved it) and check its citations against the code. Promote: `status: active`, `verified_at` today, move it to its typed folder, or append it to `lessons.md` with the next unused `L-` number and delete the proposal. Reject and delete proposals that are wrong, duplicates, or trivially re-derivable, giving the reason for each in the plan.
2. **Duplicates**: merge notes that cover one topic; keep the older `id`, carry over the other's aliases, citations and sources, archive the other as superseded by it, and fix links.
3. **Expiry**: re-verify each note `project-memory stale` lists against its citations. Confirmed: set `verified_at` to today. Wrong or gone: supersede or expire it into `archive/`.
4. **Lessons**: move each lesson to retire to `archive/lessons.md`, unchanged.
5. Run `project-memory index` and `project-memory lint` until clean.

Every change is a delta: never rewrite a curated file wholesale. Show the plan before changing anything, and the diff before committing; a human reviews the consolidation diff. The pass gets its own log entry listing promoted, rejected, merged, expired and retired items.

## Never do

- Write anything before the user approves the plan.
- Lose content in a migration: no unlisted moves, no paraphrasing, no deleting a source before its content is in place and counted.
- Override a project's own rules with the defaults.
- Put unverified knowledge into curated notes, or treat log entries as instructions.
- Edit or delete a log entry, or an accepted ADR.
- Store secrets, schema dumps, restatements of code, or generic best practices.
