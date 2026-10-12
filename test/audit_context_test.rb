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
    write "#{dir}/CLAUDE.md", body
    File.symlink("CLAUDE.md", path("#{dir}/AGENTS.md")) unless File.symlink?(path("#{dir}/AGENTS.md"))
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
    assert_includes out, "== app/services/CLAUDE.md (last updated"
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
    append "app/services/CLAUDE.md", "\n<!-- reviewed: 2026-10-01 -->\n"
    commit "reviewed"
    assert_equal "No drift detected.\n", audit.out
  end

  def test_never_committed_and_symlink_problems
    context "app/models"
    write "app/jobs/CLAUDE.md", "# jobs\n"
    write "app/views/CLAUDE.md", "# views\n"
    File.symlink("README.md", path("app/views/AGENTS.md"))
    git "add", "app/jobs", "app/views"
    git "commit", "-q", "-m", "partial"
    out = audit.out
    assert_includes out, "== app/models/CLAUDE.md\n   never committed - commit it or review now"
    assert_includes out, "missing AGENTS.md symlink - run: (cd app/jobs && ln -s CLAUDE.md AGENTS.md)"
    assert_includes out, "AGENTS.md symlink points to README.md, expected CLAUDE.md"
  end

  def test_real_agents_md_must_be_migrated
    write "app/services/AGENTS.md", "# old\n"
    commit
    assert_includes audit.out, "== app/services/AGENTS.md\n   real AGENTS.md - migrate: git mv AGENTS.md CLAUDE.md && ln -s CLAUDE.md AGENTS.md"
  end

  def test_size_triggers_count_bytes_as_well_as_lines
    write "CLAUDE.md", (["x" * 300] * 110).join("\n") + "\n" # 110 lines but 32 KB
    context "app/models", (1..160).map(&:to_s).join("\n") + "\n"
    context "app/views", "# small\n"
    commit
    out = audit.out
    assert_includes out, "== CLAUDE.md (root)\n   oversized: 110 lines, 33110 bytes (review trigger: 200 lines or 12288 bytes)"
    assert_includes out, "oversized: 160 lines, 532 bytes (review trigger: 150 lines or 10240 bytes)"
    assert_includes out, "Oversized files: cut inventory"
    refute_includes out, "app/views/CLAUDE.md"
  end

  def test_candidate_directories
    write "CLAUDE.md", "# root\n"
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

    write "CLAUDE.md", "# root\n<!-- context-skip: app/helpers/ app/models/library -->\n"
    commit "skip"
    refute_includes audit.out, "Directories with 5+ files"
  end
end
