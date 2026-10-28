//! Strict bounded canonical transport encoding. Sender identity comes only
//! from the authenticated channel, never from a payload's claimed broadcaster.
use crate::{
    acs,
    asks::{self, PhaseMessage},
    codec::{bad, bytes, Packet},
    gather, vaba,
};
use std::io::Result;
pub(crate) struct Cursor<'a> {
    b: &'a [u8],
    i: usize,
}
impl<'a> Cursor<'a> {
    pub fn new(b: &'a [u8]) -> Result<Self> {
        if b.len() > crate::codec::MAX {
            return Err(bad("wire capacity"));
        }
        Ok(Self { b, i: 0 })
    }
    pub fn take(&mut self, n: usize) -> Result<&'a [u8]> {
        let end = self.i.checked_add(n).ok_or_else(|| bad("wire length"))?;
        if end > self.b.len() {
            return Err(bad("short wire"));
        }
        let b = &self.b[self.i..end];
        self.i = end;
        Ok(b)
    }
    pub fn consumed(&self) -> usize {
        self.i
    }
    pub fn byte(&mut self) -> Result<u8> {
        Ok(self.take(1)?[0])
    }
    pub fn u16(&mut self) -> Result<u16> {
        Ok(u16::from_le_bytes(self.take(2)?.try_into().unwrap()))
    }
    pub fn u64(&mut self) -> Result<u64> {
        Ok(u64::from_le_bytes(self.take(8)?.try_into().unwrap()))
    }
    pub fn fixed32(&mut self) -> Result<[u8; 32]> {
        Ok(self.take(32)?.try_into().unwrap())
    }
    /// A canonical Nat: digits up to and including the 255 terminator.
    pub fn nat(&mut self) -> Result<crate::codec::Nat> {
        let start = self.i;
        while self.byte()? != 255 {}
        let mut r = crate::codec::Reader::new(&self.b[start..self.i])?;
        let n = r.nat()?;
        r.finish()?;
        Ok(n)
    }
    /// A canonical Nat read as a count, bounded by `codec::MAX`.
    pub fn count(&mut self) -> Result<usize> {
        let start = self.i;
        while self.byte()? != 255 {}
        let mut r = crate::codec::Reader::new(&self.b[start..self.i])?;
        let n = r.count()?;
        r.finish()?;
        Ok(n)
    }
    pub fn bytes(&mut self) -> Result<Vec<u8>> {
        let n = self.count()?;
        Ok(self.take(n)?.to_vec())
    }
    pub fn finish(self) -> Result<()> {
        if self.i != self.b.len() {
            return Err(bad("wire trailing bytes"));
        }
        Ok(())
    }
}
pub(crate) fn put_phase(p: &PhaseMessage, o: &mut Vec<u8>) {
    let (tag, v) = match p {
        PhaseMessage::Init(v) => (0, v),
        PhaseMessage::Echo(v) => (1, v),
        PhaseMessage::Ready(v) => (2, v),
    };
    o.push(tag);
    bytes(v, o);
}
pub(crate) fn get_phase(c: &mut Cursor) -> Result<PhaseMessage> {
    let t = c.byte()?;
    let b = c.bytes()?;
    match t {
        0 => Ok(PhaseMessage::Init(b)),
        1 => Ok(PhaseMessage::Echo(b)),
        2 => Ok(PhaseMessage::Ready(b)),
        _ => Err(bad("wire phase")),
    }
}
fn put_set(s: &vaba::Set, o: &mut Vec<u8>) {
    bytes(&acs::set_bytes(s), o)
}
fn set(c: &mut Cursor, n: usize) -> Result<vaba::Set> {
    acs::read_set(&c.bytes()?, n)
}
fn put_cover(m: &gather::Message, o: &mut Vec<u8>) {
    o.extend(m.context);
    match &m.body {
        gather::Body::Gather(g) => {
            o.push(0);
            match g {
                gather::IgBody::Inform(s) => {
                    o.push(0);
                    put_set(s, o)
                }
                gather::IgBody::Ack => o.push(1),
                gather::IgBody::Prepare(s) => {
                    o.push(2);
                    put_set(s, o)
                }
            }
        }
        gather::Body::Ra(j, p) => {
            o.push(1);
            o.extend(j.to_le_bytes());
            put_phase(p, o)
        }
        gather::Body::Withdraw => o.push(2),
    }
}
fn cover(c: &mut Cursor, n: usize) -> Result<gather::Message> {
    let context = c.fixed32()?;
    let body = match c.byte()? {
        0 => gather::Body::Gather(match c.byte()? {
            0 => gather::IgBody::Inform(set(c, n)?),
            1 => gather::IgBody::Ack,
            2 => gather::IgBody::Prepare(set(c, n)?),
            _ => return Err(bad("gather tag")),
        }),
        1 => gather::Body::Ra(c.u16()?, get_phase(c)?),
        2 => gather::Body::Withdraw,
        _ => return Err(bad("cover tag")),
    };
    Ok(gather::Message { context, body })
}
pub fn encode_vaba(m: &vaba::Message) -> Vec<u8> {
    let mut o = b"DREGG.VABA.WIRE\x01".to_vec();
    o.extend(m.context);
    o.extend(m.view.to_le_bytes());
    match &m.body {
        vaba::Body::Asks(j, p) => {
            o.push(0);
            o.extend(j.to_le_bytes());
            bytes(&asks::encode_message(p), &mut o)
        }
        vaba::Body::Pre(j, p) => {
            o.push(1);
            o.extend(j.to_le_bytes());
            put_phase(p, &mut o)
        }
        vaba::Body::Vote(j, p) => {
            o.push(2);
            o.extend(j.to_le_bytes());
            put_phase(p, &mut o)
        }
        vaba::Body::Cover(p) => {
            o.push(3);
            put_cover(p, &mut o)
        }
        vaba::Body::Final(p) => {
            o.push(4);
            put_phase(p, &mut o)
        }
    }
    o
}
pub fn decode_vaba(b: &[u8], n: usize) -> Result<vaba::Message> {
    let mut c = Cursor::new(b)?;
    let prefix = b"DREGG.VABA.WIRE\x01";
    if c.take(prefix.len())? != prefix {
        return Err(bad("VABA wire version"));
    }
    let context = c.fixed32()?;
    let view = c.u64()?;
    let body = match c.byte()? {
        0 => vaba::Body::Asks(c.u16()?, asks::decode_message(&c.bytes()?)?),
        1 => vaba::Body::Pre(c.u16()?, get_phase(&mut c)?),
        2 => vaba::Body::Vote(c.u16()?, get_phase(&mut c)?),
        3 => vaba::Body::Cover(cover(&mut c, n)?),
        4 => vaba::Body::Final(get_phase(&mut c)?),
        _ => return Err(bad("VABA body tag")),
    };
    c.finish()?;
    let m = vaba::Message {
        context,
        view,
        body,
    };
    if encode_vaba(&m) != b {
        return Err(bad("noncanonical VABA wire"));
    }
    Ok(m)
}
pub fn encode_acs(m: &acs::Message) -> Vec<u8> {
    let mut o = b"DREGG.ACS.WIRE\x01".to_vec();
    o.extend(m.context);
    match &m.body {
        acs::Body::Selector(j, p) => {
            o.push(0);
            o.extend(j.to_le_bytes());
            put_phase(p, &mut o)
        }
        acs::Body::Vaba(p) => {
            o.push(1);
            bytes(&encode_vaba(p), &mut o)
        }
    }
    o
}
pub fn decode_acs(b: &[u8], n: usize) -> Result<acs::Message> {
    let mut c = Cursor::new(b)?;
    let prefix = b"DREGG.ACS.WIRE\x01";
    if c.take(prefix.len())? != prefix {
        return Err(bad("ACS wire version"));
    }
    let context = c.fixed32()?;
    let body = match c.byte()? {
        0 => acs::Body::Selector(c.u16()?, get_phase(&mut c)?),
        1 => acs::Body::Vaba(decode_vaba(&c.bytes()?, n)?),
        _ => return Err(bad("ACS body tag")),
    };
    c.finish()?;
    let m = acs::Message { context, body };
    if encode_acs(&m) != b {
        return Err(bad("noncanonical ACS wire"));
    }
    Ok(m)
}
/// An outbox: Nat count, then per packet the u16 LE recipient and the
/// length-prefixed message wire.
pub(crate) fn put_outbox<M>(ps: &[Packet<M>], encode: impl Fn(&M) -> Vec<u8>) -> Vec<u8> {
    let mut o = vec![];
    crate::codec::Nat::new(ps.len() as u64).put(&mut o);
    for p in ps {
        o.extend(p.to.to_le_bytes());
        bytes(&encode(&p.message), &mut o)
    }
    o
}
/// Strict inverse of `put_outbox`: at most `bound` packets, recipients below
/// `n`, and the re-encoding must equal the input. `name` labels refusals.
pub(crate) fn get_outbox<M>(
    b: &[u8],
    n: usize,
    bound: usize,
    name: &str,
    decode: impl Fn(&[u8]) -> Result<M>,
    encode: impl Fn(&M) -> Vec<u8>,
) -> Result<Vec<Packet<M>>> {
    let mut c = Cursor::new(b)?;
    let count = c.count()?;
    if count > bound {
        return Err(bad(&format!("{name} outbox bound")));
    }
    let mut out = vec![];
    for _ in 0..count {
        let to = c.u16()?;
        if to as usize >= n {
            return Err(bad(&format!("{name} outbox recipient")));
        }
        out.push(Packet {
            to,
            message: decode(&c.bytes()?)?,
        });
    }
    c.finish()?;
    if put_outbox(&out, encode) != b {
        return Err(bad(&format!("{name} outbox canonical")));
    }
    Ok(out)
}
pub fn encode_outbox(ps: &[acs::Send]) -> Vec<u8> {
    put_outbox(ps, encode_acs)
}
pub fn decode_outbox(b: &[u8], n: usize) -> Result<Vec<acs::Send>> {
    get_outbox(b, n, crate::codec::MAX / 48, "ACS", |m| decode_acs(m, n), encode_acs)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn every_boundary_roundtrips_and_trailing_refuses() {
        let vs = [
            vaba::Body::Pre(1, PhaseMessage::Echo(vec![1, 0, 2, 1, 0, 2, 0, 0])),
            vaba::Body::Cover(gather::Message {
                context: [8; 32],
                body: gather::Body::Gather(gather::IgBody::Inform(vaba::Set::from([1, 2, 3]))),
            }),
            vaba::Body::Final(PhaseMessage::Ready(vec![0, 0])),
        ];
        for body in vs {
            let m = acs::Message {
                context: [7; 32],
                body: acs::Body::Vaba(vaba::Message {
                    context: [9; 32],
                    view: 254,
                    body,
                }),
            };
            let b = encode_acs(&m);
            assert_eq!(decode_acs(&b, 4).unwrap(), m);
            let mut bad = b;
            bad.push(0);
            assert!(decode_acs(&bad, 4).is_err());
        }
    }
}

