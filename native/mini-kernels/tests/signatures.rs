//! Signature-kernel vectors retained from native/credential-signature-verifier.
//! The private seeds and published SSHSIG vector are public deterministic test data.
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use mini_kernels::{
    mini_kernels_ed25519_verify, mini_kernels_sshsig_verify, verify_ed25519, verify_sshsig,
};
use sha2::{Digest, Sha512};

fn hex(value: &str) -> Vec<u8> {
    assert_eq!(value.len() % 2, 0);
    value
        .as_bytes()
        .chunks_exact(2)
        .map(|pair| u8::from_str_radix(std::str::from_utf8(pair).unwrap(), 16).unwrap())
        .collect()
}

fn malformed_point() -> [u8; 32] {
    (0..=u8::MAX)
        .map(|byte| [byte; 32])
        .find(|bytes| VerifyingKey::from_bytes(bytes).is_err())
        .expect("a repeated-byte point fixture must fail decompression")
}

#[test]
fn signature_rfc8032_vectors_verify() {
    // RFC 8032 section 7.1, TEST 1 and TEST 2.
    let vectors = [
        (
            "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
            "",
            concat!(
                "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155",
                "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
            ),
        ),
        (
            "3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c",
            "72",
            concat!(
                "92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da",
                "085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00"
            ),
        ),
    ];
    for (key, frame, signature) in vectors {
        assert_eq!(
            verify_ed25519(&hex(key), &hex(frame), &hex(signature)),
            Ok(true)
        );
    }
}

#[test]
fn signature_opaque_frames_and_all_signed_inputs_are_checked() {
    let frame = b"\x00\xffLean frame\r\n\x80\x00";
    let signing = SigningKey::from_bytes(&[41; 32]);
    let key = signing.verifying_key().to_bytes();
    let signature = signing.sign(frame).to_bytes();
    assert_eq!(verify_ed25519(&key, frame, &signature), Ok(true));

    let mut modified_frame = frame.to_vec();
    modified_frame[0] ^= 1;
    assert_eq!(verify_ed25519(&key, &modified_frame, &signature), Ok(false));
    let mut modified_signature = signature.clone();
    modified_signature[32] ^= 1;
    assert_eq!(verify_ed25519(&key, frame, &modified_signature), Ok(false));
    let other = SigningKey::from_bytes(&[42; 32]).verifying_key();
    assert_eq!(
        verify_ed25519(&other.to_bytes(), frame, &signature),
        Ok(false)
    );
}

#[test]
fn signature_strict_verification_rejects_weak_key_forgery() {
    let mut identity = [0; 32];
    identity[0] = 1;
    let mut signature = [0; 64];
    signature[..32].copy_from_slice(&identity);
    let frame = b"the ordinary verifier accepts this universal weak-key forgery";
    let weak = VerifyingKey::from_bytes(&identity).unwrap();
    assert!(weak.is_weak());
    assert!(weak
        .verify(frame, &Signature::from_bytes(&signature))
        .is_ok());
    assert_eq!(verify_ed25519(&identity, frame, &signature), Ok(false));
}

#[test]
fn signature_malformed_inputs_are_errors_not_negative_verdicts() {
    let signing = SigningKey::from_bytes(&[41; 32]);
    let frame = b"exact input framing";
    let key = signing.verifying_key().to_bytes();
    let signature = signing.sign(frame).to_bytes();
    for length in [0, 1, 31, 33, 1024] {
        assert!(verify_ed25519(&vec![0; length], frame, &signature).is_err());
    }
    for length in [0, 1, 63, 65, 1024] {
        assert!(verify_ed25519(&key, frame, &vec![0; length]).is_err());
    }
    assert!(verify_ed25519(&malformed_point(), frame, &signature).is_err());
    assert!(verify_sshsig(&key, b"", frame, &signature).is_err());
}

