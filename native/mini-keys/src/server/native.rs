//! What the broker asks the Store: whether a member key is the subject's
//! current, unrevoked key, at which key epoch, and at which Store height. One
//! public-socket query (operation 144), pinned to the Host image and config
//! the challenge named, and answered only by the pinned uid of the account
//! that serves the public socket (`credentials.publicSocketUid`).
//!
//! What binds the unsigned reply to the queried key: the answerer is the pinned
//! uid, the connection carries exactly one query, and Lean's `isCurrent` is
//! defined as "the subject's current key equals the QUERIED key"
//! (`Kernel/Receivers/SubjectKeyRotation.lean` `status`, `decide (current.publicKey
//! = publicKey)`). A reply that names a `publicKey` must name the queried one.
//! The Host's reply today (`Host/Json.lean` `subjectKeyStatusJson`) names
//! neither `publicKey` nor `height`; the Lean ask for both is in
//! `deploy/hermes/README.md` ("What the broker decides, and what it still trusts"). Until `height`
//! is there, a grant's `notAfter` is checked against the controller's stated
//! height (the one remaining claim).
use super::credentials::Owner;
use crate::wire;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::io::Read;
use std::path::Path;
use std::time::Instant;

pub const MAX_HOST_CONFIG: usize = 65_536;
const MAX_HOST_IMAGE: u64 = 1 << 31;
const KEY_STATUS: u8 = 144;

pub fn sha256_hex(bytes: &[u8]) -> String {
    wire::hex(&Sha256::digest(bytes))
}

/// SHA-256 of the selected Host image (a regular file).
pub fn host_sha256(host: &Path) -> Result<String, String> {
    let mut file = std::fs::File::open(host).map_err(|_| "the selected Host image is unavailable")?;
    let meta = file.metadata().map_err(|_| "the selected Host image is unavailable")?;
    if !meta.is_file() || meta.len() > MAX_HOST_IMAGE {
        return Err("the selected Host image is not a regular file".into());
    }
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 1 << 16];
    loop {
        let n = file.read(&mut buf).map_err(|_| "the selected Host image is unreadable")?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }
    Ok(wire::hex(&hasher.finalize()))
}

/// The Host image the deployment pinned (`credentials.hostSha256`, from the
/// candidate manifest). It is hashed once at start and again only when the
/// file's identity or timestamps change, never per request: a member action
/// used to stream the whole image (116 MB) six times.
pub struct HostPin {
    pub path: std::path::PathBuf,
    pub sha256: String,
    seen: std::sync::Mutex<Option<[i64; 7]>>,
}

fn stamp(path: &Path) -> Result<[i64; 7], String> {
    use std::os::unix::fs::MetadataExt;
    let m = std::fs::metadata(path).map_err(|_| "the selected Host image is unavailable")?;
    Ok([m.dev() as i64, m.ino() as i64, m.len() as i64, m.mtime(), m.mtime_nsec(), m.ctime(), m.ctime_nsec()])
}

impl HostPin {
    pub fn new(path: &Path, sha256: &str) -> Self {
        HostPin { path: path.to_owned(), sha256: sha256.to_owned(), seen: std::sync::Mutex::new(None) }
    }

    /// The pinned digest, if the image on disk still is that image.
    pub fn current(&self) -> Result<String, String> {
        let before = stamp(&self.path)?;
        let mut seen = self.seen.lock().map_err(|_| "host pin poisoned")?;
        if *seen == Some(before) {
            return Ok(self.sha256.clone());
        }
        let sha = host_sha256(&self.path)?;
        if sha != self.sha256 {
            *seen = None;
            return Err(format!("the selected Host image {} is not the pinned candidate image (hostSha256)", self.path.display()));
        }
        // Remember the stamp only if nothing moved while it was hashed.
        if stamp(&self.path)? == before {
            *seen = Some(before);
        }
        Ok(sha)
    }
}

/// The pinned Host config bytes, exactly (their digest is what members compare).
pub fn host_config(path: &Path) -> Result<Vec<u8>, String> {
    let file = std::fs::File::open(path).map_err(|_| "the pinned Host config is unavailable")?;
    let mut bytes = Vec::new();
    file.take((MAX_HOST_CONFIG + 1) as u64)
        .read_to_end(&mut bytes)
        .map_err(|_| "the pinned Host config is unreadable")?;
    if bytes.len() > MAX_HOST_CONFIG {
        return Err("the pinned Host config exceeds its bound".into());
    }
    Ok(bytes)
}

