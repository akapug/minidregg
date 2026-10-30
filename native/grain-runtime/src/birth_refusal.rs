//! A native prepare refusal is an outcome, not a lost custody reply. Keep its
//! exact origin until signed zero-charge tool cleanup and foreground settlement
//! finish. No error message or absence of a call can manufacture this record.
use super::*;

#[derive(Clone, Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct BirthRefusal {
    pub(super) origin: BirthPending,
    request_id: String,
    request_sha256: String,
    frame_sha256: String,
    refusal: Value,
    #[serde(default)]
    terminal_tool: Option<Value>,
    #[serde(default)]
    terminal_query: Option<u64>,
    #[serde(default)]
    terminal_files: BTreeMap<String, String>,
}

pub(super) fn legacy_execution_trace(
    journal: &Journal,
    foreground: &ForegroundAttempt,
) -> Result<u64> {
    let validated = journal
        .reconciliation_log
        .iter()
        .filter(|entry| {
            entry["action"] == "foreground-session-resume"
                && entry["stage"] == "validated"
                && entry["requestId"] == foreground.request_id
                && entry["operationId"] == foreground.operation_id.to_string()
        })
        .filter_map(|entry| entry["decisionId"].as_str()?.parse::<u64>().ok())
        .max()
        .ok_or("legacy refusal has no source-bound foreground execution trace")?;
    let requested = journal.reconciliation_log.iter().any(|entry| {
        entry["action"] == "foreground-session-resume"
            && entry["stage"] == "requested"
            && entry["decisionId"] == validated.to_string()
            && entry["operationId"] == foreground.operation_id.to_string()
            && entry["requestId"] == foreground.request_id
            && entry["requestSha256"] == foreground.request_sha256
    });
    if !requested || validated >= journal.next_operation_id {
        return Err("legacy refusal has no matching request-bound execution trace".into());
    }
    Ok(validated)
}

impl BirthRefusal {
    pub(super) fn retain_terminal(
        &mut self,
        operation: &BirthOperation,
        terminal: Value,
    ) -> Result<()> {
        if operation.family != self.origin.family
            || operation.ordinal != self.origin.ordinal
            || operation.no_native_submit
            || terminal.pointer("/grain/task") != self.origin.tool_view.pointer("/grain/task")
            || terminal.pointer("/grain/status").and_then(Value::as_str) != Some("0")
            || terminal.pointer("/grain/reserved").and_then(Value::as_str) != Some("0")
        {
            return Err("native refusal cleanup differs from its exact birth origin".into());
        }
        self.terminal_tool = Some(terminal);
        Ok(())
    }
    pub(super) fn bind_terminal_files(&mut self, state: &Path, id: u64) -> Result<()> {
        let directory = state.join(format!("query-{id:016}/attempt"));
        let mut files = BTreeMap::new();
        for name in ["view.bin", "challenge.bin", "view.json", "challenge.json"] {
            files.insert(
                name.to_owned(),
                sha256_bytes(&bounded_regular_file(&directory.join(name), 1_048_576)?)?,
            );
        }
        self.terminal_query = Some(id);
        self.terminal_files = files;
        self.verify_terminal_files(state)
    }
    fn verify_terminal_files(&self, state: &Path) -> Result<()> {
        let id = self.terminal_query.ok_or("refusal terminal query absent")?;
        let directory = state.join(format!("query-{id:016}/attempt"));
        if self.terminal_files.len() != 4 {
            return Err("refusal terminal evidence count differs".into());
        }
        for name in ["view.bin", "challenge.bin", "view.json", "challenge.json"] {
            if self.terminal_files.get(name)
                != Some(&sha256_bytes(&bounded_regular_file(
                    &directory.join(name),
                    1_048_576,
                )?)?)
            {
                return Err("refusal terminal signed evidence changed".into());
            }
        }
        let view: Value = serde_json::from_slice(&bounded_regular_file(
            &directory.join("view.json"),
            1_048_576,
        )?)
        .map_err(|e| e.to_string())?;
        let challenge: Value = serde_json::from_slice(&bounded_regular_file(
            &directory.join("challenge.json"),
            1_048_576,
        )?)
        .map_err(|e| e.to_string())?;
        let projection = json!({"grain":view["cell"]["grain"],"targetRoot":view["cell"]["root"],"authorityRoot":challenge["authorityRoot"],"worldRoot":challenge["worldRoot"],"height":challenge["height"]});
        if self.terminal_tool.as_ref() != Some(&projection) {
            return Err("refusal terminal projection differs from signed query".into());
        }
        Ok(())
    }
}

