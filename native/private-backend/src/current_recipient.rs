//! The Host's current-recipient readback, parsed into the one value custody
//! accepts as the source of its CURRENT epoch.
//!
//! `Host/CurrentRecipientVerifier.lean` (`inspect current-recipient`) writes
//! `DREGG.CURRENT.RECIPIENT.READBACK/v1` only after `Kernel.NativeCurrentMemberKeyIO.authenticate`
//! accepted the member's `Compiler.CurrentRecipientRecord` against the pinned
//! continuity point. The bytes are a CLAIM about that verdict, not a proof: the
//! caller must have obtained them from the pinned local inspect operation under
//! the client's custody lock (the Lean docs say the same). What this module adds
//! is exactness: every field the Lean side binds is re-checked against the
//! scope the operator pinned, so a readback for another member, room, domain or
//! semantics, or one whose record disagrees with its own selected key, is
//! refused by name. There is no other constructor.
use crate::codec::{bad, Nat, Reader};
use std::io::Result;

const READBACK_FRAME: &[u8] = b"DREGG.CURRENT.RECIPIENT.READBACK\x01";
const QUERY_FRAME: &[u8] = b"DREGG.CURRENT.RECIPIENT.QUERY\x01";
/// `Compiler.CurrentRecipientRecord.payload`: epoch(4) enc(32) room(8) keysCell(8) signing(32) sig(64).
pub const RECORD_BYTES: usize = 148;

/// The scope the operator pinned: what a readback must be about.
pub struct ReadbackScope {
    pub domain: Nat,
    pub semantics: Nat,
    pub member: Nat,
    pub room: u64,
    pub keys_cell: u64,
}

pub struct VerifiedCurrentRecipient {
    epoch: Nat,
    encryption_key: [u8; 32],
}
impl VerifiedCurrentRecipient {
    pub fn from_host_readback(readback: &[u8], scope: &ReadbackScope) -> Result<Self> {
        let rest = readback
            .strip_prefix(READBACK_FRAME)
            .ok_or_else(|| bad("current recipient readback frame"))?;
        let mut r = Reader::new(rest)?;
        let query = r.bytes()?;
        let domain = r.nat()?;
        let semantics = r.nat()?;
        let _key_id = r.nat()?;
        let key_epoch = r.nat()?;
        let public_key = r.bytes()?;
        r.finish()?;
        if domain != scope.domain || semantics != scope.semantics {
            return Err(bad("current recipient readback domain/semantics differ from the pinned scope"));
        }
        let query = query
            .strip_prefix(QUERY_FRAME)
            .ok_or_else(|| bad("current recipient query frame"))?;
        let mut q = Reader::new(query)?;
        let _height = q.nat()?;
        let _root = q.nat()?;
        let member = q.nat()?;
        let room = q.nat()?;
        let keys_cell = q.nat()?;
        let payload = q.bytes()?;
        q.finish()?;
        if member != scope.member
            || room != Nat::new(scope.room)
            || keys_cell != Nat::new(scope.keys_cell)
        {
            return Err(bad("current recipient readback member/room/keys cell differ from the pinned scope"));
        }
        if payload.len() != RECORD_BYTES {
            return Err(bad("current recipient record is not the 148-byte Suite1 record"));
        }
        let be = |b: &[u8]| b.iter().fold(0u64, |n, x| n * 256 + *x as u64);
        let epoch = Nat::new(be(&payload[0..4]));
        if be(&payload[36..44]) != scope.room || be(&payload[44..52]) != scope.keys_cell {
            return Err(bad("current recipient record scope differs from its query"));
        }
        if key_epoch != epoch || public_key != payload[52..84] {
            return Err(bad("current recipient record disagrees with the selected signing key"));
        }
        Ok(Self {
            epoch,
            encryption_key: payload[4..36].try_into().unwrap(),
        })
    }
    pub fn epoch(&self) -> &Nat {
        &self.epoch
    }
    /// The record's 32-byte X25519 encryption key.
    pub fn encryption_key(&self) -> &[u8; 32] {
        &self.encryption_key
    }
}

