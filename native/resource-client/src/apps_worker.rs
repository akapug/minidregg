//! `mini apps-worker`: the operator-side custodian of the app market
//! (docs/APP-MARKET-2026-10-27.md §4). It runs as the grain world's operator (a
//! system unit, User=mini-core), reaches the SPK broker in mini-core's user manager, and acts on admitted install
//! requests through `spk-host grain` and the ordinary `mini` client verbs, the
//! way `scripts/spk-platform/grain-journey.sh` does by hand. It holds no member
//! key; the member is named by the socket peer (`SO_PEERCRED`), never by a
//! field of the request.
//!
//! Two sockets:
//! - `worker.sock` (0660, group `mini-sessions`): members' verbs, one JSON line
//!   each way, bounded. Every reply is a decoded outcome: `decided` with a
//!   receipt or a refusal by name, or `undecided` with its exact retry.
//! - `edge.sock` (0660, group `mini-edge`): the grain front asks `connect` for a
//!   (grain, route) and receives the connected custodian socket over
//!   `SCM_RIGHTS`. Route sockets live under the operator's 0700 state root; the
//!   worker is the one process that reaches them, and it adds no authority: the
//!   custodian still checks the token the browser presents.
//!
//! Every step is idempotent on its retained artifact (`requests/<id>.json`
//! phases; `spk-host grain`'s own one-shot markers), so a lost reply is answered
//! by the exact retry of the same request id and a second install is never
//! issued (SPK-LIFECYCLE).

use crate::{absolute, hex, path, Args, Result};
use serde_json::{json, Map, Value};
use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt};
use std::os::unix::io::{AsRawFd, FromRawFd, IntoRawFd};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use super::{valid_app_id, valid_grain, valid_package_id, WORKER_PROTOCOL};

const MAX_LINE: usize = 256 * 1024;
const MAX_DOCUMENT: usize = 64 * 1024;
const MEMBER_PREFIX: &str = "mini-s-";
pub(crate) const IDENTITY_NOTICE: &str = "v1: this grain signs for every member it is shared with as one guest subject; members are told apart by route, token and receipt, not by the app (per-member subjects are v2)";

fn now() -> String {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs().to_string()).unwrap_or_default()
}

fn text<'a>(value: &'a Value, key: &str) -> Result<&'a str> {
    value.get(key).and_then(Value::as_str).ok_or_else(|| format!("request lacks {key}"))
}

fn private_dir(path: &Path) -> Result<()> {
    if path.is_dir() {
        return Ok(());
    }
    fs::DirBuilder::new().mode(0o700).recursive(true).create(path).map_err(|e| format!("{}: {e}", path.display()))
}

fn write_json(path: &Path, value: &Value) -> Result<()> {
    let bytes = serde_json::to_vec_pretty(value).map_err(|e| e.to_string())?;
    let temp = path.with_extension("json.new");
    let _ = fs::remove_file(&temp);
    let mut file = fs::OpenOptions::new().write(true).create_new(true).mode(0o600).open(&temp).map_err(|e| format!("{}: {e}", temp.display()))?;
    file.write_all(&bytes).map_err(|e| e.to_string())?;
    file.sync_all().map_err(|e| e.to_string())?;
    fs::rename(&temp, path).map_err(|e| e.to_string())
}

fn read_json(path: &Path) -> Result<Value> {
    let bytes = crate::fsio::read_bounded(path, MAX_LINE)?;
    serde_json::from_slice(&bytes).map_err(|e| format!("{}: {e}", path.display()))
}

// ------------------------------------------------------------- the world

pub(crate) struct Installed {
    pub app: String,
    pub raw_sha256: String,
    pub signed_app_id: String,
    pub app_version: String,
}

pub(crate) struct RouteBound {
    pub directory: PathBuf,
    pub socket: PathBuf,
    pub browser_token_sha256: String,
    pub bootstrap_token_sha256: String,
    pub api_token_sha256: String,
}

/// The lifecycle outcome `spk-host grain` reports: STOP is minutes long.
#[derive(Debug, PartialEq)]
pub(crate) enum Lifecycle {
    Done,
    Undecided(String),
}

/// What the worker needs from the box. The process-backed world drives
/// `spk-host grain` and `mini`; tests supply a fake.
pub(crate) trait World {
    fn package(&self, package_id: &str) -> Result<Option<(PathBuf, String, u64)>>;
    fn want(&self, package_id: &str) -> Result<()>;
    fn install(&self, work: &Path, source: &Path, receipt: &Path, spk: &Path, class: &str, delegation: &Path) -> Result<Installed>;
    fn start(&self, app: &str) -> Result<Lifecycle>;
    fn stop(&self, app: &str) -> Result<Lifecycle>;
    fn status(&self, app: &str) -> Result<Value>;
    /// A participant route for `member` on `app` with `expected_host`: the
    /// session birth, the ticket under the delegated capability, the
    /// enrollment and `spk-host grain route`.
    fn route(&self, work: &Path, app: &str, member: &str, expected_host: &str) -> Result<RouteBound>;
    fn export(&self, app: &str, out: &Path) -> Result<()>;
    fn identities(&self, app: &str) -> Result<Vec<Value>>;
    fn revoke_identity(&self, app: &str, token: &str) -> Result<()>;
    fn verdict(&self, package_id: &str, verdict: &Value) -> Result<()>;
    fn domain(&self) -> &str;
}

// --------------------------------------------------------------- the state

pub(crate) struct Worker {
    state: PathBuf,
    world: Box<dyn World + Send + Sync>,
    lock: Mutex<()>,
}

fn request_file(state: &Path, id: &str) -> PathBuf {
    state.join("requests").join(format!("{id}.json"))
}

fn grain_file(state: &Path, grain: &str) -> PathBuf {
    state.join("grains").join(format!("{grain}.json"))
}

fn refused(name: &str, detail: impl Into<String>) -> Value {
    json!({"protocol":WORKER_PROTOCOL,"decided":true,"refused":name,"state":"refused","detail":detail.into()})
}

fn undecided(state: &str, detail: impl Into<String>, retry: &str) -> Value {
    json!({"protocol":WORKER_PROTOCOL,"decided":false,"state":state,"detail":detail.into(),"exactRetry":retry})
}

fn performed(state: &str, detail: impl Into<String>, receipt: Value) -> Value {
    json!({"protocol":WORKER_PROTOCOL,"decided":true,"state":state,"detail":detail.into(),"receipt":receipt})
}

fn valid_member(name: &str) -> bool {
    !name.is_empty() && name.len() <= 32 && name.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
}

fn valid_class(class: &str) -> bool {
    matches!(class, "S" | "M" | "L" | "auto")
}

impl Worker {
    pub(crate) fn open(state: PathBuf, world: Box<dyn World + Send + Sync>) -> Result<Self> {
        for sub in ["requests", "grains", "work", "exports"] {
            private_dir(&state.join(sub))?;
        }
        Ok(Self { state, world, lock: Mutex::new(()) })
    }

    fn grain_record(&self, grain: &str) -> Result<Option<Value>> {
        let path = grain_file(&self.state, grain);
        if !path.exists() {
            return Ok(None);
        }
        read_json(&path).map(Some)
    }

    fn owned_grain(&self, member: &str, grain: &str, allow_shared: bool) -> std::result::Result<Value, Value> {
        if !valid_grain(grain) {
            return Err(refused("grainRefused", format!("{grain:?} is not a grain id of the form a<app>")));
        }
        let Some(record) = self.grain_record(grain).map_err(|e| refused("stateUnavailable", e))? else {
            return Err(refused("unknownGrain", format!("{grain} is not a grain of this world")));
        };
        let owner = record.get("owner").and_then(Value::as_str).unwrap_or("");
        let shared = record.get("routes").and_then(Value::as_object).is_some_and(|r| r.contains_key(member));
        if owner != member && !(allow_shared && shared) {
            return Err(refused("notOwner", format!("{grain} belongs to another member")));
        }
        Ok(record)
    }

    /// One request: dispatch by verb, the member named by the peer.
    pub(crate) fn handle(&self, member: &str, request: &Value) -> Value {
        if request.get("protocol").and_then(Value::as_str) != Some(WORKER_PROTOCOL) {
            return refused("protocolRefused", "the request carries another protocol");
        }
        if !valid_member(member) {
            return refused("memberRefused", "the peer is not a member account");
        }
        let verb = request.get("verb").and_then(Value::as_str).unwrap_or("");
        let _serial = self.lock.lock().unwrap_or_else(|p| p.into_inner());
        match verb {
            "install" | "retry" => self.install(member, request),
            "list" => self.list(member),
            "status" => self.with_grain(member, request, true, |w, g, r| w.status(g, &r)),
            "open" => self.with_grain(member, request, true, |w, g, r| w.open_route(member, g, r)),
            "stop" => self.with_grain(member, request, false, |w, g, r| w.lifecycle(g, r, false)),
            "start" => self.with_grain(member, request, false, |w, g, r| w.lifecycle(g, r, true)),
            "share" => self.with_grain(member, request, false, |w, g, r| w.share(g, r, request)),
            "export" => self.with_grain(member, request, false, |w, g, r| w.export(g, r)),
            "delete" => self.with_grain(member, request, false, |w, g, r| w.delete(g, r)),
            "identities" => self.with_grain(member, request, true, |w, g, r| w.identities(g, &r)),
            "revoke-identity" => self.with_grain(member, request, false, |w, g, r| w.revoke_identity(g, r, request)),
            other => refused("unknownVerb", format!("{other:?}")),
        }
    }

    fn with_grain(&self, member: &str, request: &Value, allow_shared: bool, f: impl FnOnce(&Self, &str, Value) -> Value) -> Value {
        let grain = request.get("grain").and_then(Value::as_str).unwrap_or("");
        match self.owned_grain(member, grain, allow_shared) {
            Ok(record) => f(self, grain, record),
            Err(refusal) => refusal,
        }
    }

    fn list(&self, member: &str) -> Value {
        let mut grains = Vec::new();
        if let Ok(entries) = fs::read_dir(self.state.join("grains")) {
            for entry in entries.flatten() {
                let Ok(record) = read_json(&entry.path()) else { continue };
                let owner = record.get("owner").and_then(Value::as_str).unwrap_or("");
                let shared = record.get("routes").and_then(Value::as_object).is_some_and(|r| r.contains_key(member));
                if owner == member || shared {
                    grains.push(json!({
                        "grain":record["grain"],"owner":owner,"shared":owner != member,"appId":record["appId"],
                        "indexName":record["indexName"],"class":record["class"],"state":record["state"],
                        "origin":record["origin"],"routes":record.get("routes").and_then(Value::as_object).map(|r| r.keys().cloned().collect::<Vec<_>>()).unwrap_or_default(),
                    }));
                }
            }
        }
        grains.sort_by(|a, b| a["grain"].as_str().cmp(&b["grain"].as_str()));
        performed("listed", format!("{} grain(s)", grains.len()), json!({"grains":grains,"identityNotice":IDENTITY_NOTICE}))
    }