// Real ssh-keygen SSHSIG vector from native/credential-signature-verifier/tests/sshsig.rs.
const SSHSIG_KEY: &str = "6d3bb2cc3f9d5432129e1f6e8eb1d0379fb6d1f909db26b94236f3f9dcfd490a";
const MINT: &str = "8525966c00f39ff54ef5e537a4736af436494d1f1681c659bd98e37ac28beff1";
const ENROL_ADDRESS: &str = "16946aa663362d557dd21ee08e8da60c2ea8a73467713c7c5205991e36634af5";
const MINI_KEY: &str = "197f6b23e16c8532c6abc838facd5ea789be0c76b2920334039bfa8b3d368d61";
const SSHSIG_RAW: &str = "e3024a122f7f20335c168b22d428617cbcfb4dc6d0b68f26dae8e2c2038641fd40d672e739b8a1d1a681f6d8488f46046985570f0ee30db01ae361309ff21f09";
const NAMESPACE: &[u8] = b"dregg-enrol@v1";

fn sshsig_message() -> Vec<u8> {
    [hex(MINT), hex(ENROL_ADDRESS), hex(MINI_KEY)].concat()
}

#[test]
fn signature_sshsig_real_vector_and_tampering() {
    let key = hex(SSHSIG_KEY);
    let message = sshsig_message();
    let signature = hex(SSHSIG_RAW);

    // Independently rebuild PROTOCOL.sshsig's signed bytes, as the original vector test does.
    let mut signed = b"SSHSIG".to_vec();
    for field in [
        NAMESPACE,
        b"".as_slice(),
        b"sha512".as_slice(),
        &Sha512::digest(&message),
    ] {
        signed.extend_from_slice(&(field.len() as u32).to_be_bytes());
        signed.extend_from_slice(field);
    }
    VerifyingKey::from_bytes(&key.clone().try_into().unwrap())
        .unwrap()
        .verify_strict(
            &signed,
            &Signature::from_bytes(&signature.clone().try_into().unwrap()),
        )
        .unwrap();

    assert_eq!(
        verify_sshsig(&key, NAMESPACE, &message, &signature),
        Ok(true)
    );
    let mut other_message = message.clone();
    other_message[95] ^= 1;
    assert_eq!(
        verify_sshsig(&key, NAMESPACE, &other_message, &signature),
        Ok(false)
    );
    assert_eq!(
        verify_sshsig(&key, b"dregg-enrol", &message, &signature),
        Ok(false)
    );
    let mut other_signature = signature.clone();
    other_signature[0] ^= 1;
    assert_eq!(
        verify_sshsig(&key, NAMESPACE, &message, &other_signature),
        Ok(false)
    );
    assert_eq!(
        verify_sshsig(&hex(MINI_KEY), NAMESPACE, &message, &signature),
        Ok(false)
    );
}

#[test]
fn signature_ffi_uses_the_lean_verdict_codes() {
    let signing = SigningKey::from_bytes(&[41; 32]);
    let key = signing.verifying_key().to_bytes();
    let frame = b"borrowed Lean byte arrays";
    let signature = signing.sign(frame).to_bytes();
    let plain = |key: &[u8], signature: &[u8]| unsafe {
        mini_kernels_ed25519_verify(
            key.as_ptr(),
            key.len(),
            frame.as_ptr(),
            frame.len(),
            signature.as_ptr(),
            signature.len(),
        )
    };
    assert_eq!(plain(&key, &signature), 0);
    assert_eq!(plain(&key, &[0; 64]), 1);
    assert_eq!(plain(&key[..31], &signature), 2);

    let sshsig_key = hex(SSHSIG_KEY);
    let message = sshsig_message();
    let sshsig_signature = hex(SSHSIG_RAW);
    let sshsig = |namespace: &[u8]| unsafe {
        mini_kernels_sshsig_verify(
            sshsig_key.as_ptr(),
            sshsig_key.len(),
            namespace.as_ptr(),
            namespace.len(),
            message.as_ptr(),
            message.len(),
            sshsig_signature.as_ptr(),
            sshsig_signature.len(),
        )
    };
    assert_eq!(sshsig(NAMESPACE), 0);
    assert_eq!(sshsig(b"dregg-enrol"), 1);
    assert_eq!(sshsig(b""), 2);
}
