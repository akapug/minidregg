//! Explicit recovery of a session request that stopped before its first birth.
//! The session's first durable ordinal/marker precedes every tool attach, reserve,
//! author or submit. A never-used family, no marker/result and the exact original
//! parent reservation therefore permit continuation of this request, not replay of
//! a session effect. Failed checks never settle the hold or acknowledge a result.
use super::*;

pub(super) fn successful_reply(request_id: &str, response: &str) -> bool {
    let Ok(value) = serde_json::from_str::<Value>(response) else {
        return false;
    };
    valid_foreground_request_id(request_id)
        && value["type"] == "mini-foreground-session-recovery-v1"
        && value["requestId"] == request_id
        && value["resultReady"] == true
        && value["acknowledged"] == false
        && value["operationId"]
            .as_str()
            .is_some_and(|v| v.parse::<u64>().is_ok_and(|n| n > 0 && n.to_string() == v))
        && value["resultSha256"].as_str().is_some_and(|v| {
            v.len() == 64
                && v.bytes()
                    .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        })
}

fn candidate(journal: &Journal, state: &Path) -> Result<ForegroundRequest> {
    journal.validate_foreground(state)?;
    let attempt = journal
        .foreground_attempt
        .as_ref()
        .ok_or("no retained foreground session")?;
    if attempt.name != "mini_create_application_session"
        || attempt.reported
        || !matches!(
            attempt.phase,
            ForegroundPhase::Uncertain | ForegroundPhase::Executing | ForegroundPhase::Reserved
        )
        || attempt.result_path.is_some()
        || attempt.result_sha256.is_some()
        || !matches!(state.join(format!("foreground-{:016}.result.json",attempt.operation_id)).symlink_metadata(),
            Err(error) if error.kind()==io::ErrorKind::NotFound)
    {
        return Err("foreground session is not an unresolved pre-birth request".into());
    }
    let request: ForegroundRequest =
        serde_json::from_slice(&bounded_regular_file(&attempt.request_path, 262_144)?)
            .map_err(|e| format!("retained session request: {e}"))?;
    if request.request_id != attempt.request_id || request.name != attempt.name {
        return Err("retained session request identity differs".into());
    }
    let arguments = request
        .arguments
        .as_object()
        .ok_or("session arguments must be an object")?;
    let family = arguments
        .get("family")
        .and_then(Value::as_str)
        .ok_or("session family absent")?;
    let application = arguments
        .get("application")
        .and_then(Value::as_str)
        .ok_or("session application absent")?;
    if arguments.len() != 2
        || family.is_empty()
        || application.is_empty()
        || journal.birth_next_ordinal.contains_key(family)
        || journal
            .born_resources
            .iter()
            .any(|record| record.pending.family == family)
    {
        return Err(
            "session family already crossed its first birth marker or arguments differ".into(),
        );
    }
    // Inspect the same journal fields across the frozen cohort and newer controllers.
    // No effect-bearing channel may be retained alongside this first session.
    let value = serde_json::to_value(journal).map_err(|e| e.to_string())?;
    for field in [
        "child",
        "pending",
        "toolPending",
        "toolHold",
        "birthOperation",
        "birthPending",
        "workspaceAttempt",
        "roomAttempt",
        "workspaceBirth",
        "providerPending",
        "providerHold",
        "providerAttempt",
        "dispatchPending",
        "dispatchHold",
        "dispatchAttempt",
        "applicationApiAttempt",
        "settlementDue",
        "residentPromptOrigin",
        "residentDelivery",
        "residentCompletion",
        "providerRetryGate",
    ] {
        if value.get(field).is_some_and(|v| !v.is_null()) {
            return Err(format!("session recovery blocked by {field}"));
        }
    }
    if !journal.unresolved_external.is_empty() || journal.hard_reconnect_pending {
        return Err("session recovery has unresolved external effects or reconnect".into());
    }
    let hold = journal
        .parent_hold
        .as_ref()
        .ok_or("session recovery has no parent hold")?;
    if !hold.reserve_confirmed
        || hold.reserve_refused
        || hold.reserve_attempt.is_none()
        || hold.reserve_boundary.is_none()
    {
        return Err("session recovery lacks confirmed original parent reserve".into());
    }
    let witness = journal
        .prompt_witness
        .as_ref()
        .ok_or("session recovery has no parent witness")?;
    if witness.pointer("/before/status").and_then(Value::as_str) != Some("4")
        || witness
            .pointer("/before/generation")
            .and_then(Value::as_str)
            != Some(hold.before_generation.as_str())
        || witness.pointer("/before/reserved").and_then(Value::as_str)
            != Some(hold.reserve.as_str())
        || witness
            .get("expectedTargetRoot")
            .and_then(Value::as_str)
            .is_none()
    {
        return Err("session recovery requires original soft reserved parent witness".into());
    }
    Ok(request)
}