impl Runtime {
    pub(super) fn retain_birth_refusal(
        &mut self,
        origin: &BirthPending,
        refusal: Value,
    ) -> Result<()> {
        // ACP errors retain their existing recovery semantics. This record joins
        // only the explicit foreground request whose result will consume it.
        let Some(WorkOrigin::ForegroundTool { operation_id }) = origin.work_origin.as_ref() else {
            return Ok(());
        };
        let foreground = self
            .journal
            .foreground_attempt
            .as_ref()
            .ok_or("birth refusal foreground absent")?;
        if foreground.operation_id != *operation_id
            || origin.prompt_operation_id != *operation_id
            || self.journal.birth_refusal.is_some()
            || refusal["type"] != "refused"
            || refusal["phase"] != "70726570617265"
        {
            return Err("native refusal does not belong to this foreground request".into());
        }
        let pending = self
            .journal
            .tool_pending
            .as_ref()
            .ok_or("birth refusal pending attempt absent")?;
        self.verify_birth_origin(pending, origin)?;
        let record = BirthRefusal {
            origin: origin.clone(),
            request_id: foreground.request_id.clone(),
            request_sha256: foreground.request_sha256.clone(),
            frame_sha256: sha256_file(&pending.attempt.join("pre-submit-refusal.frame"))?,
            refusal,
            terminal_tool: None,
            terminal_query: None,
            terminal_files: BTreeMap::new(),
        };
        self.journal.birth_refusal = Some(record);
        self.save()
    }

    /// None means an ordinary error. Some is a source-bound native refusal with
    /// completed signed cleanup; all partial or mismatched records are errors.
    pub(super) fn completed_birth_refusal_result(&self) -> Result<Option<Value>> {
        let Some(record) = self.journal.birth_refusal.as_ref() else {
            return Ok(None);
        };
        let foreground = self
            .journal
            .foreground_attempt
            .as_ref()
            .ok_or("refusal foreground missing")?;
        self.journal.validate_foreground(&self.config.state_dir)?;
        if foreground.request_id != record.request_id
            || foreground.request_sha256 != record.request_sha256
            || record.origin.work_origin
                != Some(WorkOrigin::ForegroundTool {
                    operation_id: foreground.operation_id,
                })
            || record.origin.prompt_operation_id != foreground.operation_id
            || self.journal.birth_operation.is_some()
            || self.journal.birth_pending.is_some()
            || self.journal.tool_pending.is_some()
            || self.journal.tool_hold.is_some()
            || self.journal.born_resources.iter().any(|b| {
                b.pending.family == record.origin.family
                    && b.pending.ordinal == record.origin.ordinal
            })
        {
            return Err("native refusal is not terminal for this exact foreground request".into());
        }
        record.verify_terminal_files(&self.config.state_dir)?;
        let terminal = record
            .terminal_tool
            .as_ref()
            .ok_or("native refusal tool cleanup unfinished")?;
        let mut checked = record.clone();
        checked.retain_terminal(
            &BirthOperation {
                family: record.origin.family.clone(),
                ordinal: record.origin.ordinal,
                no_native_submit: false,
            },
            terminal.clone(),
        )?;
        let pending = Pending {
            operation_id: record.origin.operation_id,
            operation: "tool birth".into(),
            attempt: self
                .config
                .state_dir
                .join(format!("attempt-{:016}", record.origin.operation_id)),
            uncertain: false,
            publication: None,
        };
        self.verify_birth_origin(&pending, &record.origin)?;
        if sha256_file(&pending.attempt.join("pre-submit-refusal.frame"))? != record.frame_sha256
            || inspected_pre_submit_refusal(&self.config, &pending.attempt)?.as_ref()
                != Some(&record.refusal)
        {
            return Err("native refusal evidence changed after cleanup".into());
        }
        Ok(Some(json!({"isError":true,"text":json!({
            "type":"mini-resource-birth-refused-v1", "family":record.origin.family,
            "ordinal":record.origin.ordinal,"nativeOperationId":record.origin.operation_id.to_string(),
            "reason":record.refusal.get("reason"),"phase":"prepare", "born":false,
            "toolCharge":"0", "dispositionSha256":sha256_bytes(&serde_json::to_vec(record).map_err(|e|e.to_string())?)?,
            "detail":"Native policy refused this resource birth; delegated tool allowance was released at zero charge."
        }).to_string()})))
    }

