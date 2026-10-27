//! Exact native JointBackendPartyCodec REQUEST adapter and the inner native
//! credential claims. The OUTCOME side is Lean `decodeOutcome`; restore a Rust
//! decoder only when a Host receiver exists.
//! These are untrusted claims. Canonical decoding and semantic byte matching
//! confer no current enrollment, source Applied, funding, WAL readback or Qualified.
use crate::{
    authenticated_ingress::{self, Envelope},
    codec::{bad, bytes, Generation, Nat, Reader},
};
use std::io::Result;
const REQUEST: &[u8] = b"DREGG.JOINT.PRIVATE.REQUEST\x01";
pub const MAX_REQUEST: usize = 262144;
/// Closed recipient-to-native205 IPC carries full certified retained history,
/// independently bounded from network203/mix frames. No implicit fragmentation.
pub const MAX_LOCAL_INNER: usize = crate::codec::MAX;
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RequestClaim {
    pub candidate_bytes: Vec<u8>,
    pub participant: Nat,
    pub full_generation_bytes: Vec<u8>,
    pub manifest_root: Nat,
    pub raw_carrier: Vec<u8>,
}
impl RequestClaim {
    pub fn encode(&self) -> Result<Vec<u8>> {
        let mut b = REQUEST.to_vec();
        bytes(&self.candidate_bytes, &mut b);
        self.participant.put(&mut b);
        bytes(&self.full_generation_bytes, &mut b);
        self.manifest_root.put(&mut b);
        bytes(&self.raw_carrier, &mut b);
        if b.len() > MAX_REQUEST {
            return Err(bad("native private request codec capacity"));
        }
        Ok(b)
    }
    pub fn decode(b: &[u8]) -> Result<Self> {
        if b.len() > MAX_REQUEST || !b.starts_with(REQUEST) {
            return Err(bad("native private request frame/capacity"));
        }
        let mut r = Reader::new(&b[REQUEST.len()..])?;
        let v = Self {
            candidate_bytes: r.bytes()?,
            participant: r.nat()?,
            full_generation_bytes: r.bytes()?,
            manifest_root: r.nat()?,
            raw_carrier: r.bytes()?,
        };
        r.finish()?;
        if v.encode()? != b {
            return Err(bad("native private request canonical"));
        }
        Ok(v)
    }
    /// Mechanical equality only: native receiver still selects actual source
    /// manifest/current grant and verifies its native request-header credential.
    pub fn protocol_binding(&self) -> Result<Envelope> {
        let wire = authenticated_ingress::public_ingress_gate(&self.raw_carrier)?;
        let envelope = Envelope::decode(&wire)?;
        let mut r = Reader::new(&self.full_generation_bytes)?;
        let generation = Generation::get(&mut r)?;
        r.finish()?;
        let mut canonical = vec![];
        generation.put(&mut canonical);
        if canonical != self.full_generation_bytes
            || generation != envelope.party.context.generation
        {
            return Err(bad("native outer/inner exact generation"));
        }
        Ok(envelope)
    }
}
/// Exact Host.JointBackendPartyInner request. This contains source claims and
/// a credential only. Decoding cannot produce a Checked or VerifiedPacket.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct InnerCredentialRequest {
    pub original_request_bytes: Vec<u8>,
    pub source_index: Nat,
    pub certificate_bytes: Vec<u8>,
    pub credential: Vec<u8>,
}
impl InnerCredentialRequest {
    pub fn encode(&self) -> Result<Vec<u8>> {
        let mut b = b"DREGG.JOINT.PRIVATE.INNER.REQUEST\x01".to_vec();
        bytes(&self.original_request_bytes, &mut b);
        self.source_index.put(&mut b);
        bytes(&self.certificate_bytes, &mut b);
        bytes(&self.credential, &mut b);
        if b.len() > MAX_LOCAL_INNER {
            return Err(bad("inner native request capacity"));
        }
        Ok(b)
    }
    pub fn decode(b: &[u8]) -> Result<Self> {
        const FRAME: &[u8] = b"DREGG.JOINT.PRIVATE.INNER.REQUEST\x01";
        if b.len() > MAX_LOCAL_INNER || !b.starts_with(FRAME) {
            return Err(bad("inner native request frame/capacity"));
        }
        let mut r = Reader::new(&b[FRAME.len()..])?;
        let out = Self {
            original_request_bytes: r.bytes()?,
            source_index: r.nat()?,
            certificate_bytes: r.bytes()?,
            credential: r.bytes()?,
        };
        r.finish()?;
        if out.encode()? != b {
            return Err(bad("inner native request canonical"));
        }
        Ok(out)
    }
    /// A recipient constructs the exact source request only after successful
    /// decryption of the source-retained ORIGINAL capsule. Actual native205
    /// verifies the original prefix/certificate/credential separately.
    pub fn from_opened(
        original: &RequestClaim,
        opened: &crate::recipient_seal::DecryptedEnvelope,
        source_index: Nat,
        certificate_bytes: Vec<u8>,
    ) -> Result<Self> {
        if original.raw_carrier != opened.original_sealed_bytes() {
            return Err(bad("inner credential cross original capsule"));
        }
        let mut generation = vec![];
        opened.inner().party.context.generation.put(&mut generation);
        if original.full_generation_bytes != generation {
            return Err(bad("inner credential cross generation"));
        }
        let out = Self {
            original_request_bytes: original.encode()?,
            source_index,
            certificate_bytes,
            credential: opened.inner().credential.clone(),
        };
        out.encode()?;
        Ok(out)
    }
}
/// Native INNER response claims. Only a deployment-pinned native channel
/// running the actual original-prefix verifier can confer credential authority.
/// This codec intentionally exports no Checked or VerifiedPacket constructor.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum InnerCredentialOutcome {
    Refused(Vec<u8>),
    CredentialCheckedClaim {
        source_index: Nat,
        party_bytes: Vec<u8>,
        sequence: u64,
        semantic_commitment: [u8; 64],
        enrollment_bytes: Vec<u8>,
        source_receipt_bytes: Vec<u8>,
    },
}
impl InnerCredentialOutcome {
    pub fn encode(&self) -> Result<Vec<u8>> {
        let mut b = b"DREGG.JOINT.PRIVATE.INNER.OUTCOME\x01".to_vec();
        match self {
            Self::Refused(reason) => {
                b.push(0);
                bytes(reason, &mut b);
            }
            Self::CredentialCheckedClaim {
                source_index,
                party_bytes,
                sequence,
                semantic_commitment,
                enrollment_bytes,
                source_receipt_bytes,
            } => {
                b.push(1);
                source_index.put(&mut b);
                bytes(party_bytes, &mut b);
                b.extend(sequence.to_le_bytes());
                b.extend(semantic_commitment);
                bytes(enrollment_bytes, &mut b);
                bytes(source_receipt_bytes, &mut b);
            }
        }
        if b.len() > MAX_LOCAL_INNER {
            return Err(bad("inner outcome capacity"));
        }
        Ok(b)
    }
    pub fn decode(b: &[u8]) -> Result<Self> {
        const FRAME: &[u8] = b"DREGG.JOINT.PRIVATE.INNER.OUTCOME\x01";
        if b.len() > MAX_LOCAL_INNER || !b.starts_with(FRAME) {
            return Err(bad("inner outcome frame/capacity"));
        }
        let mut c = crate::consensus_wire::Cursor::new(&b[FRAME.len()..])?;
        let out = match c.byte()? {
            0 => Self::Refused(c.bytes()?),
            1 => {
                let mut n = vec![];
                loop {
                    let x = c.byte()?;
                    n.push(x);
                    if x == 255 {
                        break;
                    }
                }
                let mut r = Reader::new(&n)?;
                let source_index = r.nat()?;
                r.finish()?;
                Self::CredentialCheckedClaim {
                    source_index,
                    party_bytes: c.bytes()?,
                    sequence: c.u64()?,
                    semantic_commitment: c.take(64)?.try_into().unwrap(),
                    enrollment_bytes: c.bytes()?,
                    source_receipt_bytes: c.bytes()?,
                }
            }
            _ => return Err(bad("inner outcome tag")),
        };
        c.finish()?;
        if out.encode()? != b {
            return Err(bad("inner outcome canonical"));
        }
        Ok(out)
    }
    /// Exact endpoint-opened public context equality only. Native channel
    /// custody, original source enrollment/receipt verification remain required.
    pub fn matches_opened(
        &self,
        request: &InnerCredentialRequest,
        opened: &crate::recipient_seal::DecryptedEnvelope,
    ) -> Result<bool> {
        match self {
            Self::Refused(_) => Ok(false),
            Self::CredentialCheckedClaim {
                source_index,
                party_bytes,
                sequence,
                semantic_commitment,
                enrollment_bytes,
                source_receipt_bytes,
            } => {
                if source_index != &request.source_index
                    || *party_bytes != opened.inner().party.encode()
                    || *sequence != opened.inner().sequence
                    || *semantic_commitment != opened.semantic_commitment()
                    || enrollment_bytes.is_empty()
                    || source_receipt_bytes.is_empty()
                {
                    return Err(bad("inner outcome cross original source context"));
                }
                Ok(true)
            }
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use crate::authenticated_ingress::{CommitteeParty, Context, Protocol};
    fn request() -> RequestClaim {
        let generation = Generation {
            invocation: Nat::from_be(&[255; 32]),
            command: vec![3, 4],
            attempt: Nat::new(7),
            generation: Nat::new(11),
            configuration: Nat::from_be(&[254; 32]),
        };
        let packet = Envelope {
            party: CommitteeParty {
                context: Context {
                    protocol: Protocol::AcssId,
                    generation: generation.clone(),
                    authority_epoch: Nat::new(14),
                    session: vec![6],
                    recipient: 3,
                    recipient_role: b"holder".to_vec(),
                },
                party: 1,
                subject: vec![2],
                key_epoch: Nat::new(19),
                key_binding: vec![4],
                credential_purpose: b"private-message".to_vec(),
            },
            sequence: 123,
            message: vec![3, 7],
            credential: vec![8, 9],
        };
        let mut g = vec![];
        generation.put(&mut g);
        RequestClaim {
            candidate_bytes: vec![2],
            participant: Nat::from_be(&[255; 32]),
            full_generation_bytes: g,
            manifest_root: Nat::from_be(&[253; 32]),
            raw_carrier: authenticated_ingress::carrier(&packet.encode().unwrap()).unwrap(),
        }
    }
    #[test]
    fn canonical_native_claim_codec_preserves_full_nats_and_rejects_suffixes() {
        let r = request();
        assert_eq!(RequestClaim::decode(&r.encode().unwrap()).unwrap(), r);
        let mut bytes = r.encode().unwrap();
        bytes.push(0);
        assert!(RequestClaim::decode(&bytes).is_err());
    }
    #[test]
    fn a_crossed_outer_generation_refuses_the_protocol_binding() {
        let r = request();
        let mut packet = r.protocol_binding().unwrap();
        packet.party.context.generation.attempt = Nat::new(8);
        let mut wrong = r.clone();
        wrong.raw_carrier = authenticated_ingress::carrier(&packet.encode().unwrap()).unwrap();
        assert!(wrong.protocol_binding().is_err());
    }
    #[test]
    fn inner_native_outcome_claim_refuses_crossed_context_and_never_grants_authority() {
        use crate::{
            crypto_transit,
            recipient_seal::{recipient_key_id, HidingDraft, RecipientSpec},
        };
        let old = request();
        let envelope = old.protocol_binding().unwrap();
        let keys = crypto_transit::generate_keypair().unwrap();
        let spec = RecipientSpec {
            algorithm: Nat::new(2),
            key_epoch: Nat::new(3),
            key_id: recipient_key_id(&keys.public),
            plaintext_bound: 4096,
        };
        let draft = HidingDraft::new(
            envelope.party.clone(),
            envelope.sequence,
            envelope.message.clone(),
            spec.clone(),
        )
        .unwrap();
        let sealed = draft.seal(vec![9; 32], &keys.public).unwrap();
        let opened = sealed
            .open(
                &keys.secret,
                &keys.public,
                &envelope.party,
                envelope.sequence,
                &spec,
            )
            .unwrap();
        let mut original = old;
        original.raw_carrier = sealed.encode().unwrap();
        let request = InnerCredentialRequest::from_opened(
            &original,
            &opened,
            Nat::from_be(&[255; 32]),
            vec![8; 32],
        )
        .unwrap();
        let claim = InnerCredentialOutcome::CredentialCheckedClaim {
            source_index: request.source_index.clone(),
            party_bytes: opened.inner().party.encode(),
            sequence: opened.inner().sequence,
            semantic_commitment: opened.semantic_commitment(),
            enrollment_bytes: vec![3],
            source_receipt_bytes: vec![4],
        };
        assert!(claim.matches_opened(&request, &opened).unwrap());
        assert_eq!(
            InnerCredentialOutcome::decode(&claim.encode().unwrap()).unwrap(),
            claim
        );
        for tag in 0..6 {
            let mut changed = claim.clone();
            let InnerCredentialOutcome::CredentialCheckedClaim {
                source_index,
                party_bytes,
                sequence,
                semantic_commitment,
                enrollment_bytes,
                source_receipt_bytes,
            } = &mut changed
            else {
                unreachable!()
            };
            match tag {
                0 => *source_index = Nat::new(0),
                1 => party_bytes.push(0),
                2 => *sequence += 1,
                3 => semantic_commitment[0] ^= 1,
                4 => enrollment_bytes.clear(),
                _ => source_receipt_bytes.clear(),
            }
            assert!(changed.matches_opened(&request, &opened).is_err());
        }
        let refusal = InnerCredentialOutcome::Refused(b"fixed original-prefix refusal".to_vec());
        assert!(!refusal.matches_opened(&request, &opened).unwrap());
        let mut trailing = claim.encode().unwrap();
        trailing.push(0);
        assert!(InnerCredentialOutcome::decode(&trailing).is_err());
    }
}
