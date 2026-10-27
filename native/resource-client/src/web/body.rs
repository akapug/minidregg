//! `mini web --body`: the member's rendering process behind the web gateway
//! (docs/WEB-FRONTEND-2026-10-27.md §2). It serves the listener the root helper bound and handed
//! it on fd 3 (a root-only path, so only the gateway, through the helper, reaches it), and answers
//! stage FRAGMENTS: the `Site` renders this file's parent already has (documents, history, diffs,
//! boards, rooms, inspection, search, the editor), plus the places the one front end adds
//! (receipts, grants and laws, keys) and the actions behind every form.
//!
//! Every action is a `mini shell` line run as this member, through the same `shell` subcommand
//! the ssh login runs (`mini shell --workspace … --home …`, script mode on stdin), and its ending
//! is rendered by one partial: exit 0 admitted, 3 refused (the Host's own clause), 4 undecided
//! (the attempt is retained; `lookup` and `retry` are offered), 1 and 2 the client's error or
//! usage. There is no admission logic here: the shell decides, the body shows.
//!
//! `--anonymous` is the public reader: no write affordance, every POST refused before any read.

use super::*;
use std::io::Read;
use std::os::fd::FromRawFd;
use std::os::unix::net::{UnixListener, UnixStream};
use std::process::{Command, Stdio};

/// The shell's paths this body runs lines with.
pub(super) struct Shell {
    pub host: PathBuf,
    pub config: PathBuf,
    pub home: PathBuf,
}

pub(super) fn run(mut args: Args, root: PathBuf) -> Result<()> {
    let fd: i32 = args
        .required("listen-fd")?
        .to_str()
        .and_then(|s| s.parse().ok())
        .filter(|fd| *fd >= 3)
        .ok_or("--listen-fd takes an inherited descriptor number (3 or above)")?;
    let anonymous = args.optional("anonymous").is_some();
    let home = absolute(&path(args.required("home")?))?;
    let host = absolute(&path(args.required("host")?))?;
    let config = absolute(&path(args.required("config")?))?;
    args.finish()?;
    let workspace = workspace::load(&root)?;
    let site = Arc::new(Site {
        mutations: Mutex::new(()),
        home: Some(home.clone()),
        subject: workspace::member(&workspace, "subject")?.to_owned(),
        root,
        workspace,
        token: String::new(),
        front: Front { origins: Vec::new(), read_only: anonymous },
        base: String::new(),
        face: Face::Body,
        shell: Some(Shell { host, config, home }),
    });
    let listener = unsafe { UnixListener::from_raw_fd(fd) };
    eprintln!("mini web --body: subject {} serving fd {fd}{}", site.subject, if anonymous { " (anonymous)" } else { "" });
    let handler: Arc<dyn Fn(UnixStream, Instant) + Send + Sync> = Arc::new(move |stream, deadline| {
        if let Err(error) = serve(&site, stream, deadline) {
            eprintln!("mini web --body: {error}");
        }
    });
    let connections = admission::Pool::new(admission::MAX_CONNECTIONS);
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                if let Err(error) = connections.dispatch(stream, handler.clone()) {
                    eprintln!("mini web --body: {error}");
                }
            }
            Err(error) => eprintln!("mini web --body: accept: {error}"),
        }
    }
    Ok(())
}

const ANONYMOUS: &str = "the public reader shows what members published; writing needs your own session (Join, then open the link the door gives you)";

fn serve(site: &Site, mut stream: UnixStream, deadline: Instant) -> Result<()> {
    stream.set_write_timeout(Some(Duration::from_secs(10))).map_err(|e| e.to_string())?;
    let mut head = Vec::new();
    let mut buffer = [0u8; 2048];
    while !head.windows(4).any(|w| w == b"\r\n\r\n") {
        let read = admission::read_ingress(&mut stream, &mut buffer, deadline).map_err(|e| e.to_string())?;
        if read == 0 {
            return Ok(());
        }
        head.extend_from_slice(&buffer[..read]);
        if head.len() > MAX_REQUEST {
            return answer(&mut stream, &simple(431, "Too large", "request head too large"), site);
        }
    }
    let request = match parse_request(&head) {
        Ok(request) => request,
        Err(error) => return answer(&mut stream, &simple(400, "Bad request", &error), site),
    };
    let target = request.target.split(['?', '#']).next().unwrap_or("").to_owned();
    let segments: Vec<String> = target.split('/').filter(|s| !s.is_empty()).map(str::to_owned).collect();
    if segments.iter().any(|s| !s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-')) {
        return answer(&mut stream, &simple(404, "Not found", "no such page"), site);
    }
    let parts: Vec<&str> = segments.iter().map(String::as_str).collect();
    let page = match request.method.as_str() {
        "GET" | "HEAD" => {
            let draft = matches!(parts.as_slice(), ["new-document", ..] | ["doc", _, "edit", ..]);
            if draft && site.front.read_only {
                simple(403, "Read only", ANONYMOUS)
            } else {
                let _mutation = if draft { Some(site.mutations.lock().map_err(|_| "custody lock poisoned")?) } else { None };
                get(site, &parts, &request.target)
            }
        }
        "POST" => {
            if site.front.read_only {
                outcome_page("Refused", "refused", "This body is the public reader", ANONYMOUS, &[])
            } else {
                let length = request
                    .headers
                    .iter()
                    .find(|(k, _)| k == "content-length")
                    .and_then(|(_, v)| v.parse::<usize>().ok())
                    .filter(|n| *n <= editor::MAX_FORM)
                    .ok_or("a form needs one bounded Content-Length")?;
                let end = head.windows(4).position(|w| w == b"\r\n\r\n").unwrap() + 4;
                let mut body = head[end..].to_vec();
                while body.len() < length {
                    let remaining = (length - body.len()).min(buffer.len());
                    let read = admission::read_ingress(&mut stream, &mut buffer[..remaining], deadline).map_err(|e| e.to_string())?;
                    if read == 0 {
                        return answer(&mut stream, &simple(400, "Incomplete", "incomplete form"), site);
                    }
                    body.extend_from_slice(&buffer[..read]);
                }
                body.truncate(length);
                let _mutation = site.mutations.lock().map_err(|_| "custody lock poisoned")?;
                post(site, &parts, &body)
            }
        }
        _ => simple(405, "Method", "GET, HEAD and POST only"),
    };
    answer(&mut stream, &page, site)
}

