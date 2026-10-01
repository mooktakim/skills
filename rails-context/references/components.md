# app/components - generation guide

Read this before generating `app/components/CLAUDE.md` in the target app. Derive every statement from that app's code; skip any question the app has no answer to. Only generate the file if the directory qualified in Phase 1 - an app with no component framework gets no components file.

## Questions to answer from the code

- **Framework**: ViewComponent, Phlex, or both - and if both, which direction the migration runs. State what the framework is used *for* and what it is not (components only vs full pages).
- **Base class**: what `ApplicationComponent` provides (registered helpers, routes, translate) so new components don't re-include it.
- **Helper access**: the sanctioned way to reach Rails helpers, and the forbidden shortcuts (direct ActionView includes, deprecated `helpers.` proxies) with the reason.
- **Naming and organisation**: suffix conventions, the principle behind the namespace layout (by feature? by audience?), whether a component namespace is registered in an initializer.
- **File layout**: single-file with inline template method, or sidecars (template, preview, Stimulus controller) - and how they're named.
- **Rendering conventions**: conditional-render guards (`render?`), slots, ivars vs attr_reader.
- **Styling**: Tailwind/CSS conventions - when class strings get extracted to methods, design-token usage.
- **Turbo integration**: broadcasting mixins, automatic frame wrapping (and double-wrap traps), stream targets.
- **Boundaries**: sharing rules between audiences (admin vs public), and what earns a component vs a partial.
- **DSL gotchas**: the framework-specific traps this app has hit (escaping, raw HTML, SVG attributes, form builders) - only ones evidenced in the code.

## Target shape (fictional excerpt - copy the density, never the content)

```markdown
# Phlex Components

Everything here is Phlex; ERB pages in `app/views/` embed components - never
build full-page Phlex views rendered straight from a controller.

## Conventions
- Inherit `ApplicationComponent`; it already provides route helpers and `t`.
  For anything else include the matching `Phlex::Rails::Helpers::*` module on
  your component - never include ActionView modules directly (they clobber
  core Phlex methods).
- One Ruby file per component, markup in `#view_template`, no ERB sidecars.
- Conditional rendering: override `render?` and return false to emit nothing.
- New component? Read the closest sibling in the same namespace and mirror it.

## Gotchas
- Components that broadcast include `TurboBroadcastable`, which wraps output in
  a turbo_frame automatically - writing the outer frame yourself double-wraps.
- Never share a component between `Admin::*` and public namespaces.
```
