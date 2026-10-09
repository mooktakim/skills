# Upgrading to current Hotwire

Read this when the app runs rails-ujs, Turbolinks, Turbo 7 (turbo-rails below 2.0), Stimulus 1.x syntax, or removed Turbo APIs. Upgrades are app-mode work: plan them and get approval first.

## Target

turbo-rails 2.0.x (Turbo 8.0.x), stimulus-rails 1.3.x (Stimulus 3.2.x), and importmap-rails 2.x for importmap apps.

## rails-ujs to Turbo

| rails-ujs | Turbo |
|---|---|
| `link_to "Delete", post, method: :delete` | `button_to "Delete", post, method: :delete` |
| `data-confirm` / `data: { confirm: }` | `data-turbo-confirm` on the form or submitter (`button_to ..., form: { data: { turbo_confirm: } }`) |
| `data-disable-with` / `disable_with:` | `data-turbo-submits-with` (Turbo disables the submitter anyway) |
| `remote: true`, `data-remote`, `local: false` | nothing: every form submits through Turbo; respond with a redirect, a 422, or a stream |
| `.js.erb` responses (`create.js.erb`) | a Turbo Stream template (`create.turbo_stream.erb`) or a redirect |
| `ajax:success` / `ajax:error` events | `turbo:submit-end` (`detail.success`) |
| `Rails.ajax` | `@rails/request.js` |

Remove `@rails/ujs` from the importmap or package.json and `Rails.start()`. With both loaded, links and forms can submit twice.

## Turbolinks to Turbo

`turbolinks:load` becomes `turbo:load` (better: a Stimulus controller), `data-turbolinks="false"` becomes `data-turbo="false"`, `data-turbolinks-track` becomes `data-turbo-track`, `Turbolinks.visit` becomes `Turbo.visit`. Remove the `turbolinks` gem and package. Forms now submit through Turbo, so add 422 statuses to failure renders.

## Turbo 7 to Turbo 8

- New: page refreshes with morphing, hover prefetch (on by default - check GET links that change state), view transitions, `Turbo.config`.
- A redirect back to the same URL is now a `replace` visit.
- Then, per 8.0.21: `data-turbo-cache="false"` on elements is gone (use `data-turbo-temporary`), `Turbo.clearCache()` is gone (use `Turbo.cache.clear()`), and the `requestSubmit` / `SubmitEvent` polyfills are gone.
- Deprecated: `Turbo.setProgressBarDelay`, `setConfirmMethod`, `setFormMode` - use `Turbo.config.drive.progressBarDelay`, `Turbo.config.forms.confirm`, `Turbo.config.forms.mode`.
- `:unprocessable_entity` is deprecated on Rack 3.1+; use `:unprocessable_content`.

## Stimulus 1 and 2 syntax

`data-target="search.query"` becomes `data-search-target="query"` (the old form still works with a deprecation warning); `this.data.get("url")` and `data-search-url` become `static values` and `data-search-url-value`; `import { Controller } from "stimulus"` becomes `from "@hotwired/stimulus"`.

## Steps

1. Run the audit (`scripts/audit_hotwire`) and the integration and system tests for a baseline.
2. Update gems and pins (`bundle update turbo-rails stimulus-rails`, `bin/importmap pin @hotwired/turbo-rails` where pinned from a CDN); confirm the lock and pin files changed.
3. Fix the findings group by group, running the affected tests after each.
4. Walk the app in a browser: navigation, back button, every form (success and failure), deletes with confirms, live updates.
5. Run the audit again, and record the new conventions in `app/javascript/CLAUDE.md` if the app has one.
