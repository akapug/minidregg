//! Focused typed Config/journal checks; no native admission or network fixture.
use super::*;

fn receipt(count: &str) -> Value {
    json!({"transactionId":"100", "eventId":"101", "acceptedCount":count, "worldRoot":"102"})
}
fn old_config() -> Config {
    serde_json::from_value(json!({
        "mini":"/fixture/mini", "host":"/fixture/host", "hostConfig":"/fixture/host.json",
        "hostSocket":"/fixture/host.sock", "controlSocket":"/fixture/state/control.sock",
        "custodyKey":"/fixture/controller.key", "stateDir":"/fixture/state", "cwd":"/fixture/work",
        "task":"6000", "subject":"8", "capability":"10", "queryCapability":"11", "commands":[],
        "toolTask":{"task":"6300", "subject":"9", "capability":"12", "queryCapability":"13",
            "custodyKey":"/fixture/tool.key", "parentCapability":"14", "parentObserveCapability":"15",
            "reserve":"5", "charge":"0", "allowedPublications":[]},
        "dispatchTask":{"task":"6500", "subject":"10", "capability":"16", "queryCapability":"17",
            "custodyKey":"/fixture/purse.key", "parentCapability":"18", "parentObserveCapability":"19",
            "reserve":"1", "charge":"1", "socketPath":"/fixture/reverse.sock", "hostUid":1001}
    })).unwrap()
}
fn enrolled(old: &Config) -> Config {
    let mut value = serde_json::to_value(old).unwrap();
    let r = receipt("10");
    let birth = json!({"call":"/fixture/birth", "callSha256":"ab".repeat(32),
        "transactionId":"1", "eventId":"2", "acceptedCount":"3", "worldRoot":"4"});
    let issue = json!({"kind":"grainBackedEvent22", "ingress":"/fixture/ticket", "ingressSha256":"cd".repeat(32),
        "transactionId":r["transactionId"], "eventId":r["eventId"], "acceptedCount":r["acceptedCount"], "worldRoot":r["worldRoot"]});
    value["toolTask"]["registeredSharedApplications"] = json!([{
        "name":"shared-app", "applicationFamily":"oracle", "appTarget":"6100", "manifestTarget":"6101",
        "snapshotTarget":"6102", "ticketTarget":"6408", "appObserveCapability":"21",
        "manifestObserveCapability":"22", "snapshotObserveCapability":"23", "ticketObserveCapability":"24",
        "birth":birth, "issue":issue
    }]);
    value["toolTask"]["allowedApplicationLifetimeRoutes"] = json!([{
        "name":"shared-app", "socketPath":"/fixture/agent.sock", "hostUid":1001,
        "hostUnit":"spk-host@example.service", "appResource":"6100", "sessionResource":"6209",
        "ticketResource":"6408", "participantSubject":"8", "parentTask":"6000",
        "originalParentGeneration":"1", "originalDescriptorSha256":"ab".repeat(32),
        "purseResource":"6500", "signedApiPath":"/", "dispatchSelectors":{"issueIndex":"9",
            "packageManifest":"6101", "snapshotManifest":"6102", "sessionObserve":"81",
            "manifestObserve":"82", "enrollmentObserve":"83"},
        "grantIssueIndex":"13", "grantResource":"6600", "grantObserveCapability":"84",
        "grantAttemptDir":"/fixture/grant", "grantDigest":"103", "grantInitializedRoot":"104",
        "originalIssueReceipt":r, "grantIssueReceipt":receipt("14")
    }]);
    value["toolTask"]["applicationServices"] = json!([{"application":"shared-app", "protocol":"oracle-operations-v1"}]);
    value["toolTask"]["lifetimeApiHostSha256"] = json!("ef".repeat(32));
    serde_json::from_value(value).unwrap()
}

#[test]
fn first_addition_accepts_actual_serde_skipped_empty_vectors() {
    let old = old_config(); let new = enrolled(&old);
    let old_json = serde_json::to_value(&old).unwrap();
    assert!(old_json["toolTask"].get("applicationServices").is_none());
    assert!(old_json["toolTask"].get("allowedApplicationLifetimeRoutes").is_none());
    let mut journal = Journal::fresh(json!({"config":old, "configPath":"/fixture/controller.json"}));
    journal.connection = Connection::Fenced; journal.next_operation_id = 2;
    let before = serde_json::to_value(&journal).unwrap();
    assert!(quiescent(&journal, quiescence::ResidentEvidence::NotConfigured).is_ok());
    assert!(permitted(&old, &new, &journal, "application").is_ok());
    assert_eq!(serde_json::to_value(&journal).unwrap(), before, "checking may not reset the prior query or journal");
}

