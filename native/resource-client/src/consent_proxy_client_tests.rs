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
