//! Explicit peer credentials for controller-private operator proxy sockets.
//! Path custody stays owner-private. A socket activated by systemd can be owned
//! by the controller while its listener credentials name the activator; this
//! pin describes that endpoint, not the UID of the process accepting requests.
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

static SELECTED: OnceLock<u32> = OnceLock::new();
static SOCKETS: Mutex<BTreeMap<PathBuf, u32>> = Mutex::new(BTreeMap::new());

pub(crate) fn configure(uid: u32) -> Result<(), String> {
    if SELECTED.get().is_some_and(|old| *old != uid) {
        return Err("operator peer UID changed within command".into());
    }
    let _ = SELECTED.set(uid);
    Ok(())
}

fn retain(socket: &Path, uid: u32) -> Result<(), String> {
    if !socket.is_absolute() {
        return Err("operator socket peer pin requires an absolute path".into());
    }
    if SELECTED.get().is_some_and(|selected| *selected != uid) {
        return Err("operator peer UID differs from retained custody".into());
    }
    let mut pins = SOCKETS.lock().map_err(|_| "operator peer pin lock poisoned")?;
    if pins.get(socket).is_some_and(|old| *old != uid) {
        return Err("operator socket peer identity changed within command".into());
    }
    pins.insert(socket.to_path_buf(), uid);
    Ok(())
}

pub(crate) fn restore(socket: &Path, pin: &serde_json::Value) -> Result<(), String> {
    let uid = match pin.get("operatorPeerUid") {
        None | Some(serde_json::Value::Null) => mini_sdk::private::euid(),
        Some(value) => value.as_u64().and_then(|n| u32::try_from(n).ok())
            .ok_or("invalid retained operator peer UID")?,
    };
    retain(socket, uid)
}

pub(crate) fn selected(socket: &Path) -> Result<u32, String> {
    Ok(SOCKETS.lock().map_err(|_| "operator peer pin lock poisoned")?.get(socket).copied()
        .or_else(|| SELECTED.get().copied()).unwrap_or_else(mini_sdk::private::euid))
}

pub(crate) fn check_socket(socket: &Path) -> Result<(), String> {
    mini_sdk::private::check_socket(socket).map_err(String::from)?;
    retain(socket, selected(socket)?)
}

/// `None` is an ordinary public socket. Registered operator sockets must keep
/// their original custody and peer on every actual connection before a write.
pub(crate) fn before_connect(socket: &Path) -> Result<Option<u32>, String> {
    let uid = SOCKETS.lock().map_err(|_| "operator peer pin lock poisoned")?.get(socket).copied();
    if uid.is_some() { mini_sdk::private::check_socket(socket).map_err(String::from)?; }
    Ok(uid)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::io::Read;
    use std::os::unix::fs::PermissionsExt;
    use std::os::unix::net::UnixListener;
    use std::time::Duration;
    fn fixture() -> (PathBuf, PathBuf, UnixListener) {
        // Short on purpose: this scratch binds a Unix socket, and macOS caps a
        // socket path at 104 bytes (`SUN_LEN`), which a long `$TMPDIR` already
        // spends most of.
        let directory = std::env::temp_dir().join(format!("mini-op-{}-{}", std::process::id(),
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()));
        fs::create_dir(&directory).unwrap();
        fs::set_permissions(&directory, fs::Permissions::from_mode(0o700)).unwrap();
        let socket = directory.join("mini.sock");
        let listener = UnixListener::bind(&socket).unwrap();
        fs::set_permissions(&socket, fs::Permissions::from_mode(0o600)).unwrap();
        (directory, socket, listener)
    }
    #[test]
    fn operator_peer_legacy_private_custody_and_pin_drift() {
        let (directory, socket, _listener) = fixture();
        restore(&socket, &serde_json::json!({})).unwrap();
        check_socket(&socket).unwrap();
        assert_eq!(before_connect(&socket).unwrap(), Some(mini_sdk::private::euid()));
        assert!(restore(&socket, &serde_json::json!({"operatorPeerUid": u64::MAX})).is_err());
        assert!(restore(&socket, &serde_json::json!({"operatorPeerUid": mini_sdk::private::euid().wrapping_add(1)})).is_err());
        let before = before_connect(&socket).unwrap();
        assert!(before.is_some());
        let original = directory.join("original.sock");
        fs::rename(&socket, &original).unwrap();
        fs::write(&socket, b"replacement").unwrap();
        fs::set_permissions(&socket, fs::Permissions::from_mode(0o600)).unwrap();
        assert!(check_socket(&socket).is_err(), "post-connect custody recheck rejects a replaced path");
        fs::remove_file(&socket).unwrap();
        fs::rename(&original, &socket).unwrap();
        fs::set_permissions(&socket, fs::Permissions::from_mode(0o660)).unwrap();
        assert!(before_connect(&socket).is_err());
        fs::set_permissions(&socket, fs::Permissions::from_mode(0o600)).unwrap();
        let link = directory.join("alias");
        std::os::unix::fs::symlink(&socket, &link).unwrap();
        assert!(check_socket(&link).is_err());
        fs::set_permissions(&directory, fs::Permissions::from_mode(0o710)).unwrap();
        assert!(before_connect(&socket).is_err());
        fs::remove_dir_all(directory).unwrap();
    }
    #[test]
    fn operator_peer_mismatch_sends_no_request_bytes() {
        let (directory, socket, listener) = fixture();
        restore(&socket, &serde_json::json!({"operatorPeerUid":mini_sdk::private::euid().wrapping_add(1)})).unwrap();
        let peer = std::thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            stream.set_read_timeout(Some(Duration::from_secs(2))).unwrap();
            let mut byte = [0];
            assert_eq!(stream.read(&mut byte).unwrap(), 0);
        });
        let error = crate::transport::exchange_unix(&socket, b"must not send").unwrap_err();
        assert!(error.contains("peer UID mismatch before transmission"));
        peer.join().unwrap();
        fs::remove_dir_all(directory).unwrap();
    }
    #[test]
    fn operator_peer_matching_endpoint_preserves_frame() {
        let (directory, socket, listener) = fixture();
        restore(&socket, &serde_json::json!({"operatorPeerUid":mini_sdk::private::euid()})).unwrap();
        let peer = std::thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            assert_eq!(crate::transport::read_frame(&mut stream).unwrap(), Some(vec![80, 7]));
            crate::transport::write_frame(&mut stream, &[80, 9]).unwrap();
        });
        assert_eq!(crate::transport::exchange_unix(&socket, &[80, 7]).unwrap(), [80, 9]);
        peer.join().unwrap();
        fs::remove_dir_all(directory).unwrap();
    }
}
