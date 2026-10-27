//! `mini apps`: the app market (docs/APP-MARKET-2026-10-27.md).
//!
//! The catalogue is a cached copy of the Sandstorm app index that `mini-market`
//! refreshes (`deploy/market/mini-market-fetch`); it is data, never
//! instructions. Identity comes from the signed package (the appId is the
//! signing key's hash, the packageId the first 16 bytes of the SPK's SHA-256),
//! so the catalogue shows the index's claims beside Mini's own verdict, written
//! by the worker's real ingest, and never calls a package verified by itself.
//!
//! The lifecycle verbs talk to the worker over its authenticated Unix socket
//! (`SO_PEERCRED` names the member); every reply is a decoded outcome: decided
//! or undecided with its exact retry, never a spinner that lies.

#[path = "apps_front.rs"]
pub(crate) mod front;

use crate::{absolute, hex, path, Args, Result};
use serde_json::{json, Map, Value};
use std::collections::BTreeMap;
use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::path::{Path, PathBuf};

pub(crate) const DEFAULT_INDEX: &str = "/var/lib/mini-market/index.json";
pub(crate) const DEFAULT_META: &str = "/var/lib/mini-market/meta";
pub(crate) const DEFAULT_VERDICTS: &str = "/var/lib/mini-apps/verdicts";
pub(crate) const DEFAULT_WORKER_SOCKET: &str = "/run/mini-apps/worker.sock";
pub(crate) const INDEX_URL: &str = "https://app-index.sandstorm.io/apps/index.json";
pub(crate) const PACKAGE_URL: &str = "https://app-index.sandstorm.io/packages/";
pub(crate) const WORKER_PROTOCOL: &str = "mini-apps-worker-v1";
/// The index is 67 KiB today; a 4 MiB bound leaves room and refuses a flood.
const MAX_INDEX: usize = 4 * 1024 * 1024;
const MAX_REPLY: usize = 64 * 1024;
/// The standard import profile's raw bound (`spk-package-stream` `standard-v1`).
pub(crate) const STANDARD_RAW_BYTES: u64 = 256 * 1024 * 1024;
const MAX_TEXT: usize = 512;
const WORKER_VERBS: &[&str] = &[
    "list", "status", "install", "retry", "open", "stop", "start", "share", "export", "delete",
];

/// One catalogue entry: the index's claims about one app, bounded and typed.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Entry {
    pub app_id: String,
    pub package_id: String,
    pub name: String,
    pub version: String,
    pub version_number: u64,
    pub author: String,
    pub upstream_author: String,
    pub short_description: String,
    pub categories: Vec<String>,
    pub web_link: String,
    pub code_link: String,
    pub created_at: String,
    pub open_source: bool,
}

/// A Sandstorm appId: 52 base32 digits (`sandstorm_package::spk::base32`).
pub(crate) fn valid_app_id(text: &str) -> bool {
    text.len() == 52 && text.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit())
}

/// A packageId: the first 16 bytes of the SPK's SHA-256, lowercase hex.
pub(crate) fn valid_package_id(text: &str) -> bool {
    text.len() == 32 && text.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f'))
}

fn bounded_text(value: &Value, key: &str, required: bool) -> Result<String> {
    match value.get(key) {
        None | Some(Value::Null) if !required => Ok(String::new()),
        // The index's own data has trailing newlines in versions: whitespace is
        // trimmed; any other control byte refuses the entry.
        Some(Value::String(text)) if text.len() <= MAX_TEXT && !text.trim().bytes().any(|b| b < 0x20) => {
            Ok(text.trim().to_owned())
        }
        Some(Value::String(_)) => Err(format!("index entry {key} is over {MAX_TEXT} bytes or holds control bytes")),
        _ => Err(format!("index entry lacks {key}")),
    }
}

