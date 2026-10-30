fn main() {
    println!("cargo:rerun-if-changed=schema/archive.capnp");
    capnpc::CompilerCommand::new()
        .src_prefix("schema")
        .file("schema/archive.capnp")
        .run()
        .expect("compile wire-compatible SPK archive schema");
}
