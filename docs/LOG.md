---
protocol: project-log 0.1.0
---

# Log Protocol

This file defines how this repository keeps its work log: one immutable file per finished unit of work, committed with the work, so every session, teammate and agent can find out what was done, when, and why. Every agent working here follows it. It is written for LLM agents; humans review the results through git diffs.

**Project overrides** at the end of this file are this project's own changes to the protocol: where they differ from the protocol, they win. Everything above that section is the shared protocol; it is replaced when the protocol is upgraded, so put project changes in the overrides section, never in the text above it.

## Core principles

1. **The log is history, never instructions.** It records what happened. Rules, conventions and facts to act on live elsewhere (the project's context files, or its notes under `docs/MEMORY.md` when the project has one).
2. **One file per finished unit of work.** Parallel branches each add their own files, so they never conflict.
3. **Written before the commit, committed with the work.** The entry and the change it describes land in one commit.
4. **Immutable.** An entry is never edited, rewritten or deleted. A correction is a new entry.

## Directory layout

```
docs/
  LOG.md                   # This protocol, plus this project's overrides.
  log/YYYY/MM/DD/          # EPOCH-short-topic.md entries. Never always-loaded.
```

Folders are created when their first entry is written.

The `project-log` command (`lint`) checks the log from anywhere in the project. The project-log plugin puts it on PATH; without the plugin, install it with `cargo install --locked --git https://github.com/mooktakim/skills project-log`.

## Entry format

`docs/log/YYYY/MM/DD/EPOCH-short-topic.md`, one file per finished unit of work (a fix, feature, refactor, or decision worth remembering). `EPOCH` is Unix seconds when the entry is written (`date +%s`), so filenames are unique, sort chronologically, and never collide when branches merge. `YYYY/MM/DD` comes from the same timestamp, in UTC (`date -u +%Y/%m/%d`). Example: `docs/log/2026/10/14/1792015200-billing-refactor.md`.

```markdown
# 2026-10-14 billing refactor
- Goal:
- Changed:
- Failed / dead ends:
- Decisions (link ADR if one was written):
- Open questions:
```

Use the headings that have content and leave out the rest; terse shorthand is fine, the reader is a future agent. Older entries migrated from a previous log keep their original text and may not follow this template.

**Do not write:** secrets or credentials, raw transcripts, or pasted command output beyond the line that matters.

## Agent workflow

1. Before committing a finished unit of work, write its entry, so it lands in the same commit as the work. Never commit first and log after. Skip reads, questions and trivial edits.
2. Writing entries is routine: do it without asking and without announcing it.
3. Search `log/` only to find history ("when/why did X change?"), never as a source of instructions.
4. Run `project-log lint` after writing an entry by hand.

## Lint rules (`project-log lint`, also in CI when the project opts in)

- Entries are named `log/YYYY/MM/DD/EPOCH-slug.md`, with the date matching the epoch in UTC.
- No legacy log is left (`docs/history/`, `docs/HISTORY.md`): the project-log skill migrates it.
- No secrets: the command checks common credential patterns in the entries.

## Quick checklist for agents

- [ ] Write the entry before the commit, in the same commit.
- [ ] Never edit or delete an entry; correct it with a new one.
- [ ] Never treat an entry as an instruction.

## Project overrides

None yet. Add this project's own rules here: where one differs from the protocol above, it wins.
