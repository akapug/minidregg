//! Gateway mode against a fake gateway: HELLO, IDENTIFY with the token and intents 0, READY,
//! an INTERACTION_CREATE answered through the REST callback with the deferred answer PATCHed
//! after the line ran, a heartbeat carrying the last sequence, RECONNECT then RESUME with that
//! session and sequence, and INVALID_SESSION(false) then a fresh IDENTIFY.

use std::net::{TcpListener, TcpStream};
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use std::sync::atomic::AtomicBool;
use std::sync::{mpsc, Arc};
use std::time::{Duration, Instant};

use minidregg_discord_entrance::curl::Poster;
use minidregg_discord_entrance::gateway::{Gateway, Url};
use minidregg_discord_entrance::http::{read_request, write_response};
use minidregg_discord_entrance::server::{App, Config, Mode};
use minidregg_discord_entrance::session::{Deployment, Retention, Sessions};
use serde_json::{json, Value};
use tungstenite::{Message, WebSocket};

const APP_ID: &str = "1507638321877090374";
const FRIEND: &str = "111";
const TOKEN: &str = "bot.token-for_tests";

fn app(root: &std::path::Path, api: &str) -> Arc<App> {
    for d in ["sessions/friend", "spool"] {
        std::fs::create_dir_all(root.join(d)).unwrap();
    }
    let wrapper = root.join("wrapper");
    std::fs::write(&wrapper, "#!/bin/sh\nprintf 'ran [%s]\\n' \"$SSH_ORIGINAL_COMMAND\"\n").unwrap();
    std::fs::set_permissions(&wrapper, std::fs::Permissions::from_mode(0o755)).unwrap();
    let roster = root.join("roster.json");
    std::fs::write(&roster, json!({"version":1,"users":{FRIEND:"friend"}}).to_string()).unwrap();
    std::fs::set_permissions(&roster, std::fs::Permissions::from_mode(0o644)).unwrap();
    let uid = std::os::unix::fs::MetadataExt::uid(&std::fs::metadata(&roster).unwrap());
    let p = |x: &str| PathBuf::from(format!("/fixed/{x}"));
    App::new(Config {
        mode: Mode::Gateway,
        bot_token_file: None,
        gateway_url: String::new(),
        ca_file: PathBuf::from("/nonexistent"),
        listen: String::new(),
        application_id: APP_ID.into(),
        public_key_hex: String::new(),
        api_base: format!("http://{api}/api/v10"),
        roster,
        roster_owner_uid: uid,
        max_inflight: 4,
        deployment: Deployment { wrapper, mini: p("mini"), host: p("host"), config: p("config"), socket: p("socket"),
            timeout: Duration::from_secs(20), runner: None },
        sessions: Sessions { dir: root.join("sessions"), sponsor: "ember".into(), sponsor_workspace: p("sponsor-ws") },
        poster: Poster { curl: "/usr/bin/curl".into(), spool: root.join("spool"), max_time_s: 10 },
        state: None,
        door_links: None,
        door_url: None,
        retention: Retention { max_age_s: 86_400, max_records: 100 },
    })
    .unwrap()
}

/// The REST stand-in: every request's method, path and JSON body.
fn rest() -> (String, mpsc::Receiver<(String, Value)>) {
    let api = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = api.local_addr().unwrap().to_string();
    let (tx, rx) = mpsc::channel();
    std::thread::spawn(move || {
        for s in api.incoming() {
            let mut s = s.unwrap();
            let req = read_request(&mut s).unwrap();
            let _ = write_response(&mut s, 204, "No Content", "application/json", b"");
            let _ = tx.send((format!("{} {}", req.method, req.path), serde_json::from_slice(&req.body).unwrap_or(Value::Null)));
        }
    });
    (addr, rx)
}

fn accept(listener: &TcpListener) -> WebSocket<TcpStream> {
    let (tcp, _) = listener.accept().unwrap();
    tcp.set_read_timeout(Some(Duration::from_secs(10))).unwrap();
    tungstenite::accept(tcp).unwrap()
}

fn say(ws: &mut WebSocket<TcpStream>, v: Value) {
    ws.send(Message::text(v.to_string())).unwrap();
}

/// The next JSON message from the client, skipping heartbeats unless `heartbeats`.
fn hear(ws: &mut WebSocket<TcpStream>, heartbeats: bool) -> Value {
    loop {
        match ws.read().unwrap() {
            Message::Text(t) => {
                let v: Value = serde_json::from_str(t.as_str()).unwrap();
                if v["op"] == 1 && !heartbeats {
                    say(ws, json!({"op":11}));
                    continue;
                }
                return v;
            }
            _ => continue,
        }
    }
}