/// The fragment: the read context line, then the body. The gateway adds the chrome.
fn answer(stream: &mut UnixStream, page: &Page, site: &Site) -> Result<()> {
    let context = match &page.stamp {
        Stamp::Read(read) => format!(
            "<details class=\"ctx\"><summary>Authorized read</summary><p>read as subject <span class=id>{}</span> at height <span class=id data-height=\"{h}\">{h}</span> | authority root {} | cell root {}</p></details>\n",
            escape(&site.subject),
            short(&read.authority_root),
            short(&read.cell_root),
            h = escape(&read.height)
        ),
        Stamp::EditBase(read) => format!("<p class=\"ctx\">Editor base snapshot at height <span class=id>{}</span>; sidebar observations may be newer.</p>\n", escape(&read.height)),
        Stamp::Refused => format!("<p class=\"ctx\">subject <span class=id>{}</span> | the Host refused this page's signed read</p>\n", escape(&site.subject)),
        Stamp::Unavailable => "<p class=\"ctx\">Current text unavailable</p>\n".to_owned(),
        Stamp::CurrentReads(_) | Stamp::None => String::new(),
    };
    let body = format!("{context}{}", page.body);
    let title = page.title.replace(['\r', '\n'], " ");
    let head = format!(
        "HTTP/1.1 {} {}\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nX-Mini-Title: {}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n",
        page.status,
        reason(page.status),
        body.len(),
        title
    );
    stream.write_all(head.as_bytes()).and_then(|_| stream.write_all(body.as_bytes())).map_err(|e| e.to_string())
}

// ---------------------------------------------------------------- GET

fn get(site: &Site, parts: &[&str], target: &str) -> Page {
    match parts {
        [] | ["doc"] => {
            let mut page = site.index();
            if !site.front.read_only {
                page.body.push_str(
                    "<section><h2>New document</h2><form method=\"post\" action=\"/doc/new\" class=\"row\"><div><label for=\"dn\">Name</label><input id=\"dn\" name=\"name\" type=\"text\" required pattern=\"[A-Za-z0-9-]+\"></div>\
                     <div><label for=\"dl\">Law</label><select id=\"dl\" name=\"law\"><option>note</option><option>draft</option><option>index</option></select></div>\
                     <div><label for=\"dr\">In room (optional)</label><input id=\"dr\" name=\"room\" type=\"text\" pattern=\"[A-Za-z0-9/-]*\"></div><button>Create</button></form></section>\n",
                );
            }
            page
        }
        ["board"] | ["room"] => place_index(site, parts[0]),
        ["search"] => search::page(site, target),
        ["purse"] => purse(site),
        ["verb"] => verbs::index(site),
        ["verb", name] => verbs::page(site, name),
        ["receipts"] => receipts(site),
        ["receipts", "lookup"] => match query(target, "id") {
            Some(id) => receipt(site, &id),
            None => simple(400, "Receipts", "give an attempt id"),
        },
        ["receipts", id] => receipt(site, id),
        ["grants"] => grants(site),
        ["laws"] => laws(site),
        ["keys"] => keys(site),
        ["room", name] => room(site, name),
        ["room", name, "resident"] => {
            let mut page = resident::page(site, name);
            if !site.front.read_only {
                page.body.push_str(&summon_form(name));
            }
            page
        }
        ["laws", "show"] => match query(target, "ref") {
            Some(name) => match verb(site, &[format!("law show {}", quote(&name))]) {
                Some(ending) => Page { status: 200, title: format!("Law on {name}"), stamp: Stamp::None, body: outcome(&ending, &[("laws", "/laws")]) },
                None => simple(500, "Laws", "this body has no shell paths"),
            },
            None => simple(400, "Laws", "give a reference"),
        },
        ["doc", name] if !site.front.read_only => {
            let mut page = site.route(&["doc".to_owned(), name.to_string()]);
            if page.status == 200 {
                page.body.push_str(&append_form(name));
            }
            page
        }
        ["board", name] if !site.front.read_only => {
            let mut page = site.route(&["board".to_owned(), name.to_string()]);
            if page.status == 200 {
                page.body.push_str(&board_forms(name));
            }
            page
        }
        ["apps", ..] | ["studio", ..] | ["stream", ..] => simple(404, "Not here", "this page is the gateway's, or not a page"),
        _ => site.route(&parts.iter().map(|s| s.to_string()).collect::<Vec<_>>()),
    }
}

