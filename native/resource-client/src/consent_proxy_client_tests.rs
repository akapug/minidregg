//! Actual client connection and binding tests; fake service, no Lean admission.
use super::*;
use std::os::unix::fs::PermissionsExt;
use std::sync::atomic::{AtomicU64, Ordering};
use std::thread;

static NEXT: AtomicU64 = AtomicU64::new(0);
struct Fixture {
    dir: PathBuf,
    selection: Selection,
    config: Vec<u8>,
    listener: UnixListener,
}
impl Fixture {
    fn new() -> Self {
        let dir = std::env::temp_dir().join(format!(
            "mini-consent-client-test-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&dir).unwrap();
        fs::set_permissions(&dir, fs::Permissions::from_mode(0o700)).unwrap();
        let socket = dir.join("consent.sock");
        let listener = UnixListener::bind(&socket).unwrap();
        fs::set_permissions(&socket, fs::Permissions::from_mode(0o600)).unwrap();
        let config = b"fixture-config".to_vec();
        let selection = Selection {
            socket,
            peer: unsafe { libc::geteuid() },
            executable: [7; 32],
            config: Sha256::digest(&config).into(),
        };
        Self {
            dir,
            selection,
            config,
            listener,
        }
    }
}
impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.selection.socket);
        let _ = fs::remove_dir(&self.dir);
    }
}

#[test]
fn connects_and_exchanges_without_a_local_provider_executable() {
    let fixture = Fixture::new();
    let listener = fixture.listener.try_clone().unwrap();
    let expected = fixture.selection.hello();
    let server = thread::spawn(move || {
        let (mut socket, _) = listener.accept().unwrap();
        let hello = transport::read_frame(&mut socket).unwrap().unwrap();
        assert_eq!(hello, expected);
        transport::write_frame(&mut socket, &hello).unwrap();
        let request = transport::read_frame(&mut socket).unwrap().unwrap();
        assert_eq!(request, [220, 1, 2]);
        transport::write_frame(&mut socket, &[220, 3]).unwrap();
    });
    let (mut input, mut output) = connect(&fixture.selection, &fixture.config).unwrap();
    transport::write_frame(&mut input, &[220, 1, 2]).unwrap();
    assert_eq!(
        transport::read_frame(&mut output).unwrap().unwrap(),
        [220, 3]
    );
    server.join().unwrap();
}

#[test]
fn rejects_changed_config_before_connecting() {
    let fixture = Fixture::new();
    assert!(connect(&fixture.selection, b"different config")
        .err()
        .unwrap()
        .contains("config digest mismatch"));
}

#[test]
fn rejects_wrong_connected_peer_before_sending_anything() {
    let mut fixture = Fixture::new();
    fixture.selection.peer = fixture.selection.peer.wrapping_add(1);
    let listener = fixture.listener.try_clone().unwrap();
    let server = thread::spawn(move || {
        let (mut socket, _) = listener.accept().unwrap();
        socket
            .set_read_timeout(Some(Duration::from_secs(2)))
            .unwrap();
        let mut byte = [0; 1];
        assert_eq!(socket.read(&mut byte).unwrap(), 0);
    });
    assert!(connect(&fixture.selection, &fixture.config)
        .err()
        .unwrap()
        .contains("peer UID mismatch"));
    server.join().unwrap();
}

#[test]
fn rejects_handshake_with_a_different_provider_digest() {
    let fixture = Fixture::new();
    let listener = fixture.listener.try_clone().unwrap();
    let server = thread::spawn(move || {
        let (mut socket, _) = listener.accept().unwrap();
        let mut hello = transport::read_frame(&mut socket).unwrap().unwrap();
        hello[TAG.len()] ^= 1;
        transport::write_frame(&mut socket, &hello).unwrap();
    });
    assert!(connect(&fixture.selection, &fixture.config)
        .err()
        .unwrap()
        .contains("service binding mismatch"));
    server.join().unwrap();
}

/// The warm public body keeps one delegated connection for hours. The worker closes a connection that
/// has been idle for REPLAY and ends itself when idle, so the next request met a dead transport and
/// every later one answered "consent transport is poisoned". Now a dead connection is noticed before
/// the next request is sent, the session is dropped, and the next request opens a fresh connection.
#[test]
fn a_body_whose_worker_closed_its_connection_serves_the_next_request_on_a_fresh_one() {
    let fixture = Fixture::new();
    let listener = fixture.listener.try_clone().unwrap();
    let expected = fixture.selection.hello();
    let server = thread::spawn(move || {
        // first connection: one exchange, then the worker goes away (idle exit or deadline)
        let (mut first, _) = listener.accept().unwrap();
        assert_eq!(transport::read_frame(&mut first).unwrap().unwrap(), expected);
        transport::write_frame(&mut first, &expected).unwrap();
        assert_eq!(transport::read_frame(&mut first).unwrap().unwrap(), [220, 1]);
        transport::write_frame(&mut first, &[220, 2]).unwrap();
        drop(first);
        // second connection, from the socket-activated unit's next worker
        let (mut second, _) = listener.accept().unwrap();
        assert_eq!(transport::read_frame(&mut second).unwrap().unwrap(), expected);
        transport::write_frame(&mut second, &expected).unwrap();
        assert_eq!(transport::read_frame(&mut second).unwrap().unwrap(), [220, 3]);
        transport::write_frame(&mut second, &[220, 4]).unwrap();
    });
    let session = |(input, output, live): (Box<dyn Write + Send>, Box<dyn Read + Send>, Lifeline)| {
        (Some(mini_sdk::consent::Consent(mini_sdk::local::Session::over(input, output, PathBuf::from("/x"), Vec::new()))), Some(live))
    };
    let (mut slot, mut live) = session(connect_with_lifeline(&fixture.selection, &fixture.config).unwrap());
    assert!(live.as_ref().unwrap().alive(), "a fresh connection is alive");
    assert!(!crate::client_consent::drop_dead_delegated_session(&mut slot, &mut live), "and is kept");
    let reply = slot.as_mut().unwrap().0.exchange(220, &[1]).unwrap();
    assert_eq!(reply, (220, vec![2]));
    // the worker is gone: the idle connection is dead before anything is sent into it
    for _ in 0..200 {
        if !live.as_ref().unwrap().alive() { break; }
        thread::sleep(Duration::from_millis(10));
    }
    assert!(crate::client_consent::drop_dead_delegated_session(&mut slot, &mut live), "a closed connection is dropped");
    assert!(slot.is_none() && live.is_none());
    // the next request: a fresh connection, one exchange, never a replay of the old one
    let (mut slot, _live) = session(connect_with_lifeline(&fixture.selection, &fixture.config).unwrap());
    assert_eq!(slot.as_mut().unwrap().0.exchange(220, &[3]).unwrap(), (220, vec![4]));
    server.join().unwrap();
}
