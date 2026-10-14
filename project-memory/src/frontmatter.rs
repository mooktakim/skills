//! The note frontmatter: a --- block of one-line `key: value` or
//! `key: [a, b]` fields. No nested YAML, so no YAML parser is needed.

use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    Text(String),
    List(Vec<String>),
}

#[derive(Debug, Default)]
pub struct Fields(BTreeMap<String, Value>);

impl Fields {
    /// A one-value field; None when missing, empty, or a list.
    pub fn text(&self, key: &str) -> Option<&str> {
        match self.0.get(key) {
            Some(Value::Text(text)) => Some(text),
            _ => None,
        }
    }

    /// A field as a list; a one-value field is a list of one.
    pub fn list(&self, key: &str) -> Vec<String> {
        match self.0.get(key) {
            Some(Value::Text(text)) => vec![text.clone()],
            Some(Value::List(items)) => items.clone(),
            None => Vec::new(),
        }
    }

    pub fn has(&self, key: &str) -> bool {
        self.0.contains_key(key)
    }
}

pub struct Parsed {
    /// None when the text has no frontmatter block.
    pub fields: Option<Fields>,
    pub errors: Vec<String>,
    pub body: String,
}

/// Splits a note into its fields and body. Lines that are not `key: value`
/// become errors naming their line number.
pub fn parse(text: &str) -> Parsed {
    let mut lines = text.split_inclusive('\n');
    let Some(first) = lines.next().filter(|l| l.trim_end_matches(['\n', '\r']) == "---") else {
        return no_frontmatter(text);
    };
    let mut fields = Fields::default();
    let mut errors = Vec::new();
    let mut consumed = first.len();
    let mut closed = false;
    for (index, line) in lines.enumerate() {
        consumed += line.len();
        let line = line.trim_end_matches(['\n', '\r']);
        if line.trim_end() == "---" {
            closed = true;
            break;
        }
        if line.trim().is_empty() {
            continue;
        }
        match split_pair(line) {
            Some((key, raw)) => {
                if let Some(value) = value_of(raw) {
                    fields.0.insert(key.to_string(), value);
                } else {
                    fields.0.remove(key);
                }
            }
            None => errors.push(format!("frontmatter line {} is not `key: value`", index + 2)),
        }
    }
    if !closed {
        return no_frontmatter(text);
    }
    Parsed { fields: Some(fields), errors, body: text[consumed.min(text.len())..].to_string() }
}

fn no_frontmatter(text: &str) -> Parsed {
    Parsed {
        fields: None,
        errors: vec!["no frontmatter: a note starts with a --- block (see docs/MEMORY.md)".to_string()],
        body: text.to_string(),
    }
}

fn split_pair(line: &str) -> Option<(&str, &str)> {
    let colon = line.find(':')?;
    let key = &line[..colon];
    if key.is_empty() || !key.bytes().all(|c| c.is_ascii_lowercase() || c == b'_') {
        return None;
    }
    Some((key, &line[colon + 1..]))
}

/// The value after the colon, without a trailing comment (`#` at the start,
/// or after two or more spaces). None when it is empty.
fn value_of(raw: &str) -> Option<Value> {
    let text = strip_comment(raw).trim();
    if text.len() >= 2 && text.starts_with('[') && text.ends_with(']') {
        let items: Vec<String> =
            text[1..text.len() - 1].split(',').map(|item| unquote(item.trim()).to_string()).filter(|item| !item.is_empty()).collect();
        return (!items.is_empty()).then_some(Value::List(items));
    }
    let text = unquote(text);
    (!text.is_empty()).then_some(Value::Text(text.to_string()))
}

fn strip_comment(raw: &str) -> &str {
    let bytes = raw.as_bytes();
    if bytes.first() == Some(&b'#') {
        return "";
    }
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i].is_ascii_whitespace() {
            let start = i;
            while i < bytes.len() && bytes[i].is_ascii_whitespace() {
                i += 1;
            }
            if i - start >= 2 && bytes.get(i) == Some(&b'#') {
                return &raw[..start];
            }
        } else {
            i += 1;
        }
    }
    raw
}

fn unquote(text: &str) -> &str {
    let b = text.as_bytes();
    if b.len() >= 2 && (b[0] == b'"' || b[0] == b'\'') && b[b.len() - 1] == b[0] {
        &text[1..text.len() - 1]
    } else {
        text
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fields_lists_comments_and_body() {
        let parsed = parse(
            "---\nid: conv-money\ntype: convention           # convention | gotcha\nvalid_until:        # set later\n\
             aliases: [cents, \"price\", ]\nsummary: Use C# money; never Float.\n---\n\nBody\n",
        );
        let fields = parsed.fields.unwrap();
        assert!(parsed.errors.is_empty());
        assert_eq!(fields.text("type"), Some("convention"));
        assert!(!fields.has("valid_until"));
        assert_eq!(fields.list("aliases"), vec!["cents", "price"]);
        assert_eq!(fields.text("summary"), Some("Use C# money; never Float."));
        assert_eq!(fields.text("aliases"), None);
        assert_eq!(parsed.body, "\nBody\n");
    }

    #[test]
    fn bad_lines_and_missing_blocks() {
        let parsed = parse("---\nid: a\nNot a pair\n---\n");
        assert_eq!(parsed.errors, vec!["frontmatter line 3 is not `key: value`"]);
        assert!(parse("No frontmatter\n").fields.is_none());
        assert!(parse("---\nid: a\n").fields.is_none(), "an unclosed block is not frontmatter");
    }
}
