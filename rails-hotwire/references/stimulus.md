# Stimulus

Read this before writing or changing a Stimulus controller, or changing how controllers load. Current: Stimulus 3.2.2 (no release since 2023; a fix for a listener leak under Turbo morphs is merged on `main` but unreleased), stimulus-rails 1.3.4.

## Design

- **One behaviour per controller, named after the behaviour**: `toggle`, `clipboard`, `auto-submit`, `dialog`, `element-removal`, `hotkey` - not `users-index` or `checkout-page`. A big domain controller (`composer`, `messages`) is the exception, for one complex widget.
- **Configure from HTML**: values, targets, classes, and action params make one controller serve many places. Reuse when only the configuration differs; write a new controller when the behaviour differs.
- **Compose** several controllers on one element (`data-controller="dialog auto-submit"`) instead of growing one.
- **Turbo first**: if a frame, a stream, or a form round trip does it, no controller.
- **The server renders HTML.** A controller that needs new content fetches a rendered fragment (`get(url, { responseKind: "turbo-stream" })`, a frame `src`), never JSON to build markup.
- **Progressive enhancement**: the page works before the controller connects; the controller adds to it. A field submits correctly without JavaScript.
- Start each controller with a short comment: what it does and where it is used.

```js
// Shows and hides a panel. Used by dropdowns and the filter bar.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel"]
  static values = { open: Boolean }

  // Actions
  toggle() { this.openValue = !this.openValue }
  close() { this.openValue = false }

  // Callbacks
  openValueChanged(open) {
    this.panelTarget.hidden = !open
    this.buttonTarget.setAttribute("aria-expanded", open)
  }
}
```

```erb
<div data-controller="disclosure" data-action="keydown.esc->disclosure#close turbo:before-cache@document->disclosure#close">
  <button type="button" data-disclosure-target="button" data-action="disclosure#toggle" aria-expanded="false" aria-controls="filters">Filters</button>
  <div id="filters" data-disclosure-target="panel" hidden>...</div>
</div>
```

## State lives in the DOM