#[cfg(test)]
mod pin_wire {
    use super::*;
    use crate::asks::PhaseMessage as PinPhase;
    fn pin_sends() -> Vec<acs::Send> {
        vec![
            acs::Send { to: 1, message: acs::Message { context: [7; 32], body: acs::Body::Selector(1, PinPhase::Echo(vec![1])) } },
            acs::Send { to: 3, message: acs::Message { context: [7; 32], body: acs::Body::Selector(1, PinPhase::Ready(vec![1])) } },
        ]
    }
    /// Outbox wire: Nat count, then per packet u16 LE recipient and the
    /// length-prefixed message wire; canonical, bounded, recipient-checked.
    #[test]
    fn pin_outbox_wire() {
        let ps = pin_sends();
        let b = encode_outbox(&ps);
        let mut want = vec![2, 255];
        for s in &ps {
            want.extend(s.to.to_le_bytes());
            let m = encode_acs(&s.message);
            crate::codec::Nat::new(m.len() as u64).put(&mut want);
            want.extend(m);
        }
        assert_eq!(&b[..4], &[2, 255, 1, 0]);
        assert_eq!(b, want);
        assert_eq!(decode_outbox(&b, 4).unwrap(), ps);
        assert!(decode_outbox(&b, 3).is_err(), "recipient 3 is outside n = 3");
        let mut trailing = b.clone();
        trailing.push(0);
        let b = trailing;
        assert!(decode_outbox(&b, 4).is_err(), "trailing bytes refuse");
        let mut huge = vec![];
        crate::codec::Nat::new(crate::codec::MAX as u64).put(&mut huge);
        let b = huge;
        assert!(decode_outbox(&b, 4).is_err(), "an absurd count refuses");
    }
    #[test]
    fn pin_phase_wire() {
        for (tag, p) in [
            (0u8, PinPhase::Init(vec![9, 8])),
            (1, PinPhase::Echo(vec![9, 8])),
            (2, PinPhase::Ready(vec![9, 8])),
        ] {
            let mut b = vec![];
            put_phase(&p, &mut b);
            assert_eq!(b, vec![tag, 2, 255, 9, 8]);
            let mut c = crate::consensus_wire::Cursor::new(&b).unwrap();
            assert_eq!(get_phase(&mut c).unwrap(), p);
            c.finish().unwrap();
        }
        let mut c = crate::consensus_wire::Cursor::new(&[3, 0, 255]).unwrap();
        assert!(get_phase(&mut c).is_err());
    }
}

