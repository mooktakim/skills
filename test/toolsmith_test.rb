# frozen_string_literal: true

require_relative "test_helper"

# The toolsmith plugin. Every tool is held to the contract in
# toolsmith/references/contract.md: a complete manifest, a guide that covers
# every section, and examples that run against the real binary (built through
# the bin/ shim) and must change exactly the files they say. The hooks and the
# history analysis run the way Claude Code and the skill run them.
#
# Tests that need a built tool skip without cargo, unless REQUIRE_CARGO is set,
# as it is in CI.
class ToolsmithTest < Minitest::Test
  include ScriptTestHelper

  PLUGIN = File.join(REPO, "toolsmith")
  NAME = /\Atoolsmith-[a-z]+(-[a-z]+)*\z/.freeze
  REQUIRED = %w[name intent usage use_when not_for input options output exit_codes examples family mode added].freeze
  SECTIONS = ["Use it when", "Do not use it for", "Input", "Options", "Output", "Exit codes", "Examples"].freeze
  SHIM_LINE = %(exec "$(dirname "${BASH_SOURCE[0]}")/../libexec/shim" %s "$@"\n)
  EXAMPLE_KEYS = %w[title situation setup fake_commands git files cwd args stdin exit stdout stdout_regex stdout_sample
                    stderr stderr_regex stderr_sample files_after staged].freeze

  def setup
    super
    @state = File.realpath(Dir.mktmpdir("toolsmith-state"))
    @log = File.join(@state, "usage.jsonl")
  end

  def teardown
    super
    FileUtils.rm_rf(@state)
  end

  def manifests
    Dir.glob(File.join(PLUGIN, "crates/*/tool.json")).sort.map { |file| JSON.parse(File.read(file)) }
  end

  def family_ids
    JSON.parse(File.read(File.join(PLUGIN, "families.json"))).fetch("families").map { |f| f["id"] }
  end

  def cargo?
    system("command -v cargo >/dev/null 2>&1")
  end

  def family_matches?(id, command)
    family = JSON.parse(File.read(File.join(PLUGIN, "families.json"))).fetch("families").find { |f| f["id"] == id }
    family.fetch("rules").any? { |rule| rule.all? { |re| Regexp.new(re).match?(command) } }
  end

  # A family counts, and reminds of its tool for, only the job the tool does.
  FAMILY_CASES = {
    "ci-wait" => {
      "gh run watch 123 --exit-status" => true,
      "gh pr checks 228 --watch --fail-fast" => true,
      "until gh pr checks 5 | grep -qv pending; do sleep 20; done" => true,
      "gh run view 400 --log-failed | tail -50" => true,
      "gh run view 40063031171 --repo x --json status,conclusion,jobs --jq ." => false,
      "gh pr checks 228 -R mooktakim/oasis-kids | head -3" => false,
      "gh run view 40 --log | grep error" => false
    },
    "literal-replace" => {
      "sed -i '' 's/ok/fine/' app/a.html.erb" => true,
      "sed -i '' 's/\\.nvmrc/.tool-versions/g' $files" => true,
      "perl -pi -e 's/foo/bar/g' x.rb" => true,
      "python3 - <<'PY'\np='a'; s=open(p).read(); open(p,'w').write(s.replace('a','b'))\nPY" => true,
      "ruby -e 'File.write(f, File.read(f).sub(\"a\", \"b\"))'" => true,
      "sed -i '' 's/^nodejs 24.2.0$/nodejs 24.22.0/' ~/.tool-versions" => false,
      "sed -i '' 's/reads .tool-versions (nvm)/x/' f" => false,
      "perl -0pi -e 's/end\\n(\\s+)def/x/' a.rb" => false,
      "python3 -c \"import re; open('a','w').write(re.sub(r'x+','y',s))\"" => false,
      "ruby -e 'File.write(f, File.read(f).gsub(/a+/, \"b\"))'" => false,
      "sed -n 5,9p x.rb" => false
    }
  }.freeze

  def test_families_match_only_the_job_their_tool_does
    FAMILY_CASES.each do |id, cases|
      cases.each { |command, want| assert_equal want, family_matches?(id, command), "#{id}: #{command}" }
    end
  end

  def need_cargo
    return if cargo?
    flunk "cargo is required: REQUIRE_CARGO is set" if ENV["REQUIRE_CARGO"]

    skip "cargo is not installed"
  end

  def run_tool(name, *args, stdin: "", cwd: @dir, env: {})
    run_bash File.join(PLUGIN, "bin", name), *args, stdin: stdin, cwd: cwd, env: { "TOOLSMITH_LOG" => @log }.merge(env)
  end

  def log_events
    File.exist?(@log) ? File.readlines(@log).map { |line| JSON.parse(line) } : []
  end

  # Every file under dir except .git, as relative path => content.
  def tree(dir)
    Dir.glob(File.join(dir, "**/*"), File::FNM_DOTMATCH).reject { |f| File.directory?(f) || f.include?("/.git/") }
       .map { |f| [f.sub("#{dir}/", ""), File.read(f)] }.to_h
  end

  # Expected files with glob keys resolved to the one file each must match.
  def resolve(dir, files)
    files.map do |pattern, content|
      found = pattern.include?("*") ? Dir.glob(File.join(dir, pattern)).map { |f| f.sub("#{dir}/", "") } : [pattern]
      assert_equal 1, found.size, "#{pattern} should match exactly one file, matched #{found.inspect}"
      [found.first, content]
    end.to_h
  end

  # -- the contract, checked on every manifest ------------------------------

  def test_every_tool_crate_has_a_complete_manifest
    crates = Dir.glob(File.join(PLUGIN, "crates/*")).map { |d| File.basename(d) }.sort - ["common"]
    refute_empty crates
    crates.each { |crate| assert File.file?(File.join(PLUGIN, "crates", crate, "tool.json")), "crates/#{crate} needs a tool.json" }
    families = family_ids
    owners = Hash.new(0)
    manifests.each do |m|
      name = m["name"]
      REQUIRED.each { |key| assert m.key?(key), "#{name}: tool.json needs #{key}" }
      assert_match NAME, name
      assert File.file?(File.join(PLUGIN, "crates", name.sub("toolsmith-", ""), "tool.json")), "#{name}: crate directory must be the name without toolsmith-"
      intent = m["intent"]
      assert intent.end_with?("."), "#{name}: the intent is one sentence ending with a full stop"
      assert_equal 1, intent.scan(/[.!?](\s|\z)/).size, "#{name}: the intent is one sentence"
      refute_match(/ (and|or) /, intent, "#{name}: one intent - no 'and' or 'or'")
      assert_operator intent.length, :<=, 100, "#{name}: keep the intent under 100 characters"
      assert m["usage"].start_with?(name), "#{name}: usage starts with the command"
      %w[use_when not_for].each do |key|
        refute_empty m[key], "#{name}: #{key} lists at least one case"
        assert m[key].all? { |item| item.is_a?(String) && !item.strip.empty? }
      end
      %w[input output].each { |key| refute_empty m[key].to_s.strip, "#{name}: #{key} is described" }
      m["options"].each { |option| assert option["flag"].to_s.start_with?("--") && !option["text"].to_s.empty?, "#{name}: option #{option}" }
      codes = m["exit_codes"].map { |c| c["code"] }
      assert_equal [0, 1, 2], codes.first(3), "#{name}: exit codes 0, 1 and 2 are documented, in order"
      assert family_ids.include?(m["family"]), "#{name}: family #{m['family']} is not in families.json" if families
      owners[m["family"]] += 1
      assert_includes %w[remind block], m["mode"]
      assert_match(/\A\d{4}-\d{2}-\d{2}\z/, m["added"])
      check_examples(name, m["examples"])
    end
    owners.each { |family, n| assert_equal 1, n, "family #{family} has more than one tool" }
  end

  def check_examples(name, examples)
    assert_operator examples.size, :>=, 2, "#{name}: at least two examples"
    assert examples.any? { |e| e["exit"].to_i.zero? }, "#{name}: an example of success"
    assert examples.any? { |e| e["exit"].to_i != 0 }, "#{name}: an example of a failure"
    examples.each do |e|
      refute_empty e["title"].to_s
      assert_empty e.keys - EXAMPLE_KEYS, "#{name}: '#{e['title']}' has unknown keys"
      refute_empty e["situation"].to_s, "#{name}: '#{e['title']}' has a setup or fake commands, so its situation explains them" if e["setup"] || e["fake_commands"]
      assert e.key?("exit"), "#{name}: '#{e['title']}' gives its exit code"
      assert e.key?("stdout") || e.key?("stdout_regex"), "#{name}: '#{e['title']}' gives its output"
      %w[stdout stderr].each do |stream|
        next unless e["#{stream}_regex"]

        assert_match Regexp.new(e["#{stream}_regex"]), e["#{stream}_sample"].to_s, "#{name}: '#{e['title']}' #{stream}_sample must match #{stream}_regex"
      end
      refute_match(/^EOF$/, e["stdin"].to_s, "#{name}: '#{e['title']}' stdin cannot hold a line EOF, the guide's heredoc end")
    end
  end

  def test_bin_has_one_shim_per_tool_and_nothing_else
    names = manifests.map { |m| m["name"] }.sort
    assert_equal names, Dir.children(File.join(PLUGIN, "bin")).sort
    names.each do |name|
      file = File.join(PLUGIN, "bin", name)
      assert File.executable?(file), "bin/#{name} must be executable"
      assert_equal "#!/usr/bin/env bash\n#{format(SHIM_LINE, name)}", File.read(file)
    end
    assert File.executable?(File.join(PLUGIN, "libexec/shim"))
    _out, err, status = Open3.capture3(bash_bin, "-n", File.join(PLUGIN, "libexec/shim"))
    assert status.success?, err
  end

  # -- the tools, run through the shim --------------------------------------

  def test_every_example_does_what_its_guide_says
    need_cargo
    manifests.each do |m|
      m["examples"].each { |example| run_example(m["name"], example) }
    end
  end

  def run_example(name, example)
    label = "#{name}: '#{example['title']}'"
    dir = File.realpath(Dir.mktmpdir("toolsmith-example"))
    if example["git"]
      Open3.capture3("git", "init", "-q", dir)
      Open3.capture3("git", "-C", dir, "config", "user.email", "test@example.com")
    end
    if example["setup"]
      out, status = Open3.capture2e(bash_bin, "-c", example["setup"], chdir: dir)
      assert status.success?, "#{label} setup failed: #{out}"
    end
    (example["files"] || {}).each do |rel, content|
      FileUtils.mkdir_p(File.dirname(File.join(dir, rel)))
      File.write(File.join(dir, rel), content)
    end
    before = tree(dir)
    fakes = Dir.mktmpdir("fakes", @state)
    (example["fake_commands"] || {}).each do |command, script|
      File.write(File.join(fakes, command), script)
      File.chmod(0o755, File.join(fakes, command))
    end
    cwd = File.join(dir, example["cwd"] || ".")
    env = { "PATH" => "#{fakes}:#{ENV['PATH']}", "TMPDIR" => @state }
    result = run_tool(name, *example["args"], stdin: example["stdin"].to_s, cwd: cwd, env: env)
    assert_equal example["exit"], result.code, "#{label} exit code; stderr: #{result.err}"
    if example["stdout_regex"]
      assert_match Regexp.new(example["stdout_regex"]), result.out, label
    else
      assert_equal example["stdout"], result.out, label
    end
    assert_equal example["stderr"], result.err, label if example.key?("stderr")
    assert_match Regexp.new(example["stderr_regex"]), result.err, label if example.key?("stderr_regex")
    expected = example["files_after"] ? resolve(dir, example["files_after"]) : before
    assert_equal expected, tree(dir), "#{label} must change exactly the files it says"
    (example["staged"] || []).each do |pattern|
      staged, = Open3.capture3("git", "-C", dir, "diff", "--cached", "--name-only")
      assert_equal 1, staged.lines.count { |line| File.fnmatch(pattern, line.chomp) }, "#{label} stages #{pattern}"
    end
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_guides_cover_every_section_and_example
    need_cargo
    manifests.each do |m|
      name = m["name"]
      guide = run_tool(name, "--llm")
      assert_equal 0, guide.code, guide.err
      SECTIONS.each { |section| assert_includes guide.out, "\n## #{section}\n", "#{name} --llm" }
      assert_includes guide.out, "Purpose: #{m['intent']}"
      (m["use_when"] + m["not_for"]).each { |item| assert_includes guide.out, item }
      m["examples"].each do |e|
        assert_includes guide.out, e["title"]
        assert_includes guide.out, (e["stdout"] || e["stdout_sample"]) unless (e["stdout"] || e["stdout_sample"]).to_s.empty?
      end
      help = run_tool(name, "--help")
      assert_equal 0, help.code
      assert help.out.start_with?("#{name} - #{m['intent']}\n")
      assert_includes help.out, "#{name} --llm"
      assert_operator help.out.lines.size, :<=, 25, "#{name} --help stays short"
      assert_equal help.out, run_tool(name, "-h").out
    end
  end

  def test_unknown_options_are_usage_errors
    need_cargo
    manifests.each do |m|
      result = run_tool(m["name"], "--no-such-option", stdin: "x\n")
      assert_equal 2, result.code, m["name"]
      assert_includes result.err, "#{m['name']} --help"
      assert_empty result.out
    end
  end

  def test_runs_are_logged_without_their_input
    need_cargo
    write "a.txt", "secret-value\n"
    run_tool("toolsmith-text-replace", stdin: "@@ a.txt\n-secret-value\n+other\n")
    run_tool("toolsmith-text-replace", "--llm")
    events = log_events
    assert_equal [%w[run 0], %w[llm 0]], events.map { |e| [e["mode"], e["exit"].to_s] }
    assert events.all? { |e| e["tool"] == "toolsmith-text-replace" && e["event"] == "run" && e["cwd"] == @dir }
    refute_includes File.read(@log), "secret-value"
    run_tool("toolsmith-text-replace", "--help", env: { "TOOLSMITH_LOG" => "" })
    assert_equal 2, log_events.size, "an empty TOOLSMITH_LOG turns logging off"
  end

  def test_text_replace_keeps_permissions_and_symlinks
    need_cargo
    write "bin/run", "echo old\n"
    File.chmod(0o755, path("bin/run"))
    File.symlink("bin/run", path("run"))
    result = run_tool("toolsmith-text-replace", stdin: "@@ run\n-old\n+new\n")
    assert_equal 0, result.code, result.err
    assert_equal "echo new\n", File.read(path("bin/run"))
    assert File.symlink?(path("run"))
    assert_equal 0o755, File.stat(path("bin/run")).mode & 0o777
    assert_equal ["run"], Dir.children(path("bin")), "no temporary file is left behind"
  end

  def test_text_replace_applies_edits_in_order_and_writes_nothing_on_any_failure
    need_cargo
    write "a.txt", "one\n"
    write "b.txt", "keep\n"
    chained = run_tool("toolsmith-text-replace", stdin: "@@ a.txt\n-one\n+two\n\n@@ ./a.txt\n-two\n+three\n")
    assert_equal 0, chained.code, chained.err
    assert_equal "three\n", File.read(path("a.txt"))
    missing = run_tool("toolsmith-text-replace", stdin: "@@ b.txt\n-keep\n+gone\n\n@@ nope.txt\n-x\n+y\n")
    assert_equal 1, missing.code
    assert_includes missing.err, "nope.txt (spec line 5): cannot read the file"
    assert_equal "keep\n", File.read(path("b.txt"))
    later = run_tool("toolsmith-text-replace", stdin: "@@ b.txt\n-absent\n+x\n-keep\n+y\n")
    assert_includes later.err, "1 later edits in a file with a failed edit were not checked."
    bad = run_tool("toolsmith-text-replace", stdin: "@@ b.txt\nkeep\n")
    assert_equal 2, bad.code
    assert_includes bad.err, "bad spec: line 2: every line must start with '@@', '-' or '+'"
  end

  def test_history_add_never_overwrites_an_entry
    need_cargo
    assert_equal 0, run_tool("toolsmith-history-add", "--help").code, "build first, so the build time cannot pass the entries below"
    write "docs/MEMORY.md", "# Memory Protocol\n"
    now = Time.now.to_i
    (now..now + 60).each { |epoch| write "docs/log/#{Time.at(epoch).utc.strftime('%Y/%m/%d')}/#{epoch}-same-title.md", "- First.\n" }
    before = tree(@dir)
    result = run_tool("toolsmith-history-add", "Same title", stdin: "- Second.\n")
    assert_equal 1, result.code, result.out
    assert_match(%r{already exists, and history entries are never overwritten}, result.err)
    assert_equal before, tree(@dir)
  end

  def test_rust_unit_tests_pass
    need_cargo
    out, err, status = Open3.capture3({ "CARGO_TARGET_DIR" => File.join(PLUGIN, "target") }, "cargo", "test", "--workspace", "--quiet",
                                      "--manifest-path", File.join(PLUGIN, "Cargo.toml"))
    assert status.success?, "#{out}\n#{err}"
  end

  def test_shim_builds_a_missing_or_stale_binary_and_explains_a_missing_cargo
    need_cargo
    target = File.join(@state, "target")
    env = { "TOOLSMITH_TARGET_DIR" => target }
    assert_equal 0, run_tool("toolsmith-history-add", "--help", env: env).code
    binary = File.join(target, "release/toolsmith-history-add")
    assert File.executable?(binary)
    File.utime(Time.at(0), Time.at(0), binary)
    assert_equal 0, run_tool("toolsmith-history-add", "--help", env: env).code
    assert_operator File.mtime(binary), :>, Time.at(0), "a binary older than its source is rebuilt"
    FileUtils.rm_rf(target)
    no_cargo = run_tool("toolsmith-history-add", "--help", env: env.merge("PATH" => "/usr/bin:/bin"))
    assert_equal 127, no_cargo.code
    assert_includes no_cargo.err, "cargo is not installed"
    unknown = run_bash File.join(PLUGIN, "libexec/shim"), "toolsmith-no-such-tool"
    assert_equal 127, unknown.code
    assert_includes unknown.err, "there is no tool named toolsmith-no-such-tool"
  end

  # -- the hooks ------------------------------------------------------------

  # A plugin root with the real manifests and families, and a chosen scan date.
  def fake_root(last_scan: Time.now.strftime("%Y-%m-%d"), mode: nil)
    root = Dir.mktmpdir("root", @state)
    FileUtils.mkdir_p(File.join(root, "metrics"))
    FileUtils.cp(File.join(PLUGIN, "families.json"), root)
    manifests.each do |m|
      dir = File.join(root, "crates", m["name"].sub("toolsmith-", ""))
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "tool.json"), JSON.generate(mode ? m.merge("mode" => mode) : m))
    end
    File.write(File.join(root, "metrics/weekly.json"), JSON.generate("last_scan" => last_scan, "weeks" => {})) if last_scan
    root
  end

  def hook(script, stdin: "", env: {})
    env = { "TOOLSMITH_ROOT" => fake_root }.merge(env) unless env.key?("TOOLSMITH_ROOT")
    run_bash File.join(PLUGIN, "hooks", script), stdin: stdin, env: { "TOOLSMITH_LOG" => @log }.merge(env)
  end

  def bash_event(command, **fields)
    JSON.generate({ "tool_name" => "Bash", "tool_input" => { "command" => command }, "cwd" => @dir }.merge(fields.transform_keys(&:to_s)))
  end

  def reminded(command, **fields)
    out = hook("pre-bash.sh", stdin: bash_event(command, **fields)).out
    out.empty? ? nil : JSON.parse(out).dig("hookSpecificOutput", "additionalContext")
  end

  def test_session_start_lists_every_tool_and_a_due_scan
    result = hook("session-start.sh")
    assert_equal 0, result.code
    manifests.each { |m| assert_includes result.out, "- #{m['name']}: #{m['intent']}" }
    assert_includes result.out, "run `<command> --llm` once in a session"
    refute_includes result.out, "scan"
    stale = hook("session-start.sh", env: { "TOOLSMITH_ROOT" => fake_root(last_scan: (Time.now - 10 * 86_400).strftime("%Y-%m-%d")) })
    assert_includes stale.out, "was 10 days ago"
    never = hook("session-start.sh", env: { "TOOLSMITH_ROOT" => fake_root(last_scan: nil).tap { |r| FileUtils.rm_f(File.join(r, "metrics/weekly.json")) } })
    assert_includes never.out, "has not been scanned for new tool ideas yet"
  end

  def test_session_start_leaves_out_a_tool_another_command_shadows
    shadow = File.join(@state, "shadow")
    FileUtils.mkdir_p(shadow)
    File.write(File.join(shadow, "toolsmith-text-replace"), "#!/bin/sh\n")
    File.chmod(0o755, File.join(shadow, "toolsmith-text-replace"))
    other_copy = File.join(@state, "other-version/bin")
    FileUtils.mkdir_p(other_copy)
    FileUtils.cp(File.join(PLUGIN, "bin/toolsmith-history-add"), other_copy)
    result = hook("session-start.sh", env: { "PATH" => "#{shadow}:#{other_copy}:#{File.join(PLUGIN, 'bin')}:#{ENV['PATH']}" })
    assert_includes result.out, "toolsmith-text-replace is not available: #{shadow}/toolsmith-text-replace has the same name"
    refute_includes result.out, "- toolsmith-text-replace:"
    assert_includes result.out, "- toolsmith-history-add:", "another toolsmith copy's shim is not a clash"
  end

  def test_pre_bash_reminds_only_on_a_matching_command
    script = "python3 - <<'EOF'\np='a.rb'; s=open(p).read()\ns=s.replace('a','b')\nopen(p,'w').write(s)\nEOF"
    result = hook("pre-bash.sh", stdin: bash_event(script))
    assert_equal 0, result.code
    output = JSON.parse(result.out).fetch("hookSpecificOutput")
    assert_equal "PreToolUse", output["hookEventName"]
    assert_includes output["additionalContext"], "`toolsmith-text-replace` exists for that"
    refute output.key?("permissionDecision"), "remind mode never blocks"
    assert_equal [["nudge", "toolsmith-text-replace", @dir]], log_events.map { |e| [e["event"], e["tool"], e["cwd"]] }
    history = hook("pre-bash.sh", stdin: bash_event(%(f="docs/history/$(date +%F)/$(date +%s)-x.md"; mkdir -p "$(dirname "$f")"; cat > "$f" <<'EOF'\n- x\nEOF)))
    assert_includes history.out, "toolsmith-history-add"
    ["ls -la", "toolsmith-text-replace <<'EOF'\n@@ a\n-sed -i x\n+y\nEOF", "git status"].each do |command|
      assert_empty hook("pre-bash.sh", stdin: bash_event(command)).out, command
    end
    assert_empty hook("pre-bash.sh", stdin: "not json").out
    assert_equal 0, hook("pre-bash.sh", stdin: "not json").code
  end

  def test_pre_bash_names_every_tool_a_command_matches
    script = "jq '.x = 1' a.json > t.json && mv t.json a.json && sed -i '' 's/a/b/' b.rb"
    context = JSON.parse(hook("pre-bash.sh", stdin: bash_event(script)).out).dig("hookSpecificOutput", "additionalContext")
    assert_includes context, "`toolsmith-json-set` exists for that"
    assert_includes context, "`toolsmith-text-replace` exists for that"
    assert_equal %w[toolsmith-json-set toolsmith-text-replace], log_events.map { |e| e["tool"] }
  end

  def test_pre_bash_reminds_once_per_session_and_never_in_a_subagent
    sed = "sed -i '' 's/a/b/' x.rb"
    assert_includes reminded(sed, session_id: "s1").to_s, "toolsmith-text-replace"
    assert_nil reminded(sed, session_id: "s1"), "a second reminder in the same session"
    assert_includes reminded("sed -n 1,5p a.rb; sed -n 9,12p b.rb", session_id: "s1").to_s, "toolsmith-file-lines", "another tool is still new"
    assert_includes reminded(sed, session_id: "s2").to_s, "toolsmith-text-replace", "a new session"
    assert_nil reminded(sed, session_id: "s3", agent_id: "a1", agent_type: "Explore"), "a subagent"
    assert_includes reminded(sed, session_id: "s3").to_s, "toolsmith-text-replace", "the subagent did not use up the session's reminder"
    refute_includes reminded(sed).to_s, "say why"
    assert_equal 5, log_events.size, "only reminders shown are logged"
  end

  def test_pre_bash_patterns_skip_the_commands_that_misfired
    {
      "sed -n 40,60p a.rb; sed -n '98,110p' b.rb" => "toolsmith-file-lines",
      "cd app && bin/rails test test/models | tail -5" => "toolsmith-check-run",
      "bin/audit_design --strict 2>&1 | tail -3" => "toolsmith-check-run",
      "gh pr checks 12 --watch" => "toolsmith-ci-wait"
    }.each { |command, tool| assert_includes reminded(command, session_id: command).to_s, tool, command }
    [
      "sed -n 1,80p app/models/user.rb",
      "git show HEAD:a.rb | sed -n 1,20p",
      "grep -n 'def ' bin/audit_design | head",
      "gh run view 123 --log | grep -i error",
      "perl -MTime::HiRes=time -e 'print time'",
      "python3 - <<'EOF'\nimport json\nd=json.load(open('a.json')); d['x']=[1]\njson.dump(d, open('a.json','w'))\nEOF"
    ].each { |command| assert_nil reminded(command, session_id: command), command }
  end

  def test_pre_bash_denies_in_block_mode
    result = hook("pre-bash.sh", stdin: bash_event("sed -i '' 's/a/b/' x.rb"), env: { "TOOLSMITH_ROOT" => fake_root(mode: "block") })
    output = JSON.parse(result.out).fetch("hookSpecificOutput")
    assert_equal "deny", output["permissionDecision"]
    assert_includes output["permissionDecisionReason"], "toolsmith-text-replace"
  end

  # -- the history analysis -------------------------------------------------

  def transcript(file, records)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, records.map { |r| JSON.generate(r) + "\n" }.join)
  end

  def bash_use(id, command, time, session = "s1")
    { "type" => "assistant", "timestamp" => time, "sessionId" => session,
      "message" => { "content" => [{ "type" => "tool_use", "id" => id, "name" => "Bash", "input" => { "command" => command } }] } }
  end

  def error_result(id)
    { "type" => "user", "message" => { "content" => [{ "type" => "tool_result", "tool_use_id" => id, "is_error" => true, "content" => "boom" }] } }
  end

  def projects
    dir = File.join(@state, "projects")
    transcript(File.join(dir, "-proj-a/one.jsonl"), [
      bash_use("t1", "sed -i '' 's/a/b/' x.rb", "2026-10-06T10:00:00Z"),
      bash_use("t2", "toolsmith-text-replace <<'EOF'\n@@ x.rb\n-a\n+b\nEOF", "2026-10-06T10:05:00Z"),
      error_result("t2"),
      bash_use("t3", "grep -n foo x.rb | head -5", "2026-10-06T10:06:00Z"),
      bash_use("t4", "cd app && grep -n bar y.rb", "2026-10-06T10:07:00Z"),
      { "type" => "summary", "message" => "not a tool call" }
    ])
    transcript(File.join(dir, "-proj-b/two.jsonl"), [
      bash_use("t1", "sed -i '' 's/a/b/' x.rb", "2026-10-06T10:00:00Z"),
      bash_use("t5", "ls", "2026-09-29T09:00:00Z", "s2")
    ])
    File.write(File.join(dir, "-proj-b/broken.jsonl"), "{not json \"tool_use\" \"Bash\"\n")
    dir
  end

  def analyse(*args)
    out, err, status = Open3.capture3({ "TOOLSMITH_ROOT" => fake_root }, ruby_bin, File.join(PLUGIN, "scripts/analyse"), *args)
    Result.new(out, err, status)
  end

  def test_scan_counts_families_and_keeps_weekly_metrics_after_transcripts_go
    dir = projects
    metrics = File.join(@state, "weekly.json")
    result = analyse("scan", "--projects", dir, "--metrics", metrics)
    assert_equal 0, result.code, result.err
    assert_includes result.out, "5 Bash calls in 2 sessions, 2 projects, 2026-09-29 to 2026-10-06."
    assert_match(/^  1 +1 +1 +0 +\d+ +literal-replace +toolsmith-text-replace$/, result.out)
    assert_match(/^  2 +grep -n$/, result.out)
    saved = JSON.parse(File.read(metrics))
    assert_equal Time.now.strftime("%Y-%m-%d"), saved["last_scan"]
    week = saved["weeks"].fetch("2026-W41")
    assert_equal 4, week["bash_calls"]
    assert_equal({ "calls" => 1, "errors" => 1 }, week["tools"]["toolsmith-text-replace"])
    assert_equal 1, week["families"]["literal-replace"]["calls"]
    assert_equal 1, saved["weeks"].fetch("2026-W40")["bash_calls"]
    FileUtils.rm_rf(File.join(dir, "-proj-a"))
    analyse("scan", "--projects", dir, "--metrics", metrics)
    kept = JSON.parse(File.read(metrics))["weeks"]["2026-W41"]
    assert_equal 4, kept["bash_calls"], "deleted transcripts do not lower saved counts"
    assert_equal 1, kept["tools"]["toolsmith-text-replace"]["calls"]
  end

  def test_examples_show_recent_matching_commands
    dir = projects
    family = analyse("examples", "--family", "literal-replace", "--projects", dir)
    assert_includes family.out, "1 matching calls; the 1 most recent:"
    assert_includes family.out, "sed -i '' 's/a/b/' x.rb"
    match = analyse("examples", "--match", "grep -n", "--limit", "1", "--projects", dir)
    assert_includes match.out, "2 matching calls; the 1 most recent:"
    assert_includes match.out, "cd app && grep -n bar y.rb"
    refute_includes match.out, "foo"
    assert_equal 1, analyse("examples", "--family", "nope", "--projects", dir).code
  end

  def test_adoption_compares_tool_calls_with_the_old_pattern_and_reads_the_log
    dir = projects
    File.write(@log, [
      { "ts" => 1000, "event" => "nudge", "tool" => "toolsmith-text-replace" },
      { "ts" => 1100, "event" => "run", "tool" => "toolsmith-text-replace", "mode" => "llm", "exit" => 0 },
      { "ts" => 1200, "event" => "run", "tool" => "toolsmith-text-replace", "mode" => "run", "exit" => 0 },
      { "ts" => 5000, "event" => "run", "tool" => "toolsmith-text-replace", "mode" => "run", "exit" => 1 }
    ].map { |e| JSON.generate(e) + "\n" }.join)
    result = analyse("adoption", "--projects", dir, "--log", @log)
    assert_equal 0, result.code, result.err
    section = result.out[/toolsmith-text-replace .*?\n\n/m]
    assert_includes section, "(replaces literal-replace, added "
    assert_match(/^  2026-W41 +1 +1 +1 +50%$/, section)
    assert_match(/^  2026-W40 +0 +0 +0 +-$/, section)
    assert_includes section, "Usage log: 2 runs, 1 failed, 1 guide reads, 1 reminders, 1 reminders followed by a run within 10 minutes."
  end
end
