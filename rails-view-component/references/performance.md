# Performance

Read this before working on a slow page full of components, caching a component, or turning on instrumentation.

## Where the time goes

Components compile their templates to Ruby methods once, at boot in production, so a component render is cheap. A slow component page is almost always one of these:

1. **Queries in components** - an association or a scope called inside a component that renders in a list. Find them with the audit (`query` rule) or the log, and move the loading to the caller: `Invoice.includes(:customer, lines: :product)`. Strict loading (`.strict_loading` on the relation, or `config.active_record.strict_loading_by_default` in development) makes a component that lazy-loads raise.
2. **Too much markup** - a list of thousands of rows. Paginate, or load the rest lazily in a Turbo Frame.
3. **Work repeated per row** - a helper or a computation that is the same for every item. Compute it once in the caller and pass it to `with_collection` as an extra argument.

Measure before and after (the log's view and query times, or `rack-mini-profiler` if the app has it).

## Caching

- Fragment caching around a component in the caller (`<% cache invoice do %><%= render ... %><% end %>`): below 4.15 the cache digest covers the view template, not the component, so a change to the component does not expire the cache - add a deploy version to the key yourself. On 4.15+, `include ViewComponent::ExperimentallyCacheable` in the component (even without `cache_on`) registers it with the digestor so the surrounding `cache` block expires correctly, or add `Billing::InvoiceRowComponent.cache_digest` to the key.
- ViewComponent 4.15 adds experimental self-caching:
  ```ruby
  class Billing::InvoiceRowComponent < ApplicationComponent
    include ViewComponent::ExperimentallyCacheable
    cache_on :invoice, unless: -> { invoice.draft? }
  end
  ```
  The key covers the component's virtual path, template digest, format, variant, locale, and the `cache_on` values. Caching runs only when `perform_caching` is on (off by default in development and test). Limits: it raises if the caller passes content or slots; `cache_on` methods cannot use helpers; mixed-in modules are not in the digest; it is inherited, so never put it on a base class. The API may change in a minor release. Use it only where measurement shows a gain, and not in a component that takes content.
- Never cache a component whose output depends on the viewer, unless the viewer is in the key.

## Instrumentation

`config.view_component.instrumentation_enabled = true` emits `render.view_component` events (`name`, `identifier`) for profilers and APM tools. It costs time on every render; turn it on where you need the data.
