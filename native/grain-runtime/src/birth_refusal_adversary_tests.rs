//! Exercises refusal producer and completion with a controlled client, not Mini admission.
use super::*;

fn log(rt: &Runtime) -> Vec<u8> {
    fs::read(rt.config.state_dir.join("operations.jsonl")).unwrap()
}

#[test]
fn actual_producer_rejects_substituted_foreground_origin_or_terminal() {
    for variant in 0..9 {
        let (mut rt, root) = tests::fixture(false);
        assert!(tests::produce(&mut rt).contains("resource birth refused"));
        assert!(rt.completed_birth_refusal_result().unwrap().is_some());
        let before = log(&rt);
        let record = rt.journal.birth_refusal.as_mut().unwrap();
        match variant {
            0 => record.request_id = "ffffffffffffffffffffffffffffffff".into(),
            1 => record.request_sha256 = "00".repeat(32),
            2 => record.origin.operation_id += 1,
            3 => record.origin.ordinal += 1,
            4 => record.terminal_tool.as_mut().unwrap()["grain"]["status"] = json!("1"),
            5 => record.terminal_tool.as_mut().unwrap()["grain"]["reserved"] = json!("1"),
            6 => record.terminal_tool.as_mut().unwrap()["grain"]["task"] = json!("9999"),
            7 => record.terminal_tool.as_mut().unwrap()["grain"]["remaining"] = json!("999"),
            8 => record.terminal_tool.as_mut().unwrap()["targetRoot"] = json!("999"),
            _ => unreachable!(),
        }
        assert!(
            rt.completed_birth_refusal_result().is_err(),
            "variant {variant}"
        );
        assert!(rt.journal.parent_hold.is_some());
        assert!(rt.foreground_result(tests::REQUEST).is_err());
        assert_eq!(before, log(&rt));
        fs::remove_dir_all(root).unwrap();
    }
}

#[test]
fn actual_producer_rejects_replaced_refusal_frame_and_source() {
    for variant in 0..2 {
        let (mut rt, root) = tests::fixture(false);
        tests::produce(&mut rt);
        let origin = &rt.journal.birth_refusal.as_ref().unwrap().origin;
        let id = origin.operation_id;
        let path = if variant == 0 {
            rt.config
                .state_dir
                .join(format!("attempt-{id:016}/pre-submit-refusal.frame"))
        } else {
            rt.config.state_dir.join(format!("source-{id:016}.json"))
        };
        fs::write(path, b"substituted foreign evidence").unwrap();
        let before = log(&rt);
        assert!(rt.completed_birth_refusal_result().is_err());
        assert!(rt.journal.parent_hold.is_some());
        assert_eq!(before, log(&rt));
        fs::remove_dir_all(root).unwrap();
    }
}

