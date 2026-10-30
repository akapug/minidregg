//! Shared by `#[path]` into spk-host and grain-runtime: the identity of one file inode, and the
//! SHA-256 of a file computed once per identity. A pinned binary (the 169 MB Lean host, bwrap, the
//! config) is hashed when first seen and whenever its identity changes; every other use re-reads
//! only the metadata. The identity is (dev, ino, size, mode, owner, mtime, ctime): a writer can set
//! mtime but not ctime, so an in-place edit is always seen.
#![allow(dead_code)]
use sha2::{Digest, Sha256};
use std::fs::{self, File};
use std::io::{self, Read};
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(crate) struct ImageFingerprint {
    dev: u64,
    ino: u64,
    size: u64,
    mode: u32,
    uid: u32,
    mtime: (i64, i64),
    ctime: (i64, i64),
}

impl ImageFingerprint {
    pub(crate) fn of(meta: &fs::Metadata) -> Self {
        Self {
            dev: meta.dev(),
            ino: meta.ino(),
            size: meta.size(),
            mode: meta.mode(),
            uid: meta.uid(),
            mtime: (meta.mtime(), meta.mtime_nsec()),
            ctime: (meta.ctime(), meta.ctime_nsec()),
        }
    }
}

fn hex(bytes: &[u8]) -> String {
    const DIGITS: &[u8; 16] = b"0123456789abcdef";
    let mut text = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        text.push(DIGITS[usize::from(byte >> 4)] as char);
        text.push(DIGITS[usize::from(byte & 15)] as char);
    }
    text
}

static DIGESTS: Mutex<Vec<(PathBuf, ImageFingerprint, String)>> = Mutex::new(Vec::new());

/// SHA-256 (lowercase hex) of the file at `path`, as `File::open(path)` reads it. The file is
/// opened and its descriptor's identity compared with the one the cached digest was taken under;
/// on a match the digest is returned without reading the contents. Otherwise the opened
/// descriptor is hashed, and the digest is kept only if the descriptor's identity did not change
/// while it was read.
pub(crate) fn cached_file_sha256(path: &Path) -> io::Result<String> {
    cached_regular_file_sha256(path, u64::MAX)
}

/// As `cached_file_sha256`, refusing (before any read) a descriptor that is not a regular file
/// or is longer than `maximum`.
pub(crate) fn cached_regular_file_sha256(path: &Path, maximum: u64) -> io::Result<String> {
    let mut file = File::open(path)?;
    let metadata = file.metadata()?;
    if !metadata.is_file() || metadata.len() > maximum {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "file has the wrong type or length"));
    }
    let opened = ImageFingerprint::of(&metadata);
    {
        let cache = DIGESTS.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        if let Some((_, _, digest)) = cache.iter().find(|(p, f, _)| p == path && *f == opened) {
            return Ok(digest.clone());
        }
    }
    let mut hasher = Sha256::new();
    let mut buffer = vec![0u8; 1024 * 1024];
    loop {
        let count = match file.read(&mut buffer) {
            Ok(count) => count,
            Err(error) if error.kind() == io::ErrorKind::Interrupted => continue,
            Err(error) => return Err(error),
        };
        if count == 0 {
            break;
        }
        hasher.update(&buffer[..count]);
    }
    let digest = hex(&hasher.finalize());
    if ImageFingerprint::of(&file.metadata()?) == opened {
        let mut cache = DIGESTS.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        cache.retain(|(p, _, _)| p != path);
        cache.push((path.to_path_buf(), opened, digest.clone()));
    }
    Ok(digest)
}

#[cfg(test)]
mod file_identity_tests {
    use super::*;

    #[test]
    fn a_digest_is_kept_per_identity_and_recomputed_when_the_file_changes() {
        let path = std::env::temp_dir().join(format!("mini-file-identity-{}", std::process::id()));
        fs::write(&path, b"abc").unwrap();
        let abc = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";
        assert_eq!(cached_file_sha256(&path).unwrap(), abc);
        assert_eq!(cached_file_sha256(&path).unwrap(), abc);
        // Same length, new content: ctime moves, so the digest is recomputed.
        std::thread::sleep(std::time::Duration::from_millis(30));
        fs::write(&path, b"abd").unwrap();
        assert_ne!(cached_file_sha256(&path).unwrap(), abc);
        assert!(cached_regular_file_sha256(&path, 2).is_err());
        assert!(cached_regular_file_sha256(&std::env::temp_dir(), 1 << 20).is_err());
        fs::remove_file(&path).unwrap();
    }
}
