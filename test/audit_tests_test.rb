# frozen_string_literal: true

require_relative "test_helper"

# rails-minitest's audit_tests, run against small throwaway Rails-shaped apps.
class AuditTestsTest < Minitest::Test
  include ScriptTestHelper

  GOOD_HELPER = <<~RUBY
    ENV["RAILS_ENV"] ||= "test"
    require "simplecov"
    SimpleCov.start "rails"
    require_relative "../config/environment"
    require "rails/test_help"
    require "webmock/minitest"
    WebMock.disable_net_connect!(allow_localhost: true)

    class ActiveSupport::TestCase
      parallelize workers: :number_of_processors
      fixtures :all
    end
  RUBY

  FIXTURE_GUARD = <<~RUBY
    class FixturesTest < ActiveSupport::TestCase
      test "every fixture is valid" do
        ApplicationRecord.descendants.each { |model| model.find_each { |record| assert record.valid? } }
      end
    end
  RUBY

  def setup
    super
    install "rails-minitest", "audit_tests"
  end

  def lock(gems)
    specs = gems.map { |name, version| "    #{name} (#{version})\n" }.join
    write "Gemfile.lock", "GEM\n  remote: https://rubygems.org/\n  specs:\n#{specs}\nPLATFORMS\n  ruby\n"
  end

  def app(helper: GOOD_HELPER, gems: { "rails" => "8.1.4", "minitest" => "6.0.3", "minitest-mock" => "5.27.0", "simplecov" => "1.3.2", "webmock" => "3.26.0" })
    lock gems
    write "test/test_helper.rb", helper
    write "test/fixtures/users.yml", "admin:\n  name: Ada\n"
    write "test/models/fixtures_test.rb", FIXTURE_GUARD
  end

  def audit(*args, cwd: @dir)
    run_script "audit_tests", *args, cwd: cwd
  end

  def findings(*args)
    audit(*args).out[/^Findings.*?(?=\n\n|\z)/m].lines.drop(1).map(&:strip)
  end

  def rules
    findings.map { |line| line[/\A\[([a-z-]+)\]/, 1] }.compact
  end

  def test_refuses_an_app_without_a_minitest_helper
    write "spec/spec_helper.rb", "# rspec\n"
    result = audit
    assert_equal 1, result.code
    assert_includes result.err, "no test/test_helper.rb found"
  end

  def test_a_well_set_up_suite_has_no_findings_and_is_found_from_a_subfolder
    app
    write "app/models/card.rb", "class Card < ApplicationRecord\n  def close = update!(closed: true)\nend\n"
    write "test/models/card_test.rb", %(class CardTest < ActiveSupport::TestCase\n  test "closes" do\n    assert true\n  end\n  test "reopens" do\n  end\nend\n)
    FileUtils.mkdir_p(path("app/models"))
    result = audit(cwd: path("app/models"))
    assert_equal 0, result.code
    assert_includes result.out, "Rails Minitest audit: #{@dir}\n"
    assert_includes result.out, "  Rails 8.1.4, Minitest 6.0.3\n"
    assert_includes result.out, "  Test data: fixtures (1 files)\n"
    assert_includes result.out, "minitest-mock 5.27.0, webmock 3.26.0, simplecov 1.3.2"
    assert_includes result.out, "  parallelize: yes\n  fixtures :all: yes\n  network guard: WebMock\n  coverage: SimpleCov, test_helper.rb line 2\n"
    assert_match(/^  models\s+2 files\s+3 tests$/, result.out)
    assert_includes result.out, "Untested (0 of 1 files with code"
    assert_includes result.out, "Findings (0)\n  none\n"
  end

  def test_suite_level_gaps
    app helper: %(require_relative "../config/environment"\nrequire "rails/test_help"\n)
    write "test/models/fixtures_test.rb", "# no guard\n"
    assert_equal %w[no-parallel no-network-guard no-fixture-guard], rules
  end

  def test_allow_net_connect_without_arguments_turns_the_guard_off
    app helper: GOOD_HELPER + "WebMock.allow_net_connect!\n"
    assert_equal ["[network-allowed] test/test_helper.rb:13 - WebMock.allow_net_connect! turns the network guard off for every test; allow hosts with disable_net_connect!(allow: ...)"], findings
    app helper: GOOD_HELPER + "WebMock.allow_net_connect!(net_http_connect_on_start: true)\n"
    assert_equal %w[network-allowed], rules, "arguments do not limit it"
    app helper: GOOD_HELPER + "WebMock.enable_net_connect!\n"
    assert_equal %w[network-allowed], rules
  end

  def test_coverage_that_starts_after_the_app_loads
    app helper: GOOD_HELPER.sub(%(require "simplecov"\nSimpleCov.start "rails"\n), "") + %(require "simplecov"\nSimpleCov.start\n)
    assert_includes findings.first, "[coverage-late] test/test_helper.rb:11 - SimpleCov starts after the app loads (line 2)"
  end

  def test_parallel_coverage_hooks_depend_on_the_simplecov_version
    hooks = GOOD_HELPER + %(class ActiveSupport::TestCase\n  parallelize_setup { |w| SimpleCov.command_name "t-\#{w}" }\n  parallelize_teardown { |_| SimpleCov.result }\nend\n)
    app helper: hooks
    assert_equal %w[coverage-parallel-hooks], rules
    app helper: hooks, gems: { "rails" => "8.1.4", "minitest" => "5.25.0", "simplecov" => "0.22.0", "webmock" => "3.26.0" }
    assert_empty rules
    app helper: GOOD_HELPER, gems: { "rails" => "8.1.4", "minitest" => "5.25.0", "simplecov" => "0.22.0", "webmock" => "3.26.0" }
    assert_equal %w[coverage-parallel], rules
  end

  def test_minitest_six_stubs_need_minitest_mock
    app gems: { "rails" => "8.1.4", "minitest" => "6.0.3", "webmock" => "3.26.0", "mocha" => "3.1.0" }
    write "test/models/a_test.rb", "Card.stubs(:find).returns(1)\n"
    assert_empty rules, "mocha's stubs is not Minitest's stub"
    write "test/models/b_test.rb", "\nTime.stub(:now, 1) { }\nTime.stub :now, 1 do\nend\n"
    assert_equal ["[minitest-mock-missing] test/models/b_test.rb:2 - Minitest 6.0.3 has no stub or Minitest::Mock without the minitest-mock gem (2 uses)"], findings
    app gems: { "rails" => "8.1.4", "minitest" => "5.25.0", "webmock" => "3.26.0" }
    assert_empty rules
  end

  def test_line_smells_skip_comments_and_lookalikes
    app
    write "test/controllers/cards_controller_test.rb", <<~RUBY
      class CardsControllerTest < ActionController::TestCase
        # sleep 1 and binding.irb in a comment
        test "a" do
          assert_equal nil, x
          assert_same(nil, y)
          sleep 0.5
          sleep(1)
          @asleep = true
          binding.irb
          MiniTest::Assertion
        end
        i_suck_and_my_tests_are_order_dependent!
      end
    RUBY
    assert_equal %w[controller-test-case assert-equal-nil assert-equal-nil sleep sleep debugger minitest-namespace order-dependent], rules
    assert_includes findings, "[sleep] test/controllers/cards_controller_test.rb:6 - sleep; use travel_to, or Capybara's waiting matchers"
  end

  def test_only_unconditional_skips_at_the_start_of_a_test
    app
    write "test/models/card_test.rb", <<~RUBY
      class CardTest < ActiveSupport::TestCase
        test "flaky" do
          skip "fails on CI"
        end

        test "needs vips" do
          skip "no libvips" unless vips?
        end

        test "inside a branch" do
          if broken?
            skip "broken"
          end
        end
      end
    RUBY
    assert_equal ["[skip] test/models/card_test.rb:3 - test skipped unconditionally"], findings
  end

  def test_env_writes_are_leads_only_without_an_ensure
    app
    write "test/models/a_test.rb", %(test "x" do\n  ENV["FLAG"] = "1"\n  assert ENV["FLAG"] == "1"\nend\n)
    write "test/models/b_test.rb", %(def with_flag\n  old, ENV["FLAG"] = ENV["FLAG"], "1"\n  yield\nensure\n  ENV["FLAG"] = old\nend\n)
    assert_equal ["[env-write] test/models/a_test.rb:2 - ENV changed in a test file with no ensure to restore it"], findings
  end

  def test_form_login_is_reported_once_when_three_files_repeat_it
    app
    login = %(setup do\n  post session_path, params: { email: "a", password: "b" }\nend\n)
    write "test/controllers/a_controller_test.rb", login
    write "test/controllers/b_controller_test.rb", login
    write "test/controllers/sessions_controller_test.rb", login
    write "test/integration/password_resets_test.rb", login
    assert_empty rules, "auth tests sign in through the form on purpose"
    write "test/integration/checkout_test.rb", login + login
    assert_equal ["[form-login] test/controllers/a_controller_test.rb:2 - 3 integration test files sign in through the login route; add a sign_in_as helper that creates the session directly"], findings
  end

  def test_system_heavy_suites
    app
    write "test/models/card_test.rb", (1..15).map { |i| %(test "m#{i}" do\nend\n) }.join
    write "test/system/flow_test.rb", (1..5).map { |i| %(test "s#{i}" do\nend\n) }.join
    assert_equal %w[system-heavy], rules
    assert_includes audit.out, "  system share: 24%\n"
  end

  def test_untested_files_mirror_the_app_and_cap_at_ten
    app
    write "app/models/application_record.rb", "class ApplicationRecord < ActiveRecord::Base\n  primary_abstract_class\nend\n"
    write "app/models/empty.rb", "class Empty < ApplicationRecord\nend\n"
    write "app/models/card.rb", "class Card\n  def a; end\nend\n"
    write "app/models/card/closeable.rb", "module Card::Closeable\n  def close; end\nend\n"
    write "test/models/card/closeable_test.rb", "\n"
    write "app/controllers/cards_controller.rb", "class CardsController\n  def index; end\nend\n"
    write "test/integration/cards_controller_test.rb", "\n"
    write "app/views/cards/index.html.erb", "<p>x</p>\n"
    write "lib/tasks/x.rb", "def x; end\n"
    12.times { |i| write "app/services/s#{format('%02d', i)}.rb", "class S\n  def run; end\nend\n" }
    out = audit.out
    assert_includes out, "Untested (13 of 15 files with code have no test file named after them)\n"
    assert_includes out, "  app/models (1 of 2)\n    app/models/card.rb\n"
    assert_includes out, "  app/services (12 of 12)\n"
    assert_includes out, "    app/services/s09.rb\n    ... 2 more (--all lists them)\n"
    refute_includes out, "app/controllers ("
    assert_includes audit("--all").out, "    app/services/s11.rb\n"
  end

  def test_record_hot_spots
    app
    write "test/models/a_test.rb", "create(:user)\ncreate_list(:card, 3)\nUser.create!(name: 1)\nCard.create(x: 1)\nFactoryBot.create(:board)\n"
    write "test/models/b_test.rb", "create(:user)\n"
    out = audit.out
    assert_includes out, "Records (test files with the most create calls)\n     5  test/models/a_test.rb\n"
    refute_includes out, "test/models/b_test.rb"
  end
end
