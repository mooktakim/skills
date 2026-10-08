# Each kind of test

Read the section for the kind you are writing. Every kind follows the rules in `SKILL.md`; this file adds what each kind proves and how.

## Models, concerns, and plain Ruby objects

`ActiveSupport::TestCase`. Most of the suite's tests live here, because it is where the logic is and it is the cheapest level.

- **Validations** that carry a rule: the invalid case and the error it adds, `assert record.errors.added?(:email, :taken)`. Skip tests that only restate `validates :name, presence: true`.
- **Scopes and queries:** assert the exact records from fixtures, and their order when order is the behaviour: `assert_equal [cards(:shipping)], Card.closed`.
- **State changes:** assert before and after, and the side effects (`assert_difference -> { card.events.count }, +1`).
- **Callbacks:** assert their effect through the public method that triggers them, never by calling the callback.
- **Concerns:** one file per concern mirroring `app/models/<model>/<concern>.rb`. A concern shared by many models: see "Shared behaviour" in `references/organisation.md`.
- **Hot query paths:** lock in an N+1 fix with `assert_queries_count(2) { report.rows.to_a }`, or `assert_no_queries` for code that must use loaded data (both Rails 7.2+).
- **Errors that are rescued and reported:** `assert_error_reported(PaymentError) { ... }`.

## Integration tests (controllers)

`ActionDispatch::IntegrationTest`, one file per controller in `test/controllers/`. They render views, so they also cover templates. They prove the HTTP contract, not the domain logic.

For each action, cover what applies:

