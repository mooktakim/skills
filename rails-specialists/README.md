# rails-specialists

A team of ten Rails specialist agents for Claude Code. Each agent owns one slice of Rails work - the data layer, the Hotwire front end, tests, background jobs, debugging, review, security, performance, deployment, upgrades - and carries the focused expertise and working discipline for that slice, so the main session can delegate instead of context-switching.

The agents are stack-agnostic: every one starts by reading the Gemfile and config to learn what the project actually uses (Minitest or RSpec, Solid Queue or Sidekiq, Kamal or Heroku, ViewComponent or partials) and follows the project's own conventions rather than imposing defaults.

## What it ships

| Agent | Specialty | Writes code? |
|---|---|---|
| `rails-model` | ActiveRecord models, associations, validations, safe reversible migrations, schema design | yes |
| `rails-hotwire` | Turbo Drive/Frames/Streams, Stimulus, the view layer | yes |
| `rails-tester` | Writes and runs tests in the project's framework; returns summaries, not suite dumps | yes |
| `rails-jobs` | Background jobs, mailers, recurring work, Action Cable | yes |
| `rails-debugger` | Reproduces bugs, digs logs and console state, returns a proven root cause | read-only |
| `rails-reviewer` | Code review of a diff/branch: correctness, conventions, migration safety, layering | read-only |
| `rails-security` | Brakeman + dependency audit + manual authz/injection/mass-assignment review | read-only |
| `rails-performance` | N+1s, indexes, query plans, memory, caching - with measurements as evidence | read-only |
| `rails-deploy` | Deploy config, Dockerfiles, process topology, health checks, CI | yes |
| `rails-upgrade` | Rails/Ruby/gem upgrades in small green steps, defaults-flag by defaults-flag | yes |

## Philosophy

**Specialists, no manager.** There is deliberately no architect/orchestrator agent. The main session stays in charge of the plan, the conversation, and every approval; specialists are dispatched with pre-resolved inputs and report back. An agent never asks the user anything.

**Two reasons to delegate.** An agent earns its place either by isolating noisy work (test runs, log digs, scanner output stay out of the main context) or by carrying deep domain discipline (migration safety, job idempotency, Turbo semantics) so the main session doesn't need re-prompting.

**Detect, don't assume.** Every agent reads the Gemfile, config, and neighbouring code before acting, and matches the project's idiom - even where it differs from common defaults.

**Advisors are read-only.** The debugger, reviewer, security, and performance agents have file editing disabled. They return diagnoses and findings with evidence; fixing is a separate, deliberate step by the caller or a writing specialist.

**Delegation at fixed moments.** Agent descriptions alone rarely win against the built-in general-purpose agent, so the plugin ships a `SessionStart` hook that, in Rails projects only, tells the main session when to delegate without being asked: `rails-reviewer` after implementing a change and before committing or opening a PR (trivial changes skipped), `rails-security` when a change touches auth, money, uploads, or secrets and before a production deploy, `rails-tester` for any test run, and `rails-debugger` when a bug's root cause is not yet proven. Each review costs tokens (roughly 100-200k for a feature-sized diff); that is the deliberate trade for catching bugs before they merge. When several reviews apply to one change (including `rails-design-system:design-reviewer`), the hook asks for them in a single message so they run in parallel, and for each prompt to name the changed files and the intent, so the agents skip rediscovering the scope. The writing specialists stay on-demand.

**Reports, not transcripts.** Each agent ends with a structured report - what changed or what was found, the evidence, and the follow-ups for other specialists - never raw tool output.

## Install

```
/plugin marketplace add mooktakim/skills
/plugin install rails-specialists@mooktakim
```

## How to use it

Mostly you don't invoke them - you just work. The agents' descriptions tell Claude when to delegate: ask for a code review before committing and `rails-reviewer` fires; report a bug and `rails-debugger` reproduces it; ask for tests and `rails-tester` writes and runs them without flooding the conversation.

To invoke one explicitly, @-mention it:

```
@rails-specialists:rails-security audit the changes on this branch
@rails-specialists:rails-performance why is the dashboard slow?
@rails-specialists:rails-upgrade take us from Rails 7.2 to 8.0
```

The read-only agents (debugger, reviewer, security, performance) hand back findings; apply fixes yourself or dispatch the matching specialist with the findings as input.
