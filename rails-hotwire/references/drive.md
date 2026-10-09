# Turbo Drive

Read this before working on links, navigation, redirects, the page cache, prefetch, the progress bar, `<head>` and assets, view transitions, or turning Drive off. Current: turbo-rails 2.0.x ships Turbo 8.0.x (8.0.23 in January 2026; there is no Turbo 9).

## Visits

- A link or form under Drive is a fetch: Turbo replaces `<body>`, merges `<head>`, and pushes history. `advance` (the default) pushes a history entry, `replace` replaces it (`data-turbo-action="replace"` or `Turbo.visit(url, { action: "replace" })`), and `restore` is Turbo's own back/forward visit - never set it yourself.
- Cancel a visit in `turbo:before-visit` (`event.preventDefault()`); restoration visits cannot be cancelled.
- Event order for a visit: `turbo:click`, `turbo:before-visit`, `turbo:visit`, `turbo:before-fetch-request`, `turbo:before-fetch-response`, `turbo:before-cache`, `turbo:before-render` (has `renderMethod`), `turbo:render`, `turbo:load`. With a cached preview, the render events fire twice.
- Page setup belongs in Stimulus controllers. `DOMContentLoaded` and `$(document).ready` run once per full load, not on each visit; `turbo:load` code must be idempotent because it runs again on restores.

## Redirects and status codes

| Response | Use |
|---|---|
| success of a non-GET form | `redirect_to ..., status: :see_other` (303), or a Turbo Stream |
| failed validation | `render :new, status: :unprocessable_content` (422; `:unprocessable_entity` before Rack 3.1). Turbo renders 4xx/5xx HTML in place and keeps the URL |
| 200 to a non-GET form | wrong: Turbo raises "Form responses must redirect to another location" and the page does not change |

- A redirect back to the current URL becomes a `replace` visit, and with morph refreshes it morphs the page (see `morphing.md`) - the simplest way to show a change on the same page.
- Rails' scaffold uses `ActionDispatch::Constants::UNPROCESSABLE_CONTENT`, which picks the right symbol for the Rack version - use it in code that must run on both.
- Downloads and other non-HTML links: `download` attribute, `data-turbo="false"`, or a URL ending in an unvisitable extension (`.pdf`, `.csv`, ...). Otherwise Drive fetches it, sees non-HTML, and reloads the page - two requests.

## State-changing links and confirm

- **Everything that changes state is a non-GET: `button_to`, or a form.** `data-turbo-method` on a link works but is second choice (the handbook: real forms and buttons are better for accessibility), and a plain GET link that changes state is a bug: hover prefetch runs it.
- Confirm: `data-turbo-confirm` on a form or submitter, or on a link that also has `data-turbo-method`. With `button_to`: `button_to "Delete", post, method: :delete, form: { data: { turbo_confirm: "Delete this post?" } }`.
- Custom confirm dialog: `Turbo.config.forms.confirm = (message, form, submitter) => Promise<boolean>` (`setConfirmMethod` is deprecated). See `patterns.md`.

## Prefetch on hover (Turbo 8)

- On by default: hovering a link for 100 ms sends a low-priority GET with `X-Sec-Purpose: prefetch`; one cached response, kept for 10 s; leaving the link cancels it.
- Never prefetched: other origins, links with `target`, `download`, `#` links, `data-turbo="false"`, non-GET `data-turbo-method`, `data-turbo-confirm`, `data-turbo-stream`.
- Opt out: `data-turbo-prefetch="false"` on a link or an ancestor (`"true"` turns it back on inside), `<meta name="turbo-prefetch" content="false">` for the page, or cancel `turbo:before-prefetch` (for example on `navigator.connection.saveData`).
- Consequences: GET endpoints must be safe to call on hover. Do not count prefetches as page views - check `request.headers["X-Sec-Purpose"] == "prefetch"`. Expensive pages get extra load; turn prefetch off for links to them.
- `data-turbo-preload` is different: it loads a link into the snapshot cache when the page loads. Use it on a few key links only.

## The page cache

