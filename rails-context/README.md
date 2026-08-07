# rails-context

Rails is MVC. This skill adds a fourth letter: **Context**. It sets up per-directory context files across a Rails application so that AI agents working in any part of the codebase automatically inherit that directory's local conventions.

## What it creates

- A `CLAUDE.md` in each significant directory under `app/` and `lib/`, describing that directory's conventions: naming, base classes, call signatures, return shapes, what a correct new addition looks like, and gotchas.
- An `AGENTS.md` relative symlink beside each one (`ln -s CLAUDE.md AGENTS.md`), so tools that read either filename get the same content. `CLAUDE.md` is canonical; edits never go to the symlink.
- A maintenance rule appended to the root context file: agents must check the context files of directories they touched and surgically update them when a change breaks or adds a documented pattern — in the same commit as the change.
- `bin/audit_context` — a drift-detection script that flags directories whose code has changed since their context file was last touched, plus missing or mis-pointed symlinks and unmigrated real `AGENTS.md` files. Its output is a signal to review, not proof of staleness.
- `.claude/commands/context-audit.md` — a `/context-audit` command that runs the audit and reviews each flagged directory, editing surgically or reporting "checked, still accurate".

## Philosophy: intent, not inventory

Context files describe the *shape* of a directory, never its *contents*. "Services are single-purpose command objects named `VerbNoun`, exposing `.call` and returning a `Result`" is allowed; "the main services are X, Y, Z" is forbidden. File lists go stale the moment anyone adds a file, and a stale context file is worse than none — the code is the inventory, and agents can glob and grep it. Context files answer what grep cannot: why the directory is structured this way, what a correct new addition looks like, what mistakes to avoid.

The litmus test: if a sentence would need editing when someone adds one more file of the same kind, the sentence gets deleted. Files stay between 30 and 100 lines (hard cap 120), and only directories that earn one get one — a vanilla `app/helpers/` gets nothing.

## How it runs

The skill works in four phases, with you approving between them:

1. **Survey and plan** — reads the Gemfile and representative files, then proposes which directories deserve a context file (5+ files sharing a local convention, domain-encoding namespaces, or code an agent would plausibly get wrong: API clients, state machines, money, multi-tenancy). Waits for your approval.
2. **Generate** — derives each directory's conventions from the actual code, never guessing, using a fixed skeleton (Purpose / Conventions / Patterns / Adding new code here / Gotchas) guided by per-layer generation guides bundled in `references/` (models, controllers, services, components, jobs, views, test). Context files are only written for directories the app actually has and uses — nothing is ever scaffolded. Contradictory patterns get flagged to you rather than papered over.
3. **Wire up maintenance** — adds the root maintenance rule, `bin/audit_context`, and the `/context-audit` command.
4. **Review** — shows you every generated file; your stated intent outranks anything inferred from code. Corrections are folded in before committing.

## Install and use

```
/plugin marketplace add mooktakim/skills
/plugin install rails-context@mooktakim
```

Then, in a Claude Code session inside your Rails app, ask to "set up MVC context" (or invoke the skill directly). Afterwards, run `/context-audit` periodically — or after big refactors — to catch drift.
