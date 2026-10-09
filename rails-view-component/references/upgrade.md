# Upgrading ViewComponent

Read this when the app runs ViewComponent older than 4.14, or uses v3 APIs or config. Upgrades are library-mode work: plan them and get approval first.

## Target

The latest 4.x (4.15.0 in October 2026). It needs Ruby 3.2+ and Rails 7.1+. At least 4.14: it fixes CVE-2026-54497, where a component instance rendered more than once could leak content and slot content from one render into the next; 4.14 raises `ViewComponent::ReusedInstanceError` instead.

## v3 to v4

| v3 | v4 |
|---|---|
| components subclass `ActionView::Base` behaviour | they do not; app and gem helpers need `include` or `helpers.` (`helpers.md`) |
| `use_helper :icon`, `use_helpers :a, :b` | `include IconHelper`, or `delegate :icon, to: :helpers` |
| `render_component`, the `render` monkey patch | `render` |
| `config.view_component.preview_paths`, `preview_route`, `show_previews`, `preview_controller`, `default_preview_layout` | `config.view_component.previews.paths`, `.route`, `.enabled`, `.controller`, `.default_layout` |
| `config.view_component.test_controller = "X"` | `def vc_test_controller_class = X` in the test (or a base test class) |
| `view_component_path`, `component_parent_class`, generator flags | `config.view_component.generate.path`, `.parent_class`, `.sidecar`, `.stimulus_controller`, `.preview`, `.locale` |
| `capture_compatibility_patch_enabled`, `render_monkey_patch_enabled` | removed; not needed |
| `rails g component Foo` | `rails g view_component:component Foo` (`--call` for a `call` method) |
| `preview_source` | removed; Lookbook shows source |
| variant names containing `.` | not supported |
| the catch-all `initialize(*)` | none; `dry-initializer` works |
| test HTML parsed with HTML4 | parsed with `Nokogiri::HTML5`; some selectors on malformed markup change |

Added in v4 and later: `around_render`, default slots (`default_<slot>`), `Turbo::StreamsHelper` support, `ViewComponent::Serializable` and `render_later` (4.13), the reuse error (4.14), experimental caching (4.15). Form helpers that yield inside components render in the right order from 4.10.

## Steps

1. Run the audit (`scripts/audit_components`) and the component tests for a baseline.
2. `bundle update view_component` (to the target); confirm `Gemfile.lock` changed.
3. Fix config keys (`v3-config`), then removed APIs (`removed-api`): each `use_helpers` becomes an `include` of the helper module, or a `delegate ... to: :helpers` for helpers that need the view.
4. Run the component tests, then the full suite. Errors to expect: `NoMethodError` for app helpers (step 3 missed one), `ReusedInstanceError` (an instance kept in a constant or rendered twice - build one per render), changed selectors from the HTML5 parser.
5. Open the previews and the main pages in a browser.
6. Run the audit again; record what changed in `app/components/CLAUDE.md` if the app has one.
