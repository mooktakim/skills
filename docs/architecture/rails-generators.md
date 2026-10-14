---
id: rails-generators
type: architecture
status: active
summary: rails-generators plugin - why it exists (hand-written migrations), PreToolUse guard design, no agent/no audit decision, open items
aliases: [generators, migrations, guard, schema.rb]
created: 2026-10-09
verified_at: 2026-10-15
citations: [rails-generators/hooks/guard.sh, rails-generators/SKILL.md]
sources: [auto memory rails-generators-status.md]
---

rails-generators 0.1.0 (2026-10-09): skill + PreToolUse guard so Claude uses `bin/rails generate` and framework commands instead of writing their files. Trigger: user noticed Claude hand-writes migrations; maynard 21/35 and miraj 8/12 migrations have round hand-picked timestamps.

- Guard denies new migration files (Write or shell), writes to schema dumps, config/**/*.enc, Gemfile.lock wherever bin/rails exists; notes edits to already-run migrations. Verified headless: deny holds under bypassPermissions.
- Decided by me, not the user (tell them if they ask): name `rails-generators`; no agent (rails-specialists:rails-model owns migrations and now uses generators); no audit script.
- Pushed 2026-10-09 (3dcf76a, CI green). Open: watch for guard false positives in real apps.

Related: [rails-specialists-status](rails-specialists.md), [rails-hotwire-status](rails-hotwire.md)
