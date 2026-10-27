//! Allocation receipt: physical one-use durability, NOT privateRecovery.
//! Decoding yields a CLAIM only. VerifiedAnchorReceipt has no public constructor;
//! it comes from actual protected-authority readback and immutable pool binding.
use crate::{
    codec::{bad, bytes, parse_request, Journal},
    consensus_wire::Cursor,
};
use std::io::Result;
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AllocationReceipt {
    pub request: Vec<u8>,
    pub descriptor_bytes: Vec<u8>,
    pub journal_bytes: Vec<u8>,
    pub row_commitment: [u8; 32],
}
impl AllocationReceipt {
    pub fn encode(&self) -> Vec<u8> {
        let mut b = vec![];
        bytes(b"DREGG.PRIVATE.ALLOCATION\x01", &mut b);
        bytes(&self.request, &mut b);
        bytes(&self.descriptor_bytes, &mut b);
        bytes(&self.journal_bytes, &mut b);
        bytes(&self.row_commitment, &mut b);
        b
    }
    pub fn decode(b: &[u8]) -> Result<Self> {
        let mut c = Cursor::new(b)?;
        if c.bytes()? != b"DREGG.PRIVATE.ALLOCATION\x01" {
            return Err(bad("allocation receipt version"));
        }
        let request = c.bytes()?;
        parse_request(&request)?;
        let descriptor_bytes = c.bytes()?;
        let journal_bytes = c.bytes()?;
        Journal::decode(&journal_bytes)?;
        let row_commitment = c
            .bytes()?
            .try_into()
            .map_err(|_| bad("allocation row commitment length"))?;
        c.finish()?;
        let r = Self {
            request,
            descriptor_bytes,
            journal_bytes,
            row_commitment,
        };
        if r.descriptor_bytes.is_empty() || r.encode() != b {
            return Err(bad("noncanonical allocation claim"));
        }
        Ok(r)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use crate::codec::{request, Correlation, Generation, Nat, Purpose};
    fn g() -> Generation {
        Generation {
            invocation: Nat::from_be(&[255; 32]),
            command: vec![9],
            attempt: Nat::new(0),
            generation: Nat::new(1),
            configuration: Nat::new(7),
        }
    }
    #[test]
    fn decoded_claim_is_not_verified_and_codec_preserves_large_digests() {
        let id = Correlation {
            pool: Nat::from_be(&[254; 32]),
            row: Nat::new(254),
        };
        let g = g();
        let journal = Journal::default()
            .reserve(id.clone(), g.clone(), Purpose::HolderPad)
            .unwrap();
        let r = AllocationReceipt {
            request: request(&id, &g, Purpose::HolderPad),
            descriptor_bytes: vec![9, 8, 7],
            journal_bytes: journal.encode(),
            row_commitment: [6; 32],
        };
        assert_eq!(AllocationReceipt::decode(&r.encode()).unwrap(), r);
        let mut bad = r.encode();
        bad.push(0);
        assert!(AllocationReceipt::decode(&bad).is_err());
        // Only claim parsing is exercised here: no disk authority/native Qualified.
    }
}
