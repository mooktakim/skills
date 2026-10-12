//! toolsmith-ci-wait: waits for the GitHub Actions runs of one commit to
//! finish, then prints one line per run (or per job, when something failed)
//! and the end of each failed job's log. Talks to GitHub through `gh`. See
//! tool.json for the guide that `--llm` prints.

use std::thread::sleep;
use std::time::{Duration, Instant};

use toolsmith_common::process::run;
use toolsmith_common::text::strip_ansi;
use toolsmith_common::{Tool, Value, EXIT_FAILED, EXIT_OK};

/// No runs appeared for the commit, or they did not finish in time.
const EXIT_NO_RESULT: i32 = 3;
/// How long to wait for the first run to appear after a push.
const APPEAR_SECONDS: u64 = 120;
const PASSED: [&str; 3] = ["success", "skipped", "neutral"];

struct Options {
    pr: Option<String>,
    commit: Option<String>,
    timeout_minutes: u64,
    interval_seconds: u64,
    lines: usize,
}

struct Run {
    id: String,
    name: String,
    status: String,
    conclusion: String,
}

fn main() {
    let tool = Tool::new(include_str!("../tool.json"));
    let args = tool.handle_guide_flags(std::env::args().skip(1).collect());
    let options = parse_options(&tool, &args);
    let sha = resolve_commit(&tool, &options);
    let short: String = sha.chars().take(7).collect();

    let started = Instant::now();
    let appear = Duration::from_secs(APPEAR_SECONDS.min(options.timeout_minutes * 60));
    let deadline = Duration::from_secs(options.timeout_minutes * 60);
    let runs = loop {
        let runs = list_runs(&tool, &sha);
        if runs.is_empty() && started.elapsed() >= appear {
            eprintln!(
                "{}: no CI runs for {} after {} seconds. Check that the commit is pushed and that a workflow runs on it.",
                tool.name(),
                short,
                appear.as_secs()
            );
            tool.exit(EXIT_NO_RESULT);
        }
        if !runs.is_empty() && runs.iter().all(|r| r.status == "completed") {
            break runs;
        }
        if started.elapsed() >= deadline {
            let waiting: Vec<String> = runs.iter().filter(|r| r.status != "completed").map(|r| format!("{} ({})", r.name, r.status)).collect();
            eprintln!(
                "{}: still running after {} minutes: {}. Run the command again to keep waiting.",
                tool.name(),
                options.timeout_minutes,
                waiting.join(", ")
            );
            tool.exit(EXIT_NO_RESULT);
        }
        sleep(Duration::from_secs(options.interval_seconds));
    };

    let failed: Vec<&Run> = runs.iter().filter(|r| !PASSED.contains(&r.conclusion.as_str())).collect();
    if failed.is_empty() {
        println!("CI for {}: {}, all passed.", short, plural(runs.len(), "run"));
        for run in &runs {
            println!("  {:<9} {}", run.conclusion, run.name);
        }
        tool.exit(EXIT_OK);
    }

    let mut rows: Vec<(String, String, String)> = Vec::new();
    for run in &runs {
        for (name, conclusion) in jobs(&tool, run) {
            rows.push((conclusion, name, run.name.clone()));
        }
    }
    let failed_jobs = rows.iter().filter(|(c, _, _)| !PASSED.contains(&c.as_str())).count();
    println!(
        "CI for {}: {}, {}, {} failed.",
        short,
        plural(runs.len(), "run"),
        plural(rows.len(), "job"),
        failed_jobs
    );
    for (conclusion, name, workflow) in &rows {
        println!("  {:<9} {} ({})", conclusion, name, workflow);
    }
    for run in failed {
        print_failed_logs(run, options.lines);
    }
    tool.exit(EXIT_FAILED);
}

fn plural(n: usize, word: &str) -> String {
    format!("{} {}{}", n, word, if n == 1 { "" } else { "s" })
}

fn number(tool: &Tool, flag: &str, value: Option<&String>) -> u64 {
    value
        .and_then(|v| v.parse::<u64>().ok())
        .filter(|n| *n > 0)
        .unwrap_or_else(|| tool.usage_error(&format!("{} needs a whole number above 0", flag)))
}

fn parse_options(tool: &Tool, args: &[String]) -> Options {
    let mut options = Options { pr: None, commit: None, timeout_minutes: 30, interval_seconds: 15, lines: 40 };
    let mut i = 0;
    while i < args.len() {
        let value = args.get(i + 1);
        match args[i].as_str() {
            "--pr" => options.pr = Some(number(tool, "--pr", value).to_string()),
            "--commit" => {
                options.commit = Some(value.cloned().unwrap_or_else(|| tool.usage_error("--commit needs a commit SHA or ref")))
            }
            "--timeout" => options.timeout_minutes = number(tool, "--timeout", value),
            "--interval" => options.interval_seconds = number(tool, "--interval", value),
            "--lines" => options.lines = number(tool, "--lines", value) as usize,
            // A bare argument is the commit: `toolsmith-ci-wait $(git rev-parse HEAD)`.
            other if !other.starts_with('-') && options.commit.is_none() => {
                options.commit = Some(other.to_string());
                i += 1;
                continue;
            }
            other => tool.usage_error(&format!("unknown argument {}", other)),
        }
        i += 2;
    }
    if options.pr.is_some() && options.commit.is_some() {
        tool.usage_error("give --pr or --commit, not both");
    }
    options
}