/// `/board` and `/room`: the workspace's references, each opened as that place.
fn place_index(site: &Site, place: &str) -> Page {
    let mut rows = String::new();
    for name in site.names() {
        rows.push_str(&format!("<li><a href=\"/{place}/{n}\">{n}</a></li>\n", n = escape(&name)));
    }
    let (title, note) = match place {
        "board" => ("Boards", "A reference read with the board layout: task n's state is field 2n+2, its owner field 2n+3."),
        _ => ("Rooms", "A reference read as a room: its members (the Host's `who` view), the names bound in it, its streams."),
    };
    Page { status: 200, title: title.into(), stamp: Stamp::None, body: format!("<p class=note>{note}</p>\n<ul>{rows}</ul>{}", if place == "room" && !site.front.read_only { room_new_form() } else { String::new() }) }
}

fn room(site: &Site, name: &str) -> Page {
    let mut page = site.route(&["room".to_owned(), name.to_owned()]);
    if page.status != 200 {
        return page;
    }
    // The room's streams as chat: the shell's own `tail`, read as this member.
    if let Some(ending) = verb(site, &[format!("tail -n 40 --in {}", quote(name))]) {
        page.body.push_str("<section class=\"chat\" data-live=\"5000\"><h2>Chat</h2>\n");
        if ending.code == 0 {
            page.body.push_str(&format!("<pre class=\"turns\">{}</pre>\n", escape(ending.text().trim())));
        } else {
            page.body.push_str(&outcome(&ending, &[]));
        }
        if !site.front.read_only {
            page.body.push_str(&format!(
                "<form method=\"post\" action=\"/room/{n}/say\" class=\"row\"><label for=\"say-{n}\">Say</label><input id=\"say-{n}\" type=\"text\" name=\"text\" maxlength=\"2000\" required autocomplete=\"off\"><button>Send</button></form>\n",
                n = escape(name)
            ));
        }
        page.body.push_str("</section>\n");
    }
    page
}

fn receipts(site: &Site) -> Page {
    let mut body = String::from(
        "<p>Every retained attempt of this workspace with its last Host outcome, as <code>history all</code> prints it. \
         Open an attempt to see the Host's receipt and refusal frame, ask again (<code>lookup</code>) or retry an undecided one (<code>retry</code>: exact, never a second write).</p>\n",
    );
    match verb(site, &["history all".to_owned()]) {
        Some(ending) if ending.code == 0 => {
            let text = ending.text();
            let mut rows = String::new();
            for line in text.lines() {
                let id = line.split_whitespace().next().unwrap_or("");
                if id.len() > 1 && id.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-') {
                    rows.push_str(&format!("<tr><td><a href=\"/receipts/{id}\">{id}</a></td><td>{}</td></tr>\n", escape(line[id.len()..].trim())));
                }
            }
            if rows.is_empty() {
                body.push_str(&format!("<pre>{}</pre>", escape(text.trim())));
            } else {
                body.push_str(&format!("<table><thead><tr><th>attempt</th><th>outcome</th></tr></thead><tbody>{rows}</tbody></table>"));
            }
        }
        Some(ending) => body.push_str(&outcome(&ending, &[])),
        None => body.push_str("<p class=note>no shell paths: receipts are shown through the shell</p>"),
    }
    body.push_str("<form method=\"get\" action=\"/receipts/lookup\" class=\"row\"><label for=\"rid\">Attempt id</label><input id=\"rid\" type=\"text\" name=\"id\" pattern=\"[A-Za-z0-9-]+\" required><button>Open</button></form>");
    Page { status: 200, title: "Receipts".into(), stamp: Stamp::None, body }
}

fn receipt(site: &Site, id: &str) -> Page {
    if workspace_id(id).is_err() {
        return simple(404, "Receipts", "not an attempt id");
    }
    let mut body = String::new();
    for (heading, line) in [("Outcome", format!("lookup {id}")), ("Receipt", format!("inspect receipt {id}")), ("Why", format!("why {id}"))] {
        if let Some(ending) = verb(site, &[line]) {
            body.push_str(&format!("<section><h2>{heading}</h2>{}</section>\n", outcome(&ending, &[])));
        }
    }
    if !site.front.read_only {
        body.push_str(&format!(
            "<p class=\"next\"><form method=\"post\" action=\"/receipts/{id}/retry\" class=\"inline\"><button class=\"quiet\">retry {id}</button></form> \
             <form method=\"post\" action=\"/receipts/{id}/lookup\" class=\"inline\"><button class=\"quiet\">lookup {id}</button></form> \
             <form method=\"post\" action=\"/receipts/{id}/publish\" class=\"inline\"><button class=\"quiet\">publish {id}</button></form></p>\n"
        ));
    }
    Page { status: 200, title: format!("Attempt {id}"), stamp: Stamp::None, body }
}

