---
name: rails-hotwire
description: Build interactive Rails UI with Hotwire - Turbo Drive, Turbo Frames, Turbo Streams, broadcasts over Action Cable, Turbo 8 page refreshes and morphing, and Stimulus - the way 37signals and the Turbo source intend. Covers choosing the lightest tool, form responses and status codes, prefetch and the page cache, frame ids and lazy loading, stream templates and custom actions, refresh vs targeted broadcasts, signed and authorised streams, keeping state through morphs, Stimulus controller design and cleanup, common UI patterns (dialogs, inline editing, search, infinite scroll, flash, autosave), accessibility of dynamic updates, testing, Hotwire Native readiness, and upgrading from rails-ujs, Turbolinks, or Turbo 7. Use when building or changing anything interactive in a Rails app that uses turbo-rails or stimulus-rails, when a Turbo navigation, frame, stream, broadcast, or form "does nothing" or behaves oddly, when writing a Stimulus controller, or when asked to audit or upgrade an app's Hotwire setup. ViewComponent-specific wiring lives in the rails-view-component skill.
---

# Rails Hotwire

You build Rails UI the Hotwire way: the server renders HTML, Turbo moves it to the browser, and Stimulus adds only the behaviour HTML cannot express. Pages work as plain HTML first; every layer on top is an enhancement. This file holds the rules for every change. The `references/` files beside it hold the detail - they ship with this skill, so resolve their paths from this skill's directory (`${CLAUDE_SKILL_DIR}`), not the app. Read the matching one before you write that kind of code:

| Read | Before |
|---|---|
| `references/drive.md` | links, navigation, redirects, the page cache, prefetch, the progress bar, `<head>` and assets, view transitions, turning Drive off |
| `references/frames.md` | adding a Turbo Frame, lazy loading, targeting `_top` or another frame, fixing "Content missing" |
| `references/streams.md` | a Turbo Stream response, a stream template, a custom stream action, flash messages after a stream |
| `references/broadcasting.md` | pushing updates over Action Cable: refresh or targeted broadcasts, stream names, authorisation, adapters |
| `references/morphing.md` | page refreshes, `method: :morph`, or anything that must keep its state through a morph |
| `references/stimulus.md` | writing or changing a Stimulus controller, or loading controllers |
| `references/forms.md` | a form that submits through Turbo: statuses, errors, submit buttons, confirm, autosubmit, autosave, dependent fields |
| `references/patterns.md` | dialogs, inline editing, search and filters, pagination and infinite scroll, tabs, flash, optimistic UI, sorting, live counters, and the accessibility of dynamic updates |
| `references/testing.md` | testing stream responses, frames, broadcasts, morphs, or Stimulus behaviour |
| `references/native.md` | an app that ships, or will ship, Hotwire Native iOS or Android shells |
| `references/upgrade.md` | an app on rails-ujs, Turbolinks, Turbo 7, or Stimulus 1.x syntax, or using removed Turbo APIs |

For components: when the UI is a ViewComponent, the rails-view-component skill owns rendering components in streams and broadcasts, component Stimulus identifiers, and `TurboViewComponent`. The rules here still apply. Visual design belongs to the app's design system.

## Two modes

- **Writing mode** - the Hotwire parts of a change, or a fix. Follow the rules below. Changes that belong to the task need no approval step.
- **App mode** - the user asks to audit, upgrade, or reorganise the app's Hotwire setup. Follow "App mode" at the end: survey, plan, approval, apply, verify.

## Detect first

1. Read `Gemfile.lock`: `turbo-rails` (2.x ships Turbo 8), `stimulus-rails`, `importmap-rails` or `jsbundling-rails` or `vite_rails`, `requestjs-rails`, `view_component`, and the cable adapter in `config/cable.yml` (production). Below turbo-rails 2.0, or with rails-ujs or Turbolinks loaded, read `references/upgrade.md` first.
2. Read the layouts: `turbo_refreshes_with` (morph refreshes), view-transition and prefetch meta tags, `yield :head`, where the JavaScript loads.
3. Read `app/javascript/CLAUDE.md` and `app/views/CLAUDE.md` if they exist, `app/javascript/controllers/index.js`, and two or three existing controllers and stream templates, for the app's idiom.
4. Look for the app's own Hotwire helpers (`app/helpers/*turbo*`, `*stream*`, a flash stream helper, form helpers that add Stimulus attributes) and use them.

