# rails-context 0.8.0: byte-based size triggers + root budget

- Review defect 6: size rule counted lines only and the root had no budget. miraj root grew to 30 KB in 114 paragraph-long lines and never tripped anything; maynard/yardnote dir files reached 279-331 lines with no maintenance run.
- Size discipline: dir files review at 150 lines OR 10 KB; root has its own budget (aim < 8 KB, review at 200 lines OR 12 KB) since it loads every session. Root size repair moves directory-specific content down and never cuts content this skill did not write without asking.
- `bin/audit_context` now reports oversized files, root included (`size_note` helper). Verified read-only against real projects: flags miraj root (30 KB), maynard root + components/controllers/models, yardnote controllers/models/views/test, dinehere root (12 KB); lifeadmin clean.
- Generated root block now states the limits, so daily-work edits see them (skill body is only read at setup). README updated.
