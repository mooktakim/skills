# Component design

Read this before creating a component or changing its API. It covers ViewComponent 4.x; for v3 apps see `upgrade.md`.

## Component, partial, or helper

| Need | Use |
|---|---|
| Markup with inputs, logic, states, or more than one use | a component |
| A section used once, on one page, with no logic | the view itself (or a partial, if the app does that) until a second use appears |
| A plain value - a formatted string, a URL, a label | a helper or a model method |
| A whole page | a view template that composes components; a page-as-component only where the app already does that |

Extract bottom up: the small repeated parts first, then the parts made of them. Wait for the third similar instance before you build a shared, configurable component; two similar instances are often two different things.

Two kinds of component live in a library:

- **Building blocks** - generic, know nothing about the domain (`Ui::ModalComponent`, `Ui::EmptyStateComponent`). Inputs are plain values, slots, and options.
- **Domain components** - take a domain object and render it, usually by composing building blocks (`Billing::InvoiceRowComponent.new(invoice:)`).

## The initializer

```ruby
class Billing::InvoiceRowComponent < ApplicationComponent
  STATES = %i[compact full].freeze

  def initialize(invoice:, mode: :full, selectable: false, **html_attributes)
    @invoice = invoice
    @mode = STATES.include?(mode) ? mode : raise(ArgumentError, "unknown mode: #{mode.inspect}")
    @selectable = selectable
    @html_attributes = html_attributes
  end

  private

  attr_reader :invoice, :mode
  def selectable? = @selectable
  def overdue? = invoice.due_on.past? && !invoice.paid?
end
```

- Keyword arguments only. Required arguments have no default; a missing one is an `ArgumentError` at the call site.
- Assign and validate; nothing else. No helpers, no `t`, no queries, no formatting.
- Methods the template calls are private. Templates can call private methods; tests cannot, which keeps tests on the output.
- Pass the domain object, not ten of its attributes, unless the component is a building block that must stay domain-free.
- v4 has no catch-all initializer, so `dry-initializer` works if the app already uses it. Do not add it for one component.

## Lifecycle

| Hook | Runs | Use for |
|---|---|---|
| `initialize` | when the caller builds the component | assigning arguments |
| `render?` | before rendering; false renders nothing | "nothing to show" |
| `before_render` | before `render?`, with the view context and slots available; it runs even when `render?` is false | values that need helpers, `t`, or slot content; keep it cheap |
| `around_render` | wraps the render (v4) | instrumentation, rarely |

```ruby
def render? = invoice.lines.any?   # lines preloaded by the caller

def before_render
  @title = t(".title", number: invoice.number)
end
```

- `before_render` is for view-context work, not data loading. Data arrives through the initializer.
- Do not rescue errors in `around_render`; a component that hides its own exceptions hides bugs.

## Content and slots

`content` is the block the caller passes; `content?` says whether there was one. Use it when the component wraps one region. Use slots for named regions.

```ruby
class Ui::PanelComponent < ApplicationComponent
  renders_one :header, "HeaderComponent"                       # nested component class, as a string
  renders_many :actions, Ui::ActionComponent                   # component slot
  renders_one :footer                                          # plain slot: any block
  renders_one :title, ->(level: 2, &block) { content_tag(:"h#{level}", &block) }   # lambda slot
  renders_one :visual, types: {                                # polymorphic slot
    icon: Ui::IconComponent,
    avatar: ->(**args) { Ui::AvatarComponent.new(size: :small, **args) }
  }

  def default_footer = Ui::PanelFooterComponent.new           # v4 default slot

  class HeaderComponent < ApplicationComponent
    def initialize(sticky: false) = @sticky = sticky
    def call = tag.header(content, data: { sticky: @sticky })
  end
end
```

```erb
<%= render(Ui::PanelComponent.new) do |panel| %>
  <% panel.with_header(sticky: true) { "Invoices" } %>
  <% panel.with_visual_icon(name: :receipt) %>
  <% panel.with_action(href: new_invoice_path) { "New" } %>
  <%= render Billing::InvoiceRowComponent.with_collection(@invoices) %>
<% end %>
```

- Setters start with `with_`; `with_<slot>_content("text")` works for a slot that takes no arguments; a list goes in at once with `with_actions([{ href: "/a" }, ...])`.
- In the template, check optional slots with `header?` before wrapping them in markup.
- Prefer component slots to plain slots when the slot has its own structure: the slot's API is then checked like any component's.
- Slot content is not available in `initialize`; read it in `before_render` or the template.
- Add a slot only for a region callers really fill differently. A slot for every element is an API nobody can learn.

