//! Operator capacity policy for controller routes sharing one application.
//! This selects physical budgets, never source grants or caller authority.
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, PartialEq, Eq)]
pub(crate) enum AgentRouteProfile {
    #[default]
    #[serde(rename = "standard-v1")]
    Standard,
    #[serde(rename = "shared-64-v1")]
    Shared64,
}

impl AgentRouteProfile {
    pub(crate) const fn active(self) -> usize {
        match self { Self::Standard => 8, Self::Shared64 => 64 }
    }
    pub(crate) const fn revisions(self) -> usize {
        match self { Self::Standard => 64, Self::Shared64 => 1024 }
    }
    pub(crate) const fn history_bytes(self) -> u64 {
        self.revisions() as u64 * 64 * 1024
    }
}

// START and failed-START recovery must read the same bounded configuration.
pub(crate) const MAX_RESIDENT_CONFIG: u64 =
    16 * 1024 * (crate::resident_route_control::MAX_ROUTES as u64 + 1);

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn operator_route_profiles_are_explicit_and_bounded() {
        assert_eq!(AgentRouteProfile::default().active(), 8);
        let shared: AgentRouteProfile = serde_json::from_str("\"shared-64-v1\"").unwrap();
        assert_eq!((shared.active(), shared.revisions(), shared.history_bytes()),
                   (64, 1024, 64 * 1024 * 1024));
        assert!(serde_json::from_str::<AgentRouteProfile>("\"unlimited\"").is_err());
        assert!(serde_json::from_str::<AgentRouteProfile>("64").is_err());
    }
}