#[test]
fn identify_interaction_heartbeat_resume_and_fresh_identify() {
    let root = std::env::temp_dir().join(format!("discord-gateway-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    let (api, calls) = rest();
    let app = app(&root, &api);
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    let stop = Arc::new(AtomicBool::new(false));
    let gateway = Gateway {
        app,
        url: Url::parse(&format!("ws://127.0.0.1:{port}/?v=10&encoding=json")).unwrap(),
        token: TOKEN.into(),
        tls: None,
        stop: stop.clone(),
    };
    let client = std::thread::spawn(move || gateway.run());

    // Connection 1: HELLO, IDENTIFY, READY, one interaction, a heartbeat, RECONNECT.
    let mut ws = accept(&listener);
    say(&mut ws, json!({"op":10,"d":{"heartbeat_interval":3000}}));
    let identify = hear(&mut ws, false);
    assert_eq!(identify["op"], 2, "{identify}");
    assert_eq!(identify["d"]["token"], TOKEN);
    assert_eq!(identify["d"]["intents"], 0, "interactions need no intents");
    say(&mut ws, json!({"op":0,"s":1,"t":"READY","d":{"session_id":"sess-1","user":{"username":"dragons-egg"},
        "resume_gateway_url":"wss://elsewhere.example"}}));
    say(&mut ws, json!({"op":0,"s":2,"t":"INTERACTION_CREATE","d":{"type":2,"id":"900001","application_id":APP_ID,
        "token":"interaction-token-1","member":{"user":{"id":FRIEND}},
        "data":{"name":"mini","options":[{"name":"line","type":3,"value":"read shared"}]}}}));
    let (route, body) = calls.recv_timeout(Duration::from_secs(20)).expect("no callback");
    assert_eq!(route, "POST /api/v10/interactions/900001/interaction-token-1/callback");
    assert_eq!(body, json!({"type":5,"data":{"flags":64}}), "the deferred, ephemeral answer");
    let (route, body) = calls.recv_timeout(Duration::from_secs(20)).expect("no follow-up");
    assert_eq!(route, format!("PATCH /api/v10/webhooks/{APP_ID}/interaction-token-1/messages/@original"));
    assert!(body["content"].as_str().unwrap().contains("ran [read shared]"), "{body}");
    // A heartbeat carries the last sequence seen (one sent before READY carried null).
    let mut beats = Vec::new();
    loop {
        let beat = hear(&mut ws, true);
        assert_eq!(beat["op"], 1, "{beat}");
        say(&mut ws, json!({"op":11}));
        beats.push(beat["d"].clone());
        if beat["d"] == 2 {
            break;
        }
        assert!(beats.len() < 4, "{beats:?}");
    }
    say(&mut ws, json!({"op":7,"d":null}));
    drop(ws);

    // Connection 2: RESUME with the session and sequence, on the configured host; then
    // INVALID_SESSION(false) asks for a fresh session.
    let mut ws = accept(&listener);
    say(&mut ws, json!({"op":10,"d":{"heartbeat_interval":300}}));
    let resume = hear(&mut ws, false);
    assert_eq!(resume, json!({"op":6,"d":{"token":TOKEN,"session_id":"sess-1","seq":2}}));
    say(&mut ws, json!({"op":0,"s":3,"t":"RESUMED","d":{}}));
    say(&mut ws, json!({"op":9,"d":false}));
    drop(ws);

    // Connection 3: a fresh IDENTIFY, not a RESUME.
    let started = Instant::now();
    let mut ws = accept(&listener);
    say(&mut ws, json!({"op":10,"d":{"heartbeat_interval":300}}));
    let again = hear(&mut ws, false);
    assert_eq!(again["op"], 2, "{again}");
    assert!(started.elapsed() < Duration::from_secs(20));
    stop.store(true, std::sync::atomic::Ordering::SeqCst);
    drop(ws);
    client.join().unwrap().unwrap();
    std::fs::remove_dir_all(&root).unwrap();
}

#[test]
fn a_missed_heartbeat_ack_ends_the_connection_and_resumes() {
    let root = std::env::temp_dir().join(format!("discord-gateway-zombie-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&root);
    let (api, _calls) = rest();
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let port = listener.local_addr().unwrap().port();
    let stop = Arc::new(AtomicBool::new(false));
    let gateway = Gateway { app: app(&root, &api), url: Url::parse(&format!("ws://127.0.0.1:{port}/")).unwrap(),
        token: TOKEN.into(), tls: None, stop: stop.clone() };
    let client = std::thread::spawn(move || gateway.run());
    let mut ws = accept(&listener);
    say(&mut ws, json!({"op":10,"d":{"heartbeat_interval":200}}));
    assert_eq!(hear(&mut ws, false)["op"], 2);
    say(&mut ws, json!({"op":0,"s":5,"t":"READY","d":{"session_id":"sess-z","user":{"username":"x"}}}));
    // Never ACK: the second heartbeat time finds the first unanswered, and the client leaves.
    assert_eq!(hear(&mut ws, true)["op"], 1);
    let mut ws = accept(&listener);
    say(&mut ws, json!({"op":10,"d":{"heartbeat_interval":200}}));
    assert_eq!(hear(&mut ws, false), json!({"op":6,"d":{"token":TOKEN,"session_id":"sess-z","seq":5}}));
    stop.store(true, std::sync::atomic::Ordering::SeqCst);
    drop(ws);
    client.join().unwrap().unwrap();
    std::fs::remove_dir_all(&root).unwrap();
}
