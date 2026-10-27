//! Real user-namespace ownership and retained-handle checks. See namespace-review.sh.
#![cfg(target_os = "linux")]
#[path = "../../../../native/spk-host/src/namespace_identity.rs"]
mod namespace_identity;
#[path = "../../../../native/spk-host/src/shared_data.rs"]
mod shared_data;
mod os { pub(crate) fn root_owner(uid: u32) -> bool { uid == 0 } }
use sha2::{Digest, Sha256};
use std::io::{Read, Write};
use std::{fs, os::unix::fs::MetadataExt, path::PathBuf};

fn main() {
    let base = PathBuf::from(std::env::var_os("ATTACHMENT_NAMESPACE_FIXTURE").expect("use namespace-review.sh"));
    let root = base.join("root");
    let config = root.join("config.json");
    let foreign = base.join("foreign");
    let app = base.join("app");
    let link = base.join("link");
    assert_eq!(fs::metadata(&root).unwrap().uid(), 0);
    assert_ne!(fs::metadata(&foreign).unwrap().uid(), 0);
    let source = base.join("source");
    let content = b"public fixture\n";
    fs::write(source.join("facts"), content).unwrap();
    let inventory = serde_json::to_vec(&serde_json::json!({"schema":"minidregg-public-data-inventory-v1","visibility":"public","files":[{"path":"facts","size":content.len(),"sha256":format!("{:x}", Sha256::digest(content))}]})).unwrap();
    let store = root.join("spk/public-data");
    let published = shared_data::publish(&store, &source, &inventory).unwrap();
    let declaration = serde_json::to_vec(&serde_json::json!({"schema":"minidregg-public-data-v1","inventory_sha256":published.inventory_sha256})).unwrap();
    let requirement = shared_data::parse_signed_attachment(&declaration).unwrap();
    let package = base.join("fixture.spk");
    let key = ed25519_dalek::SigningKey::from_bytes(&[7;32]);
    let archive = sandstorm_package::SpkBuilder::new()
        .manifest_json(r#"{"app_id":"untrusted","app_title":"namespace fixture","app_version":1,"continue_command":{"argv":["/app"]}}"#)
        .file(sandstorm_package::File::executable("app", b"fixture".to_vec()))
        .pack(&key);
    fs::write(&package, &archive).unwrap();
    let mut decoded = Vec::new(); xz2::read::XzDecoder::new(&archive[8..]).read_to_end(&mut decoded).unwrap();
    let original = key.verifying_key().to_bytes();
    let key_offset = decoded.windows(32).position(|w| w == original).unwrap();
    decoded[key_offset..key_offset+32].copy_from_slice(ed25519_dalek::SigningKey::from_bytes(&[8;32]).verifying_key().as_bytes());
    let mut encoder = xz2::write::XzEncoder::new(Vec::new(), 1); encoder.write_all(&decoded).unwrap();
    let mut forged = archive[..8].to_vec(); forged.extend(encoder.finish().unwrap());
    let forged_path = base.join("forged.spk"); fs::write(&forged_path, forged).unwrap();
    let scratch = root.join("spk/packages");
    let original_data_meta = fs::metadata(published.directory.join("data/facts")).unwrap();
    assert_eq!(original_data_meta.uid(), unsafe { libc::geteuid() });
    assert_eq!(original_data_meta.gid(), 0, "fixture must exercise unmapped group normalization");
    for untrusted in [&foreign, &app, &link] {
        assert!(namespace_identity::prepare_root_handles(&untrusted.join("config"), &root, "store", "grain").is_err(), "untrusted ancestor accepted: {}", untrusted.display());
    }
    namespace_identity::prepare_root_handles(&config, &root, "store", "grain").unwrap();
    let bwrap = PathBuf::from("/usr/local/libexec/mini-grain-bwrap");
    let bwrap_sha = std::env::var("ATTACHMENT_BWRAP_SHA256").unwrap();
    namespace_identity::enter(&bwrap, &bwrap_sha, unsafe { libc::geteuid() }, unsafe { libc::getegid() }, 100000, 100000).unwrap();
    let limits = minidregg_spk_package_stream::Limits::DEFAULT;
    let old = minidregg_spk_package_stream::verify_in_private_temp_at(&package, &scratch, limits).err().expect("old check should reject unmapped root");
    assert!(old.to_string().contains("scratch parent custody refused"));
    let verified = minidregg_spk_package_stream::verify_in_private_temp_at_with_root_custody(&package, &scratch, limits, namespace_identity::root_owned).expect("valid signature and retained scratch ancestry must pass");
    assert_eq!(verified.raw_sha256, <[u8;32]>::from(Sha256::digest(&archive)));
    assert!(minidregg_spk_package_stream::verify_in_private_temp_at_with_root_custody(&forged_path, &scratch, limits, namespace_identity::root_owned).is_err(), "forged signature must refuse");
    for bad in [&foreign, &app, &link] {
        let error = minidregg_spk_package_stream::verify_in_private_temp_at_with_root_custody(&package, bad, limits, namespace_identity::root_owned).err().expect("untrusted scratch must refuse");
        assert!(error.to_string().contains("scratch parent custody refused"), "untrusted scratch unexpectedly reached verification: {error}");
    }
    let held = shared_data::open_published(&store, &requirement, 100000).expect("published data opens after namespace entry");
    held.recheck().unwrap();
    shared_data::audit(&store, &requirement, 100000).unwrap();
    let namespace_data_meta = fs::metadata(published.directory.join("data/facts")).unwrap();
    assert_ne!(namespace_data_meta.gid(), original_data_meta.gid());
    assert_eq!(namespace_identity::original_owner(&namespace_data_meta), Some((original_data_meta.uid(), original_data_meta.gid())));
    let extra_revision = store.join(format!("sha256-{}", "a".repeat(64)));
    fs::create_dir(&extra_revision).unwrap();
    assert!(held.recheck().is_ok(), "adding another catalog entry must not invalidate the held publication");
    let moved = store.join("temporarily-removed");
    fs::rename(&published.directory, &moved).unwrap();
    assert!(held.recheck().is_err(), "renaming the held publication changes pinned metadata and must fail closed");
    assert!(shared_data::open_published(&store, &requirement, 100000).is_err(), "missing catalog revision must fail closed");
    fs::rename(&moved, &published.directory).unwrap();
    let unknown = base.join("unknown-after-capture");
    fs::write(&unknown, b"uncaptured").unwrap();
    assert_eq!(namespace_identity::original_owner(&fs::metadata(&unknown).unwrap()), None);
    let root_meta = fs::symlink_metadata(&root).unwrap();
    assert_eq!(namespace_identity::original_owner(&root_meta), Some((0, 100001)));
    let foreign_meta = fs::symlink_metadata(&foreign).unwrap();
    assert_ne!(root_meta.uid(), 0);
    assert_eq!(root_meta.uid(), foreign_meta.uid(), "fixture must demonstrate overflow collision");
    assert_eq!(fs::symlink_metadata(&app).unwrap().uid(), 100000);
    assert!(namespace_identity::root_owned(&root, &root_meta));
    assert_eq!(namespace_identity::original_owner(&foreign_meta), None);
    assert!(!namespace_identity::root_owned(&foreign, &foreign_meta));
    assert!(!namespace_identity::root_owned(&app, &fs::symlink_metadata(&app).unwrap()));
    assert!(!namespace_identity::root_owned(&link, &fs::symlink_metadata(&link).unwrap()));
    fs::rename(&root, base.join("old-root")).unwrap();
    fs::rename(&foreign, &root).unwrap();
    assert!(!namespace_identity::root_owned(&root, &fs::symlink_metadata(&root).unwrap()));
    println!("namespace provenance control passed: root and foreign uid {}, app uid 100000; untrusted ancestors and replacement refused", root_meta.uid());
}
