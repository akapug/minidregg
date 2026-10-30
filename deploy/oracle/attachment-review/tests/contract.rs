//! Independent adversarial controls against the production custody API.
//! Run on Linux with ATTACHMENT_REVIEW_ROOT set to an existing private directory.
#![cfg(target_os = "linux")]
#[path = "../../../../native/spk-host/src/namespace_identity.rs"]
mod namespace_identity;
mod os { pub(crate) fn root_owner(uid: u32) -> bool { uid == 0 } }
#[path = "../../../../native/spk-host/src/shared_data.rs"]
mod shared_data;
use shared_data::{audit, open_published, parse_signed_attachment, publish};
use serde_json::json;
use sha2::{Digest, Sha256};
use std::{fs, os::unix::fs::{symlink, PermissionsExt}, path::PathBuf, sync::atomic::{AtomicU64, Ordering}};
static SERIAL: AtomicU64 = AtomicU64::new(0);
fn hash(data: &[u8]) -> String { format!("{:x}", Sha256::digest(data)) }
struct Case { root: PathBuf, store: PathBuf, source: PathBuf, inventory: Vec<u8>, declaration: Vec<u8> }
impl Case {
    fn new() -> Self {
        let parent = PathBuf::from(std::env::var_os("ATTACHMENT_REVIEW_ROOT").expect("set ATTACHMENT_REVIEW_ROOT to an existing private directory"));
        let root = parent.join(format!("attachment-review-{}-{}", std::process::id(), SERIAL.fetch_add(1, Ordering::Relaxed)));
        fs::create_dir(&root).unwrap(); fs::set_permissions(&root, fs::Permissions::from_mode(0o700)).unwrap();
        let store = root.join("store"); let source = root.join("source");
        fs::create_dir(&store).unwrap(); fs::create_dir(&source).unwrap();
        fs::set_permissions(&store, fs::Permissions::from_mode(0o700)).unwrap();
        fs::write(source.join("facts"), b"public facts\n").unwrap();
        let inventory = serde_json::to_vec(&json!({"schema":"minidregg-public-data-inventory-v1","visibility":"public","files":[{"path":"facts","size":13,"sha256":hash(b"public facts\n")}]})).unwrap();
        let declaration = serde_json::to_vec(&json!({"schema":"minidregg-public-data-v1","inventory_sha256":hash(&inventory)})).unwrap();
        Self { root, store, source, inventory, declaration }
    }
    fn req(&self) -> shared_data::SharedDataRequirement { parse_signed_attachment(&self.declaration).unwrap() }
    fn published(&self) -> PathBuf { self.store.join(format!("sha256-{}", hash(&self.inventory))) }
    fn publish(&self) { publish(&self.store, &self.source, &self.inventory).expect("valid publication"); }
}
fn make_removable(path: &std::path::Path) {
    if let Ok(meta) = fs::symlink_metadata(path) {
        if meta.is_dir() && !meta.file_type().is_symlink() {
            let _ = fs::set_permissions(path, fs::Permissions::from_mode(0o700));
            if let Ok(entries) = fs::read_dir(path) { for entry in entries.flatten() { make_removable(&entry.path()); } }
        }
    }
}
impl Drop for Case { fn drop(&mut self) { make_removable(&self.root); let _ = fs::remove_dir_all(&self.root); } }
fn app_uid() -> u32 { 65534 }

#[test]
fn signed_declaration_is_exact_and_closed() {
    let c = Case::new(); assert!(parse_signed_attachment(&c.declaration).is_ok());
    for bad in [
        b"{}".as_slice(),
        b"{\"schema\":\"minidregg-public-data-v1\",\"inventory_sha256\":\"ABC\"}",
        b"{\"schema\":\"minidregg-public-data-v1\",\"inventory_sha256\":\"0000000000000000000000000000000000000000000000000000000000000000\",\"hostpath\":\"/etc\"}",
        b"{\"schema\":\"minidregg-public-data-v1\",\"schema\":\"minidregg-public-data-v1\",\"inventory_sha256\":\"0000000000000000000000000000000000000000000000000000000000000000\"}",
    ] { assert!(parse_signed_attachment(bad).is_err(), "accepted {}", String::from_utf8_lossy(bad)); }
}
#[test]
fn exact_revision_missing_data_and_reopen_fail_closed() {
    let c = Case::new(); let req = c.req();
    assert!(open_published(&c.store, &req, app_uid()).is_err());
    c.publish(); assert!(audit(&c.store, &req, app_uid()).is_ok());
    let held = open_published(&c.store, &req, app_uid()).expect("positive control");
    let other = serde_json::to_vec(&json!({"schema":"minidregg-public-data-v1","inventory_sha256":"a".repeat(64)})).unwrap();
    assert!(open_published(&c.store, &parse_signed_attachment(&other).unwrap(), app_uid()).is_err());
    fs::set_permissions(c.published().join("data"), fs::Permissions::from_mode(0o700)).unwrap();
    fs::remove_file(c.published().join("data/facts")).unwrap();
    assert!(held.recheck().is_err());
    assert!(open_published(&c.store, &req, app_uid()).is_err());
}
#[test]
fn source_symlink_and_bad_inventory_are_refused() {
    let c = Case::new(); fs::remove_file(c.source.join("facts")).unwrap();
    symlink("/etc/passwd", c.source.join("facts")).unwrap();
    assert!(publish(&c.store, &c.source, &c.inventory).is_err());
    fs::remove_file(c.source.join("facts")).unwrap(); fs::write(c.source.join("facts"), b"public facts\n").unwrap();
    let malformed = serde_json::to_vec(&json!({"schema":"minidregg-public-data-inventory-v1","visibility":"private","files":[{"path":"../facts","size":13,"sha256":hash(b"public facts\n")}]})).unwrap();
    assert!(publish(&c.store, &c.source, &malformed).is_err());
}

