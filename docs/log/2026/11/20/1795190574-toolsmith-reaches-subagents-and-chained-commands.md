# toolsmith reaches subagents and chained commands

Why toolsmith-check-run use dropped (interactive sessions, W45 to W47): the
main session still used it (about 88% once chained calls are left out), but
subagents ran 423 old-pattern test, lint and audit calls against 270
check-run calls. A subagent never saw the SessionStart tool list, and the
reminder hook skipped subagents on purpose. Our own agents almost never used
it (design-reviewer 77 old to 1, rails-reviewer 61 to 2). A further 183
main-session calls chained a test run after a `toolsmith-text-replace` edit
in one command, which the hook skipped because the command held
`toolsmith-`.

Now:
- A `SubagentStart` hook (`hooks/subagent-start.sh`, `registry subagent`)
  gives every subagent the tool list as its starting context, except in a
  Bridge agent session.
- Reminders run in subagents too, once per subagent and tool (the
  reminded-state key is the session id plus the agent id).
- In a command that holds a toolsmith command, the hook leaves out each
  toolsmith segment (quote-aware, up to the next unquoted ; & | ) or newline;
  the & of 2>&1 does not end it) and the heredoc body fed to it, and checks
  the rest.

Replayed on the 5,396 interactive commands with `toolsmith-` since 11-06:
367 check-run reminders (all sampled were tests or audits cut with tail or
grep), 41 text-replace and 7 file-lines refusals (all real `sed -i`,
`perl -pi` or python `.replace` scripts and `sed -n` reads, several placed
right after a `toolsmith-text-replace --llm` guide read), 21 files-write
reminders. Version 0.7.0.
