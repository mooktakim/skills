//! A small JSON reader for the tool manifests, plus string quoting for the
//! usage log. Standard library only, so tools build without network access.

#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    Null,
    Bool(bool),
    Number(f64),
    String(String),
    Array(Vec<Value>),
    /// Keys keep their file order, so guides list sections as written.
    Object(Vec<(String, Value)>),
}

impl Value {
    pub fn parse(text: &str) -> Result<Value, String> {
        let mut parser = Parser { bytes: text.as_bytes(), pos: 0 };
        let value = parser.value()?;
        parser.space();
        if parser.pos != parser.bytes.len() {
            return Err(parser.error("unexpected text after the value"));
        }
        Ok(value)
    }

    pub fn get(&self, key: &str) -> Option<&Value> {
        match self {
            Value::Object(pairs) => pairs.iter().find(|(k, _)| k == key).map(|(_, v)| v),
            _ => None,
        }
    }

    pub fn as_str(&self) -> Option<&str> {
        match self {
            Value::String(s) => Some(s),
            _ => None,
        }
    }

    pub fn as_array(&self) -> Option<&[Value]> {
        match self {
            Value::Array(items) => Some(items),
            _ => None,
        }
    }

    pub fn as_object(&self) -> Option<&[(String, Value)]> {
        match self {
            Value::Object(pairs) => Some(pairs),
            _ => None,
        }
    }

    pub fn as_i64(&self) -> Option<i64> {
        match self {
            Value::Number(n) if n.fract() == 0.0 => Some(*n as i64),
            _ => None,
        }
    }
}

/// Quotes `s` as a JSON string literal.
pub fn quote(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

struct Parser<'a> {
    bytes: &'a [u8],
    pos: usize,
}

impl<'a> Parser<'a> {
    fn error(&self, message: &str) -> String {
        format!("{} at byte {}", message, self.pos)
    }

    fn space(&mut self) {
        while let Some(b' ' | b'\n' | b'\r' | b'\t') = self.bytes.get(self.pos) {
            self.pos += 1;
        }
    }

    fn expect(&mut self, literal: &str, value: Value) -> Result<Value, String> {
        if self.bytes[self.pos..].starts_with(literal.as_bytes()) {
            self.pos += literal.len();
            Ok(value)
        } else {
            Err(self.error("invalid literal"))
        }
    }

    fn value(&mut self) -> Result<Value, String> {
        self.space();
        match self.bytes.get(self.pos) {
            None => Err(self.error("unexpected end of input")),
            Some(b'{') => self.object(),
            Some(b'[') => self.array(),
            Some(b'"') => self.string().map(Value::String),
            Some(b't') => self.expect("true", Value::Bool(true)),
            Some(b'f') => self.expect("false", Value::Bool(false)),
            Some(b'n') => self.expect("null", Value::Null),
            Some(b'-' | b'0'..=b'9') => self.number(),
            Some(_) => Err(self.error("unexpected character")),
        }
    }

    fn object(&mut self) -> Result<Value, String> {
        self.pos += 1;
        let mut pairs = Vec::new();
        self.space();
        if self.bytes.get(self.pos) == Some(&b'}') {
            self.pos += 1;
            return Ok(Value::Object(pairs));
        }
        loop {
            self.space();
            if self.bytes.get(self.pos) != Some(&b'"') {
                return Err(self.error("expected a key"));
            }
            let key = self.string()?;
            self.space();
            if self.bytes.get(self.pos) != Some(&b':') {
                return Err(self.error("expected ':'"));
            }
            self.pos += 1;
            let value = self.value()?;
            pairs.push((key, value));
            self.space();
            match self.bytes.get(self.pos) {
                Some(b',') => self.pos += 1,
                Some(b'}') => {
                    self.pos += 1;
                    return Ok(Value::Object(pairs));
                }
                _ => return Err(self.error("expected ',' or '}'")),
            }
        }
    }

    fn array(&mut self) -> Result<Value, String> {
        self.pos += 1;
        let mut items = Vec::new();
        self.space();
        if self.bytes.get(self.pos) == Some(&b']') {
            self.pos += 1;
            return Ok(Value::Array(items));
        }
        loop {
            items.push(self.value()?);
            self.space();
            match self.bytes.get(self.pos) {
                Some(b',') => self.pos += 1,
                Some(b']') => {
                    self.pos += 1;
                    return Ok(Value::Array(items));
                }
                _ => return Err(self.error("expected ',' or ']'")),
            }
        }
    }

