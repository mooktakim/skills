//! Finds the git conflict blocks in a file's text:
//!
//! ```text
//! <<<<<<< HEAD
//! ours
//! ||||||| base      (diff3 only)
//! base
//! =======
//! theirs
//! >>>>>>> topic
//! ```
//!
//! Lines keep their newlines, so a resolved file is the untouched lines plus
//! the chosen sides, byte for byte.

#[derive(Debug, PartialEq)]
pub struct Block {
    /// Index of the '<<<<<<<' line in `Parsed::lines`.
    pub start: usize,
    /// Index of the '>>>>>>>' line in `Parsed::lines`.
    pub end: usize,
    pub ours: Vec<String>,
    pub theirs: Vec<String>,
}

impl Block {
    /// The block's lines in the file, counted from 1.
    pub fn line_range(&self) -> String {
        format!("lines {}-{}", self.start + 1, self.end + 1)
    }
}

#[derive(Debug)]
pub struct Parsed {
    pub lines: Vec<String>,
    pub blocks: Vec<Block>,
}

#[derive(PartialEq, Clone, Copy)]
enum Marker {
    Start,
    Base,
    Separator,
    End,
}

fn marker(line: &str) -> Option<Marker> {
    let line = line.strip_suffix('\n').unwrap_or(line);
    if line == "=======" {
        return Some(Marker::Separator);
    }
    for (prefix, kind) in [("<<<<<<<", Marker::Start), ("|||||||", Marker::Base), (">>>>>>>", Marker::End)] {
        if let Some(rest) = line.strip_prefix(prefix) {
            if rest.is_empty() || rest.starts_with(' ') {
                return Some(kind);
            }
        }
    }
    None
}

fn name(kind: Marker) -> &'static str {
    match kind {
        Marker::Start => "<<<<<<<",
        Marker::Base => "|||||||",
        Marker::Separator => "=======",
        Marker::End => ">>>>>>>",
    }
}

#[derive(PartialEq)]
enum State {
    Outside,
    Ours,
    Base,
    Theirs,
}

/// Splits `text` into lines and finds its conflict blocks. Err names the
/// first broken marker by its file line.
pub fn parse(text: &str) -> Result<Parsed, String> {
    if text.contains("\r\n") {
        return Err("the file has CRLF line endings; this tool reads LF files only".to_string());
    }
    let lines: Vec<String> = text.split_inclusive('\n').map(str::to_string).collect();
    let mut blocks = Vec::new();
    let mut state = State::Outside;
    let (mut start, mut ours, mut theirs) = (0, Vec::new(), Vec::new());
    for (i, line) in lines.iter().enumerate() {
        let kind = marker(line);
        let unexpected = |kind: Marker| format!("file line {}: a '{}' marker where none belongs", i + 1, name(kind));
        match (&state, kind) {
            (State::Outside, Some(Marker::Start)) => {
                state = State::Ours;
                start = i;
            }
            // A line of '=' outside a block is ordinary text, such as a heading underline.
            (State::Outside, Some(Marker::Separator)) | (State::Outside, None) => {}
            (State::Outside, Some(other)) => return Err(format!("{}, outside a conflict block", unexpected(other))),
            (State::Ours, Some(Marker::Base)) => state = State::Base,
            (State::Ours, Some(Marker::Separator)) | (State::Base, Some(Marker::Separator)) => state = State::Theirs,
            (State::Ours, None) => ours.push(line.clone()),
            (State::Base, None) => {}
            (State::Theirs, Some(Marker::End)) => {
                blocks.push(Block { start, end: i, ours: std::mem::take(&mut ours), theirs: std::mem::take(&mut theirs) });
                state = State::Outside;
            }
            (State::Theirs, None) => theirs.push(line.clone()),
            (_, Some(other)) => {
                return Err(format!("{}, inside the conflict block that starts at file line {}", unexpected(other), start + 1))
            }
        }
    }
    if state != State::Outside {
        return Err(format!("file line {}: the conflict block that starts here has no '>>>>>>>' end", start + 1));
    }
    Ok(Parsed { lines, blocks })
}

/// The file's text with block `i` replaced by `resolved[i]`.
pub fn render(parsed: &Parsed, resolved: &[Vec<String>]) -> String {
    let mut out = String::new();
    let mut next = 0;
    for (block, lines) in parsed.blocks.iter().zip(resolved) {
        out.extend(parsed.lines[next..block.start].iter().map(String::as_str));
        out.extend(lines.iter().map(String::as_str));
        next = block.end + 1;
    }
    out.extend(parsed.lines[next..].iter().map(String::as_str));
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn finds_blocks_with_their_sides() {
        let p = parse("a\n<<<<<<< HEAD\nours\n=======\ntheirs 1\ntheirs 2\n>>>>>>> topic\nz\n").unwrap();
        assert_eq!(p.blocks, vec![Block { start: 1, end: 6, ours: vec!["ours\n".into()], theirs: vec!["theirs 1\n".into(), "theirs 2\n".into()] }]);
        assert_eq!(p.blocks[0].line_range(), "lines 2-7");
    }

    #[test]
    fn drops_the_diff3_base() {
        let p = parse("<<<<<<< HEAD\nA\n||||||| base\nO\n=======\nB\n>>>>>>> topic\n").unwrap();
        assert_eq!(p.blocks[0].ours, vec!["A\n"]);
        assert_eq!(p.blocks[0].theirs, vec!["B\n"]);
    }

    #[test]
    fn a_separator_line_outside_a_block_is_text() {
        let p = parse("Title\n=======\n").unwrap();
        assert!(p.blocks.is_empty());
    }

    #[test]
    fn marker_lookalikes_are_text() {
        let p = parse("<<<<<<<<\n>>>>>>>x\n").unwrap();
        assert!(p.blocks.is_empty());
    }

    #[test]
    fn broken_markers_name_their_line() {
        assert_eq!(parse("x\n<<<<<<< HEAD\nA\n").unwrap_err(), "file line 2: the conflict block that starts here has no '>>>>>>>' end");
        assert_eq!(parse("A\n>>>>>>> topic\n").unwrap_err(), "file line 2: a '>>>>>>>' marker where none belongs, outside a conflict block");
        assert_eq!(
            parse("<<<<<<< HEAD\nA\n>>>>>>> topic\n").unwrap_err(),
            "file line 3: a '>>>>>>>' marker where none belongs, inside the conflict block that starts at file line 1"
        );
        assert!(parse("a\r\nb\r\n").unwrap_err().contains("CRLF"));
    }

    #[test]
    fn renders_each_block_with_its_resolution() {
        let p = parse("a\n<<<<<<< H\n1\n=======\n2\n>>>>>>> t\nb\n<<<<<<< H\n3\n=======\n4\n>>>>>>> t\n").unwrap();
        let out = render(&p, &[vec!["one\n".into()], vec![]]);
        assert_eq!(out, "a\none\nb\n");
    }

    #[test]
    fn keeps_a_missing_final_newline() {
        let p = parse("<<<<<<< H\n1\n=======\n2\n>>>>>>> t\nend").unwrap();
        assert_eq!(render(&p, &[vec!["2\n".into()]]), "2\nend");
    }
}
