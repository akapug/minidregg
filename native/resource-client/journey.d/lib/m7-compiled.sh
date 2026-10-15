# The compiled inputs of a packed candidate (Lean sources, lake/lean pins, every Rust crate's manifest,
# sources and build scripts, rust-toolchain.toml, the native builders): the lines of DIR/logs/source-files.sha256
# that M7 (journey.d/m7.sh) requires identical between a candidate and its reproduction reference.
# One definition: m7.sh reads it, and scripts/pipeline/journey-runner reads it to pick a reference set.
m7_compiled_inputs() {  # CANDIDATE_DIR -> its compiled-input lines on stdout
  grep -E '^[0-9a-f]{64}  \./(.*\.lean|Cargo\.(toml|lock)|\.cargo/.*|lakefile\.toml|lake-manifest\.json|lean-toolchain|rust-toolchain\.toml|native/.*|protocol/.*|scripts/build-native-host\.sh|deploy/candidate/(build|lane-build|lib)\.sh)$' "$1/logs/source-files.sha256"
}