#[test]
fn swapped_lineage_and_changed_old_authority_are_refused() {
    let old = old_config(); let good = enrolled(&old); let journal = Journal::fresh(json!({}));
    for (pointer, replacement) in [
        ("/toolTask/registeredSharedApplications/0/issue/worldRoot", json!("999")),
        ("/toolTask/applicationServices/0/application", json!("other-app")),
        ("/toolTask/allowedApplicationLifetimeRoutes/0/dispatchSelectors/packageManifest", json!("999")),
        ("/toolTask/allowedApplicationLifetimeRoutes/0/ticketResource", json!("999")),
        ("/dispatchTask/subject", json!("999")),
        ("/toolTask/subject", json!("999")),
    ] {
        let mut value = serde_json::to_value(&good).unwrap();
        *value.pointer_mut(pointer).unwrap() = replacement;
        let changed: Config = serde_json::from_value(value).unwrap();
        assert!(permitted(&old, &changed, &journal, "application").is_err(), "{pointer}");
    }
}

#[test]
fn only_host_unit_may_change_on_existing_route() {
    let old = enrolled(&old_config());
    let mut value = serde_json::to_value(&old).unwrap();
    value["toolTask"]["allowedApplicationLifetimeRoutes"][0]["hostUnit"] = json!("spk-host@new.service");
    let refreshed: Config = serde_json::from_value(value.clone()).unwrap();
    let journal = Journal::fresh(json!({}));
    assert!(permitted(&old, &refreshed, &journal, "application").is_ok());
    value["toolTask"]["allowedApplicationLifetimeRoutes"][0]["grantResource"] = json!("999");
    let wrong: Config = serde_json::from_value(value).unwrap();
    assert!(permitted(&old, &wrong, &journal, "application").is_err());
    // This pure selector check is not the required live native hello check.
}

