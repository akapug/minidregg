//! Input secrecy against one honest-but-curious party, checked on the recorded
//! transcript of the width-8 private adder.
//!
//! Holder 0 privately deals `left`, holder 2 privately deals `right`; holder 1 is
//! the only output recipient; holder 0 is the King. Holder 3 (CURIOUS) follows
//! the protocol and logs every message delivered to it, in order, across the
//! input ACSS, the King preprocessing ACSS/Sh2t, the King, the layered MPC and
//! the recipient-output phase.
//!
//! The check is a constructed alternative world. From world A's honest
//! randomness the simulator below builds world B with DIFFERENT inputs (and the
//! same sum, so the output phase is comparable too): every honest dealing
//! polynomial is moved by delta*L(X) with L(0)=1, L(alpha_3)=0, so holder 3's
//! points never move, and the King extraction/check randomness is moved so that
//! every opened value (DN products, masked check points, challenge, check
//! polynomials, every MPC opening and bit check) is unchanged. World B is then
//! RUN through the actual protocol, and holder 3's two transcripts are compared
//! frame by frame.
//!
//! What equality covers: every frame except two classes, which are asserted to
//! be the only differences —
//!   * PrivSend ciphertexts of ACSS rows addressed to OTHER holders: a SHA-256
//!     pad keyed by an ASKS key of which holder 3 holds one degree-f share;
//!   * dZK column-proof frames: salted Merkle roots and challenge-dependent folds.
//! Their hiding is the classical-ROM property of those components; this test
//! does not simulate them. So the statement is: holder 3's view, apart from
//! ROM-hidden frames, is byte-for-byte consistent with at least two distinct
//! input pairs. That is not a simulator proof, and says nothing about the King's
//! (holder 0's) richer view, a malicious party, or a coalition.
#![cfg(any(test, feature = "demo"))]
#![cfg_attr(not(test), allow(dead_code, unused_imports))]
use crate::{
    acss_id::{self, AcssId},
    arithmetic_reference::tests::{completed_private_inputs_with_states, share_inputs, InputParty},
    circuit_batch::{Network, Op, Plan},
    codec::Generation,
    entropy::Entropy,
    private_output_store::tests::{drive_tapped, stores_from_completed_descriptor},
    reconstruction::Field,
    transcript::{Frame, Tap, Wire},
    triple_king::{
        acss_seed_count, per_group,
        tests::{checked_from_material, prepared_from, test_generation, PrepDealing},
    },
};
use std::collections::{BTreeMap, VecDeque};

const CURIOUS: u16 = 3;
const RECIPIENT: u16 = 1;
const COUNT: usize = 32;

