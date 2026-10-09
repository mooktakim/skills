# Testing components

Read this before writing a component test, a preview test, or a broadcast test. The general test rules - fixtures, one behaviour per test, no network, no `sleep`, never weaken a test - come from the rails-minitest skill when it is installed; follow it. This file covers what is specific to components. For RSpec apps, use the same ideas with `ViewComponent::TestHelpers` in `type: :component` specs.

## The component test

```ruby
# test/components/billing/invoice_row_component_test.rb
require "test_helper"

class Billing::InvoiceRowComponentTest < ViewComponent::TestCase
  include ActionView::RecordIdentifier # dom_id; or include it once in a shared component test base

  test "shows the number and links to the invoice" do
    render_inline Billing::InvoiceRowComponent.new(invoice: invoices(:paid))
    assert_link "INV-001", href: "/invoices/#{invoices(:paid).id}"
  end

  test "marks an overdue invoice" do
    render_inline Billing::InvoiceRowComponent.new(invoice: invoices(:overdue))
    assert_text "Overdue"
  end

  test "rejects an unknown mode" do
    assert_raises(ArgumentError) { Billing::InvoiceRowComponent.new(invoice: invoices(:paid), mode: :wide) }
  end

  test "renders nothing for an invoice with no lines" do
    render_inline Billing::InvoiceRowComponent.new(invoice: invoices(:empty))
    refute_component_rendered
  end

  test "keeps the caller's attributes" do
    render_inline Billing::InvoiceRowComponent.new(invoice: invoices(:paid), class: "extra", data: { controller: "highlight" })
    assert_selector "##{dom_id(invoices(:paid))}.extra[data-controller~='highlight']"
  end
end
```

- `render_inline` returns a Nokogiri fragment and sets the page that the Capybara matchers (`assert_selector`, `assert_text`, `assert_link`, `assert_button`, `assert_field`) check. `rendered_content` is the HTML string, for debugging.
- Assert what a user perceives - text, links, buttons, fields, labels - and the attributes that are the component's contract: the id streams target, `data-controller` and its values, `aria-*`. Avoid asserting design class names; they change for visual reasons.
- Test each state and option the API defines, `render?` both ways, each slot filled and empty, and that the caller's attributes are merged. Not every combination.
- Test through the output. Never call private methods with `send`.

## Context helpers

| Need | Helper |
|---|---|
| a URL helper that needs a request (rare - pass values in instead) | `with_request_url("/invoices?tab=open") { render_inline ... }` |
| a request variant | `with_variant(:phone) { ... }` |
| a different format | `with_format(:json) { ... }` |
| a specific controller for every test in the file | `def vc_test_controller_class = Admin::BaseController` |
| render inside the view context (forms, helpers) | `render_in_view_context { ... }` |
| a preview as the example | `render_preview(:overdue)` |

## Every preview renders

```ruby
# test/components/previews_test.rb
require "test_helper"

class PreviewsTest < ViewComponent::TestCase
  ViewComponent::Preview.all.each do |preview|
    preview.examples.each do |example|
      test "#{preview.name} #{example} renders" do
        render_preview(example, from: preview)
        assert_predicate rendered_content, :present?
      end
    end
  end
end
```

## Turbo and broadcasts

- A stream response is an integration test: `patch invoice_path(invoice), params: ..., as: :turbo_stream`, then `assert_turbo_stream action: :replace, target: invoice`.
- A broadcast test runs the job, so the component really renders through `ApplicationController.render` and `render_later` serialization: wrap the save in `perform_enqueued_jobs` and assert with `capture_turbo_stream_broadcasts` or `assert_turbo_stream_broadcasts`. See `broadcasting.md`.
- Ids that streams target: assert them in the component test (`assert_selector "##{dom_id(invoice)}"`).

## System tests

Only for behaviour that needs a browser: a Stimulus controller, morphing that must keep state, a broadcast that must appear. Visit the real page (or a preview page), act, and use Capybara's waiting matchers. Keep them few.
