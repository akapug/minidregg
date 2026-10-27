//! Isolated evidence against the reviewed broker source, not a production fix.
//! Calls public Rust handlers directly with a synthetic sealed credential.
//! Binds an unserved Unix listener because Broker::start checks its custody;
//! never starts a server, connects a network socket, invokes curl or uses a real key.
#[allow(dead_code)]
#[path = "../../../../../native/grain-runtime/src/provider_failure.rs"]
mod provider_failure;

use mini_keys::{
    credentials::{CredentialStore, Namespace, Secret},
    peer::{self, Peer},
    server::{self, provider, ticket, Note},
    wire,
};
use serde_json::{json, Value};
use std::{
    fs::{self, OpenOptions},
    os::{
        fd::AsRawFd,
        unix::fs::{OpenOptionsExt, PermissionsExt},
    },
    path::{Path, PathBuf},
    sync::{Arc, Barrier},
    thread,
    time::Duration,
};

fn private_dir(p: &Path) {
    fs::create_dir(p).unwrap();
    fs::set_permissions(p, fs::Permissions::from_mode(0o700)).unwrap();
}
fn write(p: &Path, data: &[u8], mode: u32) {
    fs::write(p, data).unwrap();
    fs::set_permissions(p, fs::Permissions::from_mode(mode)).unwrap();
}
fn request(body: &str, member: &str) -> Value {
    json!({"op":"provider-authorize","kind":"pool","provider":"poolrow","runner":"9","member":member,"maxTokens":8,"bodySha256":server::native::sha256_hex(body.as_bytes())})
}
fn authorize(broker: &server::Broker, req: &Value) -> Value {
    provider::authorize(
        broker,
        &Peer {
            uid: peer::euid(),
            gid: peer::egid(),
            pid: std::process::id() as i32,
        },
        req,
        &mut Note::default(),
    )
    .unwrap_or_else(|e| panic!("authorize {}: {}", e.code, e.detail))
}