    fn status(&self, grain: &str, record: &Value) -> Value {
        let app = record["app"].as_str().unwrap_or("");
        let live = match self.world.status(app) {
            Ok(status) => status,
            Err(error) => return undecided("statusUnavailable", error, &format!("mini apps status --grain {grain}")),
        };
        let identities = self.world.identities(app).unwrap_or_default();
        let runs = live.get("runs").and_then(Value::as_array).cloned().unwrap_or_default();
        let latest = runs.last().cloned().unwrap_or(Value::Null);
        let state = latest.get("state").and_then(Value::as_str).unwrap_or(record["state"].as_str().unwrap_or("unknown")).to_owned();
        performed(&state, format!("{grain} generation {}", latest.get("generation").and_then(Value::as_str).unwrap_or("?")), json!({
            "grain":grain,"origin":record["origin"],"class":record["class"],"appId":record["appId"],
            "indexName":record["indexName"],"owner":record["owner"],
            "routes":record.get("routes").and_then(Value::as_object).map(|r| r.keys().cloned().collect::<Vec<_>>()).unwrap_or_default(),
            "runs":runs,"identities":identities,"identityNotice":IDENTITY_NOTICE,
        }))
    }

    fn open_route(&self, member: &str, grain: &str, record: Value) -> Value {
        let Some(route) = record.pointer(&format!("/routes/{member}")) else {
            return refused("noRoute", format!("{member} has no route on {grain}; the owner shares it with `mini apps share --grain {grain} --to {member}`"));
        };
        let directory = PathBuf::from(route["directory"].as_str().unwrap_or(""));
        if directory.join("bootstrap.used").exists() {
            return performed("open", format!("{grain}: the bootstrap for this route was used; the browser holds the cookie. A fresh route needs a new share"), json!({
                "grain":grain,"origin":record["origin"],"bootstrapUsed":true,"identityNotice":IDENTITY_NOTICE}));
        }
        let token = match crate::fsio::read_bounded(&directory.join("bootstrap.token"), 128) {
            Ok(bytes) => String::from_utf8_lossy(&bytes).trim().to_owned(),
            Err(error) => return undecided("routeUnavailable", format!("the route's bootstrap token is not readable: {error}"), &format!("mini apps open --grain {grain}")),
        };
        performed("open", format!("{grain}: visit {}/__mini/bootstrap and paste the one-time token", record["origin"].as_str().unwrap_or("")), json!({
            "grain":grain,"origin":record["origin"],"bootstrapPath":"/__mini/bootstrap","bootstrapToken":token,
            "identityNotice":IDENTITY_NOTICE}))
    }

    fn lifecycle(&self, grain: &str, mut record: Value, start: bool) -> Value {
        let app = record["app"].as_str().unwrap_or("").to_owned();
        let verb = if start { "start" } else { "stop" };
        let outcome = if start { self.world.start(&app) } else { self.world.stop(&app) };
        match outcome {
            Ok(Lifecycle::Done) => {
                record["state"] = json!(if start { "running" } else { "stopped" });
                record["lifecycleAt"] = json!(now());
                if let Err(e) = write_json(&grain_file(&self.state, grain), &record) {
                    return undecided("stateUnavailable", e, &format!("mini apps status --grain {grain}"));
                }
                performed(record["state"].as_str().unwrap_or(verb), format!("{grain} {verb} completed through Mini"), json!({"grain":grain,"state":record["state"]}))
            }
            Ok(Lifecycle::Undecided(detail)) => {
                record["state"] = json!(if start { "starting" } else { "stopping" });
                let _ = write_json(&grain_file(&self.state, grain), &record);
                undecided(record["state"].as_str().unwrap_or(verb), detail, &format!("mini apps status --grain {grain}"))
            }
            Err(error) => undecided(verb, format!("{verb} did not complete: {error}; the lifecycle's own markers decide, nothing is repeated"), &format!("mini apps status --grain {grain}")),
        }
    }

    fn share(&self, grain: &str, mut record: Value, request: &Value) -> Value {
        let to = request.get("to").and_then(Value::as_str).unwrap_or("");
        if !valid_member(to) {
            return refused("memberRefused", format!("{to:?} is not a member name"));
        }
        if record.pointer(&format!("/routes/{to}")).is_some() {
            return performed("shared", format!("{grain} is already shared with {to}"), json!({"grain":grain,"member":to,"identityNotice":IDENTITY_NOTICE}));
        }
        let app = record["app"].as_str().unwrap_or("").to_owned();
        let work = self.state.join("work").join(grain).join(format!("share-{to}"));
        if let Err(e) = private_dir(&work) {
            return undecided("stateUnavailable", e, &format!("mini apps share --grain {grain} --to {to}"));
        }
        let host = format!("{grain}.{}", self.world.domain());
        match self.world.route(&work, &app, to, &host) {
            Ok(bound) => {
                record["routes"][to] = route_json(&bound, to);
                if let Err(e) = write_json(&grain_file(&self.state, grain), &record).and_then(|_| self.publish_origin(grain, &record)) {
                    return undecided("stateUnavailable", e, &format!("mini apps share --grain {grain} --to {to}"));
                }
                performed("shared", format!("{grain} shared with {to}: they open it with `mini apps open --grain {grain}`"), json!({"grain":grain,"member":to,"origin":record["origin"],"identityNotice":IDENTITY_NOTICE}))
            }
            Err(error) => undecided("sharing", format!("the route for {to} is not bound yet: {error}"), &format!("mini apps share --grain {grain} --to {to}")),
        }
    }

    fn export(&self, grain: &str, record: Value) -> Value {
        let app = record["app"].as_str().unwrap_or("").to_owned();
        let out = self.state.join("exports").join(grain);
        if out.join("manifest.sig").exists() {
            return performed("exported", format!("{grain} export retained"), json!({"grain":grain,"export":out,"files":["var.ext4","manifest.json","manifest.sig"]}));
        }
        match self.world.export(&app, &out) {
            Ok(()) => performed("exported", format!("{grain} exported (the stopped app's /var, its manifest and the Store's completion signature)"), json!({"grain":grain,"export":out,"files":["var.ext4","manifest.json","manifest.sig"]})),
            Err(error) => refused("exportRefused", format!("{error}; export needs the app's latest generation STOPped by a completed STOP")),
        }
    }

    fn delete(&self, grain: &str, mut record: Value) -> Value {
        let app = record["app"].as_str().unwrap_or("").to_owned();
        if record["state"] != "stopped" {
            match self.world.stop(&app) {
                Ok(Lifecycle::Done) => {}
                Ok(Lifecycle::Undecided(detail)) => return undecided("stopping", format!("{detail}; delete continues after the STOP completes"), &format!("mini apps delete --grain {grain}")),
                Err(error) => return undecided("stopping", error, &format!("mini apps delete --grain {grain}")),
            }
        }
        record["state"] = json!("deleted");
        record["deletedAt"] = json!(now());
        record["routes"] = json!({});
        if let Err(e) = write_json(&grain_file(&self.state, grain), &record) {
            return undecided("stateUnavailable", e, &format!("mini apps delete --grain {grain}"));
        }
        let _ = fs::remove_file(self.origin_path(grain));
        performed("deleted", format!("{grain} stopped and its routes withdrawn; its /var volume is retained by the broker (volumeRetained: the broker has no destroy verb yet)"), json!({"grain":grain,"volumeRetained":true}))
    }

    fn identities(&self, grain: &str, record: &Value) -> Value {
        let app = record["app"].as_str().unwrap_or("");
        match self.world.identities(app) {
            Ok(list) => performed("listed", format!("{} identity record(s) held by {grain}", list.len()), json!({"grain":grain,"identities":list,"identityNotice":IDENTITY_NOTICE})),
            Err(error) => undecided("statusUnavailable", error, &format!("mini apps identities --grain {grain}")),
        }
    }

    fn revoke_identity(&self, grain: &str, record: Value, request: &Value) -> Value {
        let token = request.get("token").and_then(Value::as_str).unwrap_or("");
        if !mini_sdk::hex::is_canonical_len(token, 32) {
            return refused("tokenRefused", "a saved-identity token is 64 lowercase hex digits (mini apps identities)");
        }
        let app = record["app"].as_str().unwrap_or("");
        match self.world.revoke_identity(app, token) {
            Ok(()) => performed("revoked", format!("{grain} can no longer restore identity {}…; the record stays, marked", &token[..8]), json!({"grain":grain,"token":token})),
            Err(error) => refused("revokeRefused", error),
        }
    }

    // ------------------------------------------------------------- install

    fn install(&self, member: &str, request: &Value) -> Value {
        let Some(id) = request.get("requestId").and_then(Value::as_str) else {
            return refused("requestRefused", "install needs a 32-hex requestId");
        };
        if !mini_sdk::hex::is_canonical_len(id, 16) {
            return refused("requestRefused", "requestId is not 32 hex digits");
        }
        let file = request_file(&self.state, id);
        let mut retained = match read_json(&file) {
            Ok(retained) => {
                if retained["member"] != member {
                    return refused("notOwner", "this request id belongs to another member");
                }
                retained
            }
            Err(_) => {
                if request["verb"] == "retry" {
                    return refused("unknownRequest", format!("no request {id} is retained for {member}; the first install was never received"));
                }
                match self.admit(member, request) {
                    Ok(retained) => {
                        if let Err(e) = write_json(&file, &retained) {
                            return undecided("stateUnavailable", e, &format!("mini apps install --retry {id}"));
                        }
                        retained
                    }
                    Err(refusal) => return refusal,
                }
            }
        };
        let outcome = self.advance(&mut retained);
        retained["lastOutcome"] = outcome.clone();
        let _ = write_json(&file, &retained);
        outcome
    }

    /// The request as retained: the member's choice and the three documents.
    fn admit(&self, member: &str, request: &Value) -> std::result::Result<Value, Value> {
        let app_id = text(request, "appId").map_err(|e| refused("requestRefused", e))?;
        let package_id = text(request, "packageId").map_err(|e| refused("requestRefused", e))?;
        if !valid_app_id(app_id) || !valid_package_id(package_id) {
            return Err(refused("unknownApp", "appId or packageId malformed"));
        }
        let class = request.get("class").and_then(Value::as_str).unwrap_or("auto");
        if !valid_class(class) {
            return Err(refused("classRefused", "class is S, M, L or auto"));
        }
        let mut docs = Map::new();
        for key in ["birthSource", "birthReceipt", "delegation"] {
            let Some(doc) = request.get(key).filter(|d| d.is_object()) else {
                return Err(refused("birthRequired", format!("the request carries no {key} document; the install is a member turn (docs/APP-MARKET-2026-10-27.md §3)")));
            };
            if serde_json::to_vec(doc).map(|b| b.len()).unwrap_or(usize::MAX) > MAX_DOCUMENT {
                return Err(refused("requestRefused", format!("{key} exceeds 64 KiB")));
            }
            docs.insert(key.into(), doc.clone());
        }
        if docs["delegation"].get("protocol").and_then(Value::as_str) != Some("mini-spk-grain-lifecycle-delegation-v1") {
            return Err(refused("delegationRefused", "the hosting delegation is not mini-spk-grain-lifecycle-delegation-v1 (mini shell: app delegate-lifecycle)"));
        }
        if docs["birthReceipt"].get("type").and_then(Value::as_str) != Some("confirmed") {
            return Err(refused("birthRequired", "the application birth receipt is not confirmed"));
        }
        Ok(json!({
            "protocol":WORKER_PROTOCOL,"requestId":text(request,"requestId").unwrap_or(""),"member":member,
            "appId":app_id,"packageId":package_id,"class":class,
            "indexName":request.get("indexName").cloned().unwrap_or(Value::Null),
            "indexVersion":request.get("indexVersion").cloned().unwrap_or(Value::Null),
            "documents":docs,"phases":{},"receivedAt":now(),
        }))
    }

