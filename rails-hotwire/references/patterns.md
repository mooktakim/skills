# UI patterns

Read this before building one of these patterns. Each shows the recommended Hotwire approach and its pitfalls.

## Dialogs and modals

Native `<dialog>` with one generic `dialog` controller (`showModal()`, `close()`, Escape for free). Content arrives in a frame inside the dialog.

```erb
<%# in the layout %>
<dialog id="modal" data-controller="dialog"
        data-action="turbo:frame-load->dialog#open turbo:submit-end->dialog#closeOnSuccess turbo:before-cache@document->dialog#close turbo:before-morph-attribute->dialog#keepOpen">
  <%= turbo_frame_tag "modal" %>
</dialog>

<%# a trigger anywhere %>
<%= link_to "New card", new_card_path, data: { turbo_frame: "modal" } %>

<%# new.html.erb renders the form inside turbo_frame_tag "modal", and works as a full page too %>
```

```js
open() { this.element.showModal() }
close() { this.element.close() }
closeOnSuccess(event) { if (event.detail.success) this.element.close() }
keepOpen(event) { if (event.detail.attributeName === "open") event.preventDefault() }
```

- A failed submit re-renders the form with 422 inside the frame; the dialog stays open. A success answers with streams that update the page and empty the `modal` frame (the dialog closes on `turbo:submit-end`). A plain redirect from inside the frame lands on a page without the `modal` frame and shows "Content missing" - to redirect, handle it on the frame: `turbo:frame-missing->dialog#visit` with `visit(event) { event.preventDefault(); event.detail.visit(event.detail.response) }`, which turns it into a full visit.
- A dialog that is part of the page (a picker, a menu) can hold lazy frames that load when it opens.
- Return focus to the trigger on close; put `autofocus` on the first field.
- On small screens a full page is often better than a modal; the same URL already works as a page.

## Inline editing

The display partial wraps itself in `turbo_frame_tag record, :edit`; `edit.html.erb` renders the same frame with the form; `update` redirects to the display (`status: :see_other`) or renders 422. Links that should leave the frame carry `data-turbo-frame="_top"`. On a page that refreshes by morph, protect an open edit (`morphing.md`).

## Search and filters

A GET form targeting a frame around the results, with `data-turbo-action="replace"` (or `"advance"`) so the URL is shareable, debounced with `requestSubmit()` (`forms.md`). Do not use streams for search: they do not survive back and forward.

## Pagination and infinite scroll

Each page renders its items plus a lazy frame for the next page:

```erb
<%= render @page.records %>
<% unless @page.last? %>
  <%= turbo_frame_tag "cards_page_#{@page.next_param}", src: cards_path(page: @page.next_param), loading: :lazy, refresh: :morph, target: "_top" %>
<% end %>
```

- Frames are idempotent on back and forward; appending rows with streams duplicates them.
- `refresh: :morph` keeps loaded pages through a page refresh.
- Cursor pagination (geared_pagination, or `id`/`created_at` keysets) stays correct while new records arrive.

## Tabs

Cheap panels: render all, switch with a controller (`role="tablist"`, `role="tab"`, `aria-selected`, `aria-controls`, arrow keys). Expensive panels: tab links target a frame with `data-turbo-action="advance"` so each tab has a URL; keep the tab bar inside the frame so the server renders the selected state.

## Flash and toasts

A fixed `#flash` element in the layout, inside a persistent `aria-live="polite"` region; redirects render it normally, stream responses replace it with a helper (`streams.md`). It removes itself after its animation and carries `data-turbo-temporary`. Use `flash.now` with streams.

## Optimistic UI

Hotwire has none built in. A controller changes the DOM at once (marks a row done, inserts a placeholder), then submits with `requestSubmit()`; the stream response replaces the placeholder with the server's version; on `turbo:submit-end` without `detail.success`, roll back. Use it only where latency hurts.

## Sorting by drag and drop

A controller with native drag and drop (or SortableJS) that, on drop, sends the new position with `@rails/request.js` (`patch(url, { body: { position } })`). The server answers `head :no_content` (or a stream) and broadcasts a refresh for other viewers. Offer move-up and move-down buttons for keyboard users. Protect a drag in progress from morphs.

## Confirmation dialogs

`data-turbo-confirm` uses the browser's `confirm()`. For a styled dialog, replace it once:

```js
Turbo.config.forms.confirm = (message) => new Promise(resolve => {
  const dialog = document.getElementById("confirm")
  dialog.querySelector("[data-message]").textContent = message
  dialog.addEventListener("close", () => resolve(dialog.returnValue === "confirm"), { once: true })
  dialog.showModal()
})
```

## Live updates

Refresh broadcasts for shared pages, targeted streams for feeds and private trays (`broadcasting.md`). Subscribe with `turbo_stream_from` inside `<body>`. Catch up after a reconnect on pages that must not miss updates.

## Counters and empty states

Prefer CSS so a stream that adds or removes items needs no extra action: `.list:not(:has(.item)) + .empty-state { display: block }`. Server numbers update with an extra action in the same response (`turbo_stream.update "unread_count", @count`). Never put a per-user count in a shared stream.

## Multi-step forms

One URL per step on a persisted draft record (`/signups/:id/steps/company`): each step saves and redirects to the next. Back, reload, and native apps all work. Avoid one form with hidden steps: errors land on fields the user cannot see.

## Accessibility of dynamic updates

- Keep one `aria-live="polite"` region in the layout, outside anything that streams replace or morphs rebuild; update its text (`turbo_stream.update`), never replace the region itself. `role="alert"` only for errors.
- Focus after changes: into a dialog when it opens, back to the trigger when it closes, to a neighbour or the heading after a row is removed, to the first error after a failed submit (`autofocus`).
- Drive navigations are not announced by screen readers: give every page a distinct `<title>`, and consider announcing it on `turbo:load` and focusing the main `<h1>`.
- Turbo sets `aria-busy` during visits, form submissions, and frame loads: style loading states from it.
