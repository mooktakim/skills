# frozen_string_literal: true

require_relative "test_helper"

# rails-hotwire's audit_hotwire, run against small throwaway Rails-shaped apps.
class AuditHotwireTest < Minitest::Test
  include ScriptTestHelper

  GEMS = { "rails" => "8.1.4", "turbo-rails" => "2.0.23", "stimulus-rails" => "1.3.4", "importmap-rails" => "2.2.3", "rack" => "3.2.4" }.freeze

  LAYOUT = <<~ERB
    <!DOCTYPE html>
    <html>
      <head>
        <% turbo_refreshes_with method: :morph, scroll: :preserve %>
        <%= yield :head %>
        <%= javascript_importmap_tags %>
      </head>
      <body>
        <%= yield %>
      </body>
    </html>
  ERB

  def setup
    super
    install "rails-hotwire", "audit_hotwire"
  end

  def lock(gems)
    specs = gems.map { |name, version| "    #{name} (#{version})\n" }.join
    write "Gemfile.lock", "GEM\n  remote: https://rubygems.org/\n  specs:\n#{specs}\nPLATFORMS\n  ruby\n"
  end

  def app(gems: GEMS, importmap: true)
    lock gems
    write "config/application.rb", "module App\n  class Application < Rails::Application\n  end\nend\n"
    write "config/importmap.rb", %(pin "application"\npin_all_from "app/javascript/controllers", under: "controllers"\n) if importmap
    write "config/cable.yml", "development:\n  adapter: async\n\nproduction:\n  adapter: solid_cable\n  polling_interval: 0.1.seconds\n"
    write "app/views/layouts/application.html.erb", LAYOUT
  end

  def audit(*args, cwd: @dir)
    run_script "audit_hotwire", *args, cwd: cwd
  end

  def findings
    audit.out[/^Findings.*?(?=\n\n|\z)/m].lines.drop(1).map(&:strip)
  end

  def rules
    findings.map { |line| line[/\A\[([a-z0-9-]+)\]/, 1] }.compact
  end

  def test_refuses_outside_a_rails_app_or_without_hotwire
    result = audit
    assert_equal 1, result.code
    assert_includes result.err, "no config/application.rb found"
    app gems: { "rails" => "8.1.4" }
    result = audit
    assert_equal 1, result.code
    assert_includes result.err, "neither turbo-rails nor stimulus-rails"
  end

  def test_a_clean_app_reports_its_setup_and_inventory_from_a_subfolder
    app
    write "app/javascript/controllers/toggle_controller.js", <<~JS
      import { Controller } from "@hotwired/stimulus"
      export default class extends Controller {
        static targets = ["panel"]
        connect() { document.addEventListener("keydown", this.close) }
        disconnect() { document.removeEventListener("keydown", this.close) }
        close = () => { this.panelTarget.hidden = true }
        submit() { this.element.requestSubmit() }
      }
    JS
    write "app/views/cards/create.turbo_stream.erb", %(<%= turbo_stream.append "cards", @card %>\n)
    write "app/views/boards/show.html.erb", %(<%= turbo_stream_from @board %>\n<%= turbo_frame_tag @board, :comments, src: board_comments_path(@board), loading: :lazy %>\n)
    write "app/models/card.rb", "class Card < ApplicationRecord\n  belongs_to :board, touch: true\n  broadcasts_refreshes_to :board\nend\n"
    write "app/controllers/cards_controller.rb", "class CardsController\n  def create\n    render :new, status: :unprocessable_content\n  end\nend\n"
    result = audit(cwd: path("app/views"))
    assert_equal 0, result.code
    out = result.out
    assert_includes out, "Hotwire audit: #{@dir}\n"
    assert_includes out, "  turbo-rails 2.0.23, stimulus-rails 1.3.4, Rails 8.1.4\n"
    assert_includes out, "  JavaScript: importmap; cable (production): solid_cable\n"
    assert_includes out, "  page refreshes by morph: yes\n"
    assert_includes out, "  hover prefetch: on (Turbo 8 default)\n"
    assert_includes out, "  Stimulus controllers: 1\n  stream templates (.turbo_stream.*): 1\n"
    assert_includes out, "  frames (turbo_frame_tag): 1\n"
    assert_includes out, "  broadcast calls (models and components): 1\n  subscriptions (turbo_stream_from): 1\n"
    assert_includes out, "Findings (0)\n  none\n"
  end

  def test_legacy_ujs_and_turbolinks
    app gems: GEMS.merge("turbolinks" => "5.2.1", "turbo-rails" => "1.5.0")
    write "app/javascript/application.js", %(import Rails from "@rails/ujs"\nRails.start()\ndocument.addEventListener("turbolinks:load", () => {})\n)
    write "app/views/posts/show.html.erb", <<~ERB
      <%= link_to "Delete", @post, method: :delete, data: { confirm: "Sure?" } %>
      <%= button_to "Delete", @post, method: :delete, form: { data: { turbo_confirm: "Sure?" } } %>
      <%= form_with model: @post, local: false, remote: true do |f| %><% end %>
      <a href="/x" data-turbolinks="false">x</a>
    ERB
    assert_equal %w[turbo-7 turbolinks ujs ujs-attribute ujs-attribute turbolinks turbolinks], rules
    assert_includes findings, "[ujs] app/javascript/application.js:1 - rails-ujs is loaded; Turbo replaces it (references/upgrade.md)"
  end

  def test_form_responses_and_statuses
    app
    write "app/controllers/posts_controller.rb", <<~RUBY
      class PostsController
        def create
          render :new
        end

        def update
          render :edit, status: :unprocessable_entity
        end
      end
    RUBY
    assert_equal %w[render-200 unprocessable-entity], rules
    assert_includes findings.first, "[render-200] app/controllers/posts_controller.rb:3 - render :new with no status"
    app gems: GEMS.merge("rack" => "3.0.11")
    assert_equal %w[render-200], rules
  end

  def test_sync_broadcasts_in_models
    app
    write "app/models/message.rb", <<~RUBY
      class Message < ApplicationRecord
        after_create_commit -> { broadcast_append_to room }
        after_update_commit -> { broadcast_replace_later_to room }
        after_destroy_commit -> { broadcast_remove_to room }
        # broadcast_replace_to in a comment
      end
    RUBY
    assert_equal ["[sync-broadcast] app/models/message.rb:2 - broadcast_append_to renders in the request or transaction; use the _later_to version (remove may stay sync)"], findings
  end

  def test_removed_turbo_apis_and_form_submit
    app
    write "app/views/layouts/_flash.html.erb", %(<div data-turbo-cache="false">hi</div>\n<div data-turbo-temporary>ok</div>\n)
    write "app/javascript/controllers/form_controller.js", <<~JS
      export default class extends Controller {
        save() { this.element.submit() }
        go() { this.submit() }
        also() { this.autoSaveOutlet.submit() }
        clear() { Turbo.clearCache() }
      }
    JS
    write "app/javascript/application.js", %(document.addEventListener("DOMContentLoaded", () => {})\n)
    assert_equal %w[turbo-cache-false page-ready form-submit removed-js], rules
  end

  def test_stimulus_hygiene
    app
    write "app/javascript/controllers/legacy_controller.js", %(import { Controller } from "stimulus"\nexport default class extends Controller {\n  connect() { this.url = this.data.get("url") }\n}\n)
    write "app/javascript/controllers/leaky_controller.js", <<~JS
      export default class extends Controller {
        connect() {
          window.addEventListener("resize", this.layout)
          document.addEventListener("turbo:load", this.once, { once: true })
          this.element.addEventListener("click", this.go)
          this.timer = setInterval(this.tick, 1000)
          new IntersectionObserver(this.seen).observe(this.element)
          this.menu = document.querySelector(".menu")
          this.anchor = document.getElementById(this.anchorValue)
        }
      }
    JS
    write "app/views/posts/index.html.erb", %(<div data-controller="search"><input data-target="search.query"></div>\n)
    assert_equal %w[stimulus-1 stimulus-1 stimulus-1 listener-leak listener-leak listener-leak global-query], rules
    assert_includes findings, "[listener-leak] app/javascript/controllers/leaky_controller.js:3 - a window or document listener with no removeEventListener; undo it in disconnect(), or use data-action (with @window/@document)"
  end

  def test_jsbundling_controllers_must_be_registered
    app gems: GEMS.reject { |name, _| name == "importmap-rails" }.merge("jsbundling-rails" => "1.3.1"), importmap: false
    write "app/javascript/controllers/index.js", %(import ToggleController from "./toggle_controller"\napplication.register("toggle", ToggleController)\n)
    write "app/javascript/controllers/toggle_controller.js", "export default class {}\n"
    write "app/javascript/controllers/admin/menu_controller.js", "export default class {}\n"
    assert_equal ["[unregistered] app/javascript/controllers/admin/menu_controller.js - not imported in controllers/index.js, so it never registers; run bin/rails stimulus:manifest:update"], findings
  end

  def test_layout_placement
    app
    write "app/views/layouts/admin.html.erb", <<~ERB
      <html>
        <head>
          <%= turbo_stream_from :admin %>
        </head>
        <body>
          <%= javascript_importmap_tags "admin" %>
        </body>
      </html>
    ERB
    assert_equal %w[stream-in-head body-script], rules
  end
end
