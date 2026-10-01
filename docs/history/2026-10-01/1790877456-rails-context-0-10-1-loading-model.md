# rails-context 0.10.1: correct the context-loading model

- Review defect 14: SKILL.md claimed "agents load every file on the path down to where they're working". Per Claude Code docs, nested CLAUDE.md loads only when Claude reads a file in that dir with the Read tool; Bash reads/edits and writes into an unread dir do not load it. Field data: 0 nested_memory loads in dinehere (Bash-heavy sessions); files reached Claude only because the root block told it to look.
- Fixed the two wrong statements (one-fact-one-level chain, nested files) and the size-discipline wording; added a "How the chain loads matters" paragraph.
- Root block (Phase 3) now says: before changing code in a directory, read its CLAUDE.md and its parents' - automatic loading happens only on Read. Existing apps get the new block on their next maintenance run.