fn parse_entry(value: &Value) -> Result<Entry> {
    let app_id = bounded_text(value, "appId", true)?;
    if !valid_app_id(&app_id) {
        return Err(format!("index appId {app_id:?} is not 52 base32 digits"));
    }
    let package_id = bounded_text(value, "packageId", true)?;
    if !valid_package_id(&package_id) {
        return Err(format!("index packageId {package_id:?} is not 32 lowercase hex digits"));
    }
    let name = bounded_text(value, "name", true)?;
    if name.is_empty() {
        return Err("index entry has an empty name".into());
    }
    let version_number = match value.get("versionNumber") {
        Some(Value::Number(n)) => n.as_u64().ok_or("index versionNumber is not a natural")?,
        _ => return Err("index entry lacks versionNumber".into()),
    };
    let author = match value.get("author") {
        Some(Value::Object(author)) => bounded_text(&Value::Object(author.clone()), "name", false)?,
        _ => String::new(),
    };
    let mut categories = Vec::new();
    if let Some(Value::Array(list)) = value.get("categories") {
        if list.len() > 16 {
            return Err("index entry names over 16 categories".into());
        }
        for item in list {
            match item {
                Value::String(text) if text.len() <= 64 => categories.push(text.clone()),
                _ => return Err("index category is not a short string".into()),
            }
        }
    }
    Ok(Entry {
        app_id,
        package_id,
        name,
        version: bounded_text(value, "version", false)?,
        version_number,
        author,
        upstream_author: bounded_text(value, "upstreamAuthor", false)?,
        short_description: bounded_text(value, "shortDescription", false)?,
        categories,
        web_link: bounded_text(value, "webLink", false)?,
        code_link: bounded_text(value, "codeLink", false)?,
        created_at: bounded_text(value, "createdAt", false)?,
        open_source: value.get("isOpenSource").and_then(Value::as_bool).unwrap_or(false),
    })
}

/// The index as the market serves it: `{"apps":[...]}`. Unknown keys are
/// ignored (the index may grow); a malformed entry refuses the whole file, so
/// a half-good index is never shown as the catalogue.
pub(crate) fn parse_index(bytes: &[u8]) -> Result<Vec<Entry>> {
    if bytes.len() > MAX_INDEX {
        return Err(format!("index exceeds {MAX_INDEX} bytes"));
    }
    let value: Value = serde_json::from_slice(bytes).map_err(|e| format!("index is not JSON: {e}"))?;
    let apps = value
        .get("apps")
        .and_then(Value::as_array)
        .ok_or("index lacks the apps array")?;
    let mut entries = Vec::with_capacity(apps.len());
    let mut seen = BTreeMap::new();
    for (position, app) in apps.iter().enumerate() {
        let entry = parse_entry(app).map_err(|e| format!("index entry {position}: {e}"))?;
        if let Some(first) = seen.insert(entry.package_id.clone(), position) {
            return Err(format!("index names packageId {} twice (entries {first} and {position})", entry.package_id));
        }
        entries.push(entry);
    }
    Ok(entries)
}

/// The exact known fields, re-serialised: what `index-check` writes.
pub(crate) fn render_index(entries: &[Entry]) -> Value {
    json!({"format":"mini-market-index-v1","source":INDEX_URL,"apps":entries.iter().map(|e| json!({
        "appId":e.app_id,"packageId":e.package_id,"name":e.name,"version":e.version,
        "versionNumber":e.version_number,"author":{"name":e.author},"upstreamAuthor":e.upstream_author,
        "shortDescription":e.short_description,"categories":e.categories,"webLink":e.web_link,
        "codeLink":e.code_link,"createdAt":e.created_at,"isOpenSource":e.open_source})).collect::<Vec<_>>()})
}

pub(crate) fn load_index(path: &Path) -> Result<Vec<Entry>> {
    let bytes = crate::fsio::read_bounded(path, MAX_INDEX)
        .map_err(|e| format!("no market index at {} ({e}); mini-market refreshes it", path.display()))?;
    parse_index(&bytes)
}

/// Resolve one entry by appId or packageId; `unknownApp` names the refusal.
pub(crate) fn resolve<'a>(entries: &'a [Entry], selector: &str) -> Result<&'a Entry> {
    let found = if valid_app_id(selector) {
        entries.iter().find(|e| e.app_id == selector)
    } else if valid_package_id(selector) {
        entries.iter().find(|e| e.package_id == selector)
    } else {
        return Err(format!("unknownApp: {selector:?} is neither a 52-digit appId nor a 32-hex packageId"));
    };
    found.ok_or_else(|| format!("unknownApp: {selector} is not in the market index"))
}

/// Case-insensitive substring search over the index's text fields.
pub(crate) fn search<'a>(entries: &'a [Entry], term: &str, category: Option<&str>) -> Vec<&'a Entry> {
    let term = term.to_lowercase();
    entries
        .iter()
        .filter(|e| {
            category.is_none_or(|c| e.categories.iter().any(|k| k.eq_ignore_ascii_case(c)))
        })
        .filter(|e| {
            term.is_empty()
                || [&e.name, &e.short_description, &e.author, &e.upstream_author, &e.app_id, &e.package_id]
                    .iter()
                    .any(|field| field.to_lowercase().contains(&term))
        })
        .collect()
}

