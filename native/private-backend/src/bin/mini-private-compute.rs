//! `mini-private-compute LEFT RIGHT`: the research-labelled in-process four-party demonstration.
//! Owns its process: the protocol fixtures write their crash logs and anchor sockets under the
//! temp directory, so this binary points it at one private scratch directory and removes it.
use mini_private_backend::demo;
use std::{os::unix::fs::PermissionsExt, path::PathBuf, process::ExitCode};

fn scratch() -> std::io::Result<PathBuf> {
    // Unix socket paths are short (104 bytes on macOS): fall back to /tmp when TMPDIR is long.
    let base = std::env::temp_dir();
    let base = if base.as_os_str().len() > 32 { PathBuf::from("/tmp") } else { base };
    let dir = base.join(format!("mini-pc-{}", std::process::id()));
    std::fs::create_dir(&dir)?;
    std::fs::set_permissions(&dir, std::fs::Permissions::from_mode(0o700))?;
    Ok(dir)
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let (left, right) = match demo::parse_inputs(&args) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("{}\nmini-private-compute: REFUSED {e}", demo::banner());
            return ExitCode::from(2);
        }
    };
    let dir = match scratch() {
        Ok(d) => d,
        Err(e) => {
            eprintln!("mini-private-compute: REFUSED scratch directory: {e}");
            return ExitCode::from(1);
        }
    };
    // Single-threaded here: nothing else reads the environment yet.
    std::env::set_var("TMPDIR", &dir);
    let ran = std::panic::catch_unwind(|| demo::render(left, right));
    let removed = std::fs::remove_dir_all(&dir);
    if let Err(e) = removed {
        eprintln!("mini-private-compute: could not remove {}: {e}", dir.display());
    }
    match ran {
        Ok(Ok(text)) => {
            print!("{text}");
            ExitCode::SUCCESS
        }
        Ok(Err(e)) => {
            eprintln!("{}\nmini-private-compute: REFUSED {e}", demo::banner());
            ExitCode::from(1)
        }
        Err(_) => {
            eprintln!("mini-private-compute: the computation failed an internal check");
            ExitCode::from(1)
        }
    }
}
