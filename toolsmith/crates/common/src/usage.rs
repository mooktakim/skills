//! The local usage log: one JSON line per run, so `scripts/analyse adoption`
//! can tell how often each tool runs, fails, and has its guide read. It never
//! records arguments or input, which can hold code.
//!
//! Location: `$TOOLSMITH_LOG`, else `$XDG_STATE_HOME/toolsmith/usage.jsonl`,
//! else `~/.local/state/toolsmith/usage.jsonl`. `TOOLSMITH_LOG=` (empty)
//! turns logging off. Logging problems never change a tool's result.

use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::json::quote;

pub fn log_path() -> Option<PathBuf> {
    if let Some(path) = std::env::var_os("TOOLSMITH_LOG") {
        return if path.is_empty() { None } else { Some(PathBuf::from(path)) };
    }
    let state = match std::env::var_os("XDG_STATE_HOME") {
        Some(dir) if !dir.is_empty() => PathBuf::from(dir),
        _ => PathBuf::from(std::env::var_os("HOME")?).join(".local/state"),
    };
    Some(state.join("toolsmith/usage.jsonl"))
}

pub fn record(tool: &str, mode: &str, code: i32, millis: u128) {
    let Some(path) = log_path() else { return };
    let ts = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    let cwd = std::env::current_dir().map(|d| d.display().to_string()).unwrap_or_default();
    let line = format!(
        "{{\"ts\":{},\"event\":\"run\",\"tool\":{},\"mode\":{},\"exit\":{},\"ms\":{},\"cwd\":{}}}\n",
        ts,
        quote(tool),
        quote(mode),
        code,
        millis,
        quote(&cwd)
    );
    if let Some(dir) = path.parent() {
        let _ = fs::create_dir_all(dir);
    }
    if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(&path) {
        let _ = file.write_all(line.as_bytes());
    }
}
