//! toolsmith-conflict-resolve: resolves git merge-conflict blocks in files as
//! one all-or-nothing change. Every block of every named file must get its
//! resolution in memory first; files are written only when all of them do.
//! See tool.json for the guide that `--llm` prints.

mod blocks;
mod spec;

use std::collections::HashMap;
use std::fs;
use std::io::{IsTerminal, Read};
use std::path::PathBuf;

use spec::{Choice, Resolution, Target};
use toolsmith_common::fsutil::write_atomically;
use toolsmith_common::process;
use toolsmith_common::{Tool, EXIT_FAILED, EXIT_OK};

/// Exit code when a write or `git add` failed after other files were written.
const EXIT_PARTIAL: i32 = 3;

fn main() {
    let tool = Tool::new(include_str!("../tool.json"));
    let args = tool.handle_guide_flags(std::env::args().skip(1).collect());
    let (mut show, mut stage, mut dry_run) = (false, false, false);
    let mut paths: Vec<String> = Vec::new();
    for arg in &args {
        match arg.as_str() {
            "--show" => show = true,
            "--stage" => stage = true,
            "--dry-run" => dry_run = true,
            other if other.starts_with('-') => tool.usage_error(&format!("unknown option {}", other)),
            other => paths.push(other.to_string()),
        }
    }
    if show {
        if stage || dry_run {
            tool.usage_error("--show writes nothing, so it takes no --stage or --dry-run");
        }
        show_blocks(&tool, paths);
    }
    if !paths.is_empty() {
        tool.usage_error(&format!("unexpected argument {}; paths go in the spec on stdin, or after --show", paths[0]));
    }
    if stage && dry_run {
        tool.usage_error("--dry-run writes nothing, so it cannot --stage");
    }
    resolve(&tool, stage, dry_run);
}

fn plural(n: usize, word: &str) -> String {
    format!("{} {}{}", n, word, if n == 1 { "" } else { "s" })
}

fn conflicted_files(tool: &Tool) -> Vec<String> {
    let git = |args: &[&str]| {
        let out = process::run("git", args).unwrap_or_else(|e| tool.fail(&format!("{}; name the files after --show", e)));
        if !out.success {
            tool.fail(&format!("git could not list the conflicted files ({}); name the files after --show", out.stderr));
        }
        out.stdout
    };
    // git names the files from the repository root; show them from here.
    let up = git(&["rev-parse", "--show-cdup"]);
    let up = up.trim_end();
    let names = git(&["-c", "core.quotePath=false", "diff", "--name-only", "--diff-filter=U"]);
    let mut files: Vec<String> = names.lines().map(|name| format!("{}{}", up, name)).collect();
    files.dedup();
    files
}

fn show_blocks(tool: &Tool, mut paths: Vec<String>) -> ! {
    if paths.is_empty() {
        paths = conflicted_files(tool);
        if paths.is_empty() {
            println!("No conflicted files.");
            tool.exit(EXIT_OK);
        }
    }
    let mut problems = Vec::new();
    for path in &paths {
        let parsed = match fs::read_to_string(path) {
            Ok(text) => blocks::parse(&text),
            Err(e) => Err(format!("cannot read the file: {}", e)),
        };
        let parsed = match parsed {
            Ok(parsed) => parsed,
            Err(why) => {
                problems.push(format!("{}: {}", path, why));
                continue;
            }
        };
        if parsed.blocks.is_empty() {
            println!("{}: no conflict blocks", path);
            continue;
        }
        println!("{}: {}", path, plural(parsed.blocks.len(), "conflict block"));
        for (i, block) in parsed.blocks.iter().enumerate() {
            println!("@@ {} {} ({})", path, i + 1, block.line_range());
            for line in &parsed.lines[block.start..=block.end] {
                print!("{}", line);
                if !line.ends_with('\n') {
                    println!();
                }
            }
        }
    }
    if !problems.is_empty() {
        eprintln!("{}: {}", tool.name(), problems.join("\n"));
        tool.exit(EXIT_FAILED);
    }
    tool.exit(EXIT_OK)
}

/// One file named by the spec, with the resolutions that name it.
struct File<'a> {
    shown: String,
    real: PathBuf,
    resolutions: Vec<&'a Resolution>,
}

