//! Actual Runtime refusal paths using a controlled local client; no native admission.
use super::*;

const REQUEST: &str = "839a6731941b62b1179b4de9c076f0df";

fn runtime() -> (Runtime, tests::Fixture, PathBuf) {
    let (mut rt, root) = crate::publication_refusal_tests::fixture(false, false, false);
    let fixture = tests::Fixture::new();
    rt.config.state_dir = fixture.state.clone();
    rt.config.host_socket = Some(root.join("host.sock"));
    rt.config.foreground_tool = Some(ForegroundToolProfile {
        reserve: "1".into(),
        charge: "0".into(),
    });
    fs::write(&rt.config.host, b"controlled host").unwrap();
    let host_hash = sha256_file(&rt.config.host).unwrap();
    let tool = rt.config.tool_task.as_mut().unwrap();
    tool.current_birth_host_sha256 = Some(host_hash);
    tool.allowed_session_families = vec![serde_json::from_value(json!({
        "name":"browser", "applicationFamily":"oracle", "kind":"web",
        "profile":{"genesis":{},"template":{},"factoryTarget":"10","factoryObserveCapability":"20",
        "payerAccount":"11","payerCapability":"21","payerObserveCapability":"22","tariffBase":"5","tariffPerBirth":"2"},
        "namespace":{"session":"400","descriptor":"500","sessionOwnerCapability":"1600",
        "sessionControlCapability":"1700","descriptorOwnerCapability":"1800","descriptorControlCapability":"1900"},
        "maxBirths":2,"maxResultBytes":1024
    })).unwrap()];
    tool.registered_shared_applications = vec![serde_json::from_value(json!({
        "name":"shared-oracle","applicationFamily":"oracle","appTarget":"6100","manifestTarget":"6101",
        "snapshotTarget":"6102","ticketTarget":"6408","appObserveCapability":"21",
        "manifestObserveCapability":"22","snapshotObserveCapability":"23","ticketObserveCapability":"24",
        "birth":{"call":"/fixture/birth","callSha256":"ab".repeat(32),"transactionId":"1","eventId":"2","acceptedCount":"3","worldRoot":"4"},
        "issue":{"kind":"grainBackedEvent22","ingress":"/fixture/ticket","ingressSha256":"cd".repeat(32),"transactionId":"100","eventId":"101","acceptedCount":"10","worldRoot":"102"}
    })).unwrap()];
    rt.journal = serde_json::from_value(serde_json::to_value(&fixture.journal).unwrap()).unwrap();
    rt.child = None;
    rt.prompt_active = false;
    // Any attempted custody command leaves a visible marker and fails.
    fs::write(
        &rt.config.mini,
        format!(
            "#!/bin/sh\nprintf called > '{}'; exit 1\n",
            root.join("called").display()
        ),
    )
    .unwrap();
    (rt, fixture, root)
}

fn unchanged(rt: &Runtime, original: &Value, root: &Path) {
    assert!(!root.join("called").exists());
    assert_eq!(&serde_json::to_value(&rt.journal).unwrap(), original);
    assert!(rt.preserves_foreground_session());
}

#[test]
fn runtime_refuses_wrong_request_or_active_controller_before_custody() {
    for mode in 0..2 {
        let (mut rt, _fixture, root) = runtime();
        if mode == 1 {
            rt.prompt_active = true;
        }
        let original = serde_json::to_value(&rt.journal).unwrap();
        let id = if mode == 0 {
            "ffffffffffffffffffffffffffffffff"
        } else {
            REQUEST
        };
        assert!(rt.recover_foreground_session(id).is_err());
        unchanged(&rt, &original, &root);
        fs::remove_dir_all(root).unwrap();
    }
}

#[test]
fn runtime_never_reexecutes_after_birth_or_orphan_result() {
    for mode in 0..2 {
        let (mut rt, fixture, root) = runtime();
        if mode == 0 {
            rt.journal.birth_next_ordinal.insert("browser".into(), 1);
        } else {
            write_new(
                &fixture
                    .state
                    .join("foreground-0000000000000013.result.json"),
                b"{}",
            )
            .unwrap();
        }
        let original = serde_json::to_value(&rt.journal).unwrap();
        assert!(rt.recover_foreground_session(REQUEST).is_err());
        unchanged(&rt, &original, &root);
        fs::remove_dir_all(root).unwrap();
    }
}

#[test]
fn runtime_rejects_changed_profile_and_unavailable_family_before_custody() {
    for mode in 0..2 {
        let (mut rt, _fixture, root) = runtime();
        if mode == 0 {
            rt.config.foreground_tool.as_mut().unwrap().reserve = "2".into();
        } else {
            rt.config
                .tool_task
                .as_mut()
                .unwrap()
                .allowed_session_families
                .clear();
        }
        let original = serde_json::to_value(&rt.journal).unwrap();
        assert!(rt.recover_foreground_session(REQUEST).is_err());
        unchanged(&rt, &original, &root);
        fs::remove_dir_all(root).unwrap();
    }
}