fn grants(site: &Site) -> Page {
    let mut body = String::from("<p>The grants you hold, as the Host's capability view names them (capability, scope, expiry, ancestors), drawn as a tree; then what they cover, verb by verb, prepared and dry-run against the Host (<code>can --all</code>; nothing is submitted).</p>\n");
    if let Some(ending) = verb(site, &["inspect caps --json".to_owned()]) {
        match serde_json::from_str::<Value>(ending.stdout.trim()) {
            Ok(view) if ending.code == 0 => body.push_str(&format!("<section class=\"grants\"><h2>Capability tree</h2>{}</section>\n", json_tree(&view))),
            _ => body.push_str(&outcome(&ending, &[])),
        }
    }
    if let Some(ending) = verb(site, &["can --all".to_owned()]) {
        body.push_str(&format!("<section><h2>What they cover</h2>{}</section>\n", outcome(&ending, &[])));
    }
    if !site.front.read_only {
        body.push_str(
            "<section><h2>Delegate</h2><p class=note>Delegate verbs on one of your references to another subject, with a cost ceiling; the proposal is submitted at once, and <code>publish</code> hands the recipient their reference.</p>\
             <form method=\"post\" action=\"/grants/delegate\" class=\"row\">\
             <div><label for=\"d-ref\">Reference</label><input id=\"d-ref\" name=\"ref\" type=\"text\" required pattern=\"[A-Za-z0-9/-]+\"></div>\
             <div><label for=\"d-to\">Recipient subject</label><input id=\"d-to\" name=\"recipient\" type=\"text\" required pattern=\"[0-9a-z-]+\"></div>\
             <div><label for=\"d-verbs\">Verbs (comma-separated)</label><input id=\"d-verbs\" name=\"verbs\" type=\"text\" required pattern=\"[a-z,-]+\" value=\"observe\"></div>\
             <div><label for=\"d-max\">Max cost</label><input id=\"d-max\" name=\"max\" type=\"text\" required pattern=\"[0-9]+\" value=\"0\"></div>\
             <button>Delegate</button></form></section>\n\
             <section><h2>Revoke</h2><form method=\"post\" action=\"/grants/revoke\" class=\"row\">\
             <div><label for=\"r-ref\">Reference</label><input id=\"r-ref\" name=\"ref\" type=\"text\" required pattern=\"[A-Za-z0-9/-]+\"></div>\
             <div><label for=\"r-to\">Recipient subject</label><input id=\"r-to\" name=\"recipient\" type=\"text\" required pattern=\"[0-9a-z-]+\"></div>\
             <button>Revoke</button></form></section>\n",
        );
    }
    Page { status: 200, title: "Grants".into(), stamp: Stamp::None, body }
}

fn laws(site: &Site) -> Page {
    let mut body = String::from(
        "<p>The law on a reference, as the Host holds it (<code>law show REF</code>); install a law with clauses (<code>law ID REF \"CLAUSE; …\"</code>). The Host first asks whether the law can ever pass.</p>\
         <form method=\"get\" action=\"/laws/show\" class=\"row\"><label for=\"l-ref\">Reference</label><input id=\"l-ref\" name=\"ref\" type=\"text\" required pattern=\"[A-Za-z0-9/-]+\"><button>Show</button></form>\n",
    );
    if !site.front.read_only {
        body.push_str(
            "<section><h2>Install a law</h2><form method=\"post\" action=\"/laws/install\">\
             <label for=\"li-ref\">Reference</label><input id=\"li-ref\" name=\"ref\" type=\"text\" required pattern=\"[A-Za-z0-9/-]+\">\
             <label for=\"li-clauses\">Clauses (semicolon-separated), or the predicate JSON</label><textarea id=\"li-clauses\" name=\"clauses\" required maxlength=\"4000\"></textarea>\
             <p><button>Install</button></p></form></section>\n",
        );
    }
    let _ = site;
    Page { status: 200, title: "Laws".into(), stamp: Stamp::None, body }
}

fn keys(site: &Site) -> Page {
    let mut body = String::from(
        "<p>Your signing key is <strong>hosted</strong>: it lives in your account's home on this box (readable by the operator, by your own account, and by no other member), and everything on this box is world-readable. \
         The browser never holds it; this session is a cookie that names your account.</p>\n",
    );
    for (heading, line) in [("Who am I", "whoami"), ("Key status", "key-status")] {
        if let Some(ending) = verb(site, &[line.to_owned()]) {
            body.push_str(&format!("<section><h2>{heading}</h2>{}</section>\n", outcome(&ending, &[])));
        }
    }
    body.push_str("<p><a href=\"/sessions\">Your browser sessions</a> (list and revoke) · <a href=\"/term\">Terminal</a> for <code>rotate-key</code> and <code>adopt-next-key</code>, which take the next key's file.</p>");
    Page { status: 200, title: "Keys".into(), stamp: Stamp::None, body }
}

fn append_form(name: &str) -> String {
    format!(
        "<section><h2>Append</h2><form method=\"post\" action=\"/doc/{n}/append\">\
         <label for=\"ap-{n}\">Text to append (one proposal, submitted at once)</label><textarea id=\"ap-{n}\" name=\"text\" required maxlength=\"4096\"></textarea>\
         <p><button>Append</button> <a href=\"/doc/{n}/edit\">Edit and inspect</a></p></form></section>\n\
         <section><h2>Link</h2><form method=\"post\" action=\"/doc/{n}/link\" class=\"row\">\
         <div><label for=\"lk-{n}\">To (a reference)</label><input id=\"lk-{n}\" name=\"to\" type=\"text\" required pattern=\"[A-Za-z0-9/-]+\"></div>\
         <div><label for=\"lr-{n}\">Relation</label><input id=\"lr-{n}\" name=\"relation\" type=\"text\" pattern=\"[A-Za-z0-9-]*\" value=\"\"></div>\
         <button>Link</button></form></section>\n",
        n = escape(name)
    )
}