    /// Run the next phases of a retained request; each retains its result
    /// before the next starts, so a retry resumes where the last one stopped.
    fn advance(&self, retained: &mut Value) -> Value {
        let id = retained["requestId"].as_str().unwrap_or("").to_owned();
        let member = retained["member"].as_str().unwrap_or("").to_owned();
        let package_id = retained["packageId"].as_str().unwrap_or("").to_owned();
        let retry = format!("mini apps install --retry {id}");
        let work = self.state.join("work").join(&id);
        if let Err(e) = private_dir(&work) {
            return undecided("stateUnavailable", e, &retry);
        }
        // Phase 1: the package, from the quarantine (or wanted).
        let spk = match self.world.package(&package_id) {
            Err(e) => return undecided("fetching", e, &retry),
            Ok(None) => {
                if let Err(e) = self.world.want(&package_id) {
                    return undecided("fetching", e, &retry);
                }
                retained["phases"]["package"] = json!({"state":"wanted","at":now()});
                return undecided("fetching", format!("package {package_id} is not in the quarantine yet; mini-market fetches it"), &retry);
            }
            Ok(Some((path, sha, bytes))) => {
                if !sha.starts_with(&package_id) {
                    return refused("packageIdMismatch", format!("quarantine copy hashes to {sha}"));
                }
                retained["phases"]["package"] = json!({"state":"present","path":path,"sha256":sha,"bytes":bytes});
                path
            }
        };
        // Phase 2: install through spk-host (its own one-shot markers make a resume exact).
        let installed = match retained["phases"]["install"].get("app").and_then(Value::as_str) {
            Some(app) => Installed {
                app: app.to_owned(),
                raw_sha256: retained["phases"]["install"]["rawSha256"].as_str().unwrap_or("").to_owned(),
                signed_app_id: retained["phases"]["install"]["signedAppId"].as_str().unwrap_or("").to_owned(),
                app_version: retained["phases"]["install"]["appVersion"].as_str().unwrap_or("").to_owned(),
            },
            None => {
                let docs = &retained["documents"];
                let source = work.join("birth-source.json");
                let receipt = work.join("birth-outcome.json");
                let delegation = work.join("delegation.json");
                for (path, doc) in [(&source, &docs["birthSource"]), (&receipt, &docs["birthReceipt"]), (&delegation, &docs["delegation"])] {
                    if !path.exists() {
                        if let Err(e) = write_json(path, doc) {
                            return undecided("stateUnavailable", e, &retry);
                        }
                    }
                }
                let class: String = match retained["class"].as_str().unwrap_or("auto") {
                    "auto" => {
                        let bytes = retained["phases"]["package"]["bytes"].as_u64().unwrap_or(0);
                        if bytes < 64 * 1024 * 1024 { "S".into() } else { "M".into() }
                    }
                    c => c.to_owned(),
                };
                retained["class"] = json!(class);
                let _ = write_json(&request_file(&self.state, &id), retained);
                match self.world.install(&work, &source, &receipt, &spk, &class, &delegation) {
                    Ok(installed) => {
                        if installed.signed_app_id != retained["appId"] {
                            let _ = self.world.verdict(&package_id, &json!({"verdict":"refused","reason":"appIdMismatch","signedAppId":installed.signed_app_id}));
                            return refused("appIdMismatch", format!("the signed appId {} differs from the catalogue's", installed.signed_app_id));
                        }
                        retained["phases"]["install"] = json!({"app":installed.app,"rawSha256":installed.raw_sha256,"signedAppId":installed.signed_app_id,"appVersion":installed.app_version,"at":now()});
                        let _ = self.world.verdict(&package_id, &json!({"verdict":"verified","signedAppId":installed.signed_app_id,"rawSha256":installed.raw_sha256,"running":1}));
                        installed
                    }
                    Err(error) => {
                        let name = if error.contains("unsupported physical profile") || error.contains("apiPath") { "unsupportedBridge" } else if error.contains("signature") || error.contains("Signature") { "unverifiedSignature" } else if error.contains("UNRESOLVED") || error.contains("uncertain") { return undecided("installing", error, &retry) } else { "installRefused" };
                        let _ = self.world.verdict(&package_id, &json!({"verdict":"refused","reason":format!("{name}: {error}")}));
                        return refused(name, error);
                    }
                }
            }
        };
        let grain = format!("a{}", installed.app);
        let origin = format!("https://{grain}.{}", self.world.domain());
        // Phase 3: START.
        if retained["phases"]["start"].get("state") != Some(&json!("running")) {
            match self.world.start(&installed.app) {
                Ok(Lifecycle::Done) => retained["phases"]["start"] = json!({"state":"running","at":now()}),
                Ok(Lifecycle::Undecided(detail)) => {
                    retained["phases"]["start"] = json!({"state":"starting","at":now()});
                    return undecided("starting", detail, &retry);
                }
                Err(error) => return undecided("starting", format!("START did not complete: {error}; nothing is repeated"), &retry),
            }
        }
        // Phase 4: the owner's route on the grain's own origin.
        let mut record = self.grain_record(&grain).ok().flatten().unwrap_or_else(|| json!({
            "protocol":"mini-apps-grain-v1","grain":grain,"app":installed.app,"owner":member,"appId":retained["appId"],
            "packageId":package_id,"rawSha256":installed.raw_sha256,"appVersion":installed.app_version,
            "indexName":retained["indexName"],"class":retained["class"],"origin":origin,"requestId":id,
            "state":"running","routes":{},"createdAt":now(),
        }));
        if record.pointer(&format!("/routes/{member}")).is_none() {
            let host = format!("{grain}.{}", self.world.domain());
            match self.world.route(&work, &installed.app, &member, &host) {
                Ok(bound) => {
                    record["routes"][member.as_str()] = route_json(&bound, &member);
                }
                Err(error) => {
                    let _ = write_json(&grain_file(&self.state, &grain), &record);
                    return undecided("routing", format!("the owner's route is not bound yet: {error}"), &retry);
                }
            }
        }
        record["state"] = json!("running");
        if let Err(e) = write_json(&grain_file(&self.state, &grain), &record).and_then(|_| self.publish_origin(&grain, &record)) {
            return undecided("stateUnavailable", e, &retry);
        }
        retained["phases"]["route"] = json!({"state":"bound","at":now()});
        retained["state"] = json!("running");
        performed("running", format!("{} installed as {grain}; open it with `mini apps open --grain {grain}`", retained["indexName"].as_str().unwrap_or("the app")), json!({
            "requestId":id,"grain":grain,"origin":origin,"class":retained["class"],"rawSha256":installed.raw_sha256,
            "signedAppId":installed.signed_app_id,"appVersion":installed.app_version,"identityNotice":IDENTITY_NOTICE,
        }))
    }

    fn origin_path(&self, grain: &str) -> PathBuf {
        self.state.join("origins").join(format!("{grain}.json"))
    }

    /// The front's table for this grain: the routes, their token hashes and
    /// the connector they are reached through. Token hashes are not secrets.
    fn publish_origin(&self, grain: &str, record: &Value) -> Result<()> {
        let dir = self.state.join("origins");
        if !dir.is_dir() {
            fs::DirBuilder::new().mode(0o755).create(&dir).map_err(|e| e.to_string())?;
        }
        let routes: Vec<Value> = record.get("routes").and_then(Value::as_object).map(|r| r.values().cloned().map(|v| json!({
            "member":v["member"],"socket":v["socket"],"browserTokenSha256":v["browserTokenSha256"],
            "bootstrapTokenSha256":v["bootstrapTokenSha256"],"apiTokenSha256":v["apiTokenSha256"],
        })).collect()).unwrap_or_default();
        let table = json!({"protocol":"mini-apps-origin-v1","grain":grain,"connector":self.state.join("edge.sock"),"routes":routes});
        let path = self.origin_path(grain);
        let bytes = serde_json::to_vec_pretty(&table).map_err(|e| e.to_string())?;
        let temp = path.with_extension("json.new");
        fs::write(&temp, &bytes).map_err(|e| e.to_string())?;
        fs::set_permissions(&temp, fs::Permissions::from_mode(0o644)).map_err(|e| e.to_string())?;
        fs::rename(&temp, &path).map_err(|e| e.to_string())
    }

    /// The edge connector: connect to a route's custodian socket for the front.
    fn connect_route(&self, grain: &str, member: &str) -> std::result::Result<UnixStream, Value> {
        if !valid_grain(grain) || !valid_member(member) {
            return Err(refused("routeRefused", "grain or member malformed"));
        }
        let Some(record) = self.grain_record(grain).map_err(|e| refused("stateUnavailable", e))? else {
            return Err(refused("unknownGrain", grain.to_owned()));
        };
        let Some(route) = record.pointer(&format!("/routes/{member}")) else {
            return Err(refused("noRoute", format!("{member} has no route on {grain}")));
        };
        let socket = PathBuf::from(route["socket"].as_str().unwrap_or(""));
        UnixStream::connect(&socket).map_err(|e| refused("routeUnavailable", format!("{}: {e}", socket.display())))
    }

    /// The edge connector's publishing verb: the grain's `www.sock`, which the
    /// resident binds in the app's state directory, the grandparent of every
    /// route directory (`apps/<app>/routes/<route>/http.sock`).
    fn connect_www(&self, grain: &str) -> std::result::Result<UnixStream, Value> {
        if !valid_grain(grain) {
            return Err(refused("routeRefused", "grain malformed"));
        }
        let Some(record) = self.grain_record(grain).map_err(|e| refused("stateUnavailable", e))? else {
            return Err(refused("unknownGrain", grain.to_owned()));
        };
        let socket = record.get("routes").and_then(Value::as_object).and_then(|routes| routes.values().next())
            .and_then(|route| route["socket"].as_str()).map(PathBuf::from)
            .ok_or_else(|| refused("noRoute", format!("{grain} has no route yet")))?;
        let routes_dir = socket.parent().and_then(Path::parent)
            .filter(|dir| dir.file_name().is_some_and(|name| name == "routes"))
            .ok_or_else(|| refused("stateUnavailable", format!("{} is not under a routes directory", socket.display())))?;
        let www = routes_dir.parent().ok_or_else(|| refused("stateUnavailable", "routes directory has no app directory"))?.join("www.sock");
        UnixStream::connect(&www).map_err(|e| refused("grainStopped", format!("{}: {e}", www.display())))
    }
}

