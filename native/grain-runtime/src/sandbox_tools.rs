//! Upstream Hermes's file, terminal and Python tools inside the worker
//! (docs/HERMES-TOOLS-2026-10-27.md). The operator's `controller.json`
//! `sandbox` block is the ceiling; the room's `hermes/tools` grant, carried in
//! the resident's digest-bound assignment, chooses within it; the controller
//! grants the intersection per resident prompt, launches the worker with the
//! class bounds and a fresh /scratch, and admits the session only when Hermes
//! reports exactly the Mini catalogue plus the granted toolsets' names.
use crate::*;

/// The toolsets, in grant order, with upstream Hermes Agent 6d8a8beb's tool
/// names (`toolsets.py`) and the room's `hermes/tools` bit.
pub(crate) const TOOLSETS: &[(&str, u64, &[&str])] = &[
    ("file", 1, &["read_file", "write_file", "patch", "search_files"]),
    ("terminal", 2, &["terminal", "process_manage"]),
    ("code_execution", 4, &["execute_code"]),
];

#[derive(Clone, Serialize, Deserialize, Debug, PartialEq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct Sandbox {
    /// The most any room may enable: names from `TOOLSETS`.
    pub tools: Vec<String>,
    /// The per-worker /scratch tmpfs (S 16, M 64, L 128 MiB).
    pub scratch_mib: u64,
    /// The worker unit's MemoryMax (`512M`, `1G`, `2G`...).
    pub memory_max: String,
    pub tasks_max: u64,
    pub cpu_weight: u64,
    /// CPUQuota in percent of one core.
    pub cpu_quota_percent: u64,
    /// Hermes's own per-tool-call timeout (terminal, code execution).
    pub tool_call_seconds: u64,
    /// Sandbox CPU seconds per paid `hermes/turn` when the room names none.
    pub compute_seconds_per_turn: u64,
}

impl Sandbox {
    /// The class bounds: memory, tasks and CPU weight of `spk-host`'s size classes; scratch
    /// much smaller than an app volume (a resident's working area, not its storage).
    pub(crate) fn for_class(class: &str) -> Result<Self> {
        let (scratch_mib, memory_max, tasks_max, cpu_weight) = match class {
            "S" => (16, "512M", 256, 50),
            "M" => (64, "1G", 512, 100),
            "L" => (128, "2G", 1024, 200),
            _ => return Err("grain class must be S, M or L".into()),
        };
        Ok(Self { tools: TOOLSETS.iter().map(|(n, ..)| (*n).to_owned()).collect(), scratch_mib,
            memory_max: memory_max.into(), tasks_max, cpu_weight, cpu_quota_percent: 100,
            tool_call_seconds: 120, compute_seconds_per_turn: 10 })
    }

    pub(crate) fn validate(&self) -> Result<()> {
        let mut seen = std::collections::BTreeSet::new();
        for tool in &self.tools {
            if !TOOLSETS.iter().any(|(n, ..)| n == tool) || !seen.insert(tool) {
                return Err(format!("sandbox.tools names an unknown or repeated toolset: {tool}"));
            }
        }
        let memory_ok = self.memory_max.len() <= 6 && match self.memory_max.split_at(self.memory_max.len().saturating_sub(1)) {
            (n, "M") => n.parse::<u64>().is_ok_and(|n| (64..=8192).contains(&n)),
            (n, "G") => n.parse::<u64>().is_ok_and(|n| (1..=8).contains(&n)),
            _ => false,
        };
        if !(1..=4096).contains(&self.scratch_mib) || !memory_ok || !(16..=1024).contains(&self.tasks_max)
            || !(1..=1000).contains(&self.cpu_weight) || !(1..=800).contains(&self.cpu_quota_percent)
            || !(1..=1800).contains(&self.tool_call_seconds) || !(1..=3600).contains(&self.compute_seconds_per_turn) {
            return Err("sandbox bounds outside scratchMib 1..4096, memoryMax 64M..8G, tasksMax 16..1024, cpuWeight 1..1000, cpuQuotaPercent 1..800, toolCallSeconds 1..1800, computeSecondsPerTurn 1..3600".into());
        }
        Ok(())
    }

