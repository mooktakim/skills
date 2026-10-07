//! toolsmith-file-lines: prints numbered line ranges from several files in
//! one call, each under a header, so a file can be read in parts and edited
//! by line number. See tool.json for the guide that `--llm` prints.

use std::fs;

use toolsmith_common::{Tool, EXIT_FAILED, EXIT_OK};

#[derive(Debug, PartialEq)]
enum Part {
    Whole,
    /// First and last line, 1-based and inclusive; `None` runs to the end.
    Lines(usize, Option<usize>),
    /// Every line containing the text, with context lines around it.
    Find(String),
}

fn main() {
    let tool = Tool::new(include_str!("../tool.json"));
    let args = tool.handle_guide_flags(std::env::args().skip(1).collect());
    let mut context = 3;
    let mut specs: Vec<&String> = Vec::new();
    let mut i = 0;
    while i < args.len() {
        if args[i] == "--context" {
            context = args
                .get(i + 1)
                .and_then(|v| v.parse::<usize>().ok())
                .unwrap_or_else(|| tool.usage_error("--context needs a whole number"));
            i += 2;
        } else if args[i].starts_with("--") {
            tool.usage_error(&format!("unknown option {}", args[i]));
        } else {
            specs.push(&args[i]);
            i += 1;
        }
    }
    if specs.is_empty() {
        tool.usage_error("give at least one FILE or FILE:RANGE, e.g. app/models/user.rb:10-40");
    }

    let mut errors = 0;
    let mut first = true;
    for spec in specs {
        let (path, part) = parse_spec(spec).unwrap_or_else(|e| tool.usage_error(&format!("{}: {}", spec, e)));
        let text = match fs::read(&path) {
            Ok(bytes) => String::from_utf8_lossy(&bytes).into_owned(),
            Err(e) => {
                eprintln!("{}: {}: cannot read the file: {}", tool.name(), path, e);
                errors += 1;
                continue;
            }
        };
        match show(&path, &part, &text, context) {
            Ok(block) => {
                if !first {
                    println!();
                }
                print!("{}", block);
                first = false;
            }
            Err(e) => {
                eprintln!("{}: {}", tool.name(), e);
                errors += 1;
            }
        }
    }
    tool.exit(if errors == 0 { EXIT_OK } else { EXIT_FAILED });
}

fn line_number(s: &str) -> Result<usize, String> {
    s.parse::<usize>().ok().filter(|n| *n > 0).ok_or_else(|| format!("\"{}\" is not a line number (lines start at 1)", s))
}

/// "path", "path:12", "path:12-40", "path:12-", "path:12+20" or "path:/text/".
fn parse_spec(spec: &str) -> Result<(String, Part), String> {
    // A search splits at the first ":/", so its text may hold colons.
    let split = match spec.find(":/") {
        Some(at) => Some((&spec[..at], &spec[at + 1..])),
        None => spec.rsplit_once(':'),
    };
    let Some((path, range)) = split else { return Ok((spec.to_string(), Part::Whole)) };
    if path.is_empty() {
        return Err("the file path is missing".to_string());
    }
    let part = if range.starts_with('/') {
        if range.len() < 3 || !range.ends_with('/') {
            return Err("a /text/ search needs text and a closing '/'; quote the whole argument when the text has spaces, e.g. 'app/x.rb:/def call/'".to_string());
        }
        Part::Find(range[1..range.len() - 1].to_string())
    } else if let Some((a, b)) = range.split_once('-') {
        let a = line_number(a)?;
        if b.is_empty() {
            Part::Lines(a, None)
        } else {
            let b = line_number(b)?;
            if b < a {
                return Err(format!("the range ends ({}) before it starts ({})", b, a));
            }
            Part::Lines(a, Some(b))
        }
    } else if let Some((a, n)) = range.split_once('+') {
        let (a, n) = (line_number(a)?, line_number(n)?);
        Part::Lines(a, Some(a + n - 1))
    } else if range.chars().all(|c| c.is_ascii_digit()) && !range.is_empty() {
        let a = line_number(range)?;
        Part::Lines(a, Some(a))
    } else {
        return Ok((spec.to_string(), Part::Whole));
    };
    Ok((path.to_string(), part))
}

fn numbered(lines: &[&str], from: usize, to: usize, width: usize) -> String {
    (from..=to).map(|n| format!("{:>w$}  {}\n", n, lines[n - 1], w = width)).collect()
}