/// Test-only author of a readback in the exact Lean wire shape.
#[cfg(test)]
pub(crate) mod fixture {
    use super::*;
    use crate::codec::bytes;
    pub fn scope() -> ReadbackScope {
        ReadbackScope {
            domain: Nat::new(31),
            semantics: Nat::new(32),
            member: Nat::new(5),
            room: 11,
            keys_cell: 12,
        }
    }
    pub fn readback(scope: &ReadbackScope, epoch: u32, encryption_key: &[u8; 32], signing: &[u8; 32]) -> Vec<u8> {
        let mut payload = epoch.to_be_bytes().to_vec();
        payload.extend(encryption_key);
        payload.extend(scope.room.to_be_bytes());
        payload.extend(scope.keys_cell.to_be_bytes());
        payload.extend(signing);
        payload.extend([0u8; 64]);
        let mut query = QUERY_FRAME.to_vec();
        Nat::new(3).put(&mut query);
        Nat::new(77).put(&mut query);
        scope.member.put(&mut query);
        Nat::new(scope.room).put(&mut query);
        Nat::new(scope.keys_cell).put(&mut query);
        bytes(&payload, &mut query);
        let mut out = READBACK_FRAME.to_vec();
        bytes(&query, &mut out);
        scope.domain.put(&mut out);
        scope.semantics.put(&mut out);
        Nat::new(9).put(&mut out);
        Nat::new(epoch as u64).put(&mut out);
        bytes(signing, &mut out);
        out
    }
    /// Verified record for `public`'s X25519 half at `epoch`.
    pub fn verified(epoch: u32, public: &[u8]) -> VerifiedCurrentRecipient {
        let s = scope();
        let enc: [u8; 32] = public[..32].try_into().unwrap();
        VerifiedCurrentRecipient::from_host_readback(&readback(&s, epoch, &enc, &[4; 32]), &s).unwrap()
    }
}

#[cfg(test)]
mod tests {
    use super::fixture::*;
    use super::*;
    fn refused(b: &[u8], scope: &ReadbackScope) -> String {
        VerifiedCurrentRecipient::from_host_readback(b, scope).err().unwrap().to_string()
    }
    #[test]
    fn readback_parses_exactly_and_refuses_each_scope_or_record_disagreement_by_name() {
        let s = scope();
        let good = readback(&s, 258, &[7; 32], &[4; 32]);
        let v = VerifiedCurrentRecipient::from_host_readback(&good, &s).unwrap();
        assert_eq!(v.epoch(), &Nat::new(258));
        assert_eq!(v.encryption_key(), &[7; 32]);
        let mut other = scope();
        other.member = Nat::new(6);
        assert!(refused(&good, &other).contains("member/room/keys cell"));
        let mut other = scope();
        other.domain = Nat::new(1);
        assert!(refused(&good, &other).contains("domain/semantics"));
        let mut other = scope();
        other.room = 99;
        assert!(refused(&good, &other).contains("member/room/keys cell"));
        // The record's own epoch must be the selected key's epoch.
        let wrong_epoch = {
            let mut r = readback(&s, 258, &[7; 32], &[4; 32]);
            // replace the selected-key epoch Nat(258) with Nat(259)
            let mut want = vec![];
            Nat::new(258).put(&mut want);
            let mut with = vec![];
            Nat::new(259).put(&mut with);
            let pos = r.windows(want.len()).rposition(|w| w == want.as_slice()).unwrap();
            r.splice(pos..pos + want.len(), with);
            r
        };
        assert!(refused(&wrong_epoch, &s).contains("disagrees with the selected signing key"));
        // The selected signing key must be the record's signing key.
        let mut key = readback(&s, 258, &[7; 32], &[4; 32]);
        *key.last_mut().unwrap() ^= 1;
        assert!(refused(&key, &s).contains("disagrees with the selected signing key"));
        let short = &good[..good.len() - 1];
        assert!(VerifiedCurrentRecipient::from_host_readback(short, &s).is_err());
        let mut trailing = good.clone();
        trailing.push(0);
        assert!(VerifiedCurrentRecipient::from_host_readback(&trailing, &s).is_err());
        assert!(refused(b"DREGG.CURRENT.RECIPIENT.QUERY\x01", &s).contains("readback frame"));
    }
}
