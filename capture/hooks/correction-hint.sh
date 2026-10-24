#!/usr/bin/env bash
# UserPromptSubmit hook: when a prompt reads like a correction or a standing rule,
# remind Claude it can offer to capture it. A keyword heuristic that is wrong more
# often than right, so the reminder asks Claude to judge, never to act.
# Only when a person is at the session: an offer in a headless or SDK run
# (CLAUDE_CODE_SESSION_ATTENDED=0) reaches nobody.
[ "${CLAUDE_CODE_SESSION_ATTENDED:-1}" = "0" ] && exit 0
input=$(cat)
prompt=$(printf '%s' "$input" | tr '\n' ' ' | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\(.*\)/\1/p')
[ -n "$prompt" ] || exit 0
# Slash commands, skill runs, and harness messages (agent notifications, command
# output) are not the user's words.
case "$prompt" in "/"*|"<command-"*|"<task-notification>"*|"<local-command-"*|"<bash-"*|"<system-reminder>"*) exit 0 ;; esac

lower=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
# A bare "no" or "nope" is an answer, not a rule; it counts only before a rule word.
# A bare "stop" is a command ("stop the server"); "stop doing ..." is below.
start='^((no|nope),? +)?(don.?t|do not|never|always|wrong|not like that|again)([^a-z]|$)'
anywhere='(i (already )?(said|told you|asked)|from now on|every time|each time|keep (doing|forgetting|adding|using)|remember (to|that)|you (always|keep|forgot)|why did you|stop (doing|adding|using)|(update|add (it|this|that) to) (the )?(claude|agents)\.md|so you (don.?t|stop|remember)|we (always|never) |we don.?t (ever |want |use |do |delete |allow |show |include |add |put |link )|(you|we) should (always|never) |(don.?t|never) (ever )?do (that|this) again)'
printf '%s' "$lower" | grep -qE "$start|$anywhere" || exit 0
# "Don't merge yet" holds back one task; it is not a standing rule.
printf '%s' "$lower" | grep -qE "^(don.?t|do not) [^.?!]* yet([^a-z]|$)" && ! printf '%s' "$lower" | grep -qE "$anywhere" && exit 0

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "This message may state a lasting rule. Handle the request first. Then decide: does it say how this project or this user always or never works, beyond this one task (for example \"we don't use licensed fonts\", \"always rebase on main before waiting for CI\", \"I already told you to use Phlex\")? If yes, end your reply with one line that offers to record it with the capture skill: the rule in a few words and the file it would go to. If it only steers this task, say nothing about it. Do not write anything unless the user approves."
  }
}
EOF