#[cfg(test)]
mod pin_cursor {
    use super::*;
    use crate::codec::{Nat, MAX};
    fn pin(bytes: &[u8]) -> Cursor<'_> {
        Cursor::new(bytes).unwrap()
    }
    /// The Nat readers every store used to copy: terminator-delimited,
    /// canonical, refusing an unterminated or noncanonical digit string; a
    /// count additionally refuses past `codec::MAX`.
    #[test]
    fn pin_nat_and_count_cursor() {
        let mut c = pin(&[45, 1, 255, 7]);
        assert_eq!(c.nat().unwrap().value().unwrap(), 300);
        assert_eq!(c.byte().unwrap(), 7);
        let mut c = pin(&[45, 1, 255, 7]);
        assert_eq!(c.count().unwrap(), 300);
        assert_eq!(c.byte().unwrap(), 7);
        assert_eq!(pin(&[255]).nat().unwrap().value().unwrap(), 0);
        assert_eq!(pin(&[255]).count().unwrap(), 0);
        assert_eq!(pin(&[200, 254, 255]).count().unwrap(), 200 + 254 * 255);
        for bad in [&[45u8, 1][..], &[45, 0, 255], &[][..]] {
            assert!(pin(bad).nat().is_err());
            assert!(pin(bad).count().is_err());
        }
        let mut huge = vec![];
        Nat::new(MAX as u64 + 1).put(&mut huge);
        assert!(pin(&huge).nat().is_ok());
        assert!(pin(&huge).count().is_err());
        let mut framed = vec![];
        crate::codec::bytes(&[9, 8, 7], &mut framed);
        assert_eq!(pin(&framed).bytes().unwrap(), vec![9, 8, 7]);
        framed.pop();
        assert!(pin(&framed).bytes().is_err());
    }
}
