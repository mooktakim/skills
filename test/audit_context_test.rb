# frozen_string_literal: true

require_relative "test_helper"

class AuditContextTest < Minitest::Test
  include ScriptTestHelper

  def setup
    super
    install "rails-context", "audit_context"
  end

  def audit(cwd: @dir)
    run_script "audit_context", cwd: cwd
  end

  def context(dir, body = "# #{dir}\nrules\n")
    write "#{dir}/AGENTS.md", body
    write "#{dir}/CLAUDE.md", "@AGENTS.md\n"
  end

  def sources(dir, count, ext: "rb")
    count.times { |i| write "#{dir}/f#{i}.#{ext}", "class F#{i}; end\n" }
  end

  def test_no_context_files
    write "README", "x"
    commit
    result = audit
    assert_equal 0, result.code
    assert_includes result.out, "No context files found under app/, lib/, test/, or spec/."
  end

  def test_clean_after_commit_and_works_from_a_subfolder
    context "app/services"
    sources "app/services", 2
    commit
    result = audit(cwd: path("app/services"))
    assert_equal "No drift detected.\n", result.out
  end

  def test_not_a_git_repo
    other = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(other, "bin"))
    FileUtils.cp(path("bin/audit_context"), File.join(other, "bin"))
    _out, err, status = Open3.capture3(ruby_bin, File.join(other, "bin/audit_context"), chdir: other)
    assert_equal 1, status.exitstatus
    assert_includes err, "not a git repo"
  ensure
    FileUtils.rm_rf(other)
  end

  def test_deleted_files_are_listed_apart_from_changed_ones
    context "app/services"
    sources "app/services", 5
    commit "init"
    git "rm", "-q", "app/services/f0.rb"
    git "mv", "app/services/f1.rb", "app/services/f1b.rb"
    append "app/services/f2.rb", "# touched\n"
    commit "changes"
    File.delete(path("app/services/f3.rb"))
    write "app/services/new.rb", "class New; end\n"
    out = audit.out
    assert_includes out, "== app/services/AGENTS.md (last updated"
    assert_includes out, "   2 file(s) deleted since - remove anything that still describes them:\n" \
                         "     - app/services/f0.rb\n     - app/services/f3.rb\n"
    assert_includes out, "   3 file(s) changed since:\n" \
                         "     - app/services/f1b.rb\n     - app/services/f2.rb\n     - app/services/new.rb\n"
  end

  def test_reviewed_marker_commit_clears_the_flag
    context "app/services"
    sources "app/services", 2
    commit "init"
    append "app/services/f0.rb", "# routine\n"
    commit "routine"
    assert_includes audit.out, "1 file(s) changed since:"
    append "app/services/AGENTS.md", "\n<!-- reviewed: 2026-10-01 -->\n"
    commit "reviewed"
    assert_equal "No drift detected.\n", audit.out
  end

  def test_never_committed_and_layout_problems
    context "app/models"
    write "app/jobs/AGENTS.md", "# jobs\n"
    write "app/views/AGENTS.md", "# views\n"
    File.symlink("AGENTS.md", path("app/views/CLAUDE.md"))
    write "app/mailers/AGENTS.md", "# mailers\n"
    write "app/mailers/CLAUDE.md", "# mailers, Claude's copy\n"
    write "app/helpers/CLAUDE.md", "@AGENTS.md\n"
    git "add", "app/jobs", "app/views", "app/mailers", "app/helpers"
    git "commit", "-q", "-m", "partial"
    out = audit.out
    assert_includes out, "== app/models/AGENTS.md\n   never committed - commit it or review now"
    assert_includes out, "missing CLAUDE.md - run: (cd app/jobs && printf '@AGENTS.md\\n' > CLAUDE.md && git add CLAUDE.md)"
    assert_includes out, "CLAUDE.md is a symlink - replace it with an import: (cd app/views && rm CLAUDE.md && printf '@AGENTS.md\\n' > CLAUDE.md && git add CLAUDE.md)"
    assert_includes out, "== app/mailers/AGENTS.md (last updated"
    assert_includes out, "CLAUDE.md and AGENTS.md are both real files - merge CLAUDE.md into AGENTS.md"
    assert_includes out, "== app/helpers/CLAUDE.md (last updated"
    assert_includes out, "CLAUDE.md imports AGENTS.md, but there is no AGENTS.md here"
  end

  # The old layout (content in CLAUDE.md, AGENTS.md a symlink to it, or no
  # AGENTS.md) is still audited, and the printed command migrates it.
  def test_old_layout_is_audited_and_its_command_migrates_it
    write "app/services/CLAUDE.md", "# services\n"
    File.symlink("CLAUDE.md", path("app/services/AGENTS.md"))
    write "app/jobs/CLAUDE.md", "# jobs\n"
    sources "app/services", 2
    commit
    append "app/services/f0.rb", "# changed\n"
    out = audit.out
    assert_includes out, "== app/services/CLAUDE.md (last updated"
    assert_includes out, "1 file(s) changed since:"
    services = "(cd app/services && git rm -q AGENTS.md && git mv CLAUDE.md AGENTS.md && printf '@AGENTS.md\\n' > CLAUDE.md && git add CLAUDE.md)"
    jobs = "(cd app/jobs && git mv CLAUDE.md AGENTS.md && printf '@AGENTS.md\\n' > CLAUDE.md && git add CLAUDE.md)"
    assert_includes out, "old layout (content in CLAUDE.md) - migrate: #{services}"
    assert_includes out, "old layout (content in CLAUDE.md) - migrate: #{jobs}"
    [services, jobs].each do |command|
      _out, err, status = Open3.capture3("bash", "-c", command, chdir: @dir)
      assert status.success?, err
    end
    commit "migrate"
    assert_equal "# services\n", File.read(path("app/services/AGENTS.md"))
    assert_equal "@AGENTS.md\n", File.read(path("app/services/CLAUDE.md"))
    refute File.symlink?(path("app/services/AGENTS.md"))
    assert_equal "No drift detected.\n", audit.out
  end

  def test_root_layout_and_claude_only_lines_count_toward_size
    write "CLAUDE.md", "# root\n"
    commit
    assert_includes audit.out, "== CLAUDE.md (root)\n   old layout (content in CLAUDE.md) - migrate: git mv CLAUDE.md AGENTS.md && " \
                               "printf '@AGENTS.md\\n' > CLAUDE.md && git add CLAUDE.md (ask before changing the root)"
    context "app/models", (1..100).map(&:to_s).join("\n") + "\n"
    append "app/models/CLAUDE.md", (1..60).map { |i| "claude #{i}" }.join("\n") + "\n"
    commit
    assert_includes audit.out, "oversized: 160 lines"
  end

  def test_size_triggers_count_bytes_as_well_as_lines
    context ".", (["x" * 300] * 110).join("\n") + "\n" # 110 lines but 32 KB
    context "app/models", (1..160).map(&:to_s).join("\n") + "\n"
    context "app/views", "# small\n"
    commit
    out = audit.out
    assert_includes out, "== AGENTS.md (root)\n   oversized: 110 lines, 33110 bytes (review trigger: 200 lines or 12288 bytes)"
    assert_includes out, "oversized: 160 lines, 532 bytes (review trigger: 150 lines or 10240 bytes)"
    assert_includes out, "Oversized files: cut inventory"
    refute_includes out, "app/views/AGENTS.md"
  end

  def test_candidate_directories
    context ".", "# root\n"
    context "app/models", "# models\n- `billing/` - money\n"
    sources "app/models/billing", 6
    sources "app/models/library", 6
    sources "app/helpers", 6
    sources "app/javascript/controllers", 6, ext: "js"
    context "app/javascript/controllers"
    sources "app/services", 3
    sources "app/assets/stuff", 9, ext: "js"
    commit
    out = audit.out
    assert_includes out, "Directories with 5+ files and no context file"
    assert_includes out, "     - app/helpers (6 files)\n"
    assert_includes out, "     - app/models/library (6 files)\n"
    refute_includes out, "app/models/billing", "named in the parent's CLAUDE.md"
    refute_includes out, "app/javascript (", "a CLAUDE.md exists deeper in its tree"
    refute_includes out, "app/services (", "fewer than 5 files"
    refute_includes out, "app/assets"
    assert out.end_with?("No drift in the existing context files.\n"), "not \"No drift detected\" above a list of candidates"
    refute_includes out, "Oversized files", "no size advice without an oversized file"

    write "AGENTS.md", "# root\n<!-- context-skip: app/helpers/ app/models/library -->\n"
    commit "skip"
    refute_includes audit.out, "Directories with 5+ files"
  end
end
