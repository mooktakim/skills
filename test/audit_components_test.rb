# frozen_string_literal: true

require_relative "test_helper"

# rails-view-component's audit_components, run against small throwaway
# Rails-shaped apps.
class AuditComponentsTest < Minitest::Test
  include ScriptTestHelper

  GEMS = { "rails" => "8.1.4", "view_component" => "4.15.0", "turbo-rails" => "2.0.23", "importmap-rails" => "2.2.3", "rack" => "3.2.4" }.freeze

  def setup
    super
    install "rails-view-component", "audit_components"
  end

  def lock(gems)
    specs = gems.map { |name, version| "    #{name} (#{version})\n" }.join
    write "Gemfile.lock", "GEM\n  remote: https://rubygems.org/\n  specs:\n#{specs}\nPLATFORMS\n  ruby\n"
  end

  def app(gems: GEMS)
    lock gems
    write "config/application.rb", "module App\n  class Application < Rails::Application\n  end\nend\n"
    write "app/components/application_component.rb", "class ApplicationComponent < ViewComponent::Base\nend\n"
  end

  def component(rel, ruby, template = nil)
    write "app/components/#{rel}.rb", ruby
    write "app/components/#{rel}.html.erb", template if template
  end

  def audit(*args, cwd: @dir)
    run_script "audit_components", *args, cwd: cwd
  end

  def findings
    audit.out[/^Findings.*?(?=\n\n|\z)/m].lines.drop(1).map(&:strip)
  end

  def rules
    findings.map { |line| line[/\A\[([a-z0-9-]+)\]/, 1] }.compact
  end

  def test_refuses_outside_a_rails_app_or_without_view_component
    result = audit
    assert_equal 1, result.code
    assert_includes result.err, "no config/application.rb found"
    app gems: { "rails" => "8.1.4" }
    result = audit
    assert_equal 1, result.code
    assert_includes result.err, "view_component is not in Gemfile.lock"
  end

  def test_a_clean_library_has_no_findings_and_is_found_from_a_subfolder
    app
    component "ui/badge_component", "class Ui::BadgeComponent < ApplicationComponent\n  def initialize(label:)\n    @label = label\n  end\nend\n", "<span><%= @label %></span>\n"
    component "cards/card_component/card_component", "class Cards::CardComponent < ApplicationComponent\n  def call = tag.div(content)\nend\n"
    write "test/components/previews/ui/badge_component_preview.rb", "\n"
    write "test/components/ui/badge_component_test.rb", "\n"
    result = audit(cwd: path("app/components"))
    assert_equal 0, result.code
    out = result.out
    assert_includes out, "ViewComponent audit: #{@dir}\n"
    assert_includes out, "  view_component 4.15.0, Rails 8.1.4, turbo-rails 2.0.23, stimulus-rails none\n"
    assert_includes out, "  base classes: app/components/application_component.rb\n"
    assert_match(/^  cards\s+1$/, out)
    assert_match(/^  ui\s+1$/, out)
    assert_includes out, "  templates: 1 call method, 1 sibling template\n"
    assert_includes out, "Previews (1 of 2 components have no preview file named after them)\n  app/components/cards/card_component/card_component.rb\n"
    assert_includes out, "Tests (1 of 2 components have no test file named after them)\n"
    assert_includes out, "Findings (0)\n  none\n"
  end

  def test_version_findings
    app gems: GEMS.merge("view_component" => "3.21.0")
    write "config/initializers/vc.rb", "Rails.application.config.view_component.preview_paths << 'x'\n"
    write "app/components/a_component.rb", "class AComponent < ApplicationComponent\n  use_helpers :icon\nend\n"
    assert_equal %w[vc-v3], rules, "v3 keys and APIs are right on v3"
    app gems: GEMS.merge("view_component" => "4.12.0")
    assert_equal %w[vc-insecure v3-config removed-api], rules
    assert_includes findings, "[v3-config] config/initializers/vc.rb:1 - config.view_component.preview_paths is a v3 key; see references/upgrade.md"
  end

  def test_base_class_findings
    lock GEMS
    write "config/application.rb", "\n"
    3.times { |i| component "c#{i}_component", "class C#{i}Component < ViewComponent::Base\nend\n" }
    assert_equal %w[no-base-class], rules, "direct-base needs an ApplicationComponent to point to"
    app
    assert_equal %w[direct-base direct-base direct-base], rules
    assert_includes findings, "[direct-base] app/components/c0_component.rb:1 - inherits ViewComponent::Base; inherit ApplicationComponent"
  end

  def test_component_code_smells
    app
    component "post_component", <<~RUBY, <<~ERB
      class PostComponent < ApplicationComponent
        def initialize(post:)
          @post = post
          @when = helpers.time_ago_in_words(post.created_at)
          @label = t(".label")
        end

        def comments = @post.comments.where(visible: true)
        def admin? = helpers.current_user.admin?
        def tab = params[:tab]
        def id = "post-\#{SecureRandom.hex(4)}"
        # helpers.current_user in a comment
      end
    RUBY
      <%= @post.body.html_safe %>
      <%# Current.user in a comment %>
      <% if Current.user %>x<% end %>
    ERB
    assert_equal %w[html-safe global-state helpers-in-initialize helpers-in-initialize query global-state global-state random-id], rules
    assert_includes findings, "[helpers-in-initialize] app/components/post_component.rb:4 - helpers in initialize raises; use before_render or a method called while rendering"
    assert_includes findings, "[global-state] app/components/post_component.rb:9 - reads helpers.current_user; pass the value in as an argument"
  end

  def test_turbo_findings
    app
    component "status_component", <<~RUBY, %(<%= turbo_frame_tag frame_id do %>\n  ok\n<% end %>\n)
      class StatusComponent < TurboViewComponent
        def render? = true
      end
    RUBY
    component "lazy_component", "class LazyComponent < ApplicationComponent\nend\n", %(<%= turbo_frame_tag "x", src: "/x", loading: :lazy %>\n)
    write "app/models/message.rb", <<~RUBY
      class Message < ApplicationRecord
        after_create_commit -> {
          broadcast_append_later_to room,
            renderable: MessageComponent.new(message: self)
        }
        after_update_commit -> { broadcast_replace_later_to room, renderable: MessageComponent.render_later(message: self) }
      end
    RUBY
    write "app/views/posts/show.html.erb", %(<%= render ButtonComponent.new(variant: :danger) { "Delete" } %>\n<%= render(ButtonComponent.new(variant: :danger)) { "Delete" } %>\n<%= render ButtonComponent.new do %>ok<% end %>\n)
    assert_equal %w[hidden-target frame-wrapper later-renderable lost-block], rules
    assert_includes findings, "[later-renderable] app/models/message.rb:3 - a _later broadcast with renderable: MessageComponent.new; the job cannot serialize it. Include ViewComponent::Serializable and use .render_later"
    assert_includes findings, "[lost-block] app/views/posts/show.html.erb:1 - the { } block binds to .new, not render, so the content is lost; write render(Foo.new(...)) { ... }"
  end

  def test_sidecar_stimulus_controllers_need_an_importmap_pin
    app
    write "app/components/ui/menu_component_controller.js", "export default class {}\n"
    write "config/importmap.rb", %(pin_all_from "app/javascript/controllers", under: "controllers"\n)
    assert_equal %w[sidecar-js-unloaded], rules
    append "config/importmap.rb", %(pin_all_from "app/components", under: "components", to: ""\n)
    assert_empty rules
    app gems: GEMS.reject { |name, _| name == "importmap-rails" }.merge("jsbundling-rails" => "1.3.1")
    write "config/importmap.rb", "\n"
    assert_empty rules, "bundler setups import their own way"
  end

  def test_unprocessable_entity_only_on_rack_three_one
    app
    write "app/controllers/posts_controller.rb", "class PostsController\n  def create = render(:new, status: :unprocessable_entity)\nend\n"
    assert_equal ["[unprocessable-entity] app/controllers/posts_controller.rb:2 - :unprocessable_entity is deprecated on Rack 3.2.4; use :unprocessable_content"], findings
    app gems: GEMS.merge("rack" => "3.0.11")
    assert_empty rules
  end
end