    /// The toolsets granted to one prompt: the ceiling ∩ the room's grant, in
    /// `TOOLSETS` order. A prompt that is not a resident's gets none.
    pub(crate) fn grant(&self, prompt: Option<&str>) -> Vec<&'static str> {
        let Some(room) = prompt.and_then(room_grant) else { return Vec::new() };
        TOOLSETS.iter()
            .filter(|(name, bit, _)| room & bit != 0 && self.tools.iter().any(|t| t == name))
            .map(|(name, ..)| *name).collect()
    }

    /// The launcher's environment for a granted worker.
    pub(crate) fn environment(&self, command: &mut Command) {
        command.env("MINI_GRAIN_SCRATCH_MIB", self.scratch_mib.to_string())
            .env("MINI_GRAIN_MEMORY_MAX", &self.memory_max)
            .env("MINI_GRAIN_TASKS_MAX", self.tasks_max.to_string())
            .env("MINI_GRAIN_CPU_WEIGHT", self.cpu_weight.to_string())
            .env("MINI_GRAIN_CPU_QUOTA", self.cpu_quota_percent.to_string());
    }
}

/// The room's `hermes/tools` bitmask as the resident read it into the
/// assignment (`sandboxTools`), from the prompt the controller was handed.
fn room_grant(prompt: &str) -> Option<u64> {
    let assignment: Value = serde_json::from_str(prompt.strip_prefix(room_resident::ASSIGNMENT_PREFIX)?).ok()?;
    assignment.get("sandboxTools")?.as_u64().filter(|bits| *bits <= 15)
}

/// The room's `hermes/tools` bit 8: the oracle (Oracle tools through the operator's lifetime
/// route), granted per room like the sandbox toolsets.
pub(crate) const ORACLE_BIT: u64 = 8;
pub(crate) fn oracle_granted(prompt: Option<&str>) -> bool {
    prompt.and_then(room_grant).is_some_and(|bits| bits & ORACLE_BIT != 0)
}

/// The exact upstream names the granted toolsets add to the catalogue.
pub(crate) fn names(granted: &[&str]) -> Vec<String> {
    TOOLSETS.iter().filter(|(n, ..)| granted.contains(n))
        .flat_map(|(_, _, names)| names.iter().map(|n| (*n).to_owned())).collect()
}

/// The `hermes-acp` arguments that ask the worker for the granted toolsets
/// and Hermes's own per-call timeout; none when nothing is granted.
pub(crate) fn worker_arguments(granted: &[&str], tool_call_seconds: u64) -> Vec<String> {
    if granted.is_empty() { return Vec::new(); }
    vec![format!("--mini-sandbox-tools={}", granted.join(",")), format!("--mini-tool-seconds={tool_call_seconds}")]
}

/// The CPU the launch gate recorded for a worker unit (`STATE/UNIT.cpu`),
/// or None when the gate wrote none.
pub(crate) fn recorded_cpu_usec(state_dir: &Path, unit: &str) -> Result<Option<u64>> {
    let path = state_dir.join(format!("{unit}.cpu"));
    if !path.try_exists().map_err(|e| e.to_string())? { return Ok(None); }
    let text = String::from_utf8(bounded_regular_file(&path, 64)?).map_err(|e| e.to_string())?;
    text.strip_prefix("mini-grain-cpu-v1 ").and_then(|n| n.strip_suffix('\n'))
        .and_then(|n| n.parse::<u64>().ok()).map(Some)
        .ok_or_else(|| format!("{} is not a gate CPU record", path.display()))
}

/// Paid compute turns for `usec` of sandbox CPU at `seconds` per turn.
pub(crate) fn compute_turns(usec: u64, seconds: u64) -> u64 {
    usec.div_ceil(seconds.max(1).saturating_mul(1_000_000))
}

#[cfg(test)]
mod tests {
    use super::*;
    fn prompt(bits: Value) -> String { format!("{}{}", room_resident::ASSIGNMENT_PREFIX, json!({"sandboxTools":bits})) }

