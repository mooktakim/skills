# Forms in components

Read this before putting a form, or a part of a form, in a component.

## Use the app's form builder

Forms use what the app already uses. Do not introduce a custom `FormBuilder`, a forms gem (`simple_form`, `view_component-form`, ...), or a form DSL.

1. Read the app: `default_form_builder` in controllers, a builder class in `app/form_builders/` or `app/helpers/`, a forms gem in `Gemfile.lock`, and two or three existing forms.
2. If the app has one, follow it - its field methods, its error display, its wrappers.
3. If it has none, use Rails: `form_with(model:)` and the standard `ActionView::Helpers::FormBuilder` field methods.

**`form_with` inside a component ignores a controller's `default_form_builder`** (v4 components do not get the controller's view setup). The app-wide `config.action_view.default_form_builder` still applies. If the app sets its builder per controller, pass it: `form_with(model: @invoice, builder: AppFormBuilder)`. If many components build forms, put a `form_with` override that defaults `builder:` in `ApplicationComponent`.

## Where the form lives

- **The form in the view, parts in components.** The view (or a form component) calls `form_with`; field groups, fieldsets, and repeated rows are components that receive the builder.
- **A whole-form component** when the same form appears in more than one place (new and edit, a page and a modal, a Turbo Stream re-render). It takes the model or form object and builds the form itself.

```ruby
class Billing::InvoiceFormComponent < ApplicationComponent
  def initialize(invoice:, url: nil)
    @invoice = invoice
    @url = url
  end

  def form_id = dom_id(@invoice, :form)
end
```

```erb
<%= form_with model: @invoice, url: @url, id: form_id do |form| %>
  <%= render Billing::LineFieldsComponent.with_collection(@invoice.lines, form: form) %>
  <%= form.label :due_on %>
  <%= form.date_field :due_on, aria: { describedby: (form.field_id(:due_on, :error) if @invoice.errors[:due_on].any?) } %>
  <% @invoice.errors.full_messages_for(:due_on).each do |message| %>
    <p id="<%= form.field_id(:due_on, :error) %>"><%= message %></p>
  <% end %>
  <%= form.submit data: { turbo_submits_with: t(".saving") } %>
<% end %>
```

## Components that receive the builder

```ruby
class Billing::LineFieldsComponent < ApplicationComponent
  with_collection_parameter :line

  def initialize(line:, form:)
    @line = line
    @form = form
  end
end
```

```erb
<%= @form.fields_for :lines, @line do |line_form| %>
  <%= line_form.label :description %>
  <%= line_form.text_field :description %>
<% end %>
```

- Take the builder as `form:`, and the attribute name when the component renders one field. Call the builder's methods (`form.text_field :email`), never `text_field_tag` for a model attribute: the `*_tag` helpers lose the param naming, the value, and the errors.
- Errors come from `form.object.errors[attribute]`; ids come from `form.field_id(attribute, :error)` and `form.field_id(attribute, :hint)`, which stay correct inside `fields_for` with an index. Link them to the input with `aria-describedby`, and set `aria-invalid` when there are errors.
- Nested attributes: `fields_for` yields a builder of the same class; pass it down as `form:`. The `lines_attributes` param names need `accepts_nested_attributes_for :lines` on the model; without it the names are `invoice[lines][...]`.
- A form object (`ActiveModel::Model` with `persisted?`) works with `form_with(model:)` like a record, and keeps multi-model forms out of controllers and components.
- Since ViewComponent 4.10, passing a builder into components and rendering fields in blocks inside them has no output-buffer problems. On older versions, see `upgrade.md`.

## Turbo and forms

- Failed validation: `render :new, status: :unprocessable_content` (`:unprocessable_entity` before Rack 3.1), or `render Billing::InvoiceFormComponent.new(invoice: @invoice), status: :unprocessable_content`. Success: `redirect_to ..., status: :see_other`.
- To replace only the form, stream it: `turbo_stream.replace(dom_id(@invoice, :form), Billing::InvoiceFormComponent.new(invoice: @invoice))`, with `method: :morph` to keep focus and typed input. The form's root needs that id.
- `data-turbo-submits-with` swaps the submit button's label while the request runs; Turbo also disables it.
- Auto-submitting forms call `requestSubmit()` (not `submit()`) from a generic Stimulus controller, so Turbo handles the submission.
- Dependent fields: first make it work with a plain GET round trip (`formaction`, `formmethod: :get`), then improve it with a frame or a small controller.
- A form in a broadcast component renders a CSRF token that is not the viewer's; Turbo sends the page's token in the request header, so the form still works when Turbo submits it. Do not turn Turbo off for it.

## Testing forms in components

- A component that takes `form:` needs a builder from the test's view context. Build the form in the test's view context and render inside it:
  ```ruby
  render_in_view_context(invoices(:draft)) do |invoice|
    form_with(model: invoice) { |form| render Billing::LineFieldsComponent.new(line: invoice.lines.first, form: form) }
  end
  assert_selector "input[name='invoice[lines_attributes][0][description]']" # Invoice accepts_nested_attributes_for :lines
  ```
  Or build one directly: `ActionView::Helpers::FormBuilder.new(:invoice, invoice, vc_test_view_context, {})`. Never use `vc_test_controller.view_context`: it makes a new view context on each call and the output comes out of order.
- Render with an invalid object (`invoice.tap(&:validate)`) and assert the error text, its id, and the input's `aria-describedby` and `aria-invalid`.
- The 422 path and the stream replace belong in an integration test; `data-turbo-submits-with` and dependent fields in a system test.
