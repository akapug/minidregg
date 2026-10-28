//! A fresh, source-inspected STOP claim. Receipt-only recovery cannot create one.
//!
//! This module does not fence or stop a unit. The physical path must join this
//! sealed claim to the retained Running journal and volume witness, durably
//! mark the attempt, and perform the checked manager action under that lock.

use crate::dispatch_native::{private_dir, write_new, PrivateOperator};
use crate::lifecycle_v3_native::{decimal, framed_payload, hex};
use crate::lifecycle_v3_stop_native::{ReceiptFields, StopTarget};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::fs::DirBuilder;
use std::io;
use std::os::unix::fs::DirBuilderExt;
use std::path::Path;

const COMMITTED_TAG: &[u8] = b"DREGG/APPLICATION/LIFECYCLE-CLAIM-COMMITTED/v3";
const MAX_FRAME: usize = 12_102_760;
const STOP_INSPECT_OPERATION: u8 = crate::host_operations::APPLICATION_STOP_INSPECT;
const MAX_INSPECTION: u64 = 2 * 1024 * 1024;

fn invalid(reason: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, reason)
}

fn inspection_request(plan: &[u8], committed: &[u8]) -> io::Result<Vec<u8>> {
    let size = plan.len().checked_add(committed.len()).and_then(|n| n.checked_add(4))
        .ok_or_else(|| invalid("STOP inspection request size overflow"))?;
    if plan.is_empty() || committed.is_empty() || size >= MAX_FRAME {
        return Err(invalid("STOP inspection request size refused"));
    }
    let mut request = Vec::with_capacity(size);
    request.extend_from_slice(&(plan.len() as u32).to_le_bytes());
    request.extend_from_slice(plan);
    request.extend_from_slice(committed);
    Ok(request)
}

fn inspection_reply(frame: &[u8]) -> io::Result<&[u8]> {
    let payload = framed_payload("stop inspect", frame, STOP_INSPECT_OPERATION, b"")?;
    if payload.len() as u64 > MAX_INSPECTION {
        return Err(invalid("STOP current source inspection bound refused"));
    }
    let view: Value = serde_json::from_slice(payload)?;
    if view.get("type").and_then(Value::as_str)
        != Some("application-lifecycle-stop-claim-verified-v1")
    {
        return Err(invalid("STOP current source inspection type refused"));
    }
    Ok(payload)
}

/// Ask the exact pinned operator Host to join these retained inputs with its
/// refreshed verifier-minted history. No detached JSON or cached authority is
/// accepted. The request is read-only; callers still compare all returned source
/// identities before the existing physical fence. No automatic retry is made.
pub(crate) fn inspect_current(
    operator: &PrivateOperator,
    plan: &[u8],
    committed: &[u8],
    output: &Path,
) -> io::Result<Vec<u8>> {
    let request = inspection_request(plan, committed)?;
    let frame = operator.invoke(STOP_INSPECT_OPERATION, &request)?;
    let payload = inspection_reply(&frame)?;
    // Retain the same exact inspection artifact as the cold CLI path did.
    let parent = output.parent().ok_or_else(|| invalid("STOP inspection output parent absent"))?;
    let name = output.file_name().and_then(|s| s.to_str())
        .ok_or_else(|| invalid("STOP inspection output name refused"))?;
    write_new(parent, name, payload)?;
    Ok(payload.to_vec())
}

/// Exact native four-field receipt, with no independent authority to stop.
#[derive(Clone)]
pub(crate) struct ExactReceipt {
    transaction_id: String,
    event_id: String,
    accepted_count: String,
    world_root: String,
}

impl ExactReceipt {
    pub(crate) fn new(
        transaction_id: &str,
        event_id: &str,
        accepted_count: &str,
        world_root: &str,
    ) -> io::Result<Self> {
        if [transaction_id, event_id, accepted_count, world_root]
            .iter()
            .any(|value| !decimal(value))
            || accepted_count == "0"
        {
            return Err(invalid("STOP receipt fields are not canonical"));
        }
        Ok(Self {
            transaction_id: transaction_id.to_owned(),
            event_id: event_id.to_owned(),
            accepted_count: accepted_count.to_owned(),
            world_root: world_root.to_owned(),
        })
    }

    fn from_source(value: &Value) -> io::Result<Self> {
        let field = |name| -> io::Result<&str> {
            value
                .get(name)
                .and_then(Value::as_str)
                .ok_or_else(|| invalid("STOP committed receipt field absent"))
        };
        Self::new(
            field("transactionId")?,
            field("eventId")?,
            field("acceptedCount")?,
            field("worldRoot")?,
        )
    }

