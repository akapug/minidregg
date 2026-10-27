//! Durable file publication: the ONE implementation of "this file is complete or absent".
//!
//! Every function stages the bytes in a unique `0600`/mode-chosen sibling (never at the final
//! name), `fsync`s the file, commits the final name atomically, then `fsync`s the directory:
//!
//! - [`replace`]: temp, fsync, `rename`, fsync dir. The final name is the old bytes or the new
//!   bytes, never a prefix of either.
//! - [`create_new`]: temp, fsync, `link` (fails if the name exists), fsync dir, unlink temp. The
//!   final name is absent or complete; an existing name is never touched.
//! - [`retain_exact`]: `create_new`, or on an existing name a byte comparison, so a replay of the
//!   same custody write is idempotent and a different one is refused.
//!
//! Key material goes through these and nowhere else: a crash can never leave a partial secret
//! (or an empty file a later run reads as one) at its final name.
//!
//! Deferred directory syncs ([`defer_directory_syncs`]): a process that publishes many files
//! between two externally visible steps may opt in to coalescing the directory `fsync`s. The file
//! itself is still staged and `fsync`ed before its name is committed, so "complete or absent" (and
//! "old or new") holds at every crash point exactly as before; what is deferred is only the
//! durability of the *name*, until the next barrier: [`flush_directory_syncs`], or any of
//! [`sync_dir`], [`sync_parent`], [`sync_ancestors`], which flush first. A crash before the barrier
//! may forget a name committed since the last one (the directory as it was at that barrier), never
//! expose a partial file. The opting-in process must reach a barrier before anything outside it may
//! depend on those names (a request to a service, its exit).
//!
//! Caches (`crate::phase`): inside a thread's cache scope a file is still staged and linked
//! complete, but neither it nor its name is synced; the attempt's seal record is the durable copy
//! and readers repair the cache from it. Everything outside a scope is unchanged.
//!
//! The `*_with` forms take a [`Stage`] observer called at each crash boundary. An observer error
//! models the process dying at that point: it propagates at once and nothing is cleaned up, so a
//! test sees exactly the bytes a crash leaves behind.
use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Write};
use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Mutex;

/// File permissions of a published file.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Perm {
    /// Owner read/write only (`0600`): custody evidence and every secret.
    Private,
    /// Owner read/write/execute only (`0700`): a retained executable.
    PrivateExecutable,
    /// The process umask decides: public material (a public key).
    Umask,
}

impl Perm {
    fn mode(self) -> Option<u32> {
        match self {
            Perm::Private => Some(0o600),
            Perm::PrivateExecutable => Some(0o700),
            Perm::Umask => None,
        }
    }
}

/// The crash boundaries of a publication, in order. `AfterCommit` is the instant the final name
/// holds the new bytes; `AfterDirectorySync` is when that is durable.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Stage {
    /// Half of the bytes are in the staging file.
    MidWrite,
    /// All bytes are written, not yet fsynced.
    BeforeFileSync,
    /// The staging file is durable; the final name is not yet committed.
    BeforeCommit,
    /// The final name is committed; the directory entry is not yet durable.
    AfterCommit,
    /// The directory is synced (when deferring: queued for the next barrier).
    AfterDirectorySync,
}

/// `fsync` a directory (so a rename, link or unlink inside it survives power loss). A barrier:
/// every deferred directory sync is flushed first.
pub fn sync_dir(directory: &Path) -> io::Result<()> {
    flush_directory_syncs()?;
    fsync_dir(directory)
}

fn fsync_dir(directory: &Path) -> io::Result<()> {
    sync_file(&File::open(directory)?)
}

thread_local! {
    static FSYNCS: std::cell::Cell<u64> = const { std::cell::Cell::new(0) };
}

/// `fsync` one open file or directory, counted ([`fsyncs`]).
pub fn sync_file(file: &File) -> io::Result<()> {
    FSYNCS.with(|n| n.set(n.get() + 1));
    file.sync_all()
}

