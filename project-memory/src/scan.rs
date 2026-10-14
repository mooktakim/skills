//! Text scans with no regex engine: markdown links outside fenced code, and
//! common credential shapes.

/// Relative link targets in the prose of a markdown text: `[text](target)`,
/// leaving out fenced code, URLs with a scheme, anchors, and absolute paths.
pub fn relative_links(text: &str) -> Vec<String> {
    let mut targets = Vec::new();
    let mut fence: Option<&str> = None;
    for line in text.lines() {
        let marker = ["```", "~~~"].into_iter().find(|m| line.starts_with(m));
        match (fence, marker) {
            (None, Some(m)) => {
                fence = Some(m);
                continue;
            }
            (Some(open), Some(m)) if open == m => {
                fence = None;
                continue;
            }
            (Some(_), _) => continue,
            _ => {}
        }
        targets.extend(links_in_line(line).into_iter().filter(|t| !external(t)));
    }
    targets
}

fn links_in_line(line: &str) -> Vec<String> {
    let b = line.as_bytes();
    let mut out = Vec::new();
    let mut i = 0;
    while i < b.len() {
        if b[i] != b'[' {
            i += 1;
            continue;
        }
        let Some(close) = b[i + 1..].iter().position(|&c| c == b']').map(|p| p + i + 1) else { break };
        if b.get(close + 1) != Some(&b'(') {
            i = close + 1;
            continue;
        }
        let start = close + 2;
        let mut end = start;
        while end < b.len() && b[end] != b')' && !b[end].is_ascii_whitespace() {
            end += 1;
        }
        let mut after = end;
        while after < b.len() && b[after].is_ascii_whitespace() {
            after += 1;
        }
        if after > end && b.get(after) == Some(&b'"') {
            if let Some(q) = b[after + 1..].iter().position(|&c| c == b'"') {
                after += q + 2;
            }
        }
        if end > start && b.get(after) == Some(&b')') {
            out.push(line[start..end].to_string());
            i = after + 1;
        } else {
            i = close + 1;
        }
    }
    out
}

fn external(target: &str) -> bool {
    if target.starts_with('#') || target.starts_with('/') {
        return true;
    }
    match target.find(':') {
        Some(colon) if colon > 0 => {
            let scheme = &target.as_bytes()[..colon];
            scheme[0].is_ascii_alphabetic() && scheme.iter().all(|&c| c.is_ascii_alphanumeric() || b"+.-".contains(&c))
        }
        _ => false,
    }
}

fn word(c: u8) -> bool {
    c.is_ascii_alphanumeric() || c == b'_'
}

fn alnum(c: u8) -> bool {
    c.is_ascii_alphanumeric()
}

fn upper_digit(c: u8) -> bool {
    c.is_ascii_uppercase() || c.is_ascii_digit()
}

fn word_or_dash(c: u8) -> bool {
    word(c) || c == b'-'
}

fn alnum_dash(c: u8) -> bool {
    alnum(c) || c == b'-'
}

/// How a token must end after its prefix and `min` characters of its set.
#[derive(Clone, Copy)]
enum End {
    /// Anywhere: the token may run on.
    Open,
    /// At a word boundary, after `min` or more characters.
    BoundaryAfterMin,
    /// At a word boundary right after exactly `min` characters.
    BoundaryAtMin,
}

/// Whether the line has `prefix` at a word start, followed by at least `min`
/// characters of `set`, ending as `end` says.
fn token(line: &[u8], prefix: &str, set: fn(u8) -> bool, min: usize, end: End) -> bool {
    let p = prefix.as_bytes();
    let boundary = |at: usize| {
        let before = at.checked_sub(1).map(|i| word(line[i])).unwrap_or(false);
        let after = line.get(at).map(|&c| word(c)).unwrap_or(false);
        before != after
    };
    let mut from = 0;
    while let Some(found) = line[from..].windows(p.len()).position(|w| w == p) {
        let at = from + found;
        from = at + 1;
        if at > 0 && word(line[at - 1]) {
            continue;
        }
        let start = at + p.len();
        let run = line[start..].iter().take_while(|&&c| set(c)).count();
        if run < min {
            continue;
        }
        let ok = match end {
            End::Open => true,
            End::BoundaryAfterMin => (min..=run).any(|k| boundary(start + k)),
            End::BoundaryAtMin => boundary(start + min),
        };
        if ok {
            return true;
        }
    }
    false
}