fn parent_matches(journal: &Journal, task: &str, observed: &Value) -> Result<()> {
    let witness = journal
        .prompt_witness
        .as_ref()
        .ok_or("missing session parent witness")?;
    if witness.get("task").and_then(Value::as_str) != Some(task)
        || observed.pointer("/grain/task").and_then(Value::as_str) != Some(task)
        || observed.get("targetRoot") != witness.get("expectedTargetRoot")
    {
        return Err("current signed parent differs from exact session reservation root".into());
    }
    for field in ["generation", "status", "remaining", "reserved"] {
        if observed.get("grain").and_then(|v| v.get(field))
            != witness.get("before").and_then(|v| v.get(field))
        {
            return Err(format!("current signed parent reservation {field} changed"));
        }
    }
    Ok(())
}

fn reserve_source_matches(
    source: &Value,
    parent: &Authority,
    hold: &HeldCharge,
    id: u64,
) -> Result<()> {
    let grain = &source["grain"];
    if !grain_source::retained_identity(source, &parent.task, &parent.task, &parent.subject, id)
        || grain["task"] != parent.task
        || grain["subject"] != parent.subject
        || grain["capability"] != parent.capability
        || grain["observeCapability"] != parent.query_capability
        || grain["schemaVersion"] != "1"
        || grain["expectedTargetRoot"] != hold.before_target_root
        || grain["before"]["generation"] != hold.before_generation
        || grain["before"]["status"] != "2"
        || grain["before"]["reserved"] != "0"
        || grain["operation"] != json!({"type":"reserve","amount":hold.reserve})
        || grain["context"]["payload"] != "foreground tool"
        || grain["publications"] != json!([])
        || grain.get("parentWitness").is_some()
        || source["grants"]
            != json!([{"kind":"object","target":parent.task,"capability":parent.query_capability}])
    {
        return Err("retained call source is not this foreground parent reserve".into());
    }
    Ok(())
}

impl Runtime {
    /// Startup and ordinary reconnect must not settle an exact pre-birth session
    /// reservation. This predicate never executes work or unfences the controller.
    pub(super) fn preserves_foreground_session(&self) -> bool {
        // Even a corrupted candidate or one that crossed a later boundary stays
        // held for exact inspection. Failed validation is never permission for
        // startup to settle an uncertain session behind the operator's back.
        self.journal
            .foreground_attempt
            .as_ref()
            .is_some_and(|attempt| {
                attempt.name == "mini_create_application_session"
                    && !matches!(
                        attempt.phase,
                        ForegroundPhase::Definite | ForegroundPhase::Audited
                    )
            })
    }

