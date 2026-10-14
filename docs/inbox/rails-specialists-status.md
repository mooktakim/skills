---
id: rails-specialists-status
type: decision
status: proposed
summary: rails-specialists plugin - standing design constraints, field results, and what is unproven (as of 2026-10-01)
created: 2026-10-01
sources: [auto memory rails-specialists-status.md]
---

Standing constraints from the user's planning choices (2026-08-15), still in force: no `model:` pinning (agents inherit the session model); stack-agnostic (the user rejected baking their personal rails.md tech defaults into the agents); advisor agents (debugger, reviewer, security, performance) stay read-only via `disallowedTools`; no orchestrator agent, and agents never ask the user anything - they stop and return plans or commands in their report.

Field result (usage review 2026-10-01, see [[usage-review-2026-10]]): `rails-reviewer` found 12 real bugs in 2 maynard runs, zero false positives - but Claude never delegated to any specialist on its own. Fixed by "Use proactively" description leads (reviewer, security, tester, debugger, performance) plus a SessionStart note in Rails projects.

**Why:** the agents only earn their place if they actually get used; descriptions alone lost to general-purpose/Explore.
Roster change (2026-10-08): the user moved test work out - the tester now ships in the new `rails-minitest` plugin, renamed `rails-minitest:minitest-runner` (user's choice, named for its main use) (Minitest only, skill preloaded via `skills:`), rails-specialists 0.4.0 has nine agents. See [[rails-minitest-status]].
Roster change (2026-10-09): rails-hotwire moved out to the rails-hotwire plugin as `rails-hotwire:hotwire-builder`; rails-specialists 0.5.0 has eight agents. ViewComponent work goes to `rails-view-component:component-builder`. Add `rails-hotwire:` and `rails-view-component:` to the count command's prefixes.
Roster decision (2026-10-01): option A - change nothing, wait 2-3 weeks (check from about 2026-10-22), then count real delegations per agent in the transcripts. If rails-model, rails-hotwire and rails-jobs stay at zero while the user builds models, Turbo UI and jobs, propose option B: convert them to skills the main session loads (fold in or point to the user's installed turbo-hotwire / viewcomponent / phlex skills). Deploy and upgrade stay agents either way.

Count command (unique tool calls; a plain grep counts each call twice because transcripts log it twice). Baseline on 2026-10-01: 2 x rails-reviewer, nothing else.
`python3 -c 'import glob,json,os,collections as C;s=set();c=C.Counter()
for f in glob.glob(os.path.expanduser("~/.claude/projects/*/*.jsonl")):
  for l in open(f,errors="ignore"):
    if "rails-specialists:" not in l and "rails-minitest:" not in l: continue
    try: m=json.loads(l).get("message") or {}
    except Exception: continue
    for b in (m.get("content") if isinstance(m,dict) and isinstance(m.get("content"),list) else []):
      t=(b.get("input") or {}).get("subagent_type","") if isinstance(b,dict) else ""
      if t.startswith(("rails-specialists:","rails-minitest:")) and b.get("id") not in s: s.add(b.get("id")); c[t]+=1
print(c.most_common())'`

Speed decision (2026-10-04): user asked about Sonnet for slow agents; advised no (reviewer value is bug recall; time is tool calls). Shipped parallel launch + scope-in-prompt instead (rails-specialists 0.3.0, rails-design-system 0.15.0). Baseline: 28 of 43 same-session agent pairs ran sequentially; medians reviewer 174s, design-reviewer 115s, security 239s. At the ~2026-10-22 check, also re-measure overlap and durations. If still too slow, next lever is `effort`/Sonnet for rails-tester only, or `CLAUDE_CODE_SUBAGENT_MODEL` per machine - not pinning the reviewers.

**How to apply:** when the user returns to this, run the count first and decide from it; do not reopen the roster without data, since the full roster was the user's deliberate choice.
