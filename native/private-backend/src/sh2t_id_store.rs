//! Deterministic crash WAL for actual Sh2t-Id. Complete source input/randomness,
//! authenticated received frames, source request events and recursive outboxes
//! commit before visibility. Honest crash storage only, no rollback/release authority.
use crate::{
    asks::PhaseMessage,
    codec::{bad, bytes, Generation, Nat, Reader},
    consensus_wire::Cursor,
    private_send_store,
    reconstruction::Field,
    sh2t_id::{Body, Message, Send, Sh2tId},
    transition_journal::{Journal, Machine},
};
use std::{
    fs::File,
    io::{Read, Result},
    path::Path,
};
pub(crate) fn count(c: &mut Cursor) -> Result<usize> {
    let mut b = vec![];
    loop {
        let v = c.byte()?;
        b.push(v);
        if v == 255 {
            break;
        }
    }
    let mut r = Reader::new(&b)?;
    let n = r.count()?;
    r.finish()?;
    Ok(n)
}
pub(crate) fn put_phase(p: &PhaseMessage, b: &mut Vec<u8>) {
    let (t, v) = match p {
        PhaseMessage::Init(v) => (0, v),
        PhaseMessage::Echo(v) => (1, v),
        PhaseMessage::Ready(v) => (2, v),
    };
    b.push(t);
    bytes(v, b);
}
pub(crate) fn phase(c: &mut Cursor) -> Result<PhaseMessage> {
    let tag = c.byte()?;
    let b = c.bytes()?;
    match tag {
        0 => Ok(PhaseMessage::Init(b)),
        1 => Ok(PhaseMessage::Echo(b)),
        2 => Ok(PhaseMessage::Ready(b)),
        _ => Err(bad("Sh2t phase")),
    }
}
pub(crate) fn put_fields(v: &[Field], b: &mut Vec<u8>) {
    Nat::new(v.len() as u64).put(b);
    for x in v {
        b.extend(x.0.to_le_bytes());
    }
}
pub(crate) fn fields(c: &mut Cursor) -> Result<Vec<Field>> {
    let n = count(c)?;
    if n > 128 {
        return Err(bad("Sh2t point vector capacity"));
    }
    (0..n)
        .map(|_| Ok(Field(u128::from_le_bytes(c.take(16)?.try_into().unwrap()))))
        .collect()
}
pub fn encode_message(m: &Message) -> Vec<u8> {
    let mut b = b"DREGG.SH2T.ID.WIRE\x01".to_vec();
    b.extend(m.context);
    match &m.body {
        Body::Commitment(p) => {
            b.push(0);
            put_phase(p, &mut b);
        }
        Body::Private { holder, message } => {
            b.push(1);
            b.extend(holder.to_le_bytes());
            bytes(&private_send_store::encode_message(message), &mut b);
        }
        Body::Termination(p) => {
            b.push(2);
            put_phase(p, &mut b);
        }
        Body::Complaint { holder, phase } => {
            b.push(3);
            b.extend(holder.to_le_bytes());
            put_phase(phase, &mut b);
        }
        Body::OpenRequest {
            holder,
            requester,
            phase,
        } => {
            b.push(4);
            b.extend(holder.to_le_bytes());
            b.extend(requester.to_le_bytes());
            put_phase(phase, &mut b);
        }
        Body::ReconRequest {
            group,
            receiver,
            requester,
            phase,
        } => {
            b.push(5);
            Nat::new(*group as u64).put(&mut b);
            b.extend(receiver.to_le_bytes());
            b.extend(requester.to_le_bytes());
            put_phase(phase, &mut b);
        }
        Body::AgreementAccusation { holder, phase } => {
            b.push(6);
            b.extend(holder.to_le_bytes());
            put_phase(phase, &mut b);
        }
        Body::Point {
            group,
            receiver,
            values,
            masks,
        } => {
            b.push(7);
            Nat::new(*group as u64).put(&mut b);
            b.extend(receiver.to_le_bytes());
            put_fields(values, &mut b);
            put_fields(masks, &mut b);
        }
    }
    b
}
pub fn decode_message(b: &[u8]) -> Result<Message> {
    let mut c = Cursor::new(b)?;
    let domain = b"DREGG.SH2T.ID.WIRE\x01";
    if c.take(domain.len())? != domain {
        return Err(bad("Sh2t wire domain"));
    }
    let context = c.fixed32()?;
    let body = match c.byte()? {
        0 => Body::Commitment(phase(&mut c)?),
        1 => Body::Private {
            holder: c.u16()?,
            message: private_send_store::decode_message(&c.bytes()?)?,
        },
        2 => Body::Termination(phase(&mut c)?),
        3 => Body::Complaint {
            holder: c.u16()?,
            phase: phase(&mut c)?,
        },
        4 => Body::OpenRequest {
            holder: c.u16()?,
            requester: c.u16()?,
            phase: phase(&mut c)?,
        },
        5 => Body::ReconRequest {
            group: count(&mut c)?,
            receiver: c.u16()?,
            requester: c.u16()?,
            phase: phase(&mut c)?,
        },
        6 => Body::AgreementAccusation {
            holder: c.u16()?,
            phase: phase(&mut c)?,
        },
        7 => Body::Point {
            group: count(&mut c)?,
            receiver: c.u16()?,
            values: fields(&mut c)?,
            masks: fields(&mut c)?,
        },
        _ => return Err(bad("Sh2t wire tag")),
    };
    c.finish()?;
    let m = Message { context, body };
    if encode_message(&m) != b {
        return Err(bad("Sh2t wire canonical"));
    }
    Ok(m)
}
fn outbox(ps: &[Send]) -> Vec<u8> {
    let mut b = vec![];
    Nat::new(ps.len() as u64).put(&mut b);
    for p in ps {
        b.extend(p.to.to_le_bytes());
        bytes(&encode_message(&p.message), &mut b);
    }
    b
}
pub(crate) fn parse_outbox(b: &[u8], n: usize) -> Result<Vec<Send>> {
    let mut c = Cursor::new(b)?;
    let len = count(&mut c)?;
    if len > crate::codec::MAX / 40 {
        return Err(bad("Sh2t outbox capacity"));
    }
    let mut ps = vec![];
    for _ in 0..len {
        let to = c.u16()?;
        if to as usize >= n {
            return Err(bad("Sh2t outbox recipient"));
        }
        ps.push(Send {
            to,
            message: decode_message(&c.bytes()?)?,
        });
    }
    c.finish()?;
    if outbox(&ps) != b {
        return Err(bad("Sh2t outbox canonical"));
    }
    Ok(ps)
}
/// Tag 5: commit the dealing seed and inputs durably, publishing nothing.
pub(crate) fn commit_event(seed: [u8; 32], polys: &[Vec<Field>]) -> Vec<u8> {
    let mut e = vec![5];
    e.extend(seed);
    Nat::new(polys.len() as u64).put(&mut e);
    for p in polys {
        for x in p {
            e.extend(x.0.to_le_bytes());
        }
    }
    e
}
/// Tag 6: emit the deal from the committed seed and inputs.
pub(crate) const EMIT_EVENT: [u8; 1] = [6];
#[derive(Clone)]
pub struct Sh2tMachine {
    pub state: Sh2tId,
    /// Seed and inputs committed by a tag 5 event, awaiting their tag 6 emission.
    pub pending: Option<([u8; 32], Vec<Vec<Field>>)>,
}
impl Machine for Sh2tMachine {
    fn apply(&mut self, e: &[u8]) -> Result<Vec<u8>> {
        let mut c = Cursor::new(e)?;
        let out = match c.byte()? {
            5 => {
                let seed = c.fixed32()?;
                let n = count(&mut c)?;
                if n != self.state.count() {
                    return Err(bad("Sh2t event polynomial count"));
                }
                let polys = (0..n)
                    .map(|_| {
                        (0..=2 * self.state.f)
                            .map(|_| {
                                Ok(Field(u128::from_le_bytes(c.take(16)?.try_into().unwrap())))
                            })
                            .collect::<Result<Vec<_>>>()
                    })
                    .collect::<Result<Vec<_>>>()?;
                c.finish()?;
                if self.pending.is_some() {
                    return Err(bad("Sh2t dealer already committed"));
                }
                // Dry run on a clone: a commit that could never emit is refused.
                self.state.clone().dealer(&polys, seed)?;
                self.pending = Some((seed, polys));
                vec![]
            }
            6 => {
                c.finish()?;
                let (seed, polys) = self
                    .pending
                    .take()
                    .ok_or_else(|| bad("Sh2t emit without committed dealer"))?;
                self.state.dealer(&polys, seed)?
            }
            1 => {
                let holder = c.u16()?;
                c.finish()?;
                self.state.request_open(holder)?
            }
            2 => {
                let sender = c.u16()?;
                let m = decode_message(&c.bytes()?)?;
                c.finish()?;
                self.state.receive(sender, m)?
            }
            3 => {
                let group = count(&mut c)?;
                let receiver = c.u16()?;
                c.finish()?;
                self.state.request_private_reconstruction(group, receiver)?
            }
            4 => {
                let holder = c.u16()?;
                c.finish()?;
                self.state.request_accusation(holder)?
            }
            _ => return Err(bad("Sh2t event tag")),
        };
        Ok(outbox(&out))
    }
}
pub struct Store {
    journal: Journal<Sh2tMachine>,
}
impl Store {
    pub fn open(
        path: &Path,
        me: u16,
        dealer: u16,
        n: usize,
        f: usize,
        g: &Generation,
        per_group: usize,
    ) -> Result<Self> {
        let state = Sh2tId::new(me, dealer, n, f, g, per_group)?;
        let mut identity = b"DREGG.SH2T.ID.PARTY.WAL.V2".to_vec();
        g.put(&mut identity);
        identity.extend(state.context);
        identity.extend(me.to_le_bytes());
        Ok(Self {
            journal: Journal::open(
                path,
                &identity,
                Sh2tMachine {
                    state,
                    pending: None,
                },
            )?,
        })
    }
    pub fn state(&self) -> &Sh2tId {
        &self.journal.state().state
    }
    pub fn torn_tail(&self) -> Option<&crate::transition_journal::TornTail> {
        self.journal.torn_tail()
    }
    fn apply(&mut self, e: &[u8]) -> Result<Vec<Send>> {
        let out = self.journal.append(e)?;
        parse_outbox(&out, self.state().n)
    }
    /// The deal is two journalled steps: commit the seed and inputs (nothing
    /// published), then emit. A tear of the emit record, or its loss to
    /// damage after publication, re-derives the same deal from the committed
    /// seed; a tear of the commit record means nothing was ever published.
    pub fn dealer(&mut self, polys: &[Vec<Field>]) -> Result<Vec<Send>> {
        if let Some(old) = self.state().dealer_inputs() {
            if old != polys {
                return Err(bad("Sh2t changed dealer retry"));
            }
            return self.replay_outboxes();
        }
        if self.state().me != self.state().dealer
            || polys.len() != self.state().count()
            || polys.iter().any(|p| p.len() != 2 * self.state().f + 1)
        {
            return Err(bad("Sh2t dealer inputs"));
        }
        if let Some((_, old)) = &self.journal.state().pending {
            if old != polys {
                return Err(bad("Sh2t changed dealer retry"));
            }
        } else {
            let mut seed = [0; 32];
            File::open("/dev/urandom")?.read_exact(&mut seed)?;
            self.apply(&commit_event(seed, polys))?;
        }
        self.apply(&EMIT_EVENT)
    }
    pub fn receive(&mut self, sender: u16, m: &Message) -> Result<Vec<Send>> {
        let mut e = vec![2];
        e.extend(sender.to_le_bytes());
        bytes(&encode_message(m), &mut e);
        self.apply(&e)
    }
    pub fn request_open(&mut self, holder: u16) -> Result<Vec<Send>> {
        let mut e = vec![1];
        e.extend(holder.to_le_bytes());
        self.apply(&e)
    }
    pub fn request_private_reconstruction(
        &mut self,
        group: usize,
        receiver: u16,
    ) -> Result<Vec<Send>> {
        let mut e = vec![3];
        Nat::new(group as u64).put(&mut e);
        e.extend(receiver.to_le_bytes());
        self.apply(&e)
    }
    pub fn request_accusation(&mut self, holder: u16) -> Result<Vec<Send>> {
        let mut e = vec![4];
        e.extend(holder.to_le_bytes());
        self.apply(&e)
    }
    pub fn replay_outboxes(&self) -> Result<Vec<Send>> {
        let mut out = vec![];
        for b in self.journal.replay_outboxes() {
            out.extend(parse_outbox(b, self.state().n)?);
        }
        Ok(out)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::sh2t_id::Reconstruction;
    use std::{
        collections::VecDeque,
        fs,
        time::{SystemTime, UNIX_EPOCH},
    };
    fn generation() -> Generation {
        Generation {
            invocation: Nat::from_be(&[255; 32]),
            command: vec![5],
            attempt: Nat::new(0),
            generation: Nat::new(1),
            configuration: Nat::new(9),
        }
    }
    fn polys() -> Vec<Vec<Field>> {
        (0..16)
            .map(|i| vec![Field(0), Field(i as u128 + 3), Field(i as u128 + 19)])
            .collect()
    }
    fn root() -> std::path::PathBuf {
        let p = std::env::temp_dir().join(format!(
            "mini-sh2t-{}-{}",
            std::process::id(),
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir(&p).unwrap();
        p
    }
    fn run(ns: &mut [Store], q: &mut VecDeque<(u16, Send)>) {
        let mut steps = 0;
        while let Some((from, p)) = q.pop_front() {
            steps += 1;
            assert!(steps < 100000);
            let to = p.to;
            let out = ns[to as usize].receive(from, &p.message).unwrap();
            q.extend(out.into_iter().map(|p| (to, p)));
        }
    }
    #[test]
    fn retained_full_dealer_randomness_exact_outbox_changed_input_identity_and_tear() {
        let p = root().join("wal");
        let out;
        {
            let mut s = Store::open(&p, 0, 0, 4, 1, &generation(), 1).unwrap();
            out = s.dealer(&polys()).unwrap();
            assert_eq!(s.dealer(&polys()).unwrap(), out);
        }
        {
            let mut s = Store::open(&p, 0, 0, 4, 1, &generation(), 1).unwrap();
            assert_eq!(s.replay_outboxes().unwrap(), out);
            let mut changed = polys();
            changed[0][0] = Field(1);
            assert!(s.dealer(&changed).is_err());
        }
        let mut wrong = generation();
        wrong.command.push(8);
        assert!(Store::open(&p, 0, 0, 4, 1, &wrong, 1).is_err());
        let len = fs::metadata(&p).unwrap().len();
        fs::OpenOptions::new()
            .write(true)
            .open(&p)
            .unwrap()
            .set_len(len - 1)
            .unwrap();
        // The final record (the emit) lost its last byte. Whether that is a crash
        // tear or damage to a published record cannot be told apart, so the same
        // deal must come back: re-derived from the committed seed, never re-drawn.
        let mut s = Store::open(&p, 0, 0, 4, 1, &generation(), 1).unwrap();
        assert!(s.torn_tail().is_some(), "the dropped emit record is reported");
        assert!(s.replay_outboxes().unwrap().is_empty());
        assert!(s.state().dealer_inputs().is_none());
        assert!(s.dealer(&changed_polys()).is_err(), "changed inputs refuse after the tear");
        assert_eq!(s.dealer(&polys()).unwrap(), out, "same deal, not a re-deal");
        assert_eq!(s.dealer(&polys()).unwrap(), out);
        drop(s);
        let s = Store::open(&p, 0, 0, 4, 1, &generation(), 1).unwrap();
        assert!(s.torn_tail().is_none());
        assert_eq!(s.replay_outboxes().unwrap(), out);
    }
    fn changed_polys() -> Vec<Vec<Field>> {
        let mut c = polys();
        c[0][0] = Field(1);
        c
    }
    #[test]
    fn torn_commit_record_published_nothing_so_a_fresh_deal_is_safe() {
        let p = root().join("wal");
        let (after_open, after_commit);
        {
            let mut s = Store::open(&p, 0, 0, 4, 1, &generation(), 1).unwrap();
            after_open = fs::metadata(&p).unwrap().len();
            s.dealer(&polys()).unwrap();
            after_commit = fs::metadata(&p).unwrap().len();
        }
        assert!(after_commit > after_open);
        // Cut inside the commit record: the emit record is gone with it.
        fs::OpenOptions::new()
            .write(true)
            .open(&p)
            .unwrap()
            .set_len(after_open + 5)
            .unwrap();
        let mut s = Store::open(&p, 0, 0, 4, 1, &generation(), 1).unwrap();
        assert!(s.torn_tail().is_some());
        assert!(s.replay_outboxes().unwrap().is_empty());
        assert!(!s.dealer(&changed_polys()).unwrap().is_empty());
    }
    #[test]
    fn actual_recipient_reconstruction_survives_store_reopen_and_canonical_refusers() {
        let root = root();
        let paths = (0..4)
            .map(|i| root.join(format!("p{i}")))
            .collect::<Vec<_>>();
        let mut ns = (0..4)
            .map(|i| Store::open(&paths[i], i as u16, 0, 4, 1, &generation(), 1).unwrap())
            .collect::<Vec<_>>();
        let mut q = ns[0]
            .dealer(&polys())
            .unwrap()
            .into_iter()
            .map(|p| (0, p))
            .collect();
        run(&mut ns, &mut q);
        for i in [1, 2] {
            q.extend(
                ns[i]
                    .request_private_reconstruction(15, 3)
                    .unwrap()
                    .into_iter()
                    .map(|p| (i as u16, p)),
            );
        }
        run(&mut ns, &mut q);
        let Some(Reconstruction::Verified(r)) = ns[3].state().private_reconstruction(15) else {
            panic!("no verified result")
        };
        assert_eq!(r.polynomials(), &[polys()[15].clone()]);
        let expected = r.clone();
        let out = ns[3].replay_outboxes().unwrap();
        drop(ns);
        let s = Store::open(&paths[3], 3, 0, 4, 1, &generation(), 1).unwrap();
        let Some(Reconstruction::Verified(r)) = s.state().private_reconstruction(15) else {
            panic!("replay lost result")
        };
        assert_eq!(r, &expected);
        assert_eq!(s.replay_outboxes().unwrap(), out);
        let m = Message {
            context: s.state().context,
            body: Body::Point {
                group: 15,
                receiver: 3,
                values: vec![Field(u128::MAX)],
                masks: vec![Field(1)],
            },
        };
        let b = encode_message(&m);
        assert_eq!(decode_message(&b).unwrap(), m);
        let mut malformed = b;
        malformed.push(0);
        assert!(decode_message(&malformed).is_err());
        drop(s);
        let mut fresh = Store::open(&root.join("fresh"), 1, 0, 4, 1, &generation(), 1).unwrap();
        let len = fs::metadata(root.join("fresh")).unwrap().len();
        assert!(fresh.request_open(0).is_err());
        assert!(fresh.request_accusation(0).is_err());
        assert!(fresh.request_private_reconstruction(0, 0).is_err());
        assert_eq!(fs::metadata(root.join("fresh")).unwrap().len(), len);
    }
}

#[cfg(test)]
mod pin_helpers {
    use super::*;
    use crate::consensus_wire::Cursor as PinCursor;
    fn pin(bytes: &[u8]) -> PinCursor<'_> {
        PinCursor::new(bytes).unwrap()
    }
    /// Pins the shape of the per-module Nat reader: terminator-delimited,
    /// canonical, refuses unterminated or noncanonical digits.
    #[test]
    fn pin_nat_cursor_sh2t_id_store() {
        let mut c = pin(&[45, 1, 255, 7]);
        assert_eq!(count(&mut c).unwrap(), 300);
        assert_eq!(c.byte().unwrap(), 7);
        assert_eq!(count(&mut pin(&[255])).unwrap(), 0);
        assert_eq!(count(&mut pin(&[200, 254, 255])).unwrap(), 200 + 254 * 255);
        for bad in [&[45u8, 1][..], &[45, 0, 255], &[][..]] {
            assert!(count(&mut pin(bad)).is_err());
        }
        let mut huge = vec![];
        crate::codec::Nat::new(crate::codec::MAX as u64 + 1).put(&mut huge);
        assert_eq!(count(&mut pin(&huge)).is_err(), true);
    }
}

#[cfg(test)]
mod pin_wire {
    use super::*;
    use crate::asks::PhaseMessage as PinPhase;
    fn pin_sends() -> Vec<Send> {
        vec![
            Send { to: 1, message: Message { context: [7; 32], body: Body::Termination(PinPhase::Echo(vec![1])) } },
            Send { to: 3, message: Message { context: [7; 32], body: Body::Termination(PinPhase::Ready(vec![1])) } },
        ]
    }
    /// Outbox wire: Nat count, then per packet u16 LE recipient and the
    /// length-prefixed message wire; canonical, bounded, recipient-checked.
    #[test]
    fn pin_outbox_wire() {
        let ps = pin_sends();
        let b = outbox(&ps);
        let mut want = vec![2, 255];
        for s in &ps {
            want.extend(s.to.to_le_bytes());
            let m = encode_message(&s.message);
            crate::codec::Nat::new(m.len() as u64).put(&mut want);
            want.extend(m);
        }
        assert_eq!(&b[..4], &[2, 255, 1, 0]);
        assert_eq!(b, want);
        assert_eq!(parse_outbox(&b, 4).unwrap(), ps);
        assert!(parse_outbox(&b, 3).is_err(), "recipient 3 is outside n = 3");
        let mut trailing = b.clone();
        trailing.push(0);
        let b = trailing;
        assert!(parse_outbox(&b, 4).is_err(), "trailing bytes refuse");
        let mut huge = vec![];
        crate::codec::Nat::new(crate::codec::MAX as u64).put(&mut huge);
        let b = huge;
        assert!(parse_outbox(&b, 4).is_err(), "an absurd count refuses");
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
            assert_eq!(phase(&mut c).unwrap(), p);
            c.finish().unwrap();
        }
        let mut c = crate::consensus_wire::Cursor::new(&[3, 0, 255]).unwrap();
        assert!(phase(&mut c).is_err());
    }
}