/// Ask the Store about `owner` through the public socket, refusing an answer
/// from any account but `uid`.
pub fn key_status(socket: &Path, uid: u32, config: &[u8], host_sha: &str, owner: &Owner, end: Instant) -> Result<Value, String> {
    let mut frame = vec![2];
    frame.extend_from_slice(&(config.len() as u32).to_le_bytes());
    frame.extend_from_slice(config);
    frame.extend_from_slice(&wire::unhex(host_sha)?);
    frame.push(KEY_STATUS);
    frame.extend_from_slice(&serde_json::to_vec(&json!({"subject":owner.subject,"publicKey":owner.public_key})).map_err(|_| "key-status query encode failed")?);
    let mut stream = crate::client::connect(socket, end).map_err(|_| "the native key-status query is unavailable")?;
    let answerer = crate::peer::of(&stream).map_err(|_| "the native key-status socket's account is unknown")?;
    if answerer.uid != uid {
        return Err(format!("the native key-status socket answered as uid {}, not the pinned public-socket uid {uid}", answerer.uid));
    }
    wire::write_frame(&mut stream, &frame, end)?;
    let reply = wire::read_frame(&mut stream, MAX_HOST_CONFIG, end)?;
    match reply.split_first() {
        Some((&KEY_STATUS, body)) => serde_json::from_slice(body).map_err(|_| "invalid native key status".into()),
        _ => Err("the native key-status query refused".into()),
    }
}

fn canonical_decimal(value: &str) -> bool {
    !value.is_empty() && value.len() <= 40 && value.bytes().all(|b| b.is_ascii_digit()) && (value == "0" || !value.starts_with('0'))
}

/// What the Store said about the queried key.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct KeyView {
    pub epoch: String,
    /// The Store height the status was read at, when the reply names it.
    pub height: Option<u64>,
}

/// The view must say: this subject, current (for the queried key), not
/// revoked; it names the epoch, and the key when it names one.
pub fn current_epoch(view: &Value, owner: &Owner) -> Result<KeyView, String> {
    let epoch = view["keyEpoch"].as_str().filter(|e| canonical_decimal(e));
    if view["type"] != "subject-key-status-v1"
        || view["subject"] != owner.subject
        || view.get("publicKey").is_some_and(|k| k != &json!(owner.public_key))
        || view["isCurrent"] != true
        || view["currentRevoked"] != false
        || epoch.is_none()
    {
        return Err("owner-not-current".into());
    }
    let height = match view.get("height") {
        None => None,
        Some(h) => Some(h.as_str().filter(|h| canonical_decimal(h)).and_then(|h| h.parse().ok()).ok_or("owner-not-current")?),
    };
    Ok(KeyView { epoch: epoch.unwrap_or_default().to_owned(), height })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_a_current_unrevoked_exact_view_names_an_epoch() {
        let owner = Owner::new("20", &"ab".repeat(32)).unwrap();
        let good = json!({"type":"subject-key-status-v1","subject":"20","publicKey":"ab".repeat(32),"keyEpoch":"1","height":"7","isCurrent":true,"currentRevoked":false});
        assert_eq!(current_epoch(&good, &owner).unwrap(), KeyView { epoch: "1".into(), height: Some(7) });
        // The Host's reply today names neither the key nor the height: bound by
        // the pinned answerer and Lean's isCurrent-of-the-queried-key, no height.
        let mut lean_today = good.clone();
        lean_today.as_object_mut().unwrap().remove("publicKey");
        lean_today.as_object_mut().unwrap().remove("height");
        assert_eq!(current_epoch(&lean_today, &owner).unwrap(), KeyView { epoch: "1".into(), height: None });
        let mut no_height = good.clone();
        no_height.as_object_mut().unwrap().remove("height");
        assert_eq!(current_epoch(&no_height, &owner).unwrap().height, None);
        let mut bad_height = good.clone();
        bad_height["height"] = json!(7);
        assert!(current_epoch(&bad_height, &owner).is_err());
        for field in ["isCurrent", "currentRevoked", "subject", "keyEpoch", "type"] {
            let mut bad = good.clone();
            bad.as_object_mut().unwrap().remove(field);
            assert!(current_epoch(&bad, &owner).is_err(), "{field}");
        }
        let mut revoked = good.clone();
        revoked["currentRevoked"] = json!(true);
        assert!(current_epoch(&revoked, &owner).is_err());
        let mut other_key = good.clone();
        other_key["publicKey"] = json!("cd".repeat(32));
        assert!(current_epoch(&other_key, &owner).is_err());
        let mut padded = good;
        padded["keyEpoch"] = json!("01");
        assert!(current_epoch(&padded, &owner).is_err());
    }
}