#[test]
fn prompt_or_unresolved_history_cannot_be_declared_quiescent() {
    let mut journal = Journal::fresh(json!({}));
    journal.connection = Connection::Fenced; journal.next_operation_id = 2;
    assert!(quiescent(&journal, quiescence::ResidentEvidence::NotConfigured).is_ok());
    journal.prompt_witness = Some(json!({"request":"active"}));
    assert!(quiescent(&journal, quiescence::ResidentEvidence::NotConfigured).is_err());
    journal.prompt_witness = None;
    journal.unresolved_external.push("possibly submitted".into());
    assert!(quiescent(&journal, quiescence::ResidentEvidence::NotConfigured).is_err());
    assert_eq!(journal.next_operation_id, 2);
}
// Append inside application_enrollment_adversary_tests.rs in a test-only
// snapshot. The production module and release executable are unchanged.
#[test]
fn raw_provider_gate_refuses_before_older_typed_journal_can_drop_it() {
    let nonce = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos();
    let root = std::env::temp_dir().join(format!("mini-enrollment-raw-gate-{}-{nonce}", std::process::id()));
    directory(&root).unwrap();
    for (label, gate) in [("absent",None), ("null",Some(Value::Null)),
        ("retained",Some(json!({"request":"still-pending"})))] {
        let dir = root.join(label); directory(&dir).unwrap();
        let state = dir.join("state"); directory(&state).unwrap();
        let config_path = dir.join("controller.json");
        let mut config = serde_json::to_value(old_config()).unwrap();
        config["stateDir"] = json!(state);
        let config_bytes = serde_json::to_vec(&config).unwrap();
        write_new(&config_path,&config_bytes).unwrap();
        let mut journal = json!({"binding":{"config":config,"configPath":config_path}});
        if let Some(gate) = gate { journal["providerRetryGate"] = gate; }
        let journal_bytes = serde_json::to_vec(&journal).unwrap();
        write_new(&state.join("journal.json"),&journal_bytes).unwrap();
        let request_path = dir.join("request.json");
        write_new(&request_path,&serde_json::to_vec(&json!({"protocol":PROTOCOL,
            "mode":"application","expectedBindingSha256":"0".repeat(64),
            "targetConfigSha256":sha256_bytes(&config_bytes).unwrap()})).unwrap()).unwrap();
        let error = run(&config_path,&request_path).unwrap_err();
        if label == "retained" {
            assert_eq!(error,"enrollment refuses retained provider retry work");
        } else {
            // Deliberately wrong expected binding proves null/absent passed
            // the raw gate and reached the independent next admission check.
            assert_eq!(error,"source journal binding differs from expected enrollment");
        }
        assert_eq!(private(&state.join("journal.json"),JOURNAL_LIMIT).unwrap(),journal_bytes);
        assert_eq!(private(&config_path,1_048_576).unwrap(),config_bytes);
    }
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn every_resident_work_kind_blocks_enrollment_without_changing_journal() {
    use quiescence::ResidentEvidence;
    let journal = Journal::fresh(json!({}));
    let before = serde_json::to_vec(&journal).unwrap();
    assert!(quiescent(&journal, ResidentEvidence::Unknown).is_err());
    for flag in 0..=5 {
        let evidence = ResidentEvidence::Stopped {
            prompt_pending: flag == 1, return_pending: flag == 2,
            queued_requests: flag == 3, started_request: flag == 4,
            maintenance_pending: flag == 5,
        };
        assert_eq!(quiescent(&journal, evidence).is_ok(), flag == 0);
        assert_eq!(serde_json::to_vec(&journal).unwrap(), before);
    }
}

#[test]
fn resident_selector_requires_real_private_direct_child_and_holds_its_lock() {
    let (root, rt) = crate::tests::restart_resolution_fixture("enrollment-resident");
    let state = rt.config.state_dir.join("resident");
    directory(&state).unwrap();
    write_new(&state.join("resident.lock"), b"").unwrap();
    write_new(&state.join("resident.json"), br#"{"completed":0}"#).unwrap();
    let guard = quiescence::ResidentGuard::acquire(&rt.config, Some(&state)).unwrap();
    assert!(quiescent(&Journal::fresh(json!({})), guard.evidence()).is_ok());
    assert!(quiescence::ResidentGuard::acquire(&rt.config, Some(&state)).is_err());
    let alias = rt.config.state_dir.join("alias");
    std::os::unix::fs::symlink(&state, &alias).unwrap();
    assert!(quiescence::ResidentGuard::acquire(&rt.config, Some(&alias)).is_err());
    assert!(quiescence::ResidentGuard::acquire(&rt.config, Some(&root)).is_err());
    atomic_json(&state.join("resident.json"), &json!({"completed":0,"pending":{"request":"uncertain"}})).unwrap();
    assert!(guard.assert_unchanged().is_err());
    drop(guard);
    let guard = quiescence::ResidentGuard::acquire(&rt.config, Some(&state)).unwrap();
    assert!(quiescent(&Journal::fresh(json!({})), guard.evidence()).is_err());
    drop(guard); drop(rt); fs::remove_dir_all(root).unwrap();
}


#[test]
fn consumed_terminal_origin_allows_enrollment_without_erasing_history() {
    let (mut rt, root, _) = prompt_outcome::tests::audited_fixture();
    let state=rt.config.state_dir.join("resident");directory(&state).unwrap();
    write_new(&state.join("resident.lock"),b"").unwrap();
    let origin=serde_json::to_value(rt.journal.resident_prompt_origin.as_ref().unwrap()).unwrap();
    let resident=json!({"completed":1,"pending":null,"lastInput":null,"lastCompletion":{
        "type":"prompt-complete","outcome":"failed","residentOrigin":origin},"returnPending":false});
    atomic_json(&state.join("resident.json"),&resident).unwrap();
    let requests=json!({"binding":{},"pending":[],"selected":null,"lastAuthor":null});
    atomic_json(&state.join("requests.json"),&requests).unwrap();
    let guard=quiescence::ResidentGuard::acquire(&rt.config,Some(&state)).unwrap();
    assert!(consumed_origin(&rt.journal,&rt.config,&guard).is_err(),"undecided is not terminal");
    drop(guard);rt.reconcile_prompt_audited("67").unwrap();
    let before=serde_json::to_value(&rt.journal).unwrap();
    let guard=quiescence::ResidentGuard::acquire(&rt.config,Some(&state)).unwrap();
    let proof=consumed_origin(&rt.journal,&rt.config,&guard).unwrap().unwrap();
    quiescent_with_origin(&rt.journal,guard.evidence(),Some(&proof)).unwrap();
    assert!(quiescent(&rt.journal,guard.evidence()).is_err(),"origin alone is not permission");
    assert_eq!(proof.0["origin"],origin);
    assert_eq!(proof.0["promptEvidence"]["outcome"]["state"],"refused");
    assert!(proof.0["promptEvidence"]["resolution"].is_object());
    let mut target=rt.config.clone();target.tool_task.as_mut().unwrap().agent_api_host_sha256=Some("d".repeat(64));
    let (after,_)=successor(&before,&target,&rt.config_path).unwrap();
    let mut without_binding=after.clone();without_binding["binding"]=before["binding"].clone();
    assert_eq!(without_binding,before);assert_eq!(after["residentPromptOrigin"],origin);
    guard.assert_unchanged().unwrap();drop(guard);
    for (field,value) in [("pending",json!({"uncertain":true})),("returnPending",json!(true)),("completed",json!(0)),
        ("lastCompletion",json!({"type":"prompt-complete","outcome":"failed","residentOrigin":{
            "promptOperationId":68,"residentPromptId":"a".repeat(64),"promptSha256":"b".repeat(64),"sessionId":null}}))] {
        let mut changed=resident.clone();changed[field]=value;atomic_json(&state.join("resident.json"),&changed).unwrap();
        let guard=quiescence::ResidentGuard::acquire(&rt.config,Some(&state)).unwrap();
        assert!(consumed_origin(&rt.journal,&rt.config,&guard).is_err(),"{field}");
    }
    atomic_json(&state.join("resident.json"),&resident).unwrap();
    let mut queued=requests.clone();queued["pending"]=json!([{"identity":{},"entry":{}}]);
    atomic_json(&state.join("requests.json"),&queued).unwrap();
    let guard=quiescence::ResidentGuard::acquire(&rt.config,Some(&state)).unwrap();
    assert!(consumed_origin(&rt.journal,&rt.config,&guard).is_err());drop(guard);
    atomic_json(&state.join("requests.json"),&requests).unwrap();
    let guard=quiescence::ResidentGuard::acquire(&rt.config,Some(&state)).unwrap();
    let mut other:Journal=serde_json::from_value(before.clone()).unwrap();
    other.resident_prompt_origin.as_mut().unwrap().session_id=Some("foreign-session".into());
    assert!(consumed_origin(&other,&rt.config,&guard).is_err());
    assert_eq!(serde_json::to_value(&rt.journal).unwrap(),before);
    drop(guard);drop(rt);fs::remove_dir_all(root).unwrap();
}

#[test]
#[ignore="requires the retained post-drain q2 capture; reads data only"]
fn consumed_terminal_origin_accepts_retained_native_capture() {
    let file=std::env::var_os("MINI_ENROLLMENT_CONSUMED_CAPTURE").expect("capture path required");
    let capture:Value=serde_json::from_slice(&fs::read(file).unwrap()).unwrap();
    let journal:Journal=serde_json::from_value(capture["journal"].clone()).unwrap();
    let record:prompt_outcome::Record=serde_json::from_value(capture["resolution"]["record"].clone()).unwrap();
    record.validate().unwrap();
    assert_eq!(capture["resolution"]["originalSha256"],sha256_bytes(capture["original"].as_str().unwrap().as_bytes()).unwrap());
    validate_consumed_frame(journal.resident_prompt_origin.as_ref().unwrap(),capture["resident"].as_str().unwrap().as_bytes(),&record).unwrap();
    let request:Value=serde_json::from_str(capture["requests"].as_str().unwrap()).unwrap();
    assert_eq!(request["pending"],json!([]));assert!(request["selected"].is_null());assert!(request["maintenancePending"].is_null());
    let evidence=quiescence::ResidentEvidence::Stopped{prompt_pending:false,return_pending:false,
        queued_requests:false,started_request:false,maintenance_pending:false};
    let proof=ConsumedOriginProof(json!({"origin":journal.resident_prompt_origin}));
    quiescent_with_origin(&journal,evidence,Some(&proof)).unwrap();
}

#[test]
fn consumed_admitted_turn_enrolls_preserving_session_and_all_receipts() {
    for refused in [false,true] {
        let (root,rt,state)=resident_completion::tests::consumed_fixture(if refused {"enrollment-final-refused"} else {"enrollment-final-performed"},refused);
        let before=serde_json::to_value(&rt.journal).unwrap();
        let guard=quiescence::ResidentGuard::acquire(&rt.config,Some(&state)).unwrap();
        let proof=consumed_origin(&rt.journal,&rt.config,&guard).unwrap().unwrap();
        quiescent_with_origin(&rt.journal,guard.evidence(),Some(&proof)).unwrap();
        assert!(quiescent(&rt.journal,guard.evidence()).is_err());
        let mut target=rt.config.clone();target.tool_task.as_mut().unwrap().agent_api_host_sha256=Some("d".repeat(64));
        let (mut after,_)=successor(&before,&target,&rt.config_path).unwrap();
        let enrolled:Journal=serde_json::from_value(after.clone()).unwrap();
        assert_eq!(consumed_origin(&enrolled,&target,&guard).unwrap().unwrap().0,proof.0,"historical proof survives an allowed binding-only enrollment");
        after["binding"]=before["binding"].clone();assert_eq!(after,before);
        let mut foreign:Journal=serde_json::from_value(before.clone()).unwrap();foreign.resident_prompt_origin.as_mut().unwrap().prompt_operation_id=41;
        assert!(consumed_origin(&foreign,&rt.config,&guard).is_err());
        guard.assert_unchanged().unwrap();drop(guard);drop(rt);fs::remove_dir_all(root).unwrap();
    }
}
