//! toolsmith-pr-land: merges a pull request through `gh`, then returns the
//! local clone to the updated base branch: deletes the head branch on origin
//! and locally, fast-forwards the base, and lists branches built on the head
//! that now need a rebase. See tool.json for the guide that `--llm` prints.

use toolsmith_common::process::{run, Output};
use toolsmith_common::{Tool, Value, EXIT_OK};

/// The pull request was merged, but a local clean-up step failed.
const EXIT_PARTLY: i32 = 3;
const METHODS: [(&str, &str); 3] =
    [("merge", "mergeCommitAllowed"), ("squash", "squashMergeAllowed"), ("rebase", "rebaseMergeAllowed")];

fn main() {
    let tool = Tool::new(include_str!("../tool.json"));
    let args = tool.handle_guide_flags(std::env::args().skip(1).collect());
    let mut number: Option<String> = None;
    let mut method: Option<&str> = None;
    for arg in &args {
        let flag = METHODS.iter().find(|(m, _)| arg == &format!("--{}", m)).map(|(m, _)| *m);
        if let Some(m) = flag {
            if method.is_some() {
                tool.usage_error("give only one of --merge, --squash and --rebase");
            }
            method = Some(m);
        } else if arg.parse::<u64>().is_ok() && number.is_none() {
            number = Some(arg.clone());
        } else {
            tool.usage_error(&format!("unknown argument {}", arg));
        }
    }

    match run("git", &["status", "--porcelain", "--untracked-files=no"]) {
        Ok(out) if out.success && out.stdout.trim().is_empty() => {}
        Ok(out) if out.success => tool.fail("tracked files have uncommitted changes; commit or stash them first. Nothing was merged."),
        _ => tool.fail("not in a git repository. Nothing was merged."),
    }

    let mut view = vec!["pr", "view"];
    if let Some(n) = &number {
        view.push(n);
    }
    view.extend(["--json", "number,title,state,isDraft,headRefName,headRefOid,baseRefName"]);
    let pr = json(&tool, &gh(&tool, &view));
    let (n, title, head, oid, base) =
        (text(&pr, "number"), text(&pr, "title"), text(&pr, "headRefName"), text(&pr, "headRefOid"), text(&pr, "baseRefName"));
    if text(&pr, "state") != "OPEN" {
        tool.fail(&format!("PR #{} is {}, not open. Nothing was merged.", n, text(&pr, "state").to_lowercase()));
    }
    if pr.get("isDraft") == Some(&Value::Bool(true)) {
        tool.fail(&format!("PR #{} is a draft. Mark it ready with `gh pr ready {}` first. Nothing was merged.", n, n));
    }
    let method = method.unwrap_or_else(|| repo_method(&tool));

    // Children are listed before the head branch goes, while GitHub still
    // shows their base.
    let children = json(&tool, &gh(&tool, &["pr", "list", "--base", &head, "--state", "open", "--json", "number,headRefName"]));

    let merge = run("gh", &["pr", "merge", &n, &format!("--{}", method)]);
    match merge {
        Ok(Output { success: true, .. }) => {}
        Ok(out) => tool.fail(&format!("gh could not merge PR #{}: {}. Nothing changed locally.", n, out.stderr)),
        Err(e) => tool.fail(&e),
    }
    println!("Merged #{} \"{}\" into {} ({}).", n, title, base, method);

    let mut problems: Vec<String> = Vec::new();
    let mut step = |args: &[&str], ignore: &str| -> bool {
        match run("git", args) {
            Ok(out) if out.success => true,
            Ok(out) if !ignore.is_empty() && out.stderr.contains(ignore) => true,
            Ok(out) => {
                problems.push(format!("`git {}` failed: {}", args.join(" "), out.stderr));
                false
            }
            Err(e) => {
                problems.push(e);
                false
            }
        }
    };
    let deleted_remote = step(&["push", "origin", "--delete", &head], "remote ref does not exist");
    step(&["fetch", "--prune", "--quiet", "origin"], "");
    let current = run("git", &["branch", "--show-current"]).map(|o| o.stdout.trim().to_string()).unwrap_or_default();
    let on_base = current == base || step(&["switch", "--quiet", &base], "");
    if on_base {
        step(&["merge", "--ff-only", "--quiet", &format!("origin/{}", base)], "");
    }
    let local = run("git", &["rev-parse", "--verify", "--quiet", &format!("refs/heads/{}", head)]).map(|o| o.success).unwrap_or(false);
    let deleted_local = !local || (on_base && step(&["branch", "--quiet", "-D", &head], ""));
    match (deleted_remote, deleted_local) {
        (true, true) => println!("Deleted branch {} on origin and locally.", head),
        (true, false) => println!("Deleted branch {} on origin; the local branch is still there.", head),
        (false, true) => println!("Deleted the local branch {}; it is still on origin.", head),
        (false, false) => println!("Branch {} is still on origin and locally.", head),
    }
    if let Ok(out) = run("git", &["log", "--oneline", "-1"]) {
        println!("{} is now at {}", base, out.stdout.trim());
    }

    let mut lines: Vec<String> = Vec::new();
    for child in children.as_array().unwrap_or(&[]) {
        let branch = text(child, "headRefName");
        lines.push(format!("  git rebase --onto {} {} {}", base, oid, branch));
        lines.push(format!("  gh pr edit {} --base {}", text(child, "number"), base));
    }
    let contains = run("git", &["branch", "--contains", &oid, "--format=%(refname:short)"]).map(|o| o.stdout).unwrap_or_default();
    for branch in contains.lines().map(str::trim).filter(|b| !b.is_empty() && *b != base && *b != head) {
        if !lines.iter().any(|l| l.ends_with(&format!(" {}", branch))) {
            lines.push(format!("  git rebase --onto {} {} {}", base, oid, branch));
        }
    }
    if !lines.is_empty() {
        println!("Branches built on {} need a rebase onto {}:", head, base);
        for line in lines {
            println!("{}", line);
        }
    }

    if !problems.is_empty() {
        for problem in &problems {
            eprintln!("{}: merged, but {}", tool.name(), problem);
        }
        tool.exit(EXIT_PARTLY);
    }
    tool.exit(EXIT_OK);
}

