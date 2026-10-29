//! Controller orchestration tests. The Mini fixture supplies signed-read-shaped
//! output; these tests do not substitute for native Host admission qualification.
use super::*;

const REQUEST_ID: &str = "1e32c65b408b985976785868a4d9117a";

fn fixture(tag: &str) -> (PathBuf, Runtime, Value) {
    let (root, mut rt) = tests::restart_resolution_fixture(tag);
    rt.journal = Journal::fresh(json!({}));
    rt.journal.next_operation_id = 100;
    rt.process_first_operation_id = 100;
    rt.journal.connection = Connection::Soft;
    rt.config.foreground_tool = Some(ForegroundToolProfile { reserve: "1".into(), charge: "1".into() });
    rt.config.dispatch_task = Some(serde_json::from_value(json!({
        "task":"7500","subject":"12","capability":"121","queryCapability":"122",
        "custodyKey":root.join("payer.key"),"parentCapability":"1204","parentObserveCapability":"1205",
        "reserve":"1","charge":"1","socketPath":root.join("dispatch.sock"),"hostUid":1001,
        "operatorSocket":root.join("private-operator.sock"),
        "reserveSigner":{"role":"4","index":"0","publicKey":"aa".repeat(32),"keyId":"12000","keyEpoch":"1"}
    })).unwrap());
    let receipt = json!({"transactionId":"1","eventId":"2","acceptedCount":"3","worldRoot":"4"});
    let route: application_api_tools::LifetimeRoutePin = serde_json::from_value(json!({
        "name":"oracle","socketPath":root.join("agent.sock"),"hostUid":1001,"hostUnit":"spk-host@test.service",
        "appResource":"6100","sessionResource":"6209","ticketResource":"6408","participantSubject":"7",
        "parentTask":"7101","originalParentGeneration":"1","originalDescriptorSha256":"ab".repeat(32),
        "purseResource":"7500","signedApiPath":"/",
        "dispatchSelectors":{"issueIndex":"9","packageManifest":"6101","snapshotManifest":"6102",
            "sessionObserve":"81","manifestObserve":"82","enrollmentObserve":"83"},
        "grantIssueIndex":"13","grantResource":"6600","grantObserveCapability":"84",
        "grantAttemptDir":root.join("grant"),"grantDigest":"456","grantInitializedRoot":"567",
        "originalIssueReceipt":receipt,"grantIssueReceipt":receipt
    })).unwrap();
    let tool = rt.config.tool_task.as_mut().unwrap();
    tool.allowed_application_lifetime_routes = vec![route];
    tool.application_services = vec![oracle_tools::ServiceProfile { application:"oracle".into(), protocol:oracle_tools::PROTOCOL.into() }];
    let args = json!({"application":"oracle","query":"core.query","availability":"live_direct","limit":1});
    let request = json!({"requestId":REQUEST_ID,"name":"mini_oracle_discover","arguments":args});
    let request_raw = serde_json::to_vec(&request).unwrap();
    let request_hash = sha256_bytes(&request_raw).unwrap();
    let request_path = rt.config.state_dir.join("foreground-0000000000000035.request.json");
    write_new(&request_path, &request_raw).unwrap();
    write_new(&foreground_tombstone_path(&rt.config.state_dir, REQUEST_ID), &serde_json::to_vec(&ForegroundTombstone {
        request_id:REQUEST_ID.into(),operation_id:35,request_sha256:request_hash.clone()
    }).unwrap()).unwrap();
    rt.journal.foreground_attempt = Some(ForegroundAttempt {
        request_id:REQUEST_ID.into(),operation_id:35,name:"mini_oracle_discover".into(),request_path,
        request_sha256:request_hash,phase:ForegroundPhase::Uncertain,result_path:None,result_sha256:None,reported:false
    });
    let http = rt.application_tool_arguments("mini_oracle_discover", &args).unwrap();
    let input = application_api_tools::parse_input(&http, &["oracle".into()]).unwrap();
    let forward = application_api_tools::lifetime_dispatch_request(41, &"bc".repeat(32), &input).unwrap();
    let forward_raw = serde_json::to_vec(&forward).unwrap();
    let forward_path = rt.config.state_dir.join("application-api-0000000000000041.json");
    write_new(&forward_path, &forward_raw).unwrap();
    rt.journal.application_api_attempt = Some(ApplicationApiAttempt {
        operation_id:41,route_name:"oracle".into(),request_path:forward_path,
        request_sha256:sha256_bytes(&forward_raw).unwrap(),phase:ApplicationApiPhase::Uncertain,
        binding_sha256:Some("bc".repeat(32)),host_invocation:Some("ab".repeat(16)),
        operation_fingerprint:None,lifetime_committed_receipt:None,lifetime_settled_response_sha256:None,
        lifetime_settlement:None,reply_path:None,reply_sha256:None,reported:false
    });
    let fixed = json!({"fixed":{
        "base":{"issueIndex":"9","ticketResource":"6408","packageManifest":"6101","snapshotManifest":"6102",
            "sessionObserveCapability":"81","manifestObserveCapability":"82","enrollmentObserveCapability":"83",
            "http":application_api_tools::routed_reserve_http(&forward, "/").unwrap()},
        "parentTask":"7101","parentCapability":"71","parentObserve":"74",
        "purseTask":"7500","purseCapability":"121","purseObserve":"122","payerSubject":"12",
        "reserveAmount":"1","maximumCharge":"1","reserveOperationId":"0"},
        "grantIssueIndex":"13","grantResource":"6600","grantObserveCapability":"84"});
    // The narrow query double returns the selected purse, never claims Host admission.
    let mini = fs::read_to_string(&rt.config.mini).unwrap().replace("\"task\":\"7102\"", "\"task\":\"7500\"");
    fs::write(&rt.config.mini, mini).unwrap();
    fs::write(root.join("sim/status"), b"1").unwrap();
    rt.save().unwrap();
    (root, rt, fixed)
}

