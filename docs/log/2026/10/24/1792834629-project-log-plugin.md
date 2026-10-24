# 2026-10-24 project-log plugin
- Goal: split the work log out of project-memory, so a project with its own knowledge system can still keep the log (user request).
- Changed: new project-log plugin 0.1.0: docs/LOG.md protocol template (log rules moved from MEMORY.md unchanged), SKILL.md with setup, the legacy history migration (moved from project-memory unchanged) and upgrade, Rust `project-log lint` (entry names and UTC dates, legacy logs, secrets in entries), composite CI action, README, marketplace entry, root README row, test/project_log_test.rb.
- Decisions: two crates, no shared workspace, because an installed plugin has only its own directory; date.rs and scan.rs are byte-identical copies of project-memory's, and a test fails when they drift.
- Open questions: none; project-memory moves onto it in the next commit.