fn gh(tool: &Tool, args: &[&str]) -> String {
    match run("gh", args) {
        Ok(out) if out.success => out.stdout,
        Ok(out) => tool.fail(&format!("`gh {}` failed: {}. Nothing was merged.", args.join(" "), out.stderr)),
        Err(e) => tool.fail(&format!("{}. Install the GitHub CLI (gh) and sign in with `gh auth login`.", e)),
    }
}

fn json(tool: &Tool, text: &str) -> Value {
    Value::parse(text).unwrap_or_else(|e| tool.fail(&format!("unexpected output from gh: {}. Nothing was merged.", e)))
}

fn text(value: &Value, key: &str) -> String {
    match value.get(key) {
        Some(Value::String(s)) => s.clone(),
        Some(Value::Number(n)) => n.clone(),
        _ => String::new(),
    }
}

/// The repository's only allowed merge method; a usage error when it allows more than one.
fn repo_method(tool: &Tool) -> &'static str {
    let fields: Vec<&str> = METHODS.iter().map(|(_, f)| *f).collect();
    let settings = json(tool, &gh(tool, &["repo", "view", "--json", &fields.join(",")]));
    let allowed: Vec<&'static str> =
        METHODS.iter().filter(|(_, f)| settings.get(f) == Some(&Value::Bool(true))).map(|(m, _)| *m).collect();
    match allowed.as_slice() {
        [only] => only,
        _ => tool.usage_error(&format!(
            "this repository allows {}; choose one with --{}",
            allowed.join(", "),
            allowed.join(", --")
        )),
    }
}