    fn borrowed(&self) -> ReceiptFields<'_> {
        ReceiptFields {
            transaction_id: &self.transaction_id,
            event_id: &self.event_id,
            accepted_count: &self.accepted_count,
            world_root: &self.world_root,
        }
    }

    pub(crate) fn transaction_id(&self) -> &str {
        &self.transaction_id
    }
    pub(crate) fn event_id(&self) -> &str {
        &self.event_id
    }
    pub(crate) fn accepted_count(&self) -> &str {
        &self.accepted_count
    }
    pub(crate) fn world_root(&self) -> &str {
        &self.world_root
    }
}

/// The constructor is deliberately private. The only producer below invokes
/// op26 once and accepts its fresh committed callback, never op27 or an
/// already-present/replayed outcome. A current source inspection then binds
/// the exact retained STOP plan, original BEGIN, both receipts and claim.
pub(crate) struct FreshStopClaim {
    target: StopTarget,
}

impl FreshStopClaim {
    pub(crate) fn target(&self) -> &StopTarget {
        &self.target
    }
}


fn committed_source_receipt(
    view: &Value,
    committed: &[u8],
    claim_ingress: &[u8],
    original_begin: &[u8],
) -> io::Result<ExactReceipt> {
    let field = |name| -> io::Result<&str> {
        view.get(name)
            .and_then(Value::as_str)
            .ok_or_else(|| invalid("STOP committed source inspection field absent"))
    };
    if field("type")? != "application-lifecycle-claim-committed-v3"
        || field("kind")? != "stop"
        || field("frameHex")? != hex(committed)
        || field("frameByteCount")? != committed.len().to_string()
        || field("originalClaimHex")? != hex(claim_ingress)
        || field("originalBeginHex")? != hex(original_begin)
    {
        return Err(invalid("STOP committed frame differs from original claim"));
    }
    let receipt = ExactReceipt::from_source(
        view.get("receipt")
            .ok_or_else(|| invalid("STOP committed source receipt absent"))?,
    )?;
    if field("postWorldRoot")? != receipt.world_root {
        return Err(invalid("STOP committed post-world root differs"));
    }
    Ok(receipt)
}

