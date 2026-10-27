//! The one typed per-prompt outcome record (gr §4.3). The controller writes
//! it at the moment a Hermes prompt ends, once, next to the prompt's other
//! retained artifacts in `stateDir`. It is the only input to resident
//! failed-prompt reconciliation, to a resident request's terminal status and
//! to automatic effects acknowledgement: nothing downstream infers an outcome
//! from presentation labels, note prefixes or process liveness.
//!
//! Three states, each decided by the controller at the prompt boundary:
//! * `admitted`: the turn ended `end_turn` and the parent hold settled; the
//!   receipt fields name what was settled.
//! * `refused`: the turn is decided and closed without a deliverable result
//!   (a typed turn failure at a settled boundary, a setup failure settled at
//!   zero, a preadmission refusal, or a controller refusal that left no
//!   retained custody). `reason` is the decoded reason.
//! * `undecided`: custody is still retained. `retry` names the exact admin
//!   commands, in order, that resolve it and the operation they act on. An
//!   undecided record is never read as refused.
use crate::*;

pub(crate) const KIND: &str = "mini-prompt-outcome-v1";

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct Record {
    #[serde(rename = "type")]
    pub(crate) kind: String,
    pub(crate) prompt_operation_id: u64,
    pub(crate) resident_prompt_id: Option<String>,
    pub(crate) prompt_sha256: Option<String>,
    pub(crate) session_id: Option<String>,
    pub(crate) outcome: Outcome,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "state", rename_all = "kebab-case", deny_unknown_fields)]
