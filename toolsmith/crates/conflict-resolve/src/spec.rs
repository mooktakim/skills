//! Parses the resolution spec read from stdin:
//!
//! ```text
//! @@ path/to/file <block|*> <ours|theirs|both|text>
//! +replacement line (only after a 'text' header)
//! ```
//!
//! Text after the '+' is taken exactly, spaces included. Empty lines may
//! separate headers.

#[derive(Debug, PartialEq)]
pub enum Choice {
    Ours,
    Theirs,
    Both,
    Text(Vec<String>),
}

impl Choice {
    pub fn name(&self) -> &'static str {
        match self {
            Choice::Ours => "ours",
            Choice::Theirs => "theirs",
            Choice::Both => "both",
            Choice::Text(_) => "text",
        }
    }
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub enum Target {
    /// A block number, counted from 1.
    Block(usize),
    /// Every block of the file not named by another header.
    Rest,
}

#[derive(Debug, PartialEq)]
pub struct Resolution {
    pub path: String,
    pub target: Target,
    pub choice: Choice,
    /// Spec line of the header, for error messages.
    pub line: usize,
}

pub fn parse(input: &str) -> Result<Vec<Resolution>, String> {
    let mut out: Vec<Resolution> = Vec::new();
    for (i, line) in input.lines().enumerate() {
        let n = i + 1;
        if line.is_empty() {
            continue;
        }
        if let Some(text) = line.strip_prefix('+') {
            match out.last_mut() {
                Some(Resolution { choice: Choice::Text(lines), .. }) => lines.push(format!("{}\n", text)),
                Some(r) => {
                    return Err(format!(
                        "spec line {}: a '+' line after a '{}' header; only a 'text' header takes '+' lines",
                        n,
                        r.choice.name()
                    ))
                }
                None => return Err(format!("spec line {}: a '+' line before any '@@' header", n)),
            }
            continue;
        }
        let Some(header) = line.strip_prefix("@@ ") else {
            return Err(format!("spec line {}: expected '@@ <path> <block> <choice>' or a '+' line, got {:?}", n, line));
        };
        let parts: Vec<&str> = header.split_whitespace().collect();
        if parts.len() != 3 {
            return Err(format!("spec line {}: a header is '@@ <path> <block> <choice>', got {:?}", n, line));
        }
        let target = match parts[1] {
            "*" => Target::Rest,
            number => match number.parse::<usize>() {
                Ok(b) if b >= 1 => Target::Block(b),
                _ => return Err(format!("spec line {}: the block is a number from 1 or '*', got {:?}", n, number)),
            },
        };
        let choice = match parts[2] {
            "ours" => Choice::Ours,
            "theirs" => Choice::Theirs,
            "both" => Choice::Both,
            "text" => Choice::Text(Vec::new()),
            other => return Err(format!("spec line {}: the choice is ours, theirs, both or text, got {:?}", n, other)),
        };
        out.push(Resolution { path: parts[0].to_string(), target, choice, line: n });
    }
    if out.is_empty() {
        return Err("the spec has no '@@' headers".to_string());
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_headers_with_text() {
        let r = parse("@@ a.rb 1 ours\n\n@@ a.rb 2 text\n+  x = 1\n+\n@@ b.rb * both\n").unwrap();
        assert_eq!(r.len(), 3);
        assert_eq!(r[0], Resolution { path: "a.rb".into(), target: Target::Block(1), choice: Choice::Ours, line: 1 });
        assert_eq!(r[1].choice, Choice::Text(vec!["  x = 1\n".into(), "\n".into()]));
        assert_eq!(r[2].target, Target::Rest);
        assert_eq!(r[2].line, 6);
    }

    #[test]
    fn a_text_header_without_lines_removes_the_block() {
        assert_eq!(parse("@@ a 1 text\n").unwrap()[0].choice, Choice::Text(vec![]));
    }

    #[test]
    fn rejects_bad_specs() {
        assert!(parse("").unwrap_err().contains("no '@@' headers"));
        assert!(parse("+x\n").unwrap_err().contains("before any '@@' header"));
        assert!(parse("@@ a 1 ours\n+x\n").unwrap_err().contains("after a 'ours' header"));
        assert!(parse("@@ a 0 ours\n").unwrap_err().contains("number from 1"));
        assert!(parse("@@ a 1 mine\n").unwrap_err().contains("ours, theirs, both or text"));
        assert!(parse("@@ a 1\n").unwrap_err().contains("'@@ <path> <block> <choice>'"));
        assert!(parse("-x\n").unwrap_err().contains("spec line 1"));
    }
}
