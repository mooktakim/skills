# rails-context

Rails is MVC. This skill adds a fourth letter: **Context**. It sets up per-directory context files across a Rails application so that AI agents working in any part of the codebase automatically inherit that directory's local conventions.

## What it creates

- A `CLAUDE.md` in each significant directory under `app/` and `lib/`, describing that directory's conventions: naming, base classes, call signatures, return shapes, what a correct new addition looks like, and gotchas.
- An `AGENTS.md` relative symlink beside each one (`ln -s CLAUDE.md AGENTS.md`), so tools that read either filename get the same content. `CLAUDE.md` is canonical; edits never go to the symlink.
- A maintenance rule appended to the root context file: agents must check the context files of directories they touched and surgically update them when a change breaks or adds a documented pattern - in the same commit as the change.
- `bin/audit_context` - a drift-detection script that flags directories whose code has changed since their context file was last touched, plus missing or mis-pointed symlinks and unmigrated real `AGENTS.md` files. Its output is a signal to review, not proof of staleness.

There is no separate audit command: re-running the skill is the audit (see below).

## Philosophy: intent, not inventory

Context files describe the *shape* of a directory, never its *contents*. "Services are single-purpose command objects named `VerbNoun`, exposing `.call` and returning a `Result`" is allowed; "the main services are X, Y, Z" is forbidden. File lists go stale the moment anyone adds a file, and a stale context file is worse than none - the code is the inventory, and agents can glob and grep it. Context files answer what grep cannot: why the directory is structured this way, what a correct new addition looks like, what mistakes to avoid.

The litmus test: if a sentence would need editing when someone adds one more file of the same kind, the sentence gets deleted. Files aim for 30-100 lines - a density check, not a token budget, since each file loads only for work in its own directory. A file may grow past 100 once it provably holds nothing but app-specific intent, and 150 lines or 10 KB triggers a restructuring review (usually a nested-file split). The root `CLAUDE.md` loads in every session, so it has its own budget: aim under 8 KB, review at 200 lines or 12 KB. `bin/audit_context` reports every file past its trigger. Only directories that earn a file get one - a vanilla `app/helpers/` gets nothing.

## How it runs

The skill works in four phases, with you approving between them:

1. **Survey and plan** - reads the Gemfile and representative files, then proposes which directories deserve a context file (5+ files sharing a local convention, domain-encoding namespaces, or code an agent would plausibly get wrong: API clients, state machines, money, multi-tenancy). Waits for your approval.
2. **Generate** - derives each directory's conventions from the actual code, never guessing, using a fixed skeleton (Purpose / Conventions / Patterns / Adding new code here / Gotchas) guided by per-layer generation guides bundled in `references/` (models, controllers, services, components, jobs, views, test). Context files are only written for directories the app actually has and uses - nothing is ever scaffolded. Contradictory patterns get flagged to you rather than papered over.
3. **Wire up maintenance** - adds the root maintenance rule and `bin/audit_context`.
4. **Review** - shows you every generated or edited file; your stated intent outranks anything inferred from code. Corrections are folded in before committing, and every run closes with an audit report so nothing is silently ignored.

## Install

```
/plugin marketplace add mooktakim/skills
/plugin install rails-context@mooktakim
```

## How to use it

Open a Claude Code session inside your Rails app and either ask in plain words - "set up MVC context" / "add per-directory context files" - or invoke the skill directly: `/rails-context:rails-context`.

What to expect:

1. Claude surveys the app and proposes a list of directories with one line each on what its context file would say. **Nothing is written until you approve** - trim, add, or redirect the list here.
2. The files are generated from your actual code, with the `AGENTS.md` symlinks created alongside, and the maintenance rule and `bin/audit_context` wired up.
3. Claude shows you every generated file in one message. Correct anything that misstates intent - your word outranks whatever was inferred from the code - then it commits.

Re-running later is how you maintain the setup. A run on an app that already has context files proposes (behind the same approval gate): new files for newly qualifying directories, missing symlinks, drift fixes for files `bin/audit_context` flags (surgical edits where a documented pattern changed or a described file was deleted; "checked, still accurate" where it didn't, recorded with a `<!-- reviewed: YYYY-MM-DD -->` line so the flag clears), context files for the candidate directories the audit lists (5+ files, no context file; ones that need none go in a root `<!-- context-skip: ... -->` line), and slimming of any ancestor file that repeats a fact a deeper file owns. Existing files are never regenerated.

Afterwards, day to day:

- The maintenance rule in your root `CLAUDE.md` makes agents update affected context files as part of normal work, in the same commit as the change.
- Re-run the skill periodically - or after a big refactor - to catch drift; `bin/audit_context` gives the same signal from the shell.
- You don't have to remember: the plugin ships a `SessionStart` hook that runs `bin/audit_context` quietly when a session starts and, at most once a week per project, tells you when a maintenance run is due (oversized files, 5 or more flagged files, or an audit script older than the installed skill). It stays silent in projects without `bin/audit_context` and never starts a run on its own.
- **Shell work gets the context too.** Claude Code loads a directory's `CLAUDE.md` only when its Read tool reads a file there, and agents do much of their work through the shell. The plugin's `PostToolUse` hook watches Bash, Write, Edit, and Grep calls: when one touches code under `app/`, `lib/`, `test/`, or `spec/`, it hands Claude the context files on that path (the root excluded) that have not reached it yet - once per session, and again after a compaction. Silent in projects without `bin/audit_context`.
- **Apps inside a larger repository work too.** When the Rails app is a directory of the repository you open (for example `studio/` or `hub/`), the hooks find it by its `bin/audit_context`, hand over the app's own root `CLAUDE.md` (Claude Code does not load it at session start), and `audit_context` and `context_report` list paths from the app.
- **Do the files actually reach Claude?** The plugin's hooks keep a local log in `.git/claude-context-log.jsonl` (never committed): when a context file loads into Claude's context, Claude reads one, or the hook hands one over, and which files each session changed - by any tool, Bash included. `scripts/context_report` turns it into a table per context file: sessions that worked in the directory, sessions where its file reached Claude, and the gap between them. Maintenance runs use it to fix files that are not read where it matters, and to merge files that never are.
