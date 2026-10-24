//! project-log: checks the work log under docs/log/, as the project's
//! docs/LOG.md describes. Rust standard library only.
//!
//!   project-log lint   check entry names and dates, legacy logs and secrets;
//!                      exit 1 on any problem
//!
//! The project is the nearest directory at or above the current one, up to the
//! git repository root, that has docs/LOG.md, or $LOG_ROOT when set.

// date.rs and scan.rs are byte-identical copies of project-memory's, so not
// every function in them is used here.
#[allow(dead_code)]
mod date;
#[allow(dead_code)]
mod scan;

use std::fs;
use std::path::{Path, PathBuf};
use std::process::exit;

const USAGE: &str = "usage: project-log lint";

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    match args.as_slice() {
        ["lint"] => {}
        ["-h"] | ["--help"] | ["help"] => {
            println!("{}", USAGE);
            return;
        }
        _ => {
            eprintln!("{}", USAGE);
            exit(2);
        }
    }
    let root = find_root().unwrap_or_else(|| {
        eprintln!("project-log: no docs/LOG.md here or above (up to the git root); set up the project log with the project-log skill");
        exit(1);
    });
    lint(&root);
}

fn find_root() -> Option<PathBuf> {
    if let Some(root) = std::env::var_os("LOG_ROOT") {
        let root = PathBuf::from(root);
        return root.join("docs/LOG.md").is_file().then_some(root);
    }
    let cwd = std::env::current_dir().ok()?;
    for dir in cwd.ancestors() {
        if dir.join("docs/LOG.md").is_file() {
            return Some(dir.to_path_buf());
        }
        if dir.join(".git").exists() {
            break;
        }
    }
    None
}

/// Every file under `dir`, sorted. Symlinked folders are not followed.
fn files_under(dir: &Path) -> Vec<PathBuf> {
    let mut out = Vec::new();
    let mut stack = vec![dir.to_path_buf()];
    while let Some(current) = stack.pop() {
        let Ok(entries) = fs::read_dir(&current) else { continue };
        for entry in entries.flatten() {
            let path = entry.path();
            match entry.file_type() {
                Ok(t) if t.is_dir() => stack.push(path),
                _ if path.is_file() => out.push(path),
                _ => {}
            }
        }
    }
    out.sort();
    out
}

fn relative(path: &Path, base: &Path) -> String {
    path.strip_prefix(base).unwrap_or(path).to_string_lossy().replace('\\', "/")
}

fn lint(root: &Path) {
    let docs = root.join("docs");
    let mut problems = Vec::new();
    if docs.join("history").is_dir() {
        problems.push("docs/history/ is a legacy log: migrate it with the project-log skill".to_string());
    }
    if docs.join("HISTORY.md").is_file() {
        problems.push("docs/HISTORY.md is a legacy log: migrate it with the project-log skill".to_string());
    }
    let entries = files_under(&docs.join("log"));
    for file in &entries {
        let shown = relative(file, root);
        match parse_log_name(&relative(file, &docs)) {
            None => problems.push(format!("{}: log entries are named log/YYYY/MM/DD/EPOCH-slug.md", shown)),
            Some((day, epoch)) => {
                let actual = date::utc_path(epoch);
                if actual != day {
                    problems.push(format!("{}: epoch {} is {} in UTC, not {}", shown, epoch, actual, day));
                }
            }
        }
        let bytes = fs::read(file).unwrap_or_default();
        for (index, line) in bytes.split(|&c| c == b'\n').enumerate() {
            for name in scan::secrets(line) {
                problems.push(format!("{}:{}: looks like {}; remove it and rotate it", shown, index + 1, name));
            }
        }
    }
    if problems.is_empty() {
        println!("Log is clean: {} entr{}.", entries.len(), if entries.len() == 1 { "y" } else { "ies" });
        return;
    }
    for problem in &problems {
        println!("{}", problem);
    }
    println!("{} problem(s).", problems.len());
    exit(1);
}

/// The YYYY/MM/DD folder and epoch of a log/YYYY/MM/DD/EPOCH-slug.md path.
fn parse_log_name(name: &str) -> Option<(String, i64)> {
    let digits = |s: &str, n: usize| s.len() == n && s.bytes().all(|c| c.is_ascii_digit());
    let parts: Vec<&str> = name.split('/').collect();
    if parts.len() != 5 || parts[0] != "log" || !digits(parts[1], 4) || !digits(parts[2], 2) || !digits(parts[3], 2) {
        return None;
    }
    let stem = parts[4].strip_suffix(".md")?;
    let (epoch, slug) = stem.split_once('-')?;
    if epoch.is_empty() || !epoch.bytes().all(|c| c.is_ascii_digit()) || slug.is_empty() {
        return None;
    }
    Some((format!("{}/{}/{}", parts[1], parts[2], parts[3]), epoch.parse().ok()?))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn log_names() {
        assert_eq!(parse_log_name("log/2026/10/14/1792015200-billing.md"), Some(("2026/10/14".to_string(), 1_792_015_200)));
        assert_eq!(parse_log_name("log/2026/10/14/notes.md"), None);
        assert_eq!(parse_log_name("log/2026/10/1792015200-x.md"), None);
        assert_eq!(parse_log_name("log/2026/10/14/1792015200-.md"), None);
    }
}
