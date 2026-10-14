# project-memory

Gives a project long-term memory that lives in git, so every session, teammate, and agent starts from what the project already learned.

Agents follow what they retrieve closely, so a memory full of stale or unverified notes does more harm than none. This plugin sets up a protocol built around that: keep always-loaded context small, store only what cannot be cheaply re-derived from the code, cite the code behind every fact and check the citation before trusting it, and let nothing unverified become guidance.

## What a project gets

```
CLAUDE.md               # a short block pointing at the protocol and the index
docs/
  MEMORY.md             # the protocol, plus this project's own overrides
  INDEX.md              # generated: one line per curated note, read at task start
  conventions/ architecture/ decisions/ playbooks/ gotchas/   # curated notes
  lessons.md            # abstract lessons with helpful/harmful counters
  log/YYYY/MM/DD/       # append-only log, one EPOCH-slug.md file per finished unit of work
  inbox/                # proposed memories awaiting verification
  archive/              # superseded or expired notes
```

The protocol travels with the repository: once set up, Claude follows `docs/MEMORY.md` with or without this plugin installed.

- **Notes** carry frontmatter: id, type, status, a one-line summary, aliases, citations to code (`path:line`), sources, and when they were last verified.
- **The inbox** holds new knowledge until tests pass, its PR merges, or a human approves it.
- **The log** is one immutable file per finished unit of work, written before the commit and committed with the work, so parallel branches never conflict.
- **`project-memory lint`** checks frontmatter, folders, citations, links, log file names, the index, size budgets, and common secret patterns. Claude runs it after changing `docs/`; a project can also run it in CI. `project-memory index` writes the index and `project-memory stale` lists what a consolidation pass must look at.
- **Consolidation passes** (on PR merge or weekly) promote or reject the inbox, merge duplicates, expire notes not verified within 90 days, and retire lessons that mislead more than they help.

## Project overrides

Each project can change the protocol in the **Project overrides** section at the end of its `docs/MEMORY.md`, and tune the size budgets and expiry window in its frontmatter. Overrides win over the protocol, and protocol upgrades keep them unchanged.

## Migrating from the project history log

Projects that kept the older history log (`docs/history/<YYYY-MM-DD>/<timestamp>-<slug>.md`, or a single `docs/HISTORY.md`) migrate on setup. Claude reads the old log, works out its shape (projects differ), and shows the plan: the rule for each part, example moves, counts, and every line it would drop. Each entry then moves into `docs/log/` with its text unchanged - entry files with `git mv`, so git keeps their history - and the counts and text are checked before the old log is deleted. Setup also offers to move notes out of an oversized root `CLAUDE.md`, existing ADRs, and project facts from Claude's local auto memory, each listed in the plan with counts before anything moves.

## The `project-memory` command

A Rust program (standard library only) that the plugin puts on PATH and builds with cargo the first time it runs, so it needs [Rust](https://rustup.rs) installed. It checks a large project (hundreds of notes, thousands of log entries) in under a tenth of a second, and works from any directory in a project. A teammate without the plugin installs it with:

```
cargo install --locked --git https://github.com/mooktakim/skills project-memory
```

### In GitHub Actions (opt-in)

```yaml
- uses: actions/checkout@v7
- uses: mooktakim/skills/project-memory@<full commit SHA>
```

The action builds the command from its own source once per version, caches it, and runs `project-memory lint`, so later runs take about a second. Pin a commit SHA; moving the pin is how a project upgrades. In a monorepo, pass `with: { directory: apps/web }`.

## Usage

Ask in plain words ("set up project memory", "run a memory consolidation pass") or run `/project-memory:project-memory`. Setup and maintenance show a plan and wait for your approval before writing.

## Install

```
/plugin marketplace add mooktakim/skills
/plugin install project-memory@mooktakim
```