/// Mini's verdict on a package: what the worker's real ingest recorded, or
/// `unverified` when this box has never parsed it. The fetcher's meta file adds
/// the raw size when the package was fetched.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Verdict {
    pub state: String,
    pub reason: Option<String>,
    pub raw_bytes: Option<u64>,
    pub signed_app_id: Option<String>,
    pub running: u64,
}

pub(crate) fn verdict(verdicts: &Path, meta: &Path, package_id: &str) -> Verdict {
    let mut out = Verdict { state: "unverified".into(), reason: None, raw_bytes: None, signed_app_id: None, running: 0 };
    if let Ok(bytes) = crate::fsio::read_bounded(&meta.join(format!("{package_id}.json")), 16 * 1024) {
        if let Ok(value) = serde_json::from_slice::<Value>(&bytes) {
            out.raw_bytes = value.get("bytes").and_then(Value::as_u64);
            if out.raw_bytes.is_some_and(|b| b > STANDARD_RAW_BYTES) {
                out.state = "refused".into();
                out.reason = Some("sizeOverProfile".into());
            }
        }
    }
    if let Ok(bytes) = crate::fsio::read_bounded(&verdicts.join(format!("{package_id}.json")), 16 * 1024) {
        if let Ok(value) = serde_json::from_slice::<Value>(&bytes) {
            if let Some(state) = value.get("verdict").and_then(Value::as_str) {
                out.state = state.to_owned();
            }
            out.reason = value.get("reason").and_then(Value::as_str).map(str::to_owned);
            out.signed_app_id = value.get("signedAppId").and_then(Value::as_str).map(str::to_owned);
            out.running = value.get("running").and_then(Value::as_u64).unwrap_or(0);
        }
    }
    out
}

/// The broker's size class the worker would pick from the raw size: S under
/// 64 MiB, M under 256 MiB (the standard profile's whole budget), else L.
pub(crate) fn suggested_class(raw_bytes: Option<u64>) -> &'static str {
    match raw_bytes {
        None => "unknown until fetched",
        Some(b) if b < 64 * 1024 * 1024 => "S",
        Some(b) if b <= STANDARD_RAW_BYTES => "M",
        Some(_) => "refused: sizeOverProfile",
    }
}

fn entry_json(entry: &Entry, verdict: &Verdict) -> Value {
    json!({
        "appId":entry.app_id,"packageId":entry.package_id,"name":entry.name,"version":entry.version,
        "versionNumber":entry.version_number,"publisher":entry.author,"upstreamAuthor":entry.upstream_author,
        "shortDescription":entry.short_description,"categories":entry.categories,"webLink":entry.web_link,
        "codeLink":entry.code_link,"packageUrl":format!("{PACKAGE_URL}{}",entry.package_id),
        "verdict":{"state":verdict.state,"reason":verdict.reason,"rawBytes":verdict.raw_bytes,
            "signedAppId":verdict.signed_app_id,"running":verdict.running},
        "suggestedClass":suggested_class(verdict.raw_bytes),
        "claims":"name, version, publisher and links are the index's claims; identity is the signed package's"
    })
}

fn verdict_line(verdict: &Verdict) -> String {
    let mut line = verdict.state.clone();
    if let Some(reason) = &verdict.reason {
        line.push_str(": ");
        line.push_str(reason);
    }
    if verdict.running > 0 {
        line.push_str(&format!(", running {}", verdict.running));
    }
    line
}

struct Paths {
    index: PathBuf,
    meta: PathBuf,
    verdicts: PathBuf,
    socket: PathBuf,
}

fn paths(args: &mut Args) -> Paths {
    let from = |args: &mut Args, flag: &str, env: &str, default: &str| {
        args.optional(flag)
            .map(PathBuf::from)
            .or_else(|| std::env::var_os(env).map(PathBuf::from))
            .unwrap_or_else(|| PathBuf::from(default))
    };
    Paths {
        index: from(args, "index", "MINI_MARKET_INDEX", DEFAULT_INDEX),
        meta: from(args, "meta", "MINI_MARKET_META", DEFAULT_META),
        verdicts: from(args, "verdicts", "MINI_APPS_VERDICTS", DEFAULT_VERDICTS),
        socket: from(args, "worker-socket", "MINI_APPS_WORKER_SOCKET", DEFAULT_WORKER_SOCKET),
    }
}