    // Reconstruct only public codec products, never signatures or a new plan.
    // Exact op3 admission below then verifies the retained signed call itself.
    fn verify_session_reserve_bytes(
        &self,
        hold: &HeldCharge,
        id: u64,
        trace_id: u64,
    ) -> Result<PathBuf> {
        let original = hold
            .reserve_attempt
            .as_ref()
            .ok_or("reserve attempt absent")?;
        let source_bytes = bounded_regular_file(
            &self.config.state_dir.join(format!("source-{id:016}.json")),
            131_072,
        )?;
        if source_bytes != bounded_regular_file(&original.join("intent.json"), 131_072)? {
            return Err("parent reserve source differs from retained attempt".into());
        }
        let source: Value = serde_json::from_slice(&source_bytes).map_err(|e| e.to_string())?;
        reserve_source_matches(&source, &self.parent(), hold, id)?;
        let directory = self
            .config
            .state_dir
            .join(format!("foreground-reserve-codec-{trace_id:016}"));
        fs::create_dir(&directory).map_err(|e| format!("reserve codec directory: {e}"))?;
        fs::set_permissions(&directory, fs::Permissions::from_mode(0o700))
            .map_err(|e| e.to_string())?;
        write_new(&directory.join("source.json"), &source_bytes)?;
        for name in [
            "intent.bin",
            "plan.bin",
            "transaction-signatures.bin",
            "call.bin",
        ] {
            write_new(
                &directory.join(name),
                &bounded_regular_file(&original.join(name), 1_048_576)?,
            )?;
        }
        let config = bounded_regular_file(&self.config.host_config, 65_536)?;
        if config != bounded_regular_file(&original.join("config.json"), 65_536)? {
            return Err("parent reserve config differs from current pinned config".into());
        }
        write_new(&directory.join("config.json"), &config)?;
        let codec = |verb: &str, args: &[&str]| -> Result<()> {
            let mut command = Command::new(&self.config.host);
            command.arg(directory.join("config.json")).arg(verb);
            for arg in args {
                command.arg(directory.join(arg));
            }
            // Codec kind is textual rather than a path.
            if matches!(verb, "author" | "inspect") {
                command = Command::new(&self.config.host);
                command
                    .arg(directory.join("config.json"))
                    .arg(verb)
                    .arg(args[0]);
                for arg in &args[1..] {
                    command.arg(directory.join(arg));
                }
            }
            let output = self
                .custody_gate
                .run_capture(&self.cancelled, &mut command)
                .map_err(|error| format!("supervised reserve codec: {error}"))?;
            if !output.status.success() {
                return Err("pinned Host refused reserve codec validation".into());
            }
            Ok(())
        };
        codec(
            "author",
            &["grain-intent", "source.json", "source-intent.bin"],
        )?;
        if bounded_regular_file(&directory.join("source-intent.bin"), 1_048_576)?
            != bounded_regular_file(&directory.join("intent.bin"), 1_048_576)?
        {
            return Err("parent reserve source does not encode its retained intent".into());
        }
        write_new(
            &directory.join("grain.json"),
            &serde_json::to_vec(&source["grain"]).map_err(|e| e.to_string())?,
        )?;
        codec("author", &["grain", "grain.json", "command.bin"])?;
        codec("inspect", &["plan", "plan.bin", "plan.json"])?;
        let plan: Value = serde_json::from_slice(&bounded_regular_file(
            &directory.join("plan.json"),
            4_194_304,
        )?)
        .map_err(|e| e.to_string())?;
        let command = bounded_regular_file(&directory.join("command.bin"), 1_048_576)?;
        let encoded: String = command.iter().map(|byte| format!("{byte:02x}")).collect();
        if plan.get("finalizedDraft") != Some(&json!({"type":"invoke", "command":encoded})) {
            return Err("reserve plan differs from exact source invocation".into());
        }
        codec(
            "assemble",
            &[
                "plan.bin",
                "transaction-signatures.bin",
                "assembled-call.bin",
            ],
        )?;
        if bounded_regular_file(&directory.join("assembled-call.bin"), 1_048_576)?
            != bounded_regular_file(&directory.join("call.bin"), 1_048_576)?
        {
            return Err(
                "reserve call differs from exact source plan and retained signatures".into(),
            );
        }
        Ok(directory.join("call.bin"))
    }

