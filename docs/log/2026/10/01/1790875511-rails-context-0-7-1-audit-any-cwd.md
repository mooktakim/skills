# rails-context 0.7.1: audit_context works from any directory

- `bin/audit_context` now does `cd "$(dirname "$0")/.."` first. Before, running it from a subfolder (e.g. `cd app && ../bin/audit_context`) printed "No context files found" and exited 0 - a false all-clear. Found in the 2026-10-01 usage review, reproduced and verified fixed in a scratch repo. Existing apps get it on their next maintenance run.