    /// A hard attachment break also performs the normal physical stop and
    /// signed fencing path immediately. Recovery calls the shared completion
    /// directly: it must not introduce disconnect effects on a retained hold.
    pub(super) fn complete_attached_foreground_result(
        &mut self,
        result: Value,
        charge: &str,
    ) -> Result<Value> {
        let outcome = self.complete_foreground_result(result, charge);
        if outcome.is_err() && self.completion_phase.load(Ordering::SeqCst) == PHASE_CANCELLED {
            if let Err(cleanup) = self.disconnect() {
                return Err(format!(
                    "{}; hard disconnect: {cleanup}",
                    outcome.unwrap_err()
                ));
            }
        }
        outcome
    }

    /// The ordinary foreground and recovery paths use one result/settlement
    /// sequence. Persisted result bytes precede the first settlement effect.
    pub(super) fn complete_foreground_result(
        &mut self,
        result: Value,
        charge: &str,
    ) -> Result<Value> {
        if self
            .journal
            .foreground_attempt
            .as_ref()
            .is_none_or(|attempt| attempt.phase != ForegroundPhase::Executing)
        {
            return Err(
                "foreground completion is not executing; exact retained recovery required".into(),
            );
        }
        let outcome = (|| -> Result<Value> {
            let operation_id = self
                .journal
                .foreground_attempt
                .as_ref()
                .ok_or("foreground completion absent")?
                .operation_id;
            if let Some(refusal) = &self.journal.birth_refusal {
                let bytes = serde_json::to_vec(refusal).map_err(|e| e.to_string())?;
                let disposition = self
                    .config
                    .state_dir
                    .join(format!("foreground-{operation_id:016}.birth-refusal.json"));
                if disposition.exists() {
                    if bounded_regular_file(&disposition, 4_194_304)? != bytes {
                        return Err("foreground refusal disposition changed".into());
                    }
                } else {
                    write_new(&disposition, &bytes)?;
                }
            }
            let (result, bytes) = bounded_foreground_result(result)?;
            let path = self
                .config
                .state_dir
                .join(format!("foreground-{operation_id:016}.result.json"));
            write_new(&path, &bytes)?;
            let attempt = self.journal.foreground_attempt.as_mut().unwrap();
            attempt.result_path = Some(path);
            attempt.result_sha256 = Some(sha256_bytes(&bytes)?);
            self.save()?;
            if !self.claim_completion(charge)? {
                return Err("foreground completion was interrupted".into());
            }
            self.transition(
                json!({"type":"settle","charge":charge}),
                "settle",
                "foreground tool complete",
            )?;
            self.journal.prompt_witness = None;
            self.journal.foreground_attempt.as_mut().unwrap().phase = ForegroundPhase::Definite;
            self.journal.birth_refusal = None;
            self.save()?;
            self.completion_phase.store(PHASE_IDLE, Ordering::SeqCst);
            Ok(result)
        })();
        if let Err(error) = outcome {
            self.journal.foreground_attempt.as_mut().unwrap().phase = ForegroundPhase::Uncertain;
            self.journal.connection = Connection::Fenced;
            self.cancelled.store(true, Ordering::SeqCst);
            return Err(match self.save() {
                Ok(()) => error,
                Err(persist) => format!("{error}; cannot persist completion fence: {persist}"),
            });
        }
        outcome
    }
}

