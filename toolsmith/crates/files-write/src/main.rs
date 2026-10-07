//! toolsmith-files-write: creates several new files from one stdin bundle.
//! Every target is checked before anything is written, and an existing file
//! is never overwritten unless --force is given. See tool.json for the guide
//! that `--llm` prints.

use std::fs;
use std::io::{IsTerminal, Read};
use std::path::Path;

use toolsmith_common::fsutil::write_atomically;
use toolsmith_common::{Tool, EXIT_FAILED, EXIT_OK};

/// A write failed after other files were written.
const EXIT_PARTIAL: i32 = 3;

#[derive(Debug, PartialEq)]
struct NewFile {
    path: String,
    content: String,
    lines: usize,
}

fn main() {
    let tool = Tool::new(include_str!("../tool.json"));
    let args = tool.handle_guide_flags(std::env::args().skip(1).collect());
    let mut force = false;
    let mut marker = "===".to_string();
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--force" => force = true,
            "--marker" => {
                marker = args.get(i + 1).filter(|m| !m.trim().is_empty() && !m.contains(char::is_whitespace)).cloned().unwrap_or_else(|| {
                    tool.usage_error("--marker needs a text without spaces, e.g. --marker '%%%'")
                });
                i += 1;
            }
            other => tool.usage_error(&format!("unknown argument {}", other)),
        }
        i += 1;
    }
    if std::io::stdin().is_terminal() {
        tool.usage_error("reads the files from stdin; pass them with a heredoc (<<'EOF')");
    }
    let mut input = String::new();
    if std::io::stdin().read_to_string(&mut input).is_err() {
        tool.usage_error("the input on stdin is not valid UTF-8");
    }
    let files = parse(&input, &marker).unwrap_or_else(|e| tool.usage_error(&format!("bad input: {}", e)));

    let mut problems: Vec<String> = Vec::new();
    for file in &files {
        let path = Path::new(&file.path);
        if path.is_dir() {
            problems.push(format!("{} is a directory", file.path));
        } else if path.exists() && !force {
            problems.push(format!("{} already exists", file.path));
        }
    }
    if !problems.is_empty() {
        eprintln!("{}: nothing written:", tool.name());
        for problem in &problems {
            eprintln!("  {}", problem);
        }
        eprintln!("Use the Edit tool or toolsmith-text-replace to change an existing file, or --force to replace it.");
        tool.exit(EXIT_FAILED);
    }

    let mut written: Vec<&str> = Vec::new();
    for file in &files {
        let path = Path::new(&file.path);
        let existed = path.exists();
        let result = match path.parent().filter(|p| !p.as_os_str().is_empty()) {
            Some(parent) => fs::create_dir_all(parent),
            None => Ok(()),
        }
        .and_then(|_| write_atomically(path, file.content.as_bytes()));
        if let Err(e) = result {
            eprintln!(
                "{}: writing {} failed: {}. Already written: {}.",
                tool.name(),
                file.path,
                e,
                if written.is_empty() { "none".to_string() } else { written.join(", ") }
            );
            tool.exit(EXIT_PARTIAL);
        }
        let lines = if file.lines == 1 { "1 line".to_string() } else { format!("{} lines", file.lines) };
        println!("{} {} ({})", if existed { "replaced" } else { "created" }, file.path, lines);
        written.push(&file.path);
    }
    println!("Done: {} written.", if files.len() == 1 { "1 file".to_string() } else { format!("{} files", files.len()) });
    tool.exit(EXIT_OK);
}

/// Splits the bundle at marker lines ("=== path"). A file's content is every
/// line up to the next marker, and ends with a newline unless it is empty.
fn parse(input: &str, marker: &str) -> Result<Vec<NewFile>, String> {
    let mut lines: Vec<&str> = if input.is_empty() { Vec::new() } else { input.split('\n').collect() };
    if input.ends_with('\n') {
        lines.pop();
    }
    let mut files: Vec<(String, Vec<&str>)> = Vec::new();
    for (i, line) in lines.iter().enumerate() {
        let header = line.strip_prefix(marker).filter(|rest| rest.is_empty() || rest.starts_with(' '));
        match header {
            Some(rest) => {
                let path = rest.trim();
                if path.is_empty() {
                    return Err(format!("line {}: '{}' needs a file path after it", i + 1, marker));
                }
                if path.ends_with('/') {
                    return Err(format!("line {}: {} is a directory path; give a file path", i + 1, path));
                }
                if files.iter().any(|(p, _)| p == path) {
                    return Err(format!("line {}: {} appears twice", i + 1, path));
                }
                files.push((path.to_string(), Vec::new()));
            }
            None => match files.last_mut() {
                Some((_, content)) => content.push(line),
                None => return Err(format!("line {}: text before the first '{} <path>' line", i + 1, marker)),
            },
        }
    }
    if files.is_empty() {
        return Err(format!("no files: start each file with a line '{} <path>'", marker));
    }
    Ok(files
        .into_iter()
        .map(|(path, content)| NewFile {
            lines: content.len(),
            content: if content.is_empty() { String::new() } else { content.join("\n") + "\n" },
            path,
        })
        .collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_files_at_markers() {
        let files = parse("=== a.rb\nclass A\n\nend\n=== docs/b.md\n# B\n=== empty.txt\n", "===").unwrap();
        assert_eq!(
            files,
            vec![
                NewFile { path: "a.rb".into(), content: "class A\n\nend\n".into(), lines: 3 },
                NewFile { path: "docs/b.md".into(), content: "# B\n".into(), lines: 1 },
                NewFile { path: "empty.txt".into(), content: "".into(), lines: 0 },
            ]
        );
    }

    #[test]
    fn a_marker_needs_a_space_before_the_path() {
        let files = parse("=== a.md\n==== heading\n", "===").unwrap();
        assert_eq!(files[0].content, "==== heading\n");
        assert_eq!(parse("%% a\n=== b\n", "%%").unwrap()[0].content, "=== b\n");
    }

    #[test]
    fn rejects_broken_bundles() {
        for (input, message) in [
            ("", "no files"),
            ("text\n=== a\n", "line 1: text before"),
            ("===\nx\n", "line 1: '===' needs a file path"),
            ("=== a\n=== a\n", "line 2: a appears twice"),
            ("=== dir/\n", "is a directory path"),
        ] {
            let err = parse(input, "===").unwrap_err();
            assert!(err.contains(message), "{:?}: {}", input, err);
        }
    }
}
