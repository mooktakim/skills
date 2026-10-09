# Testing Hotwire

Read this before testing stream responses, frames, broadcasts, morphs, or Stimulus behaviour. The general test rules - fixtures, one behaviour per test, no `sleep`, never weaken a test - come from the rails-minitest skill when it is installed. This file says which layer proves which Hotwire behaviour.

| Behaviour | Test | Where |
|---|---|---|
| a stream response: actions, targets, content | integration, `as: :turbo_stream` | `test/controllers/` |
| a failed form returns 422 | integration | `test/controllers/` |
| a frame response contains the frame | integration, `Turbo-Frame` header | `test/controllers/` |
| a model broadcasts, to whom, and how often | model test running the jobs | `test/models/` |
| a Stimulus behaviour, a morph that keeps state, a live update arriving | system test | `test/system/` |

## Stream and frame responses

```ruby
test "pinning a card replaces its pin button" do
  post card_pin_path(cards(:logo)), as: :turbo_stream
  assert_turbo_stream action: :replace, target: dom_id(cards(:logo), :pin) do
    assert_select "template button", text: "Unpin"
  end
  assert_no_turbo_stream action: :remove, target: "flash"
end

test "an invalid card re-renders the form" do
  post cards_path, params: { card: { title: "" } }
  assert_response :unprocessable_content
end

test "the edit frame renders inside its frame" do
  get edit_card_path(cards(:logo)), headers: { "Turbo-Frame" => dom_id(cards(:logo), :edit) }
  assert_turbo_frame cards(:logo), :edit do
    assert_select "form"
  end
end
```

- `assert_turbo_stream` also checks the response is a stream with status 200 (pass `status:` for others); `target:` takes a record. `count:` and `targets:` are available.
- `assert_turbo_frame` and `assert_no_turbo_frame` (turbo-rails 2.0.21+) take a record or id, plus `target:`, `src:`, `loading:`.
- Test the 422 path of every form.

## Broadcasts

`Turbo::Broadcastable::TestHelper` is included in `ActiveSupport::TestCase`. `_later` broadcasts are jobs: run them with `perform_enqueued_jobs`, which needs `ActiveJob::TestHelper` in model tests.

```ruby
class NotificationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper   # Rails adds it only to integration tests; or include it once in test_helper.rb

  test "a new notification reaches only its user" do
    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts [users(:kevin), :notifications], count: 1 do
        assert_turbo_stream_broadcasts [users(:david), :notifications], count: 0 do
          Notification.create!(user: users(:kevin), card: cards(:logo))
        end
      end
    end
  end

  test "renaming a board refreshes its pages" do
    streams = capture_turbo_stream_broadcasts(boards(:writebook)) do
      perform_enqueued_jobs { boards(:writebook).update!(name: "Writebook 2") }
    end
    assert_equal "refresh", streams.last["action"]
  end
end
```

- `count: 0` around the positive case proves who must not receive it - an authorisation test.
- `assert_no_turbo_stream_broadcasts` proves a filter or suppression works.
- `capture_turbo_stream_broadcasts` returns Nokogiri `<turbo-stream>` elements (`["action"]`, `["target"]`, `.to_html`); with a block it returns only that block's broadcasts.
- In tests, refresh debouncing is immediate.
- Running the jobs is what catches a partial that works in a request and breaks in a job (`current_user` in a broadcast partial).

## System tests

Only for what needs a browser. Rails 8.1 scaffolds no system tests by default; add them for critical paths.

- Never `sleep`. Assert on something that exists only after the action - Capybara waits for it: `click_on "Save"; assert_selector "#card_1", text: "Renamed"`.
- After a Turbo navigation, assert on something only the new page has (or `assert_current_path`) before the next step.
- A click before Stimulus connects does nothing: when a test is flaky on first interaction, assert on a mark the controller sets on connect.
- Live updates: `visit` waits for `<turbo-cable-stream-source>` elements to connect (turbo-rails' `Turbo::SystemTestHelper`; `config.turbo.test_connect_after_actions` adds other actions). After a Turbo navigation, call `connect_turbo_cable_stream_sources`, or wait with `assert_turbo_cable_stream_source board, connected: true`. Then change the model and assert the page shows it. `_later` broadcasts need their jobs to run - an inline queue adapter in system tests, or `perform_enqueued_jobs`.
- Morphs that keep state: start an edit or open a dialog, trigger a refresh (a model change that broadcasts it), and assert the edit or dialog is still there.

```ruby
test "a refresh keeps an edit in progress" do
  visit board_path(boards(:writebook))
  click_on "Edit"
  fill_in "Title", with: "Draft title"
  perform_enqueued_jobs { boards(:writebook).touch }
  assert_field "Title", with: "Draft title"
end
```

## Stimulus logic

There is no official unit test kit. Cover behaviour through a few system tests and keep controllers small. Logic-heavy code goes in plain modules (`app/javascript/helpers/`) that a JavaScript test runner can test without a DOM, if the app has one.
