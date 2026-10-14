# rails-design-system 0.5.0: HTML style guide removed

- User changed their mind on the browsable HTML style guide; removed entirely. The system is now markdown specs + audit script + PostToolUse hook only.
- Removed: preview pages from Phase 2 generation order and doctrine, preview-sync maintenance work kind, Phase 3 @source wiring step (existed only for preview purging), references/preview.md (deleted), all preview mentions in the pointer block, README router shape, skill README, and manifests.
- Added maintenance self-cleanup (rails-context precedent): re-runs propose deleting leftover docs/design-system HTML pages and the @source directive from apps set up by earlier versions (dinehere has both).
- Phase 1 no longer needs to locate the compiled CSS.
