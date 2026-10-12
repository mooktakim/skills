//! toolsmith-json-set: sets one value in a JSON file, keeping key order and
//! the file's indent. See tool.json for the guide that `--llm` prints.

use std::fs;

use toolsmith_common::fsutil::write_atomically;
use toolsmith_common::{Tool, Value, EXIT_OK};

#[derive(Debug, PartialEq)]
enum Step {
    Key(String),
    Index(usize),
    Append,
}

fn main() {
    let tool = Tool::new(include_str!("../tool.json"));
    let args = tool.handle_guide_flags(std::env::args().skip(1).collect());
    let mut raw_string = false;
    let mut positional: Vec<&String> = Vec::new();
    for arg in &args {
        if arg == "--string" {
            raw_string = true;
        } else if arg.starts_with("--") {
            tool.usage_error(&format!("unknown option {}", arg));
        } else {
            positional.push(arg);
        }
    }
    let [file, path_text, value_text] = positional[..] else {
        tool.usage_error("give three arguments: FILE PATH VALUE")
    };
    let path = parse_path(path_text).unwrap_or_else(|e| tool.usage_error(&format!("bad path {}: {}", path_text, e)));
    let value = if raw_string {
        Value::String(value_text.clone())
    } else {
        Value::parse(value_text).unwrap_or_else(|_| {
            tool.usage_error(&format!(
                "the value {} is not JSON; quote a string as '\"text\"', or add --string",
                value_text
            ))
        })
    };

    let original = fs::read_to_string(file).unwrap_or_else(|e| tool.fail(&format!("cannot read {}: {}", file, e)));
    let mut root = Value::parse(&original).unwrap_or_else(|e| tool.fail(&format!("{} is not valid JSON: {}", file, e)));
    let style = Style::of(&original);
    let shown = value.to_compact();
    let old = set(&mut root, &path, value.clone()).unwrap_or_else(|e| tool.fail(&format!("{}: {}", file, e)));
    if old.as_ref() == Some(&value) {
        println!("{}: {} is already {}; file unchanged.", file, path_text, shown);
        tool.exit(EXIT_OK);
    }
    // Change only the value's own text. If that cannot be done (or the result
    // would not be exactly the changed data), write the whole file pretty.
    let in_place = locate(&original, &path, value)
        .map(|spot| splice(&original, spot, &style))
        .filter(|text| Value::parse(text).ok().as_ref() == Some(&root));
    let rewritten = in_place.is_none();
    let updated = in_place.unwrap_or_else(|| style.render(&root));
    if let Err(e) = write_atomically(std::path::Path::new(file), updated.as_bytes()) {
        tool.fail(&format!("writing {} failed: {}", file, e));
    }
    match old {
        Some(old) => println!("{}: {} = {} (was {})", file, path_text, shown, cut(&old.to_compact())),
        None => println!("{}: {} = {}", file, path_text, shown),
    }
    if rewritten && Value::parse(&original).map(|v| style.render(&v) != original).unwrap_or(false) {
        println!("Note: the rest of the file was re-formatted too (indent {:?}); check `git diff {}`.", style.indent.as_deref().unwrap_or(""), file);
    }
    tool.exit(EXIT_OK);
}

fn cut(text: &str) -> String {
    if text.chars().count() > 80 {
        format!("{}...", text.chars().take(80).collect::<String>())
    } else {
        text.to_string()
    }
}

/// How the file is laid out: pretty with an indent, or compact on one line.
struct Style {
    indent: Option<String>,
    final_newline: bool,
}

impl Style {
    fn of(text: &str) -> Style {
        let body = text.trim_end();
        let indent = if body.contains('\n') {
            let unit = body
                .lines()
                .skip(1)
                .map(|l| l.chars().take_while(|c| *c == ' ' || *c == '\t').collect::<String>())
                .find(|w| !w.is_empty());
            Some(unit.unwrap_or_else(|| "  ".to_string()))
        } else {
            None
        };
        Style { indent, final_newline: text.ends_with('\n') }
    }

    fn render(&self, value: &Value) -> String {
        let mut out = match &self.indent {
            Some(unit) => value.to_pretty(unit),
            None => value.to_compact(),
        };
        if self.final_newline {
            out.push('\n');
        }
        out
    }
}

/// Where a path leads in the file's text.
#[derive(Debug, PartialEq)]
enum Spot {
    /// The value at this byte range is replaced.
    Replace { start: usize, end: usize, value: Value },
    /// A new member goes into the object or array that opens at `open`.
    Insert { open: usize, key: Option<String>, value: Value },
}