fn show(path: &str, part: &Part, text: &str, context: usize) -> Result<String, String> {
    let mut lines: Vec<&str> = if text.is_empty() { Vec::new() } else { text.split('\n').collect() };
    if text.ends_with('\n') {
        lines.pop();
    }
    let count = lines.len();
    match part {
        Part::Whole => {
            if count == 0 {
                return Ok(format!("==> {} (empty) <==\n", path));
            }
            let size = if count == 1 { "1 line".to_string() } else { format!("{} lines", count) };
            Ok(format!("==> {} ({}) <==\n{}", path, size, numbered(&lines, 1, count, count.to_string().len())))
        }
        Part::Lines(a, b) => {
            if *a > count {
                return Err(format!("{}: starts at line {}, but the file has {} lines", path, a, count));
            }
            let end = b.unwrap_or(count).min(count);
            Ok(format!("==> {}:{}-{} <==\n{}", path, a, end, numbered(&lines, *a, end, end.to_string().len())))
        }
        Part::Find(needle) => {
            let hits: Vec<usize> = lines.iter().enumerate().filter(|(_, l)| l.contains(needle.as_str())).map(|(i, _)| i + 1).collect();
            if hits.is_empty() {
                return Err(format!("{}: no line contains \"{}\"", path, needle));
            }
            let mut windows: Vec<(usize, usize)> = Vec::new();
            for hit in &hits {
                let (from, to) = (hit.saturating_sub(context).max(1), (hit + context).min(count));
                match windows.last_mut() {
                    Some(last) if from <= last.1 + 1 => last.1 = to,
                    _ => windows.push((from, to)),
                }
            }
            let width = windows.last().unwrap().1.to_string().len();
            let body: Vec<String> = windows.iter().map(|(from, to)| numbered(&lines, *from, *to, width)).collect();
            let matches = if hits.len() == 1 { "1 match".to_string() } else { format!("{} matches", hits.len()) };
            Ok(format!("==> {}:/{}/ ({}) <==\n{}", path, needle, matches, body.join("--\n")))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_every_range_form() {
        assert_eq!(parse_spec("a.rb").unwrap(), ("a.rb".into(), Part::Whole));
        assert_eq!(parse_spec("a.rb:7").unwrap(), ("a.rb".into(), Part::Lines(7, Some(7))));
        assert_eq!(parse_spec("a.rb:3-9").unwrap(), ("a.rb".into(), Part::Lines(3, Some(9))));
        assert_eq!(parse_spec("a.rb:3-").unwrap(), ("a.rb".into(), Part::Lines(3, None)));
        assert_eq!(parse_spec("a.rb:3+4").unwrap(), ("a.rb".into(), Part::Lines(3, Some(6))));
        assert_eq!(parse_spec("a.rb:/def x/").unwrap(), ("a.rb".into(), Part::Find("def x".into())));
        assert_eq!(parse_spec("a.yml:/name: shop/").unwrap(), ("a.yml".into(), Part::Find("name: shop".into())));
        assert_eq!(parse_spec("dir:name/a.rb").unwrap(), ("dir:name/a.rb".into(), Part::Whole));
        assert!(parse_spec("a.rb:0-3").unwrap_err().contains("not a line number"));
        assert!(parse_spec("a.rb:9-3").unwrap_err().contains("ends (3) before it starts (9)"));
        assert!(parse_spec("a.rb:/def").unwrap_err().contains("quote the whole argument"));
        assert!(parse_spec("a.rb://").unwrap_err().contains("needs text"));
    }

    #[test]
    fn shows_ranges_clamped_to_the_file() {
        let text = "a\nb\nc\n";
        assert_eq!(show("f", &Part::Lines(2, Some(9)), text, 3).unwrap(), "==> f:2-3 <==\n2  b\n3  c\n");
        assert!(show("f", &Part::Lines(4, None), text, 3).unwrap_err().contains("the file has 3 lines"));
        assert_eq!(show("f", &Part::Whole, "", 3).unwrap(), "==> f (empty) <==\n");
        assert_eq!(show("f", &Part::Whole, "x", 3).unwrap(), "==> f (1 line) <==\n1  x\n");
    }

    #[test]
    fn finds_text_with_merged_context() {
        let text: String = (1..=20).map(|n| if n == 5 || n == 7 || n == 15 { "hit\n".to_string() } else { format!("l{}\n", n) }).collect();
        let out = show("f", &Part::Find("hit".into()), &text, 1).unwrap();
        assert_eq!(out, "==> f:/hit/ (3 matches) <==\n 4  l4\n 5  hit\n 6  l6\n 7  hit\n 8  l8\n--\n14  l14\n15  hit\n16  l16\n");
    }
}
