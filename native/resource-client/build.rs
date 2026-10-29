// Embed the checked-in declaration sources. Operation schemas remain in those
// files and are interpreted by the same native SDK used for attached tools.
use std::{env, fs, path::PathBuf};
fn main() {
    let directory = PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap())
        .join("../../apps/interfaces");
    println!("cargo:rerun-if-changed={}", directory.display());
    let mut files: Vec<_> = fs::read_dir(&directory).expect("app interface directory")
        .map(|entry| entry.expect("interface entry").path())
        .filter(|path| path.extension().and_then(|s| s.to_str()) == Some("json"))
        .collect();
    files.sort();
    let mut generated = String::from("&[\n");
    for file in files {
        let file = file.canonicalize().expect("interface source path");
        println!("cargo:rerun-if-changed={}", file.display());
        generated.push_str(&format!("    include_str!({:?}),\n", file));
    }
    generated.push_str("]\n");
    fs::write(PathBuf::from(env::var_os("OUT_DIR").unwrap()).join("app-interface-sources.rs"), generated)
        .expect("generated interface sources");
}
