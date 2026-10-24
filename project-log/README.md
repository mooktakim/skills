# project-log

Gives a project an append-only work log in git, so every session, teammate, and agent can find out what was done, when, and why.

The log is the base layer of [`project-memory`](../project-memory/), and it also stands on its own: a project that keeps its knowledge some other way can still keep this log.

## Install

```
/plugin marketplace add mooktakim/skills
/plugin install project-log@mooktakim
```

## What a project gets

```
AGENTS.md               # a short block pointing at the protocol
docs/
  LOG.md                # the protocol, plus this project's own overrides
  log/YYYY/MM/DD/       # one EPOCH-slug.md file per finished unit of work
```

The protocol travels with the repository: once set up, Claude follows `docs/LOG.md` with or without this plugin installed.

- **One file per finished unit of work**, written before the commit and committed with the work, so parallel branches never conflict.
- **Immutable**: an entry is never edited or deleted; a correction is a new entry.
- **History, never instructions**: rules and facts to act on live in the project's context files or its memory notes, not in the log.
- **`project-log lint`** checks entry names (the date folder must match the epoch in UTC), legacy logs left behind, and common secret patterns. Claude runs it after writing an entry by hand; a project can also run it in CI.

## Project overrides

Each project can change the protocol in the **Project overrides** section at the end of its `docs/LOG.md`. Overrides win over the protocol, and protocol upgrades keep them unchanged.

## Migrating from the project history log

Projects that kept the older history log (`docs/history/<YYYY-MM-DD>/<timestamp>-<slug>.md`, or a single `docs/HISTORY.md`) migrate on setup. Claude reads the old log, works out its shape (projects differ), and shows the plan: the rule for each part, example moves, counts, and every line it would drop. Each entry then moves into `docs/log/` with its text unchanged - entry files with `git mv`, so git keeps their history - and the counts and text are checked before the old log is deleted.

## The `project-log` command

A Rust program (standard library only) that the plugin puts on PATH and builds with cargo the first time it runs, so it needs [Rust](https://rustup.rs) installed. It works from any directory in a project. A teammate without the plugin installs it with:

```
cargo install --locked --git https://github.com/mooktakim/skills project-log
```

### In GitHub Actions (opt-in)

```yaml
- uses: actions/checkout@v7
- uses: mooktakim/skills/project-log@<full commit SHA>
```

The action builds the command from its own source once per version, caches it, and runs `project-log lint`, so later runs take about a second. Pin a commit SHA; moving the pin is how a project upgrades. In a monorepo, pass `with: { directory: apps/web }`.

## Usage

Ask in plain words ("set up the project log", "migrate the old history log") or run `/project-log:project-log`. Setup and upgrades show a plan and wait for your approval before writing.

## Requirements

- [Rust](https://rustup.rs) (`cargo`), to build the `project-log` command the first time it runs.
