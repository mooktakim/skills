//! toolsmith-history-add: adds one new entry file to the project's
//! docs/log history, as the project-memory protocol (docs/MEMORY.md)
//! describes: `docs/log/<YYYY>/<MM>/<DD>/<epoch>-<slug>.md` with the UTC date
//! of the epoch, never overwriting an entry, staged so it lands in the same
//! commit as the work. See tool.json for the guide that `--llm` prints.

use std::fs::{self, OpenOptions};
use std::io::{ErrorKind, IsTerminal, Read, Write};
use std::path::{Path, PathBuf};
use std::process::Command;

use toolsmith_common::{Tool, EXIT_OK};

const SLUG_MAX: usize = 60;

fn main() {
    let tool = Tool::new(include_str!("../tool.json"));
    let args = tool.handle_guide_flags(std::env::args().skip(1).collect());
    let mut stage = true;
    let mut title: Option<String> = None;
    for arg in args {
        if arg == "--no-stage" {
            stage = false;
        } else if arg.starts_with('-') {
            tool.usage_error(&format!("unknown option {}", arg));
        } else if title.is_some() {
            tool.usage_error("give the title as one argument; quote it when it has spaces");
        } else {
            title = Some(arg);
        }
    }
    let title = title.unwrap_or_else(|| tool.usage_error("give the entry's title as the first argument"));
    let slug = slugify(&title);
    if slug.is_empty() {
        tool.usage_error("the title has no letters or digits to make a file name from");
    }
    if std::io::stdin().is_terminal() {
        tool.usage_error("reads the entry text from stdin; pass it with a heredoc (<<'EOF')");
    }
    let mut body = String::new();
    if std::io::stdin().read_to_string(&mut body).is_err() {
        tool.usage_error("the entry text on stdin is not valid UTF-8");
    }
    if body.trim().is_empty() {
        tool.usage_error("the entry text on stdin is empty");
    }
    if !body.ends_with('\n') {
        body.push('\n');
    }

    let cwd = std::env::current_dir().unwrap_or_else(|e| tool.fail(&format!("cannot read the current directory: {}", e)));
    let in_git = cwd.ancestors().any(|d| d.join(".git").exists());
    let base = match find_base(&cwd) {
        Base::Memory(base) => base,
        Base::Legacy(base) => tool.fail(&format!(
            "{} still has the legacy docs/history log; migrate it to docs/log with the project-memory skill first",
            shown_path(&base, &cwd)
        )),
        Base::None => tool.fail(
            "no docs/MEMORY.md or docs/log above here; set up project memory with the project-memory skill first",
        ),
    };
    let (day, epoch) = now().unwrap_or_else(|e| tool.fail(&e));
    let dir = base.join("docs/log").join(&day);
    if let Err(e) = fs::create_dir_all(&dir) {
        tool.fail(&format!("cannot create {}: {}", dir.display(), e));
    }
    let file = dir.join(format!("{}-{}.md", epoch, slug));
    let shown = shown_path(&file, &cwd);
    match OpenOptions::new().write(true).create_new(true).open(&file) {
        Ok(mut handle) => {
            if let Err(e) = handle.write_all(body.as_bytes()) {
                tool.fail(&format!("writing {} failed: {}", shown, e));
            }
        }
        Err(e) if e.kind() == ErrorKind::AlreadyExists => tool.fail(&format!(
            "{} already exists, and history entries are never overwritten. Use a different title.",
            shown
        )),
        Err(e) => tool.fail(&format!("cannot create {}: {}", shown, e)),
    }
    if stage && in_git {
        let added = Command::new("git").arg("add").arg("--").arg(&file).current_dir(&cwd).output();
        match added {
            Ok(out) if out.status.success() => {}
            Ok(out) => tool.fail(&format!(
                "wrote {} but `git add` failed: {}",
                shown,
                String::from_utf8_lossy(&out.stderr).trim()
            )),
            Err(e) => tool.fail(&format!("wrote {} but could not run git: {}", shown, e)),
        }
    }
    println!("{}", shown);
    tool.exit(EXIT_OK);
}

/// Lowercase ASCII letters and digits joined by single hyphens, at most
/// SLUG_MAX characters, cut at a hyphen when possible.
fn slugify(title: &str) -> String {
    let mut slug = String::new();
    for c in title.chars() {
        if c.is_ascii_alphanumeric() {
            slug.push(c.to_ascii_lowercase());
        } else if !slug.is_empty() && !slug.ends_with('-') {
            slug.push('-');
        }
    }
    while slug.ends_with('-') {
        slug.pop();
    }
    if slug.len() > SLUG_MAX {
        let cut = slug[..=SLUG_MAX].rfind('-').filter(|&i| i > 0).unwrap_or(SLUG_MAX);
        slug.truncate(cut);
    }
    slug
}

