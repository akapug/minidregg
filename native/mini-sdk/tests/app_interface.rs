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
