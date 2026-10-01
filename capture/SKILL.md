---
name: capture
description: Record a rule the user states or a correction they make into the project's checked-in context, at the one place it belongs - a directory's CLAUDE.md, the root CLAUDE.md, a design-system file, or (with extra confirmation) the user's global CLAUDE.md - so it never has to be said again. Use when the user says "remember this", "from now on", "always", "never", "don't do X again", "I already told you", "update CLAUDE.md so you stop doing this", or asks to capture or record a rule. Also offer it, once, right after the user corrects how you work in a way that should hold beyond the current task. Not for one-off taste on a single screen, task instructions, or anything already recorded and followed.
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
| Code conventions in one directory or namespace | That directory's `CLAUDE.md` (the nearest one above the code the rule concerns; `AGENTS.md` is its symlink) |
| UI wording, formats, or how a state is shown, across every section | `docs/design-system/conventions.md` |
| One UI section's look or behaviour | That section's `docs/design-system/<section>/design.md` |
| One component or page pattern | Its spec: `docs/design-system/<section>/components/<name>.md` or `patterns/<name>.md` |
| The whole project (process, tooling, architecture) | The root `CLAUDE.md` (or the project's root `AGENTS.md` if that is its canonical file) |
| The user personally, in every project | The user's global `~/.claude/CLAUDE.md` - see "Global rules" |

Read the target file before drafting, and follow its conventions: its sections, density, and voice. Files written by the `rails-context` skill describe intent, never inventories, and have size limits (a directory file reviews at 150 lines or 10 KB, the root at 200 lines or 12 KB); a capture that would push a file past its limit says so, and proposes where the file should split. Files written by `rails-design-system` keep their formats (the states table in `conventions.md`, a component spec's Contract and Rules sections).

If the right file does not exist, write to the nearest existing one and say where the rule would sit better: a directory with no `CLAUDE.md` gets its rule in the nearest ancestor (usually the root). The one exception is a design system without `conventions.md`: propose creating it with a one-line header and this rule as its first entry - a design-system maintenance run fills in the rest.

A correction about a component or page that is being built right now and has no spec yet is not a capture: the rule goes into that spec as part of the work, and you just make sure it does.

## 3. Already recorded?

Search the candidate files for the rule before drafting (grep its key terms), and look for lines that say the opposite too. A contradicting line anywhere is resolved in the same capture - edited or removed, with the user's approval - never left as a second, opposite rule. If the rule is already written where it belongs, do not add it again: tell the user where it is, and that the problem is that it was not followed. Then propose the fix that makes it stick - clearer or stronger wording, moving it to a more specific file that loads when the relevant code is read, or a mechanical check (below). If it is recorded in the wrong place, propose moving it, not copying it.

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

## Global rules

A rule about how the user works in every project goes to their global `~/.claude/CLAUDE.md`, which applies everywhere, so it needs a second, explicit confirmation: say plainly that it will apply to all projects, and wait for a yes to that. Follow the user's own instructions for that file (it may be a symlink into a config repository with its own commit-and-push rule). A rule that only seems global because it came up in this project goes to this project.

## Never do

- Write anything without the user's approval of the exact text and target.
- Record the same rule in two places, or restate a rule that a more specific file already owns.
- Record one-off taste, task instructions, or secrets.
- Invent a rule the user did not state, or widen its scope beyond what they said.
- Silently fix existing code to match a new rule.
