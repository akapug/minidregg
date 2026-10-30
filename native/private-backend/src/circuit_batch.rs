//! Canonical native PrivateCircuitAllocation plan codec and assignments.
//! The rows burn at the anchor through `field_network::Engine::reserve*`.
use crate::codec::{bad, bytes, Correlation, Generation, Nat, Reader};
use std::{collections::BTreeSet, io::Result};
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum Op {
    Constant(bool),
    Xor(u64, u64),
    And(u64, u64),
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Network {
    pub input_count: u64,
    pub gates: Vec<Op>,
    pub outputs: Vec<u64>,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Plan {
    pub generation: Generation,
    pub network: Network,
    pub public_ticks: u64,
    pub binding_bytes: Vec<u8>,
    pub rows: Vec<Correlation>,
}
impl Plan {
    pub fn assignments(&self) -> Vec<(u64, usize, &Correlation)> {
        // Material indices depend only on AND gates; each public tick repeats
        // their order. Walk that order once rather than rescanning all gates
        // for every tick, including ticks with no available material.
        let and_gates: Vec<usize> = self
            .network
            .gates
            .iter()
            .enumerate()
            .filter_map(|(gate, op)| matches!(op, Op::And(..)).then_some(gate))
            .collect();
        let mut out = vec![];
        if and_gates.is_empty() {
            return out;
        }
        for (i, row) in self.rows.iter().enumerate() {
            let tick = (i / and_gates.len()) as u64;
            if tick >= self.public_ticks {
                break;
            }
            out.push((tick, and_gates[i % and_gates.len()], row));
        }
        out
    }
    pub fn validate(&self) -> Result<()> {
        if self.network.gates.len() > 65536
            || self.network.input_count > 65536
            || self.public_ticks > 4096
            || self.rows.len() > 65536
            || self.binding_bytes.is_empty()
        {
            return Err(bad("physical circuit capacity/profile"));
        }
        for (i, op) in self.network.gates.iter().enumerate() {
            let bound = self.network.input_count + i as u64;
            if let Op::Xor(a, b) | Op::And(a, b) = op {
                if *a >= bound || *b >= bound {
                    return Err(bad("forward gate operand"));
                }
            }
        }
        let bound = self.network.input_count + self.network.gates.len() as u64;
        if self.network.outputs.iter().any(|i| *i >= bound) {
            return Err(bad("output wire range"));
        }
        let count = self
            .network
            .gates
            .iter()
            .filter(|op| matches!(op, Op::And(..)))
            .count() as u64;
        if self.public_ticks.checked_mul(count) != Some(self.rows.len() as u64) {
            return Err(bad("fixed circuit correlation count"));
        }
        let mut ids = BTreeSet::new();
        for row in &self.rows {
            let mut b = vec![];
            row.put(&mut b);
            if !ids.insert(b) {
                return Err(bad("physical row alias"));
            }
        }
        Ok(())
    }
    pub fn encode(&self) -> Vec<u8> {
        let mut b = vec![];
        bytes(b"DREGG.PRIVATE.CIRCUIT.ALLOCATION\x01", &mut b);
        self.generation.put(&mut b);
        Nat::new(self.network.input_count).put(&mut b);
        Nat::new(self.network.gates.len() as u64).put(&mut b);
        for op in &self.network.gates {
            let (tag, a, c) = match op {
                Op::Constant(false) => (0, 0, 0),
                Op::Constant(true) => (1, 0, 0),
                Op::Xor(a, c) => (2, *a, *c),
                Op::And(a, c) => (3, *a, *c),
            };
            for v in [tag, a, c] {
                Nat::new(v).put(&mut b);
            }
        }
        Nat::new(self.network.outputs.len() as u64).put(&mut b);
        for v in &self.network.outputs {
            Nat::new(*v).put(&mut b);
        }
        Nat::new(self.public_ticks).put(&mut b);
        bytes(&self.binding_bytes, &mut b);
        Nat::new(self.rows.len() as u64).put(&mut b);
        for row in &self.rows {
            row.put(&mut b);
        }
        b
    }
    pub fn decode(b: &[u8]) -> Result<Self> {
        let mut r = Reader::new(b)?;
        if r.bytes()? != b"DREGG.PRIVATE.CIRCUIT.ALLOCATION\x01" {
            return Err(bad("circuit plan frame"));
        }
        let generation = Generation::get(&mut r)?;
        let input_count = r.nat()?.value()?;
        let gate_count = r.count()?;
        if gate_count > 65536 {
            return Err(bad("gate count bound"));
        }
        let mut gates = vec![];
        for _ in 0..gate_count {
            let tag = r.nat()?.value()?;
            let a = r.nat()?.value()?;
            let c = r.nat()?.value()?;
            gates.push(match (tag, a, c) {
                (0, 0, 0) => Op::Constant(false),
                (1, 0, 0) => Op::Constant(true),
                (2, a, c) => Op::Xor(a, c),
                (3, a, c) => Op::And(a, c),
                _ => return Err(bad("noncanonical gate")),
            });
        }
        let outputs_count = r.count()?;
        if outputs_count > 65536 {
            return Err(bad("output count"));
        }
        let mut outputs = vec![];
        for _ in 0..outputs_count {
            outputs.push(r.nat()?.value()?);
        }
        let public_ticks = r.nat()?.value()?;
        let binding_bytes = r.bytes()?;
        let row_count = r.count()?;
        if row_count > 65536 {
            return Err(bad("row count"));
        }
        let mut rows = vec![];
        for _ in 0..row_count {
            rows.push(Correlation::get(&mut r)?);
        }
        r.finish()?;
        let v = Self {
            generation,
            network: Network {
                input_count,
                gates,
                outputs,
            },
            public_ticks,
            binding_bytes,
            rows,
        };
        v.validate()?;
        if v.encode() != b {
            return Err(bad("circuit plan canonical"));
        }
        Ok(v)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    fn g() -> Generation {
        Generation {
            invocation: Nat::from_be(&[255; 32]),
            command: vec![3],
            attempt: Nat::new(0),
            generation: Nat::new(1),
            configuration: Nat::from_be(&[254; 32]),
        }
    }
    fn plan() -> Plan {
        Plan {
            generation: g(),
            network: Network {
                input_count: 2,
                gates: vec![Op::Xor(0, 1), Op::And(0, 2)],
                outputs: vec![3],
            },
            public_ticks: 2,
            binding_bytes: vec![9],
            rows: (0..2)
                .map(|i| Correlation {
                    pool: Nat::new(42),
                    row: Nat::new(i),
                })
                .collect(),
        }
    }
    #[test]
    fn assignments_preserve_reference_order_including_partial_plans() {
        fn reference(p: &Plan) -> Vec<(u64, usize, &Correlation)> {
            let mut out = vec![];
            let mut i = 0;
            for tick in 0..p.public_ticks {
                for (gate, op) in p.network.gates.iter().enumerate() {
                    if matches!(op, Op::And(..)) {
                        if let Some(row) = p.rows.get(i) {
                            out.push((tick, gate, row));
                        }
                        i += 1;
                    }
                }
            }
            out
        }
        for mask in 0..32 {
            for ticks in 0..5 {
                for rows in 0..24 {
                    let mut p = plan();
                    p.network.gates = (0..5)
                        .map(|i| {
                            if mask & (1 << i) != 0 {
                                Op::And(0, 1)
                            } else {
                                Op::Xor(0, 1)
                            }
                        })
                        .collect();
                    p.public_ticks = ticks;
                    p.rows = (0..rows)
                        .map(|row| Correlation {
                            pool: Nat::new(42),
                            row: Nat::new(row),
                        })
                        .collect();
                    assert_eq!(p.assignments(), reference(&p));
                }
            }
        }
    }
    #[test]
    fn xor_only_maximum_profile_needs_no_material_assignments() {
        let mut p = plan();
        p.network.gates = vec![Op::Xor(0, 1); 65536];
        p.public_ticks = 4096;
        p.rows.clear();
        p.validate().unwrap();
        assert!(p.assignments().is_empty());
        // This public method also remains total when an unvalidated plan
        // has no AND gates and an arbitrary tick count or extraneous rows.
        p.public_ticks = u64::MAX;
        p.rows = plan().rows;
        assert!(p.assignments().is_empty());
    }
    #[test]
    fn actual_native_plan_fixture_byte_identity_and_schedule() {
        // Host.PrivateCircuitPlanFixture main ACTUALLY EXECUTED 2026-10-03:
        // JSON SHA e80d449066f9d8e1e2902dd9e63cec0be785eb88517b5e130ef5e2840fb72788.
        // These bytes are generated by the native codec, not this Rust encode.
        let bytes: Vec<u8> = vec![
            33, 255, 68, 82, 69, 71, 71, 46, 80, 82, 73, 86, 65, 84, 69, 46, 67, 73, 82, 67, 85,
            73, 84, 46, 65, 76, 76, 79, 67, 65, 84, 73, 79, 78, 1, 255, 1, 255, 3, 7, 255, 11, 255,
            255, 2, 255, 2, 255, 2, 255, 255, 1, 255, 3, 255, 255, 2, 255, 1, 255, 3, 255, 2, 255,
            1, 255, 9, 2, 255, 42, 255, 255, 42, 255, 1, 255,
        ];
        let p = Plan::decode(&bytes).unwrap();
        assert_eq!(p.encode(), bytes);
        assert_eq!(
            p.generation,
            Generation {
                invocation: Nat::new(0),
                command: vec![3],
                attempt: Nat::new(7),
                generation: Nat::new(11),
                configuration: Nat::new(0)
            }
        );
        assert_eq!(
            p.network,
            Network {
                input_count: 2,
                gates: vec![Op::Xor(0, 1), Op::And(0, 2)],
                outputs: vec![3]
            }
        );
        assert_eq!(p.public_ticks, 2);
        assert_eq!(p.binding_bytes, vec![9]);
        assert_eq!(
            p.rows,
            vec![
                Correlation {
                    pool: Nat::new(42),
                    row: Nat::new(0)
                },
                Correlation {
                    pool: Nat::new(42),
                    row: Nat::new(1)
                }
            ]
        );
        assert_eq!(
            p.assignments()
                .iter()
                .map(|(tick, gate, _)| (*tick, *gate))
                .collect::<Vec<_>>(),
            vec![(0, 1), (1, 1)]
        );
    }
    #[test]
    fn exact_circuit_plan_order_count_aliases_and_unchanged_generation() {
        let p = plan();
        assert_eq!(Plan::decode(&p.encode()).unwrap(), p);
        assert_eq!(
            p.assignments()
                .iter()
                .map(|(tick, gate, _)| (*tick, *gate))
                .collect::<Vec<_>>(),
            vec![(0, 1), (1, 1)]
        );
        let mut wrong = p.clone();
        wrong.rows[1] = wrong.rows[0].clone();
        assert!(wrong.validate().is_err());
        let mut wrong = p.clone();
        wrong.network.gates[0] = Op::Xor(3, 1);
        assert!(wrong.validate().is_err());
        let mut wrong = p.clone();
        wrong.public_ticks = 3;
        assert!(wrong.validate().is_err());
        let mut trailing = p.encode();
        trailing.push(0);
        assert!(Plan::decode(&trailing).is_err());
        assert_eq!(p.generation.command, vec![3]); // plan lives separately from accepted native command
    }
}
