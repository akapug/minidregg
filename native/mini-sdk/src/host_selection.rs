//! Selection of a caller's local semantic Host path.
//! This small std-only helper is independent of the native process/socket
//! feature. Calling it validates filesystem metadata; no image is executed.
use std::path::{Path, PathBuf};

use crate::Result;

/// Select the client's local semantic Host, never a remote serving Host.
/// Explicit CLI/toolchain pins precede MINI_LOCAL_HOST, then the supplied
/// fallback. Keeping this selection shared lets process-custody inspectors
/// recognize the same executable that the native client actually launches.
pub fn select_semantic_host(
    explicit: Option<&Path>,
    environment: Option<&std::ffi::OsStr>,
    fallback: &Path,
) -> Result<PathBuf> {
    let selected = explicit
        .map(Path::to_path_buf)
        .or_else(|| environment.map(PathBuf::from))
        .or_else(|| (!fallback.as_os_str().is_empty()).then(|| fallback.to_path_buf()))
        .ok_or("local author/inspect/signatures/assembly requires MINI_LOCAL_HOST")?;
    if !selected.is_absolute() {
        return Err("local semantic Host must be an absolute path".into());
    }
    let metadata = std::fs::metadata(&selected).map_err(|e| format!("local semantic Host: {e}"))?;
    if !metadata.is_file() {
        return Err("local semantic Host must be a regular file".into());
    }
    Ok(selected)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn semantic_host_selection_preserves_explicit_environment_fallback_precedence() {
        let dir = std::env::temp_dir().join(format!(
            "mini-sdk-host-selection-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir(&dir).unwrap();
        let explicit = dir.join("explicit");
        let environment = dir.join("environment");
        let fallback = dir.join("fallback");
        for path in [&explicit, &environment, &fallback] {
            fs::write(path, b"host").unwrap();
        }
        assert_eq!(
            select_semantic_host(Some(&explicit), Some(environment.as_os_str()), &fallback)
                .unwrap(),
            explicit
        );
        assert_eq!(
            select_semantic_host(None, Some(environment.as_os_str()), &fallback).unwrap(),
            environment
        );
        assert_eq!(
            select_semantic_host(None, None, &fallback).unwrap(),
            fallback
        );
        // Invalid higher-priority selections refuse; they never silently fall back.
        assert!(select_semantic_host(
            Some(Path::new("relative")),
            Some(environment.as_os_str()),
            &fallback
        )
        .is_err());
        assert!(
            select_semantic_host(None, Some(std::ffi::OsStr::new("relative")), &fallback).is_err()
        );
        assert!(select_semantic_host(Some(&dir), None, &fallback).is_err());
        assert!(
            select_semantic_host(None, Some(dir.join("missing").as_os_str()), &fallback).is_err()
        );
        assert!(select_semantic_host(None, None, Path::new("")).is_err());
        fs::remove_dir_all(dir).unwrap();
    }
}