#[test]
fn result_path_collision_cannot_settle_or_replace_existing_result() {
    let (mut rt, root) = tests::fixture(false);
    tests::produce(&mut rt);
    let result = rt.completed_birth_refusal_result().unwrap().unwrap();
    let path = rt
        .config
        .state_dir
        .join("foreground-0000000000000013.result.json");
    write_new(&path, b"earlier unresolved bytes").unwrap();
    let before = log(&rt);
    assert!(rt.complete_foreground_result(result, "0").is_err());
    assert_eq!(fs::read(&path).unwrap(), b"earlier unresolved bytes");
    assert_eq!(before, log(&rt));
    assert!(rt.journal.parent_hold.is_some());
    assert!(rt.journal.birth_refusal.is_some());
    assert!(rt.foreground_result(tests::REQUEST).is_err());
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn failed_parent_settlement_keeps_result_and_refusal_without_a_second_attempt() {
    let (mut rt, root) = tests::fixture(false);
    tests::produce(&mut rt);
    let result = rt.completed_birth_refusal_result().unwrap().unwrap();
    let script = fs::read_to_string(&rt.config.mini).unwrap().replace(
        "if t=='7102' and a['type']=='settle'",
        "if t=='7101' and a['type']=='settle'",
    );
    fs::write(&rt.config.mini, script).unwrap();
    fs::write(rt.config.state_dir.join("fail-release"), b"1").unwrap();
    assert!(rt.complete_foreground_result(result.clone(), "0").is_err());
    let attempt = rt.journal.foreground_attempt.as_ref().unwrap();
    let path = attempt.result_path.as_ref().unwrap();
    assert_eq!(
        serde_json::from_slice::<Value>(&fs::read(path).unwrap()).unwrap(),
        result
    );
    assert!(rt.journal.birth_refusal.is_some());
    assert!(rt.journal.parent_hold.is_some());
    assert!(rt
        .config
        .state_dir
        .join("foreground-0000000000000013.birth-refusal.json")
        .is_file());
    let before = log(&rt);
    assert!(rt.complete_foreground_result(result, "0").is_err());
    assert!(rt.create_resource(&json!({"family":"page"}), None).is_err());
    assert_eq!(before, log(&rt));
    assert!(rt.foreground_result(tests::REQUEST).is_err());
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn terminal_query_substitution_and_post_ack_disposition_are_bound() {
    let (mut rt, root) = tests::fixture(false);
    tests::produce(&mut rt);
    let record = rt.journal.birth_refusal.as_ref().unwrap();
    let query = record.terminal_query.unwrap();
    let view = rt
        .config
        .state_dir
        .join(format!("query-{query:016}/attempt/view.json"));
    let original = fs::read(&view).unwrap();
    let mut altered: Value = serde_json::from_slice(&original).unwrap();
    altered["cell"]["root"] = json!("999999");
    fs::write(&view, serde_json::to_vec(&altered).unwrap()).unwrap();
    let before = log(&rt);
    assert!(rt.completed_birth_refusal_result().is_err());
    assert_eq!(before, log(&rt));
    fs::write(&view, original).unwrap();
    let result = rt.completed_birth_refusal_result().unwrap().unwrap();
    let detail: Value = serde_json::from_str(result["text"].as_str().unwrap()).unwrap();
    let expected = detail["dispositionSha256"].as_str().unwrap().to_owned();
    rt.complete_foreground_result(result, "0").unwrap();
    let path = rt
        .config
        .state_dir
        .join("foreground-0000000000000013.birth-refusal.json");
    assert_eq!(sha256_file(&path).unwrap(), expected);
    rt.acknowledge_foreground(tests::REQUEST).unwrap();
    assert_eq!(sha256_file(&path).unwrap(), expected);
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn legacy_trace_requires_exact_request_digest_decision_and_identity() {
    let (rt, root) = tests::fixture(false);
    let mut journal: Journal = serde_json::from_value(serde_json::to_value(&rt.journal).unwrap()).unwrap();
    let attempt = journal.foreground_attempt.as_ref().unwrap().clone();
    let id = journal.next_operation_id - 1;
    journal.reconciliation_log.push(json!({"action":"foreground-session-resume","stage":"requested",
        "decisionId":id.to_string(),"operationId":attempt.operation_id.to_string(),
        "requestId":attempt.request_id,"requestSha256":attempt.request_sha256}));
    journal.reconciliation_log.push(json!({"action":"foreground-session-resume","stage":"validated",
        "decisionId":id.to_string(),"operationId":attempt.operation_id.to_string(),"requestId":attempt.request_id}));
    assert_eq!(legacy_execution_trace(&journal, &attempt).unwrap(), id);
    let value = serde_json::to_value(&journal).unwrap();
    let len = journal.reconciliation_log.len();
    for (entry, field, bad) in [
        (len-2, "requestSha256", json!("00".repeat(32))),
        (len-2, "decisionId", json!((id+1).to_string())),
        (len-1, "decisionId", json!((id+1).to_string())),
        (len-2, "requestId", json!("ffffffffffffffffffffffffffffffff")),
        (len-1, "requestId", json!("ffffffffffffffffffffffffffffffff")),
        (len-2, "operationId", json!("14")),
        (len-1, "operationId", json!("14")),
    ] {
        let mut changed = value.clone();
        changed["reconciliationLog"][entry][field] = bad;
        let changed: Journal = serde_json::from_value(changed).unwrap();
        let before = serde_json::to_vec(&changed).unwrap();
        assert!(legacy_execution_trace(&changed, &attempt).is_err(), "{field}");
        assert_eq!(before, serde_json::to_vec(&changed).unwrap());
    }
    fs::remove_dir_all(root).unwrap();
}