fn source(rt: &Runtime) -> Value {
    let p = rt.parent();
    json!({"intentNonce":"16", "grain":{
        "task":p.task,"subject":p.subject,"capability":p.capability,"observeCapability":p.query_capability,
        "schemaVersion":"1","expectedTargetRoot":"10","before":{"generation":"1","status":"2","reserved":"0"},
        "operation":{"type":"reserve","amount":"1"},"context":{"operationId":"16","payload":"foreground tool"},"publications":[]},
        "grants":[{"kind":"object","target":p.task,"capability":p.query_capability}]})
}

#[test]
fn source_binding_refuses_wrong_authority_reservation_and_identity() {
    let (rt, _fixture, root) = runtime();
    let hold = rt.journal.parent_hold.as_ref().unwrap();
    let good = source(&rt);
    reserve_source_matches(&good, &rt.parent(), hold, 16).unwrap();
    for (pointer, bad) in [
        ("/grain/task", json!("999")),
        ("/grain/subject", json!("999")),
        ("/grain/capability", json!("999")),
        ("/grain/observeCapability", json!("999")),
        ("/grain/expectedTargetRoot", json!("999")),
        ("/grain/before/generation", json!("2")),
        ("/grain/before/status", json!("4")),
        ("/grain/before/reserved", json!("1")),
        ("/grain/operation/amount", json!("2")),
        ("/grain/context/operationId", json!("17")),
        ("/intentNonce", json!("17")),
        ("/grants/0/capability", json!("999")),
        ("/grain/publications", json!([{}])),
    ] {
        let mut changed = good.clone();
        *changed.pointer_mut(pointer).unwrap() = bad;
        assert!(
            reserve_source_matches(&changed, &rt.parent(), hold, 16).is_err(),
            "{pointer}"
        );
    }
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn runtime_rejects_changed_original_reserve_before_any_native_call() {
    let (mut rt, fixture, root) = runtime();
    let attempt = fixture.state.join("attempt-0000000000000016");
    fs::create_dir(&attempt).unwrap();
    write_new(
        &attempt.join("outcome.json"),
        &serde_json::to_vec(&json!({
        "type":"confirmed","confirmation":"installed","worldRoot":"20",
        "transactionId":"11","eventId":"12","acceptedCount":"13"}))
        .unwrap(),
    )
    .unwrap();
    let mut wrong = source(&rt);
    wrong["grain"]["operation"]["amount"] = json!("2");
    let bytes = serde_json::to_vec(&wrong).unwrap();
    write_new(&fixture.state.join("source-0000000000000016.json"), &bytes).unwrap();
    write_new(&attempt.join("intent.json"), &bytes).unwrap();
    let original_hold = serde_json::to_value(&rt.journal.parent_hold).unwrap();
    let error = rt.recover_foreground_session(REQUEST).unwrap_err();
    assert!(
        error.contains("not this foreground parent reserve"),
        "{error}"
    );
    assert!(!root.join("called").exists());
    assert_eq!(
        serde_json::to_value(&rt.journal.parent_hold).unwrap(),
        original_hold
    );
    assert!(rt.preserves_foreground_session());
    assert!(rt.journal.birth_next_ordinal.is_empty());
    assert!(!fixture
        .state
        .join("foreground-0000000000000013.result.json")
        .exists());
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn runtime_fences_after_result_and_settlement_failure_without_losing_evidence() {
    let (mut rt, fixture, root) = runtime();
    let result = fixture
        .state
        .join("foreground-0000000000000013.result.json");
    let bytes = b"{\"isError\":false,\"text\":\"session pair\"}";
    write_new(&result, bytes).unwrap();
    let attempt = rt.journal.foreground_attempt.as_mut().unwrap();
    attempt.phase = ForegroundPhase::Executing;
    attempt.result_path = Some(result.clone());
    attempt.result_sha256 = Some(sha256_bytes(bytes).unwrap());
    rt.journal.birth_next_ordinal.insert("browser".into(), 1);
    rt.journal.settlement_due = Some("0".into());
    rt.foreground_operation = Some(13);
    assert!(rt
        .finish_foreground_session_recovery(22, Err("injected settle failure".into()))
        .is_err());
    assert!(rt.foreground_operation.is_none());
    assert!(rt.cancelled.load(Ordering::SeqCst));
    let saved: Journal =
        serde_json::from_slice(&fs::read(fixture.state.join("journal.json")).unwrap()).unwrap();
    assert!(matches!(saved.connection, Connection::Fenced));
    let attempt = saved.foreground_attempt.as_ref().unwrap();
    assert!(matches!(attempt.phase, ForegroundPhase::Uncertain));
    assert_eq!(attempt.result_path.as_deref(), Some(result.as_path()));
    assert_eq!(
        attempt.result_sha256.as_deref(),
        Some(sha256_bytes(bytes).unwrap().as_str())
    );
    assert_eq!(saved.birth_next_ordinal.get("browser"), Some(&1));
    assert_eq!(saved.settlement_due.as_deref(), Some("0"));
    assert_eq!(fs::read(result).unwrap(), bytes);
    assert!(rt.recover_foreground_session(REQUEST).is_err());
    assert!(!root.join("called").exists());
    fs::remove_dir_all(root).unwrap();
}
