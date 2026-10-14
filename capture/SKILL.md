---
name: capture
description: Record a rule the user states or a correction they make in the one checked-in place it belongs - a directory AGENTS.md, the root AGENTS.md, a design-system file, or the global CLAUDE.md - so it is never said again. Use when the user says remember this, from now on, always, never, or I already told you, or agrees to an offer to record a correction. Not for one-off taste or task instructions.
---

# Capture

A correction the user has to repeat is a failure of the project's context, not of the user's patience. This skill turns a stated rule into one line in the one checked-in file where future sessions will read it. Follow this document exactly. Nothing is written until the user approves the exact text and target.

## When to offer it

After the user corrects you or states a rule, first do what they asked. Then, if the rule should hold beyond this task, offer the capture in one short line: the rule as you would write it, and the file it would go to. Offer once per rule; if the user ignores or declines it, drop it.

Do not offer for:
- **Task instructions** that only apply to the current work ("make this button blue").
- **One-off taste** about a single screen or piece of copy ("I don't like this layout"). If the same kind of taste correction comes up a second time - in this conversation, or the user says "again" - it has become a rule: offer it then, as a design rule.
- **Rules already recorded** where they belong. Then the problem is that the rule was not followed - see "Already recorded" below.

## 1. State the rule

Write the rule as one imperative sentence, plus its reason when the user gave one or it is obvious ("Status badges never show a dot - the dot reads as a notification."). Keep the user's meaning, not their wording; one rule per capture. If the scope is unclear - this directory or the whole app, this section or every section - ask one question instead of guessing.

## 2. Route it to one place

Every rule lives at exactly one level: the most specific place it applies to, and nowhere else.

| The rule is about | Write it to |
|---|---|
| Code conventions in one directory or namespace | That directory's `AGENTS.md` (the nearest one above the code the rule concerns; the `CLAUDE.md` beside it only imports it) |
| UI wording, formats, or how a state is shown, across every section | `docs/design-system/conventions.md` |
| One UI section's look or behaviour | That section's `docs/design-system/<section>/design.md` |
| One component or page pattern | Its spec: `docs/design-system/<section>/components/<name>.md` or `patterns/<name>.md` |
| The whole project (process, tooling, architecture) | The root `AGENTS.md`; in a project with `docs/MEMORY.md`, usually a note instead - see "Projects with project memory" |
| How Claude alone should behave in this project, not other agents | The root `CLAUDE.md`, below its `@AGENTS.md` import (rare: most rules apply to every agent) |
| The user personally, in every project | The user's global `~/.claude/CLAUDE.md` - see "Global rules" |