/// One durable attempt. An error after the pre-submit marker, including a
/// truncated/uncertain response or a later read-only inspection refusal,
/// leaves the exact bytes for receipt-only investigation. It must not be
/// reentered or translated into a fresh claim from historical lookup.
pub(crate) fn submit_once(
    operator: &PrivateOperator,
    attempt_dir: &Path,
    retained_stop_plan: &[u8],
    original_begin: &[u8],
    claim_ingress: &[u8],
    begin_receipt: ExactReceipt,
) -> io::Result<FreshStopClaim> {
    if [retained_stop_plan, original_begin, claim_ingress]
        .iter()
        .any(|value| value.is_empty() || value.len() >= MAX_FRAME)
    {
        return Err(invalid("STOP retained input size refused"));
    }
    let parent = attempt_dir
        .parent()
        .ok_or_else(|| invalid("STOP claim attempt parent absent"))?;
    private_dir(parent)?;
    DirBuilder::new().mode(0o700).create(attempt_dir)?;
    let plan_path = write_new(attempt_dir, "stop-plan-v2.bin", retained_stop_plan)?;
    let _ = write_new(attempt_dir, "original-begin-v3.bin", original_begin)?;
    let _ = write_new(attempt_dir, "claim-ingress-v3.bin", claim_ingress)?;
    // Refuse a non-STOP or noncanonical plan before attempting any Store write.
    // Current-image agreement is checked again after the fresh callback.
    let plan_inspection = operator.tool(
        "inspect",
        "application-lifecycle-launch-stop-plan",
        &plan_path,
        &attempt_dir.join("stop-plan-v2.json"),
    )?;
    let plan_view: Value = serde_json::from_slice(&plan_inspection)?;
    if plan_view.get("type").and_then(Value::as_str)
        != Some("application-lifecycle-launch-stop-plan-v2")
        || plan_view.get("canonicalPlanHex").and_then(Value::as_str)
            != Some(hex(retained_stop_plan).as_str())
        || plan_view
            .get("basePlan")
            .and_then(|base| base.get("request"))
            .and_then(|request| request.get("kind"))
            .and_then(Value::as_str)
            != Some("stop")
    {
        return Err(invalid("STOP source plan preflight refused"));
    }
    let marker = json!({
        "protocol":"mini-spk-stop-claim-op26-requested-v1",
        "stopPlanSha256":hex(&Sha256::digest(retained_stop_plan)),
        "originalBeginSha256":hex(&Sha256::digest(original_begin)),
        "claimIngressSha256":hex(&Sha256::digest(claim_ingress)),
        "beginReceipt":{
            "transactionId":begin_receipt.transaction_id(),
            "eventId":begin_receipt.event_id(),
            "acceptedCount":begin_receipt.accepted_count(),
            "worldRoot":begin_receipt.world_root(),
        }
    });
    write_new(
        attempt_dir,
        "op26-requested.json",
        &serde_json::to_vec(&marker)?,
    )?;
    // This parent-level marker bars a second attempt in the same journal even
    // if the callback is lost. It is distinct from the later physical fence.
    write_new(
        parent,
        "lifecycle-stop-claim-v3-active.json",
        &serde_json::to_vec(&marker)?,
    )?;

    let response = operator.invoke(crate::host_operations::APPLICATION_LIFECYCLE_CLAIM_SUBMIT, claim_ingress)?;
    write_new(attempt_dir, "op26-frame.bin", &response)?;
    // Only the pinned Host's fresh installed CAS-winner path emits this tag;
    // replay and op27 return a distinct receipt-only Outcome. Retain first.
    let committed = framed_payload("lifecycle claim submit", &response, crate::host_operations::APPLICATION_LIFECYCLE_CLAIM_SUBMIT, COMMITTED_TAG)?.to_vec();
    let committed_path = write_new(attempt_dir, "committed-v3.bin", &committed)?;
    let committed_json = operator.tool(
        "inspect",
        "application-lifecycle-claim-committed-v3",
        &committed_path,
        &attempt_dir.join("committed-v3.json"),
    )?;
    let committed_view: Value = serde_json::from_slice(&committed_json)?;
    let claim_receipt =
        committed_source_receipt(&committed_view, &committed, claim_ingress, original_begin)?;

    // The same pinned Host refreshes its retained verified history. Its output
    // cannot be substituted by caller JSON or a stale op27 receipt lookup.
    let inspection_path = attempt_dir.join("stop-claim-current.json");
    let inspection = inspect_current(operator, retained_stop_plan, &committed, &inspection_path)?;
    let target = StopTarget::from_verified_inspection(
        retained_stop_plan,
        &committed,
        original_begin,
        &inspection,
        begin_receipt.borrowed(),
        claim_receipt.borrowed(),
    )?;
    Ok(FreshStopClaim { target })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stop_inspection_pair_preserves_both_exact_inputs_and_refuses_bounds() {
        assert_eq!(inspection_request(b"plan", b"claim").unwrap(),
            b"\x04\0\0\0planclaim");
        assert!(inspection_request(b"", b"claim").is_err());
        assert!(inspection_request(b"plan", b"").is_err());
        assert!(inspection_request(&vec![0; MAX_FRAME - 5], b"x").is_err());
    }

    fn inspection_frame(operation: u8, payload: &[u8]) -> Vec<u8> {
        let mut frame = ((payload.len() + 1) as u32).to_le_bytes().to_vec();
        frame.push(operation);
        frame.extend_from_slice(payload);
        frame
    }

    #[test]
    fn stop_inspection_reply_is_exact_bounded_and_not_a_refusal_or_old_lookup() {
        let body = br#"{"type":"application-lifecycle-stop-claim-verified-v1","extra":{"kept":true}}"#;
        assert_eq!(inspection_reply(&inspection_frame(STOP_INSPECT_OPERATION, body)).unwrap(), body);
        for op in [26, 27, 154, 255] {
            assert!(inspection_reply(&inspection_frame(op, body)).is_err());
        }
        assert!(inspection_reply(&inspection_frame(STOP_INSPECT_OPERATION, b"{}" )).is_err());
        assert!(inspection_reply(&inspection_frame(STOP_INSPECT_OPERATION, b"not JSON")).is_err());
        let mut extra = inspection_frame(STOP_INSPECT_OPERATION, body);
        extra.push(0);
        assert!(inspection_reply(&extra).is_err());
        let large = vec![b' '; MAX_INSPECTION as usize + 1];
        assert!(inspection_reply(&inspection_frame(STOP_INSPECT_OPERATION, &large)).is_err());
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn stop_inspection_uses_pinned_operator_socket_and_retains_exact_reply() {
        use std::io::{Read, Write};
        use std::os::unix::fs::PermissionsExt;
        use std::os::unix::net::UnixListener;
        use std::time::{SystemTime, UNIX_EPOCH};

        let unique = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_nanos();
        let root = std::env::temp_dir().join(format!("mini-stop-inspection-{}-{unique}", std::process::id()));
        DirBuilder::new().mode(0o700).create(&root).unwrap();
        struct Cleanup(std::path::PathBuf);
        impl Drop for Cleanup {
            fn drop(&mut self) { let _ = std::fs::remove_dir_all(&self.0); }
        }
        let _cleanup = Cleanup(root.clone());
        let host = root.join("host");
        std::fs::copy("/usr/bin/true", &host).unwrap();
        std::fs::set_permissions(&host, std::fs::Permissions::from_mode(0o755)).unwrap();
        let config = root.join("config.json");
        std::fs::write(&config, b"{}").unwrap();
        let socket = root.join("operator.sock");
        let listener = UnixListener::bind(&socket).unwrap();
        std::fs::set_permissions(&socket, std::fs::Permissions::from_mode(0o600)).unwrap();
        let host_sha = Sha256::digest(std::fs::read(&host).unwrap());
        let operator = PrivateOperator {
            host, config: config.clone(), socket,
            host_sha256: hex(&host_sha),
            config_sha256: hex(&Sha256::digest(b"{}")),
        };
        let body = br#"{"type":"application-lifecycle-stop-claim-verified-v1","sourceReceipt":"preserved"}"#;
        let serving = std::thread::spawn(move || {
            let (mut peer, _) = listener.accept().unwrap();
            peer.set_read_timeout(Some(std::time::Duration::from_secs(5))).unwrap();
            let mut prefix = [0; 4];
            peer.read_exact(&mut prefix).unwrap();
            let mut frame = vec![0; u32::from_le_bytes(prefix) as usize];
            peer.read_exact(&mut frame).unwrap();
            assert_eq!(frame[0], 2); // protected Host/config binding envelope
            assert_eq!(&frame[1..5], &2u32.to_le_bytes());
            assert_eq!(&frame[5..7], b"{}");
            assert_eq!(&frame[7..39], host_sha.as_slice());
            assert_eq!(frame[39], STOP_INSPECT_OPERATION);
            assert_eq!(&frame[40..], inspection_request(b"plan", b"claim").unwrap());
            peer.write_all(&inspection_frame(STOP_INSPECT_OPERATION, body)).unwrap();
        });
        let output = root.join("current.json");
        assert_eq!(inspect_current(&operator, b"plan", b"claim", &output).unwrap(), body);
        serving.join().unwrap();
        assert_eq!(std::fs::read(&output).unwrap(), body);
        std::fs::write(config, b"{\"different\":true}").unwrap();
        assert!(inspect_current(&operator, b"plan", b"claim", &root.join("drift.json")).is_err());
        assert!(!root.join("drift.json").exists());
    }

    #[test]
    fn receipt_fields_require_canonical_positive_count() {
        assert!(ExactReceipt::new("1", "2", "3", "4").is_ok());
        assert!(ExactReceipt::new("01", "2", "3", "4").is_err());
        assert!(ExactReceipt::new("1", "2", "0", "4").is_err());
    }

    #[test]
    fn committed_inspection_binds_exact_originals() {
        let frame = b"frame";
        let claim = b"claim";
        let begin = b"begin";
        let source = json!({
            "type":"application-lifecycle-claim-committed-v3",
            "kind":"stop",
            "frameHex":hex(frame),
            "frameByteCount":frame.len().to_string(),
            "originalClaimHex":hex(claim),
            "originalBeginHex":hex(begin),
            "postWorldRoot":"4",
            "receipt":{"transactionId":"1","eventId":"2","acceptedCount":"3","worldRoot":"4"}
        });
        assert!(committed_source_receipt(&source, frame, claim, begin).is_ok());
        assert!(committed_source_receipt(&source, frame, b"changed", begin).is_err());
        assert!(committed_source_receipt(&source, frame, claim, b"changed").is_err());
    }

    #[test]
    fn historical_outcome_cannot_be_fresh_callback() {
        let mut reply = Vec::new();
        let payload = b"DREGG/NATIVE-HOST/OUTCOME/v7:replayed";
        reply.extend_from_slice(&(payload.len() as u32 + 1).to_le_bytes());
        reply.push(26);
        reply.extend_from_slice(payload);
        assert!(framed_payload("lifecycle claim submit", &reply, crate::host_operations::APPLICATION_LIFECYCLE_CLAIM_SUBMIT, COMMITTED_TAG).is_err());
        reply[4] = 27;
        assert!(framed_payload("lifecycle claim submit", &reply, crate::host_operations::APPLICATION_LIFECYCLE_CLAIM_SUBMIT, COMMITTED_TAG).is_err());
    }
}