#[test]
fn changed_inventory_and_extra_tree_entry_fail_after_publication() {
    let c = Case::new(); c.publish(); let req = c.req();
    assert!(open_published(&c.store, &req, app_uid()).is_ok());
    let published = c.published();
    fs::set_permissions(&published, fs::Permissions::from_mode(0o700)).unwrap();
    let inv = published.join("inventory.json");
    fs::set_permissions(&inv, fs::Permissions::from_mode(0o600)).unwrap();
    let mut changed = c.inventory.clone(); changed.push(b' '); fs::write(&inv, changed).unwrap();
    assert!(open_published(&c.store, &req, app_uid()).is_err());
}
#[test]
fn extra_file_is_not_silently_exposed() {
    let c = Case::new(); c.publish(); let req = c.req();
    let data = c.published().join("data");
    fs::set_permissions(&data, fs::Permissions::from_mode(0o700)).unwrap();
    fs::write(data.join("unlisted"), b"extra").unwrap();
    fs::set_permissions(&data, fs::Permissions::from_mode(0o555)).unwrap();
    assert!(open_published(&c.store, &req, app_uid()).is_err());
}

#[test]
fn inventory_rejects_independent_bad_fields_and_order() {
    let c = Case::new();
    let row = json!({"path":"facts","size":13,"sha256":hash(b"public facts\n")});
    let cases = [
        json!({"schema":"wrong","visibility":"public","files":[row.clone()]}),
        json!({"schema":"minidregg-public-data-inventory-v1","visibility":"private","files":[row.clone()]}),
        json!({"schema":"minidregg-public-data-inventory-v1","visibility":"public","files":[{"path":"../facts","size":13,"sha256":hash(b"public facts\n")}]}),
        json!({"schema":"minidregg-public-data-inventory-v1","visibility":"public","files":[{"path":"facts","size":12,"sha256":hash(b"public facts\n")}]}),
        json!({"schema":"minidregg-public-data-inventory-v1","visibility":"public","files":[{"path":"facts","size":13,"sha256":"0".repeat(64)}]}),
        json!({"schema":"minidregg-public-data-inventory-v1","visibility":"public","files":[row.clone(),row.clone()]}),
        json!({"schema":"minidregg-public-data-inventory-v1","visibility":"public","files":[{"path":"z","size":0,"sha256":hash(b"")},row]}),
    ];
    for value in cases { let bytes = serde_json::to_vec(&value).unwrap(); assert!(publish(&c.store, &c.source, &bytes).is_err(), "accepted {value}"); }
}

#[test]
fn held_descriptor_rejects_data_directory_replacement() {
    let c = Case::new(); c.publish(); let req = c.req();
    let held = open_published(&c.store, &req, app_uid()).unwrap();
    let publication = c.published();
    fs::set_permissions(&publication, fs::Permissions::from_mode(0o700)).unwrap();
    fs::rename(publication.join("data"), publication.join("old-data")).unwrap();
    symlink("old-data", publication.join("data")).unwrap();
    fs::set_permissions(&publication, fs::Permissions::from_mode(0o555)).unwrap();
    assert!(held.recheck().is_err());
    assert!(open_published(&c.store, &req, app_uid()).is_err());
}

#[test]
fn held_revision_survives_catalog_rename_but_restart_fails_closed() {
    let c = Case::new(); c.publish(); let req = c.req();
    let held = open_published(&c.store, &req, app_uid()).unwrap();
    let published = c.published(); let moved = c.store.join("temporarily-removed");
    fs::rename(&published, &moved).unwrap();
    assert!(held.recheck().is_ok(), "retained verified publication should stay usable");
    assert!(open_published(&c.store, &req, app_uid()).is_err(), "restart must not find removed revision");
    symlink("temporarily-removed", &published).unwrap();
    assert!(open_published(&c.store, &req, app_uid()).is_err(), "restart must reject catalog symlink");
    fs::remove_file(&published).unwrap(); fs::rename(&moved, &published).unwrap();
    assert!(open_published(&c.store, &req, app_uid()).is_ok());
}
