# rails-design-system 0.14.0: audit rules can be scoped to a section's paths

- Found by the capture skill's dry run on maynard: the "admin badges have no dot" rule must not fire on the public site, whose status-badge spec has a dot on purpose. audit-rules had no scoping.
- Rule lines take an optional third part: `<label> :: <regex> :: <path prefix> <path prefix>...`. Applied in --hook, --stop/--changed and the full scan (`rule_applies?`). Full-scan checks now carry a per-path predicate instead of a skip-vendor flag.
- Documented in SKILL.md Phase 3 and the design-reviewer's "Promote to the audit". New test `test_rules_can_be_limited_to_a_sections_paths`; suite 71 tests green on Ruby 4.0 and on Ruby 2.6 + bash 3.2.
