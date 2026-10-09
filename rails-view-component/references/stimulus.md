# Stimulus with components

Read this before attaching a Stimulus controller to a component, or loading controllers that live beside components.

## Where a controller lives

- **Generic behaviour** (`toggle`, `clipboard`, `dialog`, `autosubmit`, `dismiss`) lives in `app/javascript/controllers/` and is named after the behaviour. Many components use it. This is the default.
- **Behaviour that belongs to one component and nothing else** may live beside it: `app/components/ui/date_range_component_controller.js` (generated with `bin/rails g view_component:component Ui::DateRange --stimulus`). Follow the app: if it keeps all controllers in `app/javascript/controllers/`, keep doing that.

A component can combine both: `data-controller="dialog ui--date-range-component"`.

## Identifiers come from the class name

Stimulus derives an identifier from the file path: `/` becomes `--` and `_` becomes `-`. Generate the same identifier in Ruby, never by hand. The method below matches the flat layout (`app/components/ui/date_range_component_controller.js`). In a sidecar directory (`ui/date_range_component/date_range_component_controller.js`, what `--sidecar --stimulus` generates) the identifier repeats the name - `ui--date-range-component--date-range-component` - so append `"--#{name.demodulize.underscore.dasherize}"` when the app uses sidecars:

```ruby
class ApplicationComponent < ViewComponent::Base
  # Ui::DateRangeComponent -> "ui--date-range-component"
  def self.stimulus_id = name.underscore.dasherize.gsub("/", "--")
  delegate :stimulus_id, to: :class
end
```

```erb
<%= tag.div id: dom_id(@range), data: {
      controller: stimulus_id,
      "#{stimulus_id}-min-value": @min.iso8601,
      "#{stimulus_id}-open-value": false
    } do %>
  <button type="button" data-action="<%= stimulus_id %>#toggle">…</button>
  <div data-<%= stimulus_id %>-target="panel" hidden>…</div>
<% end %>
```

## Loading controllers from app/components

**importmap-rails** (stimulus-rails' `eagerLoadControllersFrom` registers only importmap keys under the given prefix that end in `_controller`):

```ruby
# config/importmap.rb
pin_all_from "app/components", under: "components", to: ""

# config/initializers/assets.rb - Propshaft serves app/components. It then also serves the
# components' .rb, template, and locale files as public assets: accept that knowingly, or keep
# controllers in app/javascript/controllers/ instead.
Rails.application.config.assets.paths << Rails.root.join("app/components")

# config/application.rb - re-read pins when sidecar JS changes in development
config.importmap.cache_sweepers << Rails.root.join("app/components")
```

```js
// app/javascript/controllers/index.js
eagerLoadControllersFrom("controllers", application)
eagerLoadControllersFrom("components", application)   // components/ui/date_range_component_controller -> ui--date-range-component
```

Check the setup with `bin/importmap json`: each sidecar controller must appear under `components/...` with a path that resolves. A file named plain `controller.js` is never registered.

**jsbundling (esbuild)**: `stimulus:manifest:update` scans only `app/javascript/controllers`. Import each sidecar controller in the entry point and register it with the identifier from the rule above, or use a glob import plugin and derive the identifier from the path.

**Vite**: `import.meta.glob("../../components/**/*_controller.js", { eager: true })`, registering each with the identifier derived from its path.

## Values are the interface

- Ruby passes data to the controller through `data-*-value` attributes, built in the component: strings as they are, numbers and booleans as they are, arrays and hashes as JSON.
- A controller reads nothing global (`window`, other elements by selector). It works only through its targets, values, outlets, and events.
- Connect sibling components with dispatched events (`this.dispatch("selected", { detail: { id } })` and `data-action="ui--date-range-component:selected->report#refresh"`) or outlets whose selector the parent passes in (`dom_id`-based). Never hard-code another component's id.
- Clean up in `disconnect()`: listeners on `window` or `document`, timers, observers. Turbo caches pages; a leaked listener fires twice.
- Morphing keeps an element and its controller without calling `connect` again; changed values fire `<name>ValueChanged`. Render from value callbacks, not only in `connect`, and keep no state that exists only in JavaScript fields.
- A component accepts the caller's `data:` attributes and merges `controller` and `action` tokens (`design.md`), so a parent can attach generic behaviour without a new option.
