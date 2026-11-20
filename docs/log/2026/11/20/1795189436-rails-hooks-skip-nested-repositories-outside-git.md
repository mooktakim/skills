# Rails hooks skip nested repositories outside git

The 2026-11-20 usage review found that a session started in ~/Workspace (a
folder of repositories, not itself a git repository) ran every Rails
plugin's SessionStart hook into its timeout: about 125 cancelled hooks
(10 s for the notes, 30 s for the maintenance nudges). Outside git,
`hooks/rails-apps.sh` searched the whole tree with `find` and found 43 apps
across other projects; the one nudge that finished listed apps from
dinehere, evchargerwidget and firstmate/data.

Outside git, the search now also prunes every directory below the project
directory that has a `.git` (a repository or a worktree), so a folder of
repositories has no apps of its own. In ~/Workspace the search went from
2.3 s and 43 apps to 0.15 s and none; each SessionStart hook ends in about
0.27 s with no output. A Rails app with no git at all is still found (0.18 s
on a copy of lifeadmin). Inside git nothing changes.

All seven copies of rails-apps.sh changed together; patch versions bumped:
rails-context 0.17.2, rails-design-system 0.21.2, rails-generators 0.3.1,
rails-hotwire 0.4.1, rails-minitest 0.3.1, rails-specialists 0.6.1,
rails-view-component 0.4.1.
