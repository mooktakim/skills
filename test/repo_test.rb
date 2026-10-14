# frozen_string_literal: true

require_relative "test_helper"

# The marketplace's own structure rules from CLAUDE.md, checked so a broken
# manifest, a missing README row, or a hook pointing at a missing script fails CI
# instead of failing for users after an update.
class RepoTest < Minitest::Test
  def marketplace
    JSON.parse(File.read(File.join(REPO, ".claude-plugin/marketplace.json")))
  end

  def plugin_dirs
    Dir.glob(File.join(REPO, "*/.claude-plugin/plugin.json")).map { |file| File.basename(File.dirname(File.dirname(file))) }.sort
  end

  def frontmatter(file)
    File.read(file)[/\A---\n(.*?)\n---\n/m, 1].to_s
  end

  def test_marketplace_lists_every_plugin_and_names_match
    entries = marketplace.fetch("plugins")
    assert_equal plugin_dirs, entries.map { |entry| entry["name"] }.sort
    entries.each do |entry|
      assert_equal "./#{entry['name']}", entry["source"]
      manifest = JSON.parse(File.read(File.join(REPO, entry["name"], ".claude-plugin/plugin.json")))
      assert_equal entry["name"], manifest["name"]
      assert_match(/\A\d+\.\d+\.\d+\z/, manifest["version"], "#{entry['name']} needs a semver version")
    end
  end

  def test_root_readme_has_a_row_per_plugin
    readme = File.read(File.join(REPO, "README.md"))
    plugin_dirs.each { |name| assert_includes readme, "[`#{name}`](#{name}/)" }
  end

  def test_skill_and_agent_names_match_their_files
    plugin_dirs.each do |name|
      skill = File.join(REPO, name, "SKILL.md")
      assert_includes frontmatter(skill), "name: #{name}\n" if File.exist?(skill)
      Dir.glob(File.join(REPO, name, "agents/*.md")).each do |agent|
        meta = frontmatter(agent)
        assert_includes meta, "name: #{File.basename(agent, '.md')}\n"
        assert_match(/^description: \S/, meta)
      end
    end
  end

  # Claude Code parses the frontmatter as YAML; a plain value with ": " in it is
  # invalid YAML even when the listing happens to show it.
  def test_skill_and_agent_frontmatter_is_valid_yaml
    Dir.glob(File.join(REPO, "*/{SKILL.md,agents/*.md}")).each do |file|
      meta = YAML.safe_load(frontmatter(file))
      assert_kind_of String, meta["name"], file
      assert_kind_of String, meta["description"], file
    rescue Psych::SyntaxError => e
      flunk "#{file}: #{e.message}"
    end
  end

  # When the skill listing is over budget, Claude Code drops descriptions from
  # the least-used skills first, and a skill listed with no description is rarely
  # invoked. Short descriptions keep the whole listing inside the budget.
  def test_skill_descriptions_stay_short
    Dir.glob(File.join(REPO, "*/SKILL.md")).each do |file|
      size = YAML.safe_load(frontmatter(file))["description"].size
      assert_operator size, :<=, 500, "#{file}: description is #{size} characters; keep it to 500 with the trigger first"
    end
  end

  def test_hooks_parse_and_point_at_scripts_that_exist
    Dir.glob(File.join(REPO, "*/hooks/hooks.json")).each do |file|
      plugin_root = File.dirname(File.dirname(file))
      commands = JSON.parse(File.read(file)).fetch("hooks").values.flatten.flat_map { |group| group.fetch("hooks") }.map { |hook| hook.fetch("command") }
      refute_empty commands
      commands.each do |command|
        command.scan(%r{\$\{CLAUDE_PLUGIN_ROOT\}/([^"\s]+)}).flatten.each do |rel|
          assert File.file?(File.join(plugin_root, rel)), "#{file}: #{rel} does not exist"
        end
      end
    end
  end

  def test_shipped_scripts_are_executable_ruby_that_compiles
    scripts = Dir.glob(File.join(REPO, "*/scripts/*"))
    refute_empty scripts
    scripts.each do |script|
      assert File.executable?(script), "#{script} must be executable"
      assert_equal "#!/usr/bin/env ruby\n", File.open(script, &:gets)
      _out, err, status = Open3.capture3(ruby_bin, "-c", script)
      assert status.success?, "#{script}: #{err}"
    end
  end

  # The repo keeps its own project memory with a copy of the plugin's script.
  def test_bin_memory_is_the_project_memory_script
    assert_equal File.read(File.join(REPO, "project-memory/scripts/memory")), File.read(File.join(REPO, "bin/memory"))
  end

  def test_hook_scripts_parse_as_bash
    Dir.glob(File.join(REPO, "*/hooks/*.sh")).each do |script|
      _out, err, status = Open3.capture3(ENV.fetch("TEST_BASH", "bash"), "-n", script)
      assert status.success?, "#{script}: #{err}"
    end
  end

  def ruby_bin
    ENV.fetch("TEST_RUBY", RbConfig.ruby)
  end
end
