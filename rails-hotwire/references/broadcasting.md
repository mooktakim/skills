# Broadcasting

Read this before pushing updates over Action Cable: choosing refresh or targeted broadcasts, naming and securing streams, and the cable adapter. Stream actions themselves are in `streams.md`; keeping state through refreshes is in `morphing.md`. For ViewComponents that broadcast themselves, see the rails-view-component skill (`TurboViewComponent`).

## Refresh or targeted

| Situation | Use |
|---|---|
| a page shows shared records, and different viewers see different things (permissions, "mine", edit buttons) | **refresh**: `broadcasts_refreshes`; each browser re-fetches its page with its own session and morphs it |
| many parts of a page change together | refresh |
| an item appears in a list that looks the same to everyone (chat, feed, log) | targeted: `broadcast_append_later_to` |
| a fragment changes often and re-fetching the page is too costly | targeted `replace` / `update` |
| a private tray for one user (notifications, pins) | targeted to `[user, :notifications]` |

37signals moved to refresh broadcasts and report that they replaced a large amount of targeted broadcast code ([A happier happy path in Turbo with morphing](https://dev.37signals.com/a-happier-happy-path-in-turbo-with-morphing/)); targeted streams stay for fidelity and frequency. A refresh costs one page request per connected viewer, so keep refreshed pages cheap (fragment caching, preloading).

## Declaring broadcasts

Declare them in the model, in a concern when there are several (`Card::Broadcastable`):

```ruby
class Card < ApplicationRecord
  belongs_to :board, touch: true            # a touch on the board refreshes board pages
  broadcasts_refreshes                      # refresh pages that subscribe to this card
end

class Board < ApplicationRecord
  broadcasts_refreshes
  broadcasts_refreshes_to ->(board) { [board.account, :all_boards] }
end

class Notification < ApplicationRecord
  after_create_commit  -> { broadcast_prepend_later_to user, :notifications, target: "notifications" }
  after_destroy_commit -> { broadcast_remove_to user, :notifications }
end
```

| Macro | Create | Update | Destroy |
|---|---|---|---|
| `broadcasts_to :board` | append (`inserts_by:`) to the board's stream, later | replace, later | remove, at once |
| `broadcasts` | same, to the plural model stream | replace to its own stream | remove from its own stream, at once |
| `broadcasts_refreshes_to :board` | refresh, later | refresh, later | refresh, later |
| `broadcasts_refreshes` | refresh to the plural stream | refresh to its own stream | refresh to its own stream, at once |

- **Render in a job:** the `_later` methods (`broadcast_replace_later_to`, `broadcast_append_later_to`, `broadcast_refresh_later_to`). Synchronous broadcasts render the partial inside the request and the transaction.
- **Only `remove` stays synchronous.** A job cannot load a deleted record (it is discarded on `ActiveJob::DeserializationError`); `remove` needs only the id.
- **After commit.** The macros use `after_*_commit`. A hand-written broadcast inside a transaction goes out even if the transaction rolls back. In Rails 8.1, jobs do not wait for the commit by default (`enqueue_after_transaction_commit` is false), so broadcast from `after_commit` callbacks.
- **Debounce:** `broadcast_refresh_later_to` is debounced per stream and request for 0.5 s in the thread that sent it (not across threads or processes), and browsers debounce refreshes for 150 ms. For bulk changes, wrap them in `Card.suppressing_turbo_broadcasts { ... }` and broadcast one refresh at the end.
- **Fan-out with an audience check:** when a broadcast goes to many users' private streams, do it in a job that re-checks who may see the record when it runs.

## What a broadcast can render

Broadcasts render through `ApplicationController.render` in a job: no request, no session, no `current_user`, no `Current` values (unless a job concern sets them), a fake host. So:

- Broadcast partials are viewer-independent: the same bytes go to every subscriber. Personalise on the client - a `<meta name="current-user-id">` plus CSS (`[data-author-id="42"]`) or a Stimulus controller - or use a refresh broadcast.
- `*_url` helpers need `default_url_options[:host]`; prefer `*_path`.
- Preload what the partial needs, or keep it shallow: the partial renders once per broadcast, in a job, where N+1 queries are easy to miss. `strict_loading` in development catches them.
- Locals default to `{ model_name.element => self }`; pass `partial:` and `locals:` when the partial needs more.
- Multi-tenant apps that route by path or subdomain set the tenant in the job (a job concern that serialises `Current.account`) so URLs render correctly.

## Subscribing

```erb
<%= turbo_stream_from @board %>                       <%# inside <body> %>
<%= turbo_stream_from current_user, :notifications %>
```

- `turbo_stream_from` renders a `<turbo-cable-stream-source>` element: put it inside `<body>`, outside grid and flex layouts (or style it `display: contents`).
- The stream name joins the streamables with `:` (records by GlobalID). The view and the broadcast must use the same streamables in the same order.

## Security

- **A signed stream name is not authorisation.** `turbo_stream_from` signs the name with the app's secret; `Turbo::StreamsChannel` only checks the signature. The signature never expires and is not bound to a user: whoever once received the page can subscribe for as long as the secret lives.
- Scope streams to what the viewer may see: `[Current.account, :invoices]`, `[user, :notifications]`, never a global name for private data.
- When access can be revoked (removed from a room, a project, an account), authorise at subscription with a custom channel:

  ```ruby
  class RoomChannel < ApplicationCable::Channel
    extend Turbo::Streams::Broadcasts, Turbo::Streams::StreamName
    include Turbo::Streams::StreamName::ClassMethods

    def subscribed
      room = current_user.rooms.find_by(id: params[:room_id])
      if room && verified_stream_name_from_params == room.to_gid_param   # the stream name of a single record
        stream_from verified_stream_name_from_params
      else
        reject
      end
    end
  end
  ```

  ```erb
  <%= turbo_stream_from @room, channel: RoomChannel, data: { room_id: @room.id } %>
  ```

  The membership check runs on every subscription, so a user removed from the room cannot subscribe again; comparing the verified name with the room's own stream name stops a valid name for one room being reused with another room's id. Broadcast to it with `RoomChannel.broadcast_append_to(room, ...)`, and block the same names on `Turbo::StreamsChannel` if they must never go through the stock channel.
- Authenticate the cable connection (`ApplicationCable::Connection` with `identified_by :current_user`, from the session cookie; the Rails 8 authentication generator writes this) and set `config.action_cable.allowed_request_origins` in production.
- Never broadcast per-user markup to a shared stream.

## Adapters

| Adapter | Notes |
|---|---|
| `solid_cable` (Rails 8 default) | database-backed, polls (0.1 s default). Keep `message_retention` short (minutes, not the 1-day default) on busy apps |
| `redis` | use when the app already runs Redis or fan-out is very high |
| `postgresql` | NOTIFY payloads are limited to 8000 bytes: large rendered partials fail; prefer refreshes |
| AnyCable | a separate server; follow its docs for Turbo signed streams |
| `async` | development and test only |

## After a disconnect

Broadcasts sent while a client was offline are lost. Pages that must not miss updates catch up on reconnect: a Stimulus controller that, after the cable reconnects or the tab was hidden for a while, fetches a stream endpoint with `since=` (`get(url, { responseKind: "turbo-stream" })`) or simply refreshes the page.

## Debugging "the broadcast does nothing"

1. Is the page subscribed? `<turbo-cable-stream-source connected>` in the DOM, with the right stream (compare the streamables).
2. Did the broadcast run? `_later` broadcasts need the job to run (check the queue, or `perform_enqueued_jobs` in tests).
3. Does the target exist? A targeted action needs an element with that id on the page.
4. Did the partial render? Errors in a broadcast job appear in the job log, not the browser.
5. Was it the originating tab? Refreshes are ignored by the tab whose request caused them.
6. From the console: `Turbo::StreamsChannel.broadcast_refresh_to(board)` and watch the page.
