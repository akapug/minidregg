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
