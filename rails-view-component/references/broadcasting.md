# Self-broadcasting components

Read this before making a component update itself over Action Cable. It covers the `TurboViewComponent` base class (a component that re-renders and replaces itself when its records change, with filters on which changes count), and when a Turbo 8 refresh broadcast is the better tool.

## Pick the broadcast

| Situation | Use |
|---|---|
| The page shows different things to different users (edit buttons, "mine", permissions) | **refresh broadcast**: `broadcasts_refreshes` on the model; each browser re-fetches its own page and morphs it |
| Many fragments of a page change together | refresh broadcast |
| One small fragment changes often, looks the same to every viewer, and re-fetching the page is too costly (a progress tracker, a status badge, a counter) | **`TurboViewComponent`** |
| A new item appears in a list that looks the same to every viewer | `broadcast_append_later_to` with `renderable: Component.render_later(...)` |

A targeted broadcast renders once for every subscriber, in a job with no request and no user. Anything viewer-specific in it is wrong for someone.

```ruby
class Board < ApplicationRecord
  broadcasts_refreshes                      # refresh broadcast; children `belongs_to :board, touch: true`
end
```

```erb
<%= turbo_stream_from @board %>
<%# layout: turbo_refreshes_with method: :morph, scroll: :preserve %>
```

## The TurboViewComponent base class

```ruby
# app/components/turbo_view_component.rb
#
# A component that replaces itself in every subscribed browser when its records
# change. Subclasses define #channel and may define #target_record and
# #broadcast_on. Models call Subclass.broadcast_update(**the same arguments the
# view passes) from after_commit.
class TurboViewComponent < ApplicationComponent
  include ViewComponent::Serializable

  # Enqueues a re-render if the watched changes happened. The filter runs now,
  # while saved_changes is still there; the render runs in a job, with the
  # records reloaded, so it shows the latest state.
  def self.broadcast_update(**args)
    component = new(**args)
    return unless component.broadcast?

    Turbo::StreamsChannel.broadcast_replace_later_to(
      *Array(component.channel),
      target: component.target_id,
      renderable: render_later(**args),
      layout: false
    )
  end

  # The stream this component listens on; the view's turbo_stream_from must match.
  def channel
    raise NotImplementedError, "#{self.class.name} must define #channel"
  end

  # The id on the root element: the component's path plus the record's dom_id,
  # e.g. "blog--article-progress-component--blog_article_42".
  def target_id
    [self.class.name.underscore.dasherize.gsub("/", "--"),
     (ActionView::RecordIdentifier.dom_id(target_record) if target_record)].compact.join("--")
  end

  def broadcast?
    @broadcast_filters = []
    broadcast_on
    return true if @broadcast_filters.empty?

    @broadcast_filters.any? { |filter| filter_matches?(*filter) }
  end

  private

  # The record whose id goes into target_id; nil for a component shown once per page.
  def target_record = nil

  # Override to watch columns: changes_to record, :state, prefix: "processed_".
  def broadcast_on; end

  def changes_to(record, *columns, prefix: nil, suffix: nil)
    @broadcast_filters << [record, columns.map(&:to_s), prefix&.to_s, suffix&.to_s]
  end

  def filter_matches?(record, columns, prefix, suffix)
    return false unless record.respond_to?(:saved_changes)

    changed = record.saved_changes.keys
    return false if changed.empty?
    return true if changed == %w[updated_at] # a touch from a child record

    changed -= %w[updated_at]
    changed.any? do |key|
      columns.include?(key) || (prefix && key.start_with?(prefix)) || (suffix && key.end_with?(suffix))
    end
  end
end
```

Requires ViewComponent 4.13+ (`ViewComponent::Serializable`). Below that, see "Older ViewComponent" at the end.

## A component

```ruby
# app/components/blog/article_progress_component.rb
class Blog::ArticleProgressComponent < TurboViewComponent
  def initialize(article:)
    @article = article
  end

  def channel = article

  private

  attr_reader :article

  def target_record = article

  def broadcast_on
    changes_to article, :state, :error_message, prefix: "processed_"
  end

  def visible? = !article.draft?
  def steps = Blog::Article::PROCESS_STEPS
  def step_completed?(step) = article.public_send(:"processed_#{step}_at").present?
end
```

```erb
<%# app/components/blog/article_progress_component.html.erb %>
<%= tag.div id: target_id do %>
  <% if visible? %>
    <ol>
      <% steps.each do |step| %>
        <li data-completed="<%= step_completed?(step) %>"><%= t(".steps.#{step}") %></li>
      <% end %>
    </ol>
  <% end %>
<% end %>
```

```ruby
# app/models/blog/article.rb
after_commit :broadcast_progress, on: %i[create update]

private

def broadcast_progress
  Blog::ArticleProgressComponent.broadcast_update(article: self)
  Blog::TopicProgressComponent.broadcast_update(topic: topic)
end
```

```erb
<%# app/views/blog/articles/show.html.erb %>
<%= turbo_stream_from @article %>
<%= render Blog::ArticleProgressComponent.new(article: @article) %>
```

