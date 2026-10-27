//! The decided outcome of a provider call that did not end in a plain 200.
//!
//! Every provider attempt that leaves the happy path lands in exactly one
//! class, and each class names its settle path and its retry rule. The hold is
//! released only by a Host-admitted settle; this module decides nothing about
//! the charge. It only records which settle the controller asks the Host for,
//! which exact operator command retries that settle, and whether any resend is
//! safe. "Lookup absent" is never one of the inputs.
use serde::{Deserialize, Serialize};
use std::time::Duration;

/// The exact operator retry for every class whose settle waits on the Host.
pub(crate) const AUDITED_RETRY: &str = "grain-runtime admin STATE_DIR/admin.sock reconcile provider audited";
/// Bounded retry: at most this many tries of one request.
pub(crate) const MAX_TRIES: u32 = 3;

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "kebab-case", deny_unknown_fields)]
pub(crate) enum FailureClass {
    /// A complete, retained HTTP reply whose status is not 200.
    #[serde(rename = "complete-non-200")]
    CompleteNon200 { status: u16 },
    /// The key broker never received the whole request frame in time. Nothing
    /// left the process.
    TimeoutBeforeSend,
    /// The request crossed the send boundary and no complete reply came back
    /// before the deadline (or the lease ended while waiting).
    TimeoutAfterSend,
    /// A reply came back but cannot be retained or read as one exact HTTP
    /// response (truncated, oversized headers, withheld, unparseable).
    Malformed { reason: String },
    /// The controller restarted with the send boundary durable and no outcome.
    CrashAfterSend,
    /// Proven not sent (broker refusal before send, lease ended before send).
    NotSent { reason: String },
}