/// The owner's role basis for one grain: the world's basis (`allAccess` on the
/// box) when the signed bridge declares no roles, role 0 when it does, as the
/// journey's `basis()` picks it. A bridge that declares roles (the oracle: role 0
/// `Researcher`, permission `query`) refuses a session whose permissions are not
/// exactly its declared one, so `allAccess` would be refused at enrolment.
fn role_basis(world: &Value, schema: &Value) -> Value {
    let declares_roles = schema.get("roles").and_then(Value::as_array).is_some_and(|r| !r.is_empty());
    if declares_roles && world.get("type").and_then(Value::as_str) == Some("allAccess") {
        json!({"type":"role","id":"0"})
    } else {
        world.clone()
    }
}

fn route_json(bound: &RouteBound, member: &str) -> Value {
    json!({"member":member,"directory":bound.directory,"socket":bound.socket,
        "browserTokenSha256":bound.browser_token_sha256,"bootstrapTokenSha256":bound.bootstrap_token_sha256,
        "apiTokenSha256":bound.api_token_sha256,"boundAt":now()})
}

// ---------------------------------------------------------- the sockets

/// The peer's uid and gid.
fn peer(stream: &UnixStream) -> Result<(u32, u32)> {
    #[cfg(target_os = "linux")]
    {
        let mut credential = unsafe { std::mem::zeroed::<libc::ucred>() };
        let mut length = std::mem::size_of::<libc::ucred>() as libc::socklen_t;
        let rc = unsafe {
            libc::getsockopt(stream.as_raw_fd(), libc::SOL_SOCKET, libc::SO_PEERCRED, (&mut credential as *mut libc::ucred).cast(), &mut length)
        };
        if rc != 0 {
            return Err("SO_PEERCRED unavailable".into());
        }
        Ok((credential.uid, credential.gid))
    }
    #[cfg(not(target_os = "linux"))]
    {
        let mut uid: libc::uid_t = 0;
        let mut gid: libc::gid_t = 0;
        if unsafe { libc::getpeereid(stream.as_raw_fd(), &mut uid, &mut gid) } != 0 {
            return Err("getpeereid unavailable".into());
        }
        Ok((uid, gid))
    }
}

/// The member name of a uid: the account `mini-s-NAME`.
fn member_of_uid(uid: u32) -> Option<String> {
    let entry = unsafe { libc::getpwuid(uid) };
    if entry.is_null() {
        return None;
    }
    let name = unsafe { std::ffi::CStr::from_ptr((*entry).pw_name) }.to_str().ok()?;
    name.strip_prefix(MEMBER_PREFIX).map(str::to_owned)
}

fn read_line(stream: &mut UnixStream) -> Result<Value> {
    stream.set_read_timeout(Some(Duration::from_secs(10))).map_err(|e| e.to_string())?;
    let mut reader = BufReader::new(stream.try_clone().map_err(|e| e.to_string())?);
    let mut line = Vec::new();
    reader.by_ref().take(MAX_LINE as u64 + 1).read_until(b'\n', &mut line).map_err(|e| e.to_string())?;
    if line.len() > MAX_LINE {
        return Err("request exceeds 256 KiB".into());
    }
    serde_json::from_slice(&line).map_err(|e| format!("request is not JSON: {e}"))
}

fn write_line(stream: &mut UnixStream, value: &Value) {
    let mut bytes = serde_json::to_vec(value).unwrap_or_default();
    bytes.push(b'\n');
    let _ = stream.set_write_timeout(Some(Duration::from_secs(10)));
    let _ = stream.write_all(&bytes);
}

/// One JSON line plus one file descriptor, `SCM_RIGHTS`.
pub(crate) fn send_with_fd(stream: &UnixStream, value: &Value, fd: std::os::unix::io::RawFd) -> Result<()> {
    let mut bytes = serde_json::to_vec(value).map_err(|e| e.to_string())?;
    bytes.push(b'\n');
    let mut iov = libc::iovec { iov_base: bytes.as_mut_ptr().cast(), iov_len: bytes.len() };
    let space = unsafe { libc::CMSG_SPACE(std::mem::size_of::<libc::c_int>() as u32) } as usize;
    let mut control = vec![0_u8; space];
    let mut msg: libc::msghdr = unsafe { std::mem::zeroed() };
    msg.msg_iov = &mut iov;
    msg.msg_iovlen = 1;
    msg.msg_control = control.as_mut_ptr().cast();
    msg.msg_controllen = space as _;
    unsafe {
        let header = libc::CMSG_FIRSTHDR(&msg);
        (*header).cmsg_level = libc::SOL_SOCKET;
        (*header).cmsg_type = libc::SCM_RIGHTS;
        (*header).cmsg_len = libc::CMSG_LEN(std::mem::size_of::<libc::c_int>() as u32) as _;
        std::ptr::write_unaligned(libc::CMSG_DATA(header).cast::<libc::c_int>(), fd);
    }
    let sent = unsafe { libc::sendmsg(stream.as_raw_fd(), &msg, 0) };
    if sent < 0 {
        return Err(format!("sendmsg: {}", std::io::Error::last_os_error()));
    }
    Ok(())
}

/// The front's side: one JSON line and, with it, the connected socket.
pub(crate) fn receive_with_fd(stream: &UnixStream) -> Result<(Value, Option<UnixStream>)> {
    let mut bytes = vec![0_u8; 16 * 1024];
    let mut iov = libc::iovec { iov_base: bytes.as_mut_ptr().cast(), iov_len: bytes.len() };
    let space = unsafe { libc::CMSG_SPACE(std::mem::size_of::<libc::c_int>() as u32) } as usize;
    let mut control = vec![0_u8; space];
    let mut msg: libc::msghdr = unsafe { std::mem::zeroed() };
    msg.msg_iov = &mut iov;
    msg.msg_iovlen = 1;
    msg.msg_control = control.as_mut_ptr().cast();
    msg.msg_controllen = space as _;
    let received = unsafe { libc::recvmsg(stream.as_raw_fd(), &mut msg, 0) };
    if received < 0 {
        return Err(format!("recvmsg: {}", std::io::Error::last_os_error()));
    }
    let value: Value = serde_json::from_slice(&bytes[..received as usize]).map_err(|e| format!("connector reply is not JSON: {e}"))?;
    let mut fd = None;
    unsafe {
        let header = libc::CMSG_FIRSTHDR(&msg);
        if !header.is_null() && (*header).cmsg_level == libc::SOL_SOCKET && (*header).cmsg_type == libc::SCM_RIGHTS {
            let raw = std::ptr::read_unaligned(libc::CMSG_DATA(header).cast::<libc::c_int>());
            if raw >= 0 {
                fd = Some(UnixStream::from_raw_fd(raw));
            }
        }
    }
    Ok((value, fd))
}

/// The gid of a group name, from the passwd database.
fn group_id(name: &str) -> Result<u32> {
    let c = std::ffi::CString::new(name).map_err(|_| "group name".to_owned())?;
    let entry = unsafe { libc::getgrnam(c.as_ptr()) };
    if entry.is_null() {
        return Err(format!("groupUnavailable: no group {name:?} on this host"));
    }
    Ok(unsafe { (*entry).gr_gid })
}

/// Bind a socket with its mode and, when a group is named, that group (the
/// unit's SupplementaryGroups makes the chgrp possible; a group this process
/// cannot resolve refuses the start, never a silently private socket).
fn bind(path: &Path, mode: u32, group: Option<&str>) -> Result<UnixListener> {
    let _ = fs::remove_file(path);
    let listener = UnixListener::bind(path).map_err(|e| format!("cannot bind {}: {e}", path.display()))?;
    if let Some(group) = group {
        let gid = group_id(group)?;
        std::os::unix::fs::chown(path, None, Some(gid)).map_err(|e| format!("cannot give {} to group {group}: {e} (the unit needs SupplementaryGroups={group})", path.display()))?;
    }
    fs::set_permissions(path, fs::Permissions::from_mode(mode)).map_err(|e| e.to_string())?;
    Ok(listener)
}

/// Serve both sockets until the process ends.
pub(crate) fn serve(worker: Arc<Worker>, members: UnixListener, edge: UnixListener, dev_member: Option<String>) -> Result<()> {
    let edge_worker = worker.clone();
    std::thread::Builder::new().name("mini-apps-edge".into()).spawn(move || {
        for stream in edge.incoming() {
            let Ok(mut stream) = stream else { continue };
            let request = match read_line(&mut stream) {
                Ok(request) => request,
                Err(e) => { write_line(&mut stream, &refused("requestRefused", e)); continue; }
            };
            let grain = request.get("grain").and_then(Value::as_str).unwrap_or("");
            let member = request.get("route").and_then(Value::as_str).unwrap_or("");
            let connected = match request.get("verb").and_then(Value::as_str) {
                Some("connect") => edge_worker.connect_route(grain, member),
                Some("www") => edge_worker.connect_www(grain),
                _ => {
                    write_line(&mut stream, &refused("unknownVerb", "the edge socket serves connect and www only"));
                    continue;
                }
            };
            match connected {
                Ok(route) => {
                    let fd = route.into_raw_fd();
                    let reply = json!({"protocol":WORKER_PROTOCOL,"decided":true,"state":"connected","detail":format!("{grain}/{member}")});
                    let _ = send_with_fd(&stream, &reply, fd);
                    unsafe { libc::close(fd) };
                }
                Err(refusal) => write_line(&mut stream, &refusal),
            }
        }
    }).map_err(|e| e.to_string())?;
    for stream in members.incoming() {
        let Ok(mut stream) = stream else { continue };
        let member = match &dev_member {
            Some(name) => Some(name.clone()),
            None => match peer(&stream) {
                Ok((uid, _)) => member_of_uid(uid),
                Err(_) => None,
            },
        };
        let Some(member) = member else {
            write_line(&mut stream, &refused("memberRefused", "the peer is not a member account (mini-s-NAME)"));
            continue;
        };
        let reply = match read_line(&mut stream) {
            Ok(request) => worker.handle(&member, &request),
            Err(e) => refused("requestRefused", e),
        };
        write_line(&mut stream, &reply);
    }
    Ok(())
}

// --------------------------------------------- the process-backed world

/// The world file the operator writes (0600): where everything is.
pub(crate) struct ProcessWorld {
    pub profile: PathBuf,
    pub spk_host: PathBuf,
    pub mini: PathBuf,
    pub host: PathBuf,
    pub config: PathBuf,
    pub operator_socket: PathBuf,
    pub public_socket: PathBuf,
    pub management_subject: String,
    pub management_key_id: String,
    pub management_key_epoch: String,
    pub management_seed: PathBuf,
    pub management_public_hex: String,
    pub tool_task: String,
    pub tool_capability: String,
    pub parent_task: String,
    pub parent_capability: String,
    pub genesis: PathBuf,
    pub quarantine: PathBuf,
    pub wanted: PathBuf,
    pub verdicts: PathBuf,
    pub identities_root: PathBuf,
    pub domain: String,
    pub nonce_file: PathBuf,
    pub role_basis: Value,
}

