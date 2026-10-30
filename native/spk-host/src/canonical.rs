//! The canonical text forms spk-host reads and writes: decimal naturals and lowercase hex.
//!
//! One rule each, the Host's: a decimal is canonical when it is `toString n` for its value (digits
//! only, no sign, no leading zero, "0" itself allowed; Lean's `canonicalNat` checks exactly that),
//! and hex is lowercase, two digits per byte. The digit bound is the caller's: `DECIMAL_DIGITS`
//! is the Rust wire bound every JSON field uses unless the Lean reader it mirrors sets a tighter
//! one (`Host/Main.lean canonicalDecimal?` caps a `LifecycleSelector` field at `NAT256_DIGITS`).
//! A decoder answers `None`; its caller names the refusal.

/// The bound on a decimal JSON field spk-host accepts before any Lean reader sees it.
pub(crate) const DECIMAL_DIGITS: usize = 128;
/// The digits of 2^256 - 1, Lean's `canonicalDecimal?` bound.
pub(crate) const NAT256_DIGITS: usize = 78;

/// A canonical decimal of at most `max_digits` digits.
pub(crate) fn decimal_within(value: &str, max_digits: usize) -> bool {
    !value.is_empty()
        && value.len() <= max_digits
        && (value == "0" || !value.starts_with('0'))
        && value.bytes().all(|byte| byte.is_ascii_digit())
}

/// A canonical decimal within the wire bound.
pub(crate) fn decimal(value: &str) -> bool {
    decimal_within(value, DECIMAL_DIGITS)
}

/// A canonical decimal that fits a `u64`.
pub(crate) fn decimal_u64(value: &str) -> Option<u64> {
    if decimal_within(value, 20) { value.parse().ok() } else { None }
}

/// Lowercase hex, an even number of digits (whole bytes).
pub(crate) fn lower_hex(value: &str) -> bool {
    value.len().is_multiple_of(2)
        && value.bytes().all(|byte| byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte))
}

/// Lowercase hex of exactly `bytes` bytes.
pub(crate) fn lower_hex_of(value: &str, bytes: usize) -> bool {
    value.len() == bytes * 2 && lower_hex(value)
}

/// A SHA-256 digest (or any 32-byte value) in lowercase hex.
pub(crate) fn hex64(value: &str) -> bool {
    lower_hex_of(value, 32)
}

/// Lowercase hex of `bytes`.
pub(crate) fn hex(bytes: &[u8]) -> String {
    const DIGITS: &[u8; 16] = b"0123456789abcdef";
    let mut text = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        text.push(DIGITS[usize::from(byte >> 4)] as char);
        text.push(DIGITS[usize::from(byte & 15)] as char);
    }
    text
}

/// Whether `text` is exactly the canonical lowercase hex of `bytes`, without building that hex.
pub(crate) fn hex_matches(text: &str, bytes: &[u8]) -> bool {
    const DIGITS: &[u8; 16] = b"0123456789abcdef";
    text.len() == bytes.len() * 2
        && text.as_bytes().chunks_exact(2).zip(bytes).all(|(pair, byte)| {
            pair[0] == DIGITS[usize::from(byte >> 4)] && pair[1] == DIGITS[usize::from(byte & 15)]
        })
}

fn nibble(digit: u8) -> u8 {
    if digit.is_ascii_digit() { digit - b'0' } else { digit - b'a' + 10 }
}

/// The bytes of canonical lowercase hex, or `None`.
pub(crate) fn unhex(value: &str) -> Option<Vec<u8>> {
    if !lower_hex(value) {
        return None;
    }
    Some(value.as_bytes().as_chunks::<2>().0.iter().map(|[high, low]| nibble(*high) << 4 | nibble(*low)).collect())
}

/// Exactly `N` bytes of canonical lowercase hex, or `None`.
pub(crate) fn unhex_array<const N: usize>(value: &str) -> Option<[u8; N]> {
    unhex(value)?.try_into().ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decimal_is_the_hosts_canonical_form_within_its_bound() {
        for good in ["0", "1", "10", "18446744073709551615"] {
            assert!(decimal(good), "{good}");
        }
        for bad in ["", "00", "01", "-1", "+1", "1.0", " 1", "1 ", "١"] {
            assert!(!decimal(bad), "{bad:?}");
        }
        assert!(decimal(&"9".repeat(DECIMAL_DIGITS)));
        assert!(!decimal(&"9".repeat(DECIMAL_DIGITS + 1)));
        assert!(decimal_within(&"9".repeat(NAT256_DIGITS), NAT256_DIGITS));
        assert!(!decimal_within(&"9".repeat(NAT256_DIGITS + 1), NAT256_DIGITS));
        assert_eq!(decimal_u64("18446744073709551615"), Some(u64::MAX));
        assert_eq!(decimal_u64("18446744073709551616"), None);
        assert_eq!(decimal_u64("007"), None);
    }

    #[test]
    fn hex_round_trips_and_refuses_every_other_spelling() {
        let bytes: Vec<u8> = (0..=255).collect();
        let text = hex(&bytes);
        assert_eq!(text.len(), 512);
        assert!(lower_hex(&text) && !hex64(&text));
        assert_eq!(unhex(&text).unwrap(), bytes);
        assert!(hex_matches(&text, &bytes));
        assert!(!hex_matches(&text.to_uppercase(), &bytes));
        assert!(!hex_matches(&text[..510], &bytes));
        assert!(!hex_matches(&text, &bytes[..255]));
        assert_eq!(hex(&[0x0f, 0xa0]), "0fa0");
        for bad in ["0", "0A", "0g", "zz", " 00", "00\n"] {
            assert_eq!(unhex(bad), None, "{bad:?}");
        }
        let digest = "ab".repeat(32);
        assert!(hex64(&digest));
        assert_eq!(unhex_array::<32>(&digest), Some([0xab; 32]));
        assert_eq!(unhex_array::<31>(&digest), None);
        assert!(lower_hex_of(&"0".repeat(32), 16) && !lower_hex_of(&"0".repeat(32), 32));
    }
}
