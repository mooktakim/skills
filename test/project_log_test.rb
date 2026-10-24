# frozen_string_literal: true

require_relative "test_helper"

class ProjectLogTest < Minitest::Test
  include ScriptTestHelper

  PLUGIN = File.join(REPO, "project-log")
  TEMPLATE = File.join(PLUGIN, "templates/LOG.md")

  # The command is a Rust binary the plugin builds with cargo on first use.
  # The Ruby 2.6 CI container has no cargo, so these tests skip there, unless
  # REQUIRE_CARGO says cargo must be present.
  def self.cargo?
    @cargo = system("cargo", "--version", out: File::NULL, err: File::NULL) if @cargo.nil?
    @cargo
  end

  def setup
    super
    unless self.class.cargo?
      flunk "cargo is required: REQUIRE_CARGO is set" if ENV["REQUIRE_CARGO"]
      skip "cargo is not installed"
    end
    write "docs/LOG.md", File.read(TEMPLATE)
  end

  def log(*args, cwd: @dir, env: {})
    run_bash File.join(PLUGIN, "bin/project-log"), *args, cwd: cwd, env: env
  end

  def test_lint_is_clean_on_a_correct_log
    write "docs/log/2026/10/14/1792015200-billing.md", "# billing\n"
    write "docs/log/2026/10/15/1792022400-cache.md", "# cache\n"
    result = log("lint")
    assert_equal 0, result.code, result.out
    assert_equal "Log is clean: 2 entries.\n", result.out
  end

  def test_lint_checks_names_dates_legacy_logs_and_secrets
    write "docs/log/2026/10/14/1792015200-ok.md", "- ok\n"
    write "docs/log/2026/10/15/1792015200-wrong-day.md", "- x\n"
    write "docs/log/notes.md", "- x\n"
    write "docs/log/2026/10/14/1792015201-leak.md", "- set\n- token ghp_#{'a' * 36}\n"
    write "docs/history/2026-10-01/1790000000-old.md", "- old\n"
    write "docs/HISTORY.md", "## 2026-10-01\n- old\n"
    result = log("lint")
    assert_equal 1, result.code
    out = result.out
    assert_includes out, "docs/log/2026/10/15/1792015200-wrong-day.md: epoch 1792015200 is 2026/10/14 in UTC, not 2026/10/15"
    assert_includes out, "docs/log/notes.md: log entries are named log/YYYY/MM/DD/EPOCH-slug.md"
    assert_includes out, "docs/log/2026/10/14/1792015201-leak.md:2: looks like a GitHub token; remove it and rotate it"
    assert_includes out, "docs/history/ is a legacy log: migrate it with the project-log skill"
    assert_includes out, "docs/HISTORY.md is a legacy log: migrate it with the project-log skill"
    refute_includes out, "1792015200-ok.md"
    refute_includes out, "a" * 36, "the secret itself is never printed"
    assert_includes out, "5 problem(s)."
  end

  # The log never reads memory notes: a secret elsewhere in docs/ is
  # project-memory's to report, not the log's.
  def test_lint_looks_only_at_the_log
    write "docs/log/2026/10/14/1792015200-one.md", "- one\n"
    write "docs/inbox/leak.md", "token ghp_#{'a' * 36}\n"
    write "docs/conventions/x.md", "No frontmatter.\n"
    assert_equal "Log is clean: 1 entry.\n", log("lint").out
  end

  def test_without_a_protocol_file_or_with_a_bad_command
    File.delete(path("docs/LOG.md"))
    result = log("lint")
    assert_equal 1, result.code
    assert_includes result.err, "no docs/LOG.md here or above (up to the git root); set up the project log with the project-log skill"
    write "docs/LOG.md", File.read(TEMPLATE)
    assert_equal 2, log("frobnicate").code
    assert_equal "usage: project-log lint\n", log("--help").out
  end

  def test_finds_the_nearest_project_and_stops_at_the_git_root
    write "apps/web/docs/LOG.md", File.read(TEMPLATE)
    write "apps/web/docs/log/notes.md", "- x\n"
    write "apps/web/app/x.rb", "x\n"
    assert_includes log("lint", cwd: path("apps/web/app")).out, "docs/log/notes.md: log entries are named"
    assert_equal 0, log("lint", cwd: path("apps/web/app"), env: { "LOG_ROOT" => @dir }).code, "LOG_ROOT wins"
    FileUtils.mkdir_p(path("vendor/lib/.git"))
    outside = log("lint", cwd: path("vendor/lib"))
    assert_equal 1, outside.code
    assert_includes outside.err, "no docs/LOG.md here or above"
  end

  # Runs the composite action's shell steps the way GitHub Actions does,
  # leaving out the actions/cache step, so a cache miss builds the command.
  def test_the_github_action_builds_the_command_and_lints_the_project
    action = YAML.safe_load(File.read(File.join(PLUGIN, "action.yml")))
    steps = action.fetch("runs").fetch("steps")
    assert_equal "composite", action["runs"]["using"]
    assert_equal ["actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9"], steps.map { |step| step["uses"] }.compact
    temp = File.join(@dir, ".runner")
    output = File.join(temp, "output")
    FileUtils.mkdir_p(temp)
    env = { "GITHUB_ACTION_PATH" => PLUGIN, "RUNNER_TEMP" => temp, "GITHUB_OUTPUT" => output, "RUNNER_OS" => "Linux",
            "RUNNER_ARCH" => "X64", "CARGO_TARGET_DIR" => File.join(PLUGIN, "target") }
    write "docs/log/2026/10/14/1792015200-billing.md", "# billing\n"
    # Every step runs at the repository root: the default directory input is ".".
    results = steps.select { |step| step["run"] }.map do |step|
      out, err, status = Open3.capture3(env, "bash", "-e", "-c", step["run"], chdir: @dir)
      assert status.success?, "#{step['name']}: #{out}#{err}"
      out
    end
    assert_match(/\Akey=project-log-Linux-X64-[0-9a-f]{16}\n\z/, File.read(output))
    assert_includes results.last, "Log is clean: 1 entry."
  end

  # A plugin installs only its own directory, so project-log carries copies of
  # project-memory's date and scan code. They must not drift apart.
  def test_shared_sources_match_project_memory
    %w[date.rs scan.rs].each do |file|
      assert_equal File.read(File.join(REPO, "project-memory/src", file)), File.read(File.join(PLUGIN, "src", file)),
                   "project-log/src/#{file} differs from project-memory/src/#{file}: change both together"
    end
  end

  def test_rust_unit_tests_pass
    out, err, status = Open3.capture3({ "CARGO_TARGET_DIR" => File.join(PLUGIN, "target") }, "cargo", "test", "--quiet",
                                      "--manifest-path", File.join(PLUGIN, "Cargo.toml"))
    assert status.success?, "#{out}\n#{err}"
  end
end
