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

  # -- rails-context: the context reach log and report -----------------------

  def log_event(mode, session, extra = {})
    hook("rails-context", "log-context.sh", mode, stdin: JSON.generate({ "session_id" => session }.merge(extra)))
  end

  def report(*args)
    out, err, status = Open3.capture3(ruby_bin, File.join(REPO, "rails-context/scripts/context_report"), *args, chdir: path("app"))
    Result.new(out, err, status)
  end

  def context_app
    install "rails-context", "audit_context"
    write "CLAUDE.md", "# root\n"
    write "app/models/CLAUDE.md", "# models\n"
    write "app/services/CLAUDE.md", "# services\n"
    write "app/helpers/CLAUDE.md", "# helpers\n"
    write "app/models/user.rb", "class User; end\n"
    write "app/services/pay.rb", "class Pay; end\n"
    commit "init"
  end

  def test_context_log_is_silent_without_rails_context
    write "README", "x"
    commit
    log_event("start", "s1")
    refute File.exist?(path(".git/claude-context-log.jsonl"))
  end

  def test_context_report_measures_reach_and_the_coverage_gap
    context_app
    assert_includes report.out, "No context log yet"

    # Session 1 changes models (reached by a nested load) and services (never reached).
    log_event("start", "s1")
    log_event("load", "s1", "file_path" => path("CLAUDE.md"), "load_reason" => "session_start")
    log_event("load", "s1", "file_path" => path("app/models/CLAUDE.md"), "load_reason" => "nested_traversal",
                            "trigger_file_path" => path("app/models/user.rb"))
    append "app/models/user.rb", "# edit\n"          # an edit by any tool, e.g. sed -i
    write "app/services/refund.rb", "class Refund; end\n" # an untracked new file
    log_event("stop", "s1")
    log_event("stop", "s1") # an unchanged turn writes nothing new
    commit "work"

    # Session 2 reads the services file on purpose (via its AGENTS.md symlink path), then changes it.
    log_event("start", "s2")
    log_event("read", "s2", "tool_input" => { "file_path" => path("app/services/AGENTS.md") })
    log_event("read", "s2", "tool_input" => { "file_path" => path("app/services/pay.rb") }) # not a context file
    append "app/services/pay.rb", "# edit\n"
    log_event("stop", "s2")

    lines = File.readlines(path(".git/claude-context-log.jsonl"))
    assert_equal 1, lines.count { |line| line.include?('"s":"s1","e":"changed"') }, "unchanged turns are not logged twice"
    assert_equal 1, lines.count { |line| line.include?('"e":"read"') }

    out = report.out
    assert_includes out, "Context reach - 2 session(s)"
    assert_match(%r{app/services/CLAUDE.md\s+2\s+1\s+1\s+read 1}, out)
    assert_match(%r{app/models/CLAUDE.md\s+1\s+1\s+0\s+nested 1}, out)
    assert_includes out, "Never reached Claude: app/helpers/CLAUDE.md"
    assert_includes out, "Root CLAUDE.md: 1 KB, loaded in 1 of 2 session(s)."
    assert_includes out, "Gap = sessions that changed code"
    assert_includes report("--days", "0").out, "No sessions logged"
  end

  # -- rails-context: directory context for code touched without Read ----------

  def tool_call(tool, tool_input, session: "s1", cwd: @dir)
    hook("rails-context", "inject-context.sh",
         stdin: JSON.generate("session_id" => session, "cwd" => cwd, "tool_name" => tool, "tool_input" => tool_input))
  end

  def injected(result)
    result.out.empty? ? nil : JSON.parse(result.out).dig("hookSpecificOutput", "additionalContext")
  end

  def test_inject_context_is_silent_without_rails_context
    write "app/models/CLAUDE.md", "# models\n"
    write "app/models/user.rb", "class User; end\n"
    commit
    result = tool_call("Bash", { "command" => "cat app/models/user.rb" })
    assert_equal 0, result.code
    assert_equal "", result.out
  end

  def test_inject_context_hands_over_the_chain_once_per_session
    context_app
    write "app/CLAUDE.md", "# app\n"
    write "app/models/concerns/CLAUDE.md", "# concerns\n"

    context = injected(tool_call("Bash", { "command" => %(sed -i '' 's/User/Person/' "app/models/user.rb" && echo done) }))
    assert_includes context, "Contents of #{@dir}/app/CLAUDE.md:\n\n# app"
    assert_includes context, "Contents of #{@dir}/app/models/CLAUDE.md:\n\n# models"
    refute_includes context, "# root", "the root file loads at session start"
    refute_includes context, "# concerns", "only ancestors of the touched path"
    assert_operator context.index("# app"), :<, context.index("# models"), "outermost first"

    assert_nil injected(tool_call("Bash", { "command" => "grep -n User app/models/user.rb:1" })), "once per session"
    refute_nil injected(tool_call("Bash", { "command" => "cat app/models/user.rb" }, session: "s2")), "a new session gets it again"

    log_event("compact", "s1")
    refute_nil injected(tool_call("Bash", { "command" => "cat app/models/user.rb" })), "and again after a compaction"
  end

  def test_inject_context_skips_files_that_already_reached_claude
    context_app
    log_event("start", "s1")
    log_event("load", "s1", "file_path" => path("app/models/CLAUDE.md"), "load_reason" => "nested_traversal")
    assert_nil injected(tool_call("Edit", { "file_path" => path("app/models/user.rb") }))

    # A context file read through the shell is logged as read, not handed over again.
    assert_nil injected(tool_call("Bash", { "command" => "cat app/services/AGENTS.md" }))
    assert_nil injected(tool_call("Bash", { "command" => "cat app/services/pay.rb" }))
    assert_includes File.read(path(".git/claude-context-log.jsonl")), %("s":"s1","e":"read","f":"app/services/CLAUDE.md")
  end

  def test_inject_context_finds_paths_from_every_tool
    context_app
    assert_includes injected(tool_call("Write", { "file_path" => path("app/services/refund.rb") }, session: "w")), "# services"
    assert_includes injected(tool_call("Grep", { "path" => "app/helpers" }, session: "g")), "# helpers"
    assert_includes injected(tool_call("Bash", { "command" => "cat > app/services/new.rb <<'RUBY'\nclass New; end\nRUBY" }, session: "h")),
                    "# services", "a new file in an existing directory"
    assert_includes injected(tool_call("Bash", { "command" => "cat user.rb" }, session: "c", cwd: path("app/models"))),
                    "# models", "paths relative to the shell's directory"
    assert_includes injected(tool_call("Bash", { "command" => "rg --glob=app/models/*.rb User" }, session: "f")), "# models"

    assert_nil injected(tool_call("Bash", { "command" => "echo hello world && git status" }, session: "n"))
    assert_nil injected(tool_call("Bash", { "command" => "cat README CLAUDE.md /etc/hosts" }, session: "n"))
    assert_nil injected(tool_call("Bash", { "command" => "cat user.rb" }, session: "n", cwd: path("app/services"))),
               "a missing file without a slash is just a word"
  end

  def test_context_report_counts_hook_hand_overs_as_reach
    context_app
    log_event("start", "s1")
    tool_call("Bash", { "command" => "sed -i '' 's/Pay/Payment/' app/services/pay.rb" })
    append "app/services/pay.rb", "# edit\n"
    log_event("stop", "s1")
    assert_match(%r{app/services/CLAUDE.md\s+1\s+1\s+0\s+hook 1}, report.out)
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
    assert_includes context, "in the same message"
  end

  def test_specialists_note_only_in_rails_apps_including_one_level_down
    assert_equal "", hook("rails-specialists", "delegation-context.sh").out
    write "api/config/application.rb", "module Api\n  class Application < Rails::Application\n  end\nend\n"
    context = JSON.parse(hook("rails-specialists", "delegation-context.sh").out).dig("hookSpecificOutput", "additionalContext")
    assert_includes context, "rails-specialists:rails-reviewer"
    assert_includes context, "in one message so they run in parallel"
    refute_includes context, "rails-tester", "test runs belong to rails-minitest now"
  end

  def test_minitest_note_only_in_rails_apps_tested_with_minitest
    write "config/application.rb", "class App < Rails::Application\nend\n"
    assert_equal "", hook("rails-minitest", "session-context.sh").out, "no test/test_helper.rb"
    write "test/test_helper.rb", "require \"rails/test_help\"\n"
    write "Gemfile", "gem \"rails\"\ngem \"rspec-rails\"\n"
    assert_equal "", hook("rails-minitest", "session-context.sh").out, "an RSpec app"
    write "Gemfile", "gem \"rails\"\n"
    context = JSON.parse(hook("rails-minitest", "session-context.sh").out).dig("hookSpecificOutput", "additionalContext")
    assert_includes context, "load the rails-minitest:rails-minitest skill"
    assert_includes context, "rails-minitest:rails-tester"
  end

  def test_minitest_note_finds_an_app_one_level_down
    write "web/config/application.rb", "module Web\n  class Application < Rails::Application\n  end\nend\n"
    write "web/test/test_helper.rb", "\n"
    assert_equal "SessionStart", JSON.parse(hook("rails-minitest", "session-context.sh").out).dig("hookSpecificOutput", "hookEventName")
  end
end
