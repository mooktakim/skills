# rails-design-system 0.9.1: Phase 3 hardening

- Review defects 15-17.
- 15: step order was already script -> hook, but `chmod +x` was a parenthetical and nothing proved the wiring (miraj: hook went live before chmod, 4 "Permission denied" errors). New step 3: explicit chmod + smoke test - plants a bg-gray-100 view, runs --hook and --stop from app/ (exit 2 expected), then a clean file (exit 0), removes the test file. Must pass before step 4 wires hooks; results reported in Phase 4. Smoke block verified byte-equal to a script run in a scratch repo. Maintenance runs the smoke test after updating the script.
- 16: miraj run did `bundle add view_component` then hand-edited the pin without re-locking -> stale Gemfile.lock failed all 5 CI jobs. New generation rule: gems only when the approved plan lists them, via `bundle add`, then confirm Gemfile.lock changed and `bundle check` passes.
- 17: yardnote's .claude/settings.json was gitignored, so the hook lived on one machine. Phase 3 (and maintenance) now runs `git check-ignore -q .claude/settings.json` and reports; proposes `!.claude/settings.json`, never edits .gitignore unasked.
- Embedded audit script unchanged (so the maintenance nudge's script comparison is unaffected).
