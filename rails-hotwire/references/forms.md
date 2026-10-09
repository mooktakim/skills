# Forms under Turbo

Read this before building or changing a form that submits through Turbo. Build forms with the app's form builder, or Rails' default `form_with` when it has none - this file is about how they submit, not how fields are built.

## Responses

| Outcome | Response |
|---|---|
| success | `redirect_to target, status: :see_other` (or `notice:` with the redirect), or a Turbo Stream (`streams.md`) |
| validation failure | `render :new, status: :unprocessable_content` (`:unprocessable_entity` before Rack 3.1) - the form re-renders with errors at the same URL |
| failure inside a frame | the same 422 render; the frame shows it |
| success back to the same page, on a page that refreshes by morph | redirect to the current URL: the page morphs, keeping scroll |

A 200 response to a non-GET Drive form raises an error in Turbo and the page does not change. Every form needs a test of its 422 path.

## Submitting

- Turbo submits with fetch and sends the CSRF token from `csrf_meta_tags` - keep them in every layout (the frame layout includes them).
- Event order on the form: `turbo:submit-start` (`detail.formSubmission.stop()` aborts), `turbo:before-fetch-request`, `turbo:before-fetch-response`, `turbo:submit-end` (`detail.success`, `detail.fetchResponse`).
- Turbo disables the submit button while the request runs (`Turbo.config.forms.submitter = "aria-disabled"` keeps it focusable), sets `aria-busy` on the form, and `data-turbo-submits-with="Saving..."` swaps its label.
- From JavaScript, submit with `form.requestSubmit()` (optionally with a submitter). `form.submit()` skips the submit event and Turbo.
- Confirm: `data-turbo-confirm` on the form or the submitter (`button_to ..., form: { data: { turbo_confirm: "..." } }`).
- A form that must leave Turbo (an external payment or OAuth redirect): `data: { turbo: false }`.
- A form inside a frame that should update the whole page: `data: { turbo_frame: "_top" }`.

## GET forms: search and filters

A GET form is a visit. Target a frame around the results and keep the URL in step:

```erb
<%= form_with url: cards_path, method: :get,
      data: { turbo_frame: "cards", turbo_action: "replace", controller: "form", action: "input->form#debouncedSubmit" } do |form| %>
  <%= form.search_field :q, value: params[:q] %>
<% end %>
<%= turbo_frame_tag "cards" do %> ... <% end %>
```

The controller debounces (300 ms) and calls `requestSubmit()`. Turbo cancels a frame navigation that a newer one replaces, so results cannot arrive out of order. The index action renders the full page for the same URL.

## Autosubmit

A generic `auto-submit` controller calls `requestSubmit()` on `change` (selects, checkboxes, toggles). Mark the form busy and keep the response small (a stream that replaces one region, or a redirect that morphs).

## Autosave

- Start a timer on the first change (about 3 s), restart it on later changes, submit when it fires, and flush in `disconnect()` so leaving the page does not lose the edit.
- A background save must not morph the form being edited: submit with `@rails/request.js` and ask for JSON or `head :no_content`, not a stream that re-renders the form.
- Keep a local draft for long text: save to `localStorage` keyed by record (`card-42-draft`) on input, restore on connect, clear on `turbo:submit-end` with `detail.success`.

## Dependent fields

Make it work without JavaScript first: a submit button with `formmethod: :get`, `formaction: new_address_path`, and `data: { turbo_frame: "address_region" }` re-renders the form from params (`Address.new(address_params)`) and swaps only the dependent frame; a tiny controller clicks it on `change`. Nothing is saved. A stream that updates the `<select>` options is the alternative.

## Nested rows

Keep a `<template>` of a new row rendered with `child_index: "NEW_RECORD"`. An "add" button clones it, replacing `NEW_RECORD` with `Date.now()`; "remove" sets `_destroy` to `1` and hides a saved row, or deletes a new one from the DOM. The model needs `accepts_nested_attributes_for :lines, allow_destroy: true`.

## Uploads

Active Storage direct uploads (`direct_upload: true`) upload before the form submits. Show progress from `direct-upload:progress` (`event.detail.progress`), report `direct-upload:error`, and disable the submit button yourself on `direct-uploads:start` - Turbo's disabling starts only when the form submits. The storage bucket needs CORS for direct uploads.

## Errors and accessibility

- Errors render next to their fields, linked with `aria-describedby`, with `aria-invalid` on the field. A summary at the top for long forms, in a `role="alert"` element, with focus moved to it after a failed submit.
- After a re-render, `autofocus` on the first invalid field moves focus there: Turbo focuses the first focusable `[autofocus]` after a replace render. It does not when the page morphs, so on morph pages move focus with a small controller.
- Keep the user's input: the re-render uses the submitted object, so values come back from the server.
