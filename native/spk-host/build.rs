//! Compiles `shim/libifaddrs-lo.c` into OUT_DIR/libifaddrs-lo.so; `src/sandbox.rs` embeds the bytes with
//! `include_bytes!`, so the shim is pinned by the spk-host binary exactly as the seccomp policy is. Linux
//! only: other targets (which cannot build the rest of this crate) get an empty file.
use std::{env, fs, path::PathBuf, process::Command};

fn main() {
    println!("cargo:rerun-if-changed=shim/libifaddrs-lo.c");
    println!("cargo:rerun-if-changed=build.rs");
    let out = PathBuf::from(env::var_os("OUT_DIR").expect("OUT_DIR")).join("libifaddrs-lo.so");
    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("linux") {
        fs::write(&out, b"").expect("write placeholder");
        return;
    }
    let cc = env::var("CC").unwrap_or_else(|_| "cc".into());
    let status = Command::new(&cc)
        .args(["-shared", "-fPIC", "-O2", "-Wall", "-Werror", "-fno-ident", "-s", "-Wl,--build-id=none", "-Wl,-z,relro,-z,now", "-o"])
        .arg(&out)
        .arg("shim/libifaddrs-lo.c")
        .status()
        .unwrap_or_else(|error| panic!("cannot run {cc}: {error}"));
    assert!(status.success(), "compiling shim/libifaddrs-lo.c failed");
}