impl ProcessWorld {
    pub(crate) fn load(path: &Path) -> Result<Self> {
        let w = read_json(path)?;
        if w.get("protocol").and_then(Value::as_str) != Some("mini-apps-world-v1") {
            return Err("world file is not mini-apps-world-v1".into());
        }
        let p = |k: &str| -> Result<PathBuf> { Ok(PathBuf::from(text(&w, k)?)) };
        let s = |k: &str| -> Result<String> { Ok(text(&w, k)?.to_owned()) };
        let profile = p("profile")?;
        let prof = read_json(&profile)?;
        Ok(Self {
            spk_host: PathBuf::from(text(&prof, "spkHost")?),
            mini: p("mini")?,
            host: PathBuf::from(text(&prof, "miniHost")?),
            config: PathBuf::from(text(&prof, "miniConfig")?),
            operator_socket: PathBuf::from(text(&prof, "miniOperatorSocket")?),
            public_socket: p("publicSocket")?,
            management_subject: text(&prof, "managementSubject")?.to_owned(),
            management_key_id: s("managementKeyId")?,
            management_key_epoch: text(&prof, "managementKeyEpoch")?.to_owned(),
            management_seed: PathBuf::from(text(&prof, "managementSeed")?),
            management_public_hex: text(&prof, "managementPublicKeyHex")?.to_owned(),
            tool_task: s("toolTask")?,
            tool_capability: s("toolCapability")?,
            parent_task: s("parentTask")?,
            parent_capability: s("parentCapability")?,
            genesis: p("genesis")?,
            quarantine: p("quarantine")?,
            wanted: p("wanted")?,
            verdicts: p("verdicts")?,
            identities_root: PathBuf::from(text(&prof, "stateRoot")?).join("apps"),
            domain: s("domain")?,
            nonce_file: p("nonceFile")?,
            role_basis: w.get("roleBasis").cloned().unwrap_or(json!({"type":"allAccess"})),
            profile,
        })
    }

    fn nonce(&self) -> Result<u64> {
        let current = fs::read_to_string(&self.nonce_file).ok().and_then(|t| t.trim().parse::<u64>().ok()).unwrap_or(70_000_000);
        let next = current + 1000;
        fs::write(&self.nonce_file, next.to_string()).map_err(|e| e.to_string())?;
        Ok(next)
    }

    fn run(&self, program: &Path, args: &[&str], stdout: &Path) -> Result<Value> {
        let output = Command::new(program).args(args).output().map_err(|e| format!("{}: {e}", program.display()))?;
        let _ = fs::write(stdout, &output.stdout);
        let _ = fs::write(stdout.with_extension("stderr"), &output.stderr);
        if !output.status.success() {
            return Err(format!("{} {}: {}", program.display(), args.first().unwrap_or(&""), String::from_utf8_lossy(&output.stderr).trim()));
        }
        Ok(serde_json::from_slice(&output.stdout).unwrap_or(Value::Null))
    }

    fn mini(&self, work: &Path, label: &str, args: &[&str]) -> Result<Value> {
        let owned: Vec<String> = args.iter().map(|s| s.to_string()).collect();
        let refs: Vec<&str> = owned.iter().map(String::as_str).collect();
        self.run(&self.mini, &refs, &work.join(format!("{label}.stdout")))
    }

    fn confirmed(path: &Path) -> Result<Value> {
        let outcome = read_json(path)?;
        if outcome.get("type").and_then(Value::as_str) == Some("confirmed") && matches!(outcome.get("confirmation").and_then(Value::as_str), Some("installed" | "replayed")) {
            Ok(outcome)
        } else {
            Err(format!("attempt {} is not confirmed: {}", path.display(), outcome.get("type").and_then(Value::as_str).unwrap_or("?")))
        }
    }

    /// `query NAME SUBJECT TASK CAP NONCE [VIEW]`: one signed read as the management subject.
    fn query(&self, work: &Path, name: &str, task: &str, cap: &str, nonce: u64, view: &str) -> Result<(Value, Value)> {
        let intent = json!({"subject":self.management_subject,"nonce":nonce.to_string(),
            "purpose":{"type":"query","kind":"object","target":task,"view":view},
            "grants":[{"kind":"object","target":task,"capability":cap}]});
        let intent_path = work.join(format!("{name}-intent.json"));
        write_json(&intent_path, &intent)?;
        let dir = work.join(name);
        let _ = fs::remove_dir_all(&dir);
        let [h, c, s, i, k, d] = [self.host.to_str().unwrap_or(""), self.config.to_str().unwrap_or(""), self.public_socket.to_str().unwrap_or(""), intent_path.to_str().unwrap_or(""), self.management_seed.to_str().unwrap_or(""), dir.to_str().unwrap_or("")];
        self.mini(work, name, &["query", "--host", h, "--config", c, "--socket", s, "--intent", i, "--key", k, "--view", view, "--dir", d])?;
        Ok((read_json(&dir.join("view.json"))?, read_json(&dir.join("challenge.json"))?))
    }

    /// `grain_op`: a reserve on the metered tool, as the journey does before a birth.
    fn grain_op(&self, work: &Path, name: &str, task: &str, cap: &str, nonce: u64, operation: Value) -> Result<()> {
        let attempt = work.join(format!("{name}-attempt"));
        if attempt.join("outcome.json").exists() {
            return Self::confirmed(&attempt.join("outcome.json")).map(|_| ());
        }
        let (view, _) = self.query(work, &format!("{name}-before"), task, cap, nonce + 1, "resource")?;
        let intent = json!({"grain":{"task":task,"subject":self.management_subject,"capability":cap,"observeCapability":cap,
            "schemaVersion":"1","expectedTargetRoot":view["cell"]["root"],
            "context":{"operationId":nonce.to_string(),"payload":"mini apps-worker"},
            "before":{"generation":view["cell"]["grain"]["generation"],"status":view["cell"]["grain"]["status"],"remaining":view["cell"]["grain"]["remaining"],"reserved":view["cell"]["grain"]["reserved"]},
            "operation":operation,"publications":[]},
            "grants":[{"kind":"object","target":task,"capability":cap}],"intentNonce":nonce.to_string()});
        let intent_path = work.join(format!("{name}-intent.json"));
        write_json(&intent_path, &intent)?;
        let [h, c, s, i, k, d] = [self.host.to_str().unwrap_or(""), self.config.to_str().unwrap_or(""), self.public_socket.to_str().unwrap_or(""), intent_path.to_str().unwrap_or(""), self.management_seed.to_str().unwrap_or(""), attempt.to_str().unwrap_or("")];
        self.mini(work, name, &["submit", "--host", h, "--config", c, "--socket", s, "--intent", i, "--intent-kind", "grain-intent", "--key", k, "--dir", d])?;
        Self::confirmed(&attempt.join("outcome.json")).map(|_| ())
    }

    /// `birth_session`: the guest subject's session for one route.
    fn birth_session(&self, work: &Path, name: &str, app: &str, session: u64, kind: &str, cap: u64, nonce: u64) -> Result<Value> {
        let attempt = work.join(format!("{name}-attempt"));
        if attempt.join("outcome.json").exists() {
            return Self::confirmed(&attempt.join("outcome.json"));
        }
        if attempt.exists() {
            return Err(format!("birth {name} attempt is uncertain; exact recovery first"));
        }
        self.grain_op(work, &format!("{name}-reserve"), &self.tool_task, &self.tool_capability, nonce, json!({"type":"reserve","amount":"5"}))?;
        let (tool, _) = self.query(work, &format!("{name}-tool"), &self.tool_task, &self.tool_capability, nonce + 101, "resource")?;
        let (parent, _) = self.query(work, &format!("{name}-parent"), &self.parent_task, &self.parent_capability, nonce + 102, "resource")?;
        let genesis = read_json(&self.genesis)?;
        let m = &self.management_subject;
        let source = json!({"subject":m,"nonce":(nonce + 100).to_string(),
            "grants":[{"kind":"object","target":"10","capability":"55"},{"kind":"account","target":m,"capability":"42"},
                {"kind":"object","target":self.tool_task,"capability":self.tool_capability},{"kind":"object","target":self.parent_task,"capability":self.parent_capability}],
            "applicationSessionGrainBirth":{"tariff":{"base":"2","perBirth":"1"},
                "applicationSessionBirth":{"genesis":genesis,"template":{"issuer":"5","ownerBudget":"100000","lifetime":"10000"},
                    "creator":m,"nonce":(nonce + 100).to_string(),"sourceCapabilities":["42"],"funding":[],"feePayer":m,
                    "session":{"app":app,"session":session.to_string(),"descriptor":(session + 1).to_string(),"participant":m,"kind":kind,
                        "sessionOwnerCapability":cap.to_string(),"sessionControlCapability":(cap + 1).to_string(),
                        "descriptorOwnerCapability":(cap + 2).to_string(),"descriptorControlCapability":(cap + 3).to_string()}},
                "tool":{"task":self.tool_task,"capability":self.tool_capability,"observeCapability":self.tool_capability,"targetRoot":tool["cell"]["root"],
                    "before":{"generation":tool["cell"]["grain"]["generation"],"status":tool["cell"]["grain"]["status"],"remaining":tool["cell"]["grain"]["remaining"],"reserved":tool["cell"]["grain"]["reserved"]}},
                "parent":{"task":self.parent_task,"capability":self.parent_capability,"observeCapability":self.parent_capability,"targetRoot":parent["cell"]["root"],
                    "before":{"generation":parent["cell"]["grain"]["generation"],"status":parent["cell"]["grain"]["status"],"remaining":parent["cell"]["grain"]["remaining"],"reserved":parent["cell"]["grain"]["reserved"]}}}});
        let source_path = work.join(format!("{name}-source.json"));
        write_json(&source_path, &source)?;
        let author = work.join(format!("{name}-author"));
        let _ = fs::remove_dir_all(&author);
        let [h, c, s, k] = [self.host.to_str().unwrap_or(""), self.config.to_str().unwrap_or(""), self.public_socket.to_str().unwrap_or(""), self.management_seed.to_str().unwrap_or("")];
        self.mini(work, &format!("{name}-author"), &["current-session-intent", "--host", h, "--config", c, "--socket", s, "--source", source_path.to_str().unwrap_or(""), "--dir", author.to_str().unwrap_or("")])?;
        self.mini(work, &format!("{name}-submit"), &["submit", "--host", h, "--config", c, "--socket", s, "--intent", author.join("intent.bin").to_str().unwrap_or(""), "--intent-kind", "binary", "--key", k, "--dir", attempt.to_str().unwrap_or("")])?;
        Self::confirmed(&attempt.join("outcome.json"))
    }

