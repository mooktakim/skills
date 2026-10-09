# Helpers, URLs, and translations

Read this before using a helper, a URL helper, or a translation in a component.

## What a component already has

`ViewComponent::Base` (v4) includes `ActionView::Helpers` and the app's route helpers. So `tag`, `content_tag`, `link_to`, `button_to`, `class_names`, `token_list`, `dom_id`, `number_to_currency`, `time_ago_in_words`, `l`, and `*_path` work directly, with no `helpers.` prefix.

v4 does not subclass `ActionView::Base`, so the app's own helpers and gem helpers registered on controllers are not there. `use_helper` and `use_helpers` were removed in v4.

## Reaching other helpers

In order of preference:

1. **Include a pure helper module** - one whose methods use only their arguments and the tag helpers:
   ```ruby
   class Ui::IconComponent < ApplicationComponent
     include IconHelper
   end
   ```
   Put modules many components need in `ApplicationComponent`, one by one. Never `include ApplicationHelper`.
2. **Include the gem's helper module** - `include Turbo::FramesHelper` for `turbo_frame_tag`, `include Turbo::StreamsHelper` for `turbo_stream_from`.
3. **Delegate to the view's helpers** - `delegate :markdown, to: :helpers`, for a helper that needs the view (an asset helper from a gem, a helper with its own state). It works only while rendering: never in `initialize`. Rich text: `delegate :rich_textarea_tag, to: :helpers`.

Calling `helpers.something` couples the component to whatever controller renders it. Never use it to reach request state (`helpers.current_user`, `helpers.request`, `helpers.params`) - pass those values in.

## URLs

- `*_path` works directly. Pass every route parameter explicitly - `edit_invoice_path(invoice)`, never a helper that fills them in from the current request.
- `*_url` in a broadcast or a mailer needs a host: set `Rails.application.routes.default_url_options[:host]` per environment, or use `*_path`.
- "Is this the current page?" is a caller decision: pass `current: true`, or `current_path:`, instead of calling `current_page?` or `request.path` inside the component.

## Request-free components

A component is request-free when it reads nothing from the current request, session, or user. Make every component request-free; it is required for any component that is broadcast (`broadcasting.md`), and it is what makes previews and tests simple.

| Instead of | Pass in |
|---|---|
| `helpers.current_user` | `viewer:` (or the specific fact: `editable:`, `owned:`) |
| `params[:tab]` | `tab:` |
| `request.path`, `current_page?` | `current:` |
| `Current.account` | `account:` |
| `controller.action_name` | the option the action implies (`mode: :edit`) |

Authorisation stays on the server side of the caller: the controller or view decides `editable: policy.update?` and the component shows or hides the control. The component never decides who may do what.

## Translations

Sidecar translations are on by default. Put `invoice_row_component.yml`, or per-locale files such as `invoice_row_component.en.yml`, beside the component (`config.view_component.generate.distinct_locale_files = true` makes the generator create per-locale files):

```yaml
en:
  title: "Invoice %{number}"
  overdue: "Overdue"
```

- `t(".title", number: invoice.number)` resolves against the sidecar file. Keep all of a component's own strings there; shared strings (`t("invoices.status.paid")`, absolute keys) stay in the app's locale files.
- `t` raises in `initialize`; call it in `before_render`, the template, or a method the template calls.
- Follow the app's existing approach: if components use the app's locale files under a `components.` scope, keep doing that.
- Subclasses inherit their parent's translations and can override keys.
