//! Text helpers for tools that show other programs' output.

/// Removes ANSI escape sequences (colours, cursor moves) and carriage returns.
pub fn strip_ansi(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            '\u{1b}' => match chars.next() {
                Some('[') => {
                    for n in chars.by_ref() {
                        if ('@'..='~').contains(&n) {
                            break;
                        }
                    }
                }
                Some(']') => {
                    while let Some(n) = chars.next() {
                        if n == '\u{7}' {
                            break;
                        }
                        if n == '\u{1b}' {
                            chars.next();
                            break;
                        }
                    }
                }
                _ => {}
            },
            '\r' => {}
            c => out.push(c),
        }
    }
    out
}

/// The last `n` lines that are not blank.
pub fn last_nonblank<'a>(lines: &[&'a str], n: usize) -> Vec<&'a str> {
    let mut picked: Vec<&str> = lines.iter().rev().filter(|l| !l.trim().is_empty()).take(n).copied().collect();
    picked.reverse();
    picked
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_colours_and_carriage_returns() {
        assert_eq!(strip_ansi("\u{1b}[36;1mbin/test\u{1b}[0m ok\r"), "bin/test ok");
        assert_eq!(strip_ansi("a\u{1b}]8;;http://x\u{7}link\u{1b}]8;;\u{7}b"), "alinkb");
    }

    #[test]
    fn picks_the_last_nonblank_lines_in_order() {
        assert_eq!(last_nonblank(&["a", "", "b", "  ", "c", ""], 2), vec!["b", "c"]);
        assert_eq!(last_nonblank(&[""], 2), Vec::<&str>::new());
    }
}
