# Previews

Read this before adding or changing a preview, or setting up previews or Lookbook.

## Setup

- Previews live in `test/components/previews/`, mirroring `app/components/`: `test/components/previews/billing/invoice_row_component_preview.rb`.
- They are served at `/rails/view_components` in development and test. v4 config is under `config.view_component.previews.*` (`paths`, `route`, `enabled`, `default_layout`, `controller`).
- Set a layout that loads the app's CSS and JavaScript, so previews look and behave like the app: `layout "component_preview"` per class, or `config.view_component.previews.default_layout`.
- Lookbook (a browsing UI over the same preview classes) only if the app has it or the user approves adding it.

## One preview per component, one example per state

```ruby
class Billing::InvoiceRowComponentPreview < ApplicationComponentPreview
  # @param mode select [full, compact]
  def default(mode: :full)
    render Billing::InvoiceRowComponent.new(invoice: invoice, mode: mode.to_sym)
  end

  def overdue
    render Billing::InvoiceRowComponent.new(invoice: invoice(due_on: 3.days.ago))
  end

  def with_slots
    render(Ui::PanelComponent.new) do |panel|
      panel.with_header { "Invoices" }
      panel.with_action(href: "#") { "New" }
    end
  end

  private

  def invoice(**attributes)
    Invoice.new(number: "INV-001", total_cents: 12_000, due_on: 1.week.from_now, customer: Customer.new(name: "Ada"), **attributes)
  end
end
```

- One example per state and option the component's API defines; name each after the state (`overdue`, `empty`, `with_slots`), not `example_1`.
- **Build unsaved records** (`Invoice.new(...)`) in the preview. Never read the database (`Invoice.first`) and never write to it: previews must render on an empty database, in development and in tests.
- Preview method arguments become URL parameters (and Lookbook `@param` controls); give each a default.
- Extreme data belongs in its own example: a long name, an empty list, a missing optional field.
- Shared builders go in `ApplicationComponentPreview` (private methods), not in each preview.
- `render_with_template` and a template in `test/components/previews/<preview_name>/` when an example needs surrounding markup.

## Previews in tests

- A component test can render a preview: `render_preview(:overdue)` - one source for the example and the test.
- One test renders every preview, so a broken preview fails CI (see `testing.md`).