    /// Signed-slot approval over an inspected plan: every slot must name the management key.
    fn approve(&self, plan: &Value, header: &str, base: Value) -> Result<Value> {
        let mut signers = Vec::new();
        for slot in plan.get("slots").and_then(Value::as_array).ok_or("plan has no slots")? {
            let key_id = slot.pointer("/signing/keyId").and_then(Value::as_str).unwrap_or("");
            if key_id != self.management_key_id {
                return Err(format!("signerUnavailable: the plan asks key {key_id}; the worker holds the management key {} only", self.management_key_id));
            }
            let header_hex = slot.get(header).and_then(Value::as_str).ok_or("slot lacks its header")?;
            let header_bytes = mini_sdk::hex::decode(header_hex).map_err(|e| e.0)?;
            use sha2::Digest;
            signers.push(json!({"role":slot["role"],"index":slot["index"],"keyId":key_id,"keyEpoch":slot["signing"]["keyEpoch"],
                "publicKey":self.management_public_hex,"headerSha256":hex(&sha2::Sha256::digest(&header_bytes)),"keyPath":self.management_seed}));
        }
        let mut out = base;
        out["signers"] = json!(signers);
        Ok(out)
    }

    fn sha_file(path: &Path) -> Result<String> {
        use sha2::Digest;
        Ok(hex(&sha2::Sha256::digest(fs::read(path).map_err(|e| e.to_string())?)))
    }
}

impl World for ProcessWorld {
    fn package(&self, package_id: &str) -> Result<Option<(PathBuf, String, u64)>> {
        let path = self.quarantine.join(format!("{package_id}.spk"));
        if !path.is_file() {
            return Ok(None);
        }
        let meta = fs::metadata(&path).map_err(|e| e.to_string())?;
        Ok(Some((path.clone(), Self::sha_file(&path)?, meta.len())))
    }
    fn want(&self, package_id: &str) -> Result<()> {
        fs::write(self.wanted.join(package_id), b"").map_err(|e| format!("cannot flag {package_id} as wanted: {e}"))
    }
    fn install(&self, work: &Path, source: &Path, receipt: &Path, spk: &Path, class: &str, delegation: &Path) -> Result<Installed> {
        let [p, s, r, k, d] = [self.profile.to_str().unwrap_or(""), source.to_str().unwrap_or(""), receipt.to_str().unwrap_or(""), spk.to_str().unwrap_or(""), delegation.to_str().unwrap_or("")];
        let out = self.run(&self.spk_host, &["grain", "install", p, s, r, k, "--class", class, "--management-selector", d], &work.join("install.stdout"))?;
        let delegation_doc = read_json(delegation)?;
        let app = delegation_doc.pointer("/selector/app").and_then(Value::as_str).ok_or("delegation lacks selector.app")?.to_owned();
        Ok(Installed {
            app,
            raw_sha256: out.get("rawSha256").and_then(Value::as_str).unwrap_or("").to_owned(),
            signed_app_id: out.get("signedAppId").and_then(Value::as_str).unwrap_or("").to_owned(),
            app_version: out.get("signedAppVersion").and_then(Value::as_str).unwrap_or("").to_owned(),
        })
    }
    fn start(&self, app: &str) -> Result<Lifecycle> {
        let out = Command::new(&self.spk_host).args(["grain", "start", self.profile.to_str().unwrap_or(""), app]).output().map_err(|e| e.to_string())?;
        let text = String::from_utf8_lossy(&out.stderr).into_owned();
        if out.status.success() { Ok(Lifecycle::Done) } else if text.contains("UNRESOLVED") { Ok(Lifecycle::Undecided(text.trim().to_owned())) } else { Err(text.trim().to_owned()) }
    }
    fn stop(&self, app: &str) -> Result<Lifecycle> {
        let out = Command::new(&self.spk_host).args(["grain", "stop", self.profile.to_str().unwrap_or(""), app]).output().map_err(|e| e.to_string())?;
        let text = String::from_utf8_lossy(&out.stderr).into_owned();
        if out.status.success() { Ok(Lifecycle::Done) } else if text.contains("UNRESOLVED") || text.contains("uncertain") { Ok(Lifecycle::Undecided(text.trim().to_owned())) } else { Err(text.trim().to_owned()) }
    }
    fn status(&self, app: &str) -> Result<Value> {
        let out = Command::new(&self.spk_host).args(["grain", "status", self.profile.to_str().unwrap_or(""), app]).output().map_err(|e| e.to_string())?;
        if !out.status.success() {
            return Err(String::from_utf8_lossy(&out.stderr).trim().to_owned());
        }
        serde_json::from_slice(&out.stdout).map_err(|e| e.to_string())
    }
    fn route(&self, work: &Path, app: &str, member: &str, expected_host: &str) -> Result<RouteBound> {
        // The journey's share(): session birth, ticket issue, observe delegation, route; then enroll.
        let app_n: u64 = app.parse().map_err(|_| "app is not decimal")?;
        let base = self.nonce()?;
        let n = (base % 1_000_000) as u64;
        let session = app_n * 100 + 10 + (n % 7);
        let ticket = app_n * 100 + 20 + (n % 7);
        let cap = 300_000 + (base % 100_000) * 10;
        let label = format!("route-{member}");
        self.birth_session(work, &format!("{label}-session"), app, session, "web", cap, base)?;
        let state_app = self.identities_root.join(app);
        let pkgdir = state_app.join("install").join("launch-descriptor").join("package-v1");
        let schema = read_json(&pkgdir.join("schema-inspection.json"))?;
        let launch = read_json(&state_app.join("install").join("launch-descriptor").join("launch-inspection.json"))?;
        let birth_source = read_json(&work.join("birth-source.json"))?;
        let appcap = birth_source.pointer("/applicationGrainBirth/applicationBirth/application/appOwnerCapability").and_then(Value::as_str).ok_or("birth source lacks appOwnerCapability")?.to_owned();
        let (app_state, _) = self.query(work, &format!("{label}-app-state"), app, &appcap, base + 300, "resource")?;
        let pversion = app_state["cell"]["entries"].as_array().and_then(|e| e.iter().find(|x| x["key"]["field"] == "2")).and_then(|x| x["value"].as_str()).unwrap_or("0").to_owned();
        let t = work.join(format!("{label}-ticket"));
        private_dir(&t)?;
        if !t.join("issue").join("receipt-anchor.json").exists() {
            self.grain_op(work, &format!("{label}-ticket-reserve"), &self.tool_task, &self.tool_capability, base + 400, json!({"type":"reserve","amount":"3"}))?;
            let descriptor = read_json(&pkgdir.join("descriptor-inspection.json"))?;
            let interface = descriptor["interfaces"].as_array().and_then(|i| i.iter().find(|x| x["kind"] == "web")).cloned().ok_or("package descriptor has no web interface")?;
            let m = &self.management_subject;
            let tcap = cap + ticket % 100;
            let request = json!({"spec":{"ticket":{"resource":ticket.to_string(),"scope":{"app":app,"packageVersion":pversion,
                    "packageRoot":launch["root"],"interfaceId":interface["id"],"interfaceVersion":interface["version"],"interfaceRoot":interface["root"],
                    "schemaRoot":schema["root"],"schemaVersion":schema["version"]},
                "participant":{"session":session.to_string(),"descriptorResource":(session + 1).to_string(),"kind":"web","subject":m,"origin":{"type":"human"},
                    "sessionCapability":cap.to_string(),"appObserveCapability":appcap,"ticketObserveCapability":(tcap + 2).to_string()},
                "ceiling":{"basis":role_basis(&self.role_basis, &schema),"added":[],"removed":[],"roleSchemaRoot":schema["root"],"roleVersion":schema["version"]},
                "issueNonce":(base + 500).to_string(),"notAfter":"1000000000"},
                "issuer":m,"appDelegateCapability":appcap,"ticketOwnerCapability":tcap.to_string(),"ticketControlCapability":(tcap + 1).to_string()},
                "payer":m,"funding":[],"sourceCapabilities":["42"],
                "tool":{"task":self.tool_task,"capability":self.tool_capability,"observeCapability":self.tool_capability},
                "parent":{"task":self.parent_task,"capability":self.parent_capability,"observeCapability":self.parent_capability}});
            write_json(&t.join("request.json"), &request)?;
            let _ = fs::remove_dir_all(t.join("preview"));
            let [h, c, o] = [self.host.to_str().unwrap_or(""), self.config.to_str().unwrap_or(""), self.operator_socket.to_str().unwrap_or("")];
            self.mini(work, &format!("{label}-ticket-plan"), &["grain-share-issue-plan", "--host", h, "--config", c, "--socket", o, "--request", t.join("request.json").to_str().unwrap_or(""), "--dir", t.join("preview").to_str().unwrap_or("")])?;
            let plan = read_json(&t.join("preview").join("plan-inspected.json"))?;
            let inspected = read_json(&t.join("preview").join("request-inspected.json"))?;
            let approval = self.approve(&plan, "header", json!({"type":"minidregg-grain-share-issue-approval-v1","requestSha256":Self::sha_file(&t.join("preview").join("request.bin"))?,
                "canonicalSpec":inspected["canonicalSpec"],"issuer":inspected["spec"]["issuer"],"participantSubject":inspected["spec"]["ticket"]["participant"]["subject"],
                "appDelegateCapability":inspected["spec"]["appDelegateCapability"],"ticketResource":inspected["spec"]["ticket"]["resource"],
                "payer":inspected["payer"],"funding":inspected["funding"],"sourceCapabilities":inspected["sourceCapabilities"],"tool":inspected["tool"],"parent":inspected["parent"]}))?;
            write_json(&t.join("approval.json"), &approval)?;
            if !t.join("issue").exists() {
                self.mini(work, &format!("{label}-ticket-prepare"), &["grain-share-issue-prepare", "--host", h, "--config", c, "--socket", o, "--request", t.join("request.json").to_str().unwrap_or(""), "--approval", t.join("approval.json").to_str().unwrap_or(""), "--dir", t.join("issue").to_str().unwrap_or("")])?;
            }
            if !t.join("issue").join("submit-marker.json").exists() {
                let _ = self.mini(work, &format!("{label}-ticket-submit"), &["grain-share-issue-submit", "--socket", o, "--attempt", t.join("issue").to_str().unwrap_or("")]);
            }
            self.mini(work, &format!("{label}-ticket-lookup"), &["grain-share-issue-lookup", "--socket", o, "--attempt", t.join("issue").to_str().unwrap_or("")])?;
        }
        // The route request: the management key signs for the grain's guest subject (v1).
        let session_source = work.join(format!("{label}-session-author")).join("source.json");
        let session_receipt = work.join(format!("{label}-session-attempt")).join("outcome.json");
        let route_name = format!("member-{member}");
        let request = json!({"protocol":"mini-spk-grain-route-request-v1","name":route_name,"expectedHost":expected_host,
            "displayName":member,"preferredHandle":member,"sessionSource":session_source,"sessionReceipt":session_receipt,
            "ticketIssue":t.join("issue"),
            "participantKey":{"keyId":self.management_key_id,"keyEpoch":self.management_key_epoch,"publicKeyHex":self.management_public_hex,"seedPath":self.management_seed}});
        let request_path = work.join(format!("{label}-route-request.json"));
        write_json(&request_path, &request)?;
        let bound = self.run(&self.spk_host, &["grain", "route", self.profile.to_str().unwrap_or(""), app, request_path.to_str().unwrap_or("")], &work.join(format!("{label}-route.stdout")))?;
        let directory = PathBuf::from(bound.get("directory").and_then(Value::as_str).ok_or("grain route reported no directory")?);
        let custodian = read_json(&directory.join("custodian.json"))?;
        Ok(RouteBound {
            socket: PathBuf::from(bound.get("socket").and_then(Value::as_str).unwrap_or("")),
            browser_token_sha256: text(&custodian, "browserTokenSha256")?.to_owned(),
            bootstrap_token_sha256: text(&custodian, "bootstrapTokenSha256")?.to_owned(),
            api_token_sha256: text(&custodian, "apiTokenSha256")?.to_owned(),
            directory,
        })
    }
    fn export(&self, app: &str, out: &Path) -> Result<()> {
        let output = Command::new(&self.spk_host).args(["grain", "export", self.profile.to_str().unwrap_or(""), app, out.to_str().unwrap_or("")]).output().map_err(|e| e.to_string())?;
        if output.status.success() { Ok(()) } else { Err(String::from_utf8_lossy(&output.stderr).trim().to_owned()) }
    }
    fn identities(&self, app: &str) -> Result<Vec<Value>> {
        let dir = self.identities_root.join(app).join("identities");
        let mut out = Vec::new();
        let Ok(entries) = fs::read_dir(&dir) else { return Ok(out) };
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().into_owned();
            let Some(token) = name.strip_suffix(".json") else { continue };
            if token.len() != 64 { continue; }
            let record = read_json(&entry.path())?;
            if record.get("protocol").and_then(Value::as_str) != Some("mini-spk-saved-identity-v1") { continue; }
            out.push(json!({"token":token,"identityId":record["identityId"],"displayName":record["displayName"],"preferredHandle":record["preferredHandle"],
                "savedAt":record["savedAt"],"revoked":record.get("revoked").and_then(Value::as_bool).unwrap_or(false)}));
        }
        out.sort_by(|a, b| a["token"].as_str().cmp(&b["token"].as_str()));
        Ok(out)
    }
    fn revoke_identity(&self, app: &str, token: &str) -> Result<()> {
        let path = self.identities_root.join(app).join("identities").join(format!("{token}.json"));
        let mut record = read_json(&path).map_err(|_| format!("unknownToken: {app} holds no identity {}…", &token[..8]))?;
        record["revoked"] = json!(true);
        record["revokedAt"] = json!(now());
        write_json(&path, &record)
    }
    fn verdict(&self, package_id: &str, verdict: &Value) -> Result<()> {
        if !self.verdicts.is_dir() {
            fs::DirBuilder::new().mode(0o755).recursive(true).create(&self.verdicts).map_err(|e| e.to_string())?;
        }
        let path = self.verdicts.join(format!("{package_id}.json"));
        let temp = path.with_extension("json.new");
        fs::write(&temp, serde_json::to_vec_pretty(verdict).map_err(|e| e.to_string())?).map_err(|e| e.to_string())?;
        fs::set_permissions(&temp, fs::Permissions::from_mode(0o644)).map_err(|e| e.to_string())?;
        fs::rename(&temp, &path).map_err(|e| e.to_string())
    }
    fn domain(&self) -> &str {
        &self.domain
    }
}