    fn hex4(&mut self) -> Result<u32, String> {
        let digits = self.bytes.get(self.pos..self.pos + 4).ok_or_else(|| self.error("short \\u escape"))?;
        let text = std::str::from_utf8(digits).map_err(|_| self.error("bad \\u escape"))?;
        let code = u32::from_str_radix(text, 16).map_err(|_| self.error("bad \\u escape"))?;
        self.pos += 4;
        Ok(code)
    }

    fn string(&mut self) -> Result<String, String> {
        self.pos += 1;
        let mut out: Vec<u8> = Vec::new();
        loop {
            let byte = *self.bytes.get(self.pos).ok_or_else(|| self.error("unterminated string"))?;
            self.pos += 1;
            match byte {
                b'"' => return String::from_utf8(out).map_err(|_| self.error("invalid UTF-8")),
                b'\\' => {
                    let escape = *self.bytes.get(self.pos).ok_or_else(|| self.error("unterminated escape"))?;
                    self.pos += 1;
                    let c = match escape {
                        b'"' => '"',
                        b'\\' => '\\',
                        b'/' => '/',
                        b'b' => '\u{8}',
                        b'f' => '\u{c}',
                        b'n' => '\n',
                        b'r' => '\r',
                        b't' => '\t',
                        b'u' => {
                            let mut code = self.hex4()?;
                            if (0xD800..0xDC00).contains(&code) && self.bytes[self.pos..].starts_with(b"\\u") {
                                self.pos += 2;
                                let low = self.hex4()?;
                                code = 0x10000 + ((code - 0xD800) << 10) + (low.wrapping_sub(0xDC00) & 0x3FF);
                            }
                            char::from_u32(code).ok_or_else(|| self.error("invalid \\u escape"))?
                        }
                        _ => return Err(self.error("invalid escape")),
                    };
                    let mut buf = [0u8; 4];
                    out.extend_from_slice(c.encode_utf8(&mut buf).as_bytes());
                }
                b if b < 0x20 => return Err(self.error("control character in string")),
                b => out.push(b),
            }
        }
    }

    fn number(&mut self) -> Result<Value, String> {
        let start = self.pos;
        while let Some(b'-' | b'+' | b'.' | b'e' | b'E' | b'0'..=b'9') = self.bytes.get(self.pos) {
            self.pos += 1;
        }
        let text = std::str::from_utf8(&self.bytes[start..self.pos]).unwrap_or("");
        text.parse::<f64>().map(Value::Number).map_err(|_| self.error("invalid number"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_nested_values_in_order() {
        let v = Value::parse(r#" {"b": [1, -2.5, true, null], "a": {"x": "y"}} "#).unwrap();
        let keys: Vec<&str> = v.as_object().unwrap().iter().map(|(k, _)| k.as_str()).collect();
        assert_eq!(keys, ["b", "a"]);
        assert_eq!(v.get("b").unwrap().as_array().unwrap()[0].as_i64(), Some(1));
        assert_eq!(v.get("b").unwrap().as_array().unwrap()[1], Value::Number(-2.5));
        assert_eq!(v.get("a").unwrap().get("x").unwrap().as_str(), Some("y"));
    }

    #[test]
    fn decodes_escapes_and_utf8() {
        let v = Value::parse(r#""a\"b\\c\né😀 – ok""#).unwrap();
        assert_eq!(v.as_str(), Some("a\"b\\c\né😀 – ok"));
    }

    #[test]
    fn rejects_broken_json() {
        assert!(Value::parse("{\"a\": 1,}").is_err());
        assert!(Value::parse("[1 2]").is_err());
        assert!(Value::parse("\"open").is_err());
        assert!(Value::parse("{} x").is_err());
    }

    #[test]
    fn quote_round_trips() {
        let s = "tab\there \"quoted\" back\\slash\nnew \u{1} é";
        assert_eq!(Value::parse(&quote(s)).unwrap().as_str(), Some(s));
    }
}
