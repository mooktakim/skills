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

fn describe(path: &str, change: &edit::Change) -> String {
    let lines: Vec<String> = change.lines.iter().map(usize::to_string).collect();
    let mut out = if change.lines.len() == 1 {
        format!("{}:{}\n", path, lines[0])
    } else {
        format!("{}:{} ({} replacements, first shown)\n", path, lines.join(","), change.lines.len())
    };
    for line in &change.before {
        out.push_str(&format!("- {}\n", line));
    }
    for line in &change.after {
        out.push_str(&format!("+ {}\n", line));
    }
    out
}

/// Writes through a temporary file in the same directory and renames it over
/// the original, keeping the original's permissions.
fn write_atomically(path: &PathBuf, contents: &[u8]) -> std::io::Result<()> {
    let permissions = fs::metadata(path)?.permissions();
    let name = path.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
    let temp = path.with_file_name(format!(".{}.toolsmith-{}", name, std::process::id()));
    let result = fs::write(&temp, contents)
        .and_then(|_| fs::set_permissions(&temp, permissions))
        .and_then(|_| fs::rename(&temp, path));
    if result.is_err() {
        let _ = fs::remove_file(&temp);
    }
    result
}
