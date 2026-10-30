//! Wall-clock bounds on the controller's helper children (`mini`,
//! `minidregg-host`, `systemctl`, launchers). These are physical bounds: a
//! child that outlives one is killed with its whole process group and reaped
//! before the caller sees `io::ErrorKind::TimedOut`. A timeout says nothing
//! about whether a native call committed; callers treat it exactly like a
//! lost reply (the exact retained attempt stays unresolved and is looked up
//! later), never as a refusal and never as success.
use std::io::{self, Read};
use std::os::unix::process::CommandExt;
use std::process::{Child, Command, Output, Stdio};
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

/// One native client call through the Host (submit, retry/lookup, inspect,
/// profile, operator-status, credit). The Host's measured write max on a
/// loaded box is about 57 s (docs/review/2026-10-26-deploy); five times that.
pub(crate) const NATIVE_CALL: Duration = Duration::from_secs(300);
/// A cold controller may need to replay the Store before its first attach.
/// This is a total maintenance envelope, not a larger worker allowance. Keep
/// it inside the fixed admin transport's 1770s and installer's 1800s bounds.
pub(crate) fn startup_limit(seconds: Option<u64>) -> Result<Duration, String> {
    let seconds = seconds.unwrap_or(1200);
    if !(60..=1500).contains(&seconds) {
        return Err("startupTimeoutSeconds must be between 60 and 1500".into());
    }
    Ok(Duration::from_secs(seconds))
}

/// One service-manager query or command (`systemctl show|kill`), a launcher
/// protocol probe, or the launch gate.
pub(crate) const MANAGER_QUERY: Duration = Duration::from_secs(15);
/// The launch gate's own systemd transaction (init/stop of a worker scope).
pub(crate) const LAUNCH_GATE: Duration = Duration::from_secs(60);
/// Captured bytes per stream. A child that writes more is an error, not a
/// silently truncated reply.
const MAX_STREAM_BYTES: usize = 16 * 1024 * 1024;
/// After the leader exits, how long a stray descendant may hold a pipe.
const PIPE_GRACE: Duration = Duration::from_secs(2);

/// Spawn `command` as the leader of its own process group with piped
/// stdout/stderr. Stdin is whatever the caller configured.
pub(crate) fn spawn(command: &mut Command) -> io::Result<Child> {
    command
        .process_group(0)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
}

/// `Command::output` with a deadline: stdin is null.
pub(crate) fn output(command: &mut Command, limit: Duration) -> io::Result<Output> {
    command.stdin(Stdio::null());
    wait(spawn(command)?, limit)
}

fn drain(mut pipe: impl Read + Send + 'static) -> mpsc::Receiver<io::Result<Vec<u8>>> {
    let (tx, rx) = mpsc::channel();
    thread::spawn(move || {
        let mut kept = Vec::new();
        let mut overflow = false;
        let mut chunk = [0u8; 8192];
        // Keep draining past the bound so the child is never blocked on a
        // full pipe; the overflow is reported once the stream ends.
        let result = loop {
            match pipe.read(&mut chunk) {
                Ok(0) if overflow => break Err(io::Error::other("helper output exceeded its capture bound")),
                Ok(0) => break Ok(kept),
                Ok(n) if overflow || kept.len() + n > MAX_STREAM_BYTES => overflow = true,
                Ok(n) => kept.extend_from_slice(&chunk[..n]),
                Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
                Err(e) => break Err(e),
            }
        };
        let _ = tx.send(result);
    });
    rx
}

fn kill_group(child: &mut Child) {
    let pgid = child.id() as libc::pid_t;
    // The child leads the group we created and is not yet reaped, so its
    // PGID cannot have been reused.
    unsafe {
        libc::kill(-pgid, libc::SIGKILL);
    }
    let _ = child.kill();
}

/// Wait for a child made by [`spawn`], killing its process group at `limit`.
pub(crate) fn wait(mut child: Child, limit: Duration) -> io::Result<Output> {
    let start = Instant::now();
    let out = child.stdout.take().map(drain);
    let err = child.stderr.take().map(drain);
    let status = loop {
        match child.try_wait() {
            Ok(Some(status)) => break status,
            Ok(None) if start.elapsed() >= limit => {
                kill_group(&mut child);
                let _ = child.wait();
                return Err(io::Error::new(
                    io::ErrorKind::TimedOut,
                    format!("helper exceeded its {}s deadline; killed; outcome undecided", limit.as_secs()),
                ));
            }
            Ok(None) => thread::sleep(Duration::from_millis(10)),
            Err(e) => {
                kill_group(&mut child);
                let _ = child.wait();
                return Err(e);
            }
        }
    };
    let collect = |rx: Option<mpsc::Receiver<io::Result<Vec<u8>>>>| -> io::Result<Vec<u8>> {
        match rx {
            None => Ok(Vec::new()),
            Some(rx) => rx.recv_timeout(PIPE_GRACE).map_err(|_| {
                io::Error::new(io::ErrorKind::TimedOut,
                    "helper exited but a descendant retained an output pipe; outcome undecided")
            })?,
        }
    };
    let stdout = collect(out);
    let stderr = collect(err);
    if stdout.is_err() || stderr.is_err() {
        // A descendant escaped the leader; take the group down with it.
        unsafe {
            libc::kill(-(child.id() as libc::pid_t), libc::SIGKILL);
        }
    }
    Ok(Output { status, stdout: stdout?, stderr: stderr? })
}

/// Map a deadline helper error into the controller's string errors, naming
/// a timeout as undecided so no caller reads it as a refusal.
pub(crate) fn describe(what: &str, error: io::Error) -> String {
    if error.kind() == io::ErrorKind::TimedOut {
        format!("{what}: undecided (deadline): {error}")
    } else {
        format!("{what}: {error}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deadline_kills_a_hung_child_and_reports_timed_out() {
        let start = Instant::now();
        let error = output(Command::new("/bin/sh").args(["-c", "sleep 30 & sleep 30"]),
            Duration::from_millis(300)).unwrap_err();
        assert_eq!(error.kind(), io::ErrorKind::TimedOut);
        assert!(start.elapsed() < Duration::from_secs(5), "{:?}", start.elapsed());
        assert!(describe("x", error).contains("undecided"));
    }

    #[test]
    fn deadline_leaves_a_fast_childs_output_intact() {
        let out = output(Command::new("/bin/sh").args(["-c", "printf out; printf err >&2; exit 3"]),
            Duration::from_secs(10)).unwrap();
        assert_eq!(out.stdout, b"out");
        assert_eq!(out.stderr, b"err");
        assert_eq!(out.status.code(), Some(3));
    }

    #[test]
    fn deadline_refuses_an_unbounded_stream() {
        let error = output(Command::new("/bin/sh").args(["-c", "head -c 20000000 /dev/zero"]),
            Duration::from_secs(20)).unwrap_err();
        assert_ne!(error.kind(), io::ErrorKind::TimedOut);
    }
}