/// `mini apps-worker --state DIR --world WORLD.json [--member-socket PATH] [--edge-socket PATH]
/// [--member-group mini-sessions] [--edge-group mini-edge] [--dev-member NAME]`
pub(crate) fn run(mut args: Args) -> Result<()> {
    let state = absolute(&path(args.required("state")?))?;
    let world_path = absolute(&path(args.required("world")?))?;
    // `--socket` is the client's Host-socket option, consumed before dispatch: the member socket has its own name.
    let socket = args.optional("member-socket").map(|v| absolute(&path(v))).transpose()?.unwrap_or_else(|| PathBuf::from("/run/mini-apps/worker.sock"));
    let edge = args.optional("edge-socket").map(|v| absolute(&path(v))).transpose()?.unwrap_or_else(|| state.join("edge.sock"));
    let dev_member = args.optional("dev-member").map(|v| v.into_string().map_err(|_| "--dev-member must be UTF-8".to_owned())).transpose()?;
    let member_group = args.optional("member-group").map(|v| v.into_string().map_err(|_| "--member-group must be UTF-8".to_owned())).transpose()?;
    let edge_group = args.optional("edge-group").map(|v| v.into_string().map_err(|_| "--edge-group must be UTF-8".to_owned())).transpose()?;
    args.finish()?;
    private_dir(&state)?;
    let world = ProcessWorld::load(&world_path)?;
    let worker = Arc::new(Worker::open(state, Box::new(world))?);
    let members = bind(&socket, 0o660, member_group.as_deref())?;
    let edge_listener = bind(&edge, 0o660, edge_group.as_deref())?;
    println!("mini apps-worker: members at {}, edge connector at {}", socket.display(), edge.display());
    std::io::stdout().flush().map_err(|e| e.to_string())?;
    serve(worker, members, edge_listener, dev_member)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    use std::sync::Mutex as StdMutex;

    struct FakeWorld {
        quarantine: PathBuf,
        wanted: RefCell<Vec<String>>,
        installs: RefCell<u32>,
        stops: RefCell<u32>,
        routes: RefCell<Vec<String>>,
        stop_undecided: RefCell<bool>,
        identities: RefCell<Vec<Value>>,
        verdicts: RefCell<Vec<(String, Value)>>,
        route_dir: PathBuf,
    }
    unsafe impl Send for FakeWorld {}
    unsafe impl Sync for FakeWorld {}

    impl World for FakeWorld {
        fn package(&self, package_id: &str) -> Result<Option<(PathBuf, String, u64)>> {
            let path = self.quarantine.join(format!("{package_id}.spk"));
            if !path.exists() { return Ok(None); }
            Ok(Some((path, format!("{package_id}{}", "0".repeat(32)), 1000)))
        }
        fn want(&self, package_id: &str) -> Result<()> { self.wanted.borrow_mut().push(package_id.into()); Ok(()) }
        fn install(&self, _: &Path, source: &Path, receipt: &Path, _: &Path, class: &str, delegation: &Path) -> Result<Installed> {
            *self.installs.borrow_mut() += 1;
            assert!(source.exists() && receipt.exists() && delegation.exists());
            assert_eq!(class, "S");
            Ok(Installed { app: "4501".into(), raw_sha256: "ab".repeat(32), signed_app_id: "7qvcjh7gk0rzdx1s3c8gufd288sesf6vvdt297756xcv4q8xxvhh".into(), app_version: "5".into() })
        }
        fn start(&self, _: &str) -> Result<Lifecycle> { Ok(Lifecycle::Done) }
        fn stop(&self, _: &str) -> Result<Lifecycle> {
            *self.stops.borrow_mut() += 1;
            if *self.stop_undecided.borrow() { Ok(Lifecycle::Undecided("STOP in progress".into())) } else { Ok(Lifecycle::Done) }
        }
        fn status(&self, _: &str) -> Result<Value> { Ok(json!({"runs":[{"generation":"2","state":"running"}]})) }
        fn route(&self, _: &Path, _: &str, member: &str, host: &str) -> Result<RouteBound> {
            self.routes.borrow_mut().push(format!("{member}@{host}"));
            let dir = self.route_dir.join(member);
            fs::create_dir_all(&dir).unwrap();
            fs::write(dir.join("bootstrap.token"), "b0".repeat(32)).unwrap();
            Ok(RouteBound { directory: dir.clone(), socket: dir.join("http.sock"), browser_token_sha256: "1".repeat(64), bootstrap_token_sha256: "2".repeat(64), api_token_sha256: "3".repeat(64) })
        }
        fn export(&self, _: &str, out: &Path) -> Result<()> { fs::create_dir_all(out).unwrap(); fs::write(out.join("manifest.sig"), b"sig").unwrap(); Ok(()) }
        fn identities(&self, _: &str) -> Result<Vec<Value>> { Ok(self.identities.borrow().clone()) }
        fn revoke_identity(&self, _: &str, token: &str) -> Result<()> {
            let mut list = self.identities.borrow_mut();
            let Some(record) = list.iter_mut().find(|r| r["token"] == token) else { return Err("unknownToken".into()) };
            record["revoked"] = json!(true);
            Ok(())
        }
        fn verdict(&self, package_id: &str, verdict: &Value) -> Result<()> { self.verdicts.borrow_mut().push((package_id.into(), verdict.clone())); Ok(()) }
        fn domain(&self) -> &str { "demo.test" }
    }

    static SERIAL: StdMutex<()> = StdMutex::new(());

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("mini-apps-worker-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    const PKG: &str = "f0277a5dce2e1c6af0cce188241411a4";
    const APP: &str = "7qvcjh7gk0rzdx1s3c8gufd288sesf6vvdt297756xcv4q8xxvhh";

    fn install_request(id: &str) -> Value {
        json!({"protocol":WORKER_PROTOCOL,"verb":"install","requestId":id,"appId":APP,"packageId":PKG,"class":"auto","indexName":"Hacker Slides",
            "birthSource":{"applicationGrainBirth":{"applicationBirth":{"application":{"appOwnerCapability":"976001"}}}},
            "birthReceipt":{"type":"confirmed","confirmation":"installed","acceptedCount":"40"},
            "delegation":{"protocol":"mini-spk-grain-lifecycle-delegation-v1","appOwner":"12","managementSubject":"8","selector":{"app":"4501"}}})
    }

    fn worker(name: &str) -> (Worker, PathBuf) {
        let root = scratch(name);
        let quarantine = root.join("quarantine");
        fs::create_dir_all(&quarantine).unwrap();
        let world = FakeWorld { quarantine: quarantine.clone(), wanted: RefCell::new(vec![]), installs: RefCell::new(0), stops: RefCell::new(0), routes: RefCell::new(vec![]), stop_undecided: RefCell::new(false), identities: RefCell::new(vec![json!({"token":"c".repeat(64),"displayName":"alice","revoked":false})]), verdicts: RefCell::new(vec![]), route_dir: root.join("routes") };
        (Worker::open(root.join("state"), Box::new(world)).unwrap(), root)
    }

    fn fake(w: &Worker) -> &FakeWorld {
        // The test world is the only World this test built.
        unsafe { &*(w.world.as_ref() as *const dyn World as *const FakeWorld) }
    }

    #[test]
    fn apps_worker_install_waits_for_the_package_then_installs_once_and_routes_the_owner() {
        let _serial = SERIAL.lock().unwrap();
        let (w, root) = worker("install");
        let id = "0".repeat(32);
        // No package yet: undecided, the fetcher is asked, the request is retained.
        let first = w.handle("alice", &install_request(&id));
        assert_eq!(first["decided"], false);
        assert_eq!(first["state"], "fetching");
        assert_eq!(fake(&w).wanted.borrow().as_slice(), [PKG]);
        assert!(request_file(&w.state, &id).exists());
        // The package arrives; the exact retry completes: install once, start, the owner's route, the origin table.
        fs::write(root.join("quarantine").join(format!("{PKG}.spk")), b"spk").unwrap();
        let retry = w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"retry","requestId":id}));
        assert_eq!(retry["decided"], true, "{retry}");
        assert_eq!(retry["state"], "running");
        assert_eq!(retry["receipt"]["grain"], "a4501");
        assert_eq!(retry["receipt"]["origin"], "https://a4501.demo.test");
        assert_eq!(retry["receipt"]["identityNotice"], IDENTITY_NOTICE);
        assert_eq!(*fake(&w).installs.borrow(), 1);
        assert_eq!(fake(&w).routes.borrow().as_slice(), ["alice@a4501.demo.test"]);
        let origin = read_json(&w.state.join("origins").join("a4501.json")).unwrap();
        assert_eq!(origin["routes"][0]["member"], "alice");
        assert_eq!(origin["routes"][0]["bootstrapTokenSha256"], "2".repeat(64));
        assert_eq!(fake(&w).verdicts.borrow()[0].1["verdict"], "verified");
        // A second retry of the same id repeats nothing.
        let again = w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"retry","requestId":id}));
        assert_eq!(again["state"], "running");
        assert_eq!(*fake(&w).installs.borrow(), 1);
        assert_eq!(fake(&w).routes.borrow().len(), 1);
        // Another member cannot retry alice's request or act on her grain.
        let bob = w.handle("bob", &json!({"protocol":WORKER_PROTOCOL,"verb":"retry","requestId":id}));
        assert_eq!(bob["refused"], "notOwner");
        assert_eq!(w.handle("bob", &json!({"protocol":WORKER_PROTOCOL,"verb":"stop","grain":"a4501"}))["refused"], "notOwner");
        assert_eq!(w.handle("bob", &json!({"protocol":WORKER_PROTOCOL,"verb":"open","grain":"a4501"}))["refused"], "notOwner");
        // open hands the owner the one-time bootstrap token; list and status show the grain.
        let open = w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"open","grain":"a4501"}));
        assert_eq!(open["receipt"]["bootstrapToken"], "b0".repeat(32));
        let list = w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"list"}));
        assert_eq!(list["receipt"]["grains"][0]["grain"], "a4501");
        assert!(w.handle("bob", &json!({"protocol":WORKER_PROTOCOL,"verb":"list"}))["receipt"]["grains"].as_array().unwrap().is_empty());
        let status = w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"status","grain":"a4501"}));
        assert_eq!(status["state"], "running");
        assert_eq!(status["receipt"]["identities"][0]["displayName"], "alice");
        // share gives bob his own route; then bob may open and read status but not stop.
        let share = w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"share","grain":"a4501","to":"bob"}));
        assert_eq!(share["state"], "shared", "{share}");
        assert_eq!(fake(&w).routes.borrow().len(), 2);
        assert_eq!(w.handle("bob", &json!({"protocol":WORKER_PROTOCOL,"verb":"open","grain":"a4501"}))["state"], "open");
        assert_eq!(w.handle("bob", &json!({"protocol":WORKER_PROTOCOL,"verb":"stop","grain":"a4501"}))["refused"], "notOwner");
        assert_eq!(read_json(&w.state.join("origins").join("a4501.json")).unwrap()["routes"].as_array().unwrap().len(), 2);
        // identities and revoke by token; a malformed token refused by name.
        assert_eq!(w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"revoke-identity","grain":"a4501","token":"zz"}))["refused"], "tokenRefused");
        let revoked = w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"revoke-identity","grain":"a4501","token":"c".repeat(64)}));
        assert_eq!(revoked["state"], "revoked");
        assert_eq!(w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"identities","grain":"a4501"}))["receipt"]["identities"][0]["revoked"], true);
        // STOP is honest: undecided with its exact retry while the lifecycle runs; decided afterwards.
        *fake(&w).stop_undecided.borrow_mut() = true;
        let stopping = w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"stop","grain":"a4501"}));
        assert_eq!(stopping["decided"], false);
        assert_eq!(stopping["exactRetry"], "mini apps status --grain a4501");
        *fake(&w).stop_undecided.borrow_mut() = false;
        assert_eq!(w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"stop","grain":"a4501"}))["state"], "stopped");
        let export = w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"export","grain":"a4501"}));
        assert_eq!(export["state"], "exported");
        let delete = w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"delete","grain":"a4501"}));
        assert_eq!(delete["state"], "deleted");
        assert_eq!(delete["receipt"]["volumeRetained"], true);
        assert!(!w.state.join("origins").join("a4501.json").exists());
        assert_eq!(w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"open","grain":"a4501"}))["refused"], "noRoute");
        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn apps_worker_refuses_by_name_before_any_effect() {
        let _serial = SERIAL.lock().unwrap();
        let (w, root) = worker("refusals");
        let id = "1".repeat(32);
        let mut no_docs = install_request(&id);
        no_docs.as_object_mut().unwrap().remove("delegation");
        assert_eq!(w.handle("alice", &no_docs)["refused"], "birthRequired");
        let mut bad_app = install_request(&id);
        bad_app["appId"] = json!("short");
        assert_eq!(w.handle("alice", &bad_app)["refused"], "unknownApp");
        let mut bad_class = install_request(&id);
        bad_class["class"] = json!("XL");
        assert_eq!(w.handle("alice", &bad_class)["refused"], "classRefused");
        let mut unconfirmed = install_request(&id);
        unconfirmed["birthReceipt"] = json!({"type":"refused"});
        assert_eq!(w.handle("alice", &unconfirmed)["refused"], "birthRequired");
        assert_eq!(w.handle("alice", &json!({"protocol":"other","verb":"list"}))["refused"], "protocolRefused");
        assert_eq!(w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"dance"}))["refused"], "unknownVerb");
        assert_eq!(w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"retry","requestId":id}))["refused"], "unknownRequest");
        assert_eq!(w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"status","grain":"4501"}))["refused"], "grainRefused");
        assert_eq!(w.handle("alice", &json!({"protocol":WORKER_PROTOCOL,"verb":"status","grain":"a9"}))["refused"], "unknownGrain");
        assert_eq!(w.handle("Bad Name", &json!({"protocol":WORKER_PROTOCOL,"verb":"list"}))["refused"], "memberRefused");
        assert_eq!(*fake(&w).installs.borrow(), 0);
        assert!(fake(&w).wanted.borrow().is_empty());
        let _ = fs::remove_dir_all(&root);
    }

    #[test]
    fn apps_worker_edge_connector_hands_the_route_socket_over_scm_rights() {
        let _serial = SERIAL.lock().unwrap();
        let (w, root) = worker("edge");
        let id = "2".repeat(32);
        fs::write(root.join("quarantine").join(format!("{PKG}.spk")), b"spk").unwrap();
        assert_eq!(w.handle("alice", &install_request(&id))["state"], "running");
        // A fake custodian listens where the route record says.
        let socket = root.join("routes").join("alice").join("http.sock");
        let custodian = UnixListener::bind(&socket).unwrap();
        let worker = Arc::new(w);
        let edge_path = root.join("edge.sock");
        let members_path = root.join("worker.sock");
        let edge = bind(&edge_path, 0o600, None).unwrap();
        let members = bind(&members_path, 0o600, None).unwrap();
        assert!(bind(&root.join("none.sock"), 0o600, Some("no-such-group-anywhere")).unwrap_err().starts_with("groupUnavailable"));
        let served = worker.clone();
        std::thread::spawn(move || { let _ = serve(served, members, edge, Some("alice".into())); });
        // The front asks for alice's route and receives a connected socket.
        let mut front = UnixStream::connect(&edge_path).unwrap();
        front.write_all(br#"{"verb":"connect","grain":"a4501","route":"alice"}"#).unwrap();
        front.write_all(b"\n").unwrap();
        let (reply, fd) = receive_with_fd(&front).unwrap();
        assert_eq!(reply["state"], "connected", "{reply}");
        let mut handed = fd.expect("a socket arrived with the reply");
        let (mut app_side, _) = custodian.accept().unwrap();
        handed.write_all(b"GET / HTTP/1.1\r\n\r\n").unwrap();
        let mut head = [0_u8; 18];
        app_side.read_exact(&mut head).unwrap();
        assert_eq!(&head, b"GET / HTTP/1.1\r\n\r\n");
        // The publishing verb reaches the app directory's www.sock, the routes
        // directory's parent; with the resident gone it is grainStopped by name.
        let mut front = UnixStream::connect(&edge_path).unwrap();
        front.write_all(b"{\"verb\":\"www\",\"grain\":\"a4501\"}\n").unwrap();
        let (reply, fd) = receive_with_fd(&front).unwrap();
        assert_eq!(reply["refused"], "grainStopped", "{reply}");
        assert!(fd.is_none());
        let publishing = UnixListener::bind(root.join("www.sock")).unwrap();
        let mut front = UnixStream::connect(&edge_path).unwrap();
        front.write_all(b"{\"verb\":\"www\",\"grain\":\"a4501\"}\n").unwrap();
        let (reply, fd) = receive_with_fd(&front).unwrap();
        assert_eq!(reply["state"], "connected", "{reply}");
        let mut handed = fd.expect("the publishing socket arrived");
        let (mut site, _) = publishing.accept().unwrap();
        handed.write_all(b"HEAD / HTTP/1.0\r\n\r\n").unwrap();
        let mut head = [0_u8; 19];
        site.read_exact(&mut head).unwrap();
        assert_eq!(&head, b"HEAD / HTTP/1.0\r\n\r\n");
        // An unknown route is refused by name with no socket.
        let mut front = UnixStream::connect(&edge_path).unwrap();
        front.write_all(br#"{"verb":"connect","grain":"a4501","route":"mallory"}"#).unwrap();
        front.write_all(b"\n").unwrap();
        let (reply, fd) = receive_with_fd(&front).unwrap();
        assert_eq!(reply["refused"], "noRoute");
        assert!(fd.is_none());
        // The member socket in --dev-member mode answers a list.
        let mut member = UnixStream::connect(&members_path).unwrap();
        member.write_all(format!("{}\n", json!({"protocol":WORKER_PROTOCOL,"verb":"list"})).as_bytes()).unwrap();
        let mut reader = BufReader::new(member);
        let mut line = String::new();
        reader.read_line(&mut line).unwrap();
        let listed: Value = serde_json::from_str(&line).unwrap();
        assert_eq!(listed["receipt"]["grains"][0]["grain"], "a4501");
        let _ = fs::remove_dir_all(&root);
    }
}
