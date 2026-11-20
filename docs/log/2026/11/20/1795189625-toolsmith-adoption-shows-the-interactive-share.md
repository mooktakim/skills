# toolsmith adoption shows the interactive share

The 2026-11-20 usage review found the adoption shares mixed headless
sessions (entrypoint "sdk-cli": Bridge and no-mistakes workers, where the
toolsmith hook is off by design since 0.5.1) with the owner's own sessions
(entrypoint "cli"), so a falling share could mean either.

`analyse` now marks each Bash call interactive when its record's entrypoint
is "cli", keeps the same weekly counts again under "interactive" in
metrics/weekly.json, and `analyse adoption` adds an "interactive share"
column ("n/a" for weeks saved before the split). Version 0.6.0.

First reading (W44 to W47): the interactive share is higher for most tools
(text-replace 94%, file-lines 81-88%, conflict-resolve, pr-land and json-set
100% in W47), but toolsmith-check-run fell in interactive sessions too
(94% -> 64%), so that drop is real, not a headless artefact.
