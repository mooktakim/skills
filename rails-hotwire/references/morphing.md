# Page refreshes and morphing

Read this before turning on morph refreshes, using `method: :morph` or `refresh: :morph`, or building anything that must keep its state through a morph.

## Setup

```erb
<%# app/views/layouts/application.html.erb, inside <head>, which must yield :head %>
<% turbo_refreshes_with method: :morph, scroll: :preserve %>
<%= yield :head %>
```

- A page refresh is a `replace` visit to the same path: a form that redirects back to the current URL (exactly, query string included), `Turbo.visit(location.href, { action: "replace" })`, a `refresh` stream, or a refresh broadcast. With `method: :morph`, Turbo morphs the new page into the old one instead of replacing `<body>`; with `scroll: :preserve`, the scroll position stays.
- A 422 re-render of a form on the same page also morphs.
- Per page: `content_for(:turbo_refresh_method)` in the layout call lets a page opt out (`turbo_refreshes_with method: content_for(:turbo_refresh_method).presence || :morph, scroll: :preserve`).
- Morphing is the default for 37signals' apps. thoughtbot warns against turning it on everywhere before auditing pages ([Turbo morphing woes](https://thoughtbot.com/blog/turbo-morphing-woes)). Turn it on app-wide in a new app; in an existing app, audit each page that receives refreshes for the state below first.

## How the morph matches elements

Turbo uses idiomorph. It matches elements by id (an element's own id and its descendants' ids) and falls back to position and tag. Without ids, list items can be rebuilt instead of moved.

- Give list items, forms, inputs, elements with `data-controller`, `<details>`, and `<dialog>` stable `dom_id`-based ids.
- Elements kept by the morph keep their Stimulus controller: `connect()` does not run again. Changed `data-*-value` attributes fire `<name>ValueChanged`; new targets fire `<name>TargetConnected`. Put render logic there.
- The morph resets attributes and children to the server's HTML: an `open` attribute the user set, a class a controller added, an input's typed value (an input whose server HTML has no `value` is cleared).

## Protecting state

| State | Protection |
|---|---|
| an open `<dialog>` or `<details>` | cancel the morph of its `open` attribute |
| a control with an unsubmitted edit | cancel the morph of that element until the form submits |
| DOM a controller or library built (Tom Select, a chart, a rich editor) | tear it down on `turbo:before-render`, rebuild on `turbo:morph`; or cancel the element's morph |
| client-side formatting (local times, relative dates) | re-run on `turbo:morph` / `turbo:morph-element` |
| a lazy or paginated frame | `refresh: :morph` on the frame: it reloads its `src` and morphs |
| a frame whose content should be fetched again, not morphed | cancel its morph on `turbo:before-morph-element` and call `frame.reload()` |

```html
<dialog data-controller="dialog" data-action="turbo:before-morph-attribute->dialog#keepOpen">
```
```js
keepOpen(event) {
  if (event.detail.attributeName === "open") event.preventDefault()
}
```

```js
// a form control that holds an edit the user has not submitted
static values = { dirty: Boolean }
edited() { this.dirtyValue = true }                       // input->bid-form#edited
submitting() { this.dirtyValue = false }                  // turbo:submit-start->bid-form#submitting
keepEdit(event) { if (this.dirtyValue) event.preventDefault() }   // turbo:before-morph-element->bid-form#keepEdit
```

**`data-turbo-permanent` is not for state.** A morph never touches a permanent element - its content stops updating, and if its id changes, the old one stays next to its replacement. Keep it for elements whose content never changes from the server (a player, a third-party widget with a stable id).

## Events

| Event | When | Use |
|---|---|---|
| `turbo:before-morph-element` | before an element morphs (`detail.newElement`) | `preventDefault()` keeps the element, its attributes, and its children |
| `turbo:before-morph-attribute` | before one attribute changes (`detail.attributeName`, `detail.mutationType`) | `preventDefault()` keeps that attribute |
| `turbo:morph-element` | after an element morphed | re-run formatting on it |
| `turbo:morph` | after the page morphed | rebuild what a library owns |
| `turbo:before-render` / `turbo:render` | around the render (`detail.renderMethod` is `"morph"` or `"replace"`) | tear down before, build after |

Listen from the element's controller with `data-action` (`turbo:morph@window->combobox#rebuild`), not global listeners.

## Morphing in streams and frames

- `turbo_stream.replace target, ..., method: :morph` and `update ..., method: :morph` morph one region and keep focus and controller state inside it.
- `refresh: :morph` on a frame (see the table above).
- `Turbo.morphElements` and `Turbo.morphChildren` are exported (8.0.14+) for a custom frame render.

## Pitfalls

- A broadcast refresh resets other viewers' open disclosures and typed input: everything in the table above applies to them too.
- Refreshes cost one page request per viewer: keep refreshed pages cheap.
- Autofocus does not move focus on a morph; focus can still move through idiomorph's focus restore. Check focus after a refresh on forms.
- A redirect to the same path with a different query string is an `advance` visit: no morph.
- Prove the protection with a system test: start an edit, trigger a refresh from another session or a model change, and assert the edit is still there (`testing.md`).