fn resolve(tool: &Tool, stage: bool, dry_run: bool) -> ! {
    if std::io::stdin().is_terminal() {
        tool.usage_error("reads the resolution spec from stdin; pass it with a heredoc (<<'EOF'), or use --show");
    }
    let mut input = String::new();
    if std::io::stdin().read_to_string(&mut input).is_err() {
        tool.usage_error("the resolution spec on stdin is not valid UTF-8");
    }
    let resolutions = spec::parse(&input).unwrap_or_else(|e| tool.usage_error(&format!("bad spec: {}", e)));

    let mut problems: Vec<String> = Vec::new();
    let mut files: Vec<File> = Vec::new();
    let mut index: HashMap<PathBuf, usize> = HashMap::new();
    for r in &resolutions {
        let real = match fs::canonicalize(&r.path) {
            Ok(real) => real,
            Err(e) => {
                problems.push(format!("{} (spec line {}): cannot read the file: {}.", r.path, r.line, e));
                continue;
            }
        };
        let at = *index.entry(real.clone()).or_insert_with(|| {
            files.push(File { shown: r.path.clone(), real, resolutions: Vec::new() });
            files.len() - 1
        });
        files[at].resolutions.push(r);
    }

    let mut report = String::new();
    let mut resolved_files: Vec<(&File, String)> = Vec::new();
    let mut block_count = 0;
    for file in &files {
        let first_line = file.resolutions[0].line;
        let parsed = match fs::read_to_string(&file.real) {
            Ok(text) => blocks::parse(&text),
            Err(e) => Err(format!("cannot read the file: {}", e)),
        };
        let parsed = match parsed {
            Ok(parsed) => parsed,
            Err(why) => {
                problems.push(format!("{} (spec line {}): {}.", file.shown, first_line, why));
                continue;
            }
        };
        if parsed.blocks.is_empty() {
            problems.push(format!("{} (spec line {}): the file has no conflict blocks.", file.shown, first_line));
            continue;
        }
        match assign(&file.shown, &parsed, &file.resolutions) {
            Ok(choices) => {
                let mut resolved = Vec::new();
                for (i, (block, choice)) in parsed.blocks.iter().zip(&choices).enumerate() {
                    let lines = match choice {
                        Choice::Ours => block.ours.clone(),
                        Choice::Theirs => block.theirs.clone(),
                        Choice::Both => [block.ours.clone(), block.theirs.clone()].concat(),
                        Choice::Text(lines) => lines.clone(),
                    };
                    report.push_str(&format!(
                        "{} {} ({}): {}, {}\n",
                        file.shown,
                        i + 1,
                        block.line_range(),
                        choice.name(),
                        plural(lines.len(), "line")
                    ));
                    resolved.push(lines);
                }
                block_count += choices.len();
                resolved_files.push((file, blocks::render(&parsed, &resolved)));
            }
            Err(mut why) => problems.append(&mut why),
        }
    }

    if !problems.is_empty() {
        let mut message = format!("{}: nothing written: {}.\n", tool.name(), plural(problems.len(), "problem"));
        for problem in &problems {
            message.push_str(&format!("\n{}\n", problem));
        }
        eprint!("{}", message);
        tool.exit(EXIT_FAILED);
    }

    print!("{}", report);
    let totals = format!("{} resolved in {}", plural(block_count, "block"), plural(resolved_files.len(), "file"));
    if dry_run {
        println!(
            "Dry run: {} in {} would be resolved; nothing written.",
            plural(block_count, "block"),
            plural(resolved_files.len(), "file")
        );
        tool.exit(EXIT_OK);
    }
    let mut written: Vec<&str> = Vec::new();
    for (file, text) in &resolved_files {
        if let Err(e) = write_atomically(&file.real, text.as_bytes()) {
            eprintln!("{}: writing {} failed: {}. Already written: {}.", tool.name(), file.shown, e, list(&written));
            tool.exit(EXIT_PARTIAL);
        }
        written.push(&file.shown);
    }
    if stage {
        let mut args = vec!["add", "--"];
        args.extend(written.iter().copied());
        let staged = process::run("git", &args).and_then(|out| if out.success { Ok(()) } else { Err(out.stderr) });
        if let Err(e) = staged {
            eprintln!("{}: all files were written, but `git add` failed: {}. Written, not staged: {}.", tool.name(), e, list(&written));
            tool.exit(EXIT_PARTIAL);
        }
        println!("Done: {}, staged with git add.", totals);
    } else {
        println!("Done: {}.", totals);
    }
    tool.exit(EXIT_OK)
}