- Values (`data-<id>-<name>-value`), `hidden`, `aria-*`, and `data-*` attributes hold state; JavaScript fields hold only what cannot be serialised (a library instance, a timer). The server, the page cache, and morphs can then all restore it.
- Style state from attributes in CSS (`[aria-expanded="true"]`, `[data-changed]`, `aria-pressed:` variants in Tailwind) rather than toggling class lists - classes stay in the templates where the design system sees them. Where the app uses `static classes`, follow it.
- React to a value in `<name>ValueChanged(value, previousValue)`. It runs before `connect()` for every declared value, whether or not the attribute is present (each type has a default: `false`, `0`, `""`, `[]`, `{}`), and again on reconnect. Do not rely on `previousValue` on that first call (it is the type's default or undefined): keep the last value you acted on and act only on a different one. Write it to be idempotent and not to depend on `connect()`.

## The API

| Feature | Declare | Use | Notes |
|---|---|---|---|
| targets | `static targets = ["item"]` | `this.itemTarget`, `this.itemTargets`, `this.hasItemTarget` | the singular getter throws when missing; `itemTargetConnected(el)` / `Disconnected(el)` |
| values | `static values = { url: String, delay: { type: Number, default: 300 } }` | `this.urlValue` | Array, Boolean, Number, Object, String; `urlValueChanged` |
| classes | `static classes = ["active"]` | `this.activeClass`, `this.activeClasses` | attribute on the controller element |
| outlets | `static outlets = ["auto-save"]` + `data-<id>-auto-save-outlet="#form"` | `this.autoSaveOutlet` | the matched element must carry that controller; `autoSaveOutletConnected` |
| actions | `data-action="input->search#filter"` | method on the controller | default events: click for buttons and links, submit for forms, input for inputs, change for selects, toggle for details |
| action options | `click->x#y:prevent`, `:stop`, `:self`, `:once`, `:passive` | | |
| keyboard | `keydown.enter->x#y`, `keydown.esc@document->x#close`, `keydown.meta+enter->form#submit` | | |
| global events | `resize@window->x#layout`, `turbo:morph@window->x#rebuild` | | removed automatically on disconnect |
| params | `data-x-id-param="12"` on the action element | `({ params: { id } })` | typecast to Number, Boolean, Object, String |
| events | `this.dispatch("changed", { detail: { id } })` | `data-action="x:changed->y#refresh"` | bubbles, cancelable; prefixed with the identifier |

Communication: dispatched events for "something happened" (loose coupling); outlets only when one controller really drives another (select-all over rows, an editor telling its autosave to flush). Never `application.getControllerForElementAndIdentifier` for routine work.

## Lifecycle and cleanup

- `initialize()` once per instance; `connect()` and `disconnect()` each time the element enters or leaves the DOM. Instances are reused, so `connect()` can run many times.
- **Undo in `disconnect()` everything `connect()` set up**: a listener on `window` or `document` (keep the bound function to remove it - or declare it as a `@window` / `@document` action, which Stimulus removes for you), `setInterval` / `setTimeout`, observers (`observer.disconnect()`), third-party instances (`this.picker.destroy()`). Turbo caches and restores pages, so leaks fire twice.
- Stay in scope: `this.element`, targets, outlets. Never `document.querySelector` with a fixed selector - the controller must work with many copies on a page. An id passed in through a value is fine.
- **Page cache**: reset transient UI on `turbo:before-cache` (`data-action="turbo:before-cache@document->dropdown#close"`); `connect()` must be safe to run on a restored copy.
- **Morphs**: a morphed element keeps its controller; react in value and target callbacks, rebuild library DOM on `turbo:morph` (see `morphing.md`).

## Third-party libraries

Wrap each one in its own controller: create it in `connect()` from values (an Object value for options), destroy it in `disconnect()`, rebuild it after a morph. Pin it in importmap (vendor a single-file ESM build when the package's own files import each other by relative path). Check whether Stimulus already does what a helper library offers (`@window` actions, keyboard filters, `:once`) before adding stimulus-use or a component package.

## Shared code

In order: compose controllers on the element; plain ES modules of pure functions in `app/javascript/helpers/` (`timing_helpers.js` with `debounce`, `nextFrame`); a mixin for an "acts as" trait; a base class only for "is a". HTTP from controllers goes through `@rails/request.js` (CSRF header included). Ruby helpers build repeated `data-controller` / `data-action` attributes (`auto_submit_form_with`), merging tokens with `token_list`.

## Files, identifiers, and loading

- `app/javascript/controllers/date_picker_controller.js` is `date-picker`; `admin/users/list_item_controller.js` is `admin--users--list-item` (`/` becomes `--`, `_` becomes `-`). One default-export class per file.
- **importmap** (the Rails default): `pin_all_from "app/javascript/controllers", under: "controllers"` and `eagerLoadControllersFrom("controllers", application)`. New files need no manifest. Load eagerly (the default; importmap 2 preloads every pin). `lazyLoadControllersFrom` exists for apps with very many controllers, at the cost of a delay before controllers attach.
- **jsbundling** (esbuild, Bun, Rollup): `controllers/index.js` is a manifest. Run `bin/rails stimulus:manifest:update` (or generate with `bin/rails g stimulus name`) after adding a controller, or it never registers.
- **Vite**: `registerControllers(application, import.meta.glob("./**/*_controller.js", { eager: true }))` from `stimulus-vite-helpers`.
- `application.handleError` can report controller errors to the app's error tracker.
- Controllers that live beside ViewComponents: see the rails-view-component skill.

## Accessibility

Use `<button type="button">` for actions, not clickable `div`s; every click action works from the keyboard. Keep `aria-expanded`, `aria-pressed`, `aria-selected`, `aria-busy` in step with state. Return focus to the trigger when a popover or dialog closes; move it into a dialog when it opens. `<dialog>.showModal()` gives focus trapping, Escape, and an inert background for free.

## Outdated syntax

| Old | Now |
|---|---|
| `data-target="search.query"` | `data-search-target="query"` |
| `this.data.get("url")`, `data-search-url` | `static values`, `data-search-url-value` |
| `import { Controller } from "stimulus"` | `from "@hotwired/stimulus"` |
| `if (event.key === "Escape")` | `keydown.esc->x#close` |
| `addEventListener` in `connect` for window events | `resize@window->x#layout` |
| `event.preventDefault()` in every handler | `:prevent` |
