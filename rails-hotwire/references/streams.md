# Turbo Stream responses

Read this before writing a Turbo Stream response, a stream template, a custom stream action, or flash messages after a stream. Broadcasting the same actions over Action Cable is in `broadcasting.md`.

## The actions

| Action | Effect | Notes |
|---|---|---|
| `append` / `prepend` | add the template's content at the end / start of the target | an existing child with the same id is removed and the new one inserted at the end / start: it moves, it is not duplicated |
| `before` / `after` | insert next to the target | duplicate siblings removed (8.0.21+) |
| `replace` | swap the whole target element | `method: :morph` morphs it instead |
| `update` | swap the target's children; the element (and its listeners) stays | `method: :morph` morphs the children |
| `remove` | remove the target | no template |
| `refresh` | ask the page to refresh itself (`morphing.md`) | ignored by the tab whose request caused it |

There is no `morph` action: morph is `method: :morph` on `replace` or `update`. `targets:` (and the `*_all` builder methods: `turbo_stream.remove_all(".notice")`) apply to every element matching a CSS selector.

## Responding from a controller

```ruby
def create
  @comment = @card.comments.build(comment_params)
  if @comment.save
    respond_to do |format|
      format.turbo_stream                      # renders create.turbo_stream.erb
      format.html { redirect_to @card, status: :see_other }
    end
  else
    render :new, status: :unprocessable_content   # the request accepts HTML too, so new.html.erb renders
  end
end
```

```erb
<%# app/views/comments/create.turbo_stream.erb %>
<%= turbo_stream.before [@card, :new_comment], @comment %>                 <%# renders comments/_comment %>
<%= turbo_stream.update [@card, :new_comment], partial: "comments/form", locals: { card: @card } %>
<%= turbo_stream.replace [@card, :meta], partial: "cards/meta", locals: { card: @card }, method: :morph %>
```

- **A stream template per action** (`create.turbo_stream.erb`) once there are more than one or two actions. Keep `format.turbo_stream` bare in `respond_to`. Share templates between controllers with `format.turbo_stream { render "reactions/create" }`, and compose them from stream partials (`_refresh.turbo_stream.erb`).
- **Inline** `render turbo_stream: [...]` for one or two actions, ideally in a named controller method or concern (`render_card_replacement`).
- Targets: a record (`@comment` gives `dom_id`), an array (`[@card, :meta]` gives `meta_card_42`), a model class (`Comment` gives `new_comment`), or a string id. The target element must already have that id; for `replace`, the new content must carry it again or the next stream cannot find it.
- Keep the `format.html` path: the same action works without streams, and failures still render with 4xx.
- Streams render the `:html` partials (`_comment.html.erb`); never write separate stream-only markup.

## Streams for GET requests

Turbo asks for streams on non-GET form submissions. A link or GET form needs `data-turbo-stream` to accept them. Prefer frames for GET (a stream response is not idempotent on back and forward); use GET streams when one click must change several places. From JavaScript, `@rails/request.js`: `get(url, { responseKind: "turbo-stream" })` applies the streams in the response.

## Flash after a stream

A stream response does not redirect, so the layout's flash does not render. Give the layout a flash container with a fixed id and replace it from the stream with a helper:

```ruby
# app/controllers/concerns/turbo_flash.rb
module TurboFlash
  extend ActiveSupport::Concern
  included { helper_method :turbo_stream_flash }

  private

  def turbo_stream_flash(**flash)
    turbo_stream.replace(:flash, partial: "layouts/flash", locals: { flash: flash })
  end
end
```

```erb
<%= turbo_stream_flash(notice: t(".saved")) %>
```

- Use `flash.now` (or pass the message directly) for stream responses, or the message shows again on the next page.
- The flash element removes itself (a Stimulus controller on `animationend`, or a timeout) and carries `data-turbo-temporary` so the cache does not keep it.
- Announce it: the container is (or sits inside) an `aria-live="polite"` region that stays in the page (`patterns.md`).
- On pages that refresh by morph, a redirect with `flash[:notice]` is often simpler than a stream: the refresh morphs the flash in.

## Custom stream actions

Add one only for a small DOM primitive that several responses need and no built-in action covers (scroll a target into view, set an attribute, dispatch an event). Behaviour belongs in Stimulus controllers that react to inserted HTML - not in streams.

```js
// app/javascript/actions/scroll_into_view.js, imported once from application.js
// importmap apps pin only @hotwired/turbo-rails; bundler apps may import StreamActions from "@hotwired/turbo"
import { Turbo } from "@hotwired/turbo-rails"
Turbo.StreamActions.scroll_into_view = function () {
  this.targetElements.forEach(element => element.scrollIntoView({ block: "center" }))
}
```

```ruby
# config/initializers/turbo_stream_actions.rb
ActiveSupport.on_load :turbo_streams_tag_builder do
  def scroll_into_view(target) = action(:scroll_into_view, target)
end
```

`turbo:before-stream-render` (wrap `event.detail.render`) can adjust every stream render - for example keeping the scroll position when content is prepended above the viewport.

## Request ids

Turbo sends `X-Turbo-Request-Id` with every request; turbo-rails stores it in `Turbo.current_request_id`, and refresh broadcasts carry it so the tab that caused a change ignores its own refresh. Only `refresh` is suppressed: targeted broadcasts reach the originating tab too (append and prepend de-duplicate by id). A `turbo_stream.refresh` in a direct HTTP response carries the current request id and is ignored by the very tab that receives it - redirect instead, or pass `request_id: nil`.