## Rules

1. **The root element is a plain element with `id: target_id`, always rendered.** Never `turbo_frame_tag` as a broadcast target: a frame captures every link and form inside it, and adds an element with its own layout. Never `render?` on a broadcasting component: when it renders nothing, the next broadcast has no target. Put the "show nothing" condition inside the root element, as `visible?` does above.
2. **`channel` matches the view's `turbo_stream_from` exactly.** A record for a show page (`article`); an array for a list (`[brand, :keyword_researches]` with `turbo_stream_from @brand, :keyword_researches`). A mismatch sends broadcasts nobody receives.
3. **`broadcast_update` takes the same arguments the view passes to `new`.** They are what the job serializes, so they must be records (GlobalID), strings, numbers, symbols, or arrays and hashes of those - no blocks, no unsaved records, no slots that take blocks.
4. **The component is request-free** (`helpers.md`): no `current_user`, `params`, `request`, `Current`, or session. The job renders through `ApplicationController.render` with a fake request.
5. **Call it from `after_commit` (`on: %i[create update]`), never `after_save`.** Before the commit, the job can run before the data is visible. On destroy, remove the element instead - a job cannot load a deleted record: `component = Blog::ArticleProgressComponent.new(article: self)`, then `Turbo::StreamsChannel.broadcast_remove_to(*Array(component.channel), target: component.target_id)`.
6. **Use `broadcast_on` for components that render during busy pipelines**, so saves of large unrelated columns (bodies, outlines, briefs) do not re-render them:

   | Filter | Broadcasts when |
   |---|---|
   | no `broadcast_on` | every call |
   | `changes_to article, :state, :error_message` | `state` or `error_message` changed |
   | `changes_to article, prefix: "processed_"` | any `processed_*` column changed - new steps need no filter change |
   | `changes_to article, suffix: "_at"` | any `*_at` column changed |
   | several `changes_to` calls | any of them matches |
   | only `updated_at` changed | always (a child touched the record) |
   | nothing changed, or the object has no `saved_changes` | never |

7. **A child model broadcasts its parent's components** (`ArticleSection` saving updates `ArticleProgressComponent.broadcast_update(article: article)`) - or `belongs_to :article, touch: true` and let the parent's touch broadcast.
8. **Each broadcast builds new instances.** `broadcast_update` builds one instance to run the filter and the job builds another to render - never render the filter instance.

## Testing

Use fixtures and real saves; test the filter through what is broadcast, not by calling private methods. `Turbo::Broadcastable::TestHelper` is included in `ActiveSupport::TestCase` by turbo-rails.

```ruby
class Blog::ArticleProgressComponentTest < ViewComponent::TestCase
  test "renders the root element even for a draft" do
    render_inline Blog::ArticleProgressComponent.new(article: blog_articles(:draft))
    assert_selector "##{Blog::ArticleProgressComponent.new(article: blog_articles(:draft)).target_id}"
    assert_no_selector "ol"
  end
end

class Blog::ArticleProgressBroadcastTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "a step finishing replaces the progress tracker" do
    article = blog_articles(:processing)
    perform_enqueued_jobs do
      streams = capture_turbo_stream_broadcasts(article) { article.update!(processed_research_at: Time.current) }
      assert_equal "replace", streams.first["action"]
      assert_includes streams.first.to_html, "data-completed=\"true\""
    end
  end

  test "saving an unwatched column broadcasts nothing" do
    article = blog_articles(:processing)
    perform_enqueued_jobs do
      assert_no_turbo_stream_broadcasts(article) { article.update!(outline: "New outline") }
    end
  end
end
```

`perform_enqueued_jobs` makes the job really render the component, which is what catches a component that works in a request and breaks in a job.

## Apps with an older TurboViewComponent

Earlier versions of this base class wrapped the template in `turbo_frame_tag frame_id`, rendered synchronously with `ApplicationController.render(self, layout: false)` and `broadcast_replace_to`, and were called as `Component.new(...).broadcast_update`. In writing mode, follow the app's version. In library mode, propose the migration:

1. Replace the base class with the one above; keep `channel`, `broadcast_on`, and `changes_to` as they are.
2. In each template, replace `turbo_frame_tag frame_id do` with `tag.div id: target_id do`. Replace each `frame_id(id = nil)` override with `target_record`. Check that no caller or test used the old frame ids (`grep -rn "frame_id\|turbo-frame" app test`).
3. Move each `render?` into a condition inside the root element.
4. Change each call from `Component.new(**args).broadcast_update` to `Component.broadcast_update(**args)`.
5. Rewrite tests that call `send(:should_broadcast?)` on stub objects as broadcast tests like the ones above.

## Older ViewComponent

Below 4.13 there is no `render_later`. Render synchronously in `broadcast_update` - `Turbo::StreamsChannel.broadcast_replace_to(*Array(component.channel), target: component.target_id, html: ApplicationController.render(component, layout: false))` - and plan the upgrade (`upgrade.md`). Do not wrap that call in a `_later` method: the HTML is still rendered inside the callback.