/// How many `fsync`s this thread has issued through this module (files and directories): one
/// signed write runs on one thread, so this is its count.
pub fn fsyncs() -> u64 {
    FSYNCS.with(|n| n.get())
}

static DEFER: AtomicBool = AtomicBool::new(false);
/// The directories holding names committed since the last barrier, by (device, inode), each held
/// open so a directory renamed or removed meanwhile is still the one synced.
static PENDING: Mutex<Vec<(u64, u64, File)>> = Mutex::new(Vec::new());

/// Opt this process in to deferred directory syncs (see the module documentation). There is no
/// opt-out: a process that opts in owns reaching a barrier before its names matter outside it.
pub fn defer_directory_syncs() {
    DEFER.store(true, Ordering::SeqCst);
}

/// Whether this process defers directory syncs.
pub fn deferring_directory_syncs() -> bool {
    DEFER.load(Ordering::SeqCst)
}

/// The barrier: `fsync` every directory a name was committed in since the last barrier. On an
/// error the directories not yet synced stay pending, so a later barrier retries them.
pub fn flush_directory_syncs() -> io::Result<()> {
    let mut pending = PENDING.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
    while let Some((_, _, directory)) = pending.last() {
        sync_file(directory)?;
        pending.pop();
    }
    Ok(())
}

/// Make the name just committed at `path` durable: now, or at the next barrier when deferring.
fn commit_name(path: &Path) -> io::Result<()> {
    // A cache's name is made durable with its directory at the seal (`crate::phase`): the record
    // names it, and a reader recreates it if a crash lost it.
    if crate::phase::is_cache(path) {
        return Ok(());
    }
    if !deferring_directory_syncs() {
        return fsync_dir(parent_of(path)?);
    }
    let directory = File::open(parent_of(path)?)?;
    let meta = directory.metadata()?;
    let mut pending = PENDING.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
    if !pending.iter().any(|(dev, ino, _)| *dev == meta.dev() && *ino == meta.ino()) {
        pending.push((meta.dev(), meta.ino(), directory));
    }
    Ok(())
}

/// `fsync` the directory holding `path`.
pub fn sync_parent(path: &Path) -> io::Result<()> {
    sync_dir(parent_of(path)?)
}

/// `fsync` `directory` and every ancestor up to `/`: a freshly created chain of directories is
/// durable only when each entry is.
///
/// An ancestor this process can neither open nor create entries in is skipped: it holds nothing
/// this process made. A hosted friend's session directory sits under root's `0711`
/// `/var/lib/mini/sessions`, which that account may traverse but not read. An ancestor it can
/// write into but not open still refuses: it may hold this process's own new entries.
pub fn sync_ancestors(directory: &Path) -> io::Result<()> {
    flush_directory_syncs()?;
    let mut ancestor = Some(std::path::absolute(directory)?);
    while let Some(path) = ancestor {
        match fsync_dir(&path) {
            Ok(()) => {}
            Err(e) if e.kind() == io::ErrorKind::PermissionDenied && !can_create_in(&path) => {}
            Err(e) => return Err(e),
        }
        ancestor = path.parent().map(Path::to_path_buf);
    }
    Ok(())
}

/// Whether this process may create entries in `directory` (write and search permission).
fn can_create_in(directory: &Path) -> bool {
    use std::os::unix::ffi::OsStrExt;
    let Ok(c) = std::ffi::CString::new(directory.as_os_str().as_bytes()) else { return true };
    // SAFETY: `c` is a valid NUL-terminated path for the duration of the call.
    unsafe { libc::access(c.as_ptr(), libc::W_OK | libc::X_OK) == 0 }
}

fn parent_of(path: &Path) -> io::Result<&Path> {
    match path.parent() {
        Some(p) if p.as_os_str().is_empty() => Ok(Path::new(".")),
        Some(p) => Ok(p),
        None => Err(io::Error::new(io::ErrorKind::InvalidInput, format!("{} has no parent directory", path.display()))),
    }
}

