//! The app market and the member's grains, as L13's seam names them (docs/APP-MARKET-2026-10-27.md
//! §5a): every route is one `apps …` shell line run as the member (`body::verb`), and its `--json`
//! reply (`{decided, state, detail, receipt}`) is drawn: the catalogue with claims beside verdicts,
//! a grain's state, routes and held identities, the one-time bootstrap hand-off to the grain's own
//! origin. The `apps` verb is one row of the shell's table, so `/verb/apps` already has every form;
//! these are the bespoke views. Where the verb is absent (a tree without L13's lane) the shell's
//! usage ending is shown by the one outcome partial, never a blank.

use super::body::{act, quote, verb, Ending};
use super::*;

/// The worker's JSON reply on stdout, when the ending carries one.
fn reply(ending: &Ending) -> Option<Value> {
    let text = ending.stdout.trim();
    let start = text.find('{')?;
    serde_json::from_str(&text[start..]).ok()
}

fn grain_id(n: &str) -> Option<String> {
    let id = n.strip_prefix('a').unwrap_or(n);
    (!id.is_empty() && id.len() <= 40 && id.bytes().all(|b| b.is_ascii_alphanumeric())).then(|| format!("a{id}"))
}

/// `/apps[?q=TERM]`: the catalogue.
pub(super) fn market(site: &Site, target: &str) -> Page {
    let term = super::body::query(target, "q").unwrap_or_default();
    let body = format!(
        "<p class=\"eyebrow\">The app market</p><p>Make room for your tools. Browse apps from the Sandstorm catalogue, then install a copy of your own.</p>\
         <form method=\"get\" action=\"/apps\" class=\"row\"><div><label for=\"q\">Find an app</label><input id=\"q\" name=\"q\" type=\"search\" placeholder=\"Search the catalogue\" value=\"{}\"></div><button>Search apps</button></form>\
         <p class=\"note\">Names, descriptions and publishers are catalogue claims. Each card separately shows this box's package verdict. Your installed copy runs on its own origin.</p>{installed}<section><h2>Available apps</h2>{}</section>",
        escape(&term), catalogue(site, &term, usize::MAX),
        installed = if site.front.read_only { "" } else { "<p><a href=\"/grain\">Open your installed apps →</a></p>" }
    );
    Page { status: 200, title: "Apps".into(), stamp: Stamp::None, body }
}

/// One catalogue, shared by the market and front page. The only input is `apps search`.
/// A failed read keeps its explained outcome; an empty catalogue is never fabricated.
pub(super) fn catalogue(site: &Site, term: &str, limit: usize) -> String {
    let mut line = String::from("apps search");
    if !term.is_empty() { line.push(' '); line.push_str(&quote(term)); }
    line.push_str(" --json");
    let Some(ending) = verb(site, &[line]) else { return "<p class=note>The app catalogue is unavailable: this body has no shell paths.</p>".into() };
    let Some(value) = reply(&ending).filter(|_| ending.code == 0) else {
        return super::body::answer_html(&ending, &[("Browse app commands", "/verb/apps")]);
    };
    let apps = value["apps"].as_array().or_else(|| value["receipt"]["apps"].as_array());
    let apps = apps.map(Vec::as_slice).unwrap_or(&[]);
    if apps.is_empty() {
        return "<div class=\"empty\"><h3>No apps found</h3><p>Try another search, or <a href=\"/apps\">browse the whole catalogue</a>.</p></div>".into();
    }
    let cards: String = apps.iter().take(limit).map(|app| app_card(app, !site.front.read_only, 3)).collect();
    format!("<div class=\"app-gallery\">{cards}</div><p class=note>{} of {} shown.</p>", apps.len().min(limit),
        value["total"].as_u64().or_else(|| value["receipt"]["total"].as_u64()).unwrap_or(apps.len() as u64))
}