impl FailureClass {
    /// The `outcomeClass` the controller sends the Host with a settle request
    /// for a call that has no quotable 200 usage record.
    pub(crate) fn wire_name(&self) -> &'static str {
        match self {
            Self::CompleteNon200 { .. } => "complete-non-200",
            Self::TimeoutBeforeSend => "timeout-before-send",
            Self::TimeoutAfterSend => "timeout-after-send",
            Self::Malformed { .. } => "malformed",
            Self::CrashAfterSend => "crash-after-send",
            Self::NotSent { .. } => "not-sent",
        }
    }
    /// A complete response exists (the v3 metering frame can carry it).
    pub(crate) fn has_complete_response(&self) -> bool {
        matches!(self, Self::CompleteNon200 { .. })
    }
    /// The request may have reached upstream.
    pub(crate) fn after_send(&self) -> bool {
        matches!(
            self,
            Self::CompleteNon200 { .. } | Self::TimeoutAfterSend | Self::Malformed { .. } | Self::CrashAfterSend
        )
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub(crate) enum DecidedState {
    /// Released by a zero settle; nothing was sent.
    ReleasedNotSent,
    /// The Host's quote already admits this settle (user route: per-op fee).
    SettleByQuote,
    /// The settle needs a Host whose provider quote admits this class; the
    /// hold is kept and `retry` is the exact command that clears it.
    SettleAwaitingHost,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub(crate) enum Resend {
    /// Never resend these bytes: the outcome upstream is unknown or final.
    Never,
    /// Nothing was sent: the gateway may retry the same frame on the same
    /// attempt, with backoff, at most `MAX_TRIES` times.
    SameAttemptBackoff,
    /// The reply was definite and retryable (429, 5xx): a later request is a
    /// NEW reserve, admitted only after this attempt settles, with backoff,
    /// at most `MAX_TRIES` failures of the same request bytes.
    NewReserveBackoff,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct Decision {
    pub(crate) class: FailureClass,
    pub(crate) state: DecidedState,
    pub(crate) resend: Resend,
    /// The exact command that moves this attempt forward, or `null` when the
    /// controller does it itself.
    pub(crate) retry: Option<String>,
}

fn retryable_status(status: u16) -> bool {
    status == 429 || (500..=599).contains(&status)
}

/// The decision for one class. A complete reply of any status is quoted by
/// the Host (`Host/ProviderUsage.lean` `quoteResponse`: the per-operation fee
/// on the user route, the route fee for a refused reply on a metered route),
/// so it settles like a 200. `_route` is the attempt's credential route.
pub(crate) fn decide(class: FailureClass, _route: &str) -> Decision {
    let (state, resend, retry) = match &class {
        FailureClass::NotSent { .. } | FailureClass::TimeoutBeforeSend => {
            (DecidedState::ReleasedNotSent, Resend::SameAttemptBackoff, None)
        }
        FailureClass::CompleteNon200 { status } => {
            let resend = if retryable_status(*status) { Resend::NewReserveBackoff } else { Resend::Never };
            (DecidedState::SettleByQuote, resend, None)
        }
        FailureClass::TimeoutAfterSend | FailureClass::Malformed { .. } | FailureClass::CrashAfterSend => {
            (DecidedState::SettleAwaitingHost, Resend::Never, Some(AUDITED_RETRY.to_owned()))
        }
    };
    Decision { class, state, resend, retry }
}

/// Class from the journaled outcome string. `None` for a plain 200 or for an
/// attempt that has not crossed the send boundary and has no outcome yet.
/// `uncertain:` outcomes written before classes existed are after-send
/// unknowns, the conservative class.
pub(crate) fn classify(send_started: bool, outcome: Option<&str>, status: Option<u16>) -> Option<FailureClass> {
    match outcome {
        None if send_started => Some(FailureClass::CrashAfterSend),
        None => None,
        Some(kind) => {
            if let Some(rest) = kind.strip_prefix("not-sent:") {
                if rest.starts_with("timeout-before-send:") {
                    return Some(FailureClass::TimeoutBeforeSend);
                }
                let reason = rest.strip_prefix("refused:").unwrap_or(rest);
                return Some(FailureClass::NotSent { reason: reason.to_owned() });
            }
            if kind.starts_with("received:") {
                let status = status.or_else(|| kind.split(':').nth(1).and_then(|s| s.parse().ok()))?;
                return (status != 200).then_some(FailureClass::CompleteNon200 { status });
            }
            if let Some(rest) = kind.strip_prefix("uncertain:") {
                if let Some(reason) = rest.strip_prefix("malformed:") {
                    return Some(FailureClass::Malformed { reason: reason.to_owned() });
                }
                if rest.starts_with("crash-after-send:") {
                    return Some(FailureClass::CrashAfterSend);
                }
                if rest.starts_with("raw-header-metadata-mismatch") {
                    return Some(FailureClass::Malformed { reason: rest.to_owned() });
                }
                return Some(FailureClass::TimeoutAfterSend);
            }
            None
        }
    }
}

/// Backoff before try `next` (1-based count of failures so far): 1 s, 4 s,
/// 16 s, each jittered by up to +/-25% from `seed`; `None` once `MAX_TRIES`
/// tries have failed.
pub(crate) fn backoff(failures: u32, seed: u64) -> Option<Duration> {
    if failures == 0 || failures >= MAX_TRIES {
        return None;
    }
    let base_ms: u64 = 1000 * 4u64.pow(failures - 1);
    let spread = base_ms / 4;
    let jitter = seed % (2 * spread + 1);
    Some(Duration::from_millis(base_ms - spread + jitter))
}

/// Run `send` until it ends in anything but a not-sent timeout, at most
/// `MAX_TRIES` times, sleeping the backoff between tries and stopping early
/// once `active` is false. Only `TimeoutBeforeSend` is ever retried here; an
/// after-send outcome returns at once. Returns the last outcome and the try
/// count.
pub(crate) fn send_with_retry<T>(
    mut send: impl FnMut() -> (T, Option<FailureClass>),
    mut sleep: impl FnMut(Duration),
    active: impl Fn() -> bool,
    seed: u64,
) -> (T, u32) {
    let mut tries = 0;
    loop {
        tries += 1;
        let (outcome, class) = send();
        if class != Some(FailureClass::TimeoutBeforeSend) {
            return (outcome, tries);
        }
        match backoff(tries, seed.wrapping_add(u64::from(tries))) {
            Some(delay) if active() => sleep(delay),
            _ => return (outcome, tries),
        }
        if !active() {
            return (outcome, tries);
        }
    }
}

/// Per-request retry budget across reserves (for `NewReserveBackoff`).
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct RetryGate {
    pub(crate) request_sha256: String,
    pub(crate) failures: u32,
    pub(crate) not_before_unix_ms: u64,
}

impl RetryGate {
    /// Record one more definite retryable failure of these request bytes.
    pub(crate) fn after_failure(previous: Option<&RetryGate>, request_sha256: &str, now_ms: u64, seed: u64) -> RetryGate {
        let failures = match previous {
            Some(gate) if gate.request_sha256 == request_sha256 => gate.failures.saturating_add(1),
            _ => 1,
        };
        let wait = backoff(failures, seed).map(|d| d.as_millis() as u64).unwrap_or(0);
        RetryGate { request_sha256: request_sha256.to_owned(), failures, not_before_unix_ms: now_ms.saturating_add(wait) }
    }
    /// Refuse a new reserve of the same bytes inside the backoff or after the
    /// budget; other bytes are not gated.
    pub(crate) fn admits(&self, request_sha256: &str, now_ms: u64) -> Result<(), String> {
        if self.request_sha256 != request_sha256 {
            return Ok(());
        }
        if self.failures >= MAX_TRIES {
            return Err(format!(
                "provider retry budget exhausted: these request bytes failed {} times (bound {MAX_TRIES})",
                self.failures
            ));
        }
        if now_ms < self.not_before_unix_ms {
            return Err(format!(
                "provider retry backoff: retry these request bytes after {} ms",
                self.not_before_unix_ms - now_ms
            ));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;

    #[test]
    fn provider_failure_classes_land_in_their_decided_states() {
        let pool_429 = decide(classify(true, Some("received:429:application/json"), Some(429)).unwrap(), "pool");
        assert_eq!(pool_429.class, FailureClass::CompleteNon200 { status: 429 });
        assert_eq!(pool_429.state, DecidedState::SettleByQuote);
        assert_eq!(pool_429.retry, None);
        assert_eq!(pool_429.resend, Resend::NewReserveBackoff);

        let user_429 = decide(FailureClass::CompleteNon200 { status: 429 }, "user");
        assert_eq!((user_429.state, user_429.resend, user_429.retry), (DecidedState::SettleByQuote, Resend::NewReserveBackoff, None));
        let user_400 = decide(FailureClass::CompleteNon200 { status: 400 }, "user");
        assert_eq!(user_400.resend, Resend::Never);

        for (outcome, class) in [
            ("uncertain:timeout-after-send:the key broker did not answer in time", FailureClass::TimeoutAfterSend),
            ("uncertain:malformed:truncated reply", FailureClass::Malformed { reason: "truncated reply".into() }),
            ("uncertain:lost-reply", FailureClass::TimeoutAfterSend),
        ] {
            let got = classify(true, Some(outcome), None).unwrap();
            assert_eq!(got, class);
            let d = decide(got, "pool");
            assert_eq!((d.state, d.resend), (DecidedState::SettleAwaitingHost, Resend::Never));
            assert_eq!(d.retry.as_deref(), Some(AUDITED_RETRY));
        }
        let crash = decide(classify(true, None, None).unwrap(), "homelab");
        assert_eq!(crash.class, FailureClass::CrashAfterSend);
        assert_eq!((crash.state, crash.resend), (DecidedState::SettleAwaitingHost, Resend::Never));

        let tbs = classify(true, Some("not-sent:timeout-before-send:key broker: timed out"), None).unwrap();
        assert_eq!(tbs, FailureClass::TimeoutBeforeSend);
        assert_eq!(decide(tbs, "pool").state, DecidedState::ReleasedNotSent);
        assert_eq!(classify(false, None, None), None);
        assert_eq!(classify(true, Some("received:200:application/json"), Some(200)), None);
        // A decision survives the journal round trip with its class tag.
        let text = serde_json::to_string(&pool_429).unwrap();
        assert!(text.contains("\"class\":{\"kind\":\"complete-non-200\"") && text.contains("\"status\":429"), "{text}");
        assert_eq!(serde_json::from_str::<Decision>(&text).unwrap(), pool_429);
    }

    #[test]
    fn provider_timeout_before_send_retries_at_most_three_times_then_not_sent() {
        let slept = RefCell::new(Vec::new());
        let calls = RefCell::new(0);
        let (outcome, tries) = send_with_retry(
            || { *calls.borrow_mut() += 1; ("not-sent", Some(FailureClass::TimeoutBeforeSend)) },
            |d| slept.borrow_mut().push(d),
            || true,
            7,
        );
        assert_eq!((outcome, tries, *calls.borrow()), ("not-sent", MAX_TRIES, MAX_TRIES));
        let slept = slept.into_inner();
        assert_eq!(slept.len(), 2);
        assert!(slept[0] >= Duration::from_millis(750) && slept[0] <= Duration::from_millis(1250));
        assert!(slept[1] >= Duration::from_millis(3000) && slept[1] <= Duration::from_millis(5000));
        // Success on the second try stops the loop.
        let n = RefCell::new(0);
        let (_, tries) = send_with_retry(
            || { *n.borrow_mut() += 1; if *n.borrow() == 1 { ((), Some(FailureClass::TimeoutBeforeSend)) } else { ((), None) } },
            |_| {}, || true, 0);
        assert_eq!(tries, 2);
        // A revoked lease stops retrying.
        let (_, tries) = send_with_retry(|| ((), Some(FailureClass::TimeoutBeforeSend)), |_| {}, || false, 0);
        assert_eq!(tries, 1);
    }

    #[test]
    fn provider_timeout_after_send_is_never_retried() {
        for class in [FailureClass::TimeoutAfterSend, FailureClass::CrashAfterSend,
                      FailureClass::Malformed { reason: "x".into() }] {
            let calls = RefCell::new(0);
            let (_, tries) = send_with_retry(|| { *calls.borrow_mut() += 1; ((), Some(class.clone())) }, |_| panic!("no sleep"), || true, 0);
            assert_eq!((tries, *calls.borrow()), (1, 1));
            assert_eq!(decide(class, "user").resend, Resend::Never);
        }
    }

    #[test]
    fn provider_retry_gate_bounds_new_reserves_of_the_same_bytes() {
        let g1 = RetryGate::after_failure(None, "aa", 1_000, 0);
        assert_eq!(g1.failures, 1);
        assert!(g1.admits("aa", 1_000).is_err());
        assert!(g1.admits("bb", 1_000).is_ok());
        assert!(g1.admits("aa", 1_000 + 1_250).is_ok());
        let g2 = RetryGate::after_failure(Some(&g1), "aa", 5_000, 0);
        assert_eq!(g2.failures, 2);
        assert!(g2.admits("aa", 5_000 + 2_999).is_err());
        assert!(g2.admits("aa", 5_000 + 5_000).is_ok());
        let g3 = RetryGate::after_failure(Some(&g2), "aa", 20_000, 0);
        assert!(g3.admits("aa", u64::MAX).unwrap_err().contains("budget exhausted"));
        assert_eq!(RetryGate::after_failure(Some(&g3), "bb", 0, 0).failures, 1);
    }
}
