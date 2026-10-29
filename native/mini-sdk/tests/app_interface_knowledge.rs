//! Source-derived package frames, not recorded live app captures.
use mini_sdk::app_interface::{Declaration, NativeReply, SessionBinding};
use serde_json::{json, Value};

fn binding(package: &str) -> SessionBinding {
    SessionBinding { package_id: package.into(), subject: "7".into(), app: "8".into(),
        generation: "0".into(), session: "9".into(), session_generation: "0".into() }
}
fn reply(q: &Value, frames: Vec<String>) -> NativeReply {
    NativeReply { status: 200, headers: vec![], body: serde_json::to_vec(&json!({
        "version":1,"channel":q["channel"],"op":q["op"],"frames":frames})).unwrap(),
        receipt: json!({"native":"fixture","op":q["op"]}) }
}
#[test]
fn wbo_native_write_delivery_and_independent_snapshot() {
    let d=Declaration::load(include_bytes!("../../../apps/interfaces/wbo.json")).unwrap();
    let b=binding("ac72e0d103d7f5c21e79dc74fc616b33");
    let mut item=Value::Null; let mut sends=0;
    let result=d.execute("rectangle.write",&json!({"board":"human","id":"owned","color":"#123456","size":4,"x":10,"y":10,"x2":120,"y2":90}),&json!({"operationId":"wbo-write"}),&b,|session,p| {
        assert_eq!(session.subject,"7"); assert_eq!(p.method,"CONVERSATION");
        assert!(p.query.contains("EIO=4"));
        let q:Value=serde_json::from_slice(&p.body).unwrap();
        let mut frames=vec![];
        if q["op"]=="open" { frames.push(r#"0{"sid":"s","pingInterval":25000}"#.into()); }
        if q["op"]=="send" {
            let text=q["text"].as_str().unwrap();
            if text=="40" {frames.push("40".into());}
            else {
                let v:Value=serde_json::from_str(text.strip_prefix("42").unwrap()).unwrap();
                if v[0]=="getboard" {assert_eq!(v[1],"human");frames.push(r#"42["broadcast",{"_children":[]}]"#.into());}
                else {assert_eq!(v[0],"broadcast");assert_eq!(v[1]["board"],"human");item=v[1]["data"].clone();sends+=1;}
            }
        }
        Ok(reply(&q,frames))
    });
    assert_eq!(result.outcome.unwrap(),json!({"delivery":"sent","id":"owned"}));
    assert_eq!(sends,1);
    let result=d.execute("board.read",&json!({"board":"human"}),&json!({"operationId":"wbo-read"}),&b,|_,p| {
        let q:Value=serde_json::from_slice(&p.body).unwrap();
        let frames=if q["op"]=="open" {vec![r#"0{"sid":"r","pingInterval":25000}"#.into()]}
        else if q["text"]=="40" {vec!["40".into()]}
        else if q["op"]=="send" {vec![format!("42{}",json!(["broadcast",{"_children":[item]}]))]}
        else {vec![]}; Ok(reply(&q,frames))
    });
    let values=result.outcome.unwrap();assert_eq!(values[0]["id"],"owned");assert_eq!(values[0]["x2"],120);
}
#[test]
fn scrumblr_native_room_and_matching_card_snapshot() {
    let d=Declaration::load(include_bytes!("../../../apps/interfaces/scrumblr.json")).unwrap();
    let result=d.execute("cards.read",&json!({"room":"/human"}),&json!({"operationId":"scrum-read"}),&binding("cf6ae092f937e7000b875cbb97d17907"),|_,p| {
        assert!(p.query.contains("EIO=3"));let q:Value=serde_json::from_slice(&p.body).unwrap();
        let frames=if q["op"]=="open" {vec![r#"0{"sid":"s","pingInterval":25000}"#.into(),"40".into()]}
        else if q["op"]=="send" {
            let v:Value=serde_json::from_str(q["text"].as_str().unwrap().strip_prefix("42").unwrap()).unwrap();
            assert_eq!(v[0],"message");
            if v[1]["action"]=="joinRoom" {assert_eq!(v[1]["data"],"/human");vec![r#"42["message",{"action":"roomAccept","data":""}]"#.into()]}
            else {assert_eq!(v[1]["action"],"initializeMe");vec![r#"42["message",{"action":"initColumns","data":[]}]"#.into(),r#"42["message",{"action":"initCards","data":[{"id":"owned","text":"typed"}]}]"#.into()]}
        } else {vec![]};Ok(reply(&q,frames))
    });
    assert_eq!(result.outcome.unwrap(),json!([{"id":"owned","text":"typed"}]));
}
#[test]
fn scrumblr_unknown_mutation_is_not_replayed() {
    let d=Declaration::load(include_bytes!("../../../apps/interfaces/scrumblr.json")).unwrap();let mut mutations=0;
    let result=d.execute("card.write",&json!({"room":"/human","id":"owned","text":"typed","colour":"yellow","x":58,"y":120,"rot":3}),&json!({"operationId":"scrum-unknown"}),&binding("cf6ae092f937e7000b875cbb97d17907"),|_,p| {
        let q:Value=serde_json::from_slice(&p.body).unwrap();
        let frames=if q["op"]=="open" {vec![r#"0{"sid":"s","pingInterval":25000}"#.into(),"40".into()]}
        else if q["op"]=="send" {
            let v:Value=serde_json::from_str(q["text"].as_str().unwrap().strip_prefix("42").unwrap()).unwrap();
            if v[1]["action"]=="joinRoom" {vec![r#"42["message",{"action":"roomAccept","data":""}]"#.into()]}
            else {mutations+=1;return Err(mini_sdk::app_interface::Refusal{name:"physical-reply-lost".into(),uncertain:true});}
        } else {vec![]};Ok(reply(&q,frames))
    });
    assert_eq!(mutations,1);assert!(result.outcome.unwrap_err().uncertain);
}