/// One member of an object or array in the text: where its key (or, in an
/// array, its value) starts, and where its value starts and ends.
struct Member {
    key: Option<String>,
    start: usize,
    key_end: usize,
    value_start: usize,
    value_end: usize,
}

fn skip_ws(b: &[u8], mut i: usize) -> usize {
    while i < b.len() && matches!(b[i], b' ' | b'\t' | b'\n' | b'\r') {
        i += 1;
    }
    i
}

/// The end of the JSON value that starts at `i` (the input is valid JSON).
fn skip_value(b: &[u8], mut i: usize) -> usize {
    match b.get(i) {
        Some(b'"') => {
            i += 1;
            while i < b.len() && b[i] != b'"' {
                i += if b[i] == b'\\' { 2 } else { 1 };
            }
            i + 1
        }
        Some(b'{') | Some(b'[') => {
            let mut depth = 0;
            while i < b.len() {
                match b[i] {
                    b'"' => {
                        i = skip_value(b, i);
                        continue;
                    }
                    b'{' | b'[' => depth += 1,
                    b'}' | b']' => {
                        depth -= 1;
                        if depth == 0 {
                            return i + 1;
                        }
                    }
                    _ => {}
                }
                i += 1;
            }
            i
        }
        _ => {
            while i < b.len() && !matches!(b[i], b',' | b'}' | b']' | b' ' | b'\t' | b'\n' | b'\r') {
                i += 1;
            }
            i
        }
    }
}

/// The members of the object or array that opens at `open`, and where it closes.
fn members(text: &str, open: usize) -> Option<(Vec<Member>, usize)> {
    let b = text.as_bytes();
    let object = b[open] == b'{';
    let close_char = if object { b'}' } else { b']' };
    let mut list = Vec::new();
    let mut i = skip_ws(b, open + 1);
    if b.get(i) == Some(&close_char) {
        return Some((list, i));
    }
    loop {
        let start = i;
        let (key, key_end) = if object {
            let end = skip_value(b, i);
            match Value::parse(&text[i..end]).ok()? {
                Value::String(k) => {
                    i = skip_ws(b, end);
                    if b.get(i) != Some(&b':') {
                        return None;
                    }
                    i = skip_ws(b, i + 1);
                    (Some(k), end)
                }
                _ => return None,
            }
        } else {
            (None, i)
        };
        let value_end = skip_value(b, i);
        list.push(Member { key, start, key_end, value_start: i, value_end });
        i = skip_ws(b, value_end);
        match b.get(i) {
            Some(b',') => i = skip_ws(b, i + 1),
            Some(c) if *c == close_char => return Some((list, i)),
            _ => return None,
        }
    }
}

/// The value to insert for a missing key: `rest` of the path wraps `value` in
/// the objects (or the array before `[]`) that do not exist yet.
fn nest(rest: &[Step], value: Value) -> Value {
    match rest.split_first() {
        None => value,
        Some((Step::Key(k), more)) => Value::Object(vec![(k.clone(), nest(more, value))]),
        Some((_, more)) => Value::Array(vec![nest(more, value)]),
    }
}

/// Finds the text the change touches. None when the path does not fit the data
/// (set() has already said why).
fn locate(text: &str, path: &[Step], value: Value) -> Option<Spot> {
    let b = text.as_bytes();
    let mut pos = skip_ws(b, 0);
    for (n, step) in path.iter().enumerate() {
        let last = n + 1 == path.len();
        let found = match step {
            Step::Key(key) => {
                if b.get(pos) != Some(&b'{') {
                    return None;
                }
                let (list, _) = members(text, pos)?;
                match list.into_iter().find(|m| m.key.as_deref() == Some(key.as_str())) {
                    Some(m) => m,
                    None => return Some(Spot::Insert { open: pos, key: Some(key.clone()), value: nest(&path[n + 1..], value) }),
                }
            }
            Step::Index(i) => {
                if b.get(pos) != Some(&b'[') {
                    return None;
                }
                members(text, pos)?.0.into_iter().nth(*i)?
            }
            Step::Append => {
                if b.get(pos) != Some(&b'[') {
                    return None;
                }
                return Some(Spot::Insert { open: pos, key: None, value });
            }
        };
        if last {
            return Some(Spot::Replace { start: found.value_start, end: found.value_end, value });
        }
        pos = found.value_start;
    }
    None
}

