//! Applies one edit to a file's contents in memory: counts the matches,
//! checks them against what the block expects, replaces them, and describes
//! the change - or, when the count is wrong, explains why it did not match.

use crate::spec::{Edit, Expect};

/// The first changed span, shown as whole lines before and after.
pub struct Change {
    pub lines: Vec<usize>,
    pub before: Vec<String>,
    pub after: Vec<String>,
}

const SHOWN_WIDTH: usize = 160;

/// Starts of the non-overlapping occurrences of `needle`, left to right.
pub fn find_all(hay: &[u8], needle: &[u8]) -> Vec<usize> {
    let mut found = Vec::new();
    if needle.is_empty() || needle.len() > hay.len() {
        return found;
    }
    let mut i = 0;
    while i + needle.len() <= hay.len() {
        if hay[i] == needle[0] && &hay[i..i + needle.len()] == needle {
            found.push(i);
            i += needle.len();
        } else {
            i += 1;
        }
    }
    found
}

fn line_of(buf: &[u8], pos: usize) -> usize {
    buf[..pos].iter().filter(|&&b| b == b'\n').count() + 1
}

fn shown(line: &str) -> String {
    if line.chars().count() > SHOWN_WIDTH {
        let cut: String = line.chars().take(SHOWN_WIDTH).collect();
        format!("{}...", cut)
    } else {
        line.to_string()
    }
}

/// The whole lines that hold `buf[start..start + len]`. A zero-length span at
/// a line start, left by deleting whole lines, holds no lines.
fn lines_around(buf: &[u8], start: usize, len: usize) -> Vec<String> {
    let line_start = buf[..start].iter().rposition(|&b| b == b'\n').map_or(0, |p| p + 1);
    if len == 0 && start == line_start {
        return Vec::new();
    }
    let end = start + len;
    let line_end = if len > 0 && buf[end - 1] == b'\n' {
        end - 1
    } else {
        buf[end..].iter().position(|&b| b == b'\n').map_or(buf.len(), |p| end + p)
    };
    String::from_utf8_lossy(&buf[line_start..line_end]).split('\n').map(shown).collect()
}

/// Applies `edit` to `buf` and returns the new contents and the change, or an
/// explanation of why the match count was wrong.
pub fn apply(buf: &[u8], edit: &Edit, expect: Expect) -> Result<(Vec<u8>, Change), String> {
    let old = edit.old.as_bytes();
    let found = find_all(buf, old);
    let lines: Vec<usize> = found.iter().map(|&p| line_of(buf, p)).collect();
    let ok = match expect {
        Expect::Exactly(n) => found.len() == n,
        Expect::AtLeastOne => !found.is_empty(),
    };
    if !ok {
        return Err(count_error(buf, edit, expect, &lines));
    }
    let mut out = Vec::with_capacity(buf.len());
    let mut last = 0;
    for &pos in &found {
        out.extend_from_slice(&buf[last..pos]);
        out.extend_from_slice(edit.new.as_bytes());
        last = pos + old.len();
    }
    out.extend_from_slice(&buf[last..]);
    let change = Change {
        before: lines_around(buf, found[0], old.len()),
        after: lines_around(&out, found[0], edit.new.len()),
        lines,
    };
    Ok((out, change))
}

fn join_lines(lines: &[usize]) -> String {
    lines.iter().map(usize::to_string).collect::<Vec<_>>().join(", ")
}

fn count_error(buf: &[u8], edit: &Edit, expect: Expect, lines: &[usize]) -> String {
    let wanted = match expect {
        Expect::Exactly(n) => format!("expected {}", n),
        Expect::AtLeastOne => "expected at least 1".to_string(),
    };
    if !lines.is_empty() {
        let mut message = format!("found {} matches (lines {}), {}.", lines.len(), join_lines(lines), wanted);
        if expect == Expect::Exactly(1) {
            message.push_str(&format!(
                "\n  Add surrounding text to the '-' lines to make the match unique, or put --all or --count {} on the '@@' line.",
                lines.len()
            ));
        }
        return message;
    }
    let mut message = format!("found 0 matches, {}.", wanted);
    let text = String::from_utf8_lossy(buf);
    if text.contains("\r\n") && !edit.old.contains('\r') {
        message.push_str("\n  The file uses CRLF line endings; this tool matches text with LF line endings only.");
    }
    message.push_str(&near_miss(&text, &edit.old));
    message
}

