# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A hand-authored collection of Claude Code skills, not limited to any one domain — each skill's name and description convey what it is for (Rails, etc.). There is no application code, build step, or test suite — every deliverable is a skill directory containing markdown instructions for Claude.

## Repository structure

The repo is a Claude Code plugin marketplace (named `mooktakim` — the install handle after `@`) where each skill is its own plugin, living in a directory at the repo root:

```
.claude-plugin/marketplace.json    # marketplace manifest; one plugins[] entry per plugin
<plugin-name>/
  .claude-plugin/plugin.json       # plugin manifest (name matches the directory)
  SKILL.md             # skill plugins: frontmatter + instructions, at the plugin root
  agents/<name>.md     # agent plugins: one file per subagent
  <supporting files>   # optional: scripts, templates, references
```

A plugin ships a `SKILL.md`, an `agents/` directory, or both. Adding a new plugin means creating its directory (with `SKILL.md` and/or `agents/`, plus `plugin.json` and a human-facing `README.md`) AND adding a matching entry to the `plugins` array in `marketplace.json` — the marketplace only offers what that array lists — AND a row in the root `README.md` skills table. Plugin and directory names must all match. Run `claude plugin validate .` and `claude plugin validate <plugin-name>` after changes. Installed skills and agents are namespaced by plugin: `<plugin-name>:<skill-or-agent-name>`.

- `SKILL.md` starts with YAML frontmatter containing `name` and `description`, followed by the skill body in markdown. `name` must match the directory name: lowercase, hyphen-separated.
- The `description` is what Claude reads to decide whether to trigger the skill — write it as *what the skill does + when to use it* (including trigger phrases), not a summary of the body. It is the only part loaded before invocation.
- Agent files (`agents/*.md`) also start with `name` + `description` frontmatter; the body is the agent's system prompt. The `description` drives auto-delegation, so it states what the agent does, when to use it, AND when not to. Additional frontmatter supported for plugin agents: `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation: worktree` — but NOT `hooks`, `mcpServers`, or `permissionMode`. Give read-only advisor agents `disallowedTools: Write, Edit, NotebookEdit`. Omit `model` so agents inherit the session model.
- Supporting files live beside `SKILL.md` and are referenced from it by relative path. Keep `SKILL.md` lean; long reference material belongs in supporting files loaded on demand.

## Authoring conventions

- Skill bodies are instructions addressed to Claude, written in imperative voice ("Read the Gemfile", "Wait for approval").
- Skills that touch a user's codebase should gate destructive or bulk actions behind an explicit approval step (see `rails-context`'s Phase 1 → approval → Phase 2 flow for the pattern).
- Editing an existing skill: make surgical edits to the affected sections; don't regenerate the whole file.
- When a skill's behaviour changes, bump its `plugin.json` version in the same commit — that's what makes `/plugin marketplace update` meaningful for installed copies. Patch for wording fixes, minor for new capability.

## Git workflow

Commit directly on `main`. Never create a branch unless explicitly asked to.

Commit automatically, without asking, whenever a coherent unit of work is done — a skill created or edited, a convention changed, a correction folded in. Don't batch unrelated changes into one commit, and don't leave finished work sitting uncommitted. This overrides the global ask-before-every-commit rule for this repository. Pushing still requires explicit confirmation.

## Using these skills

Install via the marketplace: `/plugin marketplace add <path-or-repo>` then install skills individually, e.g. `/plugin install rails-context@mooktakim`. From a local checkout, add the marketplace by path (`/plugin marketplace add ~/Workspace/skills`). To test a change, invoke the skill in a Claude Code session inside a target project.