fn alpha(holder: u16) -> Field {
    Field(holder as u128 + 1)
}
fn bits(value: u64, width: usize) -> Vec<bool> {
    (0..width).map(|i| (value >> i) & 1 == 1).collect()
}
/// Every wire value of the qualified network in the clear (simulator only).
fn wires(net: &Network, inputs: &[bool]) -> Vec<Field> {
    let mut w = inputs.iter().map(|b| Field(*b as u128)).collect::<Vec<_>>();
    for op in &net.gates {
        let v = match *op {
            Op::Constant(c) => Field(c as u128),
            Op::Xor(a, b) => w[a as usize].add(w[b as usize]),
            Op::And(a, b) => w[a as usize].mul(w[b as usize]),
        };
        w.push(v);
    }
    w
}
/// Per tuple position (k-th AND in gate order, the Schedule assignment): the
/// change of its left and right operand between the two worlds.
fn operand_deltas(net: &Network, a: &[bool], b: &[bool]) -> (Vec<Field>, Vec<Field>) {
    let (wa, wb) = (wires(net, a), wires(net, b));
    let (mut dl, mut dr) = (vec![], vec![]);
    for op in &net.gates {
        if let Op::And(l, r) = *op {
            dl.push(wa[l as usize].add(wb[l as usize]));
            dr.push(wa[r as usize].add(wb[r as usize]));
        }
    }
    (dl, dr)
}
fn lagrange(xs: &[Field], k: usize, t: Field) -> Field {
    let mut num = Field(1);
    let mut den = Field(1);
    for (j, x) in xs.iter().enumerate() {
        if j != k {
            num = num.mul(t.add(*x));
            den = den.mul(xs[k].add(*x));
        }
    }
    num.mul(den.inv().unwrap())
}
/// King extraction exactly as PreparedBasis::reserve_new computes it, applied to
/// the dealers' secrets (constant terms) — the simulator knows honest dealings.
fn extract(dealings: &[PrepDealing], offset: usize, batch: usize, m: usize) -> Vec<Field> {
    let mut out = vec![];
    for index in 0..batch {
        for row in 0..2u32 {
            let v = dealings.iter().enumerate().fold(Field(0), |sum, (col, d)| {
                let a = if row == 0 { Field(1) } else { alpha(col as u16) };
                sum.add(a.mul(d.acss[offset + index][0]))
            });
            out.push(v);
        }
    }
    out.truncate(m);
    out
}
/// SIMULATOR WITNESS for the King preprocessing: given world A's dealings and
/// the required per-tuple changes of a and b (operand deltas), return dealings
/// for world B whose holder-3 points and every opened King value are unchanged
/// while each used triple is a'=a+da, b'=b+db, c'=a'b'.
fn equivocate_preparation(
    a: &[PrepDealing],
    da: &[Field],
    db: &[Field],
) -> Vec<PrepDealing> {
    let batch = per_group(COUNT, 1).unwrap();
    let m = 2 * COUNT + 1;
    assert_eq!(a.len(), 3);
    assert!(a.iter().enumerate().all(|(i, d)| d.dealer == i as u16));
    assert!(a.iter().all(|d| d.acss.len() == acss_seed_count(COUNT, 1).unwrap()));
    let va = extract(a, 0, batch, m);
    let vb = extract(a, batch, batch, m);
    // The public challenge is the sum of the dealers' check secrets; untouched.
    let r = a.iter().fold(Field(0), |s, d| s.add(d.acss[3 * batch][0]));
    let xs = (0..=COUNT).map(|i| Field(i as u128 + 1)).collect::<Vec<_>>();
    assert!(!(1..=m).any(|i| r == Field(i as u128)), "challenge in interpolation set");
    // Tuple k is King index k+1. Index 0 is chosen so the interpolated change
    // F' - F vanishes at the challenge; each mask index i in count+1..=2count
    // follows the change at its point so the opened masked values stay put.
    let complete = |used: &[Field]| -> Vec<Field> {
        let mut d = vec![Field(0); m];
        d[1..=COUNT].copy_from_slice(used);
        let rest = (1..=COUNT).fold(Field(0), |s, k| s.add(d[k].mul(lagrange(&xs, k, r))));
        d[0] = rest.mul(lagrange(&xs, 0, r).inv().unwrap());
        for i in COUNT + 1..m {
            let at = Field(i as u128 + 1);
            d[i] = (0..=COUNT).fold(Field(0), |s, k| s.add(d[k].mul(lagrange(&xs, k, at))));
        }
        let at_r = (0..=COUNT).fold(Field(0), |s, k| s.add(d[k].mul(lagrange(&xs, k, r))));
        assert_eq!(at_r, Field(0));
        d
    };
    let delta_a = complete(da);
    let delta_b = complete(db);
    let delta_r = (0..m)
        .map(|i| {
            let (a1, b1) = (va[i].add(delta_a[i]), vb[i].add(delta_b[i]));
            a1.mul(b1).add(va[i].mul(vb[i]))
        })
        .collect::<Vec<_>>();
    let slope = alpha(CURIOUS).inv().unwrap();
    let three = Field(1).add(alpha(1)).inv().unwrap();
    let mut out = a.to_vec();
    for (offset, delta) in [(0, &delta_a), (batch, &delta_b), (2 * batch, &delta_r)] {
        for index in 0..batch {
            let d0 = delta[2 * index];
            let d1 = if 2 * index + 1 < m { delta[2 * index + 1] } else { Field(0) };
            // Columns 0 (alpha 1) and 1 (alpha 2) absorb (row0,row1) = (d0,d1).
            let s1 = d0.add(d1).mul(three);
            let s0 = d0.add(s1);
            for (col, s) in [(0, s0), (1, s1)] {
                let p = &mut out[col].acss[offset + index];
                p[0] = p[0].add(s);
                p[1] = p[1].add(s.mul(slope));
            }
        }
    }
    let (va2, vb2) = (extract(&out, 0, batch, m), extract(&out, batch, batch, m));
    for k in 0..COUNT {
        assert_eq!(va2[k + 1], va[k + 1].add(da[k]));
        assert_eq!(vb2[k + 1], vb[k + 1].add(db[k]));
    }
    out
}