fn squeeze(s: &str) -> String {
    s.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn words(s: &str) -> Vec<&str> {
    s.split(|c: char| !c.is_alphanumeric() && c != '_').filter(|w| !w.is_empty()).collect()
}

/// Shared words over all distinct words, 0.0 to 1.0.
fn likeness(a: &str, b: &str) -> f64 {
    let (a, b) = (words(a), words(b));
    if a.is_empty() || b.is_empty() {
        return 0.0;
    }
    let shared = a.iter().filter(|w| b.contains(w)).count();
    shared as f64 / (a.len() + b.len() - shared) as f64
}

/// Explains the closest thing in the file to the '-' text, so the next try
/// can be right: where a multi-line match breaks, or which lines look alike.
fn near_miss(text: &str, old: &str) -> String {
    let file: Vec<&str> = text.split('\n').collect();
    let want: Vec<&str> = old.split('\n').collect();

    if want.len() > 1 {
        for (i, line) in file.iter().enumerate() {
            if !line.ends_with(want[0]) || want[0].trim().is_empty() {
                continue;
            }
            for (k, wanted) in want.iter().enumerate().skip(1) {
                let Some(actual) = file.get(i + k) else { break };
                let last = k == want.len() - 1;
                let same = if last { actual.starts_with(wanted) } else { actual == wanted };
                if !same {
                    return format!(
                        "\n  The first '-' line matches file line {}, but the text differs at file line {}:\n    file line {}: |{}|\n    '-' line {}:  |{}|",
                        i + 1,
                        i + k + 1,
                        i + k + 1,
                        shown(actual),
                        k + 1,
                        shown(wanted)
                    );
                }
            }
        }
    }

    let anchor = want.iter().find(|l| !l.trim().is_empty()).copied().unwrap_or("");
    let mut scored: Vec<(f64, usize)> = file
        .iter()
        .enumerate()
        .map(|(i, line)| {
            let score = if !anchor.trim().is_empty() && squeeze(line).contains(&squeeze(anchor)) {
                1.0
            } else {
                likeness(line, anchor)
            };
            (score, i)
        })
        .filter(|(score, _)| *score >= 0.5)
        .collect();
    scored.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap().then(a.1.cmp(&b.1)));
    if scored.is_empty() {
        return "\n  No similar lines in the file. Check the path and the text.".to_string();
    }
    let mut out = String::from("\n  Lines in the file most like the first '-' line:");
    for (score, i) in scored.iter().take(3) {
        let note = if *score == 1.0 { "  (same words, different spacing)" } else { "" };
        out.push_str(&format!("\n    {}: |{}|{}", i + 1, shown(file[*i]), note));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn e(old: &str, new: &str) -> Edit {
        Edit { old: old.into(), new: new.into(), line: 1 }
    }

    #[test]
    fn finds_non_overlapping_matches() {
        assert_eq!(find_all(b"aaaa", b"aa"), vec![0, 2]);
        assert_eq!(find_all(b"abc", b"x"), Vec::<usize>::new());
        assert_eq!(find_all(b"ab", b"abc"), Vec::<usize>::new());
    }

    #[test]
    fn replaces_one_match_and_shows_whole_lines() {
        let (out, change) = apply(b"a\nkey: 1\nb\n", &e("1", "2"), Expect::Exactly(1)).unwrap();
        assert_eq!(out, b"a\nkey: 2\nb\n");
        assert_eq!(change.lines, vec![2]);
        assert_eq!(change.before, vec!["key: 1"]);
        assert_eq!(change.after, vec!["key: 2"]);
    }

    #[test]
    fn deleting_whole_lines_shows_no_after_lines() {
        let (out, change) = apply(b"a\ngone\nb\n", &e("gone\n", ""), Expect::Exactly(1)).unwrap();
        assert_eq!(out, b"a\nb\n");
        assert_eq!(change.before, vec!["gone"]);
        assert!(change.after.is_empty());
    }

    #[test]
    fn all_and_count_replace_every_match() {
        let (out, change) = apply(b"x y x\nx\n", &e("x", "z"), Expect::AtLeastOne).unwrap();
        assert_eq!(out, b"z y z\nz\n");
        assert_eq!(change.lines, vec![1, 1, 2]);
        assert!(apply(b"x x", &e("x", "z"), Expect::Exactly(2)).is_ok());
    }

    #[test]
    fn wrong_counts_explain_themselves() {
        let many = apply(b"x\nx\n", &e("x", "y"), Expect::Exactly(1)).err().unwrap();
        assert!(many.contains("found 2 matches (lines 1, 2), expected 1."), "{}", many);
        assert!(many.contains("--count 2"));
        let count = apply(b"x\nx\n", &e("x", "y"), Expect::Exactly(3)).err().unwrap();
        assert!(count.starts_with("found 2 matches (lines 1, 2), expected 3."));
        let none = apply(b"a\n", &e("x", "y"), Expect::AtLeastOne).err().unwrap();
        assert!(none.starts_with("found 0 matches, expected at least 1."));
    }

    #[test]
    fn a_miss_points_at_the_line_that_differs() {
        let file = b"def a\n  one\n  two\nend\n";
        let err = apply(file, &e("def a\n  one\n  three", ""), Expect::Exactly(1)).err().unwrap();
        assert!(err.contains("first '-' line matches file line 1, but the text differs at file line 3"), "{}", err);
        assert!(err.contains("file line 3: |  two|"));
        let spacing = apply(b"x  =  1\n", &e("x = 1", ""), Expect::Exactly(1)).err().unwrap();
        assert!(spacing.contains("1: |x  =  1|  (same words, different spacing)"), "{}", spacing);
        let crlf = apply(b"a\r\nb\r\n", &e("a\nb", ""), Expect::Exactly(1)).err().unwrap();
        assert!(crlf.contains("CRLF"));
        let nothing = apply(b"alpha\n", &e("zzz", ""), Expect::Exactly(1)).err().unwrap();
        assert!(nothing.contains("No similar lines"));
    }
}
