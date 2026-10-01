# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "tmpdir"
require "fileutils"
require "json"
require "rbconfig"

REPO = File.expand_path("..", __dir__)

# Runs the plugins' scripts as real subprocesses inside throwaway git repos, the
# way Claude Code hooks, bin/ci, and people call them. TEST_RUBY picks the Ruby
# that runs the audit scripts (default: the Ruby running the tests), so the suite
# can prove compatibility with an old system Ruby too.
module ScriptTestHelper
  Result = Struct.new(:out, :err, :status) do
    def code
      status.exitstatus
    end
  end

  def ruby_bin
    ENV.fetch("TEST_RUBY", RbConfig.ruby)
  end

  def setup
    @dir = File.realpath(Dir.mktmpdir("skills-test"))
    git "init", "-q", "-b", "main"
    git "config", "user.email", "test@example.com"
    git "config", "user.name", "Test"
    git "config", "commit.gpgsign", "false"
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def path(rel)
    File.join(@dir, rel)
  end

  def write(rel, content)
    FileUtils.mkdir_p(File.dirname(path(rel)))
    File.write(path(rel), content)
  end

  def append(rel, content)
    File.open(path(rel), "a") { |file| file.write(content) }
  end

  def git(*args)
    out, err, status = Open3.capture3("git", *args, chdir: @dir)
    raise "git #{args.join(' ')} failed: #{err}" unless status.success?

    out
  end

  def commit(message = "change")
    git "add", "-A"
    git "commit", "-q", "--allow-empty", "-m", message
  end

  # Copies a plugin script into the repo's bin/, as the skills' Phase 3 does.
  def install(plugin, script)
    FileUtils.mkdir_p(path("bin"))
    FileUtils.cp(File.join(REPO, plugin, "scripts", script), path("bin/#{script}"))
    FileUtils.chmod(0o755, path("bin/#{script}"))
  end

  def run_script(script, *args, stdin: "", cwd: @dir, env: {})
    out, err, status = Open3.capture3(env, ruby_bin, path("bin/#{script}"), *args, stdin_data: stdin, chdir: cwd)
    Result.new(out, err, status)
  end

  def run_bash(file, *args, stdin: "", cwd: @dir, env: {})
    out, err, status = Open3.capture3(env, "bash", file, *args, stdin_data: stdin, chdir: cwd)
    Result.new(out, err, status)
  end

  def hook_json(file)
    JSON.generate("tool_input" => { "file_path" => file })
  end
end