The app's settled conventions win on style: naming, where streams live, how flash is shown, how state is styled. The rules marked **hard** below win over the app. In writing mode, follow them in new code and report the old violations you saw; fix old ones only in app mode.

## Rules for every change

**Choosing the tool**

1. Use the lightest tool that does the job, in this order: a plain link or form under Turbo Drive (with a redirect back, which morphs when refreshes morph); a Turbo Frame for navigation scoped to one part of the page or for lazy loading; a Turbo Stream response for several targeted changes from one request; a broadcast for changes other people must see. Add Stimulus only for behaviour HTML cannot express - and never custom JavaScript outside a Stimulus controller.
2. **(hard)** The server renders all UI as HTML. JavaScript never builds markup from JSON. A controller that needs data fetches a rendered fragment (a frame, a stream, or an HTML partial).
3. Every interaction works as a full-page request first: the same URL renders the whole page, and the frame or stream only narrows what changes. Keep a `format.html` path next to every `format.turbo_stream`.

**Drive and forms**

4. **(hard)** Anything that changes state is a non-GET request: `button_to` or a form, never a plain link. Turbo 8 prefetches GET links on hover, so a state-changing GET link runs when a user points at it.
5. **(hard)** A failed form submission renders with a 4xx status (`status: :unprocessable_content`; `:unprocessable_entity` before Rack 3.1); a successful one redirects (`status: :see_other` for update and destroy, as the Rails scaffold does) or answers with a stream. Turbo shows nothing for a 200 response to a form submission.
6. Pages survive the page cache and back button: flashes and one-off notices carry `data-turbo-temporary`; open menus, dialogs, and widgets close or tear down on `turbo:before-cache`; nothing assumes a page loads once (no `DOMContentLoaded`).

**Frames and streams**

7. A Turbo Frame exists for navigation inside it or for lazy loading. **(hard)** Never use a frame only as a stream or broadcast target: a frame captures every link and form inside it. A stream target is any element with an id.
8. **(hard)** Every frame id and stream target is derived from records - `turbo_frame_tag record, :purpose`, `dom_id(record, :purpose)` - or is a fixed name for a page singleton (`:flash`, `:notifications`). Never random, never built by hand from ids. Ids are unique on the page.
9. Stream responses with more than one or two actions live in an `action.turbo_stream.erb` template; render partials into streams instead of repeating markup.

**Broadcasts**

10. Prefer a refresh broadcast (`broadcasts_refreshes`, with `touch: true` on children) for pages that show the same records to many people: each browser re-renders its own page with its own session. Use targeted broadcasts for fragments that look the same to everyone - chat lines, feeds, counters - or for high-frequency updates.
11. **(hard)** Broadcast markup is request-free and viewer-independent: no `current_user`, `Current`, `request`, `params`, or session in anything a broadcast renders. Personalise on the client (a meta tag with the viewer id plus CSS or a controller) or use a refresh broadcast.
12. **(hard)** Broadcast after commit and render in a job: `_later` methods (`broadcast_replace_later_to`), from `after_*_commit` callbacks or the `broadcasts_*` macros. Only `remove` stays synchronous - a job cannot load a deleted record.
13. **(hard)** A stream that carries private data is scoped to who may see it (`[Current.account, :invoices]`, `[user, :notifications]`) and, when access can be lost, checked at subscription in a custom channel. A signed stream name proves the server issued it; it never expires and is not bound to a user.

**Morphing**

14. On pages that morph (refreshes, `method: :morph`, `refresh: :morph` frames), protect what the user is doing: cancel `turbo:before-morph-attribute` for an open `<dialog>` or `<details>`, cancel `turbo:before-morph-element` for a control with an unsubmitted edit, and rebuild JavaScript-owned DOM on `turbo:morph`. Reserve `data-turbo-permanent` for elements whose content never changes (a player, a third-party widget), with a stable unique id - never use it to keep state.