fn list(paths: &[&str]) -> String {
    if paths.is_empty() {
        "none".to_string()
    } else {
        paths.join(", ")
    }
}

/// The choice for each block of one file, or every problem with the file's
/// resolutions: a block named twice, a block that does not exist, a block
/// with no resolution.
fn assign<'a>(shown: &str, parsed: &blocks::Parsed, resolutions: &[&'a Resolution]) -> Result<Vec<&'a Choice>, Vec<String>> {
    let count = parsed.blocks.len();
    let mut problems = Vec::new();
    let mut named: Vec<Option<&Resolution>> = vec![None; count];
    let mut rest: Option<&Resolution> = None;
    for &r in resolutions {
        match r.target {
            Target::Block(b) if b > count => problems.push(format!(
                "{} (spec line {}): block {} does not exist; the file has {}. Run 'toolsmith-conflict-resolve --show {}' to see {}.",
                shown,
                r.line,
                b,
                plural(count, "conflict block"),
                shown,
                if count == 1 { "it" } else { "them" }
            )),
            Target::Block(b) => match named[b - 1] {
                Some(earlier) => problems.push(format!(
                    "{} (spec line {}): block {} is already resolved on spec line {}; give each block one resolution.",
                    shown, r.line, b, earlier.line
                )),
                None => named[b - 1] = Some(r),
            },
            Target::Rest => match rest {
                Some(earlier) => problems.push(format!(
                    "{} (spec line {}): a second '*' header for this file (the first is on spec line {}).",
                    shown, r.line, earlier.line
                )),
                None => rest = Some(r),
            },
        }
    }
    let mut choices = Vec::new();
    for (i, r) in named.iter().enumerate() {
        match r.or(rest) {
            Some(r) => choices.push(&r.choice),
            None => problems.push(format!(
                "{}: block {} ({}) has no resolution. Add '@@ {} {} <choice>', or '@@ {} * <choice>' for every block not named.",
                shown,
                i + 1,
                parsed.blocks[i].line_range(),
                shown,
                i + 1,
                shown
            )),
        }
    }
    if problems.is_empty() {
        Ok(choices)
    } else {
        Err(problems)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const TWO: &str = "<<<<<<< H\nA\n=======\nB\n>>>>>>> t\n<<<<<<< H\nC\n=======\nD\n>>>>>>> t\n";

    fn choices(text: &str, spec: &str) -> Result<Vec<&'static str>, Vec<String>> {
        let parsed = blocks::parse(text).unwrap();
        let resolutions: &'static [Resolution] = Box::leak(spec::parse(spec).unwrap().into_boxed_slice());
        let refs: Vec<&Resolution> = resolutions.iter().collect();
        assign("f", &parsed, &refs).map(|c| c.iter().map(|c| c.name()).collect())
    }

    #[test]
    fn a_star_fills_the_blocks_not_named() {
        assert_eq!(choices(TWO, "@@ f 2 ours\n@@ f * theirs\n").unwrap(), vec!["theirs", "ours"]);
    }

    #[test]
    fn every_problem_is_reported() {
        let problems = choices(TWO, "@@ f 1 ours\n@@ f 1 both\n@@ f 4 ours\n").unwrap_err();
        assert_eq!(problems.len(), 3);
        assert!(problems[0].contains("block 1 is already resolved on spec line 1"));
        assert!(problems[1].contains("block 4 does not exist; the file has 2 conflict blocks"));
        assert!(problems[1].ends_with("to see them."));
        assert!(problems[2].contains("block 2 (lines 6-10) has no resolution"));
    }

    #[test]
    fn two_stars_for_one_file_are_a_problem() {
        let problems = choices(TWO, "@@ f * ours\n@@ f * theirs\n").unwrap_err();
        assert_eq!(problems, vec!["f (spec line 2): a second '*' header for this file (the first is on spec line 1)."]);
    }
}