#[derive(Debug, PartialEq)]
enum Base {
    /// A project with project memory: docs/MEMORY.md or docs/log.
    Memory(PathBuf),
    /// A project that still has the old docs/history or docs/HISTORY.md log.
    Legacy(PathBuf),
    None,
}

/// The nearest directory at or above `cwd` that has project memory, looking
/// no higher than the git repository root.
fn find_base(cwd: &Path) -> Base {
    for dir in cwd.ancestors() {
        let docs = dir.join("docs");
        if docs.join("MEMORY.md").is_file() || docs.join("log").is_dir() {
            return Base::Memory(dir.to_path_buf());
        }
        if docs.join("history").is_dir() || docs.join("HISTORY.md").is_file() {
            return Base::Legacy(dir.to_path_buf());
        }
        if dir.join(".git").exists() {
            break;
        }
    }
    Base::None
}

/// Today's UTC date as YYYY/MM/DD and the Unix time, read in one `date` call
/// so they agree.
fn now() -> Result<(String, String), String> {
    let out = Command::new("date")
        .arg("-u")
        .arg("+%Y/%m/%d %s")
        .output()
        .map_err(|e| format!("could not run date: {}", e))?;
    let text = String::from_utf8_lossy(&out.stdout);
    let mut parts = text.split_whitespace();
    match (parts.next(), parts.next()) {
        (Some(day), Some(epoch)) if out.status.success() => Ok((day.to_string(), epoch.to_string())),
        _ => Err(format!("unexpected output from date: {}", text.trim())),
    }
}

/// `file` relative to `cwd`, climbing with `..` when it is not below it.
fn shown_path(file: &Path, cwd: &Path) -> String {
    let file_parts: Vec<_> = file.components().collect();
    let cwd_parts: Vec<_> = cwd.components().collect();
    let shared = file_parts.iter().zip(&cwd_parts).take_while(|(a, b)| a == b).count();
    if shared == 0 {
        return file.display().to_string();
    }
    let mut out = PathBuf::new();
    for _ in shared..cwd_parts.len() {
        out.push("..");
    }
    for part in &file_parts[shared..] {
        out.push(part);
    }
    if out.as_os_str().is_empty() {
        return ".".to_string();
    }
    out.display().to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn slugs_are_kebab_case_ascii() {
        assert_eq!(slugify("SEO review: staging (2nd pass)"), "seo-review-staging-2nd-pass");
        assert_eq!(slugify("  --Already-kebab--  "), "already-kebab");
        assert_eq!(slugify("Café déjà vu"), "caf-d-j-vu");
        assert_eq!(slugify("!!!"), "");
    }

    #[test]
    fn long_slugs_are_cut_at_a_hyphen() {
        let slug = slugify(&"word ".repeat(30));
        assert!(slug.len() <= SLUG_MAX);
        assert!(slug.ends_with("word"));
        assert_eq!(slugify(&"x".repeat(80)).len(), SLUG_MAX);
    }

    #[test]
    fn paths_are_shown_relative_to_the_current_directory() {
        let file = Path::new("/r/apps/web/docs/log/d/1-x.md");
        assert_eq!(shown_path(file, Path::new("/r/apps/web")), "docs/log/d/1-x.md");
        assert_eq!(shown_path(file, Path::new("/r/apps/web/app/models")), "../../docs/log/d/1-x.md");
    }

    #[test]
    fn the_nearest_project_memory_wins_up_to_the_git_root() {
        let outer = std::env::temp_dir().join(format!("toolsmith-history-{}", std::process::id()));
        let root = outer.join("repo");
        let sub = root.join("apps/web/app");
        fs::create_dir_all(&sub).unwrap();
        fs::create_dir_all(root.join(".git")).unwrap();
        fs::create_dir_all(outer.join("docs/log")).unwrap();
        assert_eq!(find_base(&sub), Base::None, "never above the git root");
        fs::create_dir_all(root.join("docs")).unwrap();
        fs::write(root.join("docs/MEMORY.md"), "x").unwrap();
        assert_eq!(find_base(&sub), Base::Memory(root.clone()));
        fs::create_dir_all(root.join("apps/web/docs/history")).unwrap();
        assert_eq!(find_base(&sub), Base::Legacy(root.join("apps/web")));
        fs::create_dir_all(root.join("apps/web/docs/log")).unwrap();
        assert_eq!(find_base(&sub), Base::Memory(root.join("apps/web")));
        fs::remove_dir_all(&outer).unwrap();
    }
}