impl Runtime {
    fn refusal_codec(
        &self,
        directory: &Path,
        verb: &str,
        kind: Option<&str>,
        inputs: &[&str],
    ) -> Result<()> {
        let mut command = Command::new(&self.config.host);
        command.arg(&self.config.host_config).arg(verb);
        if let Some(kind) = kind {
            command.arg(kind);
        }
        for name in inputs {
            command.arg(directory.join(name));
        }
        let output = self
            .custody_gate
            .run_capture(&self.cancelled, &mut command)
            .map_err(|e| format!("native refusal codec: {e}"))?;
        if !output.status.success() {
            return Err("pinned Host refused retained refusal codec".into());
        }
        Ok(())
    }

    fn retained_refusal_query(&self, id: u64, evidence: &Path) -> Result<Value> {
        let directory = evidence.join(format!("query-{id:016}"));
        fs::create_dir(&directory).map_err(|e| e.to_string())?;
        let original = self
            .config
            .state_dir
            .join(format!("query-{id:016}/attempt"));
        for name in [
            "view.bin",
            "challenge.bin",
            "observation-signatures.bin",
            "signed-observation.bin",
        ] {
            write_new(
                &directory.join(name),
                &bounded_regular_file(&original.join(name), 1_048_576)?,
            )?;
        }
        if bounded_regular_file(&original.join("config.json"), 65_536)?
            != bounded_regular_file(&self.config.host_config, 65_536)?
        {
            return Err("retained refusal query config changed".into());
        }
        self.refusal_codec(
            &directory,
            "inspect",
            Some("view-resource"),
            &["view.bin", "view.json"],
        )?;
        self.refusal_codec(
            &directory,
            "inspect",
            Some("challenge"),
            &["challenge.bin", "challenge.json"],
        )?;
        self.refusal_codec(
            &directory,
            "observe-assemble",
            None,
            &[
                "challenge.bin",
                "observation-signatures.bin",
                "reassembled.bin",
            ],
        )?;
        if bounded_regular_file(&directory.join("reassembled.bin"), 1_048_576)?
            != bounded_regular_file(&directory.join("signed-observation.bin"), 1_048_576)?
        {
            return Err("retained query signatures differ from signed observation".into());
        }
        let view: Value = serde_json::from_slice(&bounded_regular_file(
            &directory.join("view.json"),
            1_048_576,
        )?)
        .map_err(|e| e.to_string())?;
        let challenge: Value = serde_json::from_slice(&bounded_regular_file(
            &directory.join("challenge.json"),
            1_048_576,
        )?)
        .map_err(|e| e.to_string())?;
        if view["type"] != "resource"
            || challenge["intent"]["purpose"]["target"] != view["cell"]["grain"]["task"]
            || challenge["intent"]["purpose"]["type"] != "query"
        {
            return Err("retained query challenge and resource identity differ".into());
        }
        Ok(
            json!({"grain":view["cell"]["grain"], "targetRoot":view["cell"]["root"],
            "authorityRoot":challenge["authorityRoot"],"worldRoot":challenge["worldRoot"],"height":challenge["height"]}),
        )
    }