fn text_flag(args: &mut Args, name: &str) -> Result<Option<String>> {
    args.optional(name)
        .map(|v| v.into_string().map_err(|_| format!("--{name} must be UTF-8")))
        .transpose()
}

/// One request to the worker, one bounded reply line. The worker names the
/// member by `SO_PEERCRED`; nothing in the request claims an identity.
pub(crate) fn worker_call(socket: &Path, request: &Value) -> Result<Value> {
    let mut stream = std::os::unix::net::UnixStream::connect(socket).map_err(|e| {
        format!("appsWorkerUnavailable: {} ({e}); the install is not started, retry when the worker is up", socket.display())
    })?;
    stream
        .set_read_timeout(Some(std::time::Duration::from_secs(120)))
        .map_err(|e| e.to_string())?;
    let mut line = serde_json::to_vec(request).map_err(|e| e.to_string())?;
    line.push(b'\n');
    stream.write_all(&line).map_err(|e| format!("worker request not delivered: {e}"))?;
    let mut reader = BufReader::new(stream);
    let mut reply = Vec::new();
    reader
        .by_ref()
        .take(MAX_REPLY as u64 + 1)
        .read_until(b'\n', &mut reply)
        .map_err(|e| format!("worker reply lost after the request was sent; the outcome is undecided: retry the same request id ({e})"))?;
    if reply.len() > MAX_REPLY {
        return Err("worker reply exceeds 64 KiB".into());
    }
    if reply.is_empty() {
        return Err("worker closed without a reply; the outcome is undecided: retry the same request id".into());
    }
    let value: Value = serde_json::from_slice(&reply).map_err(|e| format!("worker reply is not JSON: {e}"))?;
    if value.get("protocol").and_then(Value::as_str) != Some(WORKER_PROTOCOL) {
        return Err("worker reply carries another protocol".into());
    }
    Ok(value)
}

/// Render a worker reply as a decoded outcome. Exit status: 0 decided and
/// performed, 1 decided refused, 3 undecided (the exact retry is printed).
fn report(reply: &Value, as_json: bool) -> Result<()> {
    if as_json {
        println!("{}", serde_json::to_string_pretty(reply).map_err(|e| e.to_string())?);
    }
    let decided = reply.get("decided").and_then(Value::as_bool);
    let state = reply.get("state").and_then(Value::as_str).unwrap_or("?");
    let detail = reply.get("detail").and_then(Value::as_str).unwrap_or("");
    match decided {
        Some(true) if reply.get("refused").and_then(Value::as_str).is_none() => {
            if !as_json {
                println!("{state}: {detail}");
                if let Some(receipt) = reply.get("receipt") {
                    println!("receipt: {receipt}");
                }
            }
            Ok(())
        }
        Some(true) => {
            let reason = reply.get("refused").and_then(Value::as_str).unwrap_or("refused");
            Err(format!("{reason}: {detail}"))
        }
        _ => {
            let retry = reply.get("exactRetry").and_then(Value::as_str).unwrap_or("mini apps status");
            Err(format!("undecided: {state} {detail}; exact retry: {retry}"))
        }
    }
}

fn request_id() -> Result<String> {
    Ok(hex(&crate::fsio::random::<16>()?))
}

