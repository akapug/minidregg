//! `mini private-compute --left L --right R` (shell: `private-compute L R`): the research-labelled
//! in-process four-party MPC demonstration (docs/review/2026-10-26-native-crates/private-backend.md
//! R1; owner ruling 2026-10-27: "the in-process four-party MPC as a research-labelled door").
//!
//! A LOCAL computation, never an admission: it asks no Host, signs nothing, opens no socket and
//! writes nothing to the workspace. The protocol runs in the `mini-private-compute` binary built
//! from `native/private-backend` (feature `demo`); `mini` runs it as a child process and prints
//! its report. The protocol crate is not linked into `mini` on purpose: the executed path is
//! 26K lines of research code and its test fixtures, and the child owns the process-wide scratch
//! directory (TMPDIR) the fixtures write their crash logs and anchor sockets under.
//!
//! The binary is found next to this executable, or at `MINI_PRIVATE_COMPUTE_BIN`. Its first
//! output line must be exactly [`BANNER`]: a build whose label drifted from this one is refused,
//! so the word "research" and the label cannot be lost between the protocol and the page.
use crate::*;
use std::io::Read;
use std::process::Stdio;

/// The label, verbatim from the review's R1 row.
pub(crate) const LABEL: &str = "single process, n = 4, static f = 1, no simulator, no GOD";
/// The first line of every report.
pub(crate) const BANNER: &str = "RESEARCH DEMONSTRATION: single process, n = 4, static f = 1, no simulator, no GOD";
const BIN: &str = "mini-private-compute";
/// A computation takes about 15 s on a laptop; the page's own deadline is 100 s.
const DEADLINE: std::time::Duration = std::time::Duration::from_secs(90);
const MAX_REPORT: usize = 16 * 1024;

/// One 8-bit value, as the decimal digits the grammar already checked.
pub(crate) fn value(name: &str, text: &str) -> Result<u8> {
    if text.is_empty() || text.len() > 3 || !text.bytes().all(|b| b.is_ascii_digit()) {
        return Err(format!("{name} must be a decimal value 0..=255"));
    }
    text.parse::<u8>().map_err(|_| format!("{name} must be a decimal value 0..=255"))
}

fn binary() -> Result<PathBuf> {
    if let Some(explicit) = env::var_os("MINI_PRIVATE_COMPUTE_BIN") {
        return Ok(PathBuf::from(explicit));
    }
    let exe = env::current_exe().map_err(|e| format!("private-compute: cannot find this executable: {e}"))?;
    Ok(exe.with_file_name(BIN))
}

/// Check a report: it opens with the banner, is bounded, and is text.
pub(crate) fn accept(report: &str) -> Result<()> {
    if report.lines().next() != Some(BANNER) {
        return Err(format!("private-compute: the {BIN} report does not open with the research banner {BANNER:?}; refused"));
    }
    Ok(())
}

pub(crate) fn run(mut args: Args) -> Result<()> {
    let left = value("--left", &args.required("left")?.to_string_lossy())?;
    let right = value("--right", &args.required("right")?.to_string_lossy())?;
    args.finish()?;
    let bin = binary()?;
    let mut child = Command::new(&bin)
        .args([left.to_string(), right.to_string()])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("private-compute: cannot run {}: {e} (build it: cargo build --release --features demo --bin {BIN} in native/private-backend)", bin.display()))?;
    let mut out = child.stdout.take().ok_or("private-compute: no stdout")?;
    let mut err = child.stderr.take().ok_or("private-compute: no stderr")?;
    let reader = std::thread::spawn(move || {
        let mut text = Vec::new();
        let _ = (&mut out).take(MAX_REPORT as u64 + 1).read_to_end(&mut text);
        text
    });
    let error_reader = std::thread::spawn(move || {
        let mut text = Vec::new();
        let _ = (&mut err).take(4096).read_to_end(&mut text);
        text
    });
    let started = std::time::Instant::now();
    let status = loop {
        match child.try_wait().map_err(|e| format!("private-compute: {e}"))? {
            Some(status) => break status,
            None if started.elapsed() < DEADLINE => std::thread::sleep(std::time::Duration::from_millis(25)),
            None => {
                // Our own child, by its handle: nothing else is ever signalled.
                let _ = child.kill();
                let _ = child.wait();
                return Err(format!("private-compute: the computation did not finish within {} s; stopped", DEADLINE.as_secs()));
            }
        }
    };
    let report = reader.join().unwrap_or_default();
    let diagnostics = error_reader.join().unwrap_or_default();
    if !status.success() {
        return Err(format!("private-compute: {}", String::from_utf8_lossy(&diagnostics).trim()));
    }
    if report.len() > MAX_REPORT {
        return Err("private-compute: the report exceeds its bound; refused".into());
    }
    let report = String::from_utf8(report).map_err(|_| "private-compute: the report is not text; refused".to_owned())?;
    accept(&report)?;
    print!("{report}");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_banner_is_the_research_word_and_the_label() {
        assert!(BANNER.starts_with("RESEARCH"));
        assert!(BANNER.ends_with(LABEL));
        assert_eq!(LABEL, "single process, n = 4, static f = 1, no simulator, no GOD");
    }

    #[test]
    fn values_are_bounded_decimals() {
        assert_eq!(value("--left", "255").unwrap(), 255);
        assert_eq!(value("--left", "0").unwrap(), 0);
        for bad in ["256", "-1", "1e2", "", "0x10", "1000", "+5", "١٢"] {
            assert!(value("--left", bad).is_err(), "{bad:?}");
        }
    }

    #[test]
    fn a_report_without_the_banner_is_refused() {
        let good = format!("{BANNER}\noutput: 232 (decrypted by holder 1, the only output recipient)\n");
        assert!(accept(&good).is_ok());
        // The planted fault of this lane: the label dropped from the first line.
        assert!(accept("RESEARCH DEMONSTRATION\noutput: 232\n").is_err());
        assert!(accept("output: 232\n").is_err());
        assert!(accept("").is_err());
    }
}
