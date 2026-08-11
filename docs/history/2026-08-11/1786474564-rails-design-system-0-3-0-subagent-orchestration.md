# rails-design-system 0.3.0: subagent orchestration

- Phase 1 survey now delegates fact-gathering to one read-only subagent (inline fallback); the plan and approval conversation stay in the main session.
- Phase 2 dispatches one generation agent per approved section (sections are islands, so they parallelize with no shared state). Interviews resolve at the gate BEFORE dispatch; agent prompts carry the answers, file list, token prefix, and skill-directory path; agents never ask the user anything. Main session doctrine-checks all agent output, then writes the two cross-section files (README router + index.html) itself.
- The Phase 1 plan must state the agent count so fan-out is user-approved, never a surprise (per user's global rule about swarm features).
- Section-scoped maintenance work may dispatch the same way.
- Rationale: whole-skill-in-a-subagent was rejected - subagents cannot talk to the user, which breaks both approval gates. rails-context deliberately NOT changed: output too small to justify orchestration.