    #[test]
    fn a_prompt_gets_the_ceiling_meet_the_room_grant() {
        let mut sandbox = Sandbox::for_class("M").unwrap();
        sandbox.validate().unwrap();
        assert_eq!(sandbox.grant(Some(&prompt(json!(7)))), vec!["file", "terminal", "code_execution"]);
        assert_eq!(sandbox.grant(Some(&prompt(json!(5)))), vec!["file", "code_execution"]);
        sandbox.tools = vec!["file".into()];
        assert_eq!(sandbox.grant(Some(&prompt(json!(7)))), vec!["file"]);
        assert!(sandbox.grant(Some(&prompt(json!(2)))).is_empty(), "the ceiling withholds the terminal");
        assert!(sandbox.grant(Some(&prompt(json!(8)))).is_empty(), "the oracle bit grants no sandbox toolset");
        assert!(sandbox.grant(Some(&prompt(json!(16)))).is_empty(), "an out-of-range grant is none");
        assert!(oracle_granted(Some(&prompt(json!(8)))) && oracle_granted(Some(&prompt(json!(15)))));
        assert!(!oracle_granted(Some(&prompt(json!(7)))) && !oracle_granted(Some(&prompt(json!(16)))) && !oracle_granted(None));
        assert!(sandbox.grant(Some("Assignment: {}")).is_empty());
        assert!(sandbox.grant(None).is_empty(), "a non-resident prompt gets none");
    }

    #[test]
    fn names_are_exactly_the_granted_toolsets() {
        assert_eq!(names(&["terminal"]), vec!["terminal", "process_manage"]);
        assert_eq!(names(&["file", "code_execution"]).len(), 5);
        assert!(names(&[]).is_empty());
        assert_eq!(worker_arguments(&["file", "terminal"], 120),
            vec!["--mini-sandbox-tools=file,terminal", "--mini-tool-seconds=120"]);
        assert!(worker_arguments(&[], 120).is_empty());
    }

    #[test]
    fn sandbox_bounds_refuse_unknown_tools_and_wide_limits() {
        let mut s = Sandbox::for_class("S").unwrap();
        s.tools.push("browser".into());
        assert!(s.validate().is_err());
        let mut s = Sandbox::for_class("L").unwrap();
        s.memory_max = "16G".into();
        assert!(s.validate().is_err());
        assert!(Sandbox::for_class("XL").is_err());
    }

    #[test]
    fn compute_turns_round_up_per_block() {
        assert_eq!(compute_turns(0, 10), 0);
        assert_eq!(compute_turns(1, 10), 1);
        assert_eq!(compute_turns(10_000_000, 10), 1);
        assert_eq!(compute_turns(10_000_001, 10), 2);
    }
}

/// The worker's persistent `/workspace` (Hermes's home) has no total quota of
/// its own; a prompt with sandbox tools is refused while it holds more than
/// the class volume, so one run can overshoot by at most its own bounded
/// writes and never compounds (docs/HERMES-TOOLS-2026-10-27.md §2).
pub(crate) fn require_workspace_volume(workspace: &Path, volume_mib: u64) -> Result<()> {
    let used = allocated_bytes(workspace, &mut 0)?;
    if used > volume_mib.saturating_mul(1 << 20) {
        return Err(format!("workspace-over-class-volume: {} holds {used} bytes, over the {volume_mib} MiB class volume; \
            nothing from the scratch persists there by design", workspace.display()));
    }
    Ok(())
}

fn allocated_bytes(dir: &Path, entries: &mut u64) -> Result<u64> {
    use std::os::unix::fs::MetadataExt;
    let mut total = 0u64;
    for entry in fs::read_dir(dir).map_err(|e| format!("workspace volume: {e}"))? {
        *entries += 1;
        if *entries > 1_000_000 { return Err("workspace-over-class-volume: more than a million entries".into()); }
        let entry = entry.map_err(|e| format!("workspace volume: {e}"))?;
        let meta = entry.path().symlink_metadata().map_err(|e| format!("workspace volume: {e}"))?;
        total = total.saturating_add(meta.blocks().saturating_mul(512));
        if meta.is_dir() { total = total.saturating_add(allocated_bytes(&entry.path(), entries)?); }
    }
    Ok(total)
}
