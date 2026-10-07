//! File writes that never leave a half-written file.

use std::fs;
use std::io;
use std::path::Path;

/// Writes through a temporary file in the same directory and renames it over
/// `path`. An existing file keeps its permissions; a symlink is followed, so
/// the link stays and its target changes.
pub fn write_atomically(path: &Path, contents: &[u8]) -> io::Result<()> {
    let path = match fs::canonicalize(path) {
        Ok(real) => real,
        Err(_) => path.to_path_buf(),
    };
    let permissions = fs::metadata(&path).ok().map(|m| m.permissions());
    let name = path.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
    let temp = path.with_file_name(format!(".{}.toolsmith-{}", name, std::process::id()));
    let result = fs::write(&temp, contents)
        .and_then(|_| match permissions {
            Some(p) => fs::set_permissions(&temp, p),
            None => Ok(()),
        })
        .and_then(|_| fs::rename(&temp, &path));
    if result.is_err() {
        let _ = fs::remove_file(&temp);
    }
    result
}
