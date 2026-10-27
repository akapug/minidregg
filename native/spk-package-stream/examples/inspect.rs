//! Operator post-pack inspection. Verifies a private snapshot before hashing members.
//! No application admission or Mini authority is created by this command.
use minidregg_spk_package_stream::{verify, EntryKind, ImportProfile, VerifiedPackage};
use serde_json::{json, Map, Value};
use sha2::{Digest, Sha256};
use std::{
    io::{self, Write},
    path::Path,
};

const MAX_OUTPUT: usize = 16 * 1024 * 1024;

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

struct HashWriter(Sha256);
impl Write for HashWriter {
    fn write(&mut self, bytes: &[u8]) -> io::Result<usize> {
        self.0.update(bytes);
        Ok(bytes.len())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

fn inventory(package: &VerifiedPackage, profile: ImportProfile) -> io::Result<Value> {
    let mut entries = Map::new();
    for (index, entry) in package.entries().iter().enumerate() {
        let path = entry
            .path
            .to_str()
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "non-UTF8 member"))?;
        let value = match &entry.kind {
            EntryKind::Directory => json!({"kind": "directory"}),
            EntryKind::Symlink(target) => json!({"kind": "symlink", "target": target}),
            EntryKind::Regular { executable } => {
                let mut hash = HashWriter(Sha256::new());
                package.copy_member(index, &mut hash)?;
                json!({"kind": "file", "size": entry.len(), "executable": executable,
                       "sha256": hex(&hash.0.finalize())})
            }
        };
        if entries.insert(path.into(), value).is_some() {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "duplicate verified member",
            ));
        }
    }
    Ok(
        json!({"schema": "verified-spk-inventory-v1", "signature_verified": true,
        "profile": profile.as_str(), "raw_sha256": hex(&package.raw_sha256),
        "raw_bytes": package.raw_length, "public_key_hex": hex(&package.public_key),
        "app_id": package.manifest.app_id, "app_version": package.manifest.app_version,
        "signed_data_config_sha256": package.data_config_bytes.as_ref().map(|bytes| hex(&Sha256::digest(bytes))),
        "entries": entries}),
    )
}

struct BoundedOutput(Vec<u8>);
impl Write for BoundedOutput {
    fn write(&mut self, bytes: &[u8]) -> io::Result<usize> {
        if bytes.len() > MAX_OUTPUT.saturating_sub(self.0.len()) {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "inventory JSON exceeds 16 MiB",
            ));
        }
        self.0.extend_from_slice(bytes);
        Ok(bytes.len())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args_os().collect();
    if args.len() != 4 {
        return Err(
            "usage: inspect PACKAGE.spk PROTECTED_DISK_SCRATCH standard-v1|operator-appliance-v1"
                .into(),
        );
    }
    let profile: ImportProfile = args[3].to_str().ok_or("invalid profile")?.parse()?;
    let package = verify(Path::new(&args[1]), Path::new(&args[2]), profile.limits())?;
    let value = inventory(&package, profile)?;
    let mut out = BoundedOutput(Vec::new());
    serde_json::to_writer(&mut out, &value)?;
    // Publish JSON only after the entire verified inventory fits the bound.
    io::stdout().lock().write_all(&out.0)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::SigningKey;
    use sandstorm_package::{File, SpkBuilder};

    #[test]
    fn signed_fixture_hashes_contents_and_uses_signer_identity() {
        let manifest = r#"{"app_id":"not-the-signer","app_title":"inspect fixture","app_version":1,"continue_command":{"argv":["/app"]}}"#;
        let bytes = SpkBuilder::new()
            .manifest_json(manifest)
            .file(File::executable("app", b"exact executable".to_vec()))
            .file(File::regular("data", b"exact data".to_vec()))
            .pack(&SigningKey::from_bytes(&[7; 32]));
        let temp = tempfile::tempdir().unwrap();
        let path = temp.path().join("fixture.spk");
        std::fs::write(&path, &bytes).unwrap();
        let verified = verify(&path, temp.path(), ImportProfile::Standard.limits()).unwrap();
        let actual = inventory(&verified, ImportProfile::Standard).unwrap();
        assert_eq!(
            actual["entries"]["app"],
            json!({"kind":"file","executable":true,
            "size":16,"sha256":hex(&Sha256::digest(b"exact executable"))})
        );
        assert_eq!(
            actual["entries"]["data"]["sha256"],
            hex(&Sha256::digest(b"exact data"))
        );
        assert_ne!(actual["app_id"], "not-the-signer");
        assert_eq!(actual["raw_sha256"], hex(&Sha256::digest(&bytes)));
        // The verified snapshot remains authoritative after the pathname changes.
        std::fs::write(&path, b"replacement").unwrap();
        assert_eq!(
            inventory(&verified, ImportProfile::Standard).unwrap(),
            actual
        );
        assert!(verify(&path, temp.path(), ImportProfile::Standard.limits()).is_err());
    }

    #[test]
    fn output_is_bounded_before_publication() {
        let mut out = BoundedOutput(vec![0; MAX_OUTPUT]);
        assert!(out.write_all(b"x").is_err());
        assert_eq!(out.0.len(), MAX_OUTPUT);
    }
}
