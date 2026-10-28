//! Bounded capture of the private Mini Host op34 reply.
//!
//! A matching tag is only framing. The caller must obtain these bytes from
//! its own operator-controlled Host invocation, run Mini's strict read-only
//! committed-permit inspector, and compare that inspection to these exact
//! retained bytes before using any projected value. Caller-supplied bytes,
//! op35 historical lookup, and a candidate projection grant no delivery.

use std::io;

// Native Host's max frame counts the opcode as well as its payload.
const MAX_HOST_FRAME: usize = 12_102_760;
const COMMITTED_TAG: &[u8] = b"DREGG/APPLICATION/DISPATCH-COMMITTED-PERMIT/v1";
const OUTCOME_TAG: &[u8] = b"DREGG/NATIVE-HOST/OUTCOME/v8";

fn invalid(reason: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, reason)
}

/// Opaque source bytes, not an authorization type. The private Host caller
/// retains this payload for exact comparison with source-owned inspection.
pub(crate) enum Op34Reply<'a> {
    CommittedBytes(&'a [u8]),
    /// The outcome frame; read by the qualification fixture and the tests.
    OutcomeBytes(
        #[cfg_attr(not(any(test, feature = "integration-qualification")), allow(dead_code))]
        &'a [u8],
    ),
}

/// Decode exactly one Host stdio response frame: LE32 length, opcode 34, then
/// one bounded payload. This performs no Lean semantic decoding or CAS check.
pub(crate) fn parse_op34_response(frame: &[u8]) -> io::Result<Op34Reply<'_>> {
    let header = frame
        .get(..5)
        .ok_or_else(|| invalid("truncated Mini Host reply"))?;
    let length = u32::from_le_bytes(header[..4].try_into().unwrap()) as usize;
    if !(2..=MAX_HOST_FRAME).contains(&length) || length + 4 != frame.len() {
        return Err(invalid("Mini Host reply length mismatch"));
    }
    if header[4] != 34 {
        return Err(invalid("Mini Host reply is not dispatch submit op34"));
    }
    let payload = &frame[5..];
    if payload.starts_with(COMMITTED_TAG) && payload.len() > COMMITTED_TAG.len() {
        Ok(Op34Reply::CommittedBytes(payload))
    } else if payload.starts_with(OUTCOME_TAG) && payload.len() > OUTCOME_TAG.len() {
        Ok(Op34Reply::OutcomeBytes(payload))
    } else {
        Err(invalid(
            "Mini Host op34 reply has no recognized source frame",
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn framed(op: u8, payload: &[u8]) -> Vec<u8> {
        let mut frame = Vec::new();
        frame.extend_from_slice(&((payload.len() + 1) as u32).to_le_bytes());
        frame.push(op);
        frame.extend_from_slice(payload);
        frame
    }

    #[test]
    fn exact_op34_payload_is_preserved_without_semantic_authority() {
        let mut payload = COMMITTED_TAG.to_vec();
        payload.extend_from_slice(b"\x01\x02\x03");
        match parse_op34_response(&framed(crate::host_operations::APPLICATION_DISPATCH_SUBMIT, &payload)).unwrap() {
            Op34Reply::CommittedBytes(bytes) => assert_eq!(bytes, payload),
            Op34Reply::OutcomeBytes(_) => panic!("committed frame classified as outcome"),
        }
        let mut outcome = OUTCOME_TAG.to_vec();
        outcome.push(0xff);
        match parse_op34_response(&framed(crate::host_operations::APPLICATION_DISPATCH_SUBMIT, &outcome)).unwrap() {
            Op34Reply::OutcomeBytes(bytes) => assert_eq!(bytes, outcome),
            Op34Reply::CommittedBytes(_) => panic!("outcome classified as committed"),
        }
    }

    #[test]
    fn candidate_lookup_trailing_and_truncated_frames_refuse() {
        let mut candidate = b"DREGG/APPLICATION/DISPATCH-CANDIDATE/v1".to_vec();
        candidate.push(0);
        assert!(parse_op34_response(&framed(crate::host_operations::APPLICATION_DISPATCH_SUBMIT, &candidate)).is_err());
        let mut committed = COMMITTED_TAG.to_vec();
        committed.push(0);
        assert!(parse_op34_response(&framed(crate::host_operations::APPLICATION_DISPATCH_LOOKUP, &committed)).is_err());
        let mut extra = framed(crate::host_operations::APPLICATION_DISPATCH_SUBMIT, &committed);
        extra.push(0);
        assert!(parse_op34_response(&extra).is_err());
        let mut truncated = framed(crate::host_operations::APPLICATION_DISPATCH_SUBMIT, &committed);
        truncated.pop();
        assert!(parse_op34_response(&truncated).is_err());
        assert!(parse_op34_response(&[0, 0, 0, 0]).is_err());
        assert!(parse_op34_response(&framed(crate::host_operations::APPLICATION_DISPATCH_SUBMIT, COMMITTED_TAG)).is_err());
        let oversized = framed(crate::host_operations::APPLICATION_DISPATCH_SUBMIT, &vec![0; MAX_HOST_FRAME]);
        assert!(parse_op34_response(&oversized).is_err());
    }
}
