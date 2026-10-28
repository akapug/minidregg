//! Join a mapped user namespace before parsing resident bytes. bubblewrap
//! creates it (the one sandboxing binary a host provides; on a host that confines
//! unprivileged namespace creation, its AppArmor-profiled copy is the permitted
//! creator); this process writes the two broker-selected identities into it from
//! outside and then joins it, staying the unit MainPID. Both resident and worker
//! later drop all capability sets.
use crate::io_context::IoContext;
use std::fs::{self, File, Metadata, OpenOptions};
use std::io::{self, Read, Write};
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::OnceLock;
use std::collections::BTreeMap;
// Bootstrap deliberately inspects only the fixed world SPK namespace. No archive
// or resident JSON is parsed before isolation. Finalized packages contribute their
// retained metadata, not every executable-image file; public revisions contribute
// their complete bounded metadata tree. Kernel FD limits can impose a lower bound.
const MAX_CUSTODY_HANDLES: usize = 131_072;
const MAX_CUSTODY_PATH_BYTES: usize = 32 * 1024 * 1024;
const MAX_CUSTODY_DEPTH: usize = 32;
struct Pin { file: File, original: Metadata }
struct Provenance {
    paths: BTreeMap<PathBuf, std::sync::Arc<Pin>>,
    inodes: BTreeMap<(u64,u64), std::sync::Arc<Pin>>,
    path_bytes: usize,
}
impl Provenance {
    fn new() -> Self { Self { paths:BTreeMap::new(), inodes:BTreeMap::new(), path_bytes:0 } }
}
static ROOTS: OnceLock<Provenance> = OnceLock::new();
fn refused(s: &str)->io::Error { io::Error::new(io::ErrorKind::PermissionDenied,s) }
fn stable(meta: &Metadata) -> (u64,u64,u32,u64,u64,i64,i64,i64,i64) {
    (meta.dev(),meta.ino(),meta.mode(),meta.nlink(),meta.len(),meta.mtime(),meta.mtime_nsec(),meta.ctime(),meta.ctime_nsec())
}
/// What a pinned inode must keep for its provenance to hold. A file keeps its whole stable
/// state. A directory keeps its identity, type and permission bits, but not its timestamps,
/// link count or size: those move whenever an entry is added or removed. Shared root-owned
/// ancestors such as `/var/lib/mini-spk-worlds` gain an entry every time another world is
/// registered, and that changes nothing about who may write the directory. (dregg-build,
/// 2026-10-27: a resident pinned that directory at 19:41:29, another world was registered
/// beneath it at 19:41:40, and the resident refused its own journal at 19:42:47.)
fn provenance_key(meta: &Metadata) -> (u64,u64,u32,u64,u64,i64,i64,i64,i64) {
    if meta.is_dir() { (meta.dev(),meta.ino(),meta.mode(),0,0,0,0,0,0) } else { stable(meta) }
}
/// The id a filesystem owner `original` (an id of the namespace the process started in)
/// reports as inside the namespace described by `map_text` (`/proc/self/{u,g}id_map`:
/// `inside outside count` rows): its mapped inside id, or `overflow` when unmapped.
/// `None` when the map is malformed, which callers treat as "not unchanged".
fn visible_id(map_text: &str, original: u32, overflow: u32) -> Option<u32> {
    let mut seen = None;
    for row in map_text.lines().filter(|r| !r.trim().is_empty()) {
        let f: Vec<u64> = row.split_whitespace().map(str::parse::<u64>).collect::<Result<_,_>>().ok()?;
        let [inside, outside, count] = f[..] else { return None; };
        if count == 0 || inside + count > 1 << 32 || outside + count > 1 << 32 { return None; }
        let o = u64::from(original);
        if o >= outside && o < outside + count && seen.is_none() { seen = Some((inside + (o - outside)) as u32); }
    }
    Some(seen.unwrap_or(overflow))
}
/// The running process's namespace view of ids. Read afresh per check rather than cached:
/// the maps are tiny and a cache could outlive a (refused) namespace change.
struct IdView { uid_map: String, gid_map: String, overflow_uid: u32, overflow_gid: u32 }
impl IdView {
    fn current() -> Option<Self> {
        let n = |p: &str| fs::read_to_string(p).ok().and_then(|t| t.trim().parse().ok()).unwrap_or(65534);
        Some(Self { uid_map: fs::read_to_string("/proc/self/uid_map").ok()?, gid_map: fs::read_to_string("/proc/self/gid_map").ok()?,
            overflow_uid: n("/proc/sys/fs/overflowuid"), overflow_gid: n("/proc/sys/fs/overflowgid") })
    }
}
/// Two recorded limits. Inside the namespace every unmapped owner reads as the overflow id, so a
/// root-owned pin re-owned to a different UNMAPPED uid still reads as unchanged here; the provenance
/// key (dev, ino, mode, and for files the whole stable state) and the mode check still catch a
/// replaced inode or a widened mode. A mapped non-overflow id is refused (a chown seen from inside).
/// `current` and `observed` are in-namespace views and must agree; the pin's `original`
/// owner (taken before entry) must translate to exactly that view.
fn owners_agree(original: (u32,u32), current: (u32,u32), observed: (u32,u32), view: &IdView) -> bool {
    current == observed
        && visible_id(&view.uid_map, original.0, view.overflow_uid) == Some(current.0)
        && visible_id(&view.gid_map, original.1, view.overflow_gid) == Some(current.1)
}
fn unchanged_in(pin: &Pin, observed: &Metadata, view: &IdView) -> bool {
    let Ok(current) = pin.file.metadata() else { return false; };
    provenance_key(&current) == provenance_key(&pin.original) && provenance_key(observed) == provenance_key(&pin.original)
        && owners_agree((pin.original.uid(),pin.original.gid()), (current.uid(),current.gid()), (observed.uid(),observed.gid()), view)
}
fn unchanged(pin: &Pin, observed: &Metadata) -> bool {
    IdView::current().is_some_and(|view| unchanged_in(pin, observed, &view))
}
/// Exact pre-namespace owner/group, only for the same unchanged held inode.
/// Once bootstrap has captured custody, an unknown inode is never blessed by
/// its namespace-visible UID (including the ambiguous overflow UID/GID).
pub(crate) fn original_owner(observed: &Metadata) -> Option<(u32,u32)> {
    match ROOTS.get() {
        Some(roots) => roots.inodes.get(&(observed.dev(),observed.ino()))
            .filter(|pin| unchanged(pin,observed)).map(|pin|(pin.original.uid(),pin.original.gid())),
        None if observed.uid()==0 || observed.uid()==unsafe{libc::geteuid()} => Some((observed.uid(),observed.gid())),
        None => None,
    }
}
/// Root in the initial namespace is unmapped inside the resident namespace.
/// Retained handles carry its verified provenance, never the overflow UID.
pub(crate) fn root_owned(path: &Path, observed: &Metadata) -> bool {
    if ROOTS.get().is_none() && crate::os::root_owner(observed.uid()) { return true; }
    ROOTS.get().and_then(|roots|roots.paths.get(path)).is_some_and(|pin| {
        pin.original.uid()==0 && unchanged(pin,observed)
    })
}
fn host_trusted(meta: &Metadata) -> bool {
    !meta.file_type().is_symlink() && meta.mode()&0o022==0
        && (meta.uid()==0 || meta.uid()==unsafe{libc::geteuid()})
}
fn protected_handle(path: &Path) -> io::Result<File> {
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;
    use std::path::Component;
    if !path.is_absolute() { return Err(refused("bootstrap custody path must be absolute")); }
    let mut current=OpenOptions::new().read(true).custom_flags(libc::O_PATH|libc::O_DIRECTORY|libc::O_CLOEXEC).open("/").ctx("open", &"/")?;
    let components:Vec<_>=path.components().skip(1).collect();
    for (index,component) in components.iter().enumerate() {
        if !host_trusted(&current.metadata()?) { return Err(refused("bootstrap custody ancestor belongs to another principal or is writable")); }
        let Component::Normal(name)=component else { return Err(refused("bootstrap custody path not normalized")); };
        let name=CString::new(name.as_bytes()).map_err(|_|refused("bootstrap custody path contains NUL"))?;
        let flags=libc::O_PATH|libc::O_NOFOLLOW|libc::O_CLOEXEC|if index+1<components.len(){libc::O_DIRECTORY}else{0};
        let fd=unsafe{libc::openat(current.as_raw_fd(),name.as_ptr(),flags)};
        if fd<0 { return Err(io::Error::last_os_error()); }
        current=unsafe{File::from_raw_fd(fd)};
    }
    let meta=current.metadata()?;
    if !host_trusted(&meta) || (!meta.is_dir() && !meta.is_file()) {
        return Err(refused("bootstrap custody entry belongs to another principal, is writable, or is not regular"));
    }
    Ok(current)
}
fn remember(path: &Path, roots: &mut Provenance) -> io::Result<()> {
    if roots.paths.contains_key(path) { return Ok(()); }
    let count=roots.paths.len();
    let bytes=path.as_os_str().len();
    if count>=MAX_CUSTODY_HANDLES || bytes>MAX_CUSTODY_PATH_BYTES.saturating_sub(roots.path_bytes) {
        return Err(refused("bootstrap custody handle/path bound exceeded"));
    }
    let file=protected_handle(path)?;
    let original=file.metadata()?;
    let pin=std::sync::Arc::new(Pin {file,original});
    if let Some(previous)=roots.inodes.get(&(pin.original.dev(),pin.original.ino())) {
        if !unchanged(previous,&pin.original) { return Err(refused("bootstrap custody inode changed")); }
    }
    roots.inodes.insert((pin.original.dev(),pin.original.ino()),pin.clone());
    roots.paths.insert(path.to_owned(),pin);
    roots.path_bytes+=bytes;
    Ok(())
}
fn finalized_name(name: &str) -> bool {
    name.strip_prefix("sha256-").is_some_and(|hash| crate::canonical::hex64(&hash))
}
fn public_tree(path: &Path, roots: &mut Provenance, depth: usize) -> io::Result<()> {
    if depth>MAX_CUSTODY_DEPTH { return Err(refused("bootstrap public-data tree depth exceeded")); }
    remember(path,roots)?;
    if roots.paths[path].original.is_dir() {
        for entry in fs::read_dir(&path).ctx("list", &path)? {
            public_tree(&entry?.path(),roots,depth+1)?;
        }
    }
    Ok(())
}
fn remember_spk_namespace(world: &Path, roots: &mut Provenance) -> io::Result<()> {
    let namespace=world.join("spk");
    match fs::symlink_metadata(&namespace) {
        Err(error) if error.kind()==io::ErrorKind::NotFound => return Ok(()),
        result => { result?; }
    }
    for ancestor in namespace.ancestors() { remember(ancestor,roots)?; }
    for kind in ["packages","public-data"] {
        let store=namespace.join(kind);
        match fs::symlink_metadata(&store) {
            Err(error) if error.kind()==io::ErrorKind::NotFound => continue,
            result => { result?; }
        }
        remember(&store,roots)?;
        let mut seen=0;
        for entry in fs::read_dir(&store).ctx("list", &store)? {
            seen+=1;
            if seen>MAX_CUSTODY_HANDLES { return Err(refused("bootstrap publication listing bound exceeded")); }
            let entry=entry?;
            if !entry.file_name().to_str().is_some_and(finalized_name) { continue; }
            let publication=entry.path();
            if kind=="public-data" { public_tree(&publication,roots,0)?; }
            else {
                remember(&publication,roots)?;
                for name in ["package.spk","manifest.json","import-policy.json","root"] {
                    let path=publication.join(name);
                    match fs::symlink_metadata(&path) {
                        Err(error) if error.kind()==io::ErrorKind::NotFound => continue,
                        result => { result?; }
                    }
                    remember(&path,roots)?;
                }
            }
        }
    }
    Ok(())
}
pub(crate) fn prepare_root_handles(config: &Path, root: &Path, store: &str, grain: &str) -> io::Result<()> {
    let mut roots=Provenance::new();
    for path in config.ancestors().skip(1) { remember(path,&mut roots)?; }
    let witness=root.join("attest").join(format!("{store}-{grain}.witness"));
    for path in witness.ancestors() { remember(path,&mut roots)?; }
    remember_spk_namespace(root,&mut roots)?;
    let controller=root.join("controller");
    match fs::symlink_metadata(&controller) {
        Err(e) if e.kind()==io::ErrorKind::NotFound => {},
        result => { result?; remember(&controller,&mut roots)?; }
    }
    ROOTS.set(roots).map_err(|_|refused("namespace root provenance initialized twice"))
}
/// Root setup may register one already-delegated controller. This protects the
/// operator from the controller, not controller keys from their trusted operator.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct ControllerIdentity { uid: u32, gid: u32 }
#[derive(serde::Deserialize)]
#[serde(rename_all="camelCase", deny_unknown_fields)]
struct ControllerReceipt {
    protocol: String, store: String, deployment_id: String, host_id: String,
    operator_uid: u32, operator_gid: u32, controller_uid: u32, controller_gid: u32,
    account: String,
}
static CONTROLLER: OnceLock<Option<ControllerIdentity>> = OnceLock::new();
fn receipt_identity(r: &ControllerReceipt, registry: &crate::volume_helper::Registry) -> io::Result<ControllerIdentity> {
    let valid = |id: u32| id>=65536 && id<u32::MAX;
    if r.protocol!="mini-spk-controller-namespace-v1" || r.store!=registry.store
        || r.deployment_id!=registry.deployment_id || r.host_id!=registry.host_id
        || r.operator_uid!=registry.operator_uid || r.operator_gid!=registry.operator_gid
        || r.account!=format!("mini-c-{}",registry.store)
        || !valid(r.controller_uid) || !valid(r.controller_gid)
        || r.controller_uid==registry.operator_uid || r.controller_gid==registry.operator_gid
        || registry.app_uids.contains(&r.controller_uid) || registry.app_uids.contains(&r.controller_gid)
    { return Err(refused("registered controller namespace identity differs from world")); }
    Ok(ControllerIdentity {uid:r.controller_uid,gid:r.controller_gid})
}
fn account_matches(name: &str, home: &Path, identity: ControllerIdentity) -> io::Result<()> {
    use std::ffi::{CString,CStr};
    let name=CString::new(name).map_err(|_|refused("controller account name"))?;
    let mut bytes=vec![0 as libc::c_char;16384];
    let mut entry:libc::passwd=unsafe{std::mem::zeroed()};
    let mut result=std::ptr::null_mut();
    let code=unsafe{libc::getpwnam_r(name.as_ptr(),&mut entry,bytes.as_mut_ptr(),bytes.len(),&mut result)};
    if code!=0 || result.is_null() || entry.pw_dir.is_null() || entry.pw_shell.is_null()
        || entry.pw_uid!=identity.uid || entry.pw_gid!=identity.gid
        || unsafe{CStr::from_ptr(entry.pw_dir)}.to_bytes()!=home.as_os_str().as_encoded_bytes()
        || unsafe{CStr::from_ptr(entry.pw_shell)}.to_bytes()!=b"/usr/sbin/nologin"
    { return Err(refused("registered controller passwd identity differs")); }
    let mut group:libc::group=unsafe{std::mem::zeroed()};
    let mut result=std::ptr::null_mut();
    let code=unsafe{libc::getgrnam_r(name.as_ptr(),&mut group,bytes.as_mut_ptr(),bytes.len(),&mut result)};
    if code!=0 || result.is_null() || group.gr_gid!=identity.gid
        || (!group.gr_mem.is_null() && !unsafe{*group.gr_mem}.is_null())
    { return Err(refused("registered controller private group differs")); }
    Ok(())
}
pub(crate) fn load_registered_controller(registry: &crate::volume_helper::Registry) -> io::Result<Option<ControllerIdentity>> {
    let directory=registry.grains_root.join("controller");
    match fs::symlink_metadata(&directory) {
        Err(e) if e.kind()==io::ErrorKind::NotFound => return Ok(None),
        result => { result?; }
    }
    let path=directory.join("namespace.json");
    minidregg_compatible_upgrade_custody::root_ancestors(&path)?;
    let mut file=OpenOptions::new().read(true).custom_flags(libc::O_NOFOLLOW|libc::O_CLOEXEC|libc::O_NONBLOCK).open(&path).ctx("open", &path)?;
    let before=file.metadata()?;
    if !before.is_file() || before.uid()!=0 || before.nlink()!=1 || before.mode()&0o7777!=0o644
        || before.len()==0 || before.len()>4096 {
        return Err(refused("registered controller namespace receipt custody refused"));
    }
    let mut bytes=Vec::new();
    Read::by_ref(&mut file).take(4097).read_to_end(&mut bytes)?;
    let after=file.metadata()?;
    let named=fs::symlink_metadata(&path).ctx("inspect", &path)?;
    if bytes.len() as u64!=before.len() || stable(&before)!=stable(&after)
        || stable(&before)!=stable(&named) || (before.dev(),before.ino(),before.uid(),before.gid())!=(named.dev(),named.ino(),named.uid(),named.gid()) {
        return Err(refused("registered controller receipt changed while read"));
    }
    let receipt:ControllerReceipt=serde_json::from_slice(&bytes)?;
    let identity=receipt_identity(&receipt,registry)?;
    account_matches(&receipt.account,&directory.join("home"),identity)?;
    Ok(Some(identity))
}
pub(crate) fn require_registered_controller(uid:u32) -> io::Result<()> {
    if CONTROLLER.get().and_then(|v|*v).is_some_and(|c|c.uid==uid) { Ok(()) }
    else { Err(refused("agent controller UID is not the root-registered mapped identity")) }
}

