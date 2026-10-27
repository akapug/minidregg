//! HOT-PATH 2a across real processes: two `mini` processes under one `pure_host` binding (image
//! identity + settings bytes) share ONE resident codec Host, so the storeless codec image
//! (`HOST SETTINGS codec`) starts once for both; `MINI_CODEC_RESIDENT=0` restores the
//! per-process child. The resident ends when idle (`MINI_CODEC_IDLE_S`), taking its socket and
//! PID file with it. The Host image is a stand-in that counts its starts and answers every
//! frame `7 ‖ "ok"`.
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

fn framed(body: &[u8]) -> Vec<u8> {
    [(body.len() as u32).to_le_bytes().as_slice(), body].concat()
}

/// A stand-in `HOST SETTINGS codec` loop: a line in `<dir>/starts` per start, `<dir>/reply` per frame.
fn codec_stub(dir: &Path) -> PathBuf {
    use std::os::unix::fs::PermissionsExt;
    let path = dir.join("codec-host");
    fs::write(&path, format!("#!/bin/sh\necho start >> '{d}/starts'\nwhile :; do\n  n=$(dd bs=1 count=4 2>/dev/null | od -An -tu4 | tr -d ' \\n')\n  [ -n \"$n\" ] || exit 0\n  dd bs=1 count=\"$n\" of=/dev/null 2>/dev/null\n  cat '{d}/reply'\ndone\n", d = dir.display())).unwrap();
    fs::set_permissions(&path, fs::Permissions::from_mode(0o700)).unwrap();
    path
}

fn starts(dir: &Path) -> usize {
    fs::read_to_string(dir.join("starts")).unwrap_or_default().lines().count()
}

/// `mini author` of `<dir>/input` into `<dir>/<output>`, its semantic Host the stub, its anchors
/// (and so the resident's socket) under `<dir>/anchors`, the resident on or off.
fn mini(dir: &Path, output: &str, resident: bool) -> std::process::Output {
    let host = dir.join("codec-host");
    let settings = dir.join("settings.json");
    Command::new(env!("CARGO_BIN_EXE_mini"))
        .arg("author").arg("--host").arg(&host).arg("--config").arg(&settings)
        .arg("--kind").arg("plan").arg("--input").arg(dir.join("input")).arg("--output").arg(dir.join(output))
        .env("HOME", dir)
        .env("MINI_CONSENT_ANCHOR_DIR", dir.join("anchors"))
        .env("MINI_LOCAL_HOST", &host)
        .env("MINI_CONSENT_CONFIG", &settings)
        .env("MINI_CODEC_RESIDENT", if resident { "1" } else { "0" })
        .env("MINI_CODEC_IDLE_S", "3")
        .env_remove("MINI_THIN_CONSENT")
        .output()
        .unwrap()
}

fn resident_files(anchors: &Path, suffix: &str) -> Vec<PathBuf> {
    let mut files: Vec<PathBuf> = fs::read_dir(anchors).map(|entries| entries.filter_map(|e| e.ok()).map(|e| e.path())
        .filter(|p| p.file_name().and_then(|n| n.to_str()).is_some_and(|n| n.starts_with("c-") && n.ends_with(suffix))).collect())
        .unwrap_or_default();
    files.sort();
    files
}

#[test]
fn two_mini_processes_share_one_resident_codec_host_and_opt_out_spawns_per_process() {
    // A short directory: the resident's socket path must fit sun_path.
    let dir = PathBuf::from(format!("/tmp/mcr-{}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir(&dir).unwrap();
    codec_stub(&dir);
    fs::write(dir.join("settings.json"), b"{}").unwrap();
    fs::write(dir.join("input"), b"a plan").unwrap();
    fs::write(dir.join("reply"), framed(b"\x07ok")).unwrap();
    let anchors = dir.join("anchors");

    // Two processes, one binding: the first starts the resident, the second finds it listening.
    for output in ["out-1", "out-2"] {
        let run = mini(&dir, output, true);
        assert!(run.status.success(), "{output}: {}", String::from_utf8_lossy(&run.stderr));
        assert_eq!(fs::read(dir.join(output)).unwrap(), b"ok", "{output}: the resident's reply is the Host's");
    }
    assert_eq!(starts(&dir), 1, "one codec Host child for two mini processes");
    let pids = resident_files(&anchors, ".pid");
    assert_eq!(pids.len(), 1, "one codec resident (c-<binding>.pid) in the anchor directory: {pids:?}");
    assert_eq!(resident_files(&anchors, ".sock").len(), 1);
    let pid: i32 = fs::read_to_string(&pids[0]).unwrap().trim().parse().unwrap();

    // Opted out: each process starts its own child, the resident untouched.
    for output in ["out-3", "out-4"] {
        let run = mini(&dir, output, false);
        assert!(run.status.success(), "{output}: {}", String::from_utf8_lossy(&run.stderr));
        assert_eq!(fs::read(dir.join(output)).unwrap(), b"ok");
    }
    assert_eq!(starts(&dir), 3, "MINI_CODEC_RESIDENT=0: one child per process");

    // Idle for MINI_CODEC_IDLE_S: the resident ends and removes its socket and PID file.
    let began = std::time::Instant::now();
    while pids[0].exists() && began.elapsed() < std::time::Duration::from_secs(60) {
        std::thread::sleep(std::time::Duration::from_millis(100));
    }
    if pids[0].exists() {
        // Stop the process this test started, by the PID in its own PID file, then fail.
        unsafe { libc::kill(pid, libc::SIGTERM); }
        panic!("the resident codec Host (pid {pid}) did not end after its idle time; see {}", dir.display());
    }
    assert!(resident_files(&anchors, ".sock").is_empty(), "the socket goes with the resident");
    assert_eq!(starts(&dir), 3, "ending the resident starts nothing");
    let _ = fs::remove_dir_all(&dir);
}