fn board_forms(name: &str) -> String {
    let n = escape(name);
    format!(
        "<section><h2>Act</h2>\
         <form method=\"post\" action=\"/board/{n}/add\" class=\"row\"><div><label for=\"ba-{n}\">Add task</label><input id=\"ba-{n}\" name=\"task\" type=\"text\" required pattern=\"[0-9]+\"></div><button>Add</button></form>\
         <form method=\"post\" action=\"/board/{n}/move\" class=\"row\"><div><label for=\"bm-{n}\">Move task</label><input id=\"bm-{n}\" name=\"task\" type=\"text\" required pattern=\"[0-9]+\"></div>\
         <div><label for=\"bf-{n}\">from</label><input id=\"bf-{n}\" name=\"from\" type=\"text\" required pattern=\"[A-Za-z0-9-]+\"></div><div><label for=\"bt-{n}\">to</label><input id=\"bt-{n}\" name=\"to\" type=\"text\" required pattern=\"[A-Za-z0-9-]+\"></div><button>Move</button></form>\
         <form method=\"post\" action=\"/board/{n}/take\" class=\"row\"><div><label for=\"bk-{n}\">Take task</label><input id=\"bk-{n}\" name=\"task\" type=\"text\" required pattern=\"[0-9]+\"></div><button>Take</button></form></section>\n"
    )
}

fn summon_form(name: &str) -> String {
    format!(
        "<section><h2>Summon a resident</h2><p class=note>Founder only: a Hermes resident joins the room in a role, with a budget funded from your account.</p>\
         <form method=\"post\" action=\"/room/{n}/summon\" class=\"row\"><div><label for=\"sr-{n}\">Role</label><select id=\"sr-{n}\" name=\"role\"><option>librarian</option><option>runner</option></select></div>\
         <div><label for=\"sb-{n}\">Budget</label><input id=\"sb-{n}\" name=\"budget\" type=\"text\" pattern=\"[0-9]+\" value=\"100\"></div><button>Summon</button></form></section>\n",
        n = escape(name)
    )
}

fn room_new_form() -> String {
    "<section><h2>New room</h2><form method=\"post\" action=\"/room/new\" class=\"row\"><div><label for=\"rn\">Name</label><input id=\"rn\" name=\"name\" type=\"text\" required pattern=\"[A-Za-z0-9-]+\"></div>\
     <div><label for=\"rl\">Law</label><select id=\"rl\" name=\"law\"><option>open</option><option>realm</option></select></div><button>Create</button></form></section>\n".to_owned()
}

// ---------------------------------------------------------------- POST