/// The physical bubblewrap binaries a host may provide (deploy/grain-host/resolve-bwrap):
/// the AppArmor-profiled copy a host restricting unprivileged user namespaces ships, and
/// the distro binary. The namespace and the app sandbox are made by the same binary.
pub(crate) const PHYSICAL_BWRAPS: [&str; 2] = ["/usr/local/libexec/mini-grain-bwrap", "/usr/bin/bwrap"];
/// A deployed physical bwrap: one of PHYSICAL_BWRAPS, a root-owned non-writable
/// executable regular file whose bytes have the pinned SHA-256.
/// The returned executable is the descriptor whose bytes were hashed; `enter`
/// runs it by that descriptor (`/proc/self/fd/N`), so no path is resolved again
/// between the pin and the exec (RUST-TRIAGE R7). The hashing and caching are
/// `dispatch_native::verified_image`, the same custody the Host helper runs under.
pub(crate) fn pinned_bwrap(path: &Path, sha256: &str) -> io::Result<crate::dispatch_native::VerifiedExecutable> {
    if !PHYSICAL_BWRAPS.iter().any(|b| Path::new(b) == path) {
        return Err(refused("namespace bwrap is not a deployed physical bwrap"));
    }
    let m = fs::symlink_metadata(&path).ctx("inspect", &path)?;
    if !m.file_type().is_file() || m.uid() != 0 || m.mode() & 0o022 != 0 || m.mode() & 0o111 == 0 {
        return Err(refused("namespace bwrap must be a root-owned non-writable executable"));
    }
    if sha256.len() != 64 {
        return Err(refused("namespace bwrap SHA-256 pin malformed"));
    }
    crate::dispatch_native::verified_image(path, sha256)
        .map_err(|error| io::Error::new(error.kind(), format!("namespace bwrap pin ({}): {error}", path.display())))
}
/// Name the step and the path an OS error came from: a bare ENOENT from the
/// namespace bootstrap says nothing about which helper or file is missing.
fn at(step: &str, path: &str) -> impl FnOnce(io::Error) -> io::Error {
    let (step, path) = (step.to_owned(), path.to_owned());
    move |error| io::Error::new(error.kind(), format!("namespace bootstrap {step} ({path}): {error}"))
}
fn map(program: &str, pid: u32, operator: u32, app: u32, controller: Option<u32>) -> io::Result<()> {
    eprintln!("namespace-map helper={program} pid={pid} operator={operator} app={app}");
    let mut args=vec![pid.to_string(), operator.to_string(), operator.to_string(), "1".into(), app.to_string(), app.to_string(), "1".into()];
    if let Some(id)=controller { args.extend([id.to_string(),id.to_string(),"1".into()]); }
    let status = Command::new(program)
        .args(args)
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
fn exact_map(text: &str, op: u32, app: u32, controller:Option<u32>) -> bool {
    let rows:Result<Vec<Vec<u32>>,_>=text.lines().map(|r|r.split_whitespace().map(str::parse::<u32>).collect()).collect();
    let Ok(mut rows)=rows else{return false};
    let mut expected=vec![vec![op,op,1],vec![app,app,1]];
    if let Some(id)=controller {expected.push(vec![id,id,1]);}
    rows.sort();expected.sort();rows==expected
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
    enter_registered(bwrap,bwrap_sha256,operator_uid,operator_gid,app_uid,app_gid,None)
}
pub(crate) fn enter_registered(bwrap: &Path, bwrap_sha256: &str, operator_uid: u32, operator_gid: u32,
    app_uid: u32, app_gid: u32, controller:Option<&ControllerIdentity>) -> io::Result<()> {
    if controller.is_some_and(|c| c.uid==operator_uid || c.uid==app_uid || c.gid==operator_gid || c.gid==app_gid) {
        return Err(refused("registered controller overlaps operator or app"));
    }
    if unsafe { libc::geteuid() } == 0 || unsafe { libc::geteuid() } != operator_uid || unsafe { libc::getegid() } != operator_gid {
        return Err(refused("resident requires its unprivileged operator uid"));
    }
    let threads = thread_count()?;
    if threads != 1 {
        return Err(io::Error::other(format!(
            "namespace entry requires a single-threaded process: this thread group has {threads} threads, and the kernel refuses setns(CLONE_NEWUSER) from more than one (EINVAL); enter before any thread starts"
        )));
    }
    let executable = pinned_bwrap(bwrap, bwrap_sha256)?;
    // The hashed descriptor is what runs: the kernel opens `/proc/self/fd/N`
    // for exec before it closes close-on-exec descriptors. The holder's
    // pre_exec below places the info and block pipes at 3 and 4, so the image
    // is executed through a duplicate above 9: in a process with few open files
    // the verified descriptor itself can be 3 or 4, and exec would then name
    // the pipe (EACCES; found by the tenancy bootstrap test).
    let image = crate::sandbox::inherited_fd(executable.as_raw_fd())?;
    let (info_r, info_w) = pipe()?;
    let (block_r, block_w) = pipe()?;
    let (iw, br) = (info_w.as_raw_fd(), block_r.as_raw_fd());
    let mut command = Command::new(format!("/proc/self/fd/{}", image.as_raw_fd()));
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
        if ns.metadata()?.ino() == fs::metadata("/proc/self/ns/user").ctx("inspect", &"/proc/self/ns/user")?.ino() {
            return Err(refused("namespace bwrap did not create a user namespace"));
        }
        map("/usr/bin/newuidmap", pid, operator_uid, app_uid,controller.map(|c|c.uid))?;
        map("/usr/bin/newgidmap", pid, operator_gid, app_gid,controller.map(|c|c.gid))?;
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
        let uid = fs::read_to_string("/proc/self/uid_map").ctx("read", &"/proc/self/uid_map")?;
        let gid = fs::read_to_string("/proc/self/gid_map").ctx("read", &"/proc/self/gid_map")?;
        if !exact_map(&uid, operator_uid, app_uid,controller.map(|c|c.uid)) || !exact_map(&gid, operator_gid, app_gid,controller.map(|c|c.gid)) {
            return Err(refused("namespace identity maps differ from broker selection"));
        }
        CONTROLLER.set(controller.copied()).map_err(|_|refused("controller mapping initialized twice"))?;
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

    #[test]
    fn pinned_directory_keeps_provenance_across_new_entries_but_not_mode_changes() {
        use std::os::unix::fs::PermissionsExt;
        let dir = std::env::temp_dir().join(format!("mini-pin-{}", std::process::id()));
        fs::create_dir(&dir).unwrap();
        fs::set_permissions(&dir, fs::Permissions::from_mode(0o755)).unwrap();
        let pin = Pin { file: File::open(&dir).unwrap(), original: fs::metadata(&dir).unwrap() };
        std::thread::sleep(std::time::Duration::from_millis(20));
        fs::create_dir(dir.join("another-world")).unwrap();
        assert!(unchanged(&pin, &fs::metadata(&dir).unwrap()), "a new entry is not a provenance change");
        fs::set_permissions(&dir, fs::Permissions::from_mode(0o775)).unwrap();
        assert!(!unchanged(&pin, &fs::metadata(&dir).unwrap()), "a group-writable mode is");
        let file = dir.join("pinned-file");
        fs::write(&file, b"one").unwrap();
        let file_pin = Pin { file: File::open(&file).unwrap(), original: fs::metadata(&file).unwrap() };
        fs::write(&file, b"two!").unwrap();
        assert!(!unchanged(&file_pin, &fs::metadata(&file).unwrap()), "a file keeps its whole state");
        fs::remove_dir_all(&dir).unwrap();
    }

    fn view(uid_map: &str) -> IdView { IdView { uid_map: uid_map.into(), gid_map: uid_map.into(), overflow_uid: 65534, overflow_gid: 65534 } }
    #[test]
    fn visible_id_translates_identity_shifted_unmapped_and_refuses_malformed() {
        assert_eq!(visible_id("         0          0 4294967295\n", 0, 65534), Some(0));
        assert_eq!(visible_id("         0          0 4294967295\n", 1000, 65534), Some(1000));
        assert_eq!(visible_id("0 100000 65536\n", 100005, 65534), Some(5));
        assert_eq!(visible_id("1000 1000 1\n100001 100001 1\n", 0, 65534), Some(65534));
        assert_eq!(visible_id("1000 1000 1\n100001 100001 1\n", 100001, 65534), Some(100001));
        assert_eq!(visible_id("1000 x 1\n", 1000, 65534), None);
        assert_eq!(visible_id("1000 1000\n", 1000, 65534), None);
        assert_eq!(visible_id("1000 1000 0\n", 1000, 65534), None);
    }
    #[test]
    fn root_owned_pin_is_unchanged_under_a_map_lacking_root_and_not_under_a_mapped_id() {
        let ns = view("1000 1000 1\n100001 100001 1\n");
        assert!(owners_agree((0,0), (65534,65534), (65534,65534), &ns), "unmapped root reads as overflow");
        assert!(!owners_agree((0,0), (1000,1000), (1000,1000), &ns), "a mapped non-overflow id is a chown");
        assert!(!owners_agree((0,0), (65534,65534), (0,0), &ns), "current and observed must agree");
        assert!(!owners_agree((0,0), (0,0), (0,0), &ns), "raw original is not visible inside");
        assert!(owners_agree((0,0), (0,0), (0,0), &view("0 0 4294967295\n")), "identity map: today's check");
    }
    #[test]
    fn unchanged_in_drives_a_real_pin_through_an_injected_map() {
        let dir = std::env::temp_dir().join(format!("mini-pin-map-{}", std::process::id()));
        fs::create_dir(&dir).unwrap();
        let pin = Pin { file: File::open(&dir).unwrap(), original: fs::metadata(&dir).unwrap() };
        let me = pin.original.uid();
        let ok = view(&format!("{me} {me} 1\n"));
        assert!(unchanged_in(&pin, &fs::metadata(&dir).unwrap(), &ok));
        let shifted = view(&format!("{} {me} 1\n", me + 7));
        assert!(!unchanged_in(&pin, &fs::metadata(&dir).unwrap(), &shifted), "stat still reports the raw id");
        fs::remove_dir_all(&dir).unwrap();
    }

    fn registry() -> crate::volume_helper::Registry {
        serde_json::from_value(serde_json::json!({
            "protocol":"mini-spk-volume-registry-v1","store":"ab".repeat(8),"deploymentId":"cd".repeat(32),
            "hostId":"ef".repeat(32),"grainsRoot":format!("/var/lib/mini-spk-worlds/{}","ab".repeat(8)),
            "operatorUid":1000,"operatorGid":1001,"appUids":[100000,100001],
            "helper":"/usr/local/libexec/mini-spk-volume-helper","helperSha256":"12".repeat(32)
        })).unwrap()
    }
    fn receipt() -> serde_json::Value {
        serde_json::json!({"protocol":"mini-spk-controller-namespace-v1","store":"ab".repeat(8),
            "deploymentId":"cd".repeat(32),"hostId":"ef".repeat(32),"operatorUid":1000,"operatorGid":1001,
            "controllerUid":100032,"controllerGid":100033,"account":format!("mini-c-{}","ab".repeat(8))})
    }
    #[test]
    fn controller_receipt_binds_world_operator_and_independent_ids() {
        let good:ControllerReceipt=serde_json::from_value(receipt()).unwrap();
        assert_eq!(receipt_identity(&good,&registry()).unwrap(),ControllerIdentity{uid:100032,gid:100033});
        for (field,value) in [("store",serde_json::json!("ff".repeat(8))),
            ("deploymentId",serde_json::json!("00".repeat(32))),("hostId",serde_json::json!("00".repeat(32))),
            ("operatorUid",serde_json::json!(1001)),("operatorGid",serde_json::json!(1000)),
            ("controllerUid",serde_json::json!(100000)),("controllerGid",serde_json::json!(100001)),
            ("controllerUid",serde_json::json!(65534)),("controllerGid",serde_json::json!(u32::MAX)),
            ("controllerUid",serde_json::json!(1000)),("account",serde_json::json!("another-controller"))] {
            let mut bad=receipt(); bad[field]=value;
            let parsed:ControllerReceipt=serde_json::from_value(bad).unwrap();
            assert!(receipt_identity(&parsed,&registry()).is_err(),"{field}");
        }
    }
    #[test]
    fn controller_receipt_is_strict_and_never_infers_optional_mapping() {
        let mut bad=receipt(); bad["extra"]=serde_json::json!(true);
        assert!(serde_json::from_value::<ControllerReceipt>(bad).is_err());
        let mut bad=receipt(); bad.as_object_mut().unwrap().remove("controllerGid");
        assert!(serde_json::from_value::<ControllerReceipt>(bad).is_err());
        let encoded=serde_json::to_string(&receipt()).unwrap();
        let duplicate=encoded.replacen('{',"{\"controllerUid\":100040,",1);
        assert!(serde_json::from_str::<ControllerReceipt>(&duplicate).is_err());
    }
    #[test]
    fn controller_mapping_accepts_only_exact_two_or_three_single_ids() {
        let two="1000 1000 1\n100000 100000 1\n";
        let three=format!("{two}100032 100032 1\n");
        assert!(exact_map(two,1000,100000,None));
        assert!(!exact_map(two,1000,100000,Some(100032)));
        assert!(exact_map(&three,1000,100000,Some(100032)));
        assert!(!exact_map(&three,1000,100000,None));
        assert!(!exact_map(&format!("{three}999 999 1\n"),1000,100000,Some(100032)));
        assert!(!exact_map("1000 1000 1 garbage\n100000 100000 1\n",1000,100000,None));
        assert!(!exact_map("1000 1000 1\n100000 100000 2\n",1000,100000,None));
        assert!(!exact_map(&three,1000,100000,Some(100033)));
    }

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

    /// The pinned bwrap is returned as the hashed descriptor, and a wrong pin
    /// is refused by name before anything runs. Needs the deployed bwrap.
    #[test]
    fn pinned_bwrap_yields_the_hashed_descriptor_and_refuses_a_wrong_pin() {
        use sha2::{Digest, Sha256};
        let bwrap = Path::new("/usr/bin/bwrap");
        let Ok(meta) = fs::symlink_metadata(bwrap) else { return };
        if meta.uid() != 0 || meta.mode() & 0o022 != 0 {
            return;
        }
        let bytes = fs::read(bwrap).unwrap();
        let pin = format!("{:x}", Sha256::digest(&bytes));
        let executable = pinned_bwrap(bwrap, &pin).unwrap();
        let path = executable.path();
        assert!(path.starts_with("/proc/self/fd"), "{}", path.display());
        assert_eq!(fs::read(&path).unwrap(), bytes, "the descriptor holds the hashed bytes");
        let wrong = pinned_bwrap(bwrap, &"0".repeat(64)).unwrap_err().to_string();
        assert!(wrong.starts_with("namespace bwrap pin (/usr/bin/bwrap): "), "{wrong}");
        assert!(wrong.contains("SHA-256 drift"), "{wrong}");
        let malformed = pinned_bwrap(bwrap, "abc").unwrap_err().to_string();
        assert_eq!(malformed, "namespace bwrap SHA-256 pin malformed");
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