fn app_card(app: &Value, writes: bool, level: u8) -> String {
    let text = |key: &str| escape(app[key].as_str().unwrap_or(""));
    let id = text("appId");
    let name = text("name");
    let mark = escape(&app["name"].as_str().unwrap_or("?").chars().next().unwrap_or('?').to_string());
    let state = escape(app["verdict"]["state"].as_str().unwrap_or("unchecked"));
    let reason = escape(app["verdict"]["reason"].as_str().unwrap_or("No additional verdict details reported."));
    let install = if writes {
        format!("<form method=\"post\" action=\"/apps/install\" class=\"inline\"><input type=\"hidden\" name=\"app\" value=\"{id}\"><button class=\"quiet\">Install</button></form>")
    } else { String::new() };
    format!(
        "<article class=\"app-card\" data-app=\"{id}\"><header><span class=\"app-mark\" aria-hidden=\"true\">{mark}</span><div><h{level}><a href=\"/apps/{id}\">{name}</a></h{level}><span class=\"publisher\">{}</span></div></header>\
         <p>{}</p><p class=\"note\">Version {} · Size {}</p>\
         <div class=\"verdict {state}\"><span class=\"badge\">{state}</span><p class=\"note\">{reason}</p></div>\
         <div class=\"actions\"><a href=\"/apps/{id}\">View app →</a>{install}</div></article>",
        text("publisher"), text("shortDescription"), text("version"), text("suggestedClass")
    )
}

/// `/apps/APP-ID`: one entry whole.
pub(super) fn show(site: &Site, app: &str) -> Page {
    let Some(ending) = verb(site, &[format!("apps show {} --json", quote(app))]) else { return simple(500, "Apps", "this body has no shell paths") };
    let mut body = match reply(&ending).filter(|_| ending.code == 0) {
        Some(value) => format!("{}<details><summary>Package details and publisher claims</summary>{}</details>", app_card(&value, false, 2), super::body::json_tree_html(&value)),
        None => super::body::outcome_html(&ending, &[("the market", "/apps")]),
    };
    if !site.front.read_only {
        body.push_str(&format!(
            "<form method=\"post\" action=\"/apps/install\" class=\"row\"><input type=\"hidden\" name=\"app\" value=\"{}\"><div><label for=\"cls\">Class</label><select id=\"cls\" name=\"class\"><option value=\"\">auto</option><option>S</option><option>M</option><option>L</option></select></div><button>Install</button></form>",
            escape(app)
        ));
    }
    Page { status: 200, title: format!("App {app}"), stamp: Stamp::None, body }
}

/// `POST /apps/install` (fields `app`, `class`).
pub(super) fn install(site: &Site, form: &std::collections::BTreeMap<String, String>) -> Page {
    let app = form.get("app").map(|s| s.trim()).unwrap_or("");
    if app.is_empty() {
        return simple(400, "Install", "which app?");
    }
    let mut line = format!("apps install {}", quote(app));
    if let Some(class) = form.get("class").map(|c| c.trim()).filter(|c| matches!(*c, "S" | "M" | "L")) {
        line.push_str(&format!(" --class {class}"));
    }
    act(site, &format!("Install {app}"), vec![line], "", &[("your grains", "/grain"), ("the market", "/apps")])
}

/// `/grain`: the grains this member owns or was shared.
pub(super) fn grains(site: &Site) -> Page {
    let Some(ending) = verb(site, &["apps list --json".to_owned()]) else { return simple(500, "Grains", "this body has no shell paths") };
    let body = match reply(&ending).filter(|_| ending.code == 0) {
        Some(value) => {
            let mut rows = String::new();
            for g in value["receipt"]["grains"].as_array().into_iter().flatten() {
                let id = g["grain"].as_str().unwrap_or("");
                rows.push_str(&format!(
                    "<tr><td><a href=\"/grain/{id}\"><code>{id}</code></a></td><td>{}</td><td>{}</td><td>{}</td><td><a href=\"{}\" data-full>{}</a></td></tr>",
                    escape(g["indexName"].as_str().unwrap_or("")),
                    escape(g["state"].as_str().unwrap_or("")),
                    if g["shared"] == true { "shared with you" } else { "yours" },
                    url(g["origin"].as_str().unwrap_or("")),
                    escape(g["origin"].as_str().unwrap_or("")),
                    id = escape(id)
                ));
            }
            format!(
                "<table><thead><tr><th>grain</th><th>app</th><th>state</th><th></th><th>origin</th></tr></thead><tbody>{rows}</tbody></table>{}",
                notice(&value["receipt"])
            )
        }
        None => super::body::outcome_html(&ending, &[("the market", "/apps")]),
    };
    Page { status: 200, title: "Grains".into(), stamp: Stamp::None, body }
}

fn notice(receipt: &Value) -> String {
    receipt["identityNotice"].as_str().map(|n| format!("<p class=\"outcome undecided\">{}</p>", escape(n))).unwrap_or_default()
}

