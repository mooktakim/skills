//! Parses the edit spec read from stdin:
//!
//! ```text
//! @@ path/to/file [--all | --count N]
//! -old text, one line per '-' line
//! +new text, one line per '+' line
//! ```
//!
//! A run of '-' lines followed by a run of '+' lines is one edit; the next
//! '-' line starts another edit in the same file. Text after the prefix is
//! taken exactly, spaces included. Empty lines may separate edits and blocks,
//! never sit inside one, where they would be ambiguous.

#[derive(Debug, PartialEq, Clone, Copy)]
pub enum Expect {
    Exactly(usize),
    AtLeastOne,
}

#[derive(Debug, PartialEq)]
pub struct Edit {
    pub old: String,
    pub new: String,
    /// Spec line of the edit's first '-' line, for error messages.
    pub line: usize,
}

#[derive(Debug, PartialEq)]
pub struct Block {
    pub path: String,
    pub expect: Expect,
    pub edits: Vec<Edit>,
    pub line: usize,
}

struct Pending<'a> {
    old: Vec<&'a str>,
    new: Vec<&'a str>,
    line: usize,
}

impl<'a> Pending<'a> {
    fn is_empty(&self) -> bool {
        self.old.is_empty() && self.new.is_empty()
    }

    /// Moves the collected edit, if any, into the last block.
    fn close(&mut self, blocks: &mut [Block]) -> Result<(), String> {
        if self.is_empty() {
            return Ok(());
        }
        let old = self.old.join("\n");
        if old.is_empty() {
            return Err(format!("line {}: the '-' text is empty; give the text to find", self.line));
        }
        let new = self.new.join("\n");
        blocks.last_mut().expect("edits follow a header").edits.push(Edit { old, new, line: self.line });
        self.old.clear();
        self.new.clear();
        Ok(())
    }
}

pub fn parse(input: &str) -> Result<Vec<Block>, String> {
    let mut lines: Vec<&str> = input.split('\n').collect();
    if input.ends_with('\n') {
        lines.pop();
    }
    let mut blocks: Vec<Block> = Vec::new();
    let mut pending = Pending { old: Vec::new(), new: Vec::new(), line: 0 };

    for (i, raw) in lines.iter().enumerate() {
        let no = i + 1;
        if let Some(header) = raw.strip_prefix("@@") {
            pending.close(&mut blocks)?;
            check_has_edits(blocks.last())?;
            blocks.push(parse_header(header, no)?);
        } else if let Some(text) = raw.strip_prefix('-') {
            if blocks.is_empty() {
                return Err(format!("line {}: a '-' line comes before any '@@ <path>' header", no));
            }
            if !pending.new.is_empty() {
                pending.close(&mut blocks)?;
            }
            if pending.old.is_empty() {
                pending.line = no;
            }
            pending.old.push(text);
        } else if let Some(text) = raw.strip_prefix('+') {
            if pending.old.is_empty() {
                return Err(format!("line {}: a '+' line must follow the '-' lines it replaces", no));
            }
            pending.new.push(text);
        } else if raw.is_empty() {
            let next = lines[i + 1..].iter().find(|l| !l.is_empty());
            let between = match next {
                None => true,
                Some(l) if l.starts_with("@@") => true,
                Some(l) if l.starts_with('-') => pending.is_empty() || !pending.new.is_empty(),
                Some(_) => pending.is_empty(),
            };
            if !between {
                return Err(format!(
                    "line {}: empty line inside an edit; write '-' or '+' alone for an empty line of text",
                    no
                ));
            }
        } else {
            let shown: String = raw.chars().take(40).collect();
            return Err(format!("line {}: every line must start with '@@', '-' or '+' (found \"{}\")", no, shown));
        }
    }
    pending.close(&mut blocks)?;
    check_has_edits(blocks.last())?;
    if blocks.is_empty() {
        return Err("the spec is empty; give at least one '@@ <path>' block".to_string());
    }
    Ok(blocks)
}

