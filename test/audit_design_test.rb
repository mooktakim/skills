# frozen_string_literal: true

require_relative "test_helper"

class AuditDesignTest < Minitest::Test
  include ScriptTestHelper

  def setup
    super
    install "rails-design-system", "audit_design"
    write "app/views/x/a.html.erb", %(<p class="bg-surface">ok</p>\n)
    FileUtils.mkdir_p(path("docs/sub"))
    commit "init"
  end

  def hook(file, cwd: path("docs/sub"))
    run_script "audit_design", "--hook", stdin: hook_json(file), cwd: cwd
  end

  def stop(active: false)
    run_script "audit_design", "--stop", stdin: JSON.generate("stop_hook_active" => active), cwd: path("docs/sub")
  end

  # -- the token checks themselves ------------------------------------------

  FLAGGED = [
    %(<div style="color:#ff0000">),
    %(<p class="text-[#1a2b3c]">),
    %(<i class="bg-gray-100">),
    %(<div class="w-[260px]">),
    %(<div class="grid-cols-[1fr_auto]">),
    %(<div class="bg-[var(--color-x)]">),
    %(<div class="bg-(--brand)">),
    %(<div class="md:w-[3px] hover:bg-red-500">),
    %(<div class="data-[state=open]:w-[3px]">),
    %(<div class="bg-[rgb(0,0,0)]/50">),
    %(color: #FFF;)
  ].freeze

  PASSING = [
    %(<button data-action="click->cart#add">),
    %(<form data-action="submit->form#dead">),
    %(this.#fade()),
    %(<p>&#123; &#x27;</p>),
    %(<div class="data-[state=open]:bg-surface">),
    %(<div class="aria-[expanded=true]:rotate-180">),
    %(<div class="group-has-data-[open]/menu:block">),
    %(<div class="has-[input:checked]:bg-accent">),
    %(<div class="min-[400px]:inline-flex">),
    %(<div class="bg-surface text-body">),
    %(<%# Spec: docs/design-system/app/components/button.md %>),
    %("\#{name}"),
    %(params[:id]),
    %(<div class="text-red-500"> <%# design-ok %>)
  ].freeze

  FLAGGED.each_with_index do |line, index|
    define_method("test_flags_#{index}") do
      write "app/views/x/t.html.erb", "#{line}\n"
      assert_equal 2, hook(path("app/views/x/t.html.erb")).code, "should flag: #{line}"
    end
  end

  PASSING.each_with_index do |line, index|
    define_method("test_passes_#{index}") do
      write "app/views/x/t.html.erb", "#{line}\n"
      result = hook(path("app/views/x/t.html.erb"))
      assert_equal 0, result.code, "should pass: #{line}\n#{result.err}"
    end
  end

  # -- hook mode ----------------------------------------------------------

  def test_hook_blocks_new_violation_from_a_subfolder_with_line_number
    append "app/views/x/a.html.erb", %(<p class="text-red-500">bad</p>\n)
    result = hook(path("app/views/x/a.html.erb"))
    assert_equal 2, result.code
    assert_includes result.err, %(app/views/x/a.html.erb:2: <p class="text-red-500">bad</p>)
  end

  def test_hook_ignores_old_drift_next_to_a_clean_edit
    write "app/views/x/a.html.erb", %(<p class="bg-gray-100">legacy</p>\n)
    commit "legacy"
    append "app/views/x/a.html.erb", %(<p class="text-body">clean</p>\n)
    assert_equal 0, hook(path("app/views/x/a.html.erb")).code
  end

  def test_hook_checks_whole_untracked_file
    write "app/views/x/new.html.erb", %(<i style="color:#ff0000">x</i>\n)
    assert_equal 2, hook(path("app/views/x/new.html.erb")).code
  end

  def test_hook_resolves_relative_paths_against_the_callers_directory
    write "app/views/x/new.html.erb", %(<i class="bg-red-500">x</i>\n)
    assert_equal 2, hook("views/x/new.html.erb", cwd: path("app")).code
  end

  def test_hook_handles_a_symlinked_root
    link = "#{@dir}-link"
    File.symlink(@dir, link)
    write "app/views/x/new.html.erb", %(<i class="bg-red-500">x</i>\n)
    result = Open3.capture3(ruby_bin, "#{link}/bin/audit_design", "--hook",
                            stdin_data: hook_json(path("app/views/x/new.html.erb")), chdir: path("docs/sub"))
    assert_equal 2, result[2].exitstatus
  ensure
    FileUtils.rm_f(link)
  end

  def test_hook_skips_mailers_non_views_and_files_outside_the_repo
    write "app/views/user_mailer/w.html.erb", %(<p style="color:#ff0000">m</p>\n)
    write "app/models/m.rb", %(X = "#ffffff"\n)
    assert_equal 0, hook(path("app/views/user_mailer/w.html.erb")).code
    assert_equal 0, hook(path("app/models/m.rb")).code
    assert_equal 0, hook("/etc/hosts").code
  end

  def test_hook_ignores_bad_input
    assert_equal 0, run_script("audit_design", "--hook", stdin: "not json").code
    assert_equal 0, run_script("audit_design", "--hook", stdin: "{}").code
  end

  # -- stop mode ----------------------------------------------------------

  def test_stop_catches_an_edit_made_outside_write_and_edit
    File.write(path("app/views/x/a.html.erb"), File.read(path("app/views/x/a.html.erb")).sub("bg-surface", "bg-blue-600"))
    result = stop
    assert_equal 2, result.code
    assert_includes result.err, "app/views/x/a.html.erb:1:"
  end

  def test_stop_catches_untracked_files
    write "app/views/x/h.html.erb", %(<div class="w-[37px]">heredoc</div>\n)
    assert_equal 2, stop.code
  end

  def test_stop_never_loops
    append "app/views/x/a.html.erb", %(<p class="bg-gray-100">x</p>\n)
    assert_equal 0, stop(active: true).code
  end

  def test_stop_passes_a_clean_tree
    assert_equal 0, stop.code
  end

  # -- data files ---------------------------------------------------------

  def test_vendor_paths_allow_palette_classes_only_on_their_paths
    write "docs/design-system/vendor-paths", "# external library sections\napp/views/admin/\n"
    write "app/views/admin/a.html.erb", %(<p class="bg-gray-100">a</p>\n)
    write "app/views/site/a.html.erb", %(<p class="bg-gray-100">s</p>\n)
    assert_equal 0, hook(path("app/views/admin/a.html.erb")).code
    assert_equal 2, hook(path("app/views/site/a.html.erb")).code
    write "app/views/admin/b.html.erb", %(<p class="w-[3px]">a</p>\n)
    assert_equal 2, hook(path("app/views/admin/b.html.erb")).code, "arbitrary values stay drift in vendor paths"
    commit "vendor"
    scan = run_script("audit_design")
    assert_includes scan.out, "== literal palette classes: 1"
    refute_includes scan.out, "app/views/admin/a.html.erb"
  end

  def test_audit_rules_apply_in_every_mode_and_tag_findings
    write "docs/design-system/audit-rules", <<~RULES
      # promoted from design reviews
      no gradients (app/design.md) :: (^|[^a-z-])bg-(gradient|linear|radial|conic)-
        money via helper (conventions.md) :: number_to_currency
      broken rule :: bg-(unclosed
      missing separator line
    RULES
    append "app/views/x/a.html.erb", %(<div class="bg-linear-to-r">new</div>\n)
    result = hook(path("app/views/x/a.html.erb"))
    assert_equal 2, result.code
    assert_includes result.err, "[rule: no gradients (app/design.md)]"
    assert_includes result.err, %(audit-rules: invalid regex for "broken rule" - skipped)
    assert_includes result.err, %(audit-rules: no " :: " in "missing separator line" - skipped)

    append "app/views/x/a.html.erb", %(<p><%= number_to_currency(x) %></p> <%# design-ok %>\n)
    git "add", "-A"
    git "commit", "-q", "-m", "rules"
    append "app/views/x/a.html.erb", %(<p><%= number_to_currency(y) %></p>\n)
    assert_includes stop.err, "[rule: money via helper (conventions.md)]"
    assert_includes run_script("audit_design").out, "== rule: no gradients (app/design.md): 1"
  end

  def test_rules_can_be_limited_to_a_sections_paths
    write "docs/design-system/audit-rules", "admin badge has no dot (admin/components/badge.md) :: rounded-full size-1\\.5 :: app/views/admin/ app/components/admin/\n"
    write "app/views/admin/a.html.erb", %(<span class="rounded-full size-1.5"></span>\n)
    write "app/views/site/a.html.erb", %(<span class="rounded-full size-1.5"></span>\n)
    assert_equal 2, hook(path("app/views/admin/a.html.erb")).code
    assert_equal 0, hook(path("app/views/site/a.html.erb")).code
    commit "scoped"
    out = run_script("audit_design").out
    assert_includes out, "== rule: admin badge has no dot (admin/components/badge.md): 1"
    refute_includes out, "app/views/site/a.html.erb"
  end

  def test_rules_with_paths_reach_copy_outside_the_views
    write "docs/design-system/audit-rules", <<~RULES
      money is formatted by the helper (conventions.md) :: AED \\#\\{ :: app/controllers/ app/views/
      no exclamation marks (conventions.md) :: !"
    RULES
    write "app/controllers/orders_controller.rb", %(flash[:notice] = "AED \#{total}"\nredirect_to root_path, notice: "Saved!"\n# bg-red-600\n)
    out = run_script("audit_design").out
    assert_includes out, "app/controllers/orders_controller.rb:1:"
    refute_includes out, "orders_controller.rb:2:", "a rule with no paths stays in the views"
    refute_includes out, "orders_controller.rb:3:", "token checks stay in the views"
    result = hook(path("app/controllers/orders_controller.rb"))
    assert_equal 2, result.code
    assert_includes result.err, "[rule: money is formatted by the helper (conventions.md)]"
    assert_equal 0, hook(path("app/models/order.rb").tap { |file| write "app/models/order.rb", %(X = "AED \#{1}"\n) }).code
  end

  def test_rules_with_non_ascii_patterns_work
    write "docs/design-system/audit-rules", "no pound sign (conventions.md) :: £\n"
    append "app/views/x/a.html.erb", "<p>£5</p>\n"
    assert_equal 2, hook(path("app/views/x/a.html.erb")).code
  end

  # tailwindcss-rails 4 keeps the entry CSS and component classes in
  # app/assets/tailwind/; its @theme block is where the token values live.
  def test_tailwind_css_is_checked_outside_its_theme_blocks
    write "app/assets/tailwind/application.css", <<~CSS
      @import "tailwindcss";
      @theme {
        --color-primary: #1d4ed8;
      }
      @theme inline { --color-on-primary: #fff; }
      .btn { @apply bg-primary; }
    CSS
    commit "tailwind"
    assert_equal 0, run_script("audit_design", "--strict").code, "token values in @theme blocks"

    css = path("app/assets/tailwind/application.css")
    File.write(css, File.read(css).sub("  --color-primary: #1d4ed8;\n", "  --color-primary: #1d4ed8;\n  --color-danger: #b91c1c;\n"))
    assert_equal 0, hook(css).code, "a new token in a @theme block"

    append "app/assets/tailwind/application.css", ".badge { color: #ff0000; }\n"
    result = hook(css)
    assert_equal 2, result.code
    assert_includes result.err, "app/assets/tailwind/application.css:8: .badge"
    refute_includes result.err, "--color-danger"
    assert_equal 2, stop.code
    full = run_script("audit_design")
    assert_includes full.out, "== raw hex colours: 1\n   app/assets/tailwind/application.css:8:.badge"
  end

  # -- full scan, strict, changed -----------------------------------------

  def test_full_scan_format_and_exit_codes
    result = run_script("audit_design")
    assert_equal 0, result.code
    assert_equal "== raw hex colours: 0\n\n== arbitrary values: 0\n\n== literal palette classes: 0\n\nNo drift detected.\n", result.out
    assert_equal 0, run_script("audit_design", "--strict").code

    append "app/views/x/a.html.erb", %(<p class="bg-gray-100">x</p>\n)
    result = run_script("audit_design")
    assert_equal 0, result.code
    assert_includes result.out, "   app/views/x/a.html.erb:2:<p class=\"bg-gray-100\">x</p>"
    assert_equal 1, run_script("audit_design", "--strict").code
  end

  def test_full_scan_works_from_a_subfolder_and_skips_binary_files
    File.binwrite(path("app/views/x/blob.html"), "bg-gray-100\0binary")
    assert_includes run_script("audit_design", cwd: path("docs/sub")).out, "No drift detected."
  end

  def test_changed_checks_only_lines_a_branch_adds
    append "app/views/x/a.html.erb", %(<p class="bg-gray-100">legacy</p>\n)
    commit "legacy on main"
    git "checkout", "-q", "-b", "feature"
    append "app/views/x/a.html.erb", %(<p class="text-body">clean</p>\n)
    commit "clean"
    result = run_script("audit_design", "--changed", "main")
    assert_equal 0, result.code
    assert_includes result.out, "No design drift in lines added since main."

    append "app/views/x/a.html.erb", %(<p class="text-red-500">bad</p>\n)
    commit "bad"
    result = run_script("audit_design", "--changed", "main")
    assert_equal 1, result.code
    assert_includes result.err, "Design-system drift in lines added since main:"
    refute_includes result.err, "legacy"
  end

  def test_changed_reports_bad_bases
    assert_equal 1, run_script("audit_design", "--changed", "nope").code
    assert_equal 1, run_script("audit_design", "--changed").code
  end

  def test_audit_root_lets_another_copy_audit_the_project
    append "app/views/x/a.html.erb", %(<p class="bg-gray-100">x</p>\n)
    plugin_copy = File.join(REPO, "rails-design-system/scripts/audit_design")
    out, _err, status = Open3.capture3({ "AUDIT_ROOT" => @dir }, ruby_bin, plugin_copy, "--strict", chdir: Dir.tmpdir)
    assert_equal 1, status.exitstatus
    assert_includes out, "app/views/x/a.html.erb:2:"
  end
end
