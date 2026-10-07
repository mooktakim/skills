//! toolsmith-text-replace: replaces exact, literal text in existing files as
//! one all-or-nothing change. Every edit is checked in memory first; files are
//! written only when all of them match as expected. See tool.json for the
//! guide that `--llm` prints.

mod edit;
mod spec;

use std::collections::HashMap;
use std::fs;
use std::io::{IsTerminal, Read};
use std::path::PathBuf;

use toolsmith_common::fsutil::write_atomically;
use toolsmith_common::{Tool, EXIT_FAILED, EXIT_OK};

/// Exit code when a write failed after others succeeded.
const EXIT_PARTIAL: i32 = 3;

struct File {
    shown: String,
    real: PathBuf,
    before: Vec<u8>,
    after: Vec<u8>,
    failed: bool,
}

fn main() {
    let tool = Tool::new(include_str!("../tool.json"));
    let args = tool.handle_guide_flags(std::env::args().skip(1).collect());
    let mut dry_run = false;
    for arg in &args {
        match arg.as_str() {
            "--dry-run" => dry_run = true,
            other => tool.usage_error(&format!("unknown argument {}", other)),
        }
    }
    if std::io::stdin().is_terminal() {
        tool.usage_error("reads the edit spec from stdin; pass it with a heredoc (<<'EOF')");
    }
    let mut input = String::new();
    if std::io::stdin().read_to_string(&mut input).is_err() {
        tool.usage_error("the edit spec on stdin is not valid UTF-8");
    }
    let blocks = spec::parse(&input).unwrap_or_else(|e| tool.usage_error(&format!("bad spec: {}", e)));

    let mut files: Vec<File> = Vec::new();
    let mut index: HashMap<PathBuf, usize> = HashMap::new();
    let mut report = String::new();
    let mut failures: Vec<String> = Vec::new();
    let mut skipped = 0;
    let mut replacements = 0;
    let edit_count: usize = blocks.iter().map(|b| b.edits.len()).sum();

    for block in &blocks {
        let real = match fs::canonicalize(&block.path) {
            Ok(real) => real,
            Err(e) => {
                failures.push(format!(
                    "{} (spec line {}): cannot read the file: {}. This tool only edits existing files.",
                    block.path, block.line, e
                ));
                continue;
            }
        };
        let at = match index.get(&real) {
            Some(&at) => at,
            None => match fs::read(&real) {
                Ok(bytes) => {
                    files.push(File { shown: block.path.clone(), real: real.clone(), before: bytes.clone(), after: bytes, failed: false });
                    index.insert(real, files.len() - 1);
                    files.len() - 1
                }
                Err(e) => {
                    failures.push(format!("{} (spec line {}): cannot read the file: {}.", block.path, block.line, e));
                    continue;
                }
            },
        };
        let file = &mut files[at];
        for edit in &block.edits {
            if file.failed {
                skipped += 1;
                continue;
            }
            match edit::apply(&file.after, edit, block.expect) {
                Ok((after, change)) => {
                    file.after = after;
                    replacements += change.lines.len();
                    report.push_str(&describe(&block.path, &change));
                }
                Err(why) => {
                    file.failed = true;
                    failures.push(format!("{} (spec line {}): {}", block.path, edit.line, why));
                }
            }
        }
    }

    if !failures.is_empty() {
        let mut message = format!(
            "{}: nothing written: {} of {} failed.\n",
            tool.name(),
            failures.len(),
            plural(edit_count, "edit")
        );
        for failure in &failures {
            message.push_str(&format!("\n{}\n", failure));
        }
        if skipped > 0 {
            message.push_str(&format!("\n{} later edits in a file with a failed edit were not checked.\n", skipped));
        }
        eprint!("{}", message);
        tool.exit(EXIT_FAILED);
    }

    let changed: Vec<&File> = files.iter().filter(|f| f.after != f.before).collect();
    print!("{}", report);
    if dry_run {
        println!("Dry run: {} would be made; nothing written.", totals(replacements, changed.len()));
        tool.exit(EXIT_OK);
    }
    let mut written: Vec<&str> = Vec::new();
    for file in &changed {
        if let Err(e) = write_atomically(&file.real, &file.after) {
            eprintln!(
                "{}: writing {} failed: {}. Already written: {}.",
                tool.name(),
                file.shown,
                e,
                if written.is_empty() { "none".to_string() } else { written.join(", ") }
            );
            tool.exit(EXIT_PARTIAL);
        }
        written.push(&file.shown);
    }
    println!("Done: {}.", totals(replacements, changed.len()));
    tool.exit(EXIT_OK);
}

fn plural(n: usize, word: &str) -> String {
    format!("{} {}{}", n, word, if n == 1 { "" } else { "s" })
}

fn totals(replacements: usize, files: usize) -> String {
    format!("{} in {}", plural(replacements, "replacement"), plural(files, "file"))
}

/// Lines shown per side of a change; longer sides show their start and end.
const SHOWN_LINES: usize = 6;

fn shorten(lines: &[String]) -> Vec<String> {
    if lines.len() <= SHOWN_LINES {
        return lines.to_vec();
    }
    let mut out = lines[..3].to_vec();
    out.push(format!("... ({} more lines)", lines.len() - 5));
    out.extend_from_slice(&lines[lines.len() - 2..]);
    out
}

fn describe(path: &str, change: &edit::Change) -> String {
    let lines: Vec<String> = change.lines.iter().map(usize::to_string).collect();
    let mut out = if change.lines.len() == 1 {
        format!("{}:{}\n", path, lines[0])
    } else {
        format!("{}:{} ({} replacements, first shown)\n", path, lines.join(","), change.lines.len())
    };
    for line in shorten(&change.before) {
        out.push_str(&format!("- {}\n", line));
    }
    for line in shorten(&change.after) {
        out.push_str(&format!("+ {}\n", line));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn long_changes_show_their_start_and_end() {
        let lines: Vec<String> = (1..=10).map(|n| n.to_string()).collect();
        assert_eq!(shorten(&lines), vec!["1", "2", "3", "... (5 more lines)", "9", "10"]);
        assert_eq!(shorten(&lines[..6]), lines[..6].to_vec());
    }
}
