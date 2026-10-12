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

  def test_enforce_checks_view_files_a_shell_command_changed
    design_app
    bash = ->(command) { hook("rails-design-system", "enforce.sh", "--bash", stdin: JSON.generate("tool_input" => { "command" => command })) }
    assert_equal 0, bash.call("sed -i '' 's/ok/fine/' app/views/x/a.html.erb").code, "a clean change"
    append "app/views/x/a.html.erb", %(<p class="bg-red-600">edit</p>\n)
    result = bash.call("toolsmith-text-replace <<'EOF'\n@@ app/views/x/a.html.erb\n-a\n+b\nEOF")
    assert_equal 2, result.code
    assert_includes result.err, "app/views/x/a.html.erb:2:"
    assert_equal 2, bash.call("cd app/views/x && perl -pi -e 's/a/b/' a.html.erb").code, "named by file name"
    assert_equal 0, bash.call("git status && bin/rails test").code, "a command that names no changed view"
  end

  def test_block_names_only_the_rule_a_finding_breaks
    design_app
    write "docs/design-system/audit-rules", "Money with a currency prefix :: AED \\d\n"
    commit "rules"
    append "app/views/x/a.html.erb", %(<p class="text-primary">AED 5</p>\n)
    result = hook("rails-design-system", "enforce.sh", "--stop", stdin: "{}")
    assert_equal 2, result.code
    assert_includes result.err, "[rule: Money with a currency prefix]"
    refute_includes result.err, "Untagged lines"
  end

  # A Rails app inside a larger repository (rihlo/studio, runner/hub), with the
  # session opened at the repository top.
  def test_design_hooks_work_for_an_app_below_the_project
    write "web/docs/design-system/README.md", "# Design system\n"
    write "web/app/views/x/a.html.erb", %(<p class="bg-gray-100">old drift</p>\n)
    install "rails-design-system", "audit_design", "web/"
    write ".github/workflows/web.yml", "run: web/bin/audit_design --strict\n"
    commit "init"
    append "web/app/views/x/a.html.erb", %(<p class="bg-red-600">new</p>\n)

    stop = hook("rails-design-system", "enforce.sh", "--stop", stdin: "{}")
    assert_equal 2, stop.code, "a changed tracked file is checked"
    assert_includes stop.err, "app/views/x/a.html.erb:2:"
    refute_includes stop.err, ":1:", "committed drift is not reported as new"
    edit = hook("rails-design-system", "enforce.sh", "--hook", stdin: hook_json(path("web/app/views/x/a.html.erb")))
    assert_equal 2, edit.code
    refute_includes edit.err, ":1:"
    assert_equal 2, hook("rails-design-system", "enforce.sh", "--bash", stdin: JSON.generate("tool_input" => { "command" => "sed -i '' x web/app/views/x/a.html.erb" })).code
    refute_nil hook("rails-design-system", "reviewer-context.sh").out[/design-reviewer/]

    message = system_message(hook("rails-design-system", "maintenance-nudge.sh"))
    assert_includes message, "web/: bin/audit_design reports 2 finding(s)"
    refute_includes message, "not run in CI", "CI at the repository top counts"
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

  # A Rails app inside a larger repository (rihlo/studio, runner/hub), with the
  # session opened at the repository top.
  def test_context_hooks_report_and_audit_work_for_an_app_below_the_project
    write "CLAUDE.md", "# repo\n"
    install "rails-context", "audit_context", "web/"
    write "web/CLAUDE.md", "# web root\n"
    write "web/app/models/CLAUDE.md", "# models\n"
    File.symlink("CLAUDE.md", path("web/app/models/AGENTS.md"))
    write "web/app/models/user.rb", "class User; end\n"
    commit "init"

    log_event("start", "s1")
    context = injected(tool_call("Bash", { "command" => "sed -i '' 's/User/Person/' web/app/models/user.rb" }))
    assert_includes context, "Contents of #{@dir}/web/CLAUDE.md:\n\n# web root", "an app's root file does not load at session start"
    assert_includes context, "Contents of #{@dir}/web/app/models/CLAUDE.md:\n\n# models"
    refute_includes context, "# repo"
    append "web/app/models/user.rb", "# edit\n" # a tracked file, changed
    log_event("stop", "s1")
    log = File.read(path(".git/claude-context-log.jsonl"))
    assert_includes log, %("e":"inject","f":"web/app/models/CLAUDE.md")
    assert_includes log, %("e":"changed","files":["web/app/models/user.rb"])

    # A session opened inside the app logs the same repository-relative paths.
    hook("rails-context", "log-context.sh", "load", stdin: JSON.generate("session_id" => "s2", "file_path" => path("web/app/models/CLAUDE.md")),
                                                    env: { "CLAUDE_PROJECT_DIR" => path("web") })
    assert_includes File.read(path(".git/claude-context-log.jsonl")), %("s":"s2","e":"load","f":"web/app/models/CLAUDE.md")

    out, = Open3.capture3(ruby_bin, File.join(REPO, "rails-context/scripts/context_report"), chdir: path("web/app"))
    assert_includes out, "Context reach in web/ - 2 session(s)"
    assert_match(%r{^app/models/CLAUDE.md\s+1\s+2\s+0\s}, out)

    commit "work"
    audit, = Open3.capture3(ruby_bin, path("web/bin/audit_context"), chdir: @dir)
    assert_includes audit, "== app/models/CLAUDE.md"
    assert_includes audit, "     - app/models/user.rb"
    refute_includes audit, "web/app/models/user.rb"

    6.times { |i| write "web/app/helpers/h#{i}.rb", "module H#{i}; end\n" }
    commit "helpers"
    assert_includes system_message(hook("rails-context", "maintenance-nudge.sh")), "web/: 1 director(ies) may need a context file"
  end

  def test_context_report_counts_only_the_changes_a_session_touched
    context_app
    log_event("start", "s1")
    tool_call("Bash", { "command" => "sed -i '' 's/User/Person/' app/models/user.rb" })
    append "app/models/user.rb", "# edit\n"
    append "app/services/pay.rb", "# another session's uncommitted work\n"
    log_event("stop", "s1")
    out = report.out
    assert_match(%r{app/models/CLAUDE.md\s+1\s+1\s+0\s}, out)
    assert_match(%r{app/services/CLAUDE.md\s+0\s+0\s+0\s}, out, "not this session's change")
    tool_call("Bash", { "command" => "cat app/models/user.rb" })
    assert_equal 1, File.read(path(".git/claude-context-log.jsonl")).scan(%("e":"touch")).size, "a path is logged once per session"
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
    "stop using inline styles",
    "no, never push without asking"
  ].freeze

  NOT_CORRECTIONS = [
    "add a pagination component to the bids page",
    "Make the button blue",
    "what does this method do?",
    "/rails-context:rails-context",
    "<command-name>/capture:capture</command-name>",
    "<task-notification>\n<task-id>a8</task-id>\n<status>completed</status>\n<note>A task-notification fires each time this agent stops.</note>\n</task-notification>",
    "<local-command-stdout>you keep adding</local-command-stdout>",
    "nothing else, thanks",
    "no thats fine",
    "nope, leave it",
    "dont deploy yet",
    "don't merge it yet, I want to check"
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
    assert_includes context, "rails-minitest:minitest-runner"
    assert_includes context, "more than one test file, use toolsmith-check-run when it is on PATH"
    assert_includes context, "Run a single test file directly"
    assert_includes context, "Skip the run when only docs"
  end

  def test_view_component_note_only_in_rails_apps_that_use_view_component
    write "config/application.rb", "class App < Rails::Application\nend\n"
    write "Gemfile.lock", "GEM\n  specs:\n    rails (8.1.4)\n"
    assert_equal "", hook("rails-view-component", "session-context.sh").out, "no view_component"
    write "Gemfile.lock", "GEM\n  specs:\n    rails (8.1.4)\n    view_component (4.15.0)\n"
    context = JSON.parse(hook("rails-view-component", "session-context.sh").out).dig("hookSpecificOutput", "additionalContext")
    assert_includes context, "load the rails-view-component:rails-view-component skill"
    assert_includes context, "Turbo Streams or frames"
    assert_includes context, "rails-view-component:component-builder without being asked"
    assert_includes context, "needs the user's approval"
  end

  def test_view_component_note_finds_an_app_one_level_down_from_its_gemfile
    write "web/config/application.rb", "module Web\n  class Application < Rails::Application\n  end\nend\n"
    write "web/Gemfile", "gem 'rails'\ngem \"view_component\", \"~> 4.15\"\n"
    assert_equal "SessionStart", JSON.parse(hook("rails-view-component", "session-context.sh").out).dig("hookSpecificOutput", "hookEventName")
  end

  def test_hotwire_note_only_in_rails_apps_that_use_hotwire
    write "config/application.rb", "class App < Rails::Application\nend\n"
    write "Gemfile.lock", "GEM\n  specs:\n    rails (8.1.4)\n"
    assert_equal "", hook("rails-hotwire", "session-context.sh").out, "no turbo-rails or stimulus-rails"
    write "Gemfile.lock", "GEM\n  specs:\n    rails (8.1.4)\n    stimulus-rails (1.3.4)\n"
    context = JSON.parse(hook("rails-hotwire", "session-context.sh").out).dig("hookSpecificOutput", "additionalContext")
    assert_includes context, "load the rails-hotwire:rails-hotwire skill"
    assert_includes context, "does nothing or misbehaves"
    assert_includes context, "rails-hotwire:hotwire-builder without being asked"
    assert_includes context, "needs the user's approval"
  end

  def test_hotwire_note_finds_an_app_one_level_down_from_its_gemfile
    write "web/config/application.rb", "module Web\n  class Application < Rails::Application\n  end\nend\n"
    write "web/Gemfile", "gem 'rails'\ngem \"turbo-rails\"\n"
    assert_equal "SessionStart", JSON.parse(hook("rails-hotwire", "session-context.sh").out).dig("hookSpecificOutput", "hookEventName")
  end

  def test_minitest_note_finds_an_app_one_level_down
    write "web/config/application.rb", "module Web\n  class Application < Rails::Application\n  end\nend\n"
    write "web/test/test_helper.rb", "\n"
    assert_equal "SessionStart", JSON.parse(hook("rails-minitest", "session-context.sh").out).dig("hookSpecificOutput", "hookEventName")
  end

  # -- the first-touch notes ------------------------------------------------

  FIRST_TOUCH = {
    "rails-view-component" => ["Write", { "file_path" => "/app/app/components/card_component.rb" }],
    "rails-hotwire" => ["Bash", { "command" => "cat > app/javascript/controllers/tabs_controller.js <<'JS'\nJS" }],
    "rails-minitest" => ["Edit", { "file_path" => "/app/test/models/user_test.rb" }],
    "rails-generators" => ["Bash", { "command" => "bin/rails generate migration AddSlugToPosts slug:string" }]
  }.freeze

  def test_first_touch_notes_once_per_session_and_never_in_subagents
    FIRST_TOUCH.each do |plugin, (tool, tool_input)|
      assert_equal "", hook(plugin, "first-touch.sh", stdin: JSON.generate("session_id" => "#{plugin}-none", "tool_name" => tool, "tool_input" => tool_input)).out,
                   "#{plugin}: silent outside a Rails app"
    end
    write "web/config/application.rb", "class App < Rails::Application\nend\n"
    FIRST_TOUCH.each do |plugin, (tool, tool_input)|
      note = lambda do |session, extra = {}|
        # Each plugin has its own data directory in Claude Code; here they share one.
        out = hook(plugin, "first-touch.sh", stdin: JSON.generate({ "session_id" => "#{plugin}-#{session}", "tool_name" => tool, "tool_input" => tool_input }.merge(extra))).out
        out.empty? ? nil : JSON.parse(out).dig("hookSpecificOutput", "additionalContext")
      end
      assert_includes note.call("s1").to_s, "#{plugin}:#{plugin}", plugin
      assert_nil note.call("s1"), "#{plugin}: once per session"
      refute_nil note.call("s2"), "#{plugin}: a new session"
      assert_nil note.call("s3", "agent_id" => "a1"), "#{plugin}: not in a subagent"
      other = hook(plugin, "first-touch.sh", stdin: JSON.generate("session_id" => "s4", "tool_name" => "Bash", "tool_input" => { "command" => "git status" }))
      assert_equal ["", 0], [other.out, other.code], "#{plugin}: other work"
    end
  end

  # -- rails-generators -------------------------------------------------------

  def test_generators_note_only_in_rails_apps_including_one_level_down
    assert_equal "", hook("rails-generators", "session-context.sh").out
    write "web/config/application.rb", "module Web\n  class Application < Rails::Application\n  end\nend\n"
    context = JSON.parse(hook("rails-generators", "session-context.sh").out).dig("hookSpecificOutput", "additionalContext")
    assert_includes context, "`bin/rails generate migration`"
    assert_includes context, "never hand-pick a migration timestamp"
    assert_includes context, "Load the rails-generators:rails-generators skill"
  end

  def rails_app(prefix = "")
    write "#{prefix}bin/rails", "#!/usr/bin/env ruby\n"
    write "#{prefix}config/application.rb", "class App < Rails::Application\nend\n"
    write "#{prefix}db/schema.rb", "ActiveRecord::Schema[8.1].define(version: 2026_09_30_160000) do\nend\n"
    write "#{prefix}db/migrate/20260930160000_add_name_to_users.rb", "class AddNameToUsers < ActiveRecord::Migration[8.1]\nend\n"
  end

  def guard(tool, tool_input)
    stdin = JSON.generate("tool_name" => tool, "cwd" => @dir, "tool_input" => tool_input)
    out = hook("rails-generators", "guard.sh", stdin: stdin).out
    out.empty? ? {} : JSON.parse(out).fetch("hookSpecificOutput")
  end

  def refused(tool, tool_input)
    decision = guard(tool, tool_input)
    decision["permissionDecision"] == "deny" ? decision["permissionDecisionReason"] : nil
  end

  def test_guard_refuses_a_hand_written_migration_and_allows_editing_a_generated_one
    rails_app
    reason = refused("Write", "file_path" => path("db/migrate/20261009120000_create_posts.rb"))
    assert_includes reason, "`bin/rails generate migration AddPublishedAtToPosts published_at:datetime:index`"
    assert_includes refused("Write", "file_path" => path("db/queue_migrate/20261009120000_x.rb")), "published_at:datetime:index --database queue`"
    write "db/migrate/20261009120001_create_posts.rb", "class CreatePosts < ActiveRecord::Migration[8.1]\nend\n"
    assert_equal({}, guard("Write", "file_path" => path("db/migrate/20261009120001_create_posts.rb")), "generated and not yet run")
  end

  def test_guard_notes_an_edit_to_a_migration_that_has_already_run
    rails_app
    ["perl -0pi -e 's/end/x/' db/migrate/*_add_name_to_users.rb", "sed -i '' 's/a/b/' db/migrate/20260930160000_add_name_to_users.rb"].each do |command|
      shell = guard("Bash", "command" => command)
      assert_nil shell["permissionDecision"], command
      assert_includes shell["additionalContext"].to_s, "`bin/rails db:migrate:down VERSION=20260930160000`", command
    end
    assert_equal({}, guard("Bash", "command" => "cat db/migrate/*_add_name_to_users.rb"), "a read")
    decision = guard("Edit", "file_path" => path("db/migrate/20260930160000_add_name_to_users.rb"))
    assert_nil decision["permissionDecision"]
    assert_includes decision["additionalContext"], "`bin/rails db:migrate:down VERSION=20260930160000`"
    FileUtils.rm(path("db/schema.rb"))
    write "db/structure.sql", "INSERT INTO \"schema_migrations\" (version) VALUES\n('20260930160000');\n"
    assert_includes guard("Edit", "file_path" => path("db/migrate/20260930160000_add_name_to_users.rb"))["additionalContext"], "has already run"
    write "db/structure.sql", "\n"
    assert_equal({}, guard("Edit", "file_path" => path("db/migrate/20260930160000_add_name_to_users.rb")))
  end

  def test_guard_refuses_edits_to_schema_dumps_credentials_and_the_lockfile
    rails_app
    assert_includes refused("Edit", "file_path" => path("db/schema.rb")), "`git checkout <base> -- db/schema.rb`"
    assert_includes refused("Write", "file_path" => path("db/queue_schema.rb")), "queue_schema.rb is generated"
    assert_includes refused("Edit", "file_path" => path("db/structure.sql")), "structure.sql is generated"
    assert_includes refused("Write", "file_path" => path("config/credentials/production.yml.enc")), "`bin/rails credentials:edit`"
    assert_includes refused("Edit", "file_path" => path("Gemfile.lock")), "`bundle update NAME --conservative`"
    assert_equal({}, guard("Edit", "file_path" => path("db/seeds.rb")))
    assert_equal({}, guard("Edit", "file_path" => path("Gemfile")))
  end

  def test_guard_refuses_shell_writes_and_allows_shell_reads
    rails_app
    {
      "cat > db/migrate/20261009120000_create_posts.rb <<'EOF'\nclass CreatePosts\nEOF" => "Do not write a migration file by hand",
      "sed -i '' 's/a/b/' db/schema.rb" => "schema.rb is generated",
      "bundle exec rails runner 1 && echo x | tee -a Gemfile.lock" => "Bundler writes Gemfile.lock",
      "toolsmith-text-replace <<'EOF'\n@@ db/schema.rb\n-a\n+b\nEOF" => "schema.rb is generated",
      "cp ../other/db/migrate/20250101000000_x.rb db/migrate/20261009120000_x.rb" => "Do not write a migration file by hand"
    }.each do |command, message|
      assert_includes refused("Bash", "command" => command).to_s, message, command
    end
    [
      "cat db/schema.rb | head",
      "git checkout main -- db/schema.rb && bin/rails db:migrate",
      "bin/rails generate migration AddTitleToPosts title:string > /dev/null",
      "cat > db/migrate/20260930160000_add_name_to_users.rb <<'EOF'\nclass AddNameToUsers\nEOF",
      "ls db/migrate"
    ].each { |command| assert_nil refused("Bash", "command" => command), command }
  end

  # Only the files a toolsmith spec names in its headers are written; heredoc
  # content and the command's other parts are not.
  def test_guard_reads_toolsmith_targets_from_spec_headers_only
    rails_app
    {
      "toolsmith-files-write <<'EOF'\n=== db/migrate/20261009120000_create_posts.rb\nclass CreatePosts\nEOF" => "Do not write a migration file by hand",
      "toolsmith-files-write --marker '###' <<'EOF'\n### config/master.yml.enc\nx\nEOF" => "`bin/rails credentials:edit`",
      "cd . && toolsmith-text-replace <<EOF\n@@ app/a.rb\n-a\n+b\n@@ Gemfile.lock --all\n-a\n+b\nEOF" => "Bundler writes Gemfile.lock",
      "grep -c x <<< EOF\necho $((1<<2))\necho x > db/schema.rb\nEOF" => "schema.rb is generated"
    }.each do |command, message|
      assert_includes refused("Bash", "command" => command).to_s, message, command
    end
    [
      "grep -n ' view_component (' Gemfile.lock; toolsmith-text-replace <<'EOF'\n@@ app/a.rb\n-a\n+b\nEOF",
      "toolsmith-text-replace <<'EOF'\n@@ app/a.rb\n-a\n+b\nEOF\nbin/rails db:migrate && git diff --stat db/schema.rb",
      "toolsmith-text-replace <<'EOF'\n@@ config/environments/production.rb\n-a\n+# The master key unlocks config/credentials.yml.enc on the server\nEOF",
      "toolsmith-files-write <<'EOF'\n=== docs/notes.md\nNever run `echo x > db/schema.rb` or edit Gemfile.lock.\nEOF",
      "cat > docs/notes.md <<-EOF\n\techo x > db/schema.rb\n\tEOF\nls"
    ].each { |command| assert_nil refused("Bash", "command" => command), command }
  end

  def test_guard_finds_an_app_one_level_down_and_is_silent_outside_rails
    write "db/migrate/20261009120000_x.rb.keep", ""
    assert_equal({}, guard("Write", "file_path" => path("db/migrate/20261009120000_create_posts.rb")), "no bin/rails")
    assert_equal({}, guard("Edit", "file_path" => path("Gemfile.lock")))
    rails_app("api/")
    reason = refused("Bash", "command" => "echo x > api/db/migrate/20261009120000_create_posts.rb")
    assert_includes reason, "(run it in #{path('api')})"
    assert_equal "", hook("rails-generators", "guard.sh", stdin: JSON.generate("tool_name" => "Read", "tool_input" => { "file_path" => path("app/models/user.rb") })).out
  end
end