Read the target file before drafting, and follow its conventions: its sections, density, and voice. Files written by the `rails-context` skill describe intent, never inventories, and have size limits (a directory file reviews at 150 lines or 10 KB, the root at 200 lines or 12 KB); a capture that would push a file past its limit says so, and proposes where the file should split. Files written by `rails-design-system` keep their formats (the states table in `conventions.md`, a component spec's Contract and Rules sections).

Context files use one layout: `AGENTS.md` holds the content (every agent reads it), and `CLAUDE.md` beside it is the line `@AGENTS.md` (Claude Code reads only `CLAUDE.md` and expands the import). Write rules to `AGENTS.md`, never to an importing `CLAUDE.md`. Where a project still has the older layout (content in `CLAUDE.md`, `AGENTS.md` a symlink to it), write the rule to that `CLAUDE.md`, as the project does, and say once that the layout can be migrated: by a `rails-context` maintenance run for directory files, or the `project-memory` skill for the root. Do not migrate files as part of a capture.

If the right file does not exist, write to the nearest existing one and say where the rule would sit better: a directory with no context file gets its rule in the nearest ancestor (usually the root). The one exception is a design system without `conventions.md`: propose creating it with a one-line header and this rule as its first entry - a design-system maintenance run fills in the rest.

A correction about a component or page that is being built right now and has no spec yet is not a capture: the rule goes into that spec as part of the work, and you just make sure it does.

## 3. Already recorded?

Search the candidate files for the rule before drafting (grep its key terms; in a project with project memory, also the notes under `docs/`, leaving out `docs/archive/` and `docs/log/`), and look for lines that say the opposite too. A contradicting line anywhere is resolved in the same capture - edited or removed, with the user's approval - never left as a second, opposite rule. If the rule is already written where it belongs, do not add it again: tell the user where it is, and that the problem is that it was not followed. Then propose the fix that makes it stick - clearer or stronger wording, moving it to a more specific file that loads when the relevant code is read, or a mechanical check (below). If it is recorded in the wrong place, propose moving it, not copying it.

## 4. Propose, then wait

Show the user:
- the exact line(s), as they will appear,
- the target file and the section it goes under,
- for an "already recorded" case, the existing line and the proposed change.

Then wait for the user's reply. Only a reply to this proposal is approval: "yes", "go", or an edit to the text. A reply about something else is not approval - handle it, then ask again once. Never write a capture the user did not approve.

## 5. Make it enforceable when a grep can catch it

If breaking the rule leaves a mark a regular expression can find reliably - a forbidden class, helper, or element - propose a mechanical check alongside the line:
- **Apps with a design system** (`docs/design-system/audit-rules` is read by `bin/audit_design`): propose a rule line `<label naming the spec rule> :: <regular expression>`, and for a rule that belongs to one section add ` :: <path prefixes>` (for example ` :: app/views/admin/ app/components/admin/`) so it never fires on other sections. Run the pattern over the paths it will cover first (`grep -rnE`) and report every hit; a pattern that also hits legitimate code is not ready - narrow its paths, tighten it, or drop it. The plugin's hooks enforce new rules at once; if the app's own `bin/audit_design` copy (used by CI) predates `audit-rules` support (`grep -q audit-rules bin/audit_design` fails), say that CI will only enforce the rule after a design-system maintenance run updates the copy - never hand-edit the script.
- **Other projects**: name the linter or CI step that could carry the check (RuboCop, ESLint, a `config/ci.rb` step), and leave the choice to the user.

Existing code that already breaks the new rule is reported, never fixed silently: offer the fix as a separate step the user approves.

## 6. Write and commit

Write the approved text surgically: add or edit only those lines, never regenerate the file. Follow the project's commit rules. When the capture came out of work that is not committed yet, it belongs in that same commit; otherwise commit it on its own, with a message that names the rule.

## Projects with project memory

When the project has `docs/MEMORY.md` (the `project-memory` protocol), follow it, including its Project overrides. A project-wide rule goes to the root `AGENTS.md` only when it is one of the few non-obvious hard rules every task needs; otherwise it goes to a curated note: a convention to `docs/conventions/<topic>.md`, a trap or hidden coupling to `docs/gotchas/<topic>.md`, a procedure to `docs/playbooks/<topic>.md`. Add it to the existing note for the topic when there is one (search by key terms and `aliases`); otherwise create one with the protocol's frontmatter: `status: active`, `created` and `verified_at` today, `sources: [user, YYYY-MM-DD]`, and `citations` when the rule is about specific code. Show the note's frontmatter in the proposal too. The user's approval of the exact text is the human approval the protocol's promotion rule asks for, so an approved capture skips `docs/inbox/`. After writing, run `project-memory index` and `project-memory lint`. Rules for one directory, the design system, or the user personally still go where the table above says.

## Global rules

A rule about how the user works in every project goes to their global `~/.claude/CLAUDE.md`, which applies everywhere, so it needs a second, explicit confirmation: say plainly that it will apply to all projects, and wait for a yes to that. Follow the user's own instructions for that file (it may be a symlink into a config repository with its own commit-and-push rule). A rule that only seems global because it came up in this project goes to this project.

## Never do

- Write anything without the user's approval of the exact text and target.
- Record the same rule in two places, or restate a rule that a more specific file already owns.
- Record one-off taste, task instructions, or secrets.
- Invent a rule the user did not state, or widen its scope beyond what they said.
- Silently fix existing code to match a new rule.
