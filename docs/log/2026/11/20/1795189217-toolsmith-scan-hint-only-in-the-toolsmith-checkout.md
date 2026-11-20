# toolsmith scan hint only in the toolsmith checkout

The owner saw "the last scan was N days ago" in almost every session of
every project (164 of 202 interactive sessions, 2026-10-24 to 11-20), and
does not want it there: scans are run from the skills repository, once in a
while, by choice.

The SessionStart hook now adds the scan note only when the session's cwd
(from the hook input) is in a checkout of the toolsmith source: a directory
at or above it holds toolsmith/ with crates/ and families.json. It reads the
last scan date from that checkout's toolsmith/metrics/weekly.json, where
scans save it, instead of the installed copy's, which only had the date of
the last release. The command list still shows everywhere. Version 0.5.3.

The weekly Rails maintenance nudges (rails-context, rails-design-system) stay
as they are; the owner chose to keep them.