/// `install`: the member's choice, retained under the workspace before it is
/// sent, so a lost reply is answered by the exact retry of the same id.
fn install(mut args: Args, paths: &Paths, as_json: bool) -> Result<()> {
    let selector = text_flag(&mut args, "app")?.ok_or("install requires --app APP-ID|PACKAGE-ID")?;
    let class = text_flag(&mut args, "class")?.unwrap_or_else(|| "auto".into());
    if !matches!(class.as_str(), "S" | "M" | "L" | "auto") {
        return Err("classRefused: --class takes S, M or L".into());
    }
    let root = absolute(&path(args.required("dir")?))?;
    let retry = text_flag(&mut args, "retry")?;
    let birth_source = args.optional("birth-source").map(|v| absolute(&path(v))).transpose()?;
    let birth_receipt = args.optional("birth-receipt").map(|v| absolute(&path(v))).transpose()?;
    let delegation = args.optional("delegation").map(|v| absolute(&path(v))).transpose()?;
    args.finish()?;
    let entries = load_index(&paths.index)?;
    let entry = resolve(&entries, &selector)?;
    let verdict = verdict(&paths.verdicts, &paths.meta, &entry.package_id);
    if verdict.state == "refused" {
        return Err(format!(
            "{}: {} {} was refused by this box's ingest; nothing to install",
            verdict.reason.as_deref().unwrap_or("refused"),
            entry.name,
            entry.package_id
        ));
    }
    let requests = root.join("apps").join("requests");
    crate::fsio::ensure_private_dir_all(&requests)?;
    let is_retry = retry.is_some();
    let (id, retained) = match retry {
        Some(id) => {
            if id.len() != 32 || !id.bytes().all(|b| b.is_ascii_hexdigit()) {
                return Err("--retry takes the 32-hex request id the first attempt printed".into());
            }
            let retained = crate::workspace::bounded_json(&requests.join(format!("{id}.json")))?;
            (id, retained)
        }
        None => {
            let apps_dir = root.join("apps").join(&entry.app_id);
            let source = birth_source.unwrap_or_else(|| apps_dir.join("birth").join("source.json"));
            let receipt = birth_receipt.unwrap_or_else(|| apps_dir.join("birth").join("outcome.json"));
            let delegation = delegation.unwrap_or_else(|| apps_dir.join("delegation.json"));
            for (what, file) in [("birth source", &source), ("birth receipt", &receipt), ("lifecycle delegation", &delegation)] {
                if !file.is_file() {
                    return Err(format!(
                        "birthRequired: no {what} at {}; the install is a member turn: first birth the app \
                         (mini current-application-intent + submit, retained as apps/{}/birth/), then delegate \
                         hosting (mini app-lifecycle, retained as apps/{}/delegation.json); docs/APP-MARKET-2026-10-27.md §3",
                        file.display(), entry.app_id, entry.app_id
                    ));
                }
            }
            let id = request_id()?;
            let retained = json!({
                "protocol":WORKER_PROTOCOL,"verb":"install","requestId":id,
                "appId":entry.app_id,"packageId":entry.package_id,"class":class,
                "birthSource":source,"birthReceipt":receipt,"delegation":delegation,
                "indexName":entry.name,"indexVersion":entry.version
            });
            let file = requests.join(format!("{id}.json"));
            crate::workspace::atomic_json(&file, &retained, None)?;
            (id, retained)
        }
    };
    let mut request = retained.clone();
    request["verb"] = json!(if is_retry { "retry" } else { "install" });
    let reply = worker_call(&paths.socket, &request)?;
    let outcome = requests.join(format!("{id}.outcome.json"));
    crate::workspace::atomic_json(&outcome, &reply, None).or_else(|_| {
        // A second reply for the same id (the exact retry) replaces nothing:
        // the first retained outcome stands and this one is kept beside it.
        crate::workspace::atomic_json(&requests.join(format!("{id}.outcome.{}.json", request_id()?)), &reply, None)
    })?;
    if !as_json {
        println!("request {id}: {} {} ({})", entry.name, entry.version, entry.package_id);
    }
    report(&reply, as_json)
}