fn post(site: &Site, parts: &[&str], body: &[u8]) -> Page {
    let form = match editor::form(body) {
        Ok(form) => form,
        Err(e) => return simple(400, "Form", &e),
    };
    let field = |key: &str| form.get(key).map(String::as_str).unwrap_or("").trim().to_owned();
    match parts {
        // The editor and creation forms keep their own pinned-diff path.
        ["doc", name, "edit", id] => editor::post(site, name, id, body, false),
        ["doc", name, "edit", id, "lookup"] => editor::post(site, name, id, body, true),
        ["doc", name, "edit", id, "action"] => editor::action(site, name, id, body),
        ["new-document", id] => create::post(site, id, body, "create"),
        ["new-document", id, op] => create::post(site, id, body, op),
        ["verb", name] => verbs::post(site, name, &form),
        ["doc", "new"] => {
            let name = field("name");
            let room = field("room");
            let mut line = format!("doc new {} {}", quote(&name), quote(&field("law")));
            if !room.is_empty() {
                line.push_str(&format!(" --in {}", quote(&room)));
            }
            act(site, &format!("New document {name}"), vec![line], "", &[("the document", &format!("/doc/{name}")), ("documents", "/doc")])
        }
        ["doc", name, "append"] => {
            let id = fresh_id();
            let Some(file) = text_file(site, &id, &field("text")) else { return simple(400, "Append", "text must be 1..4096 bytes") };
            act(site, &format!("Append to {name}"), vec![format!("doc append {id} {} @{file}", quote(name)), format!("submit {id}")], &id, &[("the document", &format!("/doc/{name}"))])
        }
        ["doc", name, "link"] => {
            let id = fresh_id();
            let relation = field("relation");
            let mut line = format!("doc link {id} {} {}", quote(name), quote(&field("to")));
            if !relation.is_empty() {
                line.push_str(&format!(" {}", quote(&relation)));
            }
            act(site, &format!("Link from {name}"), vec![line, format!("submit {id}")], &id, &[("the document", &format!("/doc/{name}"))])
        }
        ["board", name, op @ ("add" | "move" | "take")] => {
            let id = fresh_id();
            let line = match *op {
                "add" => format!("board add {id} {} {}", quote(name), quote(&field("task"))),
                "move" => format!("board move {id} {} {} {} {}", quote(name), quote(&field("task")), quote(&field("from")), quote(&field("to"))),
                _ => format!("board take {id} {} {}", quote(name), quote(&field("task"))),
            };
            act(site, &format!("Board {name}: {op}"), vec![line, format!("submit {id}")], &id, &[("the board", &format!("/board/{name}"))])
        }
        ["room", "new"] => {
            let name = field("name");
            act(site, &format!("Room {name}"), vec![format!("room new {} --law {}", quote(&name), quote(&field("law")))], "", &[("rooms", "/room")])
        }
        ["room", name, "say"] => act(site, &format!("Say in {name}"), vec![format!("say --in {} {}", quote(name), quote(&field("text")))], "", &[("the room", &format!("/room/{name}"))]),
        ["room", name, "summon"] => {
            let budget = field("budget");
            let mut line = format!("summon {} as {}", quote(name), quote(&field("role")));
            if !budget.is_empty() {
                line.push_str(&format!(" --budget {}", quote(&budget)));
            }
            act(site, &format!("Summon into {name}"), vec![line], "", &[("the resident", &format!("/room/{name}/resident"))])
        }
        ["receipts", id, op @ ("retry" | "lookup" | "publish")] => match workspace_id(id) {
            Ok(()) => act(site, &format!("{op} {id}"), vec![format!("{op} {id}")], id, &[("the attempt", &format!("/receipts/{id}"))]),
            Err(e) => simple(400, "Receipts", &e),
        },
        ["grants", "delegate"] => {
            let id = fresh_id();
            act(
                site,
                "Delegate",
                vec![format!("delegate {id} {} {} {} {}", quote(&field("ref")), quote(&field("recipient")), quote(&field("verbs")), quote(&field("max"))), format!("submit {id}")],
                &id,
                &[("publish it to the recipient", &format!("/receipts/{id}")), ("grants", "/grants")],
            )
        }
        ["grants", "revoke"] => {
            let id = fresh_id();
            act(site, "Revoke", vec![format!("revoke {id} {} {}", quote(&field("ref")), quote(&field("recipient"))), format!("submit {id}")], &id, &[("grants", "/grants")])
        }
        ["laws", "install"] => {
            let id = fresh_id();
            let clauses = field("clauses");
            let Some(file) = text_file(site, &id, &clauses) else { return simple(400, "Laws", "clauses must be 1..4096 bytes") };
            act(site, "Install a law", vec![format!("law {id} {} @{file}", quote(&field("ref"))), format!("submit {id}")], &id, &[("laws", "/laws")])
        }
        _ => simple(405, "Cannot act", "this address accepts reads only"),
    }
}

/// Run the lines as this member and render the ending.
pub(super) fn act(site: &Site, title: &str, lines: Vec<String>, id: &str, next: &[(&str, &str)]) -> Page {
    let Some(ending) = verb(site, &lines) else {
        return simple(500, title, "this body has no shell paths");
    };
    let mut links: Vec<(String, String)> = next.iter().map(|(a, b)| (a.to_string(), b.to_string())).collect();
    if !id.is_empty() {
        links.push(("the receipt".into(), format!("/receipts/{id}")));
    }
    let refs: Vec<(&str, &str)> = links.iter().map(|(a, b)| (a.as_str(), b.as_str())).collect();
    let status = match ending.code { 0 => 200, 3 => 403, 4 => 202, _ => 400 };
    Page { status, title: title.to_owned(), stamp: Stamp::None, body: format!("<p class=note><code>{}</code></p>\n{}", escape(&lines.join("\n")), outcome(&ending, &refs)) }
}

// ---------------------------------------------------------------- the shell as the runner

pub(super) struct Ending {
    pub code: i32,
    pub stdout: String,
    pub stderr: String,
}

impl Ending {
    fn text(&self) -> String {
        let mut text = self.stdout.clone();
        if !self.stderr.trim().is_empty() {
            if !text.is_empty() && !text.ends_with('\n') {
                text.push('\n');
            }
            text.push_str(&self.stderr);
        }
        text
    }

    /// The class and the headline the one partial shows (shell.rs: 0 ok, 1 client error,
    /// 2 usage, 3 refused, 4 undecided).
    fn class(&self) -> (&'static str, String) {
        let first = self.stderr.lines().find(|l| !l.trim().is_empty()).unwrap_or("").to_owned();
        match self.code {
            0 => ("admitted", "Admitted".into()),
            3 => ("refused", if first.is_empty() { "Refused".into() } else { first }),
            4 => ("undecided", if first.is_empty() { "Undecided: the attempt is retained".into() } else { first }),
            2 => ("refused", if first.is_empty() { "Usage".into() } else { first }),
            _ => ("refused", if first.is_empty() { "The client could not complete this".into() } else { first }),
        }
    }
}