fn private_key(line: &[u8]) -> bool {
    let text = String::from_utf8_lossy(line);
    let mut rest = text.as_ref();
    while let Some(at) = rest.find("-----BEGIN ") {
        rest = &rest[at + 11..];
        if let Some(key) = rest.find("PRIVATE KEY-----") {
            let between = &rest[..key];
            if between.is_empty()
                || (between.ends_with(' ') && between.len() > 1 && between[..between.len() - 1].bytes().all(|c| c.is_ascii_uppercase()))
            {
                return true;
            }
        }
    }
    false
}

/// The name of each credential shape found in the line.
pub fn secrets(line: &[u8]) -> Vec<&'static str> {
    let checks: [(&'static str, bool); 8] = [
        (
            "an AWS access key",
            ["AKIA", "ASIA"].iter().any(|p| token(line, p, upper_digit, 16, End::BoundaryAtMin)),
        ),
        ("a private key", private_key(line)),
        (
            "a GitHub token",
            ["ghp_", "gho_", "ghu_", "ghs_", "ghr_"].iter().any(|p| token(line, p, alnum, 36, End::BoundaryAfterMin))
                || token(line, "github_pat_", word, 50, End::BoundaryAfterMin),
        ),
        (
            "a Slack token",
            ["xoxa-", "xoxb-", "xoxp-", "xoxo-", "xoxs-", "xoxr-"].iter().any(|p| token(line, p, alnum_dash, 10, End::Open)),
        ),
        ("a Stripe live key", ["sk_live_", "rk_live_"].iter().any(|p| token(line, p, alnum, 20, End::Open))),
        ("an Anthropic API key", token(line, "sk-ant-", word_or_dash, 20, End::Open)),
        ("an OpenAI API key", ["sk-", "sk-proj-"].iter().any(|p| token(line, p, alnum, 40, End::Open))),
        ("a Google API key", token(line, "AIza", word_or_dash, 35, End::BoundaryAtMin)),
    ];
    checks.into_iter().filter(|(_, found)| *found).map(|(name, _)| name).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn links_skip_code_urls_anchors_and_titles() {
        let text = "See [a](../x.md#part) and [b](https://e.com) [c](#top) [d](y.md \"Title\").\n\
                    ```\n[e](code.md)\n```\n[f] (no) [g](/abs.md) [h](mailto:a@b.c)\n";
        assert_eq!(relative_links(text), vec!["../x.md#part", "y.md"]);
    }

    #[test]
    fn credential_shapes() {
        let gh = format!("token ghp_{}", "a".repeat(36));
        assert_eq!(secrets(gh.as_bytes()), vec!["a GitHub token"]);
        assert!(secrets(format!("xghp_{}", "a".repeat(36)).as_bytes()).is_empty(), "needs a word start");
        assert_eq!(secrets(b"AKIAABCDEFGHIJKLMNOP."), vec!["an AWS access key"]);
        assert!(secrets(b"AKIAABCDEFGHIJKLMNOPQ").is_empty(), "exactly 16 characters");
        assert_eq!(secrets(b"-----BEGIN RSA PRIVATE KEY-----"), vec!["a private key"]);
        assert_eq!(secrets(b"-----BEGIN PRIVATE KEY-----"), vec!["a private key"]);
        assert!(secrets(b"-----BEGIN PUBLIC KEY-----").is_empty());
        assert_eq!(secrets(format!("AIza{}", "x".repeat(35)).as_bytes()), vec!["a Google API key"]);
        assert_eq!(secrets(format!("sk-ant-api03-{}", "x".repeat(20)).as_bytes()), vec!["an Anthropic API key"]);
        assert!(secrets(b"no secrets, sk- short").is_empty());
    }
}
