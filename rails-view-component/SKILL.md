---
name: rails-view-component
description: Organise, write, compose, and test ViewComponent components in Rails apps, and wire them into Hotwire. Covers when to make a component, the component API (keyword arguments, render?, slots, collections), the base class and namespaces, helpers and i18n, Turbo Stream responses, Turbo Frames, self-broadcasting components (TurboViewComponent with change filters and render_later), Turbo 8 morphing, Stimulus controllers beside components, forms with the app's own form builder, previews, testing, caching, and upgrading to ViewComponent v4. Use when creating or changing a component, its preview, or its test; when rendering or broadcasting components through Turbo; when wiring Stimulus to a component; when a form lives in a component; or when asked to audit, set up, upgrade, or reorganise a component library. Not for visual design - how components look belongs to the app's design system.
---

# Rails ViewComponent

You build ViewComponent libraries to one standard: components that are small, composable, explicit about their inputs, safe to render anywhere - a page, a Turbo Stream, a broadcast job - and tested through their output. This file holds the rules for every component. The `references/` files beside it hold the detail - they ship with this skill, so resolve their paths from this skill's directory (`${CLAUDE_SKILL_DIR}`), not the app. Read the matching one before you write that kind of code:

| Read | Before |
|---|---|
| `references/design.md` | creating a component, or changing its API: component or partial, arguments, `render?`, lifecycle, content and slots, collections, templates, HTML attributes, naming, the base class |
| `references/helpers.md` | using a helper, a URL helper, or a translation in a component |
| `references/turbo.md` | rendering a component in a Turbo Stream or a frame, giving it an id, or making it survive morphing |
| `references/broadcasting.md` | making a component update itself over Action Cable: `TurboViewComponent`, change filters, `render_later`, refresh broadcasts |
| `references/stimulus.md` | attaching a Stimulus controller to a component, or loading controllers that live beside components |
| `references/forms.md` | putting a form, or a part of a form, in a component |
| `references/previews.md` | adding or changing a preview, or setting up previews or Lookbook |
| `references/testing.md` | writing a component test, a preview test, or a broadcast test |
| `references/performance.md` | slow pages full of components, caching a component, instrumentation |
| `references/upgrade.md` | an app on ViewComponent older than 4.14, or old v3 APIs and config |

This skill is about structure, code, and tests. It sets no visual rules: colours, spacing, variants, and class strings come from the app's design system (`docs/design-system/`, owned by rails-design-system when present) or from the app's existing components.

## Two modes

- **Writing mode** - components that belong to a change, or components the user asks for. Follow the rules below. A component, its preview, and its test that belong to the change need no approval step.
- **Library mode** - the user asks to audit, set up, upgrade, or reorganise the component library. Follow "Library mode" at the end: survey, plan, approval, apply, verify.

In the main conversation, when subagents are available, hand component work to `rails-view-component:component-builder` (it has this skill loaded) and pass it the change's intent, the pages or records involved, and any design-system spec that applies. Do a one-line fix yourself. In library mode the agent returns the Phase 1 plan; get the user's approval, then call it again with the approved plan.

## Detect first

1. Read `Gemfile.lock`: the `view_component` version, and `turbo-rails`, `stimulus-rails`, `importmap-rails` or `jsbundling-rails` or `vite_rails`, `lookbook`, and any forms gem (`simple_form`, `view_component-form`, ...). With no `view_component`, stop: adding the gem is a library-mode change that needs approval. Below 4.0, read `references/upgrade.md` before writing anything, because v3 APIs differ. Below 4.14, tell the user once that 4.14 fixes a security issue (CVE-2026-54497).
2. Read `app/components/CLAUDE.md` if it exists, `app/components/application_component.rb`, any other base class (`TurboViewComponent`), and the `config.view_component` settings in `config/`.
3. Read two or three existing components like the one you are about to write, with their previews and tests.
4. If the app has `docs/design-system/`, read the spec for any component you touch and follow it for markup and styling.

The app's settled conventions win on style: file layout, template style, namespaces, naming, test style. The rules marked **hard** below win over the app. In writing mode, follow them in new code and report the old violations you saw; fix old ones only in library mode.

## Rules for every component

**When and where**

1. Make a component for markup that has its own inputs, logic, or states, or that repeats. Keep a single-use page section in the view until a second use appears; extract a shared component on the third. A helper that returns HTML becomes a component; a helper that returns a plain value stays a helper.
2. Every component inherits `ApplicationComponent` (or a base class built on it). The base class holds shared infrastructure only - helper includes, attribute merging, the Stimulus identifier - never feature behaviour.
3. Namespace by domain or feature (`Billing::InvoiceRowComponent`), with generic building blocks in one shared namespace. Name a component after what it renders, end it in `Component`, and put it at the matching path under `app/components/`.

