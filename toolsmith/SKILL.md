---
name: toolsmith
description: Find repeated Bash patterns in the user's Claude Code history and build small single-purpose Rust commands (toolsmith-*) that replace them - inline Python, Ruby or sed edit scripts, hand-built log entries, CI polling and the like - then measure whether the commands are used and help. Use when the user asks to scan their Claude history for tool ideas, to build or change a toolsmith command, or to check how the toolsmith commands are doing; also when the session-start note says a scan is due and the user agrees to one. Not for running an existing toolsmith command (run `<command> --llm` for its guide), and not for tools unrelated to how Claude works in the shell.
---

# Toolsmith

Toolsmith turns Bash patterns that Claude repeats into small commands with one job each. Each command is a Rust crate under `crates/`, reached through a shim in `bin/` that the plugin puts on the Bash tool's PATH. The shim builds the binary on first use and after every change. The plugin's hooks list the commands at session start and remind Claude of one when a Bash command matches the pattern it replaces. Follow this document exactly. Nothing is built, blocked, or removed until the user approves it.

## Where to work

The plugin directory is `${CLAUDE_SKILL_DIR}`. When it is inside `~/.claude/plugins/cache`, it is an installed copy: ask the user for the path of their checkout (the repository that holds `toolsmith/`) and work there. Below, `$T` means the plugin directory in that checkout. Follow the checkout's own CLAUDE.md for commits, tests and history.

## 1. Scan for opportunities

1. Run `ruby $T/scripts/analyse scan --metrics $T/metrics/weekly.json`. It prints the families (repeated patterns from `families.json`) by number of calls, the tool that covers each, and the most frequent commands that match no family. It also saves weekly counts, which keep the trend after Claude Code deletes old transcripts.
2. For each promising family or command, read real commands: `ruby $T/scripts/analyse examples --family <id> --limit 15`, or `--match '<regex>'`. Find the one job those commands do again and again.
3. When a pattern is not a family yet, add one to `families.json`: an `id`, a `title` that completes "this command looks like ...", and `rules` (a command matches when every regex of any one rule matches). Run the scan again to get its numbers.
4. Show the user a ranked shortlist. For each candidate: the job in one sentence, calls, sessions and projects, the proposed name and intent, and what a tool removes (boilerplate, extra turns, failures). Say which patterns are better left alone, for example when Claude Code's own tools already do the job.
5. Commit `metrics/weekly.json` and any `families.json` change. Then wait for the user to choose. Build nothing without approval.

## 2. Build a tool

One tool at a time, after the user chose it.

1. Read `references/contract.md`. Every rule in it is a requirement.
2. Write the design as `crates/<object>-<verb>/tool.json` first, beside the existing tools' manifests: intent, usage, use_when, not_for, input, options, output, exit codes, examples (including a failure), `family`, `"mode": "remind"`, and today's date as `added`. Check the name: `type -a <name>` and `brew info --formula <name>` must find nothing.
3. Show the user the name, intent, usage and examples. Wait for approval of the design.
4. Write the crate: a `Cargo.toml` like an existing tool's, and `src/main.rs` that starts with `Tool::new(include_str!("../tool.json"))`, passes the arguments through `handle_guide_flags`, and leaves through `tool.exit`, `tool.fail` or `tool.usage_error`. Use the standard library only. Put unit tests for the logic in the crate.
5. Add `bin/<name>`: a copy of an existing shim with the name changed, mode 755.
6. Run `bin/test`, then `TEST_RUBY=/usr/bin/ruby TEST_BASH=/bin/bash bin/test`, from the checkout root. Fix every failure.
7. Try the tool on one real task like the examples from step 1 of the scan, and fix anything awkward in the tool or its guide.
8. Add the tool to the table in `$T/README.md`, bump the minor version in `$T/.claude-plugin/plugin.json`, and commit.
9. Tell the user that the command is available in new sessions.

To change an existing tool, follow the same steps from 1, starting from its `tool.json`. Keep its options and output compatible, or update every example and say what changed.

## 3. Review adoption

1. Run `ruby $T/scripts/analyse adoption --metrics $T/metrics/weekly.json`. For each tool and week it shows tool calls, tool errors, old-pattern calls and the tool's share, then the usage log: runs, failed runs, guide reads, reminders, and reminders followed by a run within 10 minutes.
2. Read the numbers against the tool's `added` date. A useful tool's share rises week by week and its failures stay rare.
3. Propose actions, each with its evidence, and wait for approval:
   - **Share low, reminders not followed:** read recent old-pattern commands (`analyse examples --family <id>`) to see why the tool did not fit. Then improve the guide (`use_when`, `not_for`, examples) or the tool.
   - **Failures:** read them with `analyse examples --match '<tool name>'`, and fix the tool or the guide that misled.
   - **Used well, but the old pattern continues:** switch the tool to `"mode": "block"`. Do this only with the user's explicit approval.
   - **Unused for four weeks or more, with no matching old-pattern calls:** remove the tool.
