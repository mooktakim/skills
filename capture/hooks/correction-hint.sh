#!/usr/bin/env bash
# UserPromptSubmit hook: when a prompt reads like a correction or a standing rule,
# remind Claude it can offer to capture it. A keyword heuristic: it is right about
# four times in five, so the reminder asks Claude to judge, never to act.
input=$(cat)
prompt=$(printf '%s' "$input" | tr '\n' ' ' | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\(.*\)/\1/p')
[ -n "$prompt" ] || exit 0
case "$prompt" in "<command-"*|"/"*) exit 0 ;; esac # slash commands and skill runs

lower=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')
start='^(no|nope|don.?t|do not|never|always|stop|wrong|not like that|again)([^a-z]|$)'
anywhere='(i (already )?(said|told you|asked)|from now on|every time|each time|keep (doing|forgetting|adding|using)|remember (to|that)|you (always|keep|forgot)|why did you|stop (doing|adding|using)|(update|add (it|this|that) to) (the )?(claude|agents)\.md|so you (don.?t|stop|remember)|we (always|never) |we don.?t (ever |want |use |do |delete |allow |show |include |add |put |link )|(you|we) should (always|never) |(don.?t|never) (ever )?do (that|this) again)'
printf '%s' "$lower" | grep -qE "$start|$anywhere" || exit 0

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "This message may correct how you work. Handle the request first. Then, only if it states a rule that should hold beyond this task (not one-off taste or a task instruction), offer once, in one line, to record it with the capture skill - the rule and the file it would go to. Do not write anything unless the user approves."
  }
}
EOF