pub(crate) enum Outcome {
    #[serde(rename_all = "camelCase")]
    Admitted {
        stop_reason: String,
        settled_charge: String,
        provider_response_sha256: Option<String>,
        provider_metered_charge: Option<String>,
    },
    #[serde(rename_all = "camelCase")]
    Refused { stage: RefusalStage, reason: String },
    #[serde(rename_all = "camelCase")]
    Undecided { retry: Retry, detail: String },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub(crate) enum RefusalStage {
    /// Refused before the prompt was admitted; no model request was made.
    Preadmission,
    /// The worker or session could not start; the hold settled at zero.
    Setup,
    /// The prompt was admitted and its typed turn failure settled.
    TurnFailure,
    /// The controller refused after allocating the prompt and retained no
    /// custody: no hold, attempt, worker or external-effect note remains.
    Controller,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct Retry {
    /// Exact `grain-runtime admin SOCKET CMD` commands, in order.
    pub(crate) admin: Vec<String>,
    /// The retained native attempt the first command looks up, when one is.
    pub(crate) operation: Option<u64>,
}

impl Record {
    pub(crate) fn is_failed_after_admission(&self) -> bool {
        matches!(self.outcome, Outcome::Refused { stage: RefusalStage::TurnFailure, .. })
    }
    pub(crate) fn validate(&self) -> Result<()> {
        let digest = |v: &Option<String>| v.as_ref().is_none_or(|s| resident_origin::valid_digest(s));
        let ok = self.kind == KIND
            && self.prompt_operation_id > 0
            && digest(&self.resident_prompt_id)
            && digest(&self.prompt_sha256)
            && self.resident_prompt_id.is_some() == self.prompt_sha256.is_some()
            && self.session_id.as_ref().is_none_or(|s| !s.is_empty() && s.len() <= 128)
            && match &self.outcome {
                Outcome::Admitted { stop_reason, settled_charge, .. } => {
                    stop_reason == "end_turn" && decimal_text(settled_charge)
                }
                Outcome::Refused { reason, .. } => !reason.is_empty() && reason.len() <= 4096,
                Outcome::Undecided { retry, detail } => {
                    !retry.admin.is_empty()
                        && retry.admin.iter().all(|c| admin_command(c))
                        && detail.len() <= 4096
                }
            };
        if ok { Ok(()) } else { Err("prompt outcome record is malformed".into()) }
    }
}

fn decimal_text(s: &str) -> bool {
    !s.is_empty() && s.bytes().all(|b| b.is_ascii_digit()) && (s == "0" || !s.starts_with('0'))
}

/// The admin verbs an undecided prompt may name. Each resolves retained
/// custody by exact lookup or operator audit; none resubmits the prompt.
fn admin_command(c: &str) -> bool {
    matches!(c, "recover" | "reconcile parent audited" | "reconcile tool audited"
        | "reconcile provider audited" | "reconcile worker audited" | "reconcile effects")
}

pub(crate) fn path(state_dir: &Path, prompt: u64) -> PathBuf {
    state_dir.join(format!("prompt-outcome-{prompt:016}.json"))
}

/// Write once. A second write must carry identical bytes; a differing record
/// for the same prompt is refused (the first decision stands).
pub(crate) fn write(state_dir: &Path, record: &Record) -> Result<()> {
    record.validate()?;
    let bytes = serde_json::to_vec_pretty(record).map_err(|e| e.to_string())?;
    let target = path(state_dir, record.prompt_operation_id);
    match fs::symlink_metadata(&target) {
        Ok(_) => {
            if bounded_regular_file(&target, 65_536)? == bytes {
                return Ok(());
            }
            Err(format!("prompt {} already has a different outcome record", record.prompt_operation_id))
        }
        Err(e) if e.kind() == io::ErrorKind::NotFound => {
            journal_io::write(&target, &bytes).map_err(|e| format!("prompt outcome record: {e}"))
        }
        Err(e) => Err(format!("prompt outcome record: {e}")),
    }
}

pub(crate) fn read(state_dir: &Path, prompt: u64) -> Result<Option<Record>> {
    let target = path(state_dir, prompt);
    match fs::symlink_metadata(&target) {
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(format!("prompt outcome record: {e}")),
        Ok(meta) => {
            if !meta.is_file() || meta.uid() != unsafe { libc::geteuid() } || meta.mode() & 0o077 != 0 {
                return Err("prompt outcome record must be an owned private regular file".into());
            }
            let record: Record = serde_json::from_slice(&bounded_regular_file(&target, 65_536)?)
                .map_err(|e| format!("prompt outcome record: {e}"))?;
            record.validate()?;
            if record.prompt_operation_id != prompt {
                return Err("prompt outcome record names another prompt".into());
            }
            Ok(Some(record))
        }
    }
}

/// Read the record bound to an exact resident origin. Absent is an error for
/// callers that need a decision: absence is never a refusal.
pub(crate) fn read_bound(state_dir: &Path, prompt: u64, resident_prompt_id: &str, prompt_sha256: &str) -> Result<Record> {
    let record = read(state_dir, prompt)?
        .ok_or_else(|| format!("prompt {prompt} has no outcome record; it is undecided until the controller writes one"))?;
    if record.resident_prompt_id.as_deref() != Some(resident_prompt_id)
        || record.prompt_sha256.as_deref() != Some(prompt_sha256) {
        return Err("prompt outcome record binds another resident prompt".into());
    }
    Ok(record)
}

/// The exact retry for retained custody, in the order an operator runs it.
/// `None` means the journal retains nothing for this prompt.
pub(crate) fn retry_for(journal: &Journal) -> Option<Retry> {
    let mut admin = Vec::new();
    let mut operation = None;
    if let Some(pending) = &journal.pending {
        operation = Some(pending.operation_id);
        admin.push("recover".to_owned());
    }
    if journal.child.is_some() {
        admin.push("reconcile worker audited".to_owned());
    }
    if journal.provider_pending.is_some() || journal.provider_hold.is_some() || journal.provider_attempt.is_some() {
        admin.push("reconcile provider audited".to_owned());
    }
    if journal.parent_hold.is_some() || journal.settlement_due.is_some() {
        admin.push("reconcile parent audited".to_owned());
    }
    if journal.tool_hold.is_some() || journal.tool_pending.is_some() {
        admin.push("reconcile tool audited".to_owned());
    }
    if journal.workspace_attempt.is_some() || journal.room_attempt.is_some() {
        if !admin.iter().any(|c| c == "recover") { admin.insert(0, "recover".to_owned()); }
    }
    if !journal.unresolved_external.is_empty() {
        admin.push("reconcile effects".to_owned());
    }
    (!admin.is_empty()).then_some(Retry { admin, operation })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn record(outcome: Outcome) -> Record {
        Record { kind: KIND.into(), prompt_operation_id: 42, resident_prompt_id: Some("a".repeat(64)),
            prompt_sha256: Some("b".repeat(64)), session_id: Some("s".into()), outcome }
    }

    #[test]
    fn undecided_record_names_its_retry_and_is_never_refused() {
        let dir = std::env::temp_dir().join(format!("prompt-outcome-{}", std::process::id()));
        fs::create_dir_all(&dir).unwrap();
        fs::set_permissions(&dir, fs::Permissions::from_mode(0o700)).unwrap();
        let undecided = record(Outcome::Undecided {
            retry: Retry { admin: vec!["reconcile parent audited".into(), "reconcile effects".into()], operation: None },
            detail: "ACP stream closed".into() });
        write(&dir, &undecided).unwrap();
        let back = read_bound(&dir, 42, &"a".repeat(64), &"b".repeat(64)).unwrap();
        assert_eq!(back, undecided);
        assert!(!back.is_failed_after_admission());
        let text = fs::read_to_string(path(&dir, 42)).unwrap();
        assert!(text.contains("\"state\": \"undecided\"") && text.contains("reconcile parent audited"));
        // The first decision stands: a later refused record for the same prompt is refused.
        let refused = record(Outcome::Refused { stage: RefusalStage::TurnFailure, reason: "format_error".into() });
        assert!(write(&dir, &refused).is_err());
        write(&dir, &undecided).unwrap();
        // Undecided without a retry, or with a resubmitting verb, does not validate.
        let mut empty = undecided.clone();
        empty.outcome = Outcome::Undecided { retry: Retry { admin: vec![], operation: None }, detail: String::new() };
        assert!(empty.validate().is_err());
        empty.outcome = Outcome::Undecided { retry: Retry { admin: vec!["hermes again".into()], operation: None }, detail: String::new() };
        assert!(empty.validate().is_err());
        // Absence is not a decision.
        assert!(read_bound(&dir, 43, &"a".repeat(64), &"b".repeat(64)).is_err());
        // Another resident prompt's record does not bind.
        assert!(read_bound(&dir, 42, &"c".repeat(64), &"b".repeat(64)).is_err());
        fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn admitted_requires_end_turn_and_a_decimal_charge() {
        let ok = record(Outcome::Admitted { stop_reason: "end_turn".into(), settled_charge: "1".into(),
            provider_response_sha256: None, provider_metered_charge: None });
        ok.validate().unwrap();
        let mut bad = ok.clone();
        bad.outcome = Outcome::Admitted { stop_reason: "cancelled".into(), settled_charge: "1".into(),
            provider_response_sha256: None, provider_metered_charge: None };
        assert!(bad.validate().is_err());
        bad.outcome = Outcome::Admitted { stop_reason: "end_turn".into(), settled_charge: "01".into(),
            provider_response_sha256: None, provider_metered_charge: None };
        assert!(bad.validate().is_err());
        let refused = record(Outcome::Refused { stage: RefusalStage::TurnFailure, reason: "format_error".into() });
        assert!(refused.is_failed_after_admission());
    }
}