**Inputs and state**

4. **(hard)** A component gets everything through its initializer, as keyword arguments: required ones with no default, optional ones with a default. It never reads `params`, `session`, `cookies`, `request`, `Current`, or `helpers.current_user`. A component that reads request state breaks in broadcasts, previews, and tests.
5. **(hard)** No database queries in a component or its template. The caller loads and preloads the records and passes them in. A query in a component becomes an N+1 the moment the component renders in a list.
6. `initialize` only assigns. Helpers, `controller`, `request`, and `t` raise there; derived values go in private methods (memoised if costly) or `before_render`.
7. An option with a fixed set of values is checked against a frozen list, and an unknown value raises (`OPTIONS.fetch(value)`) - a typo must fail in the test, not render something odd.
8. Use `render?` for "nothing to show". The caller never wraps a component in `if`.

**Composition**

9. **(hard)** Markup from the caller arrives through `content` or a slot, never as an HTML string argument, and a component never calls `html_safe` or `raw` on input.
10. Compose, do not inherit behaviour: a component renders other components, and named regions are slots (`renders_one`, `renders_many`; component slots for structured parts, polymorphic slots for alternatives). Subclass only the base class.
11. A component accepts extra HTML attributes (`**html_attributes`) and merges them into its root element: `class` and `data-controller`/`data-action` tokens are joined, `data` and `aria` are merged, and the component's required attributes cannot be removed.
12. Render lists with `with_collection`, not a loop that builds components by hand.

**Rendering safety**

13. **(hard)** Render a new instance every time. ViewComponent 4.14+ raises when one instance renders twice; never keep instances in constants, memoised helpers, or two stream actions.
14. **(hard)** Every id is derived from records (`dom_id`) and stable across renders - never `SecureRandom` or `object_id`. A component that a Turbo Stream or a broadcast targets carries that id on its root element.
15. **(hard)** Pass a block to `render`, not to `.new`: `render(Foo.new(x)) { "Delete" }` or `render Foo.new(x) do ... end`. In `render Foo.new(x) { "Delete" }` the braces bind to `.new` and the content is lost.

**Tests and previews**

16. Every component has a test file that renders it and asserts on its output, for each state and option its API defines. Test the HTML, never private methods. See `references/testing.md`; the rails-minitest skill's rules apply to these tests when it is installed.
17. Every component with more than one state or option has a preview with one example per state, built from unsaved records so it needs no data, and one test renders every preview.

## Library mode

The approval gate is a hard stop. Change nothing until the user approves the Phase 1 plan in a reply to that plan ("approve", "yes", "go", or edits to it). A reply about something else is not approval.

### Phase 1: survey and plan

1. From the app root, run `ruby "${CLAUDE_SKILL_DIR}/scripts/audit_components"`. It reports the stack, components per namespace, base classes, template styles, components with no preview or test, and findings with file and line. Its header comment explains each rule. Its findings are leads: confirm each one in the code before it goes into the plan.
2. Run the component tests once for the baseline (`bin/rails test test/components`), delegated to `rails-minitest:minitest-runner` when that agent is available.
3. Present the plan, grouped, each item with its files and a one-line reason:
   - **Upgrade:** the ViewComponent version, renamed config, removed APIs (`references/upgrade.md`).
   - **Infrastructure:** `ApplicationComponent`, generator settings, preview setup, Stimulus controller loading, `TurboViewComponent`.
   - **Structure:** components to move, rename, or merge; partials or HTML helpers to convert, ranked by reuse.
   - **Violations:** each hard-rule finding with its fix.
   - **Gaps:** components with no test or no preview, ranked by how much they are used.

   Say what you will not change and why. Then wait for approval.

### Phase 2: apply

Work in this order: upgrade, infrastructure, structure, violations, gaps. Gem changes go through `bundle add` or `bundle update view_component`, and you confirm `Gemfile.lock` changed. A rename or move updates every caller in the same step (search `app/` and `test/` for the class name). Run the affected tests after each group. Keep each component's rendered HTML the same unless the plan says otherwise.

### Phase 3: verify and report

1. Run the full suite (`bin/rails test:all` when there are system tests) and the audit again. Both must be no worse than the baseline.
2. Open the changed previews or pages in a browser and check that they render.
3. If the app has `app/components/CLAUDE.md`, update it with the conventions this run set up: base classes, namespaces, template style, Stimulus loading.
4. Report what changed, the findings before and after, and what is left. Commit only when the user or the project's rules say so.
