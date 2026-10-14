# frozen_string_literal: true

require_relative "test_helper"
require "date"

class ProjectMemoryTest < Minitest::Test
  include ScriptTestHelper

  TEMPLATE = File.join(REPO, "project-memory/templates/MEMORY.md")

  def setup
    super
    install "project-memory", "memory"
    write "docs/MEMORY.md", File.read(TEMPLATE)
    write "app/models/money.rb", "class Money\n  CENTS = 100\nend\n"
  end

  def memory(*args, cwd: @dir)
    run_script "memory", *args, cwd: cwd
  end

  def note(rel, fields = {}, body = "Money is integer cents.\n")
    defaults = { "id" => File.basename(rel, ".md"), "type" => "convention", "status" => "active", "summary" => "Money is integer cents.",
                 "created" => "2026-10-01", "verified_at" => Date.today.to_s, "citations" => "[app/models/money.rb:2]" }
    lines = defaults.merge(fields).reject { |_, value| value.nil? }.map { |key, value| "#{key}: #{value}" }
    write "docs/#{rel}", "---\n#{lines.join("\n")}\n---\n\n#{body}"
  end

  def lint_problems
    result = memory("lint")
    [result.code, result.out]
  end

  # -- memory index ---------------------------------------------------------

  def test_index_lists_active_notes_by_type_with_lessons_and_inbox_counts
    note "conventions/money.md"
    note "gotchas/cache.md", "type" => "gotcha", "summary" => "Cache keys include the locale.", "verified_at" => "2026-09-30"
    note "inbox/maybe.md", "status" => "proposed", "verified_at" => nil
    write "docs/lessons.md", "- [L-001] Seed first\n  Reproduce with the seed.\n  helpful: 1 | harmful: 0 | last_used: 2026-10-01 | source: x\n"
    result = memory("index")
    assert_equal 0, result.code, result.err
    index = File.read(path("docs/INDEX.md"))
    assert_includes index, "## Conventions\n- conventions/money.md - Money is integer cents. (verified #{Date.today})\n"
    assert_includes index, "## Gotchas\n- gotchas/cache.md - Cache keys include the locale. (verified 2026-09-30)\n"
    assert_operator index.index("## Conventions"), :<, index.index("## Gotchas")
    assert_includes index, "- lessons.md - 1 lesson(s); skim the titles."
    assert_includes index, "- inbox/ - 1 proposal(s) awaiting verification; never guidance."
    refute_includes index, "maybe.md"
    assert_equal "docs/INDEX.md is current.\n", memory("index", "--check").out
  end

  def test_index_check_fails_when_a_note_changes_and_works_from_a_subfolder
    note "conventions/money.md"
    memory "index"
    note "conventions/money.md", "summary" => "Money is cents, never Float."
    result = memory("index", "--check", cwd: path("app/models"))
    assert_equal 1, result.code
    assert_equal "docs/INDEX.md is out of date: run bin/memory index\n", result.out
  end

  def test_index_splits_into_folder_indexes_past_the_budget_and_joins_again
    File.write(path("docs/MEMORY.md"), File.read(TEMPLATE).sub("index_max_lines: 200", "index_max_lines: 12"))
    10.times { |i| note "conventions/c#{i}.md" }
    note "playbooks/deploy.md", "type" => "playbook", "summary" => "Deploy steps."
    memory "index"
    index = File.read(path("docs/INDEX.md"))
    assert_includes index, "## Folders\n- conventions/INDEX.md - 10 conventions note(s)\n- playbooks/INDEX.md - 1 playbooks note(s)\n"
    assert_includes File.read(path("docs/conventions/INDEX.md")), "- conventions/c0.md - Money is integer cents."
    assert_equal 0, memory("lint").code, memory("lint").out
    9.times { |i| File.delete(path("docs/conventions/c#{i}.md")) }
    memory "index"
    refute File.exist?(path("docs/conventions/INDEX.md")), "a generated folder index that is no longer needed is removed"
    assert_includes File.read(path("docs/INDEX.md")), "## Conventions\n- conventions/c9.md"
  end

  # -- memory lint ----------------------------------------------------------

  def test_lint_is_clean_on_a_correct_memory
    note "conventions/money.md", "links" => "[decisions/0001-money.md]"
    note "decisions/0001-money.md", "type" => "decision", "id" => "adr-0001", "citations" => "[app/models/money.rb:1-3]"
    note "archive/conventions/float-money.md", "status" => "superseded", "superseded_by" => "money", "valid_until" => "2026-09-01",
                                               "citations" => "[app/models/gone.rb:9]"
    note "inbox/idea.md", "status" => "proposed", "type" => "gotcha"
    write "docs/log/2026/10/14/1792015200-billing.md", "# billing\n"
    memory "index"
    code, out = lint_problems
    assert_equal 0, code, out
    assert_equal "Memory docs are clean: 4 note(s), 0 lesson(s).\n", out
  end

  def test_lint_reports_frontmatter_and_placement_problems
    note "conventions/a.md", "type" => "gotcha"
    note "conventions/b.md", "status" => "proposed"
    note "conventions/c.md", "status" => "superseded", "superseded_by" => "nobody"
    note "conventions/d.md", "verified_at" => nil, "summary" => nil, "created" => "last week"
    note "inbox/e.md", "status" => "active"
    note "gotchas/a.md", "type" => "gotcha"
    note "archive/conventions/f.md", "status" => "active"
    write "docs/conventions/g.md", "No frontmatter here.\n"
    memory "index"
    code, out = lint_problems
    assert_equal 1, code
    [
      "docs/conventions/a.md: type gotcha belongs in gotchas/",
      "docs/conventions/b.md: status: proposed belongs in inbox/",
      "docs/conventions/c.md: superseded notes belong in archive/",
      "docs/conventions/c.md: superseded_by nobody is not the id of any note",
      "docs/conventions/d.md: missing summary",
      "docs/conventions/d.md: created is not a date (YYYY-MM-DD): last week",
      "docs/conventions/d.md: active notes need verified_at",
      "docs/inbox/e.md: only proposals belong in inbox/ (status is active)",
      "docs/archive/conventions/f.md: only superseded or expired notes belong in archive/ (status is active)",
      "id a is used by docs/conventions/a.md and docs/gotchas/a.md",
      "docs/conventions/g.md: no frontmatter"
    ].each { |problem| assert_includes out, problem }
  end

  def test_lint_checks_citations_and_links_but_not_in_the_archive
    note "conventions/money.md", { "citations" => "[app/models/money.rb:9, app/models/gone.rb, app/models/money.rb]", "links" => "[nope.md]" },
         "See [the ADR](../decisions/0009.md) and [the web](https://example.com).\n\n```\n[example](not-checked.md)\n```\n"
    note "archive/conventions/old.md", "status" => "expired", "citations" => "[app/models/gone.rb:1]", "valid_until" => "2026-01-01"
    memory "index"
    _code, out = lint_problems
    assert_includes out, "docs/conventions/money.md: citation app/models/money.rb:9: app/models/money.rb has only 3 lines"
    assert_includes out, "docs/conventions/money.md: citation app/models/gone.rb: app/models/gone.rb does not exist"
    assert_includes out, "docs/conventions/money.md: link nope.md does not exist"
    assert_includes out, "docs/conventions/money.md: link ../decisions/0009.md does not exist"
    refute_includes out, "example.com"
    refute_includes out, "not-checked"
    refute_includes out, "old.md"
    assert_includes out, "4 problem(s)."
  end

  def test_lint_checks_log_names_legacy_logs_lessons_sizes_and_secrets
    write "docs/log/2026/10/14/1792015200-ok.md", "- ok\n"
    write "docs/log/2026/10/15/1792015200-wrong-day.md", "- x\n"
    write "docs/log/notes.md", "- x\n"
    write "docs/history/2026-10-01/1790000000-old.md", "- old\n"
    write "docs/lessons.md", "- [L-001] One\n  text\n- [L-001] Two\n  text\n  helpful: 1 | harmful: 0\n"
    write "CLAUDE.md", "line\n" * 151
    write "docs/inbox/leak.md", "token ghp_#{'a' * 36}\n"
    memory "index"
    _code, out = lint_problems
    assert_includes out, "docs/log/2026/10/15/1792015200-wrong-day.md: epoch 1792015200 is 2026/10/14 in UTC, not 2026/10/15"
    assert_includes out, "docs/log/notes.md: log entries are named log/YYYY/MM/DD/EPOCH-slug.md"
    refute_includes out, "1792015200-ok.md"
    assert_includes out, "docs/history/ is a legacy log: migrate it with the project-memory skill"
    assert_includes out, "docs/lessons.md:1: L-001 has no `helpful: N | harmful: N | last_used: ...` line"
    assert_includes out, "docs/lessons.md: L-001 is used 2 times"
    assert_includes out, "CLAUDE.md: 151 lines, over root_context_max_lines (150)"
    assert_includes out, "docs/inbox/leak.md:1: looks like a GitHub token; remove it and rotate it"
    refute_includes out, "a" * 36, "the secret itself is never printed"
  end

  def test_settings_come_from_the_protocol_frontmatter
    File.write(path("docs/MEMORY.md"), File.read(TEMPLATE).sub("root_context_max_lines: 150", "root_context_max_lines: 200"))
    write "CLAUDE.md", "line\n" * 180
    memory "index"
    assert_equal 0, memory("lint").code
  end

  def test_without_a_protocol_file_or_with_a_bad_command
    File.delete(path("docs/MEMORY.md"))
    result = memory("lint")
    assert_equal 1, result.code
    assert_includes result.err, "no docs/MEMORY.md"
    write "docs/MEMORY.md", File.read(TEMPLATE)
    assert_equal 2, memory("frobnicate").code
  end

  # -- memory stale ---------------------------------------------------------

  def test_stale_lists_inbox_old_notes_and_harmful_lessons
    note "conventions/fresh.md"
    note "conventions/old.md", "verified_at" => (Date.today - 91).to_s
    note "inbox/idea.md", "status" => "proposed", "created" => (Date.today - 3).to_s, "summary" => "Maybe a trap."
    write "docs/lessons.md", "- [L-001] Good\n  x\n  helpful: 3 | harmful: 1\n- [L-002] Bad\n  x\n  helpful: 1 | harmful: 1\n" \
                             "- [L-003] New\n  x\n  helpful: 0 | harmful: 0\n"
    out = memory("stale").out
    assert_includes out, "Inbox proposals to promote or reject:\n- docs/inbox/idea.md (3 day(s) old): Maybe a trap."
    assert_includes out, "Notes not verified in 90 days: re-verify or expire:\n- docs/conventions/old.md: verified #{Date.today - 91}, 91 day(s) ago"
    assert_includes out, "Lessons to retire (harmful >= helpful):\n- L-002 Bad (helpful 1, harmful 1)"
    refute_includes out, "fresh.md"
    refute_includes out, "L-003"
  end

  def test_stale_with_nothing_to_do
    assert_equal "Nothing to consolidate.\n", memory("stale").out
  end
end
