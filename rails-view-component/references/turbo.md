# Components with Turbo

Read this before rendering a component in a Turbo Stream or a Turbo Frame, giving a component an id, or making it survive morphing. Broadcasting over Action Cable is in `broadcasting.md`.

## Pick the lightest tool

Turbo Drive navigation, then a Turbo Frame (scoped navigation, lazy loading), then a Turbo Stream response (several targets from one request), then a broadcast (pushed to other users). Use the first one that does the job.

## Turbo Stream responses

The stream helpers accept a component as the content, and a record as the target (the target becomes `dom_id(record)`):

```ruby
def update
  if @invoice.update(invoice_params)
    render turbo_stream: [
      turbo_stream.replace(@invoice, Billing::InvoiceRowComponent.new(invoice: @invoice)),
      turbo_stream.update("flash", Ui::FlashComponent.new(notice: t(".saved")))
    ]
  else
    render Billing::InvoiceFormComponent.new(invoice: @invoice), status: :unprocessable_content
  end
end
```

```erb
<%# update.turbo_stream.erb - for more than two or three actions %>
<%= turbo_stream.replace @invoice, Billing::InvoiceRowComponent.new(invoice: @invoice) %>
<%= turbo_stream.replace dom_id(@invoice), method: :morph, renderable: Billing::InvoiceRowComponent.new(invoice: @invoice) %>
<%= turbo_stream.append "invoices" do %>
  <%= render Billing::InvoiceRowComponent.new(invoice: @invoice) %>
<% end %>
```

- **The target id must be on the component's root element.** `replace` swaps the whole element, so a replacement without the same id cannot be found by the next stream. Give the component `id: dom_id(invoice)` on its root (or the prefixed id the caller uses).
- One new component instance per stream action (ViewComponent 4.14+ raises on reuse).
- `method: :morph` on `replace` or `update` keeps focus, scroll, and Stimulus state inside the element (Turbo 8).
- Failed validation re-renders with a 4xx status (`:unprocessable_content` on Rack 3.1+, `:unprocessable_entity` before); success redirects with `status: :see_other`. Turbo ignores a 200 response to a form submission.
- `render Component.new` from a controller renders inside the controller's layout for HTML requests - right for a full-page re-render. Pass `layout: false` for a fragment. Content cannot come through a block there; use `Component.new(...).with_content("...")` or slots.
- To get a component as a string in a controller, use `view_context.render(Component.new(...))`. `render_to_string(Component.new(...))` wraps it in the layout unless you pass `layout: false`.

## Turbo Frames

```ruby
class Billing::CommentsPanelComponent < ApplicationComponent
  include Turbo::FramesHelper

  def self.frame_id(invoice) = ActionView::RecordIdentifier.dom_id(invoice, :comments)

  def initialize(invoice:, lazy: true)
    @invoice, @lazy = invoice, lazy
  end

  def call
    turbo_frame_tag self.class.frame_id(@invoice),
      src: (invoice_comments_path(@invoice) if @lazy), loading: (:lazy if @lazy), refresh: :morph do
      content
    end
  end
end
```

- The frame id is part of the component's public contract. Derive it in one place (a class method) and use it from the controller, the frame's response, streams, and tests. A frame response with no matching `<turbo-frame id>` shows "Content missing".
- A frame scopes every link and form inside it to that frame. Wrap a component in a frame only when it navigates inside the frame or loads lazily. A frame is not a broadcast target: use a plain element with an id (`broadcasting.md`).
- A link that must leave the frame gets `data: { turbo_frame: "_top" }`. Let the caller decide this through an option or an attribute, not by hard-coding it in a building block.
- `refresh: :morph` on a frame with `src` reloads and morphs that frame on a page refresh instead of dropping its loaded content.
- Frames render through `turbo_frame_tag`; include `Turbo::FramesHelper` in the component or in `ApplicationComponent`.

## Ids and morphing

Turbo 8 page refreshes morph the new page into the old one. Ids are what the morph uses to match moved and reordered elements.

- Give each list item, each element with a `data-controller`, each form, and each `<details>` or `<dialog>` a stable `dom_id`-based id.
- An id is unique on the page. A component rendered twice on one page takes a prefix from the caller: `dom_id(invoice, :sidebar)`.
- Never use `SecureRandom`, `object_id`, or a counter for ids: every refresh then replaces instead of morphing, and Stimulus controllers reconnect.
- `data-turbo-permanent` (with an id) keeps an element untouched across navigation and morphs - third-party widgets, players, an open popover. Its content then never updates, so expose it as an option (`permanent: true`), not a default.
- When a library adds DOM next to an element (a select replaced by a widget), the morph removes the added DOM. Mark the widget's wrapper permanent, or rebuild it on `turbo:morph-element`.
- Keep one attribute during a morph (an open `<details>`) by cancelling `turbo:before-morph-attribute` for it in a Stimulus controller.
- `turbo_stream_from` renders a `<turbo-cable-stream-source>` element; keep it out of grid and flex containers, where it takes a cell.

## Turbo helpers in components

| Helper | How to reach it in a component |
|---|---|
| `turbo_frame_tag` | `include Turbo::FramesHelper` |
| `turbo_stream_from`, `turbo_stream` | `include Turbo::StreamsHelper` (v4 supports it) |
| `dom_id`, `dom_class` | already there |