fn catalogue(action: &str, mut args: Args, paths: &Paths, as_json: bool) -> Result<()> {
    let entries = load_index(&paths.index)?;
    match action {
        "search" => {
            let term = text_flag(&mut args, "term")?.unwrap_or_default();
            let category = text_flag(&mut args, "category")?;
            args.finish()?;
            let found = search(&entries, &term, category.as_deref());
            if as_json {
                let list: Vec<Value> = found
                    .iter()
                    .map(|e| entry_json(e, &verdict(&paths.verdicts, &paths.meta, &e.package_id)))
                    .collect();
                println!("{}", serde_json::to_string_pretty(&json!({"apps":list,"total":entries.len()})).map_err(|e| e.to_string())?);
                return Ok(());
            }
            println!("{} of {} apps ({}):", found.len(), entries.len(), paths.index.display());
            for e in found {
                let v = verdict(&paths.verdicts, &paths.meta, &e.package_id);
                println!(
                    "  {:<28} {:<22} {:<24} {} [{}]",
                    truncate(&e.name, 28),
                    truncate(&e.version, 22),
                    truncate(&e.author, 24),
                    e.app_id,
                    verdict_line(&v)
                );
            }
            Ok(())
        }
        "show" => {
            let selector = text_flag(&mut args, "app")?.ok_or("show requires --app APP-ID|PACKAGE-ID")?;
            args.finish()?;
            let entry = resolve(&entries, &selector)?;
            let v = verdict(&paths.verdicts, &paths.meta, &entry.package_id);
            let value = entry_json(entry, &v);
            if as_json {
                println!("{}", serde_json::to_string_pretty(&value).map_err(|e| e.to_string())?);
                return Ok(());
            }
            println!("{} {} (index claim; the signed manifest decides)", entry.name, entry.version);
            println!("  appId      {}", entry.app_id);
            println!("  packageId  {}  ({}{})", entry.package_id, PACKAGE_URL, entry.package_id);
            println!("  publisher  {}  upstream {}", entry.author, entry.upstream_author);
            println!("  about      {}", entry.short_description);
            println!("  categories {}", entry.categories.join(", "));
            println!("  links      {}  {}", entry.web_link, entry.code_link);
            println!("  verdict    {}", verdict_line(&v));
            println!("  size       {}", v.raw_bytes.map_or("not fetched here".to_owned(), |b| format!("{b} bytes raw")));
            println!("  class      {}", suggested_class(v.raw_bytes));
            println!("  refusals an install can meet: unknownApp, sizeOverProfile, unverifiedSignature, appIdMismatch, unsupportedBridge, funding, classRefused");
            Ok(())
        }
        _ => unreachable!(),
    }
}

fn truncate(text: &str, width: usize) -> String {
    if text.chars().count() <= width {
        text.to_owned()
    } else {
        let mut out: String = text.chars().take(width - 1).collect();
        out.push('…');
        out
    }
}

/// `index-check --in RAW --out INDEX`: the fetcher's validation step. The raw
/// download is parsed, the known fields re-serialised and published by rename,
/// so the catalogue file is always one Mini re-rendered the way it reads it.
fn index_check(mut args: Args) -> Result<()> {
    let input = absolute(&path(args.required("in")?))?;
    let output = absolute(&path(args.required("out")?))?;
    args.finish()?;
    let bytes = crate::fsio::read_bounded(&input, MAX_INDEX)?;
    let entries = parse_index(&bytes)?;
    let rendered = render_index(&entries);
    let mut text = serde_json::to_vec_pretty(&rendered).map_err(|e| e.to_string())?;
    text.push(b'\n');
    let temp = output.with_extension("json.new");
    fs::write(&temp, &text).map_err(|e| format!("cannot write {}: {e}", temp.display()))?;
    fs::rename(&temp, &output).map_err(|e| format!("cannot publish {}: {e}", output.display()))?;
    println!("index-check: {} apps, {} bytes -> {}", entries.len(), text.len(), output.display());
    Ok(())
}

pub(crate) fn run(mut args: Args) -> Result<()> {
    let action = args
        .required("action")?
        .into_string()
        .map_err(|_| "action must be UTF-8".to_owned())?;
    let as_json = args.optional("json").is_some();
    let paths = paths(&mut args);
    match action.as_str() {
        "index-check" => index_check(args),
        "search" | "show" => catalogue(&action, args, &paths, as_json),
        "install" => install(args, &paths, as_json),
        verb if WORKER_VERBS.contains(&verb) => {
            let mut request = Map::new();
            request.insert("protocol".into(), json!(WORKER_PROTOCOL));
            request.insert("verb".into(), json!(verb));
            for flag in ["grain", "to", "out", "request-id"] {
                if let Some(value) = text_flag(&mut args, flag)? {
                    if flag == "grain" && !valid_grain(&value) {
                        return Err(format!("grainRefused: {value:?} is not a grain id of the form a<app>"));
                    }
                    request.insert(camel(flag), json!(value));
                }
            }
            args.finish()?;
            if matches!(verb, "open" | "stop" | "start" | "share" | "export" | "delete" | "status") && !request.contains_key("grain") {
                return Err(format!("{verb} requires --grain a<app>"));
            }
            if verb == "share" && !request.contains_key("to") {
                return Err("share requires --to MEMBER".into());
            }
            let reply = worker_call(&paths.socket, &Value::Object(request))?;
            report(&reply, as_json)
        }
        other => Err(format!(
            "mini apps: unknown action {other}; actions: search, show, index-check, {}",
            WORKER_VERBS.join(", ")
        )),
    }
}

