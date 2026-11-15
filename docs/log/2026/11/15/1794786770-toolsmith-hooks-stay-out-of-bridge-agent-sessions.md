# toolsmith hooks stay out of Bridge agent sessions

Bridge (github.com/mooktakim/bridge) runs Claude Code headless as a lead
and as workers, with the owner's full setup, so the toolsmith PreToolUse
hook ran there too. On its first real project the hook refused many worker
commands (plain `sed -n` reads and `python3 -` scripts in block mode). A
refused command in a headless session only costs a turn, and Bridge has its
own guard for what an agent may run.

`hooks/pre-bash.sh` now exits at once when `BRIDGE_SESSION_TOKEN` is set,
which Bridge puts in every agent session's environment. Interactive
sessions are unchanged. Version 0.5.1. The owner chose this over a lean
worker setup, so workers keep the owner's skills and plugins.