static COUNTER: AtomicU64 = AtomicU64::new(0);

/// A staging file in the directory of `path`: exclusive, no symlink follow, never the final name.
fn stage_file(path: &Path, perm: Perm) -> io::Result<(File, PathBuf)> {
    let parent = parent_of(path)?;
    let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("file");
    let mut last = None;
    for _ in 0..16 {
        let nonce = COUNTER.fetch_add(1, Ordering::Relaxed);
        let nanos = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.subsec_nanos()).unwrap_or(0);
        let temp = parent.join(format!(".{name}.durable-{}-{nonce}-{nanos:08x}", std::process::id()));
        let mut options = OpenOptions::new();
        options.write(true).create_new(true).custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC);
        if let Some(mode) = perm.mode() {
            options.mode(mode);
        }
        match options.open(&temp) {
            Ok(file) => return Ok((file, temp)),
            Err(e) if e.kind() == io::ErrorKind::AlreadyExists => last = Some(e),
            Err(e) => return Err(e),
        }
    }
    Err(last.unwrap_or_else(|| io::Error::other("no free staging name")))
}

/// Stage `bytes` durably; returns the staging path. IO errors remove the staging file; a stage
/// observer error (a modelled crash) leaves it.
fn staged(
    path: &Path,
    perm: Perm,
    bytes: &mut dyn Read,
    length_hint: Option<usize>,
    observe: &mut dyn FnMut(Stage) -> io::Result<()>,
) -> Result<PathBuf, Crash> {
    let (mut file, temp) = stage_file(path, perm).map_err(Crash::Io)?;
    let mut write = || -> Result<(), Crash> {
        let mut buffer = [0u8; 64 * 1024];
        let mut first = true;
        loop {
            // The first read is half of a known length, so MidWrite is a real partial write.
            let cap = match length_hint {
                Some(l) if first && l > 1 => (l / 2).min(buffer.len()),
                _ => buffer.len(),
            };
            let n = bytes.read(&mut buffer[..cap]).map_err(Crash::Io)?;
            if n == 0 {
                break;
            }
            file.write_all(&buffer[..n]).map_err(Crash::Io)?;
            if first {
                observe(Stage::MidWrite).map_err(Crash::Observer)?;
                first = false;
            }
        }
        if first {
            observe(Stage::MidWrite).map_err(Crash::Observer)?;
        }
        observe(Stage::BeforeFileSync).map_err(Crash::Observer)?;
        // A cache of an attempt's seal record (`crate::phase`, invariant 2) is staged and linked
        // without its own fsync: the record, written before anything can depend on it, is the
        // durable copy, and readers repair the cache from it.
        if !crate::phase::is_cache(path) {
            sync_file(&file).map_err(Crash::Io)?;
        }
        observe(Stage::BeforeCommit).map_err(Crash::Observer)
    };
    match write() {
        Ok(()) => Ok(temp),
        Err(Crash::Io(e)) => {
            let _ = fs::remove_file(&temp);
            Err(Crash::Io(e))
        }
        Err(crash) => Err(crash),
    }
}

enum Crash {
    Io(io::Error),
    Observer(io::Error),
}
impl Crash {
    fn into_io(self) -> io::Error {
        match self {
            Crash::Io(e) | Crash::Observer(e) => e,
        }
    }
}

/// Atomically replace (or create) `path` with `bytes`: temp, fsync, rename, fsync directory.
pub fn replace(path: &Path, bytes: &[u8], perm: Perm) -> io::Result<()> {
    replace_with(path, bytes, perm, &mut |_| Ok(()))
}