- Before Drive leaves a page it stores a copy (`cloneNode`). Back and forward show the copy at once; a normal visit to a cached URL shows it as a preview (`html[data-turbo-preview]`) until the fresh page arrives. Listeners and JavaScript state are not in the copy; Stimulus reconnects on it.
- Remove one-off elements with `data-turbo-temporary` (flash messages, notices). `data-turbo-cache="false"` on elements was removed in Turbo 8.0.21.
- Reset transient UI on `turbo:before-cache` - close menus and dialogs, reset forms, tear down widgets: `data-action="turbo:before-cache@document->dialog#close"`.
- Per page: `turbo_exempts_page_from_cache` (never cached) or `turbo_exempts_page_from_preview` (restore only); both need `yield :head` in the layout. JavaScript: `Turbo.cache.clear()` (`Turbo.clearCache()` was removed).
- Non-GET form submissions clear the cache; page refreshes neither show previews nor store snapshots.

## Progress and busy state

- The progress bar appears after 500 ms (`Turbo.config.drive.progressBarDelay = ms`; `setProgressBarDelay` is deprecated). Style `.turbo-progress-bar`.
- `html[aria-busy="true"]` during a visit, `aria-busy` on a submitting form and a loading frame: style busy states from these attributes.

## `<head>`, assets, and scripts

- Load the JavaScript entry point in `<head>`. Scripts in `<body>` run again on every visit.
- Fingerprinted CSS and JS carry `data-turbo-track="reload"` (Rails layouts do this): a changed asset forces a full reload after a deploy. `data-turbo-track="dynamic"` on a `<link>` or `<style>` removes it when the next page lacks it; never on scripts.
- Drive appends new stylesheets and scripts from the new `<head>` and replaces titles and metas.

## `data-turbo-permanent`

An element with `data-turbo-permanent` and the same unique id on both pages is moved, live, into the next page - listeners and state included - and morphs skip it. Use it for elements whose content must not change across pages: a media player, a third-party widget. It freezes the element: never use it to keep state that the server may change (see `morphing.md`).

## Meta tags

| Tag | Effect | Rails helper |
|---|---|---|
| `turbo-visit-control` `reload` | always a full page load, also from a frame | `turbo_page_requires_reload` (login pages, pages with Drive-hostile scripts) |
| `turbo-cache-control` `no-cache` / `no-preview` | cache rules for the page | `turbo_exempts_page_from_cache` / `_from_preview` |
| `turbo-prefetch` `false` | no hover prefetch | - |
| `turbo-refresh-method` / `turbo-refresh-scroll` | `morph` / `preserve` | `turbo_refreshes_with method: :morph, scroll: :preserve` |
| `turbo-root` | Drive only under this path | - |
| `view-transition` `same-origin` (or `turbo-view-transition` `true`, 8.0.14+) | View Transitions API between visits | - |

The helpers use `provide :head`: the layout must `yield :head` inside `<head>`.

## View transitions

Both the current and the next page need the meta tag, and the browser must support the API. Turbo skips them under `prefers-reduced-motion: reduce` (8.0.14+). `html[data-turbo-visit-direction]` is `forward`, `back`, or `none`, for direction-aware CSS. Name stable regions (`view-transition-name: header`) or records (`view-transition-name: <%= dom_id(record) %>`) for element transitions.

## Turning Drive off

- `data-turbo="false"` on an element or ancestor (`"true"` re-enables inside). Use it for links to pages that cannot run under Drive, and for forms that must do a full POST (some OAuth and payment redirects).
- App-wide opt-in mode: `Turbo.session.drive = false` (alias of `Turbo.config.drive.enabled`); forms only: `Turbo.config.forms.mode = "off" | "optin"`.
- Paths ending in an extension listed in `Turbo.config.drive.unvisitableExtensions` (`.pdf`, `.csv`, `.zip`, images, media) are not handled by Drive; other extensions are.

## Configuration API (Turbo 8.0.6+)

`Turbo.config.drive.progressBarDelay`, `Turbo.config.drive.unvisitableExtensions`, `Turbo.config.forms.confirm`, `Turbo.config.forms.mode`, `Turbo.config.forms.submitter` (`"disabled"` or `"aria-disabled"`). The old `Turbo.set*` functions are deprecated.