    pub(super) fn recover_foreground_session(&mut self, request_id: &str) -> Result<Value> {
        let request = candidate(&self.journal, &self.config.state_dir)?;
        if request.request_id != request_id
            || !valid_foreground_request_id(request_id)
            || self.child.is_some()
            || self.foreground_operation.is_some()
            || self.prompt_active
        {
            return Err("session recovery request differs or controller work is active".into());
        }
        self.preflight_foreground_arguments(&request)?;
        let profile = self
            .config
            .foreground_tool
            .as_ref()
            .ok_or("foreground profile absent")?
            .clone();
        let hold = self
            .journal
            .parent_hold
            .clone()
            .ok_or("parent hold absent")?;
        if hold.reserve != profile.reserve || hold.charge != profile.charge {
            return Err("foreground reservation profile changed".into());
        }
        let operation_id = self
            .journal
            .foreground_attempt
            .as_ref()
            .unwrap()
            .operation_id;
        // The runtime holds its exclusive journal flock. Any previous orphaned
        // custody child from this pre-birth prefix can only be a read-only lookup:
        // the first write requires a durable ordinal/birth marker excluded above.
        // Do not generalize this to a worker or a request that crossed that marker.
        self.journal.connection = Connection::Fenced;
        let trace_id = self.next_id()?;
        self.journal.reconciliation_log.push(json!({"decisionId":trace_id.to_string(),
            "action":"foreground-session-resume","stage":"requested","operationId":operation_id.to_string(),
            "requestId":request_id,"requestSha256":self.journal.foreground_attempt.as_ref().unwrap().request_sha256,
            "reserveAttempt":hold.reserve_attempt}));
        self.save()?;
        // Recovery itself is owner-admin authorized. No transport detach can
        // turn it into a second work request; it consumes the retained bytes.
        let was_cancelled = self.cancelled.swap(false, Ordering::SeqCst);
        let validation = (|| -> Result<Value> {
            let reserve = hold.reserve_attempt.as_ref().unwrap();
            let encoded = reserve
                .file_name()
                .and_then(|v| v.to_str())
                .and_then(|v| v.strip_prefix("attempt-"))
                .ok_or("session parent reserve attempt name invalid")?;
            let id = encoded
                .parse::<u64>()
                .map_err(|_| "session parent reserve ID invalid")?;
            if reserve != &self.config.state_dir.join(format!("attempt-{id:016}"))
                || id <= operation_id
                || id >= trace_id
            {
                return Err("session parent reserve is not this retained foreground prefix".into());
            }
            let receipt: Value = serde_json::from_slice(&bounded_regular_file(
                &reserve.join("outcome.json"),
                131_072,
            )?)
            .map_err(|e| e.to_string())?;
            let anchor = ReserveAnchor::from_confirmed(&receipt)?;
            if Some(anchor.world_root.as_str()) != hold.reserve_boundary.as_deref() {
                return Err("session original reserve receipt differs from hold".into());
            }
            let call = self.verify_session_reserve_bytes(&hold, id, trace_id)?;
            let mut command = Command::new(&self.config.mini);
            command
                .arg("historical-call-receipt-lookup")
                .arg("--host")
                .arg(&self.config.host)
                .arg("--config")
                .arg(&self.config.host_config)
                .arg("--socket")
                .arg(
                    self.config
                        .host_socket
                        .as_ref()
                        .ok_or("session recovery needs public socket")?,
                )
                .arg("--call")
                .arg(&call)
                .arg("--transaction-id")
                .arg(&anchor.transaction_id)
                .arg("--event-id")
                .arg(&anchor.event_id)
                .arg("--accepted-count")
                .arg(&anchor.accepted_count)
                .arg("--world-root")
                .arg(&anchor.world_root)
                .arg("--dir")
                .arg(
                    self.config
                        .state_dir
                        .join(format!("foreground-reserve-lookup-{trace_id:016}")),
                );
            let replay = self.supervised_json_command(command)?;
            if ReserveAnchor::from_confirmed(&replay)? != anchor
                || replay.get("confirmation").and_then(Value::as_str) != Some("replayed")
            {
                return Err("session original reserve did not replay exactly".into());
            }
            let parent = self.query()?;
            parent_matches(&self.journal, &self.config.task, &parent)?;
            let tool = self.query_as(&self.tool()?)?;
            if !matches!(
                tool.pointer("/grain/status").and_then(Value::as_str),
                Some("0" | "1")
            ) || tool.pointer("/grain/reserved").and_then(Value::as_str) != Some("0")
            {
                return Err("session delegated tool is not signed idle".into());
            }
            candidate(&self.journal, &self.config.state_dir)?;
            Ok(replay)
        })();
        let receipt = match validation {
            Ok(v) => v,
            Err(e) => {
                self.cancelled.store(was_cancelled, Ordering::SeqCst);
                self.journal
                    .reconciliation_log
                    .push(json!({"decisionId":trace_id.to_string(),
                "action":"foreground-session-resume","stage":"refused","detail":e}));
                self.save()?;
                return Err(e);
            }
        };
        let execution = (|| -> Result<Value> {
            self.journal.reconciliation_log.push(json!({"decisionId":trace_id.to_string(),
            "action":"foreground-session-resume","stage":"validated","operationId":operation_id.to_string(),
            "requestId":request_id,"reserveReceipt":receipt}));
            self.journal.foreground_attempt.as_mut().unwrap().phase = ForegroundPhase::Executing;
            self.journal.connection = Connection::Soft;
            self.save()?;
            self.foreground_operation = Some(operation_id);
            self.completion_phase.store(PHASE_RUNNING, Ordering::SeqCst);
            let result =
                self.create_resource(&request.arguments, Some(ApplicationBirthRoute::Session));
            self.foreground_operation = None;
            let result = result?;
            let (_result, bytes) =
                bounded_foreground_result(json!({"isError":false,"text":result.to_string()}))?;
            let path = self
                .config
                .state_dir
                .join(format!("foreground-{operation_id:016}.result.json"));
            write_new(&path, &bytes)?;
            let attempt = self.journal.foreground_attempt.as_mut().unwrap();
            attempt.result_path = Some(path);
            attempt.result_sha256 = Some(sha256_bytes(&bytes)?);
            self.save()?;
            if !self.claim_completion(&profile.charge)? {
                return Err("session recovery completion was interrupted".into());
            }
            self.transition(
                json!({"type":"settle","charge":profile.charge}),
                "settle",
                "recovered foreground session complete",
            )?;
            self.journal.prompt_witness = None;
            self.journal.foreground_attempt.as_mut().unwrap().phase = ForegroundPhase::Definite;
            self.journal.reconciliation_log.push(json!({"decisionId":trace_id.to_string(),
            "action":"foreground-session-resume","stage":"completed","operationId":operation_id.to_string(),"requestId":request_id}));
            self.completion_phase.store(PHASE_IDLE, Ordering::SeqCst);
            self.save()?;
            // Leave the exact definite attempt for tool-result/tool-ack. Admin success
            // is neither delivery of the tool result nor an acknowledgement.
            Ok(
                json!({"type":"mini-foreground-session-recovery-v1","requestId":request_id,"operationId":operation_id.to_string(),"resultSha256":self.journal.foreground_attempt.as_ref().unwrap().result_sha256,"resultReady":true,"acknowledged":false}),
            )
        })();
        self.finish_foreground_session_recovery(trace_id, execution)
    }

