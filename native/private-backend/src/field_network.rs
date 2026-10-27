//! Concrete checked-triple consumer for the common AND/XOR DAG. Static f<n/3,
//! actual source-bound ACSS points, classical ROM/dZK error bounds and independent
//! authenticated reliable channels are premises. Reference GF128 is variable-time.
//! Full public plan is burned before any accepted input/triple getter. This is
//! not Native Qualified, source admission, GOD/fault elimination or output release.
use crate::{
    acss_id::{AcssId, LocalSharing},
    asks::PhaseMessage,
    circuit_batch::{Network, Op, Plan},
    codec::{bad, bytes, Correlation, Generation, Nat},
    consensus_wire::Cursor,
    custody::hash,
    reconstruction::Field,
    triple_king::{self, CheckedTriples},
};
use std::{
    collections::BTreeMap,
    io::{Error, ErrorKind, Result},
    path::Path,
};
#[derive(Clone)]
pub struct InputRef {
    state: AcssId,
    generation: Generation,
    index: usize,
}
impl InputRef {
    /// Public context/index preflight only. NO accepted-share getter here.
    pub fn new(state: AcssId, generation: Generation, index: usize) -> Result<Self> {
        let expected = AcssId::new(
            state.me,
            state.dealer,
            state.n,
            state.f,
            &generation,
            state.count,
        )?;
        if expected.context != state.context || index >= state.count {
            return Err(bad("actual input generation/index"));
        }
        Ok(Self {
            state,
            generation,
            index,
        })
    }
    fn public_bytes(&self) -> Vec<u8> {
        let mut b = vec![];
        self.generation.put(&mut b);
        b.extend(self.state.context);
        b.extend(self.state.dealer.to_le_bytes());
        Nat::new(self.index as u64).put(&mut b);
        b
    }
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TripleManifest {
    pub generation: Generation,
    pub context: [u8; 32],
    pub basis: Vec<u8>,
    pub n: usize,
    pub f: usize,
    pub count: usize,
}
impl TripleManifest {
    /// Common PUBLIC protocol inventory. No tuple hash/secret-dependent ID.
    pub fn from_checked(v: &CheckedTriples) -> Self {
        let (n, f) = v.roster();
        Self {
            generation: v.generation().clone(),
            context: v.context(),
            basis: v.basis_bytes().to_vec(),
            n,
            f,
            count: v.count(),
        }
    }
    pub fn encode(&self) -> Vec<u8> {
        let mut b = b"DREGG.CHECKED.TRIPLE.INVENTORY\x01".to_vec();
        self.generation.put(&mut b);
        b.extend(self.context);
        bytes(&self.basis, &mut b);
        for n in [self.n, self.f, self.count] {
            Nat::new(n as u64).put(&mut b);
        }
        b
    }
    pub fn pool_id(&self) -> Nat {
        Nat::from_be(&hash(&self.encode()))
    }
    pub fn row(&self, index: usize) -> Result<Correlation> {
        if index >= self.count {
            return Err(bad("checked triple index"));
        }
        Ok(Correlation {
            pool: self.pool_id(),
            row: Nat::new(index as u64),
        })
    }
}
/// Public preflight for independently prepared inventories. Source admission
/// must authorize this exact set; this function supplies no enrollment grant.
fn catalog<'a>(
    checked: &'a [&'a CheckedTriples],
) -> Result<BTreeMap<Nat, (usize, TripleManifest)>> {
    if checked.is_empty() || checked.len() > 2048 {
        return Err(bad("checked inventory count"));
    }
    let mut by_pool = BTreeMap::new();
    let mut seeds = std::collections::BTreeSet::new();
    for (index, stock) in checked.iter().enumerate() {
        let manifest = TripleManifest::from_checked(stock);
        if manifest.count == 0 || manifest.count > 32 || stock.preparation_rows().is_empty() {
            return Err(bad("checked inventory public capacity/provenance"));
        }
        for seed in stock.preparation_rows() {
            if !seeds.insert(seed.clone()) {
                return Err(bad("aliased original preprocessing seeds"));
            }
        }
        if by_pool
            .insert(manifest.pool_id(), (index, manifest))
            .is_some()
        {
            return Err(bad("duplicate checked inventory pool"));
        }
    }
    Ok(by_pool)
}
/// Source program/capacity binding must separately be approved by the native
/// receiver. This codec binds actual public input provenance/inventory; it does
/// not turn caller source_binding bytes into source authority.
///
/// Versioned exact multi-inventory binding. Inventories are ordered by their
/// canonical pool IDs; caller order cannot change the common Plan. Each entry
/// also retains the actual original seed reservations, excluding relabeling
/// one post-burn basis into several seemingly independent tuple stocks.
pub fn binding_many(
    checked: &[&CheckedTriples],
    inputs: &[InputRef],
    source_binding: &[u8],
) -> Result<Vec<u8>> {
    if source_binding.is_empty() {
        return Err(bad("missing source binding"));
    }
    let by_pool = catalog(checked)?;
    let mut b = b"DREGG.PRIVATE.FIELD.NETWORK.BINDING\x02".to_vec();
    Nat::new(by_pool.len() as u64).put(&mut b);
    for (pool, (index, manifest)) in by_pool {
        pool.put(&mut b);
        bytes(&manifest.encode(), &mut b);
        Nat::new(checked[index].preparation_rows().len() as u64).put(&mut b);
        for id in checked[index].preparation_rows() {
            id.put(&mut b);
        }
    }
    Nat::new(inputs.len() as u64).put(&mut b);
    for i in inputs {
        bytes(&i.public_bytes(), &mut b);
    }
    bytes(source_binding, &mut b);
    if b.len() > crate::codec::MAX {
        return Err(bad("inventory manifest capacity"));
    }
    Ok(b)
}
/// Prepend the explicitly counted Boolean qualification network while
/// preserving original inputs, gate order and outputs. Source/compiler bytes
/// remain in the approved binding; the complete combined graph must be burned
/// before any material getter. This does not qualify the inputs by itself.
pub fn with_boolean_inputs(network: &Network) -> Result<Network> {
    let n = network.input_count;
    if n == 0 || n > 65536 {
        return Err(bad("Boolean input profile"));
    }
    let prefix = n
        .checked_mul(2)
        .and_then(|n| n.checked_add(1))
        .ok_or_else(|| bad("Boolean prefix overflow"))?;
    let count = (network.gates.len() as u64)
        .checked_add(prefix)
        .ok_or_else(|| bad("Boolean graph overflow"))?;
    if count > 65536 {
        return Err(bad("qualified graph capacity"));
    }
    let shift = |wire: u64| -> Result<u64> {
        if wire < n {
            Ok(wire)
        } else {
            wire.checked_add(prefix)
                .ok_or_else(|| bad("Boolean wire overflow"))
        }
    };
    let mut gates = vec![Op::Constant(true)];
    for i in 0..n {
        let x = n + gates.len() as u64;
        gates.push(Op::Xor(i, n));
        gates.push(Op::And(i, x));
    }
    for (i, op) in network.gates.iter().enumerate() {
        let bound = n + i as u64;
        let next = match *op {
            Op::Constant(v) => Op::Constant(v),
            Op::Xor(a, b) | Op::And(a, b) => {
                if a >= bound || b >= bound {
                    return Err(bad("source graph forward reference"));
                }
                match op {
                    Op::Xor(..) => Op::Xor(shift(a)?, shift(b)?),
                    _ => Op::And(shift(a)?, shift(b)?),
                }
            }
        };
        gates.push(next);
    }
    let outputs = network
        .outputs
        .iter()
        .map(|wire| {
            if *wire >= n + network.gates.len() as u64 {
                Err(bad("source graph output range"))
            } else {
                shift(*wire)
            }
        })
        .collect::<Result<Vec<_>>>()?;
    Ok(Network {
        input_count: n,
        gates,
        outputs,
    })
}
pub(crate) fn bit_prefix(network: &Network) -> Result<Vec<usize>> {
    let n = network.input_count as usize;
    if n == 0 || network.gates.first() != Some(&Op::Constant(true)) {
        return Err(bad("missing counted input bit prefix"));
    }
    let one = network.input_count;
    let mut positions = vec![];
    for input in 0..n {
        let xor = 1 + 2 * input;
        let and = xor + 1;
        if network.gates.get(xor) != Some(&Op::Xor(input as u64, one))
            || network.gates.get(and)
                != Some(&Op::And(input as u64, network.input_count + xor as u64))
        {
            return Err(bad("input bit prefix is not x*(x+1)"));
        }
        positions.push(and);
    }
    Ok(positions)
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Body {
    Opening {
        gate: usize,
        holder: u16,
        phase: PhaseMessage,
    },
    Bits {
        holder: u16,
        phase: PhaseMessage,
    },
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Message {
    pub context: [u8; 32],
    pub body: Body,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Send {
    pub to: u16,
    pub message: Message,
}
pub(crate) fn values(phase: &PhaseMessage) -> &[u8] {
    match phase {
        PhaseMessage::Init(b) | PhaseMessage::Echo(b) | PhaseMessage::Ready(b) => b,
    }
}
pub(crate) fn field_bytes(v: &[Field]) -> Vec<u8> {
    v.iter().flat_map(|x| x.0.to_le_bytes()).collect()
}
pub(crate) fn fields(b: &[u8], count: usize) -> Result<Vec<Field>> {
    if b.len() != count * 16 {
        return Err(bad("field opening shape"));
    }
    Ok(b.chunks_exact(16)
        .map(|p| Field(u128::from_le_bytes(p.try_into().unwrap())))
        .collect())
}
#[derive(Clone)]
pub struct Engine {
    plan: Plan,
    context: [u8; 32],
    burn_prefix: crate::codec::Journal,
    me: u16,
    n: usize,
    f: usize,
    wires: Vec<Field>,
    triples: Vec<(Field, Field, Field)>,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BitnessFailure {
    pub opened_checks: Vec<Field>,
}
impl Engine {
    /// All public shape/context/stock checks precede the complete burn; only
    /// then read actual accepted shares and checked tuples. Refusal after the
    /// burn cannot restore rows. Same rows under another attempt/plan refuse.
    pub fn reserve(
        plan: Plan,
        checked: &CheckedTriples,
        inputs: Vec<InputRef>,
        source_binding: &[u8],
        anchor: &Path,
        local: &Path,
    ) -> Result<Self> {
        let manifest = TripleManifest::from_checked(checked);
        if plan.generation != manifest.generation {
            return Err(bad("single-inventory exact consumer generation"));
        }
        let expected = binding_many(&[checked], &inputs, source_binding)?;
        Self::reserve_inner(plan, &[checked], inputs, &expected, anchor, local)
    }
    /// Burns every selected row from every stock in one durable batch before
    /// any accepted input or tuple getter. Unused stock tails remain unused;
    /// they are never relabeled as spent or available under another pool ID.
    pub fn reserve_many(
        plan: Plan,
        checked: &[&CheckedTriples],
        inputs: Vec<InputRef>,
        source_binding: &[u8],
        anchor: &Path,
        local: &Path,
    ) -> Result<Self> {
        let expected = binding_many(checked, &inputs, source_binding)?;
        Self::reserve_inner(plan, checked, inputs, &expected, anchor, local)
    }
    fn reserve_inner(
        plan: Plan,
        checked: &[&CheckedTriples],
        inputs: Vec<InputRef>,
        expected_binding: &[u8],
        anchor: &Path,
        local: &Path,
    ) -> Result<Self> {
        plan.validate()?;
        let catalog = catalog(checked)?;
        if plan.public_ticks != 1
            || plan.network.input_count as usize != inputs.len()
            || plan.binding_bytes != expected_binding
        {
            return Err(bad("exact unrolled plan/input/triple binding"));
        }
        bit_prefix(&plan.network)?;
        let me = checked[0].holder();
        let (n, f) = checked[0].roster();
        if checked
            .iter()
            .any(|v| v.holder() != me || v.roster() != (n, f))
        {
            return Err(bad("inventory holder/access structure mismatch"));
        }
        if n != 3 * f + 1 || n > 16 || me as usize >= n {
            return Err(bad("field evaluator roster"));
        }
        for input in &inputs {
            if input.state.me != me || input.state.n != n || input.state.f != f {
                return Err(bad("input receiver access structure"));
            }
        }
        let mut selected = Vec::with_capacity(plan.rows.len());
        let mut used = std::collections::BTreeSet::new();
        for row in &plan.rows {
            let (stock, manifest) = catalog
                .get(&row.pool)
                .ok_or_else(|| bad("unknown checked inventory pool"))?;
            let index = usize::try_from(row.row.value()?).map_err(|_| bad("inventory index"))?;
            if index >= manifest.count {
                return Err(bad("checked inventory index"));
            }
            used.insert(row.pool.clone());
            selected.push((*stock, index));
        }
        if used.len() != catalog.len() {
            return Err(bad("unreferenced inventory in exact plan"));
        }
        triple_king::burn_preparation(&plan.rows, &plan.generation, &plan.encode(), anchor, local)?;
        let burn_prefix = crate::codec::Journal::decode(&crate::custody::rpc(anchor, &[0])?)?;
        let indexed = burn_prefix
            .allocations
            .iter()
            .map(|a| (&a.id, a))
            .collect::<BTreeMap<_, _>>();
        if plan.rows.iter().any(|row| {
            indexed.get(row).is_none_or(|a| {
                a.generation != plan.generation
                    || a.purpose != crate::codec::Purpose::Triple
                    || a.consumed
            })
        }) {
            return Err(bad("complete fixed plan anchor disappeared"));
        }
        // FIRST private getter is below the full stable-row anchor/readback.
        let mut wires = vec![];
        for input in inputs {
            let accepted = match input.state.local_sharing() {
                Some(LocalSharing::Accepted(v)) => v,
                Some(LocalSharing::Rejected(_)) => {
                    return Err(bad("input requires actual private repair/accusation"))
                }
                None => {
                    return Err(Error::new(
                        ErrorKind::WouldBlock,
                        "input sharing incomplete; full plan remains spent",
                    ))
                }
            };
            if accepted.holder() != me || accepted.context() != input.state.context {
                return Err(bad("actual accepted input context"));
            }
            wires.push(accepted.shares()[input.index]);
        }
        let mut triples = vec![];
        for (stock, index) in selected {
            triples.push(checked[stock].triples()[index]);
        }
        let mut context = b"DREGG.PRIVATE.FIELD.NETWORK\x01".to_vec();
        bytes(&plan.encode(), &mut context);
        Ok(Self {
            plan,
            context: hash(&context),
            burn_prefix,
            me,
            n,
            f,
            wires,
            triples,
        })
    }
    pub(crate) fn pristine_material(&self) -> Result<(&[Field], &[(Field, Field, Field)])> {
        self.initial_bytes()?;
        Ok((&self.wires, &self.triples))
    }
    pub fn context(&self) -> [u8; 32] {
        self.context
    }
    pub fn holder(&self) -> u16 {
        self.me
    }
    pub fn roster(&self) -> (usize, usize) {
        (self.n, self.f)
    }
    pub fn plan(&self) -> &Plan {
        &self.plan
    }
}
impl Engine {
    /// Private original initialization only. This snapshot is not a proof of
    /// reachability, Native authority or an affine recovery/admission resource.
    pub(crate) fn initial_bytes(&self) -> Result<Vec<u8>> {
        if self.wires.len() != self.plan.network.input_count as usize {
            return Err(bad("field original initialization only"));
        }
        let mut b = b"DREGG.PRIVATE.FIELD.INITIAL\x01".to_vec();
        bytes(&self.plan.encode(), &mut b);
        b.extend(self.me.to_le_bytes());
        Nat::new(self.n as u64).put(&mut b);
        Nat::new(self.f as u64).put(&mut b);
        bytes(&self.burn_prefix.encode(), &mut b);
        bytes(&field_bytes(&self.wires), &mut b);
        let triples = self
            .triples
            .iter()
            .flat_map(|(a, b, c)| [*a, *b, *c])
            .collect::<Vec<_>>();
        bytes(&field_bytes(&triples), &mut b);
        if b.len() > crate::codec::MAX {
            return Err(bad("field initial private WAL capacity"));
        }
        Ok(b)
    }
    /// ONLY the original endpoint-private initial record written by Store::create
    /// under honest crash storage may use this path. Decoded bytes/anchor alone
    /// cannot create Native Qualified or permission to dispatch network effects.
    pub(crate) fn restore_initial(
        b: &[u8],
        expected_plan: &Plan,
        expected_holder: u16,
        anchor: &Path,
    ) -> Result<Self> {
        fn nat(c: &mut Cursor) -> Result<Nat> {
            let mut ds = vec![];
            loop {
                let v = c.byte()?;
                ds.push(v);
                if v == 255 {
                    break;
                }
            }
            let mut r = crate::codec::Reader::new(&ds)?;
            let n = r.nat()?;
            r.finish()?;
            Ok(n)
        }
        let mut c = Cursor::new(b)?;
        let tag = b"DREGG.PRIVATE.FIELD.INITIAL\x01";
        if c.take(tag.len())? != tag {
            return Err(bad("field original initial frame"));
        }
        let plan = Plan::decode(&c.bytes()?)?;
        let me = c.u16()?;
        let n = usize::try_from(nat(&mut c)?.value()?).map_err(|_| bad("field roster"))?;
        let f = usize::try_from(nat(&mut c)?.value()?).map_err(|_| bad("field faults"))?;
        if plan != *expected_plan
            || me != expected_holder
            || f > 5
            || n > 16
            || n != 3 * f + 1
            || me as usize >= n
            || plan.public_ticks != 1
        {
            return Err(bad("field retained source plan/holder/access structure"));
        }
        let burn_prefix = crate::codec::Journal::decode(&c.bytes()?)?;
        let wires = fields(&c.bytes()?, plan.network.input_count as usize)?;
        let ts = fields(&c.bytes()?, plan.rows.len() * 3)?;
        c.finish()?;
        let latest = crate::codec::Journal::decode(&crate::custody::rpc(anchor, &[0])?)?;
        if !latest.extends(&burn_prefix)
            || !burn_prefix
                .allocations
                .iter()
                .all(|a| latest.allocations.contains(a))
            || !plan.rows.iter().all(|row| {
                burn_prefix.allocations.iter().any(|a| {
                    a.id == *row
                        && a.generation == plan.generation
                        && a.purpose == crate::codec::Purpose::Triple
                })
            })
        {
            return Err(bad("field full-plan retained anchor/readback"));
        }
        bit_prefix(&plan.network)?;
        let triples = ts.chunks_exact(3).map(|v| (v[0], v[1], v[2])).collect();
        let mut ctx = b"DREGG.PRIVATE.FIELD.NETWORK\x01".to_vec();
        bytes(&plan.encode(), &mut ctx);
        let engine = Self {
            plan,
            context: hash(&ctx),
            burn_prefix,
            me,
            n,
            f,
            wires,
            triples,
        };
        if engine.initial_bytes()? != b {
            return Err(bad("field original initial canonical"));
        }
        Ok(engine)
    }
}

fn put_phase(p: &PhaseMessage, b: &mut Vec<u8>) {
    let (tag, v) = match p {
        PhaseMessage::Init(v) => (0, v),
        PhaseMessage::Echo(v) => (1, v),
        PhaseMessage::Ready(v) => (2, v),
    };
    b.push(tag);
    bytes(v, b);
}
fn get_phase(c: &mut Cursor) -> Result<PhaseMessage> {
    let t = c.byte()?;
    let v = c.bytes()?;
    match t {
        0 => Ok(PhaseMessage::Init(v)),
        1 => Ok(PhaseMessage::Echo(v)),
        2 => Ok(PhaseMessage::Ready(v)),
        _ => Err(bad("field phase")),
    }
}
pub fn encode_message(m: &Message) -> Vec<u8> {
    let mut b = b"DREGG.PRIVATE.FIELD.WIRE\x01".to_vec();
    b.extend(m.context);
    match &m.body {
        Body::Opening {
            gate,
            holder,
            phase,
        } => {
            b.push(0);
            Nat::new(*gate as u64).put(&mut b);
            b.extend(holder.to_le_bytes());
            put_phase(phase, &mut b);
        }
        Body::Bits { holder, phase } => {
            b.push(1);
            b.extend(holder.to_le_bytes());
            put_phase(phase, &mut b);
        }
    }
    b
}
pub fn decode_message(b: &[u8]) -> Result<Message> {
    let mut c = Cursor::new(b)?;
    let frame = b"DREGG.PRIVATE.FIELD.WIRE\x01";
    if c.take(frame.len())? != frame {
        return Err(bad("field wire frame"));
    }
    let context = c.fixed32()?;
    let body = match c.byte()? {
        0 => {
            let mut digits = vec![];
            loop {
                let v = c.byte()?;
                digits.push(v);
                if v == 255 {
                    break;
                }
            }
            let mut r = crate::codec::Reader::new(&digits)?;
            let gate = usize::try_from(r.nat()?.value()?).map_err(|_| bad("gate index"))?;
            r.finish()?;
            Body::Opening {
                gate,
                holder: c.u16()?,
                phase: get_phase(&mut c)?,
            }
        }
        1 => Body::Bits {
            holder: c.u16()?,
            phase: get_phase(&mut c)?,
        },
        _ => return Err(bad("field wire tag")),
    };
    c.finish()?;
    let m = Message { context, body };
    if encode_message(&m) != b {
        return Err(bad("field wire canonical"));
    }
    Ok(m)
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use std::collections::VecDeque;
    pub(crate) fn g() -> Generation {
        Generation {
            invocation: Nat::new(800),
            command: vec![1],
            attempt: Nat::new(0),
            generation: Nat::new(1),
            configuration: Nat::new(7),
        }
    }
    pub(crate) fn inputs(x: Field, y: Field) -> Vec<Vec<InputRef>> {
        let generation = g();
        let mut ns = (0..4)
            .map(|me| AcssId::new(me, 0, 4, 1, &generation, 2).unwrap())
            .collect::<Vec<_>>();
        let mut q = ns[0]
            .dealer(&[vec![x, Field(71)], vec![y, Field(29)]], [19; 32])
            .unwrap()
            .into_iter()
            .map(|p| (0, p))
            .collect::<VecDeque<_>>();
        while let Some((sender, p)) = q.pop_front() {
            let to = p.to;
            q.extend(
                ns[to as usize]
                    .receive(sender, p.message)
                    .unwrap()
                    .into_iter()
                    .map(|p| (to, p)),
            );
        }
        ns.into_iter()
            .map(|state| {
                vec![
                    InputRef::new(state.clone(), generation.clone(), 0).unwrap(),
                    InputRef::new(state, generation.clone(), 1).unwrap(),
                ]
            })
            .collect()
    }
    fn plan(checked: &CheckedTriples, inputs: &[InputRef]) -> Plan {
        let manifest = TripleManifest::from_checked(checked);
        Plan {
            generation: manifest.generation.clone(),
            network: Network {
                input_count: 2,
                gates: vec![
                    Op::Constant(true),
                    Op::Xor(0, 2),
                    Op::And(0, 3),
                    Op::Xor(1, 2),
                    Op::And(1, 5),
                    Op::And(0, 1),
                ],
                outputs: vec![7],
            },
            public_ticks: 1,
            binding_bytes: binding_many(
                &[checked],
                inputs,
                b"public source-program/input schema fixture",
            )
            .unwrap(),
            rows: (0..manifest.count.min(3))
                .map(|i| manifest.row(i).unwrap())
                .collect(),
        }
    }
    pub(crate) fn engine_nodes(
        x: Field,
        y: Field,
    ) -> (
        Vec<Engine>,
        Vec<super::super::triple_king::tests::AnchorFixture>,
    ) {
        let checked = triple_king::tests::checked_for_consumer(3);
        let input = inputs(x, y);
        let mut engines = vec![];
        let mut anchors = vec![];
        let expected = TripleManifest::from_checked(&checked[0]).pool_id();
        for i in 0..4 {
            assert_eq!(
                TripleManifest::from_checked(&checked[i]).pool_id(),
                expected,
                "common public inventory across distinct secret holder shares"
            );
            let (anchor, sock, root) =
                triple_king::tests::evaluator_anchor(&format!("field-network-{i}"));
            let p = plan(&checked[i], &input[i]);
            let engine = Engine::reserve(
                p.clone(),
                &checked[i],
                input[i].clone(),
                b"public source-program/input schema fixture",
                &sock,
                &root.join("app-burn"),
            )
            .unwrap();
            let journal =
                crate::codec::Journal::decode(&crate::custody::rpc(&sock, &[0]).unwrap()).unwrap();
            assert_eq!(
                journal.allocations.len(),
                3,
                "all prefix ANDs and final AND burned together"
            );
            assert!(Engine::reserve(
                p,
                &checked[i],
                input[i].clone(),
                b"public source-program/input schema fixture",
                &sock,
                &root.join("retry")
            )
            .is_err());
            engines.push(engine);
            anchors.push(anchor);
        }
        (engines, anchors)
    }
    #[test]
    fn independent_checked_inventories_burn_selected_rows_and_leave_unselected_tails_unused() {
        let a = triple_king::tests::checked_inventory(2, 31);
        let b = triple_king::tests::checked_inventory(2, 32);
        let input = inputs(Field(1), Field(1));
        let source = b"public complete multi-inventory program profile";
        let mut ns = vec![];
        let mut anchors = vec![];
        let mut exact = None;
        for i in 0..4 {
            let stocks = [&a[i], &b[i]];
            let mut p = plan(&a[i], &input[i]);
            p.generation = g();
            p.binding_bytes = binding_many(&stocks, &input[i], source).unwrap();
            p.rows = vec![
                TripleManifest::from_checked(&a[i]).row(0).unwrap(),
                TripleManifest::from_checked(&a[i]).row(1).unwrap(),
                TripleManifest::from_checked(&b[i]).row(1).unwrap(),
            ];
            if let Some(ref bytes) = exact {
                assert_eq!(
                    bytes,
                    &p.encode(),
                    "full common Plan across distinct holder shares"
                );
            } else {
                exact = Some(p.encode());
            }
            let (anchor, sock, root) = triple_king::tests::evaluator_anchor(&format!("many-{i}"));
            let engine = Engine::reserve_many(
                p.clone(),
                &stocks,
                input[i].clone(),
                source,
                &sock,
                &root.join("burn"),
            )
            .unwrap();
            let j =
                crate::codec::Journal::decode(&crate::custody::rpc(&sock, &[0]).unwrap()).unwrap();
            assert_eq!(j.spent.len(), 3);
            assert!(!j
                .spent
                .contains(&TripleManifest::from_checked(&b[i]).row(0).unwrap()));
            let mut changed = p;
            changed.generation.attempt = Nat::new(77);
            assert!(
                Engine::reserve_many(
                    changed,
                    &stocks,
                    input[i].clone(),
                    source,
                    &sock,
                    &root.join("retry")
                )
                .is_err(),
                "changing consumer generation cannot reuse any selected original tuple"
            );
            ns.push(engine);
            anchors.push(anchor);
        }
        // Reusing a typed post-burn stock still repeats its original seed identities.
        assert!(binding_many(&[&a[0], &a[0]], &input[0], source).is_err());
    }
    #[test]
    fn multi_inventory_all_rows_burn_before_incomplete_input_and_bad_holder_refuses() {
        let a = triple_king::tests::checked_inventory(2, 33);
        let b = triple_king::tests::checked_inventory(2, 34);
        let incomplete = AcssId::new(0, 0, 4, 1, &g(), 2).unwrap();
        let input = vec![
            InputRef::new(incomplete.clone(), g(), 0).unwrap(),
            InputRef::new(incomplete, g(), 1).unwrap(),
        ];
        let stocks = [&a[0], &b[0]];
        let source = b"fixed multi-stock refusal capacity";
        let mut p = plan(&a[0], &input);
        p.generation = g();
        p.binding_bytes = binding_many(&stocks, &input, source).unwrap();
        p.rows = vec![
            TripleManifest::from_checked(&a[0]).row(0).unwrap(),
            TripleManifest::from_checked(&a[0]).row(1).unwrap(),
            TripleManifest::from_checked(&b[0]).row(0).unwrap(),
        ];
        let (_anchor, sock, root) = triple_king::tests::evaluator_anchor("many-incomplete");
        let wrong = [&a[0], &b[1]];
        assert!(Engine::reserve_many(
            p.clone(),
            &wrong,
            input.clone(),
            source,
            &sock,
            &root.join("wrong")
        )
        .is_err());
        assert!(
            crate::codec::Journal::decode(&crate::custody::rpc(&sock, &[0]).unwrap())
                .unwrap()
                .spent
                .is_empty()
        );
        let e = Engine::reserve_many(
            p.clone(),
            &stocks,
            input.clone(),
            source,
            &sock,
            &root.join("burn"),
        )
        .err()
        .unwrap();
        assert_eq!(e.kind(), ErrorKind::WouldBlock);
        let j = crate::codec::Journal::decode(&crate::custody::rpc(&sock, &[0]).unwrap()).unwrap();
        assert_eq!(
            j.spent.len(),
            3,
            "all inventories burn before the FIRST accepted getter"
        );
        assert!(p.rows.iter().all(|r| j.spent.contains(r)));
        assert!(
            Engine::reserve_many(p, &stocks, input, source, &sock, &root.join("retry")).is_err()
        );
    }
}
