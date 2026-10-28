//! Discover declarations, rather than keeping a second list of supported apps.
use std::{env, fs, path::PathBuf};

fn main() {
    let root = PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap()).join("../../apps/interfaces");
    println!("cargo:rerun-if-changed={}", root.display());
    let mut files: Vec<_> = if root.exists() {
        fs::read_dir(&root).expect("read app interfaces").map(|e| e.unwrap().path())
            .filter(|p| p.extension().is_some_and(|e| e == "json")).collect()
    } else { Vec::new() };
    files.sort();
    let mut source = String::from("&[\n");
    for file in files {
        println!("cargo:rerun-if-changed={}", file.display());
        source.push_str(&format!("include_str!({:?}),\n", file));
    }
    source.push_str("]");
    fs::write(PathBuf::from(env::var_os("OUT_DIR").unwrap()).join("app-interfaces.rs"), source).unwrap();
}
