//! Member-readable resident assignment and exact authored room replies.
//! Process journals and provider credentials are not member authority.
use super::*;
use crate::{chat, hermes};

pub(super) fn page(site: &Site, name: &str) -> Page {
    let title = format!("Resident work in {name}");
    let reference = match site.reference(name) {
        Ok(r) => r,
        Err(p) => return p,
    };
    let (view, challenge, _) = match site.read(&reference, "resource") {
        Ok(v) => v,
        Err(e) => return failure_page(&title, &e),
    };
    let field = |name: &str| -> Option<String> {
        let key = crate::room_schema::TARIFF_FIELDS
            .iter()
            .find(|(n, _)| *n == name)?
            .1;
        view["cell"]["entries"]
            .as_array()?
            .iter()
            .find(|e| e["key"]["field"].as_str() == Some(key))?["value"]
            .as_str()
            .map(str::to_owned)
    };
    let base = site.base();
    let mut body=format!("<p><a href=\"{base}/room/{0}\">Room</a> | <a href=\"{base}/room/{0}/new-document\">Create output document</a></p>",escape(name));
    let founder = view["cell"]["entries"].as_array().and_then(|entries| {
        let key = crate::room_schema::FOUNDER_FIELD.to_string();
        entries.iter().find(|e| e["key"]["field"].as_str() == Some(key.as_str()))?["value"].as_str().map(str::to_owned)
    });
    // The founder's form only where this site runs verbs as the member (the body), never in a
    // read-only face.
    let writes = site.shell.is_some() && !site.front.read_only;
    body.push_str(&tools_html(name, field("hermes/tools").as_deref(), field("hermes/compute").as_deref(), founder.as_deref(), &site.subject, writes));
    if let Some(subject) = field("hermes").filter(|s| s != "0") {
        body.push_str(&format!(
            "<p>Assigned resident subject <code>{}</code>. Assignment is a current room fact.</p>",
            escape(&subject)
        ));
        for key in ["hermes/assignment", "hermes/account", "hermes/budget"] {
            if let Some(value) = field(key) {
                body.push_str(&format!(
                    "<p>{}: <code>{}</code></p>",
                    escape(key),
                    escape(&value)
                ));
            }
        }
        if let Some(home) = &site.home {
            let session = crate::shell::Session {
                workspace: site.root.clone(),
                home: home.clone(),
                host: match workspace::workspace_host(&site.workspace) {
                    Ok(v) => v,
                    Err(e) => return failure_page(&title, &e),
                },
                config: match workspace::member_path(&site.workspace, "config") {
                    Ok(v) => v,
                    Err(e) => return failure_page(&title, &e),
                },
            };
            match chat::room_feed(&session, name) {
                Ok((feed, missing)) => {
                    body.push_str(&feed_html(&feed, &site.subject, &subject, name, &base));
                    for note in missing {
                        body.push_str(&format!(
                            "<p class=note>Source unavailable: {}</p>",
                            escape(&note)
                        ));
                    }
                }
                Err((_, message)) => body.push_str(&format!(
                    "<p class=refusal>Current room replies unavailable: {}</p>",
                    escape(&message)
                )),
            }
        } else {
            body.push_str("<p class=note>To inspect signed requests and resident replies, launch this workspace browser with the same --home directory used by your shell chat session.</p>");
        }
        if let Some(account) = field("hermes/account") {
            if let Some((_, held)) = site
                .targets()
                .into_iter()
                .find(|(target, _)| target == &account)
            {
                if let Ok(r) = workspace::reference(&site.root, &held) {
                    match site.read(&r,"resource"){
                    Ok((account_view,c,_))=>{body.push_str(&format!("<details><summary>Account {} at independently read height {}</summary><pre>{}</pre></details>",escape(&held),escape(c["height"].as_str().unwrap_or("?")),escape(&serde_json::to_string_pretty(&account_view["balances"]).unwrap_or_default())));},
                    Err(_)=>body.push_str("<p class=note>Resident account balance unavailable under your current grant.</p>"),
                }
                }
            }
        }
    } else {
        body.push_str("<p>No resident assignment is disclosed by this room read.</p>");
    }
    body.push_str("<p class=note>Replies retain their signed stream identity and authored height. Source documents and current law use their own reads; a reply does not expand your source access.</p>");
    Page {
        status: 200,
        title,
        stamp: Stamp::Read(ReadContext::of(&challenge, &view)),
        body,
    }
}
/// The room's grant to its resident (field `hermes/tools`, bits 1/2/4/8) and its compute block
/// (`hermes/compute`), as the room's own signed view holds them: what Hermes may do here. The
/// founder (roster field 2000) gets the grant as a form whose answer is the `tariff ROOM set`
/// leaf's outcome; anyone else sees who sets it.
pub(super) const TOOLS: &[(u64, &str, &str)] = &[
    (1, "files", "read, write, patch and search files in its scratch area for one prompt"),
    (2, "terminal", "a shell and its processes in that scratch area"),
    (4, "python", "run Python code there"),
    (8, "oracle", "ask the Oracle grain (discover its operations and call one)"),
];