fn main() {
    let parent = PathBuf::from(
        std::env::args()
            .nth(1)
            .expect("own scratch directory required"),
    )
    .canonicalize()
    .unwrap();
    let root = parent.join(format!("provider-review-{}", std::process::id()));
    private_dir(&root);
    for d in ["etc", "run", "state", "credentials", "keys"] {
        private_dir(&root.join(d));
    }
    write(&root.join("keys/seal"), &[7u8; 32], 0o600);
    write(&root.join("etc/host"), b"synthetic Host bytes", 0o755);
    write(&root.join("etc/host-config"), b"{}", 0o644);
    let table = json!({"type":"mini-provider-table-v2","providers":[{"name":"poolrow","endpoint":"https://never-contacted.invalid/v1/chat/completions","kind":"openai-compatible","models":["m1"],"credential":"pool","caps":{"perCall":"64","perDay":"100","ceilingMicroUsd":"40000000","callMicroUsd":"5000","memberDayMicroUsd":"1000000","memberTotalMicroUsd":"4000000"}}]});
    write(
        &root.join("etc/providers"),
        table.to_string().as_bytes(),
        0o644,
    );
    let store = CredentialStore::open(&root.join("credentials"), &root.join("keys/seal")).unwrap();
    store
        .set(
            Namespace::Pool,
            "poolrow",
            &Secret::new("synthetic-not-an-api-key-12345678".into()).unwrap(),
        )
        .unwrap();
    let cfg = json!({"type":"mini-keys-broker-v1","socket":root.join("run/b.sock"),"audit":root.join("state/audit"),"spool":root.join("state/spool"),"singleAccount":true,"peers":[{"role":"provider","uids":[peer::euid()]}],"credentials":{"host":root.join("etc/host"),"hostSha256":server::native::sha256_hex(b"synthetic Host bytes"),"hostConfig":root.join("etc/host-config"),"publicSocket":root.join("run/never-contacted.sock"),"publicSocketUid":peer::euid(),"providers":root.join("etc/providers"),"root":root.join("credentials"),"key":root.join("keys/seal")}});
    let config = server::Config::parse(cfg.to_string().as_bytes(), peer::euid()).unwrap();
    let (broker, listener) = server::Broker::start(config).unwrap();
    drop(listener); // no serve loop exists; all handler calls below are direct
    let day = mini_keys::credentials::utc_day();

    // 1. Sequential same-body requests with different attributed members.
    let req = request("same body different members", "20");
    let alice = authorize(&broker, &req);
    let bob = authorize(&broker, &request("same body different members", "21"));
    let alice_spend = store.pool_member_spend("poolrow", "20", day).unwrap();
    let bob_spend = store.pool_member_spend("poolrow", "21", day).unwrap();
    assert_eq!(alice["ticket"], bob["ticket"]);
    assert_eq!(alice_spend, (5000, 5000));
    assert_eq!(bob_spend, (0, 0));

    // 2. Hold the real provider authority lock so both handlers can perform
    // find_request before either mints/counts; then release the common lock.
    let lock = OpenOptions::new()
        .create(true)
        .write(true)
        .mode(0o600)
        .open(root.join("credentials/_pool/poolrow.authority.lock"))
        .unwrap();
    assert_eq!(unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX) }, 0);
    let barrier = Arc::new(Barrier::new(3));
    let jobs: Vec<_> = (0..2)
        .map(|_| {
            let b = broker.clone();
            let gate = barrier.clone();
            thread::spawn(move || {
                gate.wait();
                authorize(&b, &request("concurrent identical retry", "22"))
            })
        })
        .collect();
    barrier.wait();
    thread::sleep(Duration::from_millis(300));
    assert_eq!(unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_UN) }, 0);
    let answers: Vec<_> = jobs.into_iter().map(|j| j.join().unwrap()).collect();
    assert_ne!(answers[0]["ticket"], answers[1]["ticket"]);
    let race_spend = store.pool_member_spend("poolrow", "22", day).unwrap();
    assert_eq!(race_spend, (10000, 10000));

    // 3. Seed exactly the durable Answered state a finished forward writes.
    // Its bytes are synthetic; replay takes the early answered branch and
    // never reaches secret unsealing or send/curl.
    let body = br#"{"model":"m1","max_tokens":8,"messages":[]}"#;
    let req = request(std::str::from_utf8(body).unwrap(), "23");
    let first = authorize(&broker, &req);
    let id = first["ticket"].as_str().unwrap();
    let mut t = broker.tickets.get(id).unwrap().unwrap();
    let synthetic = json!({"ok":true,"complete":true,"headers":wire::hex(b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n"),"body":wire::hex(b"synthetic retained answer")});
    broker.tickets.put_answer(id, &synthetic).unwrap();
    t.state = ticket::State::Answered;
    t.settled = ticket::now() - ticket::ANSWER_RETAIN_S - 1;
    broker.tickets.put(&t).unwrap();
    let second = authorize(&broker, &req);
    assert_ne!(first["ticket"], second["ticket"]);
    assert!(broker.tickets.answer(id).unwrap().is_some());
    let (mut socket, other) = std::os::unix::net::UnixStream::pair().unwrap();
    let replay=provider::forward(&broker,&Peer{uid:peer::euid(),gid:peer::egid(),pid:std::process::id() as i32},&json!({"op":"provider-forward","ticket":id,"body":wire::hex(body),"timeoutMs":1000,"maxResponseBytes":1024}),&mut socket,&mut Note::default()).unwrap_or_else(|e|panic!("forward {} {}",e.code,e.detail));
    assert_eq!(replay["replayed"], true);
    assert_eq!(replay["body"], synthetic["body"]);
    drop(other);
    // 4. A durable post-send uncertainty is a *refusal frame* at this API.
    let mut uncertain = broker
        .tickets
        .get(second["ticket"].as_str().unwrap())
        .unwrap()
        .unwrap();
    uncertain.state = ticket::State::Uncertain;
    uncertain.settled = ticket::now();
    broker.tickets.put(&uncertain).unwrap();
    let err=provider::forward(&broker,&Peer{uid:peer::euid(),gid:peer::egid(),pid:std::process::id() as i32},&json!({"op":"provider-forward","ticket":uncertain.id,"body":wire::hex(body),"timeoutMs":1000,"maxResponseBytes":1024}),&mut socket,&mut Note::default()).err().expect("uncertain forward must refuse");
    assert_eq!(err.code, "forward-uncertain");
    let client_err = mini_keys::client::answer(wire::refusal(&err.code, &err.detail)).unwrap_err();
    // The gateway source maps client::answer Err to ProviderOutcome::refused;
    // provider_record_outcome emits this exact tag. This part exercises the
    // real failure-class module, not the full controller or a native settle.
    let tag = format!("not-sent:refused:{client_err}");
    let class = provider_failure::classify(true, Some(&tag), None).unwrap();
    let decision = provider_failure::decide(class, "pool");
    assert_eq!(
        decision.state,
        provider_failure::DecidedState::ReleasedNotSent
    );
    broker.tickets.sweep().unwrap();
    assert!(broker.tickets.get(id).unwrap().is_none());
    println!(
        "{}",
        json!({"source":"current mini-keys public handlers; synthetic local fixtures", "fixture":root,
        "same_body_different_members":{"same_ticket":true,"alice_spend":alice_spend,"bob_spend":bob_spend},
        "concurrent_exact_authorize":{"distinct_tickets":true,"charged_micro_usd":race_spend.1},
        "answered_ticket":{"authorize_mints_new_ticket":true,"old_answer_replays_past_retention":true,"manual_sweep_removes_old_ticket":true},
        "after_send_refusal":{"broker_code":err.code,"gateway_tag":tag,"classified_state":format!("{:?}",decision.state)},
        "provider_calls":0,"servers_started":0})
    );
}
