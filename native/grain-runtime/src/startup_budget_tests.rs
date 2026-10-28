//! Orchestration and physical deadline controls. The Mini fixture emits
//! signed-read-shaped data; native Host readiness is qualified separately.
use super::*;

fn fixture(tag: &str) -> (PathBuf, Runtime) {
    let (root, mut rt) = tests::restart_resolution_fixture(tag);
    rt.journal = Journal::fresh(json!({}));
    rt.journal.connection = Connection::Soft;
    rt.prompt_active = false;
    rt.foreground_operation = None;
    rt.cancelled.store(false, Ordering::SeqCst);
    let mini = fs::read_to_string(&rt.config.mini)
        .unwrap()
        .replace("\"task\":\"7102\"", "\"task\":\"7101\"");
    fs::write(&rt.config.mini, mini).unwrap();
    fs::write(root.join("sim/status"), b"2").unwrap();
    rt.save().unwrap();
    (root, rt)
}

#[test]
fn startup_budget_is_bounded_configurable_and_absent_from_legacy_serialization() {
    assert_eq!(
        deadline::startup_limit(None).unwrap(),
        Duration::from_secs(1200)
    );
    for seconds in [60, 900, 1500] {
        assert_eq!(
            deadline::startup_limit(Some(seconds)).unwrap(),
            Duration::from_secs(seconds)
        );
    }
    for seconds in [0, 59, 1501, u64::MAX] {
        assert!(deadline::startup_limit(Some(seconds)).is_err());
    }
    let (root, rt) = fixture("startup-config");
    assert!(serde_json::to_value(&rt.config)
        .unwrap()
        .get("startupTimeoutSeconds")
        .is_none());
    assert!(serde_json::to_value(&rt.config).unwrap().get("consentFullReadiness").is_none());
    drop(rt);
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn startup_budget_is_total_nested_and_does_not_extend_active_work() {
    let (root, mut rt) = fixture("startup-scope");
    assert_eq!(rt.native_work_limit().unwrap(), deadline::NATIVE_CALL);
    let error = rt
        .with_startup_budget(None, |rt| -> Result<()> {
            assert!(rt.native_work_limit()? > deadline::NATIVE_CALL);
            let original = rt.startup_deadline.unwrap();
            rt.with_startup_budget(None, |nested| {
                assert_eq!(nested.startup_deadline, Some(original));
                Ok(())
            })?;
            rt.with_startup_budget(
                Some(Instant::now() + Duration::from_millis(500)),
                |nested| {
                    assert!(nested.native_work_limit()? <= Duration::from_millis(500));
                    Ok(())
                },
            )?;
            assert_eq!(rt.startup_deadline, Some(original));
            Err("planned refusal".into())
        })
        .unwrap_err();
    assert_eq!(error, "planned refusal");
    assert!(rt.startup_deadline.is_none());
    assert_eq!(rt.native_work_limit().unwrap(), deadline::NATIVE_CALL);
    rt.startup_deadline = Some(Instant::now() + Duration::from_secs(1200));
    rt.prompt_active = true;
    assert_eq!(rt.native_work_limit().unwrap(), deadline::NATIVE_CALL);
    assert!(rt.with_startup_budget(None, |_| Ok(())).is_err());
    rt.prompt_active = false;
    rt.foreground_operation = Some(42);
    rt.foreground_api_budget = Some(ForegroundApiBudget::new(42));
    rt.foreground_api_budget.as_mut().unwrap().deadline =
        Instant::now() + Duration::from_millis(100);
    assert!(rt.native_work_limit().unwrap() <= Duration::from_millis(100));
    assert!(rt.with_startup_budget(None, |_| Ok(())).is_err());
    drop(rt);
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn startup_budget_physically_stops_a_helper_without_claiming_refusal() {
    let (root, mut rt) = fixture("startup-timeout");
    let started = Instant::now();
    let error = rt
        .with_startup_budget(Some(started + Duration::from_millis(150)), |rt| {
            rt.command_output(Path::new("/bin/sh"), &["-c", "sleep 30 & wait"])
        })
        .unwrap_err();
    assert!(error.contains("undecided (deadline)"), "{error}");
    assert!(started.elapsed() < Duration::from_secs(3));
    assert!(rt.custody_exit_reaped.load(Ordering::SeqCst));
    assert!(rt.startup_deadline.is_none());
    assert!(rt
        .with_startup_budget::<()>(Some(Instant::now()), |_| panic!("expired work ran"))
        .is_err());
    drop(rt);
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn startup_readiness_requires_signed_idle_state_and_admits_no_tool() {
    let (root, mut rt) = fixture("startup-ready");
    let result = rt
        .prepare_idle(Instant::now() + Duration::from_secs(30))
        .unwrap();
    assert_eq!(result["type"], "mini-grain-idle-readiness-v1");
    assert_eq!(result["ready"], true);
    assert_eq!(result["signedTask"]["grain"]["status"], "2");
    assert_eq!(result["signedTask"]["grain"]["reserved"], "0");
    assert!(rt.journal.foreground_attempt.is_none());
    assert!(rt.journal.application_api_attempt.is_none());
    assert!(rt.journal.foreground_history.is_empty());
    assert!(rt.journal.pending.is_none());
    assert!(rt.journal.parent_hold.is_none());
    assert!(rt.startup_deadline.is_none());
    for (connection, valid_status) in [(Connection::Soft, "2"), (Connection::Hard, "1")] {
        rt.journal.connection = connection;
        fs::write(root.join("sim/status"), valid_status).unwrap();
        assert!(rt.prepare_idle(Instant::now() + Duration::from_secs(30)).is_ok());
        for wrong in ["0", "1", "2", "3", "4", "5", "6", "7"] {
            if wrong == valid_status { continue; }
            fs::write(root.join("sim/status"), wrong).unwrap();
            assert!(rt.prepare_idle(Instant::now() + Duration::from_secs(30))
                .unwrap_err().contains("signed idle"), "accepted {wrong} with {:?}", rt.journal.connection);
        }
    }
    // Even an otherwise idle status cannot claim readiness with retained reserve.
    let mini = fs::read_to_string(&rt.config.mini).unwrap().replace("reserved=0", "reserved=1");
    fs::write(&rt.config.mini, mini).unwrap();
    fs::write(root.join("sim/status"), b"1").unwrap();
    assert!(rt.prepare_idle(Instant::now() + Duration::from_secs(30))
        .unwrap_err().contains("signed idle"));
    rt.prompt_active = true;
    let before = rt.journal.next_operation_id;
    assert!(rt
        .prepare_idle(Instant::now() + Duration::from_secs(30))
        .unwrap_err()
        .contains("active or retained"));
    assert_eq!(rt.journal.next_operation_id, before);
    drop(rt);
    fs::remove_dir_all(root).unwrap();
}

#[test]
fn startup_full_consent_is_opt_in_strict_and_precedes_signed_read() {
    let (root, mut rt) = fixture("startup-full-consent");
    let original = fs::read_to_string(&rt.config.mini).unwrap();
    let wrapper = format!(r#"#!/bin/sh
if [ "$1" = consent-full-ready ]; then
  printf called > '{}/full-called'
  cat '{}/full-reply'
  exit 0
fi
{}"#, root.display(), root.display(), original);
    fs::write(&rt.config.mini, wrapper).unwrap();
    fs::write(root.join("full-reply"), br#"{"type":"mini-consent-full-readiness-v1","ready":true}"#).unwrap();
    let receipt = rt.prepare_idle(Instant::now() + Duration::from_secs(30)).unwrap();
    assert!(receipt["fullConsent"].is_null());
    assert!(!root.join("full-called").exists());
    rt.config.consent_full_readiness = Some(true);
    let receipt = rt.prepare_idle(Instant::now() + Duration::from_secs(30)).unwrap();
    assert_eq!(receipt["fullConsent"]["ready"], true);
    assert!(root.join("full-called").exists());
    for reply in [
        r#"{"type":"mini-consent-full-readiness-v1","ready":false}"#,
        r#"{"type":"other","ready":true}"#,
        r#"{"type":"mini-consent-full-readiness-v1","ready":true,"ready":false}"#,
        r#"{"type":"mini-consent-full-readiness-v1","ready":true,"unknown":1}"#,
        "", "legacy usage",
    ] {
        fs::write(root.join("full-reply"), reply).unwrap();
        let before = rt.journal.next_operation_id;
        assert!(rt.prepare_idle(Instant::now() + Duration::from_secs(30)).is_err());
        assert_eq!(before, rt.journal.next_operation_id, "invalid consent reply must stop before signed read");
        assert!(rt.startup_deadline.is_none());
    }
    fs::write(&rt.config.mini, original).unwrap();
    let before = rt.journal.next_operation_id;
    assert!(rt.prepare_idle(Instant::now() + Duration::from_secs(30)).is_err());
    assert_eq!(before, rt.journal.next_operation_id);
    drop(rt);
    fs::remove_dir_all(root).unwrap();
}
