# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A hand-authored collection of Claude Code skills for Rails development. There is no application code, build step, or test suite — every deliverable is a skill directory containing markdown instructions for Claude.

## Repository structure

The repo is a Claude Code plugin marketplace (`rails-skills`) hosting a single plugin (`rails`) that bundles all skills:

```
.claude-plugin/marketplace.json          # marketplace manifest; lists the plugin(s)
plugins/rails/
  .claude-plugin/plugin.json             # plugin manifest
  skills/<skill-name>/
    SKILL.md           # required: frontmatter + instructions
    <supporting files> # optional: scripts, templates, references
```

New skills go under `plugins/rails/skills/` — no manifest changes needed; the plugin picks up every skill directory automatically. Installed skills are namespaced as `rails:<skill-name>`.

- `SKILL.md` starts with YAML frontmatter containing `name` and `description`, followed by the skill body in markdown.
- `name` must match the directory name: lowercase, hyphen-separated.
- The `description` is what Claude reads to decide whether to trigger the skill — write it as *what the skill does + when to use it* (including trigger phrases), not a summary of the body. It is the only part loaded before invocation.
- Supporting files live beside `SKILL.md` and are referenced from it by relative path. Keep `SKILL.md` lean; long reference material belongs in supporting files loaded on demand.

## Authoring conventions

- Skill bodies are instructions addressed to Claude, written in imperative voice ("Read the Gemfile", "Wait for approval").
- Skills that touch a user's codebase should gate destructive or bulk actions behind an explicit approval step (see `rails-context`'s Phase 1 → approval → Phase 2 flow for the pattern).
- Editing an existing skill: make surgical edits to the affected sections; don't regenerate the whole file.

## Git workflow

Commit directly on `main`. Never create a branch unless explicitly asked to.

Commit automatically, without asking, whenever a coherent unit of work is done — a skill created or edited, a convention changed, a correction folded in. Don't batch unrelated changes into one commit, and don't leave finished work sitting uncommitted. This overrides the global ask-before-every-commit rule for this repository. Pushing still requires explicit confirmation.

## Using these skills

Install via the marketplace: `/plugin marketplace add <path-or-repo>` then `/plugin install rails@rails-skills`. From a local checkout, add the marketplace by path (`/plugin marketplace add ~/Workspace/skills/rails`). To test a change, invoke the skill (`/rails:<skill-name>`) in a Claude Code session inside a target Rails app.
