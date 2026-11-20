# toolsmith scan skips transcripts that vanish mid-scan

The 2026-11-20 usage review's `analyse scan` crashed with Errno::ENOENT: a
no-mistakes worktree's transcript folder was removed between the glob and the
read. `load_calls` now skips a transcript it can no longer open. A test plants
a dangling `.jsonl` symlink to reproduce it. Version 0.5.2.

The same review saved this week's counts to `toolsmith/metrics/weekly.json`.