/// `/grain/N`: the grain's state, routes, identities, and the actions on it.
pub(super) fn grain(site: &Site, n: &str) -> Page {
    let Some(id) = grain_id(n) else { return simple(404, "Grain", "not a grain id") };
    let Some(ending) = verb(site, &[format!("apps status {id} --json")]) else { return simple(500, "Grain", "this body has no shell paths") };
    let mut body = match reply(&ending).filter(|_| ending.code == 0) {
        Some(value) => {
            let r = &value["receipt"];
            let origin = r["origin"].as_str().unwrap_or("");
            let mut out = format!(
                "<p><strong>{}</strong> <code>{id}</code>: {} (class {}); origin <a href=\"{u}\" data-full>{o}</a></p>",
                escape(r["indexName"].as_str().unwrap_or("")),
                escape(value["state"].as_str().unwrap_or("?")),
                escape(r["class"].as_str().unwrap_or("?")),
                u = url(origin),
                o = escape(origin)
            );
            if let Some(runs) = r["runs"].as_array() {
                out.push_str("<section><h2>Runs</h2>");
                out.push_str(&super::body::json_tree_html(&Value::Array(runs.clone())));
                out.push_str("</section>");
            }
            let routes: Vec<String> = r["routes"].as_array().into_iter().flatten().filter_map(|v| v.as_str().map(str::to_owned)).collect();
            out.push_str(&format!("<section><h2>Routes</h2><p>{}</p></section>", if routes.is_empty() { "none".to_owned() } else { routes.iter().map(|r| format!("<code>{}</code>", escape(r))).collect::<Vec<_>>().join(" ") }));
            if let Some(identities) = r["identities"].as_array() {
                out.push_str("<section><h2>Identities this grain holds</h2>");
                if identities.is_empty() {
                    out.push_str("<p class=note>none</p>");
                } else {
                    out.push_str(&super::body::json_tree_html(&Value::Array(identities.clone())));
                    if !site.front.read_only {
                        out.push_str(&format!("<form method=\"post\" action=\"/grain/{id}/revoke-identity\" class=\"row\"><div><label for=\"tok\">Revoke a saved identity (its token)</label><input id=\"tok\" name=\"token\" type=\"text\" required></div><button class=\"quiet\">Revoke</button></form>"));
                    }
                }
                out.push_str("</section>");
            }
            out.push_str(&notice(r));
            out
        }
        None => super::body::outcome_html(&ending, &[("your grains", "/grain")]),
    };
    if !site.front.read_only {
        body.push_str(&format!(
            "<section><h2>Act</h2><p>\
             <form method=\"post\" action=\"/grain/{id}/open\" class=\"inline\"><button>Open</button></form> \
             <form method=\"post\" action=\"/grain/{id}/start\" class=\"inline\"><button class=\"quiet\">Start</button></form> \
             <form method=\"post\" action=\"/grain/{id}/stop\" class=\"inline\"><button class=\"quiet\">Stop</button></form> \
             <form method=\"post\" action=\"/grain/{id}/renew\" class=\"inline\"><button class=\"quiet\">Renew</button></form> \
             <form method=\"post\" action=\"/grain/{id}/export\" class=\"inline\"><input name=\"file\" type=\"text\" placeholder=\"export.spk\" aria-label=\"Export file name\" required pattern=\"[A-Za-z0-9._-]+\"><button class=\"quiet\">Export</button></form> \
             <form method=\"post\" action=\"/grain/{id}/delete\" class=\"inline\"><button class=\"quiet\">Delete</button></form></p>\
             <form method=\"post\" action=\"/grain/{id}/share\" class=\"row\"><div><label for=\"sh\">Share with (member name)</label><input id=\"sh\" name=\"member\" type=\"text\" pattern=\"[a-z][a-z0-9-]*\" required></div><button class=\"quiet\">Share</button></form></section>"
        ));
    }
    Page { status: 200, title: format!("Grain {id}"), stamp: Stamp::None, body }
}

