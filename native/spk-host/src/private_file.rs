//! The one reader of a host-private file: a regular file, not a link, one name, owned by this
//! process's user, mode 0600, within its bound, and the same file (device, inode, length, mtime,
//! ctime) from the name's lookup through the end of the read.
//!
//! The caller names what it reads: every refusal answers `InvalidData` with the caller's message;
//! an absent file or an I/O failure passes through as the OS reported it. A caller whose parent
//! directory is itself custody checks that directory first, as before.

use crate::io_context::IoContext;
use std::fs::{self, OpenOptions};
use std::io::{self, Read};
use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
use std::path::Path;

fn refused(message: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}

fn same_file(a: &fs::Metadata, b: &fs::Metadata) -> bool {
    (a.dev(), a.ino(), a.len(), a.mtime(), a.mtime_nsec(), a.ctime(), a.ctime_nsec())
        == (b.dev(), b.ino(), b.len(), b.mtime(), b.mtime_nsec(), b.ctime(), b.ctime_nsec())
}

fn read_bounded(path: &Path, min: u64, max: u64, message: &'static str) -> io::Result<Vec<u8>> {
    if !path.is_absolute() {
        return Err(refused(message));
    }
    let named = fs::symlink_metadata(&path).ctx("inspect", &path)?;
    let mut file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(&path).ctx("open", &path)?;
    let opened = file.metadata()?;
    if !opened.is_file()
        || opened.nlink() != 1
        || opened.uid() != unsafe { libc::geteuid() }
        || opened.mode() & 0o777 != 0o600
        || opened.len() < min
        || opened.len() > max
        || (named.dev(), named.ino()) != (opened.dev(), opened.ino())
    {
        return Err(refused(message));
    }
    let mut bytes = Vec::with_capacity(opened.len() as usize);
    file.by_ref().take(max + 1).read_to_end(&mut bytes)?;
    if bytes.len() as u64 != opened.len() || !same_file(&file.metadata()?, &opened) {
        return Err(refused(message));
    }
    Ok(bytes)
}

/// A nonempty host-private file of at most `max` bytes.
pub(crate) fn read(path: &Path, max: u64, message: &'static str) -> io::Result<Vec<u8>> {
    read_bounded(path, 1, max, message)
}

/// A host-private file of at most `max` bytes that may be empty.
pub(crate) fn read_maybe_empty(path: &Path, max: u64, message: &'static str) -> io::Result<Vec<u8>> {
    read_bounded(path, 0, max, message)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;

    fn scratch() -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "spk-private-file-{}-{}",
            std::process::id(),
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()
        ));
        fs::create_dir(&dir).unwrap();
        fs::set_permissions(&dir, fs::Permissions::from_mode(0o700)).unwrap();
        dir
    }

    fn private(path: &Path, bytes: &[u8]) {
        fs::write(path, bytes).unwrap();
        fs::set_permissions(path, fs::Permissions::from_mode(0o600)).unwrap();
    }

    #[test]
    fn reads_a_private_file_and_refuses_every_other_shape_by_the_callers_name() {
        let dir = scratch();
        let good = dir.join("good");
        private(&good, b"custody");
        assert_eq!(read(&good, 7, "x").unwrap(), b"custody");
        let named = |e: io::Error| e.kind() == io::ErrorKind::InvalidData && e.to_string() == "named refusal";
        assert!(named(read(&good, 6, "named refusal").unwrap_err()), "over the bound");
        assert!(named(read(Path::new("relative"), 7, "named refusal").unwrap_err()), "relative");
        let empty = dir.join("empty");
        private(&empty, b"");
        assert!(named(read(&empty, 7, "named refusal").unwrap_err()), "empty");
        assert_eq!(read_maybe_empty(&empty, 7, "x").unwrap(), b"");
        let open = dir.join("open");
        private(&open, b"x");
        fs::set_permissions(&open, fs::Permissions::from_mode(0o640)).unwrap();
        assert!(named(read(&open, 7, "named refusal").unwrap_err()), "mode 0640");
        let linked = dir.join("linked");
        fs::hard_link(&good, &linked).unwrap();
        assert!(named(read(&good, 7, "named refusal").unwrap_err()), "two names");
        fs::remove_file(&linked).unwrap();
        let symlink = dir.join("symlink");
        std::os::unix::fs::symlink(&good, &symlink).unwrap();
        assert!(read(&symlink, 7, "named refusal").is_err(), "a link");
        assert_eq!(read(&dir.join("absent"), 7, "x").unwrap_err().kind(), io::ErrorKind::NotFound);
        fs::remove_dir_all(dir).unwrap();
    }
}