    fn replay_refusal_cleanup(
        &mut self,
        id: u64,
        trace: u64,
        label: &str,
        expected: &Value,
        before: &Value,
    ) -> Result<ReserveAnchor> {
        let source: Value = serde_json::from_slice(&bounded_regular_file(
            &self.config.state_dir.join(format!("source-{id:016}.json")),
            131_072,
        )?)
        .map_err(|e| e.to_string())?;
        let authority = self.tool()?;
        let grain = &source["grain"];
        if !grain_source::retained_identity(
            &source,
            &authority.task,
            &authority.task,
            &authority.subject,
            id,
        ) || grain["subject"] != authority.subject
            || grain["task"] != authority.task
            || grain["capability"] != authority.capability
            || grain["observeCapability"] != authority.query_capability
            || grain["operation"] != *expected
            || grain["before"] != before["grain"]
            || grain["expectedTargetRoot"] != before["targetRoot"]
            || grain["publications"] != json!([])
            || source["grants"]
                != json!([{"kind":"object","target":authority.task,"capability":authority.query_capability}])
        {
            return Err("refusal cleanup source differs from exact tool origin".into());
        }
        let call = self.verify_retained_grain_call(id, trace, label)?;
        let outcome: Value = serde_json::from_slice(&bounded_regular_file(
            &self
                .config
                .state_dir
                .join(format!("attempt-{id:016}/outcome.json")),
            131_072,
        )?)
        .map_err(|e| e.to_string())?;
        let anchor = ReserveAnchor::from_confirmed(&outcome)?;
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
                    .ok_or("refusal replay needs public socket")?,
            )
            .arg("--call")
            .arg(call)
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
                    .join(format!("foreground-{label}-lookup-{trace:016}")),
            );
        let replay = self.supervised_json_command(command)?;
        if ReserveAnchor::from_confirmed(&replay)? != anchor || replay["confirmation"] != "replayed"
        {
            return Err("native refusal cleanup receipt did not replay exactly".into());
        }
        Ok(anchor)
    }

    /// Import the one historical pre-submit refusal emitted by the old runtime,
    /// which discarded its in-journal origin after cleanup. Every input comes
    /// from this retained request's own state; no caller-selected path or effect
    /// is accepted. This function never authors or submits a new native call.
    pub(super) fn adopt_legacy_session_refusal(
        &mut self,
        request: &ForegroundRequest,
        trace: u64,
    ) -> Result<()> {
        let foreground = self
            .journal
            .foreground_attempt
            .as_ref()
            .ok_or("foreground absent")?
            .clone();
        let family_name = request.arguments["family"]
            .as_str()
            .ok_or("refusal family absent")?;
        let app_name = request.arguments["application"]
            .as_str()
            .ok_or("refusal app absent")?;
        let validated = legacy_execution_trace(&self.journal, &foreground)?;
        if validated >= trace
            || self.journal.birth_refusal.is_some()
            || self.journal.birth_next_ordinal.get(family_name) != Some(&1)
        {
            return Err("legacy refusal execution boundary differs".into());
        }
        let mut found = None;
        for (count, entry) in fs::read_dir(&self.config.state_dir)
            .map_err(|e| e.to_string())?
            .enumerate()
        {
            if count >= 4096 {
                return Err("legacy refusal state listing exceeds bound".into());
            }
            let entry = entry.map_err(|e| e.to_string())?;
            let name = entry.file_name();
            let Some(name) = name.to_str() else { continue };
            let Some(id) = name
                .strip_prefix("source-")
                .and_then(|s| s.strip_suffix(".json"))
                .and_then(|s| s.parse::<u64>().ok())
            else {
                continue;
            };
            if id <= validated || id >= trace || name != format!("source-{id:016}.json") {
                continue;
            }
            let value: Value =
                serde_json::from_slice(&bounded_regular_file(&entry.path(), 262_144)?)
                    .map_err(|e| e.to_string())?;
            if value.get("applicationSessionGrainBirth").is_some() {
                if found.replace((id, value)).is_some() {
                    return Err("legacy refusal has multiple candidate births".into());
                }
            }
        }
        let (id, source) = found.ok_or("legacy refusal source not found")?;
        if id < 2 || id.checked_add(7).is_none_or(|last| last >= trace) {
            return Err("legacy refusal cleanup boundary absent".into());
        }
        let evidence = self
            .config
            .state_dir
            .join(format!("foreground-refusal-codec-{trace:016}"));
        fs::create_dir(&evidence).map_err(|e| e.to_string())?;
        fs::set_permissions(&evidence, fs::Permissions::from_mode(0o700))
            .map_err(|e| e.to_string())?;
        let tool_view = self.retained_refusal_query(id - 2, &evidence)?;
        let parent_view = self.retained_refusal_query(id - 1, &evidence)?;
        foreground_session_recovery::parent_matches(
            &self.journal,
            &self.config.task,
            &parent_view,
        )?;
        let tool = self.config.tool_task.clone().ok_or("tool absent")?;
        let family = tool
            .allowed_session_families
            .iter()
            .find(|f| f.name == family_name)
            .ok_or("refusal family changed")?;
        let reference = tool
            .registered_shared_applications
            .iter()
            .find(|r| r.name == app_name && r.application_family == family.application_family)
            .ok_or("legacy refusal requires exact registered shared application")?;
        let selected = self.resolve_shared_app(&tool, reference)?;
        let (expected, born) = application_tools::plan_session_birth(
            family,
            &tool,
            &self.config.task,
            &self.config.subject,
            &selected.app_target,
            application_tools::BirthIndex {
                nonce: id,
                ordinal: 0,
            },
            &tool_view,
            &parent_view,
        )?;
        if source != expected {
            return Err(
                "legacy refusal source differs from original request/family/reservation".into(),
            );
        }
        let attempt = self.config.state_dir.join(format!("attempt-{id:016}"));
        let author = self
            .config
            .state_dir
            .join(format!("current-author-{id:016}"));
        let origin = BirthPending {
            operation_id: id,
            family: family_name.to_owned(),
            ordinal: 0,
            source_sha256: sha256_file(
                &self.config.state_dir.join(format!("source-{id:016}.json")),
            )?,
            born: born[0].clone(),
            born_bundle: born,
            route: Some(ApplicationBirthRoute::Session),
            selected_application: Some(app_name.to_owned()),
            selected_shared: Some(selected),
            authored_intent_sha256: Some(sha256_file(&author.join("intent.bin"))?),
            tool_view: tool_view.clone(),
            parent_view,
            prompt_operation_id: foreground.operation_id,
            session_id: String::new(),
            work_origin: Some(WorkOrigin::ForegroundTool {
                operation_id: foreground.operation_id,
            }),
        };
        self.verify_birth_origin(
            &Pending {
                operation_id: id,
                operation: "tool birth".into(),
                attempt: attempt.clone(),
                uncertain: false,
                publication: None,
            },
            &origin,
        )?;
        let manifest: Value =
            serde_json::from_slice(&bounded_regular_file(&author.join("author.json"), 65_536)?)
                .map_err(|e| e.to_string())?;
        if manifest["type"] != "minidregg-current-application-birth-author-v1"
            || manifest["route"] != "session"
            || manifest["operation"] != 31
            || manifest["sourceSha256"] != origin.source_sha256
            || manifest["hostSha256"] != sha256_pinned_file(&self.config.host)?
            || manifest["host"].as_str().map(Path::new) != Some(self.config.host.as_path())
            || manifest["socket"].as_str().map(Path::new) != self.config.host_socket.as_deref()
        {
            return Err("legacy refusal author manifest differs from pinned source".into());
        }
        for name in [
            "challenge.bin",
            "observation-signatures.bin",
            "signed-observation.bin",
            "intent.bin",
        ] {
            write_new(
                &evidence.join(name),
                &bounded_regular_file(&attempt.join(name), 4_194_304)?,
            )?;
        }
        self.refusal_codec(
            &evidence,
            "inspect",
            Some("challenge"),
            &["challenge.bin", "challenge.json"],
        )?;
        let challenge: Value = serde_json::from_slice(&bounded_regular_file(
            &evidence.join("challenge.json"),
            4_194_304,
        )?)
        .map_err(|e| e.to_string())?;
        write_new(
            &evidence.join("intent.json"),
            &serde_json::to_vec(&challenge["intent"]).map_err(|e| e.to_string())?,
        )?;
        self.refusal_codec(
            &evidence,
            "author",
            Some("intent"),
            &["intent.json", "encoded-intent.bin"],
        )?;
        self.refusal_codec(
            &evidence,
            "observe-assemble",
            None,
            &[
                "challenge.bin",
                "observation-signatures.bin",
                "reassembled.bin",
            ],
        )?;
        if bounded_regular_file(&evidence.join("encoded-intent.bin"), 4_194_304)?
            != bounded_regular_file(&author.join("intent.bin"), 4_194_304)?
            || bounded_regular_file(&evidence.join("intent.bin"), 4_194_304)?
                != bounded_regular_file(&author.join("intent.bin"), 4_194_304)?
            || bounded_regular_file(&evidence.join("reassembled.bin"), 4_194_304)?
                != bounded_regular_file(&attempt.join("signed-observation.bin"), 4_194_304)?
        {
            return Err(
                "legacy refusal signed prepare request differs from authored birth intent".into(),
            );
        }
        let refusal = inspected_pre_submit_refusal(&self.config, &attempt)?
            .ok_or("legacy refusal lacks canonical prepare refusal")?;
        let release_before = json!({"grain":source["applicationSessionGrainBirth"]["tool"]["before"],"targetRoot":tool_view["targetRoot"]});
        let release = self.replay_refusal_cleanup(
            id + 3,
            trace,
            "birth-release",
            &json!({"type":"settle","charge":"0"}),
            &release_before,
        )?;
        let disconnect_view = self.retained_refusal_query(id + 5, &evidence)?;
        let mut disconnect_before = disconnect_view.clone();
        disconnect_before["grain"]
            .as_object_mut()
            .ok_or("disconnect grain absent")?
            .remove("task");
        if disconnect_view["grain"]["status"] != "1"
            || disconnect_view["grain"]["reserved"] != "0"
            || disconnect_view["grain"]["generation"] != tool_view["grain"]["generation"]
            || disconnect_view["worldRoot"] != release.world_root
        {
            return Err("legacy refusal release terminal differs from source generation".into());
        }
        let disconnected = self.replay_refusal_cleanup(
            id + 6,
            trace,
            "birth-disconnect",
            &json!({"type":"disconnect"}),
            &disconnect_before,
        )?;
        if disconnected.accepted_count.parse::<u64>().ok()
            != release
                .accepted_count
                .parse::<u64>()
                .ok()
                .and_then(|n| n.checked_add(1))
        {
            return Err("legacy refusal cleanup receipts are not consecutive".into());
        }
        let terminal = self.retained_refusal_query(id + 7, &evidence)?;
        let expected_generation = tool_view["grain"]["generation"]
            .as_str()
            .and_then(|s| s.parse::<u64>().ok())
            .and_then(|n| n.checked_add(1))
            .ok_or("refusal tool generation invalid")?;
        if terminal["worldRoot"] != disconnected.world_root
            || terminal["grain"]["generation"] != expected_generation.to_string()
        {
            return Err("legacy refusal terminal does not retire its source generation".into());
        }
        let current = self.query_as(&self.tool()?)?;
        if current["targetRoot"] != terminal["targetRoot"] || current["grain"] != terminal["grain"]
        {
            return Err("legacy refusal tool changed after recorded cleanup".into());
        }
        let mut record = BirthRefusal {
            origin,
            request_id: foreground.request_id,
            request_sha256: foreground.request_sha256,
            frame_sha256: sha256_file(&attempt.join("pre-submit-refusal.frame"))?,
            refusal,
            terminal_tool: None,
            terminal_query: None,
            terminal_files: BTreeMap::new(),
        };
        record.retain_terminal(
            &BirthOperation {
                family: family_name.to_owned(),
                ordinal: 0,
                no_native_submit: false,
            },
            terminal,
        )?;
        record.bind_terminal_files(&self.config.state_dir, id + 7)?;
        self.journal.birth_refusal = Some(record);
        self.save()
    }
}

#[cfg(test)]
#[path = "birth_refusal_adversary_tests.rs"]
mod adversary_tests;
#[cfg(test)]
#[path = "birth_refusal_tests.rs"]
mod tests;