/// The leading whitespace of the line that holds byte `at`.
fn line_indent(text: &str, at: usize) -> &str {
    let start = text[..at].rfind('\n').map_or(0, |i| i + 1);
    let width = text[start..].bytes().take_while(|c| *c == b' ' || *c == b'\t').count();
    &text[start..start + width]
}

/// A value's text: on one line, or pretty with its lines at `indent`.
fn render_at(value: &Value, multiline: bool, indent: &str, style: &Style) -> String {
    let container = matches!(value, Value::Array(items) if !items.is_empty()) || matches!(value, Value::Object(pairs) if !pairs.is_empty());
    match (&style.indent, multiline && container) {
        (Some(unit), true) => value.to_pretty(unit).replace('\n', &format!("\n{}", indent)),
        _ => value.to_compact(),
    }
}

/// The file with the change made in its text, everything else byte for byte.
fn splice(text: &str, spot: Spot, style: &Style) -> String {
    match spot {
        Spot::Replace { start, end, value } => {
            let multiline = text[start..end].contains('\n');
            let new = render_at(&value, multiline, line_indent(text, start), style);
            format!("{}{}{}", &text[..start], new, &text[end..])
        }
        Spot::Insert { open, key, value } => {
            let Some((list, close)) = members(text, open) else { return String::new() };
            let pretty_colon = if style.indent.is_some() { ": " } else { ":" };
            match list.last() {
                Some(last) => {
                    // Copy the separator and the key-colon spacing of the last member.
                    let mut gap = last.start;
                    while gap > 0 && matches!(text.as_bytes()[gap - 1], b' ' | b'\t' | b'\n' | b'\r') {
                        gap -= 1;
                    }
                    // With one member, the space before it is padding, not a separator:
                    // on one line, follow the file's ", " or ",".
                    let sep = match &text[gap..last.start] {
                        sep if list.len() > 1 || sep.contains('\n') => sep,
                        _ if text.contains(", ") => " ",
                        _ => "",
                    };
                    let colon = if last.key.is_some() { &text[last.key_end..last.value_start] } else { pretty_colon };
                    let indent = match sep.rfind('\n') {
                        Some(i) => &sep[i + 1..],
                        None => line_indent(text, last.start),
                    };
                    let member_value = render_at(&value, sep.contains('\n'), indent, style);
                    let member = match key {
                        Some(k) => format!("{}{}{}", toolsmith_common::json::quote(&k), colon, member_value),
                        None => member_value,
                    };
                    format!("{},{}{}{}", &text[..last.value_end], sep, member, &text[last.value_end..])
                }
                None => {
                    let inner = &text[open + 1..close];
                    let member_of = |value: String| match &key {
                        Some(k) => format!("{}{}{}", toolsmith_common::json::quote(k), pretty_colon, value),
                        None => value,
                    };
                    match (&style.indent, inner.contains('\n')) {
                        (Some(unit), true) => {
                            let indent = line_indent(text, open);
                            let inside = format!("{}{}", indent, unit);
                            let member = member_of(render_at(&value, true, &inside, style));
                            format!("{}\n{}{}\n{}{}", &text[..open + 1], inside, member, indent, &text[close..])
                        }
                        _ => format!("{}{}{}", &text[..open + 1], member_of(value.to_compact()), &text[close..]),
                    }
                }
            }
        }
    }
}

/// `a.b[0].c`, `list[]` (append), and `"key.with.dots"` for keys that need quoting.
fn parse_path(text: &str) -> Result<Vec<Step>, String> {
    let chars: Vec<char> = text.chars().collect();
    let mut steps = Vec::new();
    let mut i = 0;
    let mut expect_key = true;
    while i < chars.len() {
        match chars[i] {
            '[' => {
                let close = chars[i..].iter().position(|c| *c == ']').ok_or("a '[' has no ']'")? + i;
                let inner: String = chars[i + 1..close].iter().collect();
                if steps.is_empty() {
                    return Err("start with a key, not an index".into());
                }
                if inner.is_empty() {
                    steps.push(Step::Append);
                } else {
                    steps.push(Step::Index(inner.parse().map_err(|_| format!("[{}] is not an array index", inner))?));
                }
                i = close + 1;
                expect_key = false;
            }
            '.' => {
                if expect_key {
                    return Err("a key is empty".into());
                }
                i += 1;
                expect_key = true;
            }
            _ if !expect_key => return Err(format!("expected '.' or '[' at character {}", i + 1)),
            '"' => {
                let mut key = String::new();
                i += 1;
                loop {
                    match chars.get(i) {
                        None => return Err("a quoted key has no closing quote".into()),
                        Some('"') => break,
                        Some('\\') if i + 1 < chars.len() => {
                            key.push(chars[i + 1]);
                            i += 2;
                        }
                        Some(c) => {
                            key.push(*c);
                            i += 1;
                        }
                    }
                }
                i += 1;
                steps.push(Step::Key(key));
                expect_key = false;
            }
            _ => {
                let start = i;
                while i < chars.len() && !matches!(chars[i], '.' | '[' | '"') {
                    i += 1;
                }
                steps.push(Step::Key(chars[start..i].iter().collect()));
                expect_key = false;
            }
        }
    }
    if steps.is_empty() || expect_key {
        return Err("a key is empty".into());
    }
    if steps[..steps.len() - 1].contains(&Step::Append) {
        return Err("[] (append) can only come last".into());
    }
    Ok(steps)
}