**Stimulus**

15. A controller is small, named after a behaviour (`toggle`, `auto-submit`, `clipboard`), configured from HTML with values, targets, classes, and params, and reused across pages. Logic that is the same in several controllers goes in a plain module in `app/javascript/helpers/`.
16. State lives in the DOM - values, `hidden`, `aria-*`, `data-*` attributes - so the server, the cache, and morphs can all restore it. React to a changed value in `<name>ValueChanged`, not only in `connect`.
17. **(hard)** A controller undoes in `disconnect()` everything it set up: listeners on `window` or `document` (or declare them as `@window` / `@document` actions), timers, observers, third-party instances. It reaches only its own element, targets, and outlets - never `document.querySelector` with a fixed selector.
18. Controllers talk through dispatched events (`this.dispatch("changed")` plus a `data-action`), or outlets when one controller really drives another.

**Accessibility**

19. Use native elements first: `<button>` for actions, `<a>` for navigation, `<dialog>` for modals, `<details>` for disclosure. Keep `aria-expanded`, `aria-pressed`, and `aria-busy` in step with state. After a frame or stream changes what the user was working on, put focus where they expect it; announce changes that matter in an `aria-live` region.

**Tests**

20. Test each layer where it is cheapest: stream and frame responses in integration tests (`as: :turbo_stream`, `assert_turbo_stream`), broadcasts in model tests that run the jobs (`include ActiveJob::TestHelper`, `perform_enqueued_jobs`, `assert_turbo_stream_broadcasts` with the expected count, including zero for people who must not get it), and only what needs a browser - Stimulus behaviour, morphs that keep state, live updates - in system tests. The rails-minitest skill's rules apply to all of them when it is installed.

**Verify in a browser.** Check the change in a real browser when the app can run: the happy path, the failed-validation path, the back button, and - for live updates - a second window. After a Turbo navigation, wait for the new page before you look.

## App mode

The approval gate is a hard stop. Change nothing until the user approves the Phase 1 plan in a reply to that plan ("approve", "yes", "go", or edits to it). A reply about something else is not approval.

### Phase 1: survey and plan

1. From the app root, run `ruby "${CLAUDE_SKILL_DIR}/scripts/audit_hotwire"`. It reports the stack, the layouts' Turbo setup, an inventory (controllers, stream templates, frames, broadcasts, subscriptions, system tests), and findings with file and line. Its header comment explains each rule. Its findings are leads: confirm each one in the code before it goes into the plan.
2. If the app has `rails-view-component`, also run its audit for the component side.
3. Run the integration and system tests once for the baseline, delegated to `rails-minitest:minitest-runner` when that agent is available.
4. Present the plan, grouped, each item with its files and a one-line reason:
   - **Upgrade:** rails-ujs or Turbolinks removal, Turbo 7 to 8, removed APIs, Stimulus 1.x syntax (`references/upgrade.md`).
   - **Correctness:** form statuses, state-changing GET links, sync broadcasts, request state in broadcast partials, unauthorised private streams.
   - **Structure:** frames used only as targets, inline streams to move into templates, duplicated controllers to merge into one generic controller, helpers to extract.
   - **Morphing:** pages to switch to morph refreshes, and the state each one must protect.
   - **Stimulus hygiene:** leaks, global queries, unregistered controllers.
   - **Tests:** behaviour with no test at the right level.

   Say what you will not change and why. Then wait for approval.

### Phase 2: apply

Work in this order: upgrade, correctness, structure, morphing, Stimulus hygiene, tests. Gem and package changes go through `bundle` or `bin/importmap`, and you confirm the lock or pin file changed. Run the affected tests after each group, and check each changed interaction in a browser.

### Phase 3: verify and report

1. Run the full suite (`bin/rails test:all`) and the audit again. Both must be no worse than the baseline.
2. Walk the changed pages in a browser: navigation, back button, forms (success and failure), live updates in two windows.
3. If the app has `app/javascript/CLAUDE.md` or `app/views/CLAUDE.md`, update them with the conventions this run set up.
4. Report what changed, the findings before and after, and what is left. Commit only when the user or the project's rules say so.