pub(crate) struct World {
    frames: Vec<Frame>,
    result: Vec<bool>,
    inputs: Vec<Vec<AcssId>>,
}
fn run_world(
    left: &InputParty,
    right: &InputParty,
    preparation: &[PrepDealing],
    output_seed: [u8; 32],
    instance: u64,
) -> World {
    let source = include_bytes!("../fixtures/addition-network-8-plan.bin");
    let network =
        crate::field_network::with_boolean_inputs(&Plan::decode(source).unwrap().network).unwrap();
    let g: Generation = test_generation(300 + 1000 * instance);
    let mut tap = Tap::on(CURIOUS);
    let material = prepared_from(preparation, COUNT, instance, &mut tap);
    let stocks = checked_from_material(material, COUNT, &g, &mut tap)
        .into_iter()
        .map(|s| vec![s])
        .collect::<Vec<_>>();
    let (completed, anchors, inputs) = completed_private_inputs_with_states(
        &[left, right],
        network,
        source,
        &g,
        &stocks,
        &format!("view{instance}"),
        &mut tap,
    );
    let (mut stores, _anchors, _paths) = stores_from_completed_descriptor(
        completed,
        anchors,
        instance,
        b"private-input width8 addition; result to holder 1 only; no native release grant",
    );
    let keys = Entropy::from_seed(output_seed);
    let mut q = VecDeque::new();
    for (holder, s) in stores.iter_mut().enumerate() {
        let mut e = keys.fork(&[holder as u8]);
        q.extend(
            s.as_mut()
                .unwrap()
                .start_with_entropy(&mut e)
                .unwrap()
                .into_iter()
                .map(|p| (holder as u16, p)),
        );
    }
    drive_tapped(&mut stores, &mut q, false, false, &mut tap);
    for (holder, s) in stores.iter_mut().enumerate() {
        q.extend(
            s.as_mut()
                .unwrap()
                .request_delivery()
                .unwrap()
                .into_iter()
                .map(|p| (holder as u16, p)),
        );
    }
    drive_tapped(&mut stores, &mut q, false, false, &mut tap);
    for (holder, s) in stores.iter().enumerate() {
        assert_eq!(
            s.as_ref().unwrap().state().result().is_some(),
            holder as u16 == RECIPIENT
        );
    }
    let result = stores[RECIPIENT as usize]
        .as_ref()
        .unwrap()
        .state()
        .result()
        .unwrap()
        .bits()
        .to_vec();
    World {
        frames: tap.frames,
        result,
        inputs,
    }
}
fn accepted(s: &AcssId) -> Vec<Field> {
    match s.local_sharing() {
        Some(acss_id::LocalSharing::Accepted(v)) => v.shares().to_vec(),
        _ => panic!("input sharing not accepted"),
    }
}
/// Auditor (not the harness path): reconstruct a dealt value from two honest
/// holders' accepted shares.
fn reconstruct(states: &[AcssId], holders: [u16; 2]) -> u64 {
    let points = holders
        .iter()
        .map(|h| (*h, accepted(&states[*h as usize])))
        .collect::<Vec<_>>();
    let polys = acss_id::polynomial(&points, states[0].count).unwrap();
    polys.iter().enumerate().fold(0, |v, (i, p)| {
        assert!(p[0] == Field(0) || p[0] == Field(1));
        v | ((p[0].0 as u64) << i)
    })
}
fn value(result: &[bool]) -> u64 {
    result.iter().enumerate().fold(0, |v, (i, b)| v | ((*b as u64) << i))
}
/// Frames that may differ: ROM-hidden PrivSend ciphertexts of other holders'
/// ACSS rows, and dZK column-proof frames. Everything else must be identical.
fn rom_hidden(frame: &Frame) -> Option<&'static str> {
    let Wire::Acss(m) = &frame.wire else {
        return None;
    };
    match &m.body {
        acss_id::Body::Row { holder, message } if *holder != CURIOUS => match message.body {
            crate::private_send::Body::Cipher(_) => Some("acss-row-cipher(other holder)"),
            _ => None,
        },
        acss_id::Body::Column { .. } => Some("acss-dzk-column"),
        _ => None,
    }
}
/// Compare two curious transcripts; returns per (phase, class) counts.
fn compare(a: &[Frame], b: &[Frame]) -> Result<ViewCounts, String> {
    if a.len() != b.len() {
        return Err("curious transcript length differs".into());
    }
    let mut counts = BTreeMap::new();
    for (i, (x, y)) in a.iter().zip(b).enumerate() {
        if (&x.phase, x.sender) != (&y.phase, y.sender) {
            return Err(format!("frame {i} order differs"));
        }
        let class = if x.wire == y.wire {
            "identical"
        } else {
            let (cx, cy) = (rom_hidden(x), rom_hidden(y));
            if !(cx.is_some() && cx == cy) {
                return Err(format!("frame {i} ({}, from {}) differs outside the ROM-hidden classes", x.phase, x.sender));
            }
            cx.unwrap()
        };
        *counts.entry((x.phase.clone(), class)).or_insert(0) += 1;
    }
    Ok(counts)
}