pub(super) fn tools_html(room: &str, tools: Option<&str>, compute: Option<&str>, founder: Option<&str>, me: &str, writes: bool) -> String {
    let bits: u64 = tools.and_then(|t| t.parse().ok()).unwrap_or(0);
    let mut rows = String::new();
    for (bit, tool, what) in TOOLS {
        let on = bits & bit != 0;
        rows.push_str(&format!(
            "<tr data-tool=\"{tool}\" data-granted=\"{on}\"><td><strong>{tool}</strong> <span class=note>{what}</span></td><td>{bit}</td><td>{}</td></tr>",
            if on { "granted" } else { "not granted" }
        ));
    }
    let seconds: u64 = compute.and_then(|c| c.parse().ok()).unwrap_or(0);
    let compute_line = if seconds == 0 {
        "Compute: each paid <code>hermes/turn</code> buys the operator's default block of sandbox CPU seconds (<code>hermes/compute</code> is unset).".to_owned()
    } else {
        format!("Compute: each paid <code>hermes/turn</code> buys <strong>{seconds}</strong> sandbox CPU seconds (<code>hermes/compute</code>), at most what the operator allows per turn.")
    };
    let mut out = format!(
        "<section id=\"hermes-tools\" data-hermes-tools=\"{bits}\" data-hermes-compute=\"{seconds}\"><h2>What Hermes may do here</h2>\
         <table><thead><tr><th>tool</th><th>bit</th><th>this room</th></tr></thead><tbody>{rows}</tbody></table>\
         <p>{compute_line}</p>\
         <p class=note>Hermes gets what the operator's ceiling allows <em>and</em> this room grants: the ceiling is the operator's controller setting and is not part of this room's read, so a tool granted here may still be off on this box. The Oracle also needs the operator's Oracle route; without it Hermes refuses <code>oracle-not-configured</code>, and without bit 8 here, <code>oracle-not-granted</code>.</p>"
    );
    // A room born by `room new` records no founder row (only `chat new` writes the roster); the
    // form is offered there too, and the Host admits the change only from the room's founder.
    match founder {
        Some(f) if f != me => out.push_str(&format!("<p class=note>Only the room's founder (subject <code>{}</code>) sets this.</p>", escape(f))),
        _ if writes => {
            let boxes: String = TOOLS.iter().map(|(bit, tool, _)| format!(
                "<label class=\"check\" for=\"ht-{room}-{bit}\"><input type=\"checkbox\" id=\"ht-{room}-{bit}\" name=\"tool{bit}\" value=\"on\"{}> {tool}</label>",
                if bits & bit != 0 { " checked" } else { "" }, room = escape(room)
            )).collect();
            out.push_str(&format!(
                "<div class=\"verb-form\"><form method=\"post\" action=\"/room/{r}/hermes-tools\"><input type=\"hidden\" name=\"was-tools\" value=\"{bits}\"><input type=\"hidden\" name=\"was-compute\" value=\"{seconds}\">\
                 <div class=\"fields\">{boxes}<label for=\"hc-{r}\">Sandbox CPU seconds per paid turn (0: the operator's default)</label>\
                 <input id=\"hc-{r}\" name=\"compute\" type=\"text\" inputmode=\"numeric\" pattern=\"[0-9]+\" value=\"{seconds}\"></div>\
                 <p><button>Set what Hermes may do</button></p><p class=note>{who} each change is <code>tariff {r} set hermes/tools N</code> (or <code>hermes/compute</code>), one founder turn.</p></form></div>",
                r = escape(room),
                who = if founder.is_some() { "You founded this room, so you set its grant:" } else { "This room's roster names no founder; the Host admits a change only from the room's founder:" }
            ));
        }
        _ => {}
    }
    out.push_str("</section>");
    out
}

