# Turbo Frames

Read this before adding a Turbo Frame, lazy loading part of a page, targeting `_top` or another frame, or fixing "Content missing".

## When to use a frame

- **Scoped navigation:** links and forms inside the frame replace only the frame - inline editing, a filtered list, a paginated panel, a step inside a dialog.
- **Lazy loading:** `src` with `loading: :lazy` loads content when it scrolls into view - expensive or rarely seen parts, menus, trays, below-the-fold panels.
- **Not as a stream or broadcast target.** Turbo Streams target any element by id; a frame adds nothing and captures every link and form inside it. The handbook says to change such frames into plain elements.
- **Not for everything visible on first load.** Each `src` frame is one more request; several eager frames on a page cause N requests and jitter. Render visible content in the page.

## Ids

```erb
<%= turbo_frame_tag @card, :edit do %> ... <% end %>          <%# id="edit_card_42" %>
<%= turbo_frame_tag @article, :comments, src: article_comments_path(@article), loading: :lazy %>
<%= turbo_frame_tag :results do %> ... <% end %>                <%# a page singleton %>
```

- `turbo_frame_tag` builds the id with `dom_id` for records (and joins several arguments with `_`). Use `record, :purpose` so one record can have several frames; use a plain symbol only for a page singleton.
- The response must contain a `<turbo-frame>` with the same id. The response frame has no `src`.
- Keep the id in one place - a helper or the partial both views render - so the page and the response cannot drift.

## Targeting

| Want | Use |
|---|---|
| the whole page from a link or form inside a frame | `data: { turbo_frame: "_top" }` on the link or form, or `target: "_top"` on the frame (then opt single links back in with `data-turbo-frame="_self"`) |
| another frame | `data: { turbo_frame: "results" }` |
| the parent of a nested frame | `data-turbo-frame="_parent"` (Turbo 8.0.21+) |
| the URL to change with the frame | `data: { turbo_action: "advance" }` (or `"replace"`) on the frame, link, or form - then the server must render that state when the URL loads directly |

A form or link outside a frame can target it with `data-turbo-frame`; GET forms that filter a list are the common case.

## The server side

- turbo-rails sends frame requests through a minimal layout (`turbo_rails/frame`: CSRF metas plus `yield :head`) and varies the ETag. A controller with its own `layout "x"` overrides that and sends the full layout - correct, but slower. Use a layout method that returns `"turbo_rails/frame"` when `turbo_frame_request?`.
- `turbo_frame_request?` and `turbo_frame_request_id` are available in controllers and views. Do not render a different page for frame requests: the same URL must work as a full page. Use the request check only to skip expensive parts outside the frame.
- Frame forms may answer 200 (they are not Drive form submissions) or 4xx; both render into the frame. A redirect must land on a page that contains the frame.

## "Content missing"

The response had no frame with the id. Turbo writes "Content missing" into the frame, throws, and fires `turbo:frame-missing` (cancellable). Causes and fixes:

| Cause | Fix |
|---|---|
| the target page does not render the frame | render it, or target `_top` |
| the response is a login page after the session expired | `turbo_page_requires_reload` on the login page: Turbo then does a full visit |
| a redirect to a page without the frame | redirect to a page with it, or target `_top` |
| ids differ (built by hand in one place) | derive both from the same helper |

Custom handling: `addEventListener("turbo:frame-missing", e => { e.preventDefault(); e.detail.visit(e.detail.response) })`.

## Frame options

- `loading: :lazy` - load when visible. Pair with a placeholder inside the frame. A dialog can switch its lazy frames to eager when it opens (`frame.loading = "eager"`).
- `refresh: :morph` - on a page refresh (`morphing.md`), the frame reloads its `src` and morphs, instead of losing what it loaded. Use it on lazy and paginated frames on pages that refresh.
- `autoscroll: true` with `data-autoscroll-block` (`start`, `end`, `center`, `nearest`) and `data-autoscroll-behavior`.
- `disabled` - no navigation in the frame.
- `[busy]` and `aria-busy` while loading, `[complete]` when loaded, `frame.loaded` (a Promise), `frame.reload()`.
- `<turbo-frame>` is an inline element by default; give it `display: block` (or `contents`) where layout matters.

## Streams inside frame responses

A frame response can carry `<turbo-stream>` elements; Turbo runs them when the frame renders. Use this to update one thing outside the frame (a counter, a toggle button) without a second request.

## Events

`turbo:before-frame-render` (override `event.detail.render`, or pause it), `turbo:frame-render`, `turbo:frame-load`, `turbo:frame-missing`. A dialog opens on `turbo:frame-load`; a frame that should morph its new content can call `Turbo.morphChildren` from `before-frame-render`.
