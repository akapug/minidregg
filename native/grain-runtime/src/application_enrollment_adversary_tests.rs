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
    assert!(quiescent(&journal).is_ok());
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
    assert!(quiescent(&journal).is_ok());
    journal.prompt_witness = Some(json!({"request":"active"}));
    assert!(quiescent(&journal).is_err());
    journal.prompt_witness = None;
    journal.unresolved_external.push("possibly submitted".into());
    assert!(quiescent(&journal).is_err());
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