fn activate(rt: &mut Runtime) {
    rt.foreground_operation = Some(35);
    rt.foreground_api_budget = Some(ForegroundApiBudget::new(35));
    rt.journal.foreground_attempt.as_mut().unwrap().phase = ForegroundPhase::Executing;
    rt.journal.application_api_attempt.as_mut().unwrap().phase = ApplicationApiPhase::DispatchStarted;
}

#[test]
fn lifetime_foreground_budget_requires_exact_durable_invocation_without_hermes() {
    let (root, mut rt, _) = fixture("foreground-budget");
    assert!(rt.config.commands.is_empty());
    activate(&mut rt);
    assert_eq!(rt.checked_lifetime_dispatch_wall(1500).unwrap(), 1500);
    let first = rt.foreground_api_budget.as_ref().unwrap().deadline;
    rt.checked_lifetime_dispatch_wall(1800).unwrap();
    assert_eq!(rt.foreground_api_budget.as_ref().unwrap().deadline, first);
    assert!(rt.checked_lifetime_dispatch_wall(1801).is_err());
    assert!(rt.checked_lifetime_dispatch_wall(0).is_err());
    rt.prompt_active = true;
    assert!(rt.checked_lifetime_dispatch_wall(1500).is_err());
    rt.prompt_active = false;
    rt.foreground_operation = Some(36);
    assert!(rt.checked_lifetime_dispatch_wall(1500).is_err());
    rt.foreground_operation = Some(35);
    rt.journal.foreground_attempt.as_mut().unwrap().phase = ForegroundPhase::Uncertain;
    assert!(rt.checked_lifetime_dispatch_wall(1500).is_err());
    rt.journal.foreground_attempt.as_mut().unwrap().phase = ForegroundPhase::Executing;
    rt.journal.foreground_attempt.as_mut().unwrap().name = "mini_shell".into();
    assert!(rt.checked_lifetime_dispatch_wall(1500).is_err());
    rt.journal.foreground_attempt.as_mut().unwrap().name = "mini_oracle_discover".into();
    rt.config.foreground_tool = None;
    assert!(rt.checked_lifetime_dispatch_wall(1500).is_err());
    rt.foreground_operation = None;
    assert!(rt.checked_lifetime_dispatch_wall(1500).is_err());
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn lifetime_foreground_budget_physically_bounds_native_children_and_cannot_restart() {
    let (root, mut rt, _) = fixture("foreground-deadline");
    activate(&mut rt);
    rt.foreground_api_budget.as_mut().unwrap().deadline = Instant::now() + Duration::from_millis(80);
    let marker = root.join("late-marker");
    let began = Instant::now();
    let result = rt.work_output(Path::new("/bin/sh"), &["-c", "sleep 10; printf late > \"$1\"", "sh", marker.to_str().unwrap()]);
    assert!(matches!(result, Err(custody_gate::CustodyError::Uncertain(_))));
    assert!(began.elapsed() < Duration::from_secs(3));
    assert!(rt.custody_gate.is_idle());
    assert!(!marker.exists());
    // Later helpers share the expired deadline; none starts a new 300s clock.
    assert!(rt.command_output(Path::new("/bin/sh"), &["-c", "touch \"$1\"", "sh", marker.to_str().unwrap()]).is_err());
    assert!(!marker.exists());
    let mut command = Command::new("/bin/sh");
    command.args(["-c", "printf '{}' > \"$1\"", "sh", marker.to_str().unwrap()]);
    assert!(rt.supervised_json_command(command).is_err());
    assert!(!marker.exists());
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn lifetime_reverse_uses_participant_parent_authority_and_exact_http() {
    let (root, mut rt, fixed) = fixture("foreground-selectors");
    activate(&mut rt);
    assert!(rt.verified_reverse_lifetime_fixed_request("oracle", "41", &"bc".repeat(32), &fixed).is_ok());
    let mut wrong = fixed.clone();
    wrong["fixed"]["parentCapability"] = json!("1204");
    wrong["fixed"]["parentObserve"] = json!("1205");
    assert!(rt.verified_reverse_lifetime_fixed_request("oracle", "41", &"bc".repeat(32), &wrong).is_err());
    wrong = fixed.clone();
    wrong["fixed"]["base"]["http"]["path"] = json!("forged");
    assert!(rt.verified_reverse_lifetime_fixed_request("oracle", "41", &"bc".repeat(32), &wrong).is_err());
    assert!(rt.verified_reverse_lifetime_fixed_request("oracle", "42", &"bc".repeat(32), &fixed).is_err());
    assert!(rt.verified_reverse_lifetime_fixed_request("oracle", "41", &"bd".repeat(32), &fixed).is_err());
    rt.foreground_operation = None;
    assert!(rt.verified_reverse_lifetime_fixed_request("oracle", "41", &"bc".repeat(32), &fixed).is_err());
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn lifetime_foreground_unreserved_recovery_archives_no_dispatch_and_refuses_queued_callback() {
    let (root, mut rt, fixed) = fixture("foreground-recovery");
    let original = rt.journal.application_api_attempt.as_ref().unwrap().request_sha256.clone();
    let raw_foreground = fs::read(&rt.journal.foreground_attempt.as_ref().unwrap().request_path).unwrap();
    let answer = rt.recover_foreground_api_unreserved(REQUEST_ID).unwrap();
    assert_eq!(answer["type"], "mini-foreground-api-unreserved-recovery-v1");
    assert_eq!(answer["proof"]["apiOperationId"], "41");
    assert_eq!(answer["proof"]["noDispatch"], true);
    assert_eq!(answer["foregroundRemains"], true);
    assert!(rt.journal.application_api_attempt.is_none());
    let archived = rt.journal.application_api_history.last().unwrap();
    assert_eq!(archived.phase, ApplicationApiPhase::NoDispatch);
    assert_eq!(archived.request_sha256, original);
    assert!(archived.reply_path.is_none() && archived.reported);
    assert!(rt.journal.foreground_attempt.as_ref().unwrap().result_path.is_none());
    assert_eq!(fs::read(&rt.journal.foreground_attempt.as_ref().unwrap().request_path).unwrap(), raw_foreground);
    rt.journal.validate_application_api(&rt.config.state_dir).unwrap();
    rt.journal.validate_foreground(&rt.config.state_dir).unwrap();
    assert!(rt.dispatch_reserve_v3("oracle", "41", &"bc".repeat(32), 1500, &fixed).is_err());
    assert!(rt.journal.dispatch_attempt.is_none());
    assert!(rt.recover_foreground_api_unreserved(REQUEST_ID).is_err());
    let disk: Journal = serde_json::from_slice(&fs::read(rt.config.state_dir.join("journal.json")).unwrap()).unwrap();
    assert_eq!(disk.application_api_history.last().unwrap().phase, ApplicationApiPhase::NoDispatch);
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn lifetime_foreground_unreserved_recovery_refuses_possible_reserve_or_current_sender() {
    let (root, mut rt, _) = fixture("foreground-recovery-markers");
    let original = serde_json::to_vec(&rt.journal).unwrap();
    for control in ["fingerprint", "receipt", "current", "active", "prompt", "changed-forward", "busy-purse"] {
        rt.journal = serde_json::from_slice(&original).unwrap();
        rt.process_first_operation_id = 100;
        rt.foreground_operation = None;
        rt.prompt_active = false;
        let forward_path = rt.journal.application_api_attempt.as_ref().unwrap().request_path.clone();
        let saved_forward = fs::read(&forward_path).unwrap();
        match control {
            "fingerprint" => rt.journal.application_api_attempt.as_mut().unwrap().operation_fingerprint = Some("ff".repeat(32)),
            "receipt" => rt.journal.application_api_attempt.as_mut().unwrap().lifetime_committed_receipt = Some(ReserveAnchor {
                transaction_id:"1".into(),event_id:"2".into(),accepted_count:"3".into(),world_root:"4".into()
            }),
            "current" => rt.process_first_operation_id = 41,
            "active" => rt.foreground_operation = Some(35),
            "prompt" => rt.prompt_active = true,
            "changed-forward" => { fs::write(&forward_path, b"{}").unwrap(); },
            "busy-purse" => { fs::write(root.join("sim/status"), b"3").unwrap(); },
            _ => unreachable!(),
        }
        assert!(rt.recover_foreground_api_unreserved(REQUEST_ID).is_err(), "{control}");
        assert!(rt.journal.application_api_attempt.is_some(), "{control}");
        assert!(rt.journal.application_api_history.is_empty(), "{control}");
        fs::write(&forward_path, saved_forward).unwrap();
    }
    fs::remove_dir_all(root).unwrap();
}
