//! Snapshot-injected test: production namespace, worker, FD transport and bwrap.
use super::*;
use std::os::unix::fs::{MetadataExt, PermissionsExt};
use sha2::{Digest, Sha256};

#[test]
#[ignore = "disposable mapped-user-namespace mount fixture"]
fn mapped_worker_public_data_mount_and_preflight() {
    let pid = unsafe { libc::fork() };
    assert!(pid >= 0);
    if pid == 0 {
        let result = std::panic::catch_unwind(|| {
            let base = std::path::PathBuf::from(std::env::var("REVIEW_MOUNT_DIR").unwrap());
            let mode = std::env::var("REVIEW_MOUNT_MODE").unwrap();
            let operator = unsafe { libc::geteuid() };
            let group = unsafe { libc::getegid() };
            let app = 100000u32;
            let world = base.join("world");
            let store = world.join("spk/public-data");
            if mode == "private" {
                std::fs::create_dir(&store).unwrap();
                std::fs::set_permissions(&store, std::fs::Permissions::from_mode(0o700)).unwrap();
            }
            let contents = b"public fixture\n";
            let inv = serde_json::to_vec(&serde_json::json!({"schema":"minidregg-public-data-inventory-v1","visibility":"public","files":[{"path":"probe.txt","size":contents.len(),"sha256":format!("{:x}",Sha256::digest(contents))}]})).unwrap();
            let previous = unsafe { libc::umask(0o077) };
            let published = crate::shared_data::publish(&store, &base.join("source"), &inv).unwrap();
            unsafe { libc::umask(previous) };
            let store_mode = std::fs::metadata(&store).unwrap().mode() & 0o777;
            assert_eq!(store_mode, if mode == "private" { 0o700 } else { 0o755 }, "fresh store mode under umask 077 or preserved existing store");
            if mode == "acl" {
                assert!(std::process::Command::new("setfacl").args(["-m", "u:100000:---"]).arg(&store).status().unwrap().success());
            }
            let requirement = crate::shared_data::parse_signed_attachment(&serde_json::to_vec(&serde_json::json!({"schema":"minidregg-public-data-v1","inventory_sha256":published.inventory_sha256})).unwrap()).unwrap();
            crate::namespace_identity::prepare_root_handles(&world.join("config.json"), &world, "store", "grain").unwrap();
            let bwrap = std::path::PathBuf::from("/usr/local/libexec/mini-grain-bwrap");
            let bwrap_hash = format!("{:x}", Sha256::digest(std::fs::read(&bwrap).unwrap()));
            crate::namespace_identity::enter(&bwrap, &bwrap_hash, operator, group, app, app).unwrap();
            crate::resident_privilege::review_initialize_mapped_worker(operator, group, app, app).unwrap();
            let data = crate::shared_data::open_published(&store, &requirement, app).unwrap();
            let checked = crate::resident_privilege::check_public_data_access(data.root_fd());
            if mode == "private" || mode == "acl" {
                let err = checked.expect_err("inaccessible data passed preflight");
                assert!(err.to_string().contains("public-data backing path inaccessible"), "wrong refusal: {err}");
                assert_eq!(std::fs::metadata(&store).unwrap().mode() & 0o777, store_mode, "existing store mode changed");
                println!("mapped-{mode}-preflight-refused");
                return;
            }
            checked.unwrap();
            let spec = crate::sandbox::SandboxSpec {
                bwrap, image_root: base.join("image"), persistent_var: base.join("var"),
                persistent_var_max_bytes: 64 * 1024 * 1024, argv: if mode == "early-exit" { vec!["/probe".into(), "--exit-before-rpc".into()] } else { vec!["/probe".into()] }, environ: vec![], app_output: base.join("app-output.log"),
            };
            let prepared = PreparedResident::prepare_with_public_data(&spec, app, app, &bwrap_hash, Some(data));
            let (mut child, mut rpc, output) = prepared.unwrap().spawn_for_audit().unwrap();
            if mode == "early-exit" {
                use std::io::Read;
                rpc.set_read_timeout(Some(std::time::Duration::from_secs(3))).unwrap();
                let mut byte = [0u8; 1];
                assert_eq!(rpc.read(&mut byte).expect("RPC EOF before any wait or kill"), 0);
                let (sender, receiver) = std::sync::mpsc::channel();
                std::thread::spawn(move || { let _ = sender.send(output.finish()); });
                receiver.recv_timeout(std::time::Duration::from_secs(3)).expect("output EOF before any wait or kill").unwrap();
                let status = child.wait().unwrap();
                assert!(libc::WIFEXITED(status) && libc::WEXITSTATUS(status) == 42, "exact child status {status:#x}");
                let log = std::fs::read_to_string(&spec.app_output).unwrap();
                assert!(log.contains("early-child-exit"));
                println!("mapped-early-exit-rpc-and-output-eof-before-reap");
                return;
            }
            let status = child.wait().unwrap();
            output.finish().unwrap();
            let log = std::fs::read_to_string(&spec.app_output).unwrap();
            assert!(libc::WIFEXITED(status) && libc::WEXITSTATUS(status) == 0, "child status {status:#x}: {log}");
            assert!(log.contains("mapped-public-data-held"), "probe output: {log}");
            println!("mapped-positive-mounted-readonly-fd7-closed");
        });
        unsafe { libc::_exit(if result.is_ok() { 0 } else { 1 }) }
    }
    let mut status = 0;
    assert_eq!(unsafe { libc::waitpid(pid, &mut status, 0) }, pid);
    assert!(libc::WIFEXITED(status) && libc::WEXITSTATUS(status) == 0, "mapped fixture status {status:#x}");
}