/// [`replace`] with a crash-boundary observer.
pub fn replace_with(path: &Path, bytes: &[u8], perm: Perm, observe: &mut dyn FnMut(Stage) -> io::Result<()>) -> io::Result<()> {
    let temp = staged(path, perm, &mut &*bytes, Some(bytes.len()), observe).map_err(Crash::into_io)?;
    if let Err(e) = fs::rename(&temp, path) {
        let _ = fs::remove_file(&temp);
        return Err(e);
    }
    observe(Stage::AfterCommit)?;
    commit_name(path)?;
    observe(Stage::AfterDirectorySync)
}

/// Atomically create `path` with `bytes`, refusing (`AlreadyExists`) if the name is taken:
/// temp, fsync, hard link, fsync directory, unlink temp. Absent or complete, never partial.
pub fn create_new(path: &Path, bytes: &[u8], perm: Perm) -> io::Result<()> {
    create_new_with(path, bytes, perm, &mut |_| Ok(()))
}

/// [`create_new`] with a crash-boundary observer.
pub fn create_new_with(path: &Path, bytes: &[u8], perm: Perm, observe: &mut dyn FnMut(Stage) -> io::Result<()>) -> io::Result<()> {
    create_new_from(path, &mut &*bytes, Some(bytes.len()), perm, observe)
}

/// [`create_new`] from a reader (a retained executable copied from its source).
pub fn create_new_from(
    path: &Path,
    source: &mut dyn Read,
    length_hint: Option<usize>,
    perm: Perm,
    observe: &mut dyn FnMut(Stage) -> io::Result<()>,
) -> io::Result<()> {
    let temp = staged(path, perm, source, length_hint, observe).map_err(Crash::into_io)?;
    if let Err(e) = fs::hard_link(&temp, path) {
        let _ = fs::remove_file(&temp);
        return Err(e);
    }
    observe(Stage::AfterCommit)?;
    commit_name(path)?;
    observe(Stage::AfterDirectorySync)?;
    fs::remove_file(&temp)
}

/// What [`retain_exact`] did.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Retained {
    /// The name was free and now holds the bytes durably.
    Created,
    /// The name already held exactly these bytes; its directory entry was re-synced.
    Matched,
}

/// Why [`retain_exact`] refused.
#[derive(Debug)]
pub enum RetainError {
    /// The name holds different bytes (or a different length from `limit`'s view).
    Differs,
    Io(io::Error),
}
impl std::fmt::Display for RetainError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            RetainError::Differs => f.write_str("retained bytes differ from the requested bytes"),
            RetainError::Io(e) => e.fmt(f),
        }
    }
}

