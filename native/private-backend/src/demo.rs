//! The research-labelled in-process demonstration: the width-8 private adder run among four
//! holders in ONE process (holder 0 deals `left`, holder 2 deals `right`, holder 1 is the only
//! output recipient, holder 0 is the King, holder 3 is the curious one), and what the curious
//! holder saw. The executed path is the same one `private_view` checks: ACSS-Id + dZK + Sh2t-Id +
//! King + LayerEngine + private_output, driven through an in-memory queue. There is no transport,
//! no release admission and no service. Built only with the `demo` feature.
use crate::{entropy::Entropy, private_view::Dealt};
use std::collections::BTreeMap;

/// The label every output of the demonstration carries, verbatim (docs/review/2026-10-26-native-crates/private-backend.md R1).
pub const LABEL: &str = "single process, n = 4, static f = 1, no simulator, no GOD";
/// The first line of the output: the research word and the label.
pub fn banner() -> String {
    format!("RESEARCH DEMONSTRATION: {LABEL}")
}

/// `LEFT RIGHT`: two decimal 8-bit values.
pub fn parse_inputs(args: &[String]) -> Result<(u64, u64), String> {
    let [l, r] = args else {
        return Err("usage: mini-private-compute LEFT RIGHT (two values, each 0..=255)".into());
    };
    let one = |s: &str| -> Result<u64, String> {
        if s.is_empty() || s.len() > 3 || !s.bytes().all(|b| b.is_ascii_digit()) {
            return Err(format!("not a value 0..=255: {s:?}"));
        }
        let v: u64 = s.parse().map_err(|_| format!("not a value 0..=255: {s:?}"))?;
        if v > 255 {
            return Err(format!("not a value 0..=255: {s:?}"));
        }
        Ok(v)
    };
    Ok((one(l)?, one(r)?))
}

/// A pair with the same sum that differs from (`l`, `r`), if the sum has one.
pub fn alternate_pair(l: u64, r: u64) -> Option<(u64, u64)> {
    if l != r && r <= 255 {
        return Some((r, l));
    }
    let sum = l + r;
    (0..=255u64).find(|a| sum >= *a && sum - *a <= 255 && (*a, sum - *a) != (l, r)).map(|a| (a, sum - a))
}

/// Run the computation and render the report. Randomness is fresh from the OS.
pub fn render(left: u64, right: u64) -> Result<String, String> {
    let root = Entropy::os().map_err(|e| format!("entropy: {e}"))?;
    let dealt = Dealt::run(&root, left, right, 9100)?;
    let mut out = vec![banner()];
    out.push("inputs: two 8-bit values, dealt privately by holders 0 and 2; they are not printed below".into());
    out.push(format!("output: {} (decrypted by holder 1, the only output recipient)", dealt.a_result));
    if dealt.a_result != left + right {
        return Err("the recipient output is not the sum".into());
    }
    out.push("curious holder 3 followed the protocol and logged every message delivered to it".into());
    let phases = dealt.phases();
    out.push(format!("  frames delivered to holder 3: {} in {} phases", dealt.a_frames, phases.len()));
    for (phase, n) in &phases {
        out.push(format!("    {phase:24} {n}"));
    }
    out.push("  its own input shares: one point per input bit, below the reconstruction threshold f + 1 = 2".into());
    match alternate_pair(left, right) {
        None => out.push("witness: none (the sum has a single input pair)".into()),
        Some((l, r)) => {
            let counts = dealt.alternate((left, right), l, r)?;
            let (mut same, mut hidden) = (0, BTreeMap::<&str, usize>::new());
            for ((_, class), n) in &counts {
                if *class == "identical" {
                    same += n;
                } else {
                    *hidden.entry(class).or_default() += n;
                }
            }
            out.push("witness: the protocol re-run on a different input pair with the same sum (built by an equivocation witness, not a simulator), holder 3's two logs compared frame by frame".into());
            out.push(format!("  byte-identical frames: {same}"));
            for (class, n) in &hidden {
                out.push(format!("  differing frames, hidden by the random-oracle assumption: {n} ({class})"));
            }
            out.push("  differing frames outside those classes: 0".into());
            out.push("  king, layer-mpc and output frames: all byte-identical".into());
            out.push("  holder 3's own input shares: unchanged between the two runs".into());
        }
    }
    out.push("scope: any claim above is about holder 3's view only, apart from the hidden frames; it is not a simulator proof and says nothing about the King's view, a malicious party or a coalition".into());
    out.push("never deployed: no transport, no release admission, no service; one process, gone when it exits".into());
    Ok(out.join("\n") + "\n")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn inputs_are_two_bounded_decimals() {
        let args = |a: &[&str]| a.iter().map(|s| s.to_string()).collect::<Vec<_>>();
        assert_eq!(parse_inputs(&args(&["173", "59"])), Ok((173, 59)));
        for bad in [&["1"][..], &["1", "2", "3"], &["256", "1"], &["-1", "1"], &["1", ""], &["0x1", "2"], &["1e1", "2"], &["0001", "2"]] {
            assert!(parse_inputs(&args(bad)).is_err(), "{bad:?}");
        }
    }

    #[test]
    fn an_alternate_pair_keeps_the_sum_and_differs() {
        for (l, r) in [(173, 59), (7, 7), (0, 5), (255, 0), (1, 255), (255, 255), (0, 0)] {
            match alternate_pair(l, r) {
                Some((a, b)) => assert!(a + b == l + r && (a, b) != (l, r) && a <= 255 && b <= 255, "({l},{r}) -> ({a},{b})"),
                None => assert!(matches!(l + r, 0 | 510), "({l},{r}) has an alternate"),
            }
        }
    }

    /// One whole computation on a fixed input: the report opens with the research banner, carries
    /// the output, the curious holder's per-phase counts and the witness comparison, and names
    /// neither input value anywhere past the banner (counts and the output are not inputs).
    #[test]
    fn the_report_on_a_fixed_input_has_the_label_the_output_and_names_no_input() {
        let report = render(173, 59).unwrap();
        let mut lines = report.lines();
        assert_eq!(lines.next(), Some(banner().as_str()));
        assert!(report.contains("output: 232 "), "{report}");
        assert!(report.contains("frames delivered to holder 3:"), "{report}");
        assert!(report.contains("differing frames outside those classes: 0"), "{report}");
        assert!(report.contains("king, layer-mpc and output frames: all byte-identical"), "{report}");
        for token in report.split(|c: char| !c.is_ascii_alphanumeric()).filter(|t| !t.is_empty()) {
            assert!(token != "173" && token != "59", "an input value appears in the report: {token}\n{report}");
        }
    }
}
