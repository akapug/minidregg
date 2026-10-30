//! Generate a small genuinely signed SPK for the helper/RLIMIT regression.
//! The fixed signing seed is fixture material, never a deployment identity.
use ed25519_dalek::SigningKey;
use sandstorm_package::{File, SpkBuilder};
use std::{io, path::PathBuf};

fn main() -> io::Result<()> {
    let mut args = std::env::args_os().skip(1);
    let path = PathBuf::from(
        args.next()
            .ok_or_else(|| io::Error::other("expected output path"))?,
    );
    if args.next().is_some() {
        return Err(io::Error::other("expected only output path"));
    }
    // Exact unpacked BridgeConfig wire: root has zero data words (both bools false)
    // and two pointer slots. viewInfo is null/default, apiPath is the text "/".
    // package.capnp ordinals: viewInfo@0, apiPath@1, saveIdentityCaps@2,
    // powerboxApis@3, expectAppHooks@4; absent trailing fields use zero defaults.
    let mut bridge = Vec::new();
    bridge.extend_from_slice(&0u32.to_le_bytes());
    bridge.extend_from_slice(&4u32.to_le_bytes());
    for word in [2u64 << 48, 0, 1 | (2 << 32) | (2 << 35), u64::from(b'/')] {
        bridge.extend_from_slice(&word.to_le_bytes());
    }
    let bytes = SpkBuilder::new()
        .manifest_json(r#"{"app_id":"ignored","app_title":"SPK spool regression","app_version":1,"continue_command":{"argv":["/sandstorm-http-bridge","8000","--","/app"]}}"#)
        .file(File::regular("sandstorm-http-bridge-config", bridge))
        .file(File::executable("app", vec![42; 2 * 1024 * 1024]))
        .pack(&SigningKey::from_bytes(&[17; 32]));
    let mut output = std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(path)?;
    std::io::Write::write_all(&mut output, &bytes)
}