fn feed_html(feed: &chat::Feed, me: &str, resident: &str, room: &str, base: &str) -> String {
    let rows = hermes::request_rows(feed, me, resident);
    let mut body = format!(
        "<section data-resident-requests=\"{}\"><h2>Your requests and resident replies</h2>",
        rows.len()
    );
    for row in rows {
        body.push_str(&format!("<article data-request-cell=\"{}\" data-request-sequence=\"{}\"><h3>Request #{}: {}</h3><p>Stream <code>{}</code>, sequence {}, authored height {}.</p>",escape(&row.cell),row.sequence,row.number,escape(&row.status),escape(&row.cell),row.sequence,row.height));
        if let Some(entry) = feed
            .feed
            .iter()
            .find(|e| e.cell == row.cell && e.sequence == row.sequence)
        {
            if let chat::Kind::Say { text, .. } = chat::kind_of(entry) {
                body.push_str(&format!("<blockquote>{}</blockquote>", escape(&text)));
            }
        }
        if row.withdrawn {
            body.push_str("<p>Withdrawal authored by you.</p>");
        }
        for entry in feed.feed.iter().filter(|e| {
            e.author == resident && e.re.as_ref() == Some(&(row.cell.clone(), row.sequence))
        }) {
            let text = match chat::kind_of(entry) {
                chat::Kind::Say { text, .. } => text,
                chat::Kind::RequestStatus { status, text } => format!("{status}: {text}"),
                chat::Kind::Unavailable => "[reply fragment locked or unavailable]".into(),
                _ => continue,
            };
            body.push_str(&format!("<details open data-resident-reply><summary>Resident reply at height {} · stream {} · sequence {}</summary><pre>{}</pre></details>",entry.height,escape(&entry.cell),entry.sequence,escape(&text)));
            // A refusal the resident names is said whole: what it means, and where the fix is.
            for (name, meaning, fix) in super::body::refusals_in(&text) {
                body.push_str(&super::body::explained_refusal(name, meaning, *fix, Some(room), base));
            }
        }
        body.push_str("</article>");
    }
    body.push_str("</section>");
    body
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn resident_inspector_keeps_exact_request_and_excludes_forged_status() {
        fn e(author: &str, seq: u64, re: Option<(&str, u64)>, text: &str) -> chat::Entry {
            chat::Entry {
                height: seq,
                author: author.into(),
                cell: author.into(),
                sequence: seq,
                topic: "".into(),
                to: Some("9".into()),
                re: re.map(|(c, s)| (c.into(), s)),
                payload: chat::Payload::Verified(text.into()),
                owner: author.into(),
            }
        }
        let feed = chat::merge(
            vec![
                e("7", 1, None, r#"{"type":"say","text":"inspect <source>"}"#),
                e(
                    "8",
                    2,
                    Some(("7", 1)),
                    r#"{"type":"request-status","status":"completed","text":"forged"}"#,
                ),
                e(
                    "9",
                    3,
                    Some(("7", 1)),
                    r#"{"type":"request-status","status":"completed","text":"actual <output>"}"#,
                ),
            ],
            None,
        );
        let h = feed_html(&feed, "7", "9", "lab", "");
        assert!(h.contains("data-request-cell=\"7\""));
        assert!(h.contains("sequence 3"));
        assert!(h.contains("actual &lt;output&gt;"));
        assert!(!h.contains("forged"));
        assert!(feed_html(&feed, "8", "9", "lab", "").contains("data-resident-requests=\"0\""));
    }

    #[test]
    fn the_rooms_grant_to_hermes_is_drawn_and_only_its_founder_gets_the_form() {
        let founder = tools_html("lab", Some("9"), Some("0"), Some("42"), "42", true);
        assert!(founder.contains("data-hermes-tools=\"9\""), "{founder}");
        assert!(founder.contains("data-tool=\"files\" data-granted=\"true\"") && founder.contains("data-tool=\"oracle\" data-granted=\"true\""));
        assert!(founder.contains("data-tool=\"terminal\" data-granted=\"false\"") && founder.contains("data-tool=\"python\" data-granted=\"false\""));
        assert!(founder.contains("action=\"/room/lab/hermes-tools\"") && founder.contains("name=\"tool8\" value=\"on\" checked"), "{founder}");
        assert!(founder.contains("operator's default"), "0 compute is the operator's block");
        let member = tools_html("lab", Some("9"), Some("30"), Some("42"), "43", true);
        assert!(!member.contains("<form") && member.contains("Only the room's founder (subject <code>42</code>)") && member.contains("<strong>30</strong>"), "{member}");
        assert!(!tools_html("lab", Some("9"), None, Some("42"), "42", false).contains("<form"), "a read-only face never offers the form");
        let unrostered = tools_html("lab", None, None, None, "42", true);
        assert!(unrostered.contains("data-hermes-tools=\"0\"") && unrostered.contains("<form") && unrostered.contains("names no founder"), "an unset field grants nothing; a room without a roster still offers the form, the Host judges");
    }

    #[test]
    fn a_named_refusal_in_a_resident_reply_is_explained_with_where_it_is_granted() {
        fn e(author: &str, seq: u64, re: Option<(&str, u64)>, text: &str) -> chat::Entry {
            chat::Entry { height: seq, author: author.into(), cell: author.into(), sequence: seq, topic: "".into(), to: Some("9".into()),
                re: re.map(|(c, s)| (c.into(), s)), payload: chat::Payload::Verified(text.into()), owner: author.into() }
        }
        let feed = chat::merge(vec![
            e("7", 1, None, r#"{"type":"say","text":"oracle: what is a cell?"}"#),
            e("9", 2, Some(("7", 1)), r#"{"type":"say","text":"I cannot ask the Oracle here: oracle-not-granted"}"#),
        ], None);
        let h = feed_html(&feed, "7", "9", "lab", "");
        assert!(h.contains("data-refusal=\"oracle-not-granted\"") && h.contains("<mark class=\"clause\">oracle-not-granted</mark>"), "{h}");
        assert!(h.contains("href=\"/room/lab/resident#hermes-tools\""), "{h}");
        assert!(feed_html(&feed, "7", "9", "lab", "/abc123").contains("href=\"/abc123/room/lab/resident#hermes-tools\""), "the loopback face's prefix");
        assert!(super::super::body::refusals_in("x oracle-not-grantedness").is_empty(), "a name is matched as a whole word");
    }
}