fn kind(value: &Value) -> &'static str {
    match value {
        Value::Null => "null",
        Value::Bool(_) => "a boolean",
        Value::Number(_) => "a number",
        Value::String(_) => "a string",
        Value::Array(_) => "an array",
        Value::Object(_) => "an object",
    }
}

/// Sets the value at `path`, creating missing objects (and a missing array
/// before `[]`) on the way. Returns the value it replaced.
fn set(node: &mut Value, path: &[Step], value: Value) -> Result<Option<Value>, String> {
    let (step, rest) = path.split_first().expect("paths are never empty");
    match (step, node) {
        (Step::Key(key), Value::Object(pairs)) => {
            let at = match pairs.iter().position(|(k, _)| k == key) {
                Some(at) => at,
                None if rest.is_empty() => {
                    pairs.push((key.clone(), value));
                    return Ok(None);
                }
                None => match rest[0] {
                    Step::Key(_) => {
                        pairs.push((key.clone(), Value::Object(Vec::new())));
                        pairs.len() - 1
                    }
                    Step::Append => {
                        pairs.push((key.clone(), Value::Array(Vec::new())));
                        pairs.len() - 1
                    }
                    Step::Index(_) => return Err(format!("\"{}\" does not exist, so it has no index", key)),
                },
            };
            if rest.is_empty() {
                Ok(Some(std::mem::replace(&mut pairs[at].1, value)))
            } else {
                set(&mut pairs[at].1, rest, value).map_err(|e| format!("{}{}", key, prefix(&e)))
            }
        }
        (Step::Index(i), Value::Array(items)) => {
            let len = items.len();
            let item = items.get_mut(*i).ok_or_else(|| format!("[{}] is past the end of the array ({} items)", i, len))?;
            if rest.is_empty() {
                Ok(Some(std::mem::replace(item, value)))
            } else {
                set(item, rest, value).map_err(|e| format!("[{}]{}", i, prefix(&e)))
            }
        }
        (Step::Append, Value::Array(items)) => {
            items.push(value);
            Ok(None)
        }
        (Step::Key(key), other) => Err(format!(": is {}, so it has no key \"{}\"", kind(other), key)),
        (_, other) => Err(format!(": is {}, not an array", kind(other))),
    }
}

