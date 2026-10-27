//! Per-member concurrency (infra's abuse-limits review, edge/demo/ABUSE-LIMITS.md): beside the
//! gateway's 64 connections, one member holds at most `PER_MEMBER` requests to their body at once.
//! A body request may wait up to the body's deadline (120 s), so without this cap a few slow
//! requests from one member could hold every connection; with it, a fifth is refused by name (429)
//! while every other member's requests proceed.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

pub const PER_MEMBER: usize = 4;

#[derive(Clone, Default)]
pub struct InFlight(Arc<Mutex<HashMap<String, usize>>>);

/// Held for the life of one body request; dropping it frees the member's slot.
pub struct Slot {
    table: InFlight,
    name: String,
}

impl InFlight {
    /// A slot for `name`, or None when the member already has `PER_MEMBER` requests in flight.
    pub fn acquire(&self, name: &str) -> Option<Slot> {
        let mut table = self.0.lock().unwrap_or_else(|e| e.into_inner());
        let n = table.entry(name.to_owned()).or_insert(0);
        if *n >= PER_MEMBER {
            return None;
        }
        *n += 1;
        Some(Slot { table: self.clone(), name: name.to_owned() })
    }
}

impl Drop for Slot {
    fn drop(&mut self) {
        let mut table = self.table.0.lock().unwrap_or_else(|e| e.into_inner());
        if let Some(n) = table.get_mut(&self.name) {
            *n = n.saturating_sub(1);
            if *n == 0 {
                table.remove(&self.name);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_fifth_concurrent_request_from_one_member_is_refused_while_another_member_proceeds() {
        let table = InFlight::default();
        let held: Vec<Slot> = (0..PER_MEMBER).map(|_| table.acquire("alice").expect("within the cap")).collect();
        assert!(table.acquire("alice").is_none(), "the fifth is refused");
        let bob = table.acquire("bob");
        assert!(bob.is_some(), "another member's request proceeds");
        drop(held);
        assert!(table.acquire("alice").is_some(), "a finished request frees its slot");
    }
}
