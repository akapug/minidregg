//! mini-kernels: the Rust kernels the compiled Lean host calls through `@[extern]`.
//!
//! The Everest pattern (docs/HOT-PATH-2026-10-27.md §2d; SYNTHESIS §E.6): Lean keeps the
//! reference definition and every theorem is about it
//! (`Theory/Sp800185Cshake256Spec.lean` `cshake256Bytes`, `Compiler/Sp800185Kmac256.lean`
//! `kmac256Bytes`); this crate is the implementation that the compiled Host runs
//! (`Theory/Sp800185Cshake256Native.lean`, `@[extern "mini_cshake256_32"]` and
//! `@[extern "mini_kmac256_32"]`); the Lean-authored vectors (`testdata/lean-vectors.json`,
//! `tests/conformance.rs`) and the Lean conformance theorems, which evaluate the kernel at
//! every build once the dynlib is loaded, pin the equality.
//!
//! A kernel COMPUTES bytes and decides nothing (ATLAS §7: `rust/` authors nothing): no
//! framing of its own, no domain, no comparison, no admission. The Lean object marshalling
//! lives in `shim/mini_kernels_lean.c`, compiled against the toolchain's `lean.h`; this crate
//! never sees a `lean_object`.

use sha3::{
    digest::{ExtendableOutput, Update, XofReader},
    CShake256, CShake256Core,
};

/// The Keccak-f[1600] rate of cSHAKE256/KMAC256 in bytes (`rateBytes` in the Lean spec).
pub const RATE_BYTES: usize = 136;
/// Every kernel here squeezes exactly 32 bytes (`outputBytes` in the Lean spec).
pub const OUTPUT_BYTES: usize = 32;

/// cSHAKE256 with an EMPTY function name and a 32-byte output: `cshake256Bytes` in
/// `Theory/Sp800185Cshake256Spec.lean`. An empty customization is SHAKE256 (the `0x1f`
/// suffix), as in the spec's `cshake256Bytes` and in SP 800-185 §3.3.
pub fn cshake256_32(customization: &[u8], input: &[u8]) -> [u8; OUTPUT_BYTES] {
    let core = CShake256Core::new(customization);
    let mut hasher = CShake256::from_core(core);
    hasher.update(input);
    let mut reader = hasher.finalize_xof();
    let mut output = [0u8; OUTPUT_BYTES];
    reader.read(&mut output);
    output
}

/// SP 800-185 `left_encode`: the minimal big-endian bytes of `value`, preceded by their count.
fn left_encode(value: usize) -> Vec<u8> {
    let bytes = minimal_be(value);
    let mut out = Vec::with_capacity(bytes.len() + 1);
    out.push(bytes.len() as u8);
    out.extend_from_slice(&bytes);
    out
}

/// SP 800-185 `right_encode`: the minimal big-endian bytes of `value`, followed by their count.
fn right_encode(value: usize) -> Vec<u8> {
    let mut bytes = minimal_be(value);
    bytes.push(bytes.len() as u8);
    bytes
}

/// The minimal big-endian bytes of `value`; `0` is the one byte `00` (`natBytesBE` in Lean).
fn minimal_be(value: usize) -> Vec<u8> {
    let mut bytes: Vec<u8> = value.to_be_bytes().to_vec();
    while bytes.len() > 1 && bytes[0] == 0 {
        bytes.remove(0);
    }
    bytes
}

/// SP 800-185 `encode_string`: `left_encode(bit length) || bytes` (`encodeString` in Lean).
fn encode_string(bytes: &[u8]) -> Vec<u8> {
    let mut out = left_encode(bytes.len() * 8);
    out.extend_from_slice(bytes);
    out
}

/// SP 800-185 `bytepad(X, w)`: `left_encode(w) || X`, zero-padded to a multiple of `w`
/// (`bytepad` in Lean).
fn bytepad(bytes: &[u8], width: usize) -> Vec<u8> {
    let mut out = left_encode(width);
    out.extend_from_slice(bytes);
    while out.len() % width != 0 {
        out.push(0);
    }
    out
}

/// KMAC256 with a 32-byte tag: `kmac256Bytes` in `Compiler/Sp800185Kmac256.lean`,
/// `cSHAKE256(bytepad(encode_string(K), 136) || X || right_encode(256), 256, "KMAC", S)`.
pub fn kmac256_32(key: &[u8], customization: &[u8], input: &[u8]) -> [u8; OUTPUT_BYTES] {
    let core = CShake256Core::new_with_function_name(b"KMAC", customization);
    let mut hasher = CShake256::from_core(core);
    hasher.update(&bytepad(&encode_string(key), RATE_BYTES));
    hasher.update(input);
    hasher.update(&right_encode(OUTPUT_BYTES * 8));
    let mut reader = hasher.finalize_xof();
    let mut output = [0u8; OUTPUT_BYTES];
    reader.read(&mut output);
    output
}

/// A byte slice from a (pointer, length) pair the C shim hands over; a null pointer with
/// length zero is the empty slice (Lean's empty `ByteArray` may hand one over).
///
/// # Safety
/// `ptr` must be valid for `len` bytes for the duration of the call, or `len` must be 0.
unsafe fn slice<'a>(ptr: *const u8, len: usize) -> &'a [u8] {
    if len == 0 {
        &[]
    } else {
        std::slice::from_raw_parts(ptr, len)
    }
}

/// C ABI: `cshake256_32` into the caller's 32-byte buffer.
///
/// # Safety
/// `customization`/`input` must be valid for their lengths (or the length 0); `output` must be
/// valid for 32 writable bytes.
#[no_mangle]
pub unsafe extern "C" fn mini_kernels_cshake256_32(
    customization: *const u8,
    customization_len: usize,
    input: *const u8,
    input_len: usize,
    output: *mut u8,
) {
    let digest = cshake256_32(slice(customization, customization_len), slice(input, input_len));
    std::ptr::copy_nonoverlapping(digest.as_ptr(), output, OUTPUT_BYTES);
}

/// C ABI: `kmac256_32` into the caller's 32-byte buffer.
///
/// # Safety
/// As `mini_kernels_cshake256_32`, with `key` valid for `key_len` bytes.
#[no_mangle]
pub unsafe extern "C" fn mini_kernels_kmac256_32(
    key: *const u8,
    key_len: usize,
    customization: *const u8,
    customization_len: usize,
    input: *const u8,
    input_len: usize,
    output: *mut u8,
) {
    let tag = kmac256_32(
        slice(key, key_len),
        slice(customization, customization_len),
        slice(input, input_len),
    );
    std::ptr::copy_nonoverlapping(tag.as_ptr(), output, OUTPUT_BYTES);
}

#[cfg(test)]
mod framing {
    use super::*;

    /// The Lean `@[simp]` facts in `Compiler/Sp800185Cshake256.lean`: `leftEncode 0 = [1, 0]`,
    /// `leftEncode 65536 = [3, 1, 0, 0]`, `encodeString [] = [1, 0]`, `bytepad [] 4 = [1, 4, 0, 0]`.
    #[test]
    fn framing_matches_the_lean_simp_facts() {
        assert_eq!(left_encode(0), vec![1, 0]);
        assert_eq!(left_encode(65536), vec![3, 1, 0, 0]);
        assert_eq!(encode_string(&[]), vec![1, 0]);
        assert_eq!(bytepad(&[], 4), vec![1, 4, 0, 0]);
        assert_eq!(right_encode(256), vec![1, 0, 2]);
    }
}