/// Run shell lines as this member: `mini shell` in script mode (one line per form action, or the
/// proposal and its `submit`), the same binary and subcommand the ssh login runs.
pub(super) fn verb(site: &Site, lines: &[String]) -> Option<Ending> {
    let shell = site.shell.as_ref()?;
    let exe = std::env::current_exe().ok()?;
    let script = lines.iter().map(|l| format!("{l}\n")).collect::<String>();
    if script.bytes().any(|b| b.is_ascii_control() && b != b'\n') {
        return Some(Ending { code: 2, stdout: String::new(), stderr: "usage: a form field contains a control character\n".into() });
    }
    let mut command = Command::new(exe);
    command.arg("shell");
    // The deployment's socket, as the ssh wrapper passes it; a workspace that pins one takes it from the pin.
    if let Some(socket) = super::super::SOCKET.get() {
        command.arg("--socket").arg(socket);
    }
    let mut child = command
        .arg("--workspace").arg(&site.root)
        .arg("--home").arg(&shell.home)
        .arg("--host").arg(&shell.host)
        .arg("--config").arg(&shell.config)
        .env_clear()
        .env("PATH", "/usr/bin:/bin")
        .env("HOME", &shell.home)
        .stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::piped())
        .spawn()
        .ok()?;
    if let Some(mut stdin) = child.stdin.take() {
        let _ = stdin.write_all(script.as_bytes());
    }
    let mut out = child.stdout.take()?;
    let mut err = child.stderr.take()?;
    let reader = std::thread::spawn(move || {
        let mut s = Vec::new();
        let _ = out.read_to_end(&mut s);
        s
    });
    let mut stderr = Vec::new();
    let _ = err.read_to_end(&mut stderr);
    let deadline = Instant::now() + Duration::from_secs(120);
    let status = loop {
        match child.try_wait() {
            Ok(Some(status)) => break Some(status),
            Ok(None) if Instant::now() < deadline => std::thread::sleep(Duration::from_millis(25)),
            _ => {
                let _ = child.kill();
                let _ = child.wait();
                break None;
            }
        }
    };
    let stdout = reader.join().unwrap_or_default();
    let cap = |v: Vec<u8>| {
        let mut s = String::from_utf8_lossy(&v).into_owned();
        if s.len() > 64 * 1024 {
            s.truncate(64 * 1024);
            s.push_str("\n…");
        }
        s
    };
    Some(match status {
        Some(status) => Ending { code: status.code().unwrap_or(1), stdout: cap(stdout), stderr: cap(stderr) },
        None => Ending { code: 4, stdout: cap(stdout), stderr: "undecided: the shell did not finish within 120 s; the attempt, if any, is retained under Receipts\n".into() },
    })
}

/// The one outcome partial (the gateway's CSS: `.outcome.admitted|refused|undecided`).
fn outcome(ending: &Ending, next: &[(&str, &str)]) -> String {
    let (class, headline) = ending.class();
    let mut links = String::new();
    for (label, href) in next {
        links.push_str(&format!("<a href=\"{}\">{}</a> ", escape(href), escape(label)));
    }
    if class == "undecided" {
        if let Some(id) = ending.stderr.split("lookup ").nth(1).and_then(|r| r.split(|c: char| !(c.is_ascii_alphanumeric() || c == '-')).next()).filter(|s| !s.is_empty()) {
            links.push_str(&format!("<a href=\"/receipts/{id}\">the retained attempt {id}</a> "));
        }
    }
    let detail = ending.text();
    format!(
        "<div class=\"outcome {class}\"><p class=\"headline\">{}</p>{}{}</div>\n",
        headline_html(&headline),
        if detail.trim().is_empty() { String::new() } else { format!("<pre>{}</pre>", escape(detail.trim())) },
        if links.is_empty() { String::new() } else { format!("<p class=\"next\">{links}</p>") }
    )
}

/// A refusal is the clause, highlighted: `refused: law-denied: field 2 monotone (before 2, after 1)`
/// shows its kind and marks the clause the Host named.
fn headline_html(headline: &str) -> String {
    if let Some(rest) = headline.strip_prefix("refused: ") {
        if let Some((kind, clause)) = rest.split_once(": ") {
            return format!("refused: <span class=\"reason\">{}</span>: <mark class=\"clause\">{}</mark>", escape(kind), escape(clause));
        }
        return format!("refused: <mark class=\"clause\">{}</mark>", escape(rest));
    }
    escape(headline)
}

/// A JSON view drawn as a tree (the grants: capability, scope, expiry, ancestors as the Host's
/// `cap-tree` view names them), without a hand-written schema.
fn json_tree(v: &Value) -> String {
    match v {
        Value::Object(map) => {
            let mut out = String::from("<ul class=\"tree\">");
            for (k, v) in map {
                out.push_str(&format!("<li><span class=\"key\">{}</span> {}</li>", escape(k), json_tree(v)));
            }
            out + "</ul>"
        }
        Value::Array(items) => {
            let mut out = String::from("<ol class=\"tree\">");
            for v in items {
                out.push_str(&format!("<li>{}</li>", json_tree(v)));
            }
            out + "</ol>"
        }
        Value::String(s) if s.len() > 40 && s.bytes().all(|b| b.is_ascii_hexdigit()) => format!("<code class=\"id\" title=\"{}\">{}…</code>", escape(s), escape(&s[..16])),
        Value::String(s) => format!("<span class=\"val\">{}</span>", escape(s)),
        other => format!("<span class=\"val\">{}</span>", escape(&other.to_string())),
    }
}

