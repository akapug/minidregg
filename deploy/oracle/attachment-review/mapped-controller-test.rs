//! Snapshot-injected, ignored physical check. The companion shell fixture
//! supplies a root-registered named account and initial-namespace peers.
use super::*;
use std::path::PathBuf;
use std::sync::atomic::AtomicBool;
use std::time::{Duration, Instant};
use sha2::{Digest, Sha256};

#[test]
#[ignore = "disposable registered controller and real mapped namespace"]
fn mapped_controller_receipt_forward_and_reverse_peers() {
    let pid = unsafe { libc::fork() };
    assert!(pid >= 0);
    if pid == 0 {
        let outcome = std::panic::catch_unwind(|| {
            let world = PathBuf::from(std::env::var("REVIEW_CONTROLLER_WORLD").unwrap());
            let store = std::env::var("REVIEW_CONTROLLER_STORE").unwrap();
            let controller: u32 = std::env::var("REVIEW_CONTROLLER_UID").unwrap().parse().unwrap();
            let operator = unsafe { libc::geteuid() };
            let group = unsafe { libc::getegid() };
            let registry = crate::volume_helper::Registry {
                protocol: "mini-spk-volume-registry-v1".into(), store: store.clone(),
                deployment_id: "1".repeat(64), host_id: "2".repeat(64),
                grains_root: world.clone(), operator_uid: operator, operator_gid: group,
                app_uids: vec![100000], helper: PathBuf::from("/unused"), helper_sha256: "0".repeat(64),
            };
            let mut wrong = registry.clone();
            wrong.deployment_id = "3".repeat(64);
            assert!(crate::namespace_identity::load_registered_controller(&wrong).is_err(), "wrong world receipt accepted");
            let identity = crate::namespace_identity::load_registered_controller(&registry).unwrap().expect("registered controller");
            crate::namespace_identity::prepare_root_handles(&world.join("config.json"), &world, &store, "grain").unwrap();
            let bwrap = PathBuf::from("/usr/local/libexec/mini-grain-bwrap");
            let hash = format!("{:x}", Sha256::digest(std::fs::read(&bwrap).unwrap()));
            crate::namespace_identity::enter_registered(&bwrap, &hash, operator, group, 100000, 100000, Some(&identity)).unwrap();
            let app_child = unsafe { libc::fork() };
            assert!(app_child >= 0);
            if app_child == 0 {
                let ok = crate::os::drop_to_identity(100000, 100000).is_ok()
                    && crate::os::holds_exactly_identity(100000, 100000).unwrap_or(false)
                    && unsafe { libc::setuid(controller) } != 0
                    && unsafe { libc::setuid(operator) } != 0;
                unsafe { libc::_exit(if ok { 0 } else { 1 }) }
            }
            let mut app_status = 0;
            assert_eq!(unsafe { libc::waitpid(app_child, &mut app_status, 0) }, app_child);
            assert!(libc::WIFEXITED(app_status) && libc::WEXITSTATUS(app_status) == 0, "app identity/capability isolation");
            crate::os::drop_to_identity(operator, group).unwrap();
            assert!(crate::os::holds_exactly_identity(operator, group).unwrap(), "operator retains groups or capabilities");
            assert_ne!(unsafe { libc::setuid(controller) }, 0, "operator changed to controller after drop");
            crate::namespace_identity::require_registered_controller(controller).unwrap();
            assert!(crate::namespace_identity::require_registered_controller(100001).is_err());
            let forward = world.join("agent/forward.sock");
            AgentApiListener::preflight_parent(&forward, controller).unwrap();
            let listener = AgentApiListener::bind(&forward, controller).unwrap();
            std::fs::write(world.join("agent/ready"), b"ready").unwrap();
            let deadline = Instant::now() + Duration::from_secs(20);
            let stream = loop {
                if let Some(stream) = listener.accept_authenticated().unwrap() { break stream; }
                assert!(Instant::now() < deadline, "controller connection timed out");
                std::thread::sleep(Duration::from_millis(10));
            };
            drop(stream);
            let client = crate::agent_api_native::ReverseCustodyClient::new(world.join("controller/reverse/custody.sock"), controller, "fixture-app".into()).unwrap();
            let reply = client.exchange_until(&serde_json::json!({"probe":true}), &AtomicBool::new(false), Instant::now() + Duration::from_secs(20)).unwrap();
            assert_eq!(reply, serde_json::json!({"ok":true}));
            let foreign = crate::agent_api_native::ReverseCustodyClient::new(world.join("foreign/reverse.sock"), controller, "fixture-app".into()).unwrap();
            assert!(foreign.exchange_until(&serde_json::json!({"probe":true}), &AtomicBool::new(false), Instant::now() + Duration::from_secs(2)).is_err(), "foreign unmapped reverse ancestor accepted");
            println!("mapped-registered-controller-forward-and-reverse-pass");
        });
        if outcome.is_err() { eprintln!("mapped controller fixture panicked"); }
        unsafe { libc::_exit(if outcome.is_ok() {0} else {1}) }
    }
    let mut status = 0;
    assert_eq!(unsafe { libc::waitpid(pid, &mut status, 0) }, pid);
    assert!(libc::WIFEXITED(status) && libc::WEXITSTATUS(status) == 0, "fixture status {status:#x}");
}
