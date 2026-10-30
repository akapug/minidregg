//! `minidregg-link-sqlite-store-fixtures`: the crash and hold fixtures as a
//! process, for the Lean probe `scripts/durable-receiver.lean`. Built only
//! with `--features fixtures`; never part of a candidate. The fixtures
//! themselves are the crate tests' (`tests/support`).
//!
//! The Lean side reaches a helper through its `serve` coprocess
//! (`Compiler.NativeCoprocess`), so this binary serves too: each request
//! frame runs as its own child (a fixture ends its process on purpose) and the
//! child's exit code, stdout and stderr come back in the helper's reply frame
//! (`MDCOPRC1`, big-endian, as the production helper's).
#[path = "../../tests/support/mod.rs"]
mod support;

use std::ffi::OsString;
use std::io::{Read, Write};
use std::os::unix::ffi::OsStringExt;
use std::os::unix::process::ExitStatusExt;

fn serve() -> std::process::ExitCode {
    let executable = std::env::current_exe().expect("own executable");
    let mut input = std::io::BufReader::new(std::io::stdin().lock());
    let mut output = std::io::BufWriter::new(std::io::stdout().lock());
    let mut word = [0u8; 4];
    loop {
        if input.read_exact(&mut word).is_err() {
            return std::process::ExitCode::SUCCESS;
        }
        let count = u32::from_be_bytes(word) as usize;
        let mut arguments = Vec::with_capacity(count);
        for _ in 0..count {
            input.read_exact(&mut word).expect("argument length");
            let mut bytes = vec![0u8; u32::from_be_bytes(word) as usize];
            input.read_exact(&mut bytes).expect("argument");
            arguments.push(OsString::from_vec(bytes));
        }
        let result = std::process::Command::new(&executable).args(&arguments).stdin(std::process::Stdio::null()).output().expect("fixture child");
        let code: u32 = match (result.status.code(), result.status.signal()) {
            (Some(code), _) => code as u32,
            (None, Some(signal)) => 128 + signal as u32,
            (None, None) => 255,
        };
        output.write_all(b"MDCOPRC1").unwrap();
        output.write_all(&code.to_be_bytes()).unwrap();
        output.write_all(&(result.stdout.len() as u64).to_be_bytes()).unwrap();
        output.write_all(&result.stdout).unwrap();
        output.write_all(&(result.stderr.len() as u64).to_be_bytes()).unwrap();
        output.write_all(&result.stderr).unwrap();
        output.flush().unwrap();
    }
}

fn main() -> std::process::ExitCode {
    let arguments: Vec<OsString> = std::env::args_os().skip(1).collect();
    if arguments.len() == 1 && arguments[0] == "serve" {
        return serve();
    }
    support::run_fixture(arguments)
}