/// `/purse`: the member's account as a meter (`credit`), then `pay status`.
fn purse(site: &Site) -> Page {
    let mut body = String::new();
    match verb(site, &["credit".to_owned()]) {
        Some(ending) if ending.code == 0 => {
            let line = ending.stdout.lines().find(|l| l.starts_with("credit ")).unwrap_or("").to_owned();
            let balance: u64 = line.split_whitespace().nth(1).and_then(|n| n.parse().ok()).unwrap_or(0);
            let scale = balance.max(1000);
            body.push_str(&format!(
                "<section class=\"purse\"><p class=\"big\"><span class=\"n\">{balance}</span> credits</p>\
                 <meter min=\"0\" max=\"{scale}\" low=\"{}\" value=\"{balance}\">{balance}</meter>\
                 <p class=\"note\">{}</p></section>\n",
                scale / 10,
                escape(&line)
            ));
        }
        Some(ending) => body.push_str(&outcome(&ending, &[])),
        None => body.push_str("<p class=note>no shell paths</p>"),
    }
    if let Some(ending) = verb(site, &["pay status".to_owned()]) {
        body.push_str(&format!("<section><h2>Pay</h2>{}</section>", outcome(&ending, &[("pay", "/verb/pay"), ("topup", "/verb/topup"), ("tariff", "/verb/tariff")])));
    }
    Page { status: 200, title: "Purse".into(), stamp: Stamp::None, body }
}

fn outcome_page(title: &str, class: &str, headline: &str, detail: &str, next: &[(&str, &str)]) -> Page {
    let mut links = String::new();
    for (label, href) in next {
        links.push_str(&format!("<a href=\"{}\">{}</a> ", escape(href), escape(label)));
    }
    Page {
        status: if class == "refused" { 403 } else { 200 },
        title: title.to_owned(),
        stamp: Stamp::None,
        body: format!("<div class=\"outcome {class}\"><p class=\"headline\">{}</p><pre>{}</pre>{}</div>\n", escape(headline), escape(detail), if links.is_empty() { String::new() } else { format!("<p class=\"next\">{links}</p>") }),
    }
}

/// One query value of the request target, form-decoded.
fn query(target: &str, key: &str) -> Option<String> {
    let query = target.split_once('?')?.1.split('#').next()?;
    let pairs = editor::form(query.as_bytes()).ok()?;
    pairs.get(key).map(|v| v.trim().to_owned()).filter(|v| !v.is_empty())
}

/// A fresh proposal id: `w-` and 12 hex digits (the shell's `workspace_name` rule).
pub(super) fn fresh_id() -> String {
    format!("w-{}", crate::fsio::random::<6>().map(|b| hex(&b)).unwrap_or_else(|_| "000000000000".into()))
}

fn workspace_id(id: &str) -> std::result::Result<(), String> {
    if id.is_empty() || id.len() > 64 || !id.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-') {
        return Err("an attempt id is 1..64 letters, digits or hyphens".into());
    }
    Ok(())
}

/// TEXT arguments go through `@FILE` in HOME/requests, so a form's text can hold spaces, quotes
/// and newlines without touching the line syntax.
pub(super) fn text_file(site: &Site, id: &str, text: &str) -> Option<String> {
    if text.is_empty() || text.len() > 4096 {
        return None;
    }
    let shell = site.shell.as_ref()?;
    let dir = shell.home.join("requests");
    crate::fsio::ensure_private_dir(&dir).ok()?;
    let file = format!("web-{id}.txt");
    fs::write(dir.join(&file), text).ok()?;
    Some(file)
}

/// One word of the shell's line syntax (`shell::words`): bare when every byte is plain, else
/// double-quoted with `\` and `"` escaped.
pub(super) fn quote(word: &str) -> String {
    if !word.is_empty() && word.bytes().all(|b| b.is_ascii_alphanumeric() || b"-_./:@,=+".contains(&b)) {
        return word.to_owned();
    }
    let mut out = String::from("\"");
    for c in word.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quoting_round_trips_through_the_shell_word_syntax() {
        for word in ["plain", "lab/index", "has space", "a \"quote\"", "back\\slash", "", "{json: no}", "it's"] {
            let line = format!("say {}", quote(word));
            let words = crate::shell::words(&line).unwrap();
            assert_eq!(words, vec!["say".to_owned(), word.to_owned()], "{line}");
        }
    }

    #[test]
    fn endings_classify_by_exit_code_and_first_stderr_line() {
        let refused = Ending { code: 3, stdout: String::new(), stderr: "refused: law-denied: field 2 monotone\n  outcome: x\n".into() };
        assert_eq!(refused.class(), ("refused", "refused: law-denied: field 2 monotone".into()));
        let undecided = Ending { code: 4, stdout: String::new(), stderr: "undecided: Host outcome uncertain; the attempt is retained, `lookup w-1` asks again\n".into() };
        assert_eq!(undecided.class().0, "undecided");
        let html = outcome(&undecided, &[]);
        assert!(html.contains("outcome undecided") && html.contains("/receipts/w-1"), "{html}");
        let ok = Ending { code: 0, stdout: "admitted at 12\n".into(), stderr: String::new() };
        assert!(outcome(&ok, &[("the doc", "/doc/a")]).contains("outcome admitted"));
        assert!(fresh_id().starts_with("w-") && fresh_id().len() == 14);
        assert!(workspace_id("w-1").is_ok() && workspace_id("../x").is_err());
    }
}
