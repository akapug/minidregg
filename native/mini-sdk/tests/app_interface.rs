use mini_sdk::app_interface::Declaration;
use serde_json::json;
#[test]
fn native_gogs_encodes_declared_call_and_refuses_bad_input() {
    let d = Declaration::load(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    let p = d
        .prepare(
            "issue.create",
            &json!({"owner":"alice","repo":"one","title":"typed","body":"hi"}),
            &json!({}),
        )
        .unwrap();
    assert_eq!(p.path, "api/v1/repos/alice/one/issues");
    assert_eq!(
        serde_json::from_slice::<serde_json::Value>(&p.body).unwrap(),
        json!({"title":"typed","body":"hi"})
    );
    assert!(d
        .prepare(
            "issue.create",
            &json!({"owner":"../bob","repo":"one","title":"typed","body":"hi"}),
            &json!({})
        )
        .is_err());
}
#[test]
fn native_dav_binary_and_uncertain_writes() {
    let d = Declaration::load(include_bytes!("../../../apps/interfaces/davros.json")).unwrap();
    let p = d
        .prepare(
            "file.put",
            &json!({"path":"dir/a.bin","contentBase64":"AP8="}),
            &json!({}),
        )
        .unwrap();
    assert_eq!(p.body, vec![0, 255]);
    assert!(d.decode(&p, 500, &[], b"bad").unwrap_err().uncertain);
    let p = d
        .prepare("file.get", &json!({"path":"dir/a.bin"}), &json!({}))
        .unwrap();
    assert_eq!(
        d.decode(&p, 200, &[], &[0, 255]).unwrap(),
        json!({"contentBase64":"AP8="})
    );
}

fn binding() -> mini_sdk::app_interface::SessionBinding {
    mini_sdk::app_interface::SessionBinding {
        package_id: "aede44cf19129337aae68b6993324574".into(),
        subject: "7".into(),
        app: "8".into(),
        generation: "0".into(),
        session: "9".into(),
        session_generation: "0".into(),
    }
}
#[test]
fn executor_retains_receipt_and_never_replays_uninterpretable_write() {
    use mini_sdk::app_interface::NativeReply;
    let d = Declaration::load(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    let mut calls = 0;
    let e = d.execute(
        "repo.create",
        &json!({"name":"hello","description":""}),
        &json!({}),
        &binding(),
        |_, _| {
            calls += 1;
            Ok(NativeReply {
                status: 201,
                headers: vec![("content-type".into(), "application/json".into())],
                body: b"{}".to_vec(),
                receipt: json!({"exact":"native"}),
            })
        },
    );
    assert_eq!(calls, 1);
    assert!(e.outcome.unwrap_err().uncertain);
    assert_eq!(e.receipts, vec![json!({"exact":"native"})]);
}
#[test]
fn preparation_uses_result_token_and_scoped_app_cookie() {
    use mini_sdk::app_interface::NativeReply;
    let mut d: serde_json::Value =
        serde_json::from_slice(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    d["auth"]["appCookies"] = json!("retain");
    d["operations"]["token"] = json!({"internal":true,"description":"token","input":{"type":"object","additionalProperties":false},"output":{"type":"object","properties":{"token":{"type":"string"}},"required":["token"]},"write":false,"binding":{"protocol":"http","method":"GET","path":["token"],"status":[200],"decode":"json"}});
    d["operations"]["edit"] = json!({"description":"edit","input":{"type":"object","additionalProperties":false},"output":{"type":"string"},"write":true,"prepare":[{"id":"csrf","op":"token","args":{}}],"binding":{"protocol":"http","method":"POST","path":["edit"],"form":{"token":{"result":["csrf","token"]},"text":"a & b"},"status":[200],"decode":"text"}});
    let d = Declaration::load(&serde_json::to_vec(&d).unwrap()).unwrap();
    assert!(!d.tools().unwrap().iter().any(|t| t["operation"] == "token"));
    let mut calls = 0;
    let e = d.execute("edit", &json!({}), &json!({}), &binding(), |b, p| {
        assert_eq!(b.subject, "7");
        calls += 1;
        Ok(if calls == 1 {
            NativeReply {
                status: 200,
                headers: vec![
                    ("content-type".into(), "application/json".into()),
                    ("set-cookie".into(), "sid=member; HttpOnly".into()),
                ],
                body: br#"{"token":"secret"}"#.to_vec(),
                receipt: json!({"read":true}),
            }
        } else {
            assert_eq!(p.body, b"text=a%20%26%20b&token=secret");
            assert!(p
                .ordered_headers
                .contains(&("cookie".into(), "sid=member".into())));
            NativeReply {
                status: 200,
                headers: vec![],
                body: b"edited".to_vec(),
                receipt: json!({"write":true}),
            }
        })
    });
    assert_eq!(e.outcome.unwrap(), json!("edited"));
    assert_eq!(e.receipts.len(), 2);
    assert_eq!(calls, 2);
}

#[test]
fn declaration_refuses_schema_constraints_it_cannot_enforce() {
    let mut d: serde_json::Value =
        serde_json::from_slice(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    d["operations"]["repo.create"]["input"]["not"] = json!({"required":["name"]});
    assert_eq!(
        Declaration::load(&serde_json::to_vec(&d).unwrap())
            .unwrap_err()
            .name,
        "schema-keyword-unsupported"
    );
}

#[test]
fn native_generic_multipart_cookie_expression_and_json_lines() {
    use mini_sdk::app_interface::NativeReply;
    let mut v: serde_json::Value =
        serde_json::from_slice(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    v["operations"]["upload"] = json!({"description":"upload","input":{"type":"object","properties":{},"additionalProperties":false},"output":{"type":"array","items":{"type":"object"}},"write":true,"binding":{"protocol":"http","method":"POST","path":["upload"],"status":[200],"decode":"json-lines","multipart":[{"name":"file","filename":"a.bin","contentType":"application/octet-stream","base64":"AP8="},{"name":"title","text":"hello"}]}});
    let d = Declaration::load(&serde_json::to_vec(&v).unwrap()).unwrap();
    let e = d.execute("upload", &json!({}), &json!({}), &binding(), |_, p| {
        assert!(p.body.windows(2).any(|w| w == [0, 255]));
        assert!(p
            .ordered_headers
            .iter()
            .any(|(k, v)| k == "content-type" && v.starts_with("multipart/form-data; boundary=")));
        Ok(NativeReply {
            status: 200,
            headers: vec![],
            body: b"{\"id\":1}\n{\"id\":2}\n".to_vec(),
            receipt: json!({"native":"exact"}),
        })
    });
    assert_eq!(e.outcome.unwrap(), json!([{"id":1},{"id":2}]));
    assert!(mini_sdk::app_interface::resolve(
        &json!({"cookie":"csrf"}),
        &json!({}),
        &json!({"csrf":"caller-forged"}),
        &json!({})
    )
    .is_err());
}

#[test]
fn declaration_digest_matches_contract_unicode_escaping() {
    let mut v: serde_json::Value =
        serde_json::from_slice(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    v["description"] = json!("é💖\u{7f}");
    let d = Declaration::load(&serde_json::to_vec(&v).unwrap()).unwrap();
    assert_eq!(
        d.sha256,
        "917da2077e2421276b725d74c73dbc1bc5fd9e0e838cd3f497d9040ee2bfaba4"
    );
}

#[test]
fn native_ddp_authenticates_with_server_identity_and_waits_for_updated() {
    use mini_sdk::app_interface::NativeReply;
    let d = Declaration::load(include_bytes!("../../../apps/interfaces/wekan.json")).unwrap();
    let mut b = binding();
    b.package_id = d.package_id.clone();
    let mut mutations = 0;
    let e = d.execute(
        "board.create",
        &json!({"title":"typed"}),
        &json!({"operationId":"controller-operation","rendezvousSeed":"12".repeat(32),"nowMs":42}),
        &b,
        |_, p| {
            assert_eq!(p.method, "CONVERSATION");
            assert_eq!(p.path, "websocket");
            let q: serde_json::Value = serde_json::from_slice(&p.body).unwrap();
            let mut frames = vec![];
            let mut http = None;
            match q["op"].as_str().unwrap() {
                "open" | "close" => {}
                "send" => {
                    let m: serde_json::Value =
                        serde_json::from_str(q["text"].as_str().unwrap()).unwrap();
                    if m["msg"] == "connect" {
                        frames.push(json!({"msg":"connected","session":"app-session"}).to_string());
                    } else if m["msg"] == "method" {
                        mutations += 1;
                        assert_eq!(m["params"][0]["members"][0]["userId"], "server-member");
                        assert_eq!(m["params"][0]["_id"], m["id"]);
                        frames.push(
                            json!({"msg":"result","id":m["id"],"result":m["id"]}).to_string(),
                        );
                    }
                }
                "rendezvous" => {
                    let m: serde_json::Value =
                        serde_json::from_str(q["text"].as_str().unwrap()).unwrap();
                    assert_eq!(m["method"], "loginWithSandstorm");
                    assert_eq!(
                        q["http"]["bodyHex"],
                        mini_sdk::hex::encode(m["params"][0].as_str().unwrap().as_bytes())
                    );
                    http = Some(204);
                    frames.push(json!({"msg":"updated","methods":[m["id"]]}).to_string());
                    frames.push(
                        json!({"msg":"result","id":m["id"],"result":{"userId":"server-member"}})
                            .to_string(),
                    );
                }
                "receive" => {
                    assert_eq!(q["condition"]["msg"], "updated");
                    frames.push(
                        json!({"msg":"updated","methods":[q["condition"]["id"]]}).to_string(),
                    );
                }
                _ => panic!("unexpected native conversation descriptor"),
            }
            let mut response =
                json!({"version":1,"channel":q["channel"],"op":q["op"],"frames":frames});
            if let Some(s) = http {
                response["httpStatus"] = json!(s)
            }
            Ok(NativeReply {
                status: 200,
                headers: vec![],
                body: serde_json::to_vec(&response).unwrap(),
                receipt: json!({"native":"retained"}),
            })
        },
    );
    assert_eq!(mutations, 1);
    assert!(e.outcome.unwrap()["id"].is_string());
    assert_eq!(e.receipts.len(), 6);
}

#[test]
fn caldav_report_does_not_require_resource_type() {
    let mut d: serde_json::Value =
        serde_json::from_slice(include_bytes!("../../../apps/interfaces/davros.json")).unwrap();
    d["operations"]["events"] = json!({"description":"events","input":{"type":"object"},"output":{"type":"array","items":{"type":"object","properties":{"href":{"type":"string"},"etag":{"type":"string"},"calendarData":{"type":"string"}},"required":["href","etag","calendarData"],"additionalProperties":false}},"write":false,"binding":{"protocol":"http","method":"REPORT","path":["dav/"],"decode":"caldav-multistatus","status":[207]}});
    let d = Declaration::load(&serde_json::to_vec(&d).unwrap()).unwrap();
    let p = d.prepare("events", &json!({}), &json!({})).unwrap();
    let xml=br#"<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:response><d:href>/event.ics</d:href><d:propstat><d:prop><d:getetag>"a"</d:getetag><c:calendar-data>BEGIN:VCALENDAR</c:calendar-data></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat><d:propstat><d:prop><d:resourcetype/></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response></d:multistatus>"#;
    assert_eq!(
        d.decode(&p, 207, &[], xml).unwrap(),
        json!([{"href":"/event.ics","etag":"\"a\"","calendarData":"BEGIN:VCALENDAR"}])
    );
}
#[test]
fn readonly_await_retries_only_declared_transient_statuses() {
    use mini_sdk::app_interface::NativeReply;
    let mut v: serde_json::Value =
        serde_json::from_slice(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    v["qualification"] = json!([{"id":"repo","op":"repo.create","args":{"name":"x","description":""}},{"id":"me","op":"user.read","args":{},"assert":[{"path":["login"],"equals":"member"}],"await":{"attempts":3,"intervalSeconds":0,"retryStatuses":[503]}}]);
    let d = Declaration::load(&serde_json::to_vec(&v).unwrap()).unwrap();
    let mut calls = 0;
    let mut reads = 0;
    let e = d.qualify(&json!({}), &binding(), |_, p| {
        calls += 1;
        if p.method == "POST" {
            return Ok(NativeReply {
                status: 201,
                headers: vec![("content-type".into(), "application/json".into())],
                body: br#"{"id":1,"name":"x","owner":{"id":1,"login":"member"}}"#.to_vec(),
                receipt: json!({"native":calls}),
            });
        }
        reads += 1;
        Ok(NativeReply {
            status: if reads == 1 { 503 } else { 200 },
            headers: vec![("content-type".into(), "application/json".into())],
            body: br#"{"id":1,"login":"member"}"#.to_vec(),
            receipt: json!({"native":calls}),
        })
    });
    assert_eq!(calls, 3);
    assert!(e.outcome.is_ok());
    assert_eq!(e.receipts.len(), 3);
}
#[test]
fn additional_declared_interfaces_load_if_fixture_directory_is_supplied() {
    let Some(dir) = std::env::var_os("MINI_INTERFACE_FIXTURES") else {
        return;
    };
    for path in std::fs::read_dir(dir).unwrap() {
        let path = path.unwrap().path();
        if path.extension().is_some_and(|e| e == "json") {
            if let Err(e) = Declaration::load(&std::fs::read(&path).unwrap()) {
                panic!("{}: {}", path.display(), e.name)
            }
        }
    }
}

#[test]
fn postmutation_cookie_refusal_is_uncertain_but_default_omit_ignores_it() {
    use mini_sdk::app_interface::NativeReply;
    for retain in [false, true] {
        let mut v: serde_json::Value =
            serde_json::from_slice(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
        if retain {
            v["auth"]["appCookies"] = json!("retain")
        }
        let d = Declaration::load(&serde_json::to_vec(&v).unwrap()).unwrap();
        let e = d.execute(
            "repo.create",
            &json!({"name":"x","description":""}),
            &json!({}),
            &binding(),
            |_, _| {
                Ok(NativeReply {
                    status: 201,
                    headers: vec![
                        ("content-type".into(), "application/json".into()),
                        (
                            "set-cookie".into(),
                            "__Host-mini_spk_session=forged; Path=/".into(),
                        ),
                    ],
                    body: br#"{"id":1,"name":"x","owner":{"id":1,"login":"owner"}}"#.to_vec(),
                    receipt: json!({"exact":"committed"}),
                })
            },
        );
        assert_eq!(e.receipts.len(), 1);
        if retain {
            let err = e.outcome.unwrap_err();
            assert_eq!(err.name, "app-cookie-reserved");
            assert!(err.uncertain)
        } else {
            assert!(e.outcome.is_ok())
        }
    }
}

#[test]
fn declaration_digest_matches_contract_numeric_normalization() {
    let mut v: serde_json::Value =
        serde_json::from_slice(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    v["number"] = serde_json::from_str("5e-7").unwrap();
    assert_eq!(
        Declaration::load(&serde_json::to_vec(&v).unwrap())
            .unwrap()
            .sha256,
        "3064a2deefcb7380ef493ad97241ef6284ce167ffa75944167ad4eb4d73b4176"
    );
    let mut v: serde_json::Value =
        serde_json::from_slice(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    v["number"] = serde_json::from_str("1e16").unwrap();
    assert_eq!(
        Declaration::load(&serde_json::to_vec(&v).unwrap())
            .unwrap()
            .sha256,
        "75c8e38ca7cb6d620e7e8acef955fdaf7ee757cd4bcfcc41ea43c536e3ee418e"
    );
    let mut v: serde_json::Value =
        serde_json::from_slice(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    v["number"] = serde_json::from_str("100000.0").unwrap();
    assert_eq!(
        Declaration::load(&serde_json::to_vec(&v).unwrap())
            .unwrap()
            .sha256,
        "756d7c74fb948808e52500faec393130895a715a980df7f0f379174431499295"
    );
    let mut v: serde_json::Value =
        serde_json::from_slice(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    v["number"] = serde_json::from_str("-0.0").unwrap();
    assert_eq!(
        Declaration::load(&serde_json::to_vec(&v).unwrap())
            .unwrap()
            .sha256,
        "4563f556447a18181911e9efcd9940c93075900f897cfc6a4fc33b6cc9dca3fa"
    );
    let mut v: serde_json::Value =
        serde_json::from_slice(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    v["number"] = serde_json::from_str("1.2345678901234567e30").unwrap();
    assert_eq!(
        Declaration::load(&serde_json::to_vec(&v).unwrap())
            .unwrap()
            .sha256,
        "ede046763257196f30e988101622270948ceb0549f066608f83083272b5d52a5"
    );
}

#[test]
fn qualification_refuses_missing_write_readback_before_any_dispatch() {
    let mut v: serde_json::Value =
        serde_json::from_slice(include_bytes!("../../../apps/interfaces/gogs.json")).unwrap();
    v["qualification"] = json!([{"id":"me","op":"user.read","args":{}}]);
    let d = Declaration::load(&serde_json::to_vec(&v).unwrap()).unwrap();
    let e = d.qualify(&json!({}), &binding(), |_, _| panic!("must not dispatch"));
    assert_eq!(
        e.outcome.unwrap_err().name,
        "qualification-write-readback-absent"
    );
    assert!(e.receipts.is_empty());
}