/// Retain `bytes` at `path` exactly once. A free name is created durably; an existing name must
/// hold the same bytes (compared bounded by `bytes.len()+1`), and is then re-synced, because a
/// replay may be the first run to observe a rename whose directory fsync was lost.
pub fn retain_exact(path: &Path, bytes: &[u8], perm: Perm) -> Result<Retained, RetainError> {
    match create_new(path, bytes, perm) {
        Ok(()) => Ok(Retained::Created),
        Err(e) if e.kind() == io::ErrorKind::AlreadyExists => {
            let mut file = OpenOptions::new().read(true).custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC).open(path).map_err(RetainError::Io)?;
            let meta = file.metadata().map_err(RetainError::Io)?;
            if !meta.is_file() || meta.size() != bytes.len() as u64 {
                return Err(RetainError::Differs);
            }
            let mut held = Vec::with_capacity(bytes.len());
            (&mut file).take(bytes.len() as u64 + 1).read_to_end(&mut held).map_err(RetainError::Io)?;
            if held != bytes {
                return Err(RetainError::Differs);
            }
            sync_file(&file).map_err(RetainError::Io)?;
            commit_name(path).map_err(RetainError::Io)?;
            Ok(Retained::Matched)
        }
        Err(e) => Err(RetainError::Io(e)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scratch(tag: &str) -> PathBuf {
        let p = std::env::temp_dir().join(format!("mini-sdk-durable-{tag}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&p);
        fs::create_dir_all(&p).unwrap();
        p
    }

    /// An ancestor the account may traverse but neither read nor write (a hosted friend's session
    /// under root's 0711 directory) is skipped; one it may write but not read still refuses.
    /// Root opens anything, so the rows are vacuous there and say so.
    #[test]
    fn sync_ancestors_skips_what_the_account_cannot_open_or_write_and_refuses_what_it_can_write() {
        use std::os::unix::fs::PermissionsExt;
        if unsafe { libc::geteuid() } == 0 {
            eprintln!("sync_ancestors permission rows need a non-root account; skipped");
            return;
        }
        let root = scratch("ancestors");
        let outer = root.join("outer");
        let inner = outer.join("inner");
        fs::create_dir_all(&inner).unwrap();
        let mode = |m: u32| fs::set_permissions(&outer, fs::Permissions::from_mode(m)).unwrap();
        mode(0o111);
        let skipped = sync_ancestors(&inner);
        mode(0o311);
        let refused = sync_ancestors(&inner);
        mode(0o755);
        let _ = fs::remove_dir_all(&root);
        skipped.expect("a traverse-only ancestor holds nothing this account made");
        assert_eq!(refused.expect_err("a writable, unreadable ancestor may hold our entries").kind(), io::ErrorKind::PermissionDenied);
    }

    fn leftovers(dir: &Path) -> Vec<String> {
        let mut v: Vec<String> = fs::read_dir(dir).unwrap().map(|e| e.unwrap().file_name().to_string_lossy().into_owned()).collect();
        v.sort();
        v
    }

    /// Run `f` in a forked child that dies (`_exit`) at crash boundary `at`, with no unwinding and
    /// no cleanup, exactly as a killed process would. Returns true when the child reached `at`.
    fn die_at(at: Stage, f: impl FnOnce(&mut dyn FnMut(Stage) -> io::Result<()>)) -> bool {
        // SAFETY: the child only runs the primitive and `_exit`s; the parent waits for it.
        let pid = unsafe { libc::fork() };
        assert!(pid >= 0);
        if pid == 0 {
            f(&mut |stage| {
                if stage == at {
                    unsafe { libc::_exit(77) };
                }
                Ok(())
            });
            unsafe { libc::_exit(0) };
        }
        let mut status = 0;
        assert_eq!(unsafe { libc::waitpid(pid, &mut status, 0) }, pid);
        libc::WIFEXITED(status) && libc::WEXITSTATUS(status) == 77
    }

    const STAGES: [Stage; 5] = [Stage::MidWrite, Stage::BeforeFileSync, Stage::BeforeCommit, Stage::AfterCommit, Stage::AfterDirectorySync];

    #[test]
    fn replace_is_old_or_new_never_partial_across_a_kill_at_every_boundary() {
        let old = vec![b'o'; 4096];
        let new = vec![b'n'; 8192];
        for at in STAGES {
            let dir = scratch(&format!("replace-{at:?}"));
            let target = dir.join("record");
            replace(&target, &old, Perm::Private).unwrap();
            assert!(die_at(at, |obs| {
                let _ = replace_with(&target, &new, Perm::Private, obs);
            }), "child must reach {at:?}");
            let held = fs::read(&target).unwrap();
            let committed = matches!(at, Stage::AfterCommit | Stage::AfterDirectorySync);
            assert_eq!(held, if committed { new.clone() } else { old.clone() }, "kill at {at:?}");
            assert!(held == old || held == new, "never a prefix");
            fs::remove_dir_all(dir).unwrap();
        }
    }

    /// Deferring directory syncs changes when a name becomes durable, never what a crash can leave
    /// at it: the same kill at every boundary, in a child that deferred, leaves old or new.
    #[test]
    fn deferred_replace_is_still_old_or_new_across_a_kill_at_every_boundary() {
        let old = vec![b'o'; 4096];
        let new = vec![b'n'; 8192];
        for at in STAGES {
            let dir = scratch(&format!("deferred-replace-{at:?}"));
            let target = dir.join("record");
            replace(&target, &old, Perm::Private).unwrap();
            assert!(die_at(at, |obs| {
                defer_directory_syncs();
                let _ = replace_with(&target, &new, Perm::Private, obs);
            }), "child must reach {at:?}");
            let held = fs::read(&target).unwrap();
            let committed = matches!(at, Stage::AfterCommit | Stage::AfterDirectorySync);
            assert_eq!(held, if committed { new.clone() } else { old.clone() }, "kill at {at:?}");
            fs::remove_dir_all(dir).unwrap();
        }
    }

    /// The barrier syncs the directory a name was committed in, by the directory itself: one that
    /// was renamed or removed after the commit is still synced (or harmlessly gone), and a sync
    /// wrapper (`sync_parent`) is a barrier too. Runs in a forked child, since deferral is
    /// process-wide.
    #[test]
    fn deferred_names_are_synced_at_the_barrier_by_directory_identity() {
        let root = scratch("deferred-barrier");
        let pid = unsafe { libc::fork() };
        assert!(pid >= 0);
        if pid == 0 {
            let check = || -> io::Result<bool> {
                defer_directory_syncs();
                let one = root.join("one");
                fs::create_dir(&one)?;
                replace(&one.join("a"), b"a", Perm::Private)?;
                create_new(&one.join("b"), b"b", Perm::Private)?;
                let queued = PENDING.lock().unwrap().len();
                fs::rename(&one, root.join("moved"))?;
                flush_directory_syncs()?;
                let flushed = PENDING.lock().unwrap().is_empty();
                let gone = root.join("gone");
                fs::create_dir(&gone)?;
                replace(&gone.join("c"), b"c", Perm::Private)?;
                fs::remove_file(gone.join("c"))?;
                fs::remove_dir(&gone)?;
                replace(&root.join("d"), b"d", Perm::Private)?;
                sync_parent(&root.join("d"))?;
                Ok(queued == 1 && flushed && PENDING.lock().unwrap().is_empty())
            };
            unsafe { libc::_exit(if matches!(check(), Ok(true)) { 0 } else { 1 }) };
        }
        let mut status = 0;
        assert_eq!(unsafe { libc::waitpid(pid, &mut status, 0) }, pid);
        let _ = fs::remove_dir_all(&root);
        assert!(libc::WIFEXITED(status) && libc::WEXITSTATUS(status) == 0, "child status {status}");
    }

    #[test]
    fn create_new_is_absent_or_complete_across_a_kill_at_every_boundary() {
        let payload = b"0123456789abcdef0123456789abcdef".to_vec();
        for at in STAGES {
            let dir = scratch(&format!("create-{at:?}"));
            let target = dir.join("secret.key");
            assert!(die_at(at, |obs| {
                let _ = create_new_with(&target, &payload, Perm::Private, obs);
            }), "child must reach {at:?}");
            match fs::read(&target) {
                Ok(held) => {
                    assert_eq!(held, payload, "a present name is complete (kill at {at:?})");
                    assert!(matches!(at, Stage::AfterCommit | Stage::AfterDirectorySync));
                }
                Err(e) => {
                    assert_eq!(e.kind(), io::ErrorKind::NotFound);
                    assert!(!matches!(at, Stage::AfterCommit | Stage::AfterDirectorySync));
                }
            }
            // A retry after the crash completes the write; the leftover staging file is inert.
            match retain_exact(&target, &payload, Perm::Private) {
                Ok(Retained::Created | Retained::Matched) => {}
                Err(e) => panic!("retry after kill at {at:?}: {e}"),
            }
            assert_eq!(fs::read(&target).unwrap(), payload);
            fs::remove_dir_all(dir).unwrap();
        }
    }

    /// Control: the harness can see the failure the primitive prevents. The direct write the
    /// resource-client used for key material (create the final name, then write) leaves a prefix
    /// at the final name when the process dies mid-write.
    #[test]
    fn control_a_direct_write_to_the_final_name_leaves_a_prefix_the_harness_detects() {
        let dir = scratch("control");
        let target = dir.join("seed");
        let payload = [7u8; 32];
        assert!(die_at(Stage::MidWrite, |obs| {
            let mut f = OpenOptions::new().write(true).create_new(true).mode(0o600).open(&target).unwrap();
            f.write_all(&payload[..16]).unwrap();
            let _ = obs(Stage::MidWrite);
            f.write_all(&payload[16..]).unwrap();
        }));
        let held = fs::read(&target).unwrap();
        assert!(held.len() < payload.len() && held != payload, "a crash left {} of 32 bytes at the final name", held.len());
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_secret_never_exists_at_its_final_name_before_it_is_complete() {
        // Observe the directory from inside the publication: at every boundary before commit the
        // final name must be absent (create) or the old bytes (replace).
        let dir = scratch("secret-final-name");
        let target = dir.join("seed");
        let mut before_commit = Vec::new();
        create_new_with(&target, &[7u8; 32], Perm::Private, &mut |stage| {
            before_commit.push((stage, target.exists()));
            Ok(())
        })
        .unwrap();
        for (stage, exists) in &before_commit {
            let committed = matches!(stage, Stage::AfterCommit | Stage::AfterDirectorySync);
            assert_eq!(*exists, committed, "{stage:?}");
        }
        assert_eq!(before_commit.iter().map(|(s, _)| *s).collect::<Vec<_>>(), STAGES.to_vec(), "boundaries fire in order");
        use std::os::unix::fs::PermissionsExt;
        assert_eq!(fs::metadata(&target).unwrap().permissions().mode() & 0o777, 0o600);
        assert_eq!(leftovers(&dir), vec!["seed".to_owned()], "no staging file survives success");
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn failures_clean_up_their_staging_file_but_never_touch_the_existing_name() {
        let dir = scratch("exists");
        let target = dir.join("record");
        create_new(&target, b"first", Perm::Private).unwrap();
        let err = create_new(&target, b"second", Perm::Private).unwrap_err();
        assert_eq!(err.kind(), io::ErrorKind::AlreadyExists);
        assert_eq!(fs::read(&target).unwrap(), b"first");
        assert_eq!(leftovers(&dir), vec!["record".to_owned()]);
        assert!(matches!(retain_exact(&target, b"first", Perm::Private), Ok(Retained::Matched)));
        assert!(matches!(retain_exact(&target, b"other", Perm::Private), Err(RetainError::Differs)));
        assert!(matches!(retain_exact(&target, b"first plus", Perm::Private), Err(RetainError::Differs)));
        assert_eq!(fs::read(&target).unwrap(), b"first");
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_symlinked_final_name_is_replaced_not_followed() {
        let dir = scratch("symlink");
        let victim = dir.join("victim");
        fs::write(&victim, b"keep").unwrap();
        let target = dir.join("record");
        std::os::unix::fs::symlink(&victim, &target).unwrap();
        replace(&target, b"new", Perm::Private).unwrap();
        assert_eq!(fs::read(&victim).unwrap(), b"keep", "the link target is untouched");
        assert_eq!(fs::read(&target).unwrap(), b"new");
        assert!(!fs::symlink_metadata(&target).unwrap().file_type().is_symlink());
        // create_new refuses a dangling or live symlink at the name.
        let other = dir.join("other");
        std::os::unix::fs::symlink(dir.join("nowhere"), &other).unwrap();
        assert_eq!(create_new(&other, b"x", Perm::Private).unwrap_err().kind(), io::ErrorKind::AlreadyExists);
        fs::remove_dir_all(dir).unwrap();
    }
}