fn gh(tool: &Tool, args: &[&str]) -> String {
    match run("gh", args) {
        Ok(out) if out.success => out.stdout,
        Ok(out) => tool.fail(&format!("`gh {}` failed: {}", args.join(" "), out.stderr)),
        Err(e) => tool.fail(&format!("{}. Install the GitHub CLI (gh) and sign in with `gh auth login`.", e)),
    }
}

fn parse_json(tool: &Tool, text: &str) -> Value {
    Value::parse(text).unwrap_or_else(|e| tool.fail(&format!("unexpected output from gh: {}", e)))
}

fn field(value: &Value, key: &str) -> String {
    match value.get(key) {
        Some(Value::String(s)) => s.clone(),
        Some(Value::Number(n)) => n.clone(),
        _ => String::new(),
    }
}

fn resolve_commit(tool: &Tool, options: &Options) -> String {
    if let Some(pr) = &options.pr {
        let view = parse_json(tool, &gh(tool, &["pr", "view", pr, "--json", "headRefOid"]));
        return field(&view, "headRefOid");
    }
    if let Some(commit) = &options.commit {
        return match run("git", &["rev-parse", "--verify", "--quiet", &format!("{}^{{commit}}", commit)]) {
            Ok(out) if out.success => out.stdout.trim().to_string(),
            _ => commit.clone(),
        };
    }
    let head = match run("git", &["rev-parse", "HEAD"]) {
        Ok(out) if out.success => out.stdout.trim().to_string(),
        _ => tool.fail("cannot read HEAD: not in a git repository with a commit; give --commit or --pr"),
    };
    let pushed = run("git", &["branch", "-r", "--contains", &head]).map(|o| !o.stdout.trim().is_empty()).unwrap_or(false);
    if !pushed {
        eprintln!(
            "{}: HEAD ({}) is not on any remote branch, so CI cannot have run on it. Push it first.",
            tool.name(),
            &head[..7.min(head.len())]
        );
        tool.exit(EXIT_NO_RESULT);
    }
    head
}

fn list_runs(tool: &Tool, sha: &str) -> Vec<Run> {
    let out = gh(tool, &["run", "list", "--commit", sha, "--json", "databaseId,name,status,conclusion", "--limit", "100"]);
    parse_json(tool, &out)
        .as_array()
        .unwrap_or(&[])
        .iter()
        .map(|r| Run { id: field(r, "databaseId"), name: field(r, "name"), status: field(r, "status"), conclusion: field(r, "conclusion") })
        .collect()
}

fn jobs(tool: &Tool, run: &Run) -> Vec<(String, String)> {
    let view = parse_json(tool, &gh(tool, &["run", "view", &run.id, "--json", "jobs"]));
    let jobs = view.get("jobs").and_then(Value::as_array).unwrap_or(&[]);
    jobs.iter().map(|j| (field(j, "name"), field(j, "conclusion"))).collect()
}

/// A failed-step log line is "job<TAB>step<TAB>[BOM]timestamp text".
fn log_text(rest: &str) -> String {
    let rest = rest.trim_start_matches('\u{feff}');
    let rest = match rest.split_once(' ') {
        Some((stamp, text)) if stamp.len() >= 20 && stamp.ends_with('Z') && stamp.as_bytes()[4] == b'-' => text,
        _ => rest,
    };
    strip_ansi(rest)
}

fn print_failed_logs(ci_run: &Run, lines: usize) {
    let log = match run("gh", &["run", "view", &ci_run.id, "--log-failed"]) {
        Ok(out) if out.success => out.stdout,
        _ => {
            println!("\n(The log of run {} is not available yet: `gh run view {} --log-failed`.)", ci_run.id, ci_run.id);
            return;
        }
    };
    let mut jobs: Vec<(String, Vec<String>)> = Vec::new();
    for line in log.lines() {
        let mut parts = line.splitn(3, '\t');
        let (Some(job), Some(_step), Some(rest)) = (parts.next(), parts.next(), parts.next()) else { continue };
        let text = log_text(rest);
        if text.starts_with("##[group]") || text.starts_with("##[endgroup]") {
            continue;
        }
        match jobs.iter_mut().find(|(name, _)| name == job) {
            Some((_, kept)) => kept.push(text),
            None => jobs.push((job.to_string(), vec![text])),
        }
    }
    for (job, kept) in jobs {
        let start = kept.len().saturating_sub(lines);
        println!("\n== {}: last {} log lines ==", job, kept.len() - start);
        for line in &kept[start..] {
            println!("{}", line);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn log_lines_lose_their_mark_timestamp_and_colours() {
        assert_eq!(log_text("\u{feff}2026-10-07T20:24:34.6249224Z \u{1b}[36;1mbin/test\u{1b}[0m"), "bin/test");
        assert_eq!(log_text("2026-10-07T20:25:06.7480034Z ToolsmithTest#x [a.rb:261]:"), "ToolsmithTest#x [a.rb:261]:");
        assert_eq!(log_text("no stamp here"), "no stamp here");
    }
}