## Collections

```ruby
class Billing::InvoiceRowComponent < ApplicationComponent
  with_collection_parameter :invoice

  def initialize(invoice:, invoice_iteration: nil, mode: :full)
    @invoice = invoice
    @iteration = invoice_iteration   # first?, last?, index, size
    @mode = mode
  end
end
```

```erb
<%= render Billing::InvoiceRowComponent.with_collection(@invoices, mode: :compact) %>
<%= render Billing::InvoiceRowComponent.with_collection(@invoices, spacer_component: Ui::DividerComponent.new) %>
```

- Extra keyword arguments go to every item. The counter (`invoice_counter`) and iteration (`invoice_iteration`) arguments are optional; accept them only when you use them.
- The caller preloads what every row needs (`Invoice.includes(:customer, :lines)`).
- An empty collection renders nothing; put the empty state beside it in the caller, or in a list component with an `empty` slot.

## Templates and files

| Style | Use when |
|---|---|
| `foo_component.html.erb` beside the class | the default for anything with markup |
| sidecar directory `foo_component/foo_component.rb` + template, preview, controller, translations | the app already uses it, or the component has several files |
| `def call` returning `tag.*` | a component that is one tag around its content |
| `erb_template <<~ERB` | a few lines of markup; keep it short |

Follow the app's style; set it once in `config.view_component.generate.*` (`sidecar`, `preview`, `stimulus_controller`, `locale`) so the generator matches.

- No Ruby logic or local variable assignment in templates beyond `if`, `each`, and calling the component's methods. A condition that needs a name gets a method (`overdue?`).
- Variants (`call_phone`, `foo_component.html+phone.erb`) only when the app uses request variants.
- A subclass inherits its parent's template and can wrap it with `render_parent`. Use it for the base-class case only.

## HTML attributes

A component that renders one root element accepts the caller's attributes and merges them, so callers can add an id, a test hook, a Stimulus controller, or an extra class without a new option.

```ruby
class ApplicationComponent < ViewComponent::Base
  private

  # Merge the caller's attributes into the component's own, without losing either.
  def merge_attributes(own, theirs)
    own.merge(theirs) do |key, mine, other|
      case key.to_sym
      when :class then class_names(mine, other)
      when :data, :aria then mine.merge(other) { |k, a, b| k.to_s.in?(%w[controller action]) ? token_list(a, b) : b }
      else other
      end
    end
  end
end
```

```erb
<%= tag.section(**merge_attributes({ id: dom_id(@invoice), class: "invoice", data: { controller: "toggle" } }, @html_attributes)) do %>
```

- The component's own required attributes (`id` used as a stream target, `role`, `aria-*` it relies on) are set after the merge when the caller must not change them.
- Class strings are literals in the source (frozen constants or hashes), never built by interpolation: CSS tooling that scans the source cannot see `"text-#{tone}"`. What the classes are is the design system's business, not this skill's.

## Naming and namespaces

- `Billing::InvoiceRowComponent` lives in `app/components/billing/invoice_row_component.rb`; modules are plural like controllers when they name a resource.
- Name after the output (`AvatarComponent`), not the input (`UserImageComponent`).
- One namespace for the building blocks, chosen by the app (`Ui::`, `Common::`); domain namespaces mirror the app's domains.
- A section of the app with its own audience (admin, marketing) may get its own namespace; components do not cross that boundary unless the app says they may.

## The base class

```ruby
# app/components/application_component.rb
class ApplicationComponent < ViewComponent::Base
  include Turbo::FramesHelper      # only if components render frames
  # shared infrastructure: merge_attributes, stimulus_id (stimulus.md), small pure helper modules
end
```

- Set `config.view_component.generate.parent_class = "ApplicationComponent"` (the generator also picks it up by itself when it exists).
- Never `include ApplicationHelper` here: it drags every app helper, and their hidden dependencies on the request, into every component. `ActionView::Helpers` and the route helpers are already included; do not include them again.
- A matching `ApplicationComponentPreview < ViewComponent::Preview` holds shared preview helpers.
- `TurboViewComponent < ApplicationComponent` is the second base class when the app has self-broadcasting components (`broadcasting.md`).
