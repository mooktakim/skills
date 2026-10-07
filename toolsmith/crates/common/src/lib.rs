//! Shared parts of every toolsmith tool: the manifest each tool is built from
//! (`tool.json`, embedded at compile time), the `--help` and `--llm` guides
//! rendered from it, the exit-code convention, and the local usage log.
//!
//! A tool's `main` creates a `Tool`, passes its arguments through
//! `handle_guide_flags`, does its one job, and leaves through `Tool::exit` so
//! the run is logged.

pub mod fsutil;
mod guide;
pub mod json;
pub mod process;
pub mod text;
mod usage;

use std::time::Instant;

pub use json::Value;

/// The tool did its job.
pub const EXIT_OK: i32 = 0;
/// The tool understood the request but could not do it (no match, missing file...).
pub const EXIT_FAILED: i32 = 1;
/// The request itself was wrong: an unknown flag, a missing argument, bad input.
pub const EXIT_USAGE: i32 = 2;

pub struct Tool {
    manifest: Value,
    started: Instant,
}

impl Tool {
    /// Parses the manifest embedded in the binary. A broken manifest is a build
    /// bug that the test suite catches, so it panics.
    pub fn new(manifest: &str) -> Tool {
        let manifest = Value::parse(manifest).unwrap_or_else(|e| panic!("tool.json: {}", e));
        Tool { manifest, started: Instant::now() }
    }

    pub fn name(&self) -> &str {
        self.manifest.get("name").and_then(Value::as_str).expect("tool.json: name")
    }

    /// Answers `--llm`, `--help` and `-h` and exits; otherwise returns the
    /// arguments unchanged. `--llm` wins when both are given.
    pub fn handle_guide_flags(&self, args: Vec<String>) -> Vec<String> {
        if args.iter().any(|a| a == "--llm") {
            print!("{}", guide::llm(&self.manifest));
            self.finish("llm", EXIT_OK);
        }
        if args.iter().any(|a| a == "--help" || a == "-h") {
            print!("{}", guide::help(&self.manifest));
            self.finish("help", EXIT_OK);
        }
        args
    }

    /// Reports a wrong request and exits with `EXIT_USAGE`.
    pub fn usage_error(&self, message: &str) -> ! {
        let name = self.name();
        eprintln!("{}: {}\nRun `{} --help` for usage, or `{} --llm` for the full guide.", name, message, name, name);
        self.exit(EXIT_USAGE)
    }

    /// Reports a failure and exits with `EXIT_FAILED`.
    pub fn fail(&self, message: &str) -> ! {
        eprintln!("{}: {}", self.name(), message);
        self.exit(EXIT_FAILED)
    }

    /// Logs the run and exits with `code`.
    pub fn exit(&self, code: i32) -> ! {
        self.finish("run", code)
    }

    fn finish(&self, mode: &str, code: i32) -> ! {
        usage::record(self.name(), mode, code, self.started.elapsed().as_millis());
        std::process::exit(code)
    }
}
