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
    let normalised = style.render(&root) != original;
    let shown = value.to_compact();
    let old = set(&mut root, &path, value).unwrap_or_else(|e| tool.fail(&format!("{}: {}", file, e)));
    let updated = style.render(&root);
    if updated == original {
        println!("{}: {} is already {}; file unchanged.", file, path_text, shown);
        tool.exit(EXIT_OK);
    }
    if let Err(e) = write_atomically(std::path::Path::new(file), updated.as_bytes()) {
        tool.fail(&format!("writing {} failed: {}", file, e));
    }
    match old {
        Some(old) => println!("{}: {} = {} (was {})", file, path_text, shown, cut(&old.to_compact())),
        None => println!("{}: {} = {}", file, path_text, shown),
    }
    if normalised {
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

    #[test]
    fn keeps_the_file_style() {
        assert_eq!(Style::of("{\n\t\"a\": 1\n}\n").render(&v("{\"a\":2}")), "{\n\t\"a\": 2\n}\n");
        assert_eq!(Style::of("{\"a\":1}").render(&v("{\"a\":2}")), "{\"a\":2}");
        assert_eq!(Style::of("{\n}").render(&v("{\"a\":[]}")), "{\n  \"a\": []\n}");
    }
}
