# The toolsmith tool contract

Every toolsmith tool meets every rule below. Rules marked **(test)** are enforced by `test/toolsmith_test.rb`, so a tool that breaks one fails `bin/test` and CI. The others are checked when the tool is designed, before any code is written.

## One job

- The manifest's `intent` is one sentence that names one job. It ends with a full stop, has no " and " or " or ", and is under 100 characters. **(test)**
- The intent is as specific as the evidence allows: name the object and the action ("Add one new entry file to the project's docs/history log", not "Manage history"). A tool that needs subcommands for different jobs is two tools.
- `use_when` lists the situations the tool is for; `not_for` lists what it is not for and what to use instead. Both are non-empty. **(test)**

## Name

- `toolsmith-<object>-<verb>`, or `toolsmith-<verb>` when there is no natural object: lowercase words joined by single hyphens. **(test)** Related tools share the object, so they sort together (`toolsmith-history-add`, `toolsmith-history-recent`).
- The crate directory is the name without `toolsmith-`, and `bin/` holds one shim per tool with exactly the standard two lines. **(test)**
- No other command has the name: `type -a <name>` and `brew info --formula <name>` find nothing when the tool is created. The SessionStart hook checks PATH again in every session and leaves a shadowed tool out of the list.

## No interference

- Tools never wrap, alias, or replace an existing command, and never change shell config or PATH. They call `git` and `gh` as plain subprocesses.
- A tool changes only the files its guide says it changes. Every example runs in a scratch directory, and the test compares every file before and after. **(test)**
- A tool that fails leaves files as they were, unless its guide documents an exit code for a partial failure and the message lists what was done. **(test, through the failure examples)**
- The PreToolUse hook only reminds (mode `remind`). Mode `block` is set per tool, only with the user's approval, and applies only to that tool's family. If the hook cannot run, the Bash command runs as normal. **(test)**

## A guide an LLM can follow

- `--llm` prints the full guide from `tool.json`: purpose, usage, use it when, do not use it for, input, options, output, exit codes, and examples. Every section is present. **(test)**
- `--help` (and `-h`) prints the intent, usage, options in one line each, and a pointer to `--llm`, in at most 25 lines. **(test)**
- Exit codes: 0 done, 1 understood but could not do it, 2 wrong request (unknown option, missing argument, bad input). Further codes are documented. **(test)**
- An unknown option exits 2 with a pointer to `--help`, and writes nothing to stdout. **(test)**
- Error messages say what went wrong, where, and how to fix it: the spec line, the file line, the closest match.

## Fully tested

- At least two examples, including at least one failure. **(test)**
- Every example in `tool.json` runs against the built binary: exit code, stdout and stderr (exact, or a regex with a sample that matches it), the files after, and the files staged in git. The guide prints the same examples, so the guide cannot drift from the tool. **(test)**
- An example that needs git history or another program's answers builds them with `setup` (a bash script run in the scratch directory; a git remote goes under `.git/` so it is not part of the compared files) and `fake_commands` (scripts put first on PATH, such as a `gh` that returns fixed JSON). Such an example has a `situation`: the sentence the guide shows in their place. Unknown example keys fail the test. **(test)**
- Unit tests in the crate cover the logic: parsing, matching, edge cases. `cargo test --workspace` runs from `bin/test`. **(test)**
- Rust standard library only, so tools build without network access and with any recent stable Rust.

## Measured

- Every run goes through `Tool::exit`, which appends one line to the usage log: time, tool, mode (run, help, llm), exit code, duration, directory. Never the arguments or input. **(test)**
- The tool's `family` in `families.json` defines the old pattern it replaces, so `scripts/analyse adoption` can compare tool calls with old-pattern calls per week. Each family has at most one tool. **(test)**