    fn finish_foreground_session_recovery(
        &mut self,
        trace_id: u64,
        execution: Result<Value>,
    ) -> Result<Value> {
        self.foreground_operation = None;
        if let Err(error) = execution {
            // This covers result encoding/persistence and settlement as well as
            // birth failures. Never discard a written result or effect marker.
            self.journal.foreground_attempt.as_mut().unwrap().phase = ForegroundPhase::Uncertain;
            self.journal.connection = Connection::Fenced;
            self.cancelled.store(true, Ordering::SeqCst);
            self.journal
                .reconciliation_log
                .push(json!({"decisionId":trace_id.to_string(),
                "action":"foreground-session-resume","stage":"uncertain","detail":error}));
            return Err(match self.save() {
                Ok(()) => error,
                Err(persist) => format!("{error}; cannot persist recovery fence: {persist}"),
            });
        }
        execution
    }
}

#[cfg(test)]
#[path = "foreground_session_recovery_adversary_tests.rs"]
mod adversary_tests;

#[cfg(test)]
mod tests {
    use super::*;
    const REQUEST: &str = "839a6731941b62b1179b4de9c076f0df";
    pub(super) struct Fixture {
        pub(super) state: PathBuf,
        pub(super) journal: Journal,
    }
    impl Fixture {
        pub(super) fn new() -> Self {
            let state = std::env::temp_dir().join(format!(
                "mini-session-resume-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            fs::create_dir(&state).unwrap();
            fs::set_permissions(&state, fs::Permissions::from_mode(0o700)).unwrap();
            let bytes = serde_json::to_vec(
                &json!({"requestId":REQUEST,"name":"mini_create_application_session",
                "arguments":{"family":"browser","application":"shared-oracle"}}),
            )
            .unwrap();
            let path = state.join("foreground-0000000000000013.request.json");
            write_new(&path, &bytes).unwrap();
            let hash = sha256_bytes(&bytes).unwrap();
            write_new(
                &foreground_tombstone_path(&state, REQUEST),
                &serde_json::to_vec(&ForegroundTombstone {
                    request_id: REQUEST.into(),
                    operation_id: 13,
                    request_sha256: hash.clone(),
                })
                .unwrap(),
            )
            .unwrap();
            let mut journal = Journal::fresh(json!({}));
            journal.next_operation_id = 22;
            journal.foreground_attempt = Some(ForegroundAttempt {
                request_id: REQUEST.into(),
                operation_id: 13,
                name: "mini_create_application_session".into(),
                request_path: path,
                request_sha256: hash,
                phase: ForegroundPhase::Uncertain,
                result_path: None,
                result_sha256: None,
                reported: false,
            });
            journal.parent_hold = Some(HeldCharge {
                reserve: "1".into(),
                charge: "0".into(),
                before_generation: "1".into(),
                before_target_root: "10".into(),
                reserve_attempt: Some(state.join("attempt-0000000000000016")),
                reserve_confirmed: true,
                reserve_refused: false,
                reserve_boundary: Some("20".into()),
                reserve_call_sha256: None,
                reserve_source_sha256: None,
                reserve_outcome_path: None,
                reserve_outcome_sha256: None,
                reserve_anchor: None,
            });
            journal.prompt_witness = Some(json!({"task":"27920","expectedTargetRoot":"30",
                "before":{"generation":"1","status":"4","remaining":"99","reserved":"1"}}));
            Self { state, journal }
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.state);
        }
    }
    #[test]
    fn admin_success_requires_matching_complete_recovery_receipt() {
        let mut reply = json!({"type":"mini-foreground-session-recovery-v1","requestId":REQUEST,"operationId":"13","resultSha256":"ab".repeat(32),"resultReady":true,"acknowledged":false});
        assert!(successful_reply(REQUEST, &reply.to_string()));
        for field in [
            "type",
            "requestId",
            "operationId",
            "resultSha256",
            "resultReady",
            "acknowledged",
        ] {
            let old = reply[field].take();
            assert!(!successful_reply(REQUEST, &reply.to_string()), "{field}");
            reply[field] = old;
        }
    }
    #[test]
    fn foreground_session_recovery_keeps_original_request_and_reservation() {
        let fixture = Fixture::new();
        let before = serde_json::to_vec(&fixture.journal).unwrap();
        let request = candidate(&fixture.journal, &fixture.state).unwrap();
        assert_eq!(request.request_id, REQUEST);
        assert_eq!(before, serde_json::to_vec(&fixture.journal).unwrap());
        let restarted: Journal = serde_json::from_slice(&before).unwrap();
        assert_eq!(
            candidate(&restarted, &fixture.state).unwrap().request_id,
            REQUEST
        );
    }
    #[test]
    fn foreground_session_recovery_refuses_every_crossed_birth_boundary() {
        let fixture = Fixture::new();
        for (field, value) in [
            (
                "birthOperation",
                json!({"family":"browser","ordinal":0,"noNativeSubmit":true}),
            ),
            ("birthNextOrdinal", json!({"browser":0})),
            ("unresolvedExternal", json!(["unknown effect"])),
            ("settlementDue", json!("0")),
            ("hardReconnectPending", json!(true)),
        ] {
            let mut changed = serde_json::to_value(&fixture.journal).unwrap();
            changed[field] = value;
            let journal: Journal = serde_json::from_value(changed).unwrap();
            assert!(candidate(&journal, &fixture.state).is_err(), "{field}");
        }
        let mut journal: Journal =
            serde_json::from_slice(&serde_json::to_vec(&fixture.journal).unwrap()).unwrap();
        journal.tool_hold = journal.parent_hold.clone();
        assert!(candidate(&journal, &fixture.state).is_err());
        journal.tool_hold = None;
        journal.parent_hold.as_mut().unwrap().reserve_confirmed = false;
        assert!(candidate(&journal, &fixture.state).is_err());
    }
    #[test]
    fn foreground_session_recovery_refuses_result_or_tombstone_or_request_drift() {
        let fixture = Fixture::new();
        let result = fixture
            .state
            .join("foreground-0000000000000013.result.json");
        write_new(&result, b"{}").unwrap();
        assert!(candidate(&fixture.journal, &fixture.state).is_err());
        fs::remove_file(result).unwrap();
        let tombstone = foreground_tombstone_path(&fixture.state, REQUEST);
        fs::write(
            &tombstone,
            serde_json::to_vec(&ForegroundTombstone {
                request_id: REQUEST.into(),
                operation_id: 14,
                request_sha256: fixture
                    .journal
                    .foreground_attempt
                    .as_ref()
                    .unwrap()
                    .request_sha256
                    .clone(),
            })
            .unwrap(),
        )
        .unwrap();
        assert!(candidate(&fixture.journal, &fixture.state).is_err());
        fs::write(
            &fixture
                .journal
                .foreground_attempt
                .as_ref()
                .unwrap()
                .request_path,
            b"changed",
        )
        .unwrap();
        assert!(candidate(&fixture.journal, &fixture.state).is_err());
    }
    #[test]
    fn recovery_consumes_the_actual_runtime_query_projection() {
        // Exercise the producer itself: Mini's decoded view is nested under
        // cell, while Runtime::query returns grain/targetRoot and no target.
        let (mut runtime, root) = crate::publication_refusal_tests::fixture(false, false, false);
        let fixture = Fixture::new();
        runtime.config.state_dir = fixture.state.clone();
        runtime.config.task = "27920".into();
        runtime.journal =
            serde_json::from_value(serde_json::to_value(&fixture.journal).unwrap()).unwrap();
        let view = json!({"type":"resource", "cell":{"root":"30", "grain":{
            "task":"27920", "generation":"1", "remaining":"99", "reserved":"1", "status":"4"}}});
        fs::write(
            root.join("decoded-view.json"),
            serde_json::to_vec(&view).unwrap(),
        )
        .unwrap();
        let script = r#"#!/bin/sh
set -eu
[ "$1" = query ] || exit 91
dir=
while [ "$#" -gt 0 ]; do
  case "$1" in --dir) dir=$2; shift 2 ;; *) shift ;; esac
done
mkdir "$dir"
cp '__ROOT__/decoded-view.json' "$dir/view.json"
printf '%s' '{"authorityRoot":"1","worldRoot":"2","height":"40"}' > "$dir/challenge.json"
"#
        .replace("__ROOT__", root.to_str().unwrap());
        fs::write(&runtime.config.mini, script).unwrap();
        let observed = runtime.query().unwrap();
        assert!(observed.get("target").is_none());
        assert_eq!(observed.pointer("/grain/task"), Some(&json!("27920")));
        parent_matches(&runtime.journal, "27920", &observed).unwrap();
        assert!(
            runtime
                .journal
                .parent_hold
                .as_ref()
                .unwrap()
                .reserve_confirmed
        );
        assert!(
            runtime.journal.birth_operation.is_none() && runtime.journal.birth_pending.is_none()
        );
        drop(runtime);
        fs::remove_dir_all(root).unwrap();
    }
    #[test]
    fn foreground_session_recovery_requires_exact_signed_parent_boundary() {
        let fixture = Fixture::new();
        let exact = json!({"targetRoot":"30","grain":{"task":"27920","generation":"1","status":"4","remaining":"99","reserved":"1"}});
        parent_matches(&fixture.journal, "27920", &exact).unwrap();
        let mut missing = exact.clone();
        missing["grain"].as_object_mut().unwrap().remove("task");
        missing["target"] = json!("27920");
        assert!(parent_matches(&fixture.journal, "27920", &missing).is_err());
        for field in ["task", "generation", "status", "remaining", "reserved"] {
            let mut changed = exact.clone();
            changed["grain"][field] = json!("999");
            assert!(parent_matches(&fixture.journal, "27920", &changed).is_err());
        }
        for field in ["targetRoot"] {
            let mut changed = exact.clone();
            changed[field] = json!("999");
            assert!(parent_matches(&fixture.journal, "27920", &changed).is_err());
        }
    }
}
