# frozen_string_literal: true

require_relative "test_helper"

# The plugins' hook scripts, run the way Claude Code runs them: with
# CLAUDE_PROJECT_DIR, CLAUDE_PLUGIN_ROOT, and CLAUDE_PLUGIN_DATA set, from
# whatever directory the session happens to be in.
class HooksTest < Minitest::Test
  include ScriptTestHelper

  def setup
    super
    @data = Dir.mktmpdir("plugin-data")
  end

  def teardown
    super
    FileUtils.rm_rf(@data)
  end

  def plugin_env(plugin)
    { "CLAUDE_PROJECT_DIR" => @dir, "CLAUDE_PLUGIN_ROOT" => File.join(REPO, plugin), "CLAUDE_PLUGIN_DATA" => @data }
  end

  def hook(plugin, script, *args, stdin: "", cwd: @dir, env: {})
    run_bash File.join(REPO, plugin, "hooks", script), *args, stdin: stdin, cwd: cwd, env: plugin_env(plugin).merge(env)
  end

  def system_message(result)
    JSON.parse(result.out)["systemMessage"]
  end

  def design_app
    write "docs/design-system/README.md", "# Design system\n"
    write "app/views/x/a.html.erb", %(<p class="bg-surface">ok</p>\n)
    FileUtils.mkdir_p(path("docs/sub"))
    commit "init"
  end

  # -- enforce.sh: the plugin-shipped design hooks --------------------------

  def test_enforce_runs_the_plugins_copy_from_a_subfolder_with_no_bin_copy
    design_app
    append "app/views/x/a.html.erb", %(<p class="bg-red-600">edit</p>\n)
    edit = hook("rails-design-system", "enforce.sh", "--hook", stdin: hook_json(path("app/views/x/a.html.erb")), cwd: path("docs/sub"))
    assert_equal 2, edit.code
    assert_includes edit.err, "app/views/x/a.html.erb:2:"
    turn_end = hook("rails-design-system", "enforce.sh", "--stop", stdin: '{"stop_hook_active": false}', cwd: path("docs/sub"))
    assert_equal 2, turn_end.code
  end

  def test_enforce_caches_the_ruby_binary_and_recovers_from_a_stale_cache
    design_app
    hook("rails-design-system", "enforce.sh", "--stop", stdin: "{}")
    cache = Dir.glob(File.join(@data, "ruby-*")).first
    assert cache, "the resolved Ruby path is cached"
    assert File.executable?(File.read(cache))
    File.write(cache, "/nonexistent/ruby")
    append "app/views/x/a.html.erb", %(<p class="bg-red-600">edit</p>\n)
    assert_equal 2, hook("rails-design-system", "enforce.sh", "--stop", stdin: "{}").code
    refute_equal "/nonexistent/ruby", File.read(cache)
  end

  def test_enforce_is_silent_outside_design_system_projects
    write "app/views/x/a.html.erb", %(<p class="bg-red-600">x</p>\n)
    commit
    assert_equal 0, hook("rails-design-system", "enforce.sh", "--hook", stdin: hook_json(path("app/views/x/a.html.erb"))).code
    assert_equal 0, hook("rails-design-system", "enforce.sh", "--hook", env: { "CLAUDE_PROJECT_DIR" => "" }).code
  end

  # -- the weekly maintenance notices ---------------------------------------

  def test_design_nudge_reports_each_reason_once_a_week
    design_app
    install "rails-design-system", "audit_design"
    commit "audit"
    first = hook("rails-design-system", "maintenance-nudge.sh")
    message = system_message(first)
    assert_includes message, "bin/audit_design is not run in CI"
    refute_includes message, "differs"
    assert_equal "", hook("rails-design-system", "maintenance-nudge.sh").out, "at most once a week"
  end

  def test_design_nudge_flags_outdated_scripts_leftover_hooks_and_findings
    design_app
    install "rails-design-system", "audit_design"
    append "bin/audit_design", "# local edit\n"
    write ".claude/settings.json", %({"hooks":{"PostToolUse":[{"hooks":[{"command":"bin/audit_design --hook"}]}]}}\n)
    write "config/ci.rb", %(step "Design: token audit", "bin/audit_design --strict"\n)
    append "app/views/x/a.html.erb", %(<p class="bg-gray-100">x</p>\n)
    message = system_message(hook("rails-design-system", "maintenance-nudge.sh"))
    assert_includes message, "bin/audit_design reports 1 finding(s)"
    assert_includes message, "differs from the installed skill version"
    assert_includes message, "old audit_design hooks in .claude/settings.json"
    refute_includes message, "not run in CI"
  end

  def test_design_nudge_is_silent_when_all_is_well_or_not_set_up
    assert_equal "", hook("rails-design-system", "maintenance-nudge.sh").out
    design_app
    install "rails-design-system", "audit_design"
    write "config/ci.rb", %(step "Design: token audit", "bin/audit_design --strict"\n)
    commit "ci"
    assert_equal "", hook("rails-design-system", "maintenance-nudge.sh").out
  end

  def test_context_nudge
    write "README", "x"
    commit
    assert_equal "", hook("rails-context", "maintenance-nudge.sh").out, "silent without bin/audit_context"

    install "rails-context", "audit_context"
    write "CLAUDE.md", "# root\n"
    write "app/models/CLAUDE.md", (1..200).map(&:to_s).join("\n") + "\n"
    File.symlink("CLAUDE.md", path("app/models/AGENTS.md"))
    6.times { |i| write "app/helpers/h#{i}.rb", "module H#{i}; end\n" }
    commit "context"
    message = system_message(hook("rails-context", "maintenance-nudge.sh"))
    assert_includes message, "1 context file(s) over the size limit"
    assert_includes message, "1 director(ies) may need a context file"
    refute_includes message, "differs"
  end

  # -- capture: the correction hint ------------------------------------------

  def prompt_hint(prompt)
    out = hook("capture", "correction-hint.sh", stdin: JSON.generate("session_id" => "s", "prompt" => prompt)).out
    out.empty? ? nil : JSON.parse(out).dig("hookSpecificOutput", "additionalContext")
  end

  CORRECTIONS = [
    "no, don't use trailing slashes",
    "Don't add icons to buttons",
    "never commit to main",
    "I already told you to use Phlex",
    "from now on run the tests before committing",
    "why did you change the header again?",
    "you keep adding a dot to the status badge",
    "update CLAUDE.md so you stop doing this",
    "stop using inline styles"
  ].freeze

  NOT_CORRECTIONS = [
    "add a pagination component to the bids page",
    "Make the button blue",
    "what does this method do?",
    "/rails-context:rails-context",
    "<command-name>/capture:capture</command-name>",
    "nothing else, thanks"
  ].freeze

  def test_correction_hint_fires_on_corrections_and_rules
    CORRECTIONS.each { |prompt| assert_includes prompt_hint(prompt).to_s, "capture skill", prompt }
  end

  def test_correction_hint_stays_quiet_otherwise
    NOT_CORRECTIONS.each { |prompt| assert_nil prompt_hint(prompt), prompt }
    assert_equal "", hook("capture", "correction-hint.sh", stdin: "not json").out
  end

  # -- the delegation notes -------------------------------------------------

  def test_design_reviewer_note_only_in_design_system_apps
    assert_equal "", hook("rails-design-system", "reviewer-context.sh").out
    design_app
    context = JSON.parse(hook("rails-design-system", "reviewer-context.sh").out).dig("hookSpecificOutput", "additionalContext")
    assert_includes context, "rails-design-system:design-reviewer"
  end

  def test_specialists_note_only_in_rails_apps_including_one_level_down
    assert_equal "", hook("rails-specialists", "delegation-context.sh").out
    write "api/config/application.rb", "module Api\n  class Application < Rails::Application\n  end\nend\n"
    context = JSON.parse(hook("rails-specialists", "delegation-context.sh").out).dig("hookSpecificOutput", "additionalContext")
    assert_includes context, "rails-specialists:rails-reviewer"
  end
end
