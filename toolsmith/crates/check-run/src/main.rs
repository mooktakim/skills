//! toolsmith-check-run: runs a check command (tests, lint, an audit), saves
//! its full output to a log file, and prints only the result line, the
//! failure blocks and the summary. See tool.json for the guide that `--llm`
//! prints.

use std::fs::{self, File};
use std::process::{Command, Stdio};
use std::time::{Instant, SystemTime, UNIX_EPOCH};

use toolsmith_common::text::{last_nonblank, strip_ansi};
use toolsmith_common::{Tool, EXIT_FAILED, EXIT_OK};

/// Lines kept from one failure block, and from all blocks together.
const BLOCK_LINES: usize = 25;
const ALL_BLOCK_LINES: usize = 200;

fn main() {
    let tool = Tool::new(include_str!("../tool.json"));
    let args = tool.handle_guide_flags(std::env::args().skip(1).collect());
    let mut tail = 40;
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--lines" => {
                tail = args
                    .get(i + 1)
                    .and_then(|v| v.parse::<usize>().ok())
                    .filter(|n| *n > 0)
                    .unwrap_or_else(|| tool.usage_error("--lines needs a whole number above 0"));
                i += 2;
            }
            "--" => {
                i += 1;
                break;
            }
            a if a.starts_with("--") => tool.usage_error(&format!("unknown option {}", a)),
            _ => break,
        }
    }
    let command = &args[i..];
    if command.is_empty() {
        tool.usage_error("give the check command after the options, e.g. `toolsmith-check-run -- bin/rails test`");
    }
    let shown = command.join(" ");

    let dir = std::env::temp_dir().join("toolsmith-check-run");
    let stamp = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    let log = dir.join(format!("{}-{}.log", stamp, std::process::id()));
    let file = fs::create_dir_all(&dir)
        .and_then(|_| File::create(&log))
        .unwrap_or_else(|e| tool.fail(&format!("cannot create the log file {}: {}", log.display(), e)));
    let errors = file.try_clone().unwrap_or_else(|e| tool.fail(&format!("cannot share the log file: {}", e)));

    let started = Instant::now();
    let status = Command::new(&command[0]).args(&command[1..]).stdin(Stdio::null()).stdout(file).stderr(errors).status();
    let status = match status {
        Ok(status) => status,
        Err(e) => {
            let _ = fs::remove_file(&log);
            tool.fail(&format!("could not start {}: {}", command[0], e));
        }
    };
    let seconds = format!("{:.1}s", started.elapsed().as_secs_f64());
    let output = strip_ansi(&String::from_utf8_lossy(&fs::read(&log).unwrap_or_default()));
    let lines: Vec<&str> = output.lines().collect();

    if status.success() {
        println!("PASSED in {}: {}", seconds, shown);
        for line in last_nonblank(&lines, 2) {
            println!("{}", line);
        }
    } else {
        let code = status.code().map_or("a signal".to_string(), |c| c.to_string());
        println!("FAILED (exit {}) in {}: {}", code, seconds, shown);
        let blocks = failure_blocks(&lines);
        if blocks.is_empty() {
            println!("No failure blocks recognised. Last {} lines:", tail.min(lines.len()));
            for line in &lines[lines.len().saturating_sub(tail)..] {
                println!("{}", line);
            }
        } else {
            let mut printed = 0;
            for block in &blocks {
                if printed + block.len() > ALL_BLOCK_LINES {
                    println!("... {} more failure lines are in the full output.", blocks.iter().map(Vec::len).sum::<usize>() - printed);
                    break;
                }
                println!();
                for line in block {
                    println!("{}", line);
                }
                printed += block.len();
            }
            println!();
            for line in last_nonblank(&lines, 1) {
                println!("{}", line);
            }
        }
    }
    println!("Full output: {} ({} lines)", log.display(), lines.len());
    tool.exit(if status.success() { EXIT_OK } else { EXIT_FAILED });
}

/// "path:12:5: C: message", the one-line offense format of RuboCop and others.
fn is_offense(line: &str) -> bool {
    let parts: Vec<&str> = line.splitn(5, ':').collect();
    parts.len() == 5
        && !parts[0].is_empty()
        && parts[1].chars().all(|c| c.is_ascii_digit())
        && !parts[1].is_empty()
        && parts[2].chars().all(|c| c.is_ascii_digit())
        && !parts[2].is_empty()
        && matches!(parts[3].trim(), "C" | "W" | "E" | "F" | "R")
}

/// Where a failure report starts, for the common test runners and linters.
fn starts_block(line: &str) -> bool {
    let t = line.trim_start();
    let numbered = t.trim_start_matches(|c: char| c.is_ascii_digit());
    (numbered.len() < t.len() && (numbered.starts_with(") Failure") || numbered.starts_with(") Error")))
        || t.starts_with("Failure:")
        || t.starts_with("Error:")
        || t.starts_with("Failure/Error:")
        || t.starts_with("--- FAIL")
        || t.starts_with("FAIL\t")
        || (t.starts_with("thread '") && t.contains("panicked at"))
        || t.starts_with("error[")
        || t.starts_with("error:")
        || t.starts_with("Traceback (most recent call last)")
        || is_offense(t)
}

/// Each failure report: its first line and what follows, up to a blank line
/// or the next report.
fn failure_blocks<'a>(lines: &[&'a str]) -> Vec<Vec<&'a str>> {
    let mut blocks: Vec<Vec<&str>> = Vec::new();
    let mut open = false;
    for line in lines {
        if starts_block(line) {
            blocks.push(vec![line]);
            open = true;
        } else if open && !line.trim().is_empty() && blocks.last().is_some_and(|b| b.len() < BLOCK_LINES) {
            blocks.last_mut().unwrap().push(line);
        } else {
            open = false;
        }
    }
    blocks
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn recognises_failure_starts_of_common_tools() {
        for line in [
            "  1) Failure:",
            "  12) Error:",
            "Failure:",
            "     Failure/Error: expect(x).to eq(1)",
            "--- FAIL: TestRestart (0.01s)",
            "FAIL\texample.com/worker\t0.2s",
            "thread 'tests::x' panicked at src/main.rs:3:5:",
            "error[E0308]: mismatched types",
            "app/models/user.rb:12:5: C: Style/StringLiterals: Prefer double quotes.",
            "Traceback (most recent call last):",
        ] {
            assert!(starts_block(line), "{}", line);
        }
        for line in ["4 runs, 9 assertions, 0 failures", "Finished in 0.1s", "a:b:c: C: x", "12) things"] {
            assert!(!starts_block(line), "{}", line);
        }
    }

    #[test]
    fn blocks_end_at_a_blank_line_or_the_next_start() {
        let lines = ["noise", "  1) Failure:", "T#a [x.rb:3]:", "Expected 1", "", "more noise", "  2) Error:", "boom", "  3) Failure:", "T#c"];
        let blocks = failure_blocks(&lines);
        assert_eq!(blocks, vec![vec!["  1) Failure:", "T#a [x.rb:3]:", "Expected 1"], vec!["  2) Error:", "boom"], vec!["  3) Failure:", "T#c"]]);
    }

    #[test]
    fn long_blocks_are_cut() {
        let mut lines = vec!["Failure:"];
        lines.extend(std::iter::repeat_n("detail", 40));
        assert_eq!(failure_blocks(&lines)[0].len(), BLOCK_LINES);
    }
}
