//! The crash and hold fixtures, test-only. They used to be verbs of the
//! production binary (and `serve` forwarded them). Two drivers share
//! [`run_fixture`]:
//!
//! * the crate's tests: [`fixture`] re-executes the test binary on its
//!   `fixture_child` test with the fixture's argv in [`ENV`], and
//!   [`run_if_child`] (called by that test) runs it;
//! * the Lean probe `scripts/durable-receiver.lean`: the
//!   `minidregg-link-sqlite-store-fixtures` binary, built only with the
//!   `fixtures` feature (`src/bin/fixtures.rs`), so no candidate carries it.
//!
//! Each fixture ends the process exactly where the old verbs did. Each test
//! file that uses it declares
//!
//! ```ignore
//! mod support;
//! #[test]
//! fn fixture_child() { support::run_if_child() }
//! ```
#![allow(dead_code)]
use minidregg_hyperdocument_link_sqlite_store::{decode_nodes, PublishPhase, SqliteLinkStore, MAX_RECORD_BYTES};
use std::ffi::OsString;
use std::io::{Read, Write};
use std::os::unix::ffi::{OsStrExt, OsStringExt};
use std::path::Path;
use std::process::Command;
use std::time::Duration;

pub const ENV: &str = "MINI_SQ_TEST_FIXTURE";

/// The child process for one fixture: `fixture(&["publish-crash", root, input, "after-commit"])`.
/// Its stdout carries only the fixture's own output, after a `FIXTURE-OUT\n` line.
pub fn fixture<S: AsRef<std::ffi::OsStr>>(args: &[S]) -> Command {
    // Each argument hex-encoded, space-separated: an environment value holds no NUL.
    let joined: Vec<String> = args.iter().map(|a| a.as_ref().as_bytes().iter().map(|b| format!("{b:02x}")).collect()).collect();
    let mut command = Command::new(std::env::current_exe().unwrap());
    command.args(["--exact", "fixture_child", "--nocapture", "--test-threads", "1"]).env(ENV, joined.join(" "));
    command
}

/// What the fixture itself printed (libtest's own lines precede the marker).
pub fn fixture_stdout(stdout: &[u8]) -> Vec<u8> {
    let marker = b"FIXTURE-OUT\n";
    match stdout.windows(marker.len()).position(|w| w == marker) {
        Some(i) => {
            let rest = &stdout[i + marker.len()..];
            let end = rest.windows(4).position(|w| w == b"\ntest").map(|e| e + 1).unwrap_or(rest.len());
            rest[..end].to_vec()
        }
        None => Vec::new(),
    }
}

fn phase(name: &str) -> (PublishPhase, i32) {
    match name {
        "after-begin" => (PublishPhase::Begun, 86),
        "after-insert" => (PublishPhase::Inserted, 87),
        "after-commit" => (PublishPhase::Committed, 88),
        "after-anchor-prepare" => (PublishPhase::AnchorPrepared, 90),
        "after-anchor-rename" => (PublishPhase::AnchorRenamed, 91),
        "after-anchor" => (PublishPhase::Anchored, 89),
        other => panic!("unknown crash phase {other}"),
    }
}

fn input(path: &OsString) -> Vec<u8> {
    let mut bytes = Vec::new();
    std::fs::File::open(path).unwrap().take(MAX_RECORD_BYTES as u64 + 1).read_to_end(&mut bytes).unwrap();
    bytes
}

fn crash_at(target: PublishPhase, code: i32) -> impl FnMut(PublishPhase) {
    move |observed| {
        if observed == target {
            // No reply, no unwinding: SQLite/OS recovery owns the next open.
            std::process::exit(code);
        }
    }
}

/// When this process is a fixture child, perform the fixture (and never
/// return). Otherwise do nothing.
pub fn run_if_child() {
    let Ok(joined) = std::env::var(ENV) else { return };
    let unhex = |h: &str| (0..h.len()).step_by(2).map(|i| u8::from_str_radix(&h[i..i + 2], 16).unwrap()).collect::<Vec<u8>>();
    let args: Vec<OsString> = joined.split(' ').map(|a| OsString::from_vec(unhex(a))).collect();
    let mut out = std::io::stdout().lock();
    out.write_all(b"FIXTURE-OUT\n").unwrap();
    out.flush().unwrap();
    drop(out);
    run_fixture(args)
}

/// One fixture, `[--anchor-identity ID] VERB ARGS...`, the old verbs' argv.
pub fn run_fixture(mut args: Vec<OsString>) -> ! {
    let identity = if args.first().is_some_and(|a| a == "--anchor-identity") {
        let id = args[1].clone().into_vec();
        args.drain(..2);
        id
    } else {
        Vec::new()
    };
    let verb = args[0].to_str().unwrap().to_owned();
    let open = |root: &OsString| SqliteLinkStore::open_with_identity(Path::new(root), &identity).unwrap();
    let mut out = std::io::stdout().lock();
    match (verb.as_str(), &args[1..]) {
        ("publish-crash", [root, file, p]) => {
            let (target, code) = phase(p.to_str().unwrap());
            let _ = open(root).publish_with_hook(&input(file), crash_at(target, code));
        }
        ("cas-crash", [root, expected, file, p]) => {
            let (target, code) = phase(p.to_str().unwrap());
            let expected = (expected != "-").then(|| input(expected));
            let _ = open(root).compare_exchange_with_hook(expected.as_deref(), &input(file), crash_at(target, code));
        }
        ("durable-append-crash", [root, height, record, tag, nodes, p]) => {
            let (target, code) = phase(p.to_str().unwrap());
            let nodes = decode_nodes(&input(nodes)).unwrap();
            let _ = open(root).durable_append_with_hook(height.to_str().unwrap().parse().unwrap(), &input(record), &input(tag), &nodes, crash_at(target, code));
        }
        ("journal-append-crash", [root, seq, record, tag, p]) => {
            let (target, code) = phase(p.to_str().unwrap());
            let _ = open(root).journal_append_with_hook(seq.to_str().unwrap().parse().unwrap(), &input(record), &input(tag), crash_at(target, code));
        }
        ("publish-hold", [root, file, ready, release]) => {
            let (ready, release) = (Path::new(ready), Path::new(release));
            let status = open(root).publish_with_hook(&input(file), |phase| {
                if phase == PublishPhase::Inserted {
                    std::fs::write(ready, b"inserted-not-committed\n").unwrap();
                    while !release.exists() {
                        std::thread::sleep(Duration::from_millis(10));
                    }
                }
            });
            writeln!(out, "{:?}", status.unwrap()).unwrap();
            out.flush().unwrap();
            // The commit is the result; leave without libtest's reporting.
            std::process::exit(0);
        }
        _ => panic!("unknown fixture {verb} {args:?}"),
    }
    // A crash phase the operation never reached: the old verbs returned exit 1.
    std::process::exit(1);
}
