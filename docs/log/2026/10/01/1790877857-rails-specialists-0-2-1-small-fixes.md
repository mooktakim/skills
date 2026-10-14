# rails-specialists 0.2.1: subagent-safe stops, YJIT, default-branch merge-base

- Review defects 18-20. rails-upgrade ("present the plan before executing") and rails-deploy ("propose the exact command and wait") told a subagent to wait for the user, which it cannot do (AskUserQuestion is removed from subagents). Both now stop and return the plan/command in their final report for the main session to take to the user, unless the caller's prompt already carries the approval.
- rails-deploy: YJET -> YJIT.
- rails-reviewer: merge-base uses the repo's default branch via `git symbolic-ref refs/remotes/origin/HEAD`, falling back to main. Checked on maynard/dinehere/yardnote (origin/main) and this repo (no origin/HEAD -> main).