- The main path: `assert_response :success`, or `assert_redirected_to card_path(card)`.
- Signed out: redirected to sign-in.
- Wrong role and other tenant: the status the app uses for each (404 for another tenant's record keeps ids secret).
- Invalid params: the error status the app's controllers use and no change: `assert_no_difference("Card.count") { post cards_path, params: { card: { title: "" } } }`.
- The response shape:
  - HTML: `assert_dom "h1", "Cards"`, `assert_dom "li.card", count: 2`. Assert the few elements that prove the behaviour, never whole pages.
  - JSON: `get card_path(card, format: :json)`, then `response.parsed_body` (`assert_equal "Logo", response.parsed_body["title"]`).
  - Turbo Stream: `post card_comments_path(card), params: {...}, as: :turbo_stream`, then `assert_turbo_stream action: :append, target: "comments"`.
- Multi-step: `follow_redirect!` and assert the page you land on.

## System tests

`ApplicationSystemTestCase` with a headless browser. Only for flows that need JavaScript (Stimulus behaviour, drag and drop, live updates) and for a handful of critical journeys end to end (sign up, checkout). Everything else is an integration test.

- Use Capybara's waiting matchers: `assert_text`, `assert_selector`, `assert_no_selector`, `assert_current_path`. Never `sleep`, and never wrap `page.has_*?` in `assert` or `refute`: the negated form fails while the old page is still on screen, and both forms give a useless failure message.
- Find elements the way a user does: `click_on "Save"`, `fill_in "Title", with: "..."`. Add `data-testid` only where no label or role identifies the element.
- Wrap browser dialogs: `accept_confirm { click_on "Delete" }`.
- Sign in with a shortcut (`references/shortcuts.md`), never through the form except in the test of the login itself.
- Rails saves a screenshot on failure under `tmp/screenshots/`. Read it when a system test fails.

## Jobs

`ActiveJob::TestCase`. Test the job by calling it: `CleanupJob.perform_now(account)`, then assert the effect. Test the enqueue in the code that enqueues (`assert_enqueued_with(job: CleanupJob, args: [account])`). For `retry_on`/`discard_on`, make the error happen (stub the boundary that raises), perform the job, and assert it was enqueued again or discarded. Keep jobs thin: logic that needs many tests belongs in a model the job calls.

## Mailers

`ActionMailer::TestCase`.

```ruby
test "welcome email goes to the new user" do
  mail = UserMailer.with(user: users(:member)).welcome
  assert_equal [users(:member).email_address], mail.to
  assert_equal "Welcome to Acme", mail.subject
  assert_match "Get started", mail.html_part.body.to_s
end
```

Previews in `test/mailers/previews/` double as a template check. One test renders all of them, so a broken template fails the suite:

```ruby
class MailerPreviewsTest < ActiveSupport::TestCase
  ActionMailer::Preview.all.each do |preview|
    preview.emails.each do |email|
      test "#{preview.preview_name}##{email} renders" do
        assert preview.call(email).body.present?
      end
    end
  end
end
```

## Helpers

`ActionView::TestCase`. Call the helper and assert its output: `assert_equal "£12.00", format_money(1200)`, or `assert_dom_equal` for HTML.

## View components

- **ViewComponent:** `ViewComponent::TestCase`, `render_inline(BadgeComponent.new(tone: :danger))`, then `assert_selector "span.badge", text: "Overdue"`.
- **Phlex:** `ActionView::TestCase`, `render Components::Badge.new(tone: :danger)`, then `assert_dom "span.badge", "Overdue"`.

Test each variant and state the component's contract defines, not every combination.

## Channels and broadcasts

- `ActionCable::Channel::TestCase`: `subscribe(room_id: rooms(:main).id)`, `assert subscription.confirmed?`, `assert_has_stream_for rooms(:main)`.
- Broadcasts from models: `assert_broadcast_on`, or turbo-rails' `assert_turbo_stream_broadcasts` (turbo-rails includes its test helper in `ActiveSupport::TestCase`). Model-declared broadcasts (`broadcasts_to`, `broadcasts_refreshes`) run as `_later` jobs, so wrap them: `perform_enqueued_jobs { assert_turbo_stream_broadcasts(card) { card.update!(title: "New") } }`. An explicit `broadcast_*_to` call broadcasts at once and needs no wrapper.

## Rake tasks and scripts

Keep the task a thin wrapper around a class, and test the class. When the task itself needs a test, load tasks once (`Rails.application.load_tasks if Rake::Task.tasks.empty?`), then `Rake::Task["billing:renew"].reenable` and `.invoke`.

## Routes

Only for routes with constraints, custom matching, or redirects: `assert_recognizes`, `assert_routing`. Ordinary resource routes are covered by the integration tests that use them.

## Assertion choice

| To prove | Use |
|---|---|
| A count changed by an amount | `assert_difference(-> { card.comments.count }, +1) { ... }`; several at once: `assert_difference({ -> { A.count } => 1, -> { B.count } => -1 }) { ... }` |
| A value changed from one value to another | `assert_changes(-> { card.reload.status }, from: "open", to: "closed") { ... }` |
| Nothing changed | `assert_no_difference`, `assert_no_changes` |
| nil | `assert_nil` (Minitest 6 rejects `assert_equal nil, x` and `assert_same nil, x`) |
| Membership | `assert_includes`, `assert_not_includes` |
| A raise | `error = assert_raises(Card::Locked) { ... }`, then assert on `error.message` |
| A job | `assert_enqueued_with(job:, args:)`, `assert_enqueued_jobs 1, only: X`, `perform_enqueued_jobs` |
| An email | `assert_emails 1`, `assert_enqueued_email_with` |
| HTML | `assert_dom` (or `assert_select` on Rails before 7.1) |
| Turbo | `assert_turbo_stream`, `assert_turbo_stream_broadcasts` |
| Queries | `assert_queries_count`, `assert_no_queries`, `assert_queries_match` (Rails 7.2+) |
| A reported error | `assert_error_reported`, `assert_no_error_reported` |
| Floating point or time closeness | `assert_in_delta` |

With a `{ ... }` block, put the arguments in parentheses, as above: without them Ruby binds the braces to the last argument. `do ... end` needs no parentheses.