/// `POST /grain/N/ACTION`.
pub(super) fn grain_action(site: &Site, n: &str, action: &str, form: &std::collections::BTreeMap<String, String>) -> Page {
    let Some(id) = grain_id(n) else { return simple(404, "Grain", "not a grain id") };
    let field = |k: &str| form.get(k).map(|v| v.trim().to_owned()).unwrap_or_default();
    match action {
        "open" => {
            let Some(ending) = verb(site, &[format!("apps open {id} --json")]) else { return simple(500, "Grain", "no shell paths") };
            match reply(&ending).filter(|_| ending.code == 0) {
                Some(value) => {
                    let r = &value["receipt"];
                    let origin = r["origin"].as_str().unwrap_or("").to_owned();
                    let body = match r["bootstrapToken"].as_str() {
                        Some(token) => format!(
                            "<p>Your route on <code>{id}</code> is ready. The grain lives on its own origin and keeps its own cookie, so the one-time token is posted there from your browser, not from here:</p>\
                             <form method=\"post\" action=\"{}\" target=\"_blank\" data-full data-autosubmit><input type=\"hidden\" name=\"token\" value=\"{}\"><button>Sign in to {id} on {o}</button></form>\
                             <p class=\"note\">Then <a href=\"/grain/{id}/pane\">open it in a pane</a>. The token works once; a fresh route needs a new share.</p>{}",
                            url(&format!("{origin}{}", r["bootstrapPath"].as_str().unwrap_or("/__mini/bootstrap"))),
                            escape(token),
                            notice(r),
                            o = escape(&origin)
                        ),
                        None => format!(
                            "<p>{}</p><p><a href=\"{u}\" data-full>{o}</a> · <a href=\"/grain/{id}/pane\">open in a pane</a></p>{}",
                            escape(value["detail"].as_str().unwrap_or("")),
                            notice(r),
                            u = url(&origin),
                            o = escape(&origin)
                        ),
                    };
                    Page { status: 200, title: format!("Open {id}"), stamp: Stamp::None, body }
                }
                None => Page { status: 200, title: format!("Open {id}"), stamp: Stamp::None, body: super::body::outcome_html(&ending, &[("the grain", &format!("/grain/{id}"))]) },
            }
        }
        "share" => act(site, &format!("Share {id}"), vec![format!("apps share {id} {}", quote(&field("member")))], "", &[("the grain", &format!("/grain/{id}"))]),
        "revoke-identity" => act(site, &format!("Revoke an identity on {id}"), vec![format!("apps revoke-identity {id} {}", quote(&field("token")))], "", &[("the grain", &format!("/grain/{id}"))]),
        "export" => act(site, &format!("export {id}"), vec![format!("apps export {id} {}", quote(&field("file")))], "", &[("the grain", &format!("/grain/{id}"))]),
        "renew" => act(site, &format!("Renew the enrollment on {id}"), vec![format!("apps renew {id}")], "", &[("the grain", &format!("/grain/{id}"))]),
        "stop" | "start" | "delete" => act(site, &format!("{action} {id}"), vec![format!("apps {action} {id}")], "", &[("the grain", &format!("/grain/{id}")), ("your grains", "/grain")]),
        _ => simple(404, "Grain", "no such action"),
    }
}

/// `/grain/N/pane`: the grain's origin in a frame (the gateway's `frame-src` names the grain origins).
pub(super) fn pane(site: &Site, n: &str) -> Page {
    let Some(id) = grain_id(n) else { return simple(404, "Grain", "not a grain id") };
    let Some(ending) = verb(site, &[format!("apps status {id} --json")]) else { return simple(500, "Grain", "no shell paths") };
    match reply(&ending).and_then(|v| v["receipt"]["origin"].as_str().map(str::to_owned)) {
        Some(origin) => Page {
            status: 200,
            title: format!("{id}"),
            stamp: Stamp::None,
            body: format!("<iframe class=\"grain\" src=\"{u}\" title=\"{id}\" sandbox=\"allow-scripts allow-forms allow-same-origin allow-popups\"></iframe><p class=note><a href=\"{u}\" data-full>{o}</a></p>", u = url(&origin), o = escape(&origin)),
        },
        None => Page { status: 200, title: format!("Grain {id}"), stamp: Stamp::None, body: super::body::outcome_html(&ending, &[]) },
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn grain_ids_and_worker_replies_parse() {
        assert_eq!(grain_id("7").as_deref(), Some("a7"));
        assert_eq!(grain_id("a7").as_deref(), Some("a7"));
        assert!(grain_id("../x").is_none());
        let ending = Ending { code: 0, stdout: "request 9\n{\"decided\":true,\"state\":\"open\",\"receipt\":{\"origin\":\"https://a7.demo.dregg.online\",\"bootstrapToken\":\"t\"}}\n".into(), stderr: String::new() };
        let value = reply(&ending).unwrap();
        assert_eq!(value["receipt"]["bootstrapToken"], "t");
        assert!(notice(&serde_json::json!({"identityNotice": "one user"})).contains("one user"));
    }
}
