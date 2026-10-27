//! Allocation receipt: physical one-use durability, NOT privateRecovery.
//! Decoding yields a CLAIM only. VerifiedAnchorReceipt has no public constructor;
//! it comes from actual protected-authority readback and immutable pool binding.
use crate::{
    codec::{bad, bytes, parse_request, request, Correlation, Generation, Journal, Purpose},
    consensus_wire::Cursor,
    custody::{self, Pool},
};
use std::{io::Result, path::Path};
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
pub struct VerifiedAnchorReceipt {
    claim: AllocationReceipt,
}
impl VerifiedAnchorReceipt {
    pub fn claim(&self) -> &AllocationReceipt {
        &self.claim
    }
}
pub fn verify_anchor_receipt(
    claim: AllocationReceipt,
    pool: &Pool,
    row: u64,
    g: &Generation,
    purpose: Purpose,
    exact_descriptor_bytes: &[u8],
    anchor: &Path,
    local: &Path,
) -> Result<VerifiedAnchorReceipt> {
    let id = Correlation {
        pool: pool.id.clone(),
        row: crate::codec::Nat::new(row),
    };
    if claim.request != request(&id, g, purpose)
        || claim.descriptor_bytes != exact_descriptor_bytes
        || claim.row_commitment != pool.row_commitment(row)?
    {
        return Err(bad(
            "allocation exact descriptor/row/generation/purpose binding",
        ));
    }
    let captured = Journal::decode(&claim.journal_bytes)?;
    if !captured.spent.contains(&id)
        || !captured
            .allocations
            .iter()
            .any(|a| a.id == id && a.generation == *g && a.purpose == purpose)
    {
        return Err(bad("allocation claim has no exact spent record"));
    }
    // Actual readback into durable local snapshot; expected captured journal is
    // checked against current protected anchor. No claim-self-anchor shortcut.
    let actual = custody::recover_snapshot(anchor, local)?;
    if !actual.extends(&captured)
        || !actual
            .allocations
            .iter()
            .any(|a| a.id == id && a.generation == *g && a.purpose == purpose)
    {
        return Err(bad("protected anchor does not retain exact receipt"));
    }
    let captured_original = original_prefix(&captured, &id, g, purpose)?;
    let actual_original = original_prefix(&actual, &id, g, purpose)?;
    if captured_original != actual_original {
        return Err(bad("anchor original allocation prefix mismatch"));
    }
    Ok(VerifiedAnchorReceipt { claim })
}
/// Bounded source projection. Historical full journal remains internal evidence;
/// a later suffix cannot increase this source event's funded receipt envelope.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SourceAllocationReceipt {
    pub request: Vec<u8>,
    pub descriptor_bytes: Vec<u8>,
    pub row_commitment: [u8; 32],
    pub original_prefix_digest: [u8; 32],
    pub original_prefix_count: u64,
}
impl SourceAllocationReceipt {
    pub fn encode(&self) -> Vec<u8> {
        let mut b = vec![];
        bytes(b"DREGG.PRIVATE.ALLOCATION.SOURCE\x01", &mut b);
        bytes(&self.request, &mut b);
        bytes(&self.descriptor_bytes, &mut b);
        bytes(&self.row_commitment, &mut b);
        bytes(&self.original_prefix_digest, &mut b);
        crate::codec::Nat::new(self.original_prefix_count).put(&mut b);
        b
    }
    pub fn planned_byte_bound(request_bytes: &[u8], descriptor_bytes: &[u8]) -> usize {
        let mut fixed = vec![];
        bytes(b"DREGG.PRIVATE.ALLOCATION.SOURCE\x01", &mut fixed);
        bytes(request_bytes, &mut fixed);
        bytes(descriptor_bytes, &mut fixed);
        fixed.len() + 34 + 34 + 10 // two32byte vectors, canonical Nat bounded to u64.
    }
}
fn original_prefix(
    journal: &Journal,
    id: &Correlation,
    g: &Generation,
    p: Purpose,
) -> Result<Journal> {
    let pos = journal
        .allocations
        .iter()
        .position(|a| a.id == *id && a.generation == *g && a.purpose == p)
        .ok_or_else(|| bad("original allocation prefix not retained"))?;
    if journal.allocations.len() != journal.spent.len() {
        return Err(bad("anchor prefix shape"));
    }
    Ok(Journal {
        spent: journal.spent[pos..].to_vec(),
        allocations: journal.allocations[pos..].to_vec(),
    })
}
impl VerifiedAnchorReceipt {
    pub fn source_projection(&self) -> Result<SourceAllocationReceipt> {
        let journal = Journal::decode(&self.claim.journal_bytes)?;
        let (id, g, p) = parse_request(&self.claim.request)?;
        let original = original_prefix(&journal, &id, &g, p)?;
        Ok(SourceAllocationReceipt {
            request: self.claim.request.clone(),
            descriptor_bytes: self.claim.descriptor_bytes.clone(),
            row_commitment: self.claim.row_commitment,
            original_prefix_digest: custody::hash(&original.encode()),
            original_prefix_count: u64::try_from(original.allocations.len())
                .map_err(|_| bad("anchor prefix count overflow"))?,
        })
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use crate::codec::Nat;
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