fn check_has_edits(block: Option<&Block>) -> Result<(), String> {
    match block {
        Some(b) if b.edits.is_empty() => Err(format!("line {}: the block for {} has no '-' lines", b.line, b.path)),
        _ => Ok(()),
    }
}

fn parse_header(header: &str, no: usize) -> Result<Block, String> {
    let mut words = header.split_whitespace();
    let path = words.next().ok_or_else(|| format!("line {}: '@@' needs a file path", no))?.to_string();
    let mut expect = None;
    while let Some(word) = words.next() {
        let next = match word {
            "--all" => Expect::AtLeastOne,
            "--count" => {
                let n = words.next().and_then(|n| n.parse::<usize>().ok()).filter(|n| *n > 0);
                Expect::Exactly(n.ok_or_else(|| format!("line {}: --count needs a whole number above 0", no))?)
            }
            other => return Err(format!("line {}: unknown option {} (use --all or --count N)", no, other)),
        };
        if expect.is_some() {
            return Err(format!("line {}: give only one of --all and --count", no));
        }
        expect = Some(next);
    }
    Ok(Block { path, expect: expect.unwrap_or(Expect::Exactly(1)), edits: Vec::new(), line: no })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn edit(old: &str, new: &str, line: usize) -> Edit {
        Edit { old: old.into(), new: new.into(), line }
    }

    #[test]
    fn parses_blocks_edits_and_options() {
        let spec = "@@ a.rb\n-one\n-two\n+three\n-four\n\n@@ b.md --count 2\n-x\n+ y \n\n@@ c.txt --all\n-z\n";
        let blocks = parse(spec).unwrap();
        assert_eq!(blocks.len(), 3);
        assert_eq!(blocks[0].edits, vec![edit("one\ntwo", "three", 2), edit("four", "", 5)]);
        assert_eq!(blocks[1].expect, Expect::Exactly(2));
        assert_eq!(blocks[1].edits, vec![edit("x", " y ", 8)]);
        assert_eq!(blocks[2].expect, Expect::AtLeastOne);
        assert_eq!(blocks[0].expect, Expect::Exactly(1));
    }

    #[test]
    fn a_lone_dash_is_an_empty_line_so_whole_lines_can_be_deleted() {
        let blocks = parse("@@ a\n-gone\n-\n").unwrap();
        assert_eq!(blocks[0].edits, vec![edit("gone\n", "", 2)]);
    }

    #[test]
    fn an_empty_line_between_edits_is_allowed() {
        assert!(parse("@@ a\n-x\n+y\n\n-z\n+w\n").is_ok());
    }

    #[test]
    fn rejects_ambiguous_or_broken_specs() {
        let cases = [
            ("", "the spec is empty"),
            ("-x\n", "line 1: a '-' line comes before"),
            ("@@ a\n+x\n", "line 2: a '+' line must follow"),
            ("@@ a\n-x\n\n-y\n", "line 3: empty line inside an edit"),
            ("@@ a\n-x\n\n+y\n", "line 3: empty line inside an edit"),
            ("@@ a\n-x\n+y\n\n+z\n", "line 4: empty line inside an edit"),
            ("@@ a\nx\n", "line 2: every line must start"),
            ("@@\n-x\n", "line 1: '@@' needs a file path"),
            ("@@ a --count 0\n-x\n", "--count needs"),
            ("@@ a --all --count 2\n-x\n", "only one of"),
            ("@@ a --regex\n-x\n", "unknown option --regex"),
            ("@@ a\n@@ b\n-x\n", "line 1: the block for a has no '-' lines"),
            ("@@ a\n", "the block for a has no '-' lines"),
            ("@@ a\n-\n+x\n", "line 2: the '-' text is empty"),
        ];
        for (spec, message) in cases {
            let err = parse(spec).unwrap_err();
            assert!(err.contains(message), "{:?}: {}", spec, err);
        }
    }
}
