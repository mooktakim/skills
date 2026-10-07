//! Runs another program (git, gh) and captures what it printed.

use std::process::Command;

pub struct Output {
    pub success: bool,
    pub stdout: String,
    pub stderr: String,
}

/// Runs `program` with `args` and waits for it. Err when it cannot start,
/// for example because it is not installed.
pub fn run(program: &str, args: &[&str]) -> Result<Output, String> {
    let out = Command::new(program)
        .args(args)
        .output()
        .map_err(|e| format!("could not run {}: {}", program, e))?;
    Ok(Output {
        success: out.status.success(),
        stdout: String::from_utf8_lossy(&out.stdout).into_owned(),
        stderr: String::from_utf8_lossy(&out.stderr).trim().to_string(),
    })
}