/// Counts of curious-holder frames per (phase, class) for one alternate world.
pub(crate) type ViewCounts = BTreeMap<(String, &'static str), usize>;

/// World A, dealt once, against which alternate input pairs are run.
pub(crate) struct Dealt {
    width: usize,
    left: InputParty,
    right: InputParty,
    preparation: Vec<PrepDealing>,
    output_seed: [u8; 32],
    instance: u64,
    network: Network,
    a: World,
    pub(crate) a_frames: usize,
    pub(crate) a_result: u64,
}
impl Dealt {
    /// Deal `left` (holder 0) and `right` (holder 2) as width-8 inputs under fresh
    /// randomness from `root` and run the whole protocol on them (world A).
    pub(crate) fn run(root: &Entropy, left: u64, right: u64, instance: u64) -> Result<Self, String> {
        let width = 8;
        if left >> width != 0 || right >> width != 0 {
            return Err("inputs are 8-bit values (0..=255)".into());
        }
        let left_p = InputParty::new(0, left, width, &mut root.fork(b"view/left"));
        let right_p = InputParty::new(2, right, width, &mut root.fork(b"view/right"));
        let preparation = (0..3u16)
            .map(|d| PrepDealing::sample(d, COUNT, false, &mut root.fork(&[b'k', d as u8])))
            .collect::<Vec<_>>();
        let output_seed = root.fork(b"view/output-keys").bytes32();
        let a = run_world(&left_p, &right_p, &preparation, output_seed, instance);
        let a_result = value(&a.result);
        if reconstruct(&a.inputs[0], [0, 1]) != left || reconstruct(&a.inputs[1], [1, 2]) != right {
            return Err("honest holders do not recover the dealt inputs".into());
        }
        if a.frames.is_empty() {
            return Err("the curious holder saw no frames".into());
        }
        let source = include_bytes!("../fixtures/addition-network-8-plan.bin");
        let network = crate::field_network::with_boolean_inputs(&Plan::decode(source).map_err(|e| e.to_string())?.network)
            .map_err(|e| e.to_string())?;
        let a_frames = a.frames.len();
        Ok(Self { width, left: left_p, right: right_p, preparation, output_seed, instance, network, a, a_frames, a_result })
    }
    /// Frames delivered to the curious holder in world A, per phase.
    pub(crate) fn phases(&self) -> BTreeMap<String, usize> {
        let mut out = BTreeMap::new();
        for f in &self.a.frames {
            *out.entry(f.phase.clone()).or_default() += 1;
        }
        out
    }
    /// Re-run the protocol with the inputs replaced by (`l`, `r`) (the sum must be
    /// unchanged) through the equivocation witness, and compare holder 3's two
    /// transcripts frame by frame. `Err` names the first violated check.
    pub(crate) fn alternate(&self, from: (u64, u64), l: u64, r: u64) -> Result<ViewCounts, String> {
        let qualified = |l: u64, r: u64| [bits(l, self.width), bits(r, self.width)].concat();
        if from.0 + from.1 != l + r || (l, r) == from {
            return Err("an alternate pair has the same sum and differs".into());
        }
        let (dl, dr) = operand_deltas(&self.network, &qualified(from.0, from.1), &qualified(l, r));
        if dl.len() != COUNT || !dl.iter().chain(&dr).any(|d| *d != Field(0)) {
            return Err("alternate pair moves no King operand".into());
        }
        let prep_b = equivocate_preparation(&self.preparation, &dl, &dr);
        let left_b = self.left.equivocate(l, CURIOUS);
        let right_b = self.right.equivocate(r, CURIOUS);
        let b = run_world(&left_b, &right_b, &prep_b, self.output_seed, self.instance);
        // World B is genuinely a different execution: honest holders hold
        // sharings of (l, r), and the recipient still decrypts the sum.
        if reconstruct(&b.inputs[0], [0, 1]) != l || reconstruct(&b.inputs[1], [1, 2]) != r {
            return Err("alternate world does not share the alternate inputs".into());
        }
        if accepted(&b.inputs[0][0]) == accepted(&self.a.inputs[0][0]) {
            return Err("alternate world is not a different execution".into());
        }
        if value(&b.result) != self.a_result {
            return Err("recipient output differs between the worlds".into());
        }
        // Holder 3's own input shares are identical: one point below threshold
        // determines neither bit of either input.
        for k in 0..2 {
            if accepted(&b.inputs[k][CURIOUS as usize]) != accepted(&self.a.inputs[k][CURIOUS as usize]) {
                return Err("curious holder input shares moved".into());
            }
        }
        let counts = compare(&self.a.frames, &b.frames)?;
        for phase in ["king-preparation-sh2t", "king", "layer-mpc", "output"] {
            if !counts.contains_key(&(phase.to_string(), "identical")) {
                return Err(format!("{phase} not observed"));
            }
            if counts.keys().any(|(p, c)| p == phase && *c != "identical") {
                return Err(format!("{phase} frames are not all byte-identical"));
            }
        }
        Ok(counts)
    }
}

#[test]
fn curious_holder_view_is_consistent_with_three_input_pairs_and_recipient_gets_256() {
    let root = crate::entropy::test_root();
    let dealt = Dealt::run(&root, 255, 1, 9100).unwrap();
    assert_eq!(dealt.a_result, 256, "recipient decryption of 255+1");
    let mut seen = vec![(255u64, 1u64)];
    for (l, r) in [(1u64, 255u64), (128, 128)] {
        let counts = dealt.alternate((255, 1), l, r).unwrap();
        eprintln!("curious view A=(255,1) vs B=({l},{r}): {} frames", dealt.a_frames);
        for ((phase, class), n) in &counts {
            eprintln!("  {phase:24} {class:32} {n}");
        }
        seen.push((l, r));
    }
    assert_eq!(seen.len(), 3);
}

/// The instrument goes red on the wound it exists to see: under the retired
/// r31 dealing (public degree-1 coefficient 37+i) holder 3 decodes the input
/// from its shares alone; under party-local entropy the same decoder fails.
#[test]
fn retired_public_coefficient_dealing_is_decoded_by_the_curious_holder() {
    let g = test_generation(9200);
    let decode = |shares: &[Field]| -> Option<u64> {
        let mut v = 0;
        for (i, s) in shares.iter().enumerate() {
            let bit = s.add(Field(37 + i as u128).mul(alpha(CURIOUS)));
            if bit != Field(0) && bit != Field(1) {
                return None;
            }
            v |= (bit.0 as u64) << i;
        }
        Some(v)
    };
    let retired = InputParty::retired_public_coefficient_dealing(0, 255, 8);
    let states = share_inputs(&[&retired], &g, &mut Tap::none());
    assert_eq!(decode(&accepted(&states[0][CURIOUS as usize])), Some(255));
    let private = InputParty::new(0, 255, 8, &mut crate::entropy::test_root().fork(b"view/falsifier"));
    let states = share_inputs(&[&private], &g, &mut Tap::none());
    assert_eq!(decode(&accepted(&states[0][CURIOUS as usize])), None);
    assert_eq!(reconstruct(&states[0], [0, 1]), 255);
}

#[test]
fn pin_lagrange_weights() {
    let xs = [Field(1), Field(2), Field(3), Field(4)];
    assert_eq!(lagrange(&xs, 0, Field(0x00000000000000000000000000000000)), Field(0x5555555555555555555555555555557f));
    assert_eq!(lagrange(&xs, 0, Field(0x00000000000000000000000000000009)), Field(0xffffffffffffffffffffffffffffffa8));
    assert_eq!(lagrange(&xs, 0, Field(0xfeedfacefeedfacefeedfacefeedface)), Field(0xa12de536a6462b3bc4c45743c3afcc0a));
    assert_eq!(lagrange(&xs, 2, Field(0x00000000000000000000000000000000)), Field(0xb6db6db6db6db6db6db6db6db6db6def));
    assert_eq!(lagrange(&xs, 2, Field(0x00000000000000000000000000000009)), Field(0xb6db6db6db6db6db6db6db6db6db6da7));
    assert_eq!(lagrange(&xs, 2, Field(0xfeedfacefeedfacefeedfacefeedface)), Field(0xd2b0729fde0972b5b89b46bfb422f7cb));
    assert_eq!(lagrange(&xs, 3, Field(0x00000000000000000000000000000000)), Field(0x1c71c71c71c71c71c71c71c71c71c712));
    assert_eq!(lagrange(&xs, 3, Field(0x00000000000000000000000000000009)), Field(0x49249249249249249249249249249266));
    assert_eq!(lagrange(&xs, 3, Field(0xfeedfacefeedfacefeedfacefeedface)), Field(0xdd734e83230d29897c8b1e4982f56438));
}