/// Joins an inner error to the path walked so far.
fn prefix(e: &str) -> String {
    if e.starts_with(':') || e.starts_with('[') {
        e.to_string()
    } else {
        format!(".{}", e)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn v(text: &str) -> Value {
        Value::parse(text).unwrap()
    }

    #[test]
    fn parses_paths() {
        assert_eq!(parse_path("a.b").unwrap(), vec![Step::Key("a".into()), Step::Key("b".into())]);
        assert_eq!(parse_path("a[2].b[]").unwrap(), vec![Step::Key("a".into()), Step::Index(2), Step::Key("b".into()), Step::Append]);
        assert_eq!(parse_path("\"x.y\".z").unwrap(), vec![Step::Key("x.y".into()), Step::Key("z".into())]);
        for (bad, message) in [("", "empty"), ("a.", "empty"), ("a..b", "empty"), ("[0]", "start with a key"), ("a[x]", "not an array index"), ("a[].b", "only come last"), ("a\"b\"", "expected '.'")] {
            assert!(parse_path(bad).unwrap_err().contains(message), "{}", bad);
        }
    }

    #[test]
    fn sets_replaces_and_creates() {
        let mut root = v(r#"{"a": {"b": 1}, "list": [1, 2]}"#);
        assert_eq!(set(&mut root, &parse_path("a.b").unwrap(), v("5")).unwrap(), Some(v("1")));
        assert_eq!(set(&mut root, &parse_path("a.new.deep").unwrap(), v("true")).unwrap(), None);
        assert_eq!(set(&mut root, &parse_path("list[1]").unwrap(), v("9")).unwrap(), Some(v("2")));
        assert_eq!(set(&mut root, &parse_path("list[]").unwrap(), v("3")).unwrap(), None);
        assert_eq!(set(&mut root, &parse_path("tags[]").unwrap(), v("\"x\"")).unwrap(), None);
        assert_eq!(root.to_compact(), r#"{"a":{"b":5,"new":{"deep":true}},"list":[1,9,3],"tags":["x"]}"#);
    }

    #[test]
    fn explains_impossible_paths() {
        let mut root = v(r#"{"a": "text", "list": [1]}"#);
        assert_eq!(set(&mut root, &parse_path("a.b").unwrap(), v("1")).unwrap_err(), "a: is a string, so it has no key \"b\"");
        assert_eq!(set(&mut root, &parse_path("list[3]").unwrap(), v("1")).unwrap_err(), "list[3] is past the end of the array (1 items)");
        assert_eq!(set(&mut root, &parse_path("missing[0]").unwrap(), v("1")).unwrap_err(), "\"missing\" does not exist, so it has no index");
    }

    fn edit(text: &str, path: &str, value: &str) -> String {
        let mut root = v(text);
        let steps = parse_path(path).unwrap();
        set(&mut root, &steps, v(value)).unwrap();
        let out = splice(text, locate(text, &steps, v(value)).unwrap(), &Style::of(text));
        assert_eq!(v(&out), root, "the text holds exactly the changed data");
        out
    }

    #[test]
    fn changes_only_the_value_text() {
        let manifest = "{\n  \"name\": \"x\",\n  \"version\": \"0.1.0\",\n  \"author\": { \"name\": \"A\" },\n  \"keywords\": [\"a\", \"b\"]\n}\n";
        assert_eq!(edit(manifest, "version", "\"0.1.1\""), manifest.replace("0.1.0", "0.1.1"));
        assert_eq!(edit(manifest, "keywords[]", "\"c\""), manifest.replace("\"b\"]", "\"b\", \"c\"]"));
        assert_eq!(edit(manifest, "author.email", "\"e\""), manifest.replace("\"A\" }", "\"A\", \"email\": \"e\" }"));
        assert_eq!(edit(manifest, "license", "\"MIT\""), manifest.replace("\"b\"]\n}", "\"b\"],\n  \"license\": \"MIT\"\n}"));
        assert_eq!(edit(manifest, "keywords", "[\"z\"]"), manifest.replace("[\"a\", \"b\"]", "[\"z\"]"));
        assert_eq!(edit("{\"a\":{},\"b\":[]}", "a.x.y", "1"), "{\"a\":{\"x\":{\"y\":1}},\"b\":[]}");
        assert_eq!(edit("{\n  \"tags\": []\n}\n", "tags[]", "\"x\""), "{\n  \"tags\": [\"x\"]\n}\n");
        assert_eq!(
            edit("{\n  \"hooks\": {\n  }\n}\n", "hooks.Stop", "[{\"a\":1}]"),
            "{\n  \"hooks\": {\n    \"Stop\": [\n      {\n        \"a\": 1\n      }\n    ]\n  }\n}\n"
        );
        let tricky = "{\"a\": [1, \"x]\\\"{\", {\"k\": [2]}]}";
        assert_eq!(edit(tricky, "a[2].k[]", "3"), tricky.replace("[2]", "[2, 3]"), "brackets and quotes inside strings");
        assert_eq!(edit("{\n\t\"a\": [\n\t\t1\n\t]\n}", "a[0]", "{\"b\":2}"), "{\n\t\"a\": [\n\t\t{\"b\":2}\n\t]\n}");
    }

    #[test]
    fn keeps_the_file_style() {
        assert_eq!(Style::of("{\n\t\"a\": 1\n}\n").render(&v("{\"a\":2}")), "{\n\t\"a\": 2\n}\n");
        assert_eq!(Style::of("{\"a\":1}").render(&v("{\"a\":2}")), "{\"a\":2}");
        assert_eq!(Style::of("{\n}").render(&v("{\"a\":[]}")), "{\n  \"a\": []\n}");
    }
}
