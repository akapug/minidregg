//! Join a mapped user namespace before parsing resident bytes. bubblewrap
//! creates it (the one sandboxing binary a host provides; on a host that confines
//! unprivileged namespace creation, its AppArmor-profiled copy is the permitted
//! creator); this process writes the two broker-selected identities into it from
//! outside and then joins it, staying the unit MainPID. Both resident and worker
//! later drop all capability sets.
use std::fs::{self, File, Metadata, OpenOptions};
use std::io::{self, Read, Write};
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::OnceLock;
use std::collections::BTreeMap;
static ROOTS: OnceLock<BTreeMap<PathBuf, (File, Metadata)>>=OnceLock::new();
fn refused(s: &str)->io::Error { io::Error::new(io::ErrorKind::PermissionDenied,s) }
/// Root in the initial namespace is unmapped inside the resident namespace.
/// Retained handles carry its verified provenance, never the overflow uid.
pub(crate) fn root_owned(path: &Path, observed: &Metadata) -> bool {
    if crate::os::root_owner(observed.uid()) { return true; }
    ROOTS.get().and_then(|roots|roots.get(path)).is_some_and(|(f, held)| {
        let Ok(current)=f.metadata() else { return false; };
        if (current.dev(),current.ino(),current.ctime(),current.ctime_nsec())!=(held.dev(),held.ino(),held.ctime(),held.ctime_nsec()) { return false; }
        (held.dev(),held.ino(),held.mode(),held.nlink(),held.len(),held.mtime(),held.mtime_nsec(),held.ctime(),held.ctime_nsec())
        ==(observed.dev(),observed.ino(),observed.mode(),observed.nlink(),observed.len(),observed.mtime(),observed.mtime_nsec(),observed.ctime(),observed.ctime_nsec())
    })
}
fn remember(path: &Path, roots: &mut BTreeMap<PathBuf,(File,Metadata)>) -> io::Result<()> {
    let m=fs::symlink_metadata(path)?;
    if m.file_type().is_symlink() || m.mode()&0o022!=0 { return Err(refused("namespace bootstrap custody path writable or symlinked")); }
    if m.uid()==0 {
        let f=OpenOptions::new().read(true).custom_flags(libc::O_NOFOLLOW|libc::O_CLOEXEC|libc::O_PATH).open(path)?;
        let held=f.metadata()?;
        if held.uid()!=0 || (held.dev(),held.ino())!=(m.dev(),m.ino()) { return Err(refused("namespace bootstrap root handle changed")); }
        roots.insert(path.to_owned(),(f,held));
    } else if m.uid()!=unsafe{libc::geteuid()} { return Err(refused("namespace bootstrap custody path belongs to another principal")); }
    Ok(())
}
pub(crate) fn prepare_root_handles(config: &Path, root: &Path, store: &str, grain: &str) -> io::Result<()> {
    let mut roots=BTreeMap::new();
    for path in config.ancestors().skip(1) { remember(path,&mut roots)?; }
    let witness=root.join("attest").join(format!("{store}-{grain}.witness"));
    for path in witness.ancestors() { remember(path,&mut roots)?; }
    ROOTS.set(roots).map_err(|_|refused("namespace root provenance initialized twice"))
}
/// The physical bubblewrap binaries a host may provide (deploy/grain-host/resolve-bwrap):
/// the AppArmor-profiled copy a host restricting unprivileged user namespaces ships, and
/// the distro binary. The namespace and the app sandbox are made by the same binary.
pub(crate) const PHYSICAL_BWRAPS: [&str; 2] = ["/usr/local/libexec/mini-grain-bwrap", "/usr/bin/bwrap"];
/// A deployed physical bwrap: one of PHYSICAL_BWRAPS, a root-owned non-writable
/// executable regular file whose bytes have the pinned SHA-256.
pub(crate) fn pinned_bwrap(path: &Path, sha256: &str) -> io::Result<()> {
    use sha2::{Digest, Sha256};
    if !PHYSICAL_BWRAPS.iter().any(|b| Path::new(b) == path) {
        return Err(refused("namespace bwrap is not a deployed physical bwrap"));
    }
    let m = fs::symlink_metadata(path)?;
    if !m.file_type().is_file() || m.uid() != 0 || m.mode() & 0o022 != 0 || m.mode() & 0o111 == 0 {
        return Err(refused("namespace bwrap must be a root-owned non-writable executable"));
    }
    let mut f = OpenOptions::new().read(true).custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC).open(path)?;
    let held = f.metadata()?;
    if (held.dev(), held.ino()) != (m.dev(), m.ino()) {
        return Err(refused("namespace bwrap changed while pinned"));
    }
    let mut bytes = Vec::new();
    f.read_to_end(&mut bytes)?;
    if sha256.len() != 64 || format!("{:x}", Sha256::digest(&bytes)) != sha256 {
        return Err(refused("namespace bwrap SHA-256 differs from its pin"));
    }
    Ok(())
}
/// Name the step and the path an OS error came from: a bare ENOENT from the
/// namespace bootstrap says nothing about which helper or file is missing.
fn at(step: &str, path: &str) -> impl FnOnce(io::Error) -> io::Error {
    let (step, path) = (step.to_owned(), path.to_owned());
    move |error| io::Error::new(error.kind(), format!("namespace bootstrap {step} ({path}): {error}"))
}
fn map(program: &str, pid: u32, operator: u32, app: u32) -> io::Result<()> {
    eprintln!("namespace-map helper={program} pid={pid} operator={operator} app={app}");
    let status = Command::new(program)
        .args([pid.to_string(), operator.to_string(), operator.to_string(), "1".into(), app.to_string(), app.to_string(), "1".into()])
        .env_clear()
        .status()
        .map_err(at("mapping helper", program))?;
    if !status.success() {
        return Err(refused("namespace identity mapping refused"));
    }
    Ok(())
}
fn pipe() -> io::Result<(OwnedFd, OwnedFd)> {
    let mut fds = [0; 2];
    if unsafe { libc::pipe2(fds.as_mut_ptr(), libc::O_CLOEXEC) } != 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(unsafe { (OwnedFd::from_raw_fd(fds[0]), OwnedFd::from_raw_fd(fds[1])) })
}
/// `Threads:` of /proc/self/status: the size of this thread group.
fn thread_count() -> io::Result<u32> {
    let status = fs::read_to_string("/proc/self/status").map_err(at("thread census", "/proc/self/status"))?;
    status
        .lines()
        .find_map(|line| line.strip_prefix("Threads:"))
        .and_then(|rest| rest.trim().parse().ok())
        .ok_or_else(|| refused("thread census refused: /proc/self/status names no Threads"))
}
fn exact_map(text: &str, op: u32, app: u32) -> bool {
    let rows: Vec<Vec<u32>> = text.lines().map(|r| r.split_whitespace().filter_map(|n| n.parse().ok()).collect()).collect();
    rows.len() == 2 && rows.contains(&vec![op, op, 1]) && rows.contains(&vec![app, app, 1])
}
/// `bwrap --unshare-user --userns-block-fd 4 --info-fd 3` creates the namespace and,
/// given the block fd, writes no uid/gid map itself: it reports its namespaced child and
/// waits. newuidmap/newgidmap then map exactly {operator, app} into it (the operator's
/// /etc/subuid grant covers the app identity), this process holds the namespace by fd,
/// releases bwrap (whose child runs /usr/bin/true and exits), and joins by setns. The
/// joining process must be single-threaded: the kernel refuses setns(CLONE_NEWUSER)
/// from a thread group of more than one (kernel/user_namespace.c `userns_install`,
/// EINVAL), so this is checked by name before any host program is touched. The
/// production entry (`spk-host resident-bootstrap`, a fresh exec) spawns no thread
/// before it; a test harness thread is the known way to break it. The joined process
/// keeps every capability of the namespace, none of the host, until the bootstrap
/// drops them.
pub(crate) fn enter(bwrap: &Path, bwrap_sha256: &str, operator_uid: u32, operator_gid: u32, app_uid: u32, app_gid: u32) -> io::Result<()> {
    if unsafe { libc::geteuid() } == 0 || unsafe { libc::geteuid() } != operator_uid || unsafe { libc::getegid() } != operator_gid {
        return Err(refused("resident requires its unprivileged operator uid"));
    }
    let threads = thread_count()?;
    if threads != 1 {
        return Err(io::Error::other(format!(
            "namespace entry requires a single-threaded process: this thread group has {threads} threads, and the kernel refuses setns(CLONE_NEWUSER) from more than one (EINVAL); enter before any thread starts"
        )));
    }
    pinned_bwrap(bwrap, bwrap_sha256)?;
    let (info_r, info_w) = pipe()?;
    let (block_r, block_w) = pipe()?;
    let (iw, br) = (info_w.as_raw_fd(), block_r.as_raw_fd());
    let mut command = Command::new(bwrap);
    command
        .env_clear()
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .args(["--unshare-user", "--die-with-parent", "--info-fd", "3", "--userns-block-fd", "4", "--ro-bind", "/", "/", "--", "/usr/bin/true"]);
    unsafe {
        command.pre_exec(move || {
            // Move both ends above 9 first so neither dup2 can land on the other.
            let i = libc::fcntl(iw, libc::F_DUPFD_CLOEXEC, 10);
            let b = libc::fcntl(br, libc::F_DUPFD_CLOEXEC, 10);
            if i < 0 || b < 0 || libc::dup2(i, 3) != 3 || libc::dup2(b, 4) != 4 {
                return Err(io::Error::last_os_error());
            }
            Ok(())
        });
    }
    let bwrap_text = bwrap.display().to_string();
    let mut holder = command.spawn().map_err(at("bwrap spawn", &bwrap_text))?;
    drop(info_w);
    drop(block_r);
    let result = (|| -> io::Result<()> {
        let mut info = Vec::new();
        File::from(info_r).take(4096).read_to_end(&mut info)?;
        let info: serde_json::Value = serde_json::from_slice(&info).map_err(|_| refused("namespace bwrap info refused"))?;
        let pid = info
            .get("child-pid")
            .and_then(serde_json::Value::as_u64)
            .and_then(|p| u32::try_from(p).ok())
            .filter(|p| *p > 1)
            .ok_or_else(|| refused("namespace bwrap child absent"))?;
        let status_path = format!("/proc/{pid}/status");
        let status = fs::read_to_string(&status_path).map_err(at("bwrap child status", &status_path))?;
        if !status.lines().any(|l| l.split_whitespace().collect::<Vec<_>>() == ["PPid:", &holder.id().to_string()]) {
            return Err(refused("namespace holder is not the bwrap child"));
        }
        let ns_path = format!("/proc/{pid}/ns/user");
        let ns = File::open(&ns_path).map_err(at("bwrap child namespace", &ns_path))?;
        if ns.metadata()?.ino() == fs::metadata("/proc/self/ns/user")?.ino() {
            return Err(refused("namespace bwrap did not create a user namespace"));
        }
        map("/usr/bin/newuidmap", pid, operator_uid, app_uid)?;
        map("/usr/bin/newgidmap", pid, operator_gid, app_gid)?;
        File::from(block_w).write_all(&[1])?;
        if !holder.wait()?.success() {
            return Err(refused("namespace bwrap failed"));
        }
        if unsafe { libc::setns(ns.as_raw_fd(), libc::CLONE_NEWUSER) } != 0 {
            return Err(io::Error::other(format!("namespace setns(CLONE_NEWUSER) refused: {}", io::Error::last_os_error())));
        }
        // newgidmap's privileged write preserves setgroups=allow; Linux refuses
        // setgroups until a gid_map exists. Clear groups immediately afterwards.
        if unsafe { libc::setgroups(0, std::ptr::null()) } != 0 {
            return Err(io::Error::other(format!("namespace empty groups refused after gid mapping: {}", io::Error::last_os_error())));
        }
        let uid = fs::read_to_string("/proc/self/uid_map")?;
        let gid = fs::read_to_string("/proc/self/gid_map")?;
        if !exact_map(&uid, operator_uid, app_uid) || !exact_map(&gid, operator_gid, app_gid) {
            return Err(refused("namespace identity maps differ from broker selection"));
        }
        Ok(())
    })();
    if result.is_err() {
        let _ = holder.kill();
        let _ = holder.wait();
    }
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The libtest harness runs every test on a spawned thread, so this process
    /// has at least two. `enter` must refuse by name here, before it looks for
    /// bwrap or the mapping helpers: the kernel's own answer is a bare EINVAL.
    #[test]
    fn enter_refuses_a_multithreaded_process_by_name_before_any_host_program() {
        let (uid, gid) = unsafe { (libc::geteuid(), libc::getegid()) };
        if uid == 0 {
            return; // the identity check fires first as root; the rule under test needs the operator
        }
        assert!(thread_count().unwrap() >= 2, "libtest runs tests on their own thread");
        let error = enter(Path::new("/nonexistent/bwrap"), "", uid, gid, uid + 1, gid + 1).unwrap_err();
        let text = error.to_string();
        assert!(text.contains("single-threaded process"), "{text}");
        // Not the exact count: under a parallel `cargo test`, sibling test threads
        // come and go between two censuses. nextest runs one test per process.
        assert!(text.contains("threads, and the kernel refuses setns(CLONE_NEWUSER)"), "{text}");
        assert!(!text.contains("nonexistent"), "bwrap was consulted before the thread rule: {text}");
    }

    /// A forked child carries only the forking thread: the shape of the production
    /// entry, and of the sandbox-floor audit's child.
    #[test]
    fn a_forked_child_is_single_threaded() {
        let pid = unsafe { libc::fork() };
        assert!(pid >= 0);
        if pid == 0 {
            let ok = thread_count().map(|n| n == 1).unwrap_or(false);
            unsafe { libc::_exit(if ok { 0 } else { 1 }) }
        }
        let mut status = 0;
        assert_eq!(unsafe { libc::waitpid(pid, &mut status, 0) }, pid);
        assert!(libc::WIFEXITED(status) && libc::WEXITSTATUS(status) == 0, "status {status:#x}");
    }
}
