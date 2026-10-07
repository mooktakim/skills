//! Renders `--help` (short, for people) and `--llm` (the full guide, for an
//! agent) from the tool's manifest. Every example in the guide is run by the
//! test suite, so the guide cannot drift from what the tool does.

use crate::json::Value;

fn text<'a>(m: &'a Value, key: &str) -> &'a str {
    m.get(key).and_then(Value::as_str).unwrap_or("")
}

fn list<'a>(m: &'a Value, key: &str) -> &'a [Value] {
    m.get(key).and_then(Value::as_array).unwrap_or(&[])
}

pub fn help(m: &Value) -> String {
    let name = text(m, "name");
    let mut out = format!("{} - {}\n\nUsage: {}\n", name, text(m, "intent"), text(m, "usage"));
    if !list(m, "options").is_empty() {
        out.push_str("\nOptions:\n");
        for option in list(m, "options") {
            out.push_str(&format!("  {:<14} {}\n", text(option, "flag"), first_sentence(text(option, "text"))));
        }
    }
    out.push_str(&format!(
        "\nRun `{} --llm` for the full guide: when to use it, input format, exit codes and examples.\n",
        name
    ));
    out
}

pub fn llm(m: &Value) -> String {
    let name = text(m, "name");
    let mut out = format!("# {}\n\nPurpose: {}\n\nUsage: {}\n", name, text(m, "intent"), text(m, "usage"));
    section_list(&mut out, "Use it when", list(m, "use_when"));
    section_list(&mut out, "Do not use it for", list(m, "not_for"));
    section_text(&mut out, "Input", text(m, "input"));
    let options: Vec<String> = list(m, "options")
        .iter()
        .map(|o| format!("{}: {}", text(o, "flag"), text(o, "text")))
        .collect();
    let options = if options.is_empty() { "None.".to_string() } else { bullets(&options) };
    section_text(&mut out, "Options", options.trim_end());
    section_text(&mut out, "Output", text(m, "output"));
    let codes: Vec<String> = list(m, "exit_codes")
        .iter()
        .map(|c| format!("{}: {}", c.get("code").and_then(Value::as_i64).unwrap_or(-1), text(c, "text")))
        .collect();
    section_text(&mut out, "Exit codes", bullets(&codes).trim_end());
    out.push_str("\n## Examples\n");
    for (i, example) in list(m, "examples").iter().enumerate() {
        out.push_str(&example_text(name, i + 1, example));
    }
    out
}

fn first_sentence(s: &str) -> &str {
    match s.find(". ") {
        Some(i) => &s[..=i],
        None => s,
    }
}

fn bullets(items: &[String]) -> String {
    items.iter().map(|i| format!("- {}\n", i)).collect()
}

fn section_list(out: &mut String, title: &str, items: &[Value]) {
    let items: Vec<String> = items.iter().filter_map(Value::as_str).map(str::to_string).collect();
    section_text(out, title, bullets(&items).trim_end());
}

fn section_text(out: &mut String, title: &str, body: &str) {
    out.push_str(&format!("\n## {}\n\n{}\n", title, body.trim_end()));
}

/// Single-quotes an argument for display when the shell would split or expand it.
fn shell_word(arg: &str) -> String {
    if !arg.is_empty() && arg.chars().all(|c| c.is_ascii_alphanumeric() || "-_./=:@%+,".contains(c)) {
        arg.to_string()
    } else {
        format!("'{}'", arg.replace('\'', "'\\''"))
    }
}

fn files_text(files: &Value) -> String {
    let mut out = String::new();
    for (path, content) in files.as_object().unwrap_or(&[]) {
        out.push_str(&format!("--- {}\n{}", path, content.as_str().unwrap_or("")));
        if !out.ends_with('\n') {
            out.push('\n');
        }
    }
    out
}

fn example_text(name: &str, number: usize, e: &Value) -> String {
    let mut out = format!("\n### {}. {}\n", number, text(e, "title"));
    if let Some(files) = e.get("files") {
        out.push_str(&format!("\nFiles before:\n```\n{}```\n", files_text(files)));
    }
    if let Some(cwd) = e.get("cwd").and_then(Value::as_str) {
        out.push_str(&format!("\nRun from: {}\n", cwd));
    }
    let mut command = format!("$ {}", name);
    for arg in list(e, "args") {
        command.push(' ');
        command.push_str(&shell_word(arg.as_str().unwrap_or("")));
    }
    match e.get("stdin").and_then(Value::as_str) {
        Some(stdin) => {
            command.push_str(" <<'EOF'\n");
            command.push_str(stdin);
            if !stdin.ends_with('\n') {
                command.push('\n');
            }
            command.push_str("EOF");
        }
        None => {}
    }
    out.push_str(&format!("\nCommand:\n```\n{}\n```\n", command));
    let exit = e.get("exit").and_then(Value::as_i64).unwrap_or(0);
    out.push_str(&format!("\nExit code: {}\n", exit));
    let stdout = e.get("stdout").or_else(|| e.get("stdout_sample")).and_then(Value::as_str).unwrap_or("");
    if !stdout.is_empty() {
        let label = if e.get("stdout").is_some() { "Output" } else { "Output (sample; the date and time vary)" };
        out.push_str(&format!("\n{}:\n```\n{}```\n", label, stdout));
    }
    if let Some(stderr) = e.get("stderr").and_then(Value::as_str) {
        out.push_str(&format!("\nError output:\n```\n{}```\n", stderr));
    }
    if let Some(files) = e.get("files_after") {
        out.push_str(&format!("\nFiles after:\n```\n{}```\n", files_text(files)));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn manifest() -> Value {
        Value::parse(
            r#"{"name": "toolsmith-x-do", "intent": "Do x.", "usage": "toolsmith-x-do [--fast] <name>",
                "use_when": ["You need x."], "not_for": ["y"], "input": "A name.",
                "options": [{"flag": "--fast", "text": "Go fast. Skips checks."}],
                "output": "The result.", "exit_codes": [{"code": 0, "text": "Done."}],
                "examples": [{"title": "Basic", "args": ["a b"], "stdin": "line\n", "stdout": "ok\n", "exit": 0}]}"#,
        )
        .unwrap()
    }

    #[test]
    fn help_is_short_and_points_to_the_guide() {
        let h = help(&manifest());
        assert!(h.starts_with("toolsmith-x-do - Do x.\n"));
        assert!(h.contains("  --fast         Go fast.\n"));
        assert!(h.contains("toolsmith-x-do --llm"));
        assert!(!h.contains("Skips checks"));
    }

    #[test]
    fn llm_has_every_section_and_quotes_example_arguments() {
        let g = llm(&manifest());
        for title in ["Use it when", "Do not use it for", "Input", "Options", "Output", "Exit codes", "Examples"] {
            assert!(g.contains(&format!("\n## {}\n", title)), "{}", title);
        }
        assert!(g.contains("$ toolsmith-x-do 'a b' <<'EOF'\nline\nEOF"));
        assert!(g.contains("- --fast: Go fast. Skips checks.\n"));
    }
}