/// A grain id is `a<app>`: the app resource's canonical decimal, DNS-safe.
pub(crate) fn valid_grain(text: &str) -> bool {
    text.len() >= 2
        && text.len() <= 40
        && text.as_bytes()[0] == b'a'
        && text.as_bytes()[1] != b'0'
        && text.bytes().skip(1).all(|b| b.is_ascii_digit())
}

fn camel(flag: &str) -> String {
    let mut out = String::new();
    let mut upper = false;
    for c in flag.chars() {
        if c == '-' {
            upper = true;
        } else if upper {
            out.extend(c.to_uppercase());
            upper = false;
        } else {
            out.push(c);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE: &[u8] = include_bytes!("../tests/fixtures/sandstorm-index-2026-10-27.json");

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("mini-apps-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn fixture() -> Vec<Entry> {
        parse_index(FIXTURE).unwrap()
    }

    #[test]
    fn apps_fixture_parses_whole_with_the_known_apps() {
        let entries = fixture();
        assert_eq!(entries.len(), 98);
        let slides = resolve(&entries, "7qvcjh7gk0rzdx1s3c8gufd288sesf6vvdt297756xcv4q8xxvhh").unwrap();
        assert_eq!(slides.name, "Hacker Slides");
        assert_eq!(slides.package_id, "f0277a5dce2e1c6af0cce188241411a4");
        assert_eq!(slides.version, "0.4.0");
        let todos = resolve(&entries, "5830d70137cdae158118884da8790870").unwrap();
        assert_eq!(todos.name, "Simple Todos");
        assert_eq!(todos.app_id, "0dp7n6ehj8r5ttfc0fj0au6gxkuy1nhw2kx70wussfa1mqj8tf80");
        assert_eq!(todos.author, "Asheesh Laroia");
        assert!(todos.categories.contains(&"Productivity".to_owned()));
    }

    #[test]
    fn apps_unknown_and_malformed_selectors_refuse_by_name() {
        let entries = fixture();
        let missing = resolve(&entries, "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz").unwrap_err();
        assert!(missing.starts_with("unknownApp:"), "{missing}");
        let short = resolve(&entries, "etherpad").unwrap_err();
        assert!(short.starts_with("unknownApp:"), "{short}");
        assert!(resolve(&entries, "F0277A5DCE2E1C6AF0CCE188241411A4").unwrap_err().starts_with("unknownApp:"));
    }

    #[test]
    fn apps_search_is_case_insensitive_over_text_and_filters_categories() {
        let entries = fixture();
        let pads = search(&entries, "ETHERPAD", None);
        assert!(pads.iter().any(|e| e.package_id == "aee0806c9547d1f53c1ccef38ac195ba"));
        let rss = search(&entries, "tiny tiny", None);
        assert_eq!(rss.len(), 1);
        assert_eq!(rss[0].package_id, "ac6dfded255f6ea86172fb62064772fc");
        let office = search(&entries, "", Some("office"));
        assert!(office.iter().any(|e| e.name == "Simple Todos"));
        assert!(office.iter().all(|e| e.categories.iter().any(|c| c.eq_ignore_ascii_case("Office"))));
        assert!(search(&entries, "no such app anywhere", None).is_empty());
        assert_eq!(search(&entries, "", None).len(), 98);
    }

    #[test]
    fn apps_index_is_data_a_malformed_entry_refuses_the_file() {
        let mut value: Value = serde_json::from_slice(FIXTURE).unwrap();
        value["apps"][3]["packageId"] = json!("not-hex");
        let error = parse_index(&serde_json::to_vec(&value).unwrap()).unwrap_err();
        assert!(error.contains("index entry 3") && error.contains("packageId"), "{error}");
        let mut value: Value = serde_json::from_slice(FIXTURE).unwrap();
        value["apps"][0]["appId"] = json!("Short");
        assert!(parse_index(&serde_json::to_vec(&value).unwrap()).is_err());
        let mut value: Value = serde_json::from_slice(FIXTURE).unwrap();
        value["apps"][1]["name"] = json!("evil\u{7}bell");
        assert!(parse_index(&serde_json::to_vec(&value).unwrap()).unwrap_err().contains("control bytes"));
        let mut value: Value = serde_json::from_slice(FIXTURE).unwrap();
        let dup = value["apps"][0].clone();
        value["apps"].as_array_mut().unwrap().push(dup);
        assert!(parse_index(&serde_json::to_vec(&value).unwrap()).unwrap_err().contains("twice"));
        assert!(parse_index(br#"{"notapps":[]}"#).unwrap_err().contains("apps array"));
        assert!(parse_index(&vec![b' '; MAX_INDEX + 1]).unwrap_err().contains("exceeds"));
    }

    #[test]
    fn apps_index_check_round_trips_the_known_fields_only() {
        let entries = fixture();
        let rendered = render_index(&entries);
        let again = parse_index(&serde_json::to_vec(&rendered).unwrap()).unwrap();
        assert_eq!(again, entries);
        assert_eq!(rendered["format"], "mini-market-index-v1");
        // The index's author pictures and usernames are not carried: data we do not show.
        assert!(rendered["apps"][0]["author"].get("picture").is_none());
    }

    #[test]
    fn apps_verdict_defaults_to_unverified_and_reads_meta_and_ingest() {
        let dir = scratch("verdict");
        let meta = dir.join("meta");
        let verdicts = dir.join("verdicts");
        fs::create_dir_all(&meta).unwrap();
        fs::create_dir_all(&verdicts).unwrap();
        let unknown = verdict(&verdicts, &meta, "f0277a5dce2e1c6af0cce188241411a4");
        assert_eq!(unknown.state, "unverified");
        assert_eq!(suggested_class(unknown.raw_bytes), "unknown until fetched");
        fs::write(meta.join("f0277a5dce2e1c6af0cce188241411a4.json"), br#"{"bytes":16778192}"#).unwrap();
        let fetched = verdict(&verdicts, &meta, "f0277a5dce2e1c6af0cce188241411a4");
        assert_eq!((fetched.state.as_str(), suggested_class(fetched.raw_bytes)), ("unverified", "S"));
        fs::write(meta.join("2a2c05041cb4285da884d114e4820298.json"), br#"{"bytes":300000000}"#).unwrap();
        let big = verdict(&verdicts, &meta, "2a2c05041cb4285da884d114e4820298");
        assert_eq!((big.state.as_str(), big.reason.as_deref()), ("refused", Some("sizeOverProfile")));
        fs::write(
            verdicts.join("aee0806c9547d1f53c1ccef38ac195ba.json"),
            br#"{"verdict":"refused","reason":"unsupportedBridge: apiPath \"../x\"","signedAppId":"h37dm17aa89yrd8zuqpdn36p6zntumtv08fjpu8a8zrte7q1cn60"}"#,
        )
        .unwrap();
        let pad = verdict(&verdicts, &meta, "aee0806c9547d1f53c1ccef38ac195ba");
        assert_eq!(verdict_line(&pad), "refused: unsupportedBridge: apiPath \"../x\"");
        fs::write(verdicts.join("5830d70137cdae158118884da8790870.json"), br#"{"verdict":"verified","running":2}"#).unwrap();
        assert_eq!(verdict_line(&verdict(&verdicts, &meta, "5830d70137cdae158118884da8790870")), "verified, running 2");
    }

    #[test]
    fn apps_grain_ids_are_decimal_app_resources() {
        assert!(valid_grain("a4501"));
        assert!(valid_grain("a1"));
        assert!(!valid_grain("a0501"));
        assert!(!valid_grain("4501"));
        assert!(!valid_grain("a"));
        assert!(!valid_grain("a45x1"));
        assert_eq!(camel("request-id"), "requestId");
    }

    #[test]
    fn apps_worker_reply_decodes_to_three_outcomes() {
        assert!(report(&json!({"decided":true,"state":"running","detail":"a4501"}), false).is_ok());
        let refused = report(&json!({"decided":true,"refused":"funding","detail":"purse 3 < tariff 5"}), false).unwrap_err();
        assert!(refused.starts_with("funding:"));
        let undecided = report(&json!({"decided":false,"state":"stopping","detail":"since 12:00","exactRetry":"mini apps status --grain a4501"}), false).unwrap_err();
        assert!(undecided.starts_with("undecided:") && undecided.ends_with("mini apps status --grain a4501"), "{undecided}");
    }

    #[test]
    fn apps_worker_call_refuses_an_absent_socket_by_name() {
        let dir = scratch("socket");
        let error = worker_call(&dir.join("none.sock"), &json!({"protocol":WORKER_PROTOCOL,"verb":"list"})).unwrap_err();
        assert!(error.starts_with("appsWorkerUnavailable:"), "{error}");
    }
}
