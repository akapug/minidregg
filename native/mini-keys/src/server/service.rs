//! Service bearers: the operator's bearer for one HTTPS service, sent by the
//! broker on behalf of the accounts its row names. The caller never holds it.
//!
//! The service table (`mini-service-table-v1`, root-owned like the provider
//! table) names, per row: one origin, the path prefixes and methods a caller
//! may use under it, the largest request body, and the uids that may send with
//! the row's bearer. The bearer itself is sealed like a pool key (the
//! operator's namespace, under the row's name, which no provider row may
//! share) and no operation returns it.
//!
//! The provider path's rules hold, read for a service:
//!
//! * `service-authorize` checks the row (uid, method, path) and that the
//!   bearer opens, then writes a durable single-use ticket bound to the
//!   caller's uid, the row, the method, the exact path and the body digest.
//!   An exact retry while the ticket is live gets the same ticket. Nothing is
//!   counted: a service row has no caps.
//! * `service-forward` sends that exact body and returns the whole reply. It
//!   is journaled exactly as `provider-forward` ([`super::provider::journaled`]):
//!   the answer is retained before the ticket is answered, an exact retry
//!   replays it, and a send stopped midway is uncertain and never repeated. So
//!   a retried post is never posted twice; two posts of the same body are two
//!   tickets.
//! * `service-stream` sends the request and relays the reply as it arrives
//!   (a server-sent event stream may stay open for hours). It is journaled the
//!   same way, but what it retains is the stream's closing summary, never its
//!   bytes: an exact retry of a streamed ticket replays that summary and does
//!   not reconnect. A reconnect is a new ticket.
//!
//! The row says which reply each path has: a path under `paths` comes back
//! whole (and is replayable), a path under `streams` is streamed (and is not).
//! Each operation refuses the other's paths.
//!
//! Withholding: a whole reply that carries the bearer is withheld, as for a
//! provider. A streamed reply is read as it passes ([`Echo`]): it is cut
//! before any byte of an occurrence of the bearer reaches the caller, also
//! when the occurrence spans two reads.
//!
//! The stream's frames, after the request frame: one
//! `{"ok":true,"stream":"head","status":N,"headers":HEX}`, then any number of
//! `{"ok":true,"stream":"data","body":HEX}`, then one closing frame: the
//! summary `{"ok":true,"stream":"end","complete":B,"bytes":N,...}` (with
//! `"withheld":true` when the stream was cut) or a named refusal. The caller
//! ends a stream by shutting down its side of the socket (or sending any
//! byte); the broker stops the upstream call and sends the summary.
use super::credentials::{self, Namespace, Secret};
use super::provider::{self, exact, journaled, number, sha_field, text, NotAdmitted, Plan, Sent, Settle};
use super::ticket::{self, State, Ticket};
use super::{native, refuse, store_refusal, Broker, Credentials, Note, Refusal, EXCHANGE};
use crate::peer::Peer;
use crate::wire;
use serde_json::{json, Value};
use std::io::{Read, Write};
use std::os::fd::AsRawFd;
use std::os::unix::fs::{MetadataExt, PermissionsExt};
use std::os::unix::net::UnixStream;
use std::os::unix::process::CommandExt;
use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

pub const TABLE_TYPE: &str = "mini-service-table-v1";
const MAX_TABLE: u64 = 65_536;
const MAX_ROWS: usize = 32;
const MAX_PREFIXES: usize = 8;
const MAX_UIDS: usize = 64;
const MAX_PATH: usize = 2048;
const MAX_EVENT_ID: usize = 256;
const METHODS: [&str; 5] = ["GET", "POST", "PUT", "PATCH", "DELETE"];
/// One read of a streamed reply, and so at most one data frame's body.
const CHUNK: usize = 16_384;
static SEQ: AtomicU64 = AtomicU64::new(0);

/// How a path's reply comes back.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Reply {
    /// Whole, retained, replayed to an exact retry (`service-forward`).
    Whole,
    /// Relayed as it arrives, never retained (`service-stream`).
    Stream,
}

impl Reply {
    pub fn name(self) -> &'static str {
        match self {
            Reply::Whole => "whole",
            Reply::Stream => "stream",
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ServiceRow {
    pub name: String,
    /// `https://host[:port]` (plain `http` only on loopback); no path.
    pub origin: String,
    /// Path prefixes whose replies come back whole.
    pub paths: Vec<String>,
    /// Path prefixes whose replies are streamed.
    pub streams: Vec<String>,
    pub methods: Vec<String>,
    /// The largest request body the broker sends for this row.
    pub max_request: usize,
    /// The accounts that may send with this row's bearer.
    pub uids: Vec<u32>,
}

pub struct ServiceTable {
    pub rows: Vec<ServiceRow>,
}

/// `scheme://host[:port]` and nothing else: verified HTTPS, or plain HTTP on loopback.
pub fn validate_origin(origin: &str) -> Result<(), String> {
    let (scheme, authority) = origin.split_once("://").ok_or("origin lacks a scheme")?;
    if authority.is_empty()
        || authority.contains("..")
        || authority.bytes().any(|b| !(b.is_ascii_alphanumeric() || b".-:[]".contains(&b)))
    {
        return Err("origin must be scheme://host[:port] and nothing else".into());
    }
    match scheme {
        "https" => Ok(()),
        "http" if credentials::is_loopback_http(origin) => Ok(()),
        "http" => Err("plain HTTP origin is permitted only on loopback".into()),
        _ => Err("origin must use verified HTTPS".into()),
    }
}

fn plain_segment(s: &str) -> bool {
    !s.is_empty() && s != "." && s != ".." && s.bytes().all(|b| b.is_ascii_alphanumeric() || b"-._~".contains(&b))
}

/// `/`, or `/`-separated plain segments (letters, digits, `-._~`; never `.`
/// or `..`), with no empty segment and no escape: what the broker checks is
/// what the server routes.
fn plain_path(p: &str) -> bool {
    p == "/" || p.strip_prefix('/').is_some_and(|rest| rest.split('/').all(plain_segment))
}

/// A request path: a plain path, then optionally `?` and a query of plain
/// characters. Returns the path without its query.
pub fn request_path(path: &str) -> Result<&str, String> {
    if path.len() > MAX_PATH {
        return Err(format!("path exceeds {MAX_PATH} bytes"));
    }
    let (p, query) = match path.split_once('?') {
        Some((p, q)) => (p, Some(q)),
        None => (path, None),
    };
    if !plain_path(p) {
        return Err("path must be / or plain segments (letters, digits, -._~; never . or ..), no empty segment, no escape".into());
    }
    if query.is_some_and(|q| q.is_empty() || !q.bytes().all(|b| b.is_ascii_alphanumeric() || b"-._~%&=+,:@/!$*;".contains(&b))) {
        return Err("query must be nonempty plain characters".into());
    }
    Ok(p)
}

/// `path` is `prefix` or below it, segment by segment.
fn under(path: &str, prefix: &str) -> bool {
    prefix == "/" || path == prefix || path.strip_prefix(prefix).is_some_and(|rest| rest.starts_with('/'))
}

fn prefixes(entry: &Value, key: &str, name: &str) -> Result<Vec<String>, String> {
    match entry.get(key) {
        None => Ok(vec![]),
        Some(Value::Array(items)) if items.len() <= MAX_PREFIXES => items
            .iter()
            .map(|p| p.as_str().filter(|p| plain_path(p)).map(str::to_owned).ok_or_else(|| format!("service {name}: {key} must be plain path prefixes")))
            .collect(),
        Some(_) => Err(format!("service {name}: {key} must list at most {MAX_PREFIXES} prefixes")),
    }
}

impl ServiceTable {
    pub fn parse(bytes: &[u8]) -> Result<Self, String> {
        let value: Value = serde_json::from_slice(bytes).map_err(|e| format!("service table JSON: {e}"))?;
        super::fields(&value, &["type", "services"], "service table")?;
        if value.get("type").and_then(Value::as_str) != Some(TABLE_TYPE) {
            return Err(format!("service table type must be {TABLE_TYPE}"));
        }
        let entries = value
            .get("services")
            .and_then(Value::as_array)
            .filter(|rows| !rows.is_empty() && rows.len() <= MAX_ROWS)
            .ok_or("service table needs 1..32 services")?;
        let mut rows: Vec<ServiceRow> = Vec::with_capacity(entries.len());
        for entry in entries {
            super::fields(entry, &["name", "origin", "paths", "streams", "methods", "maxRequestBytes", "uids"], "service row")?;
            let name = entry.get("name").and_then(Value::as_str).ok_or("service row needs a name")?.to_owned();
            credentials::provider_name(&name).map_err(|_| "service name must be [a-z][a-z0-9-]{0,31}".to_owned())?;
            if rows.iter().any(|r| r.name == name) {
                return Err(format!("service table repeats {name}"));
            }
            let origin = entry.get("origin").and_then(Value::as_str).ok_or_else(|| format!("service {name}: origin must be a string"))?.to_owned();
            validate_origin(&origin).map_err(|e| format!("service {name}: {e}"))?;
            let paths = prefixes(entry, "paths", &name)?;
            let streams = prefixes(entry, "streams", &name)?;
            if paths.is_empty() && streams.is_empty() {
                return Err(format!("service {name}: paths or streams must name a prefix"));
            }
            // One answer per path: a whole prefix and a streamed one never nest.
            if paths.iter().any(|p| streams.iter().any(|s| under(p, s) || under(s, p))) {
                return Err(format!("service {name}: a prefix in paths and one in streams overlap"));
            }
            let methods: Vec<String> = entry
                .get("methods")
                .and_then(Value::as_array)
                .filter(|m| !m.is_empty() && m.len() <= METHODS.len())
                .ok_or_else(|| format!("service {name}: methods must list 1..5 of {METHODS:?}"))?
                .iter()
                .map(|m| m.as_str().filter(|m| METHODS.contains(m)).map(str::to_owned).ok_or_else(|| format!("service {name}: methods must be among {METHODS:?}")))
                .collect::<Result<_, _>>()?;
            if methods.iter().enumerate().any(|(i, m)| methods[..i].contains(m)) {
                return Err(format!("service {name}: methods repeat"));
            }
            let max_request = entry
                .get("maxRequestBytes")
                .and_then(Value::as_str)
                .filter(|v| !v.is_empty() && v.len() <= 8 && v.bytes().all(|b| b.is_ascii_digit()) && !(v.len() > 1 && v.starts_with('0')))
                .and_then(|v| v.parse::<usize>().ok())
                .filter(|n| (1..=wire::MAX_PROVIDER_REQUEST).contains(n))
                .ok_or_else(|| format!("service {name}: maxRequestBytes must be a canonical decimal 1..{}", wire::MAX_PROVIDER_REQUEST))?;
            let uids: Vec<u32> = entry
                .get("uids")
                .and_then(Value::as_array)
                .filter(|u| !u.is_empty() && u.len() <= MAX_UIDS)
                .ok_or_else(|| format!("service {name}: uids must name 1..{MAX_UIDS} accounts"))?
                .iter()
                .map(|u| u.as_u64().filter(|n| *n <= u32::MAX as u64).map(|n| n as u32).ok_or_else(|| format!("service {name}: uids must be numeric")))
                .collect::<Result<_, _>>()?;
            rows.push(ServiceRow { name, origin, paths, streams, methods, max_request, uids });
        }
        Ok(ServiceTable { rows })
    }

    /// Owned by root (or the broker config's owner), writable by nobody else.
    pub fn load(path: &Path, trust_owner: u32) -> Result<Self, String> {
        let meta = std::fs::symlink_metadata(path).map_err(|e| format!("service table: {e}"))?;
        if !meta.file_type().is_file() || (meta.uid() != 0 && meta.uid() != trust_owner) || meta.permissions().mode() & 0o022 != 0 || meta.len() > MAX_TABLE {
            return Err("the service table must be a regular file of root (or the broker config's owner), not group/world writable".into());
        }
        Self::parse(&std::fs::read(path).map_err(|e| format!("service table: {e}"))?)
    }

    pub fn row(&self, name: &str) -> Result<&ServiceRow, Refusal> {
        self.rows.iter().find(|r| r.name == name).ok_or_else(|| refuse("service-row-unknown", format!("the service table has no row {name}")))
    }
}

impl ServiceRow {
    /// The reply this row gives `method` on `path`, or the refusal.
    pub fn admits(&self, method: &str, path: &str) -> Result<Reply, Refusal> {
        if !self.methods.iter().any(|m| m == method) {
            return Err(refuse("service-method-refused", format!("row {} admits {:?}", self.name, self.methods)));
        }
        let p = request_path(path).map_err(|e| refuse("service-path-refused", e))?;
        if self.paths.iter().any(|x| under(p, x)) {
            Ok(Reply::Whole)
        } else if self.streams.iter().any(|x| under(p, x)) {
            Ok(Reply::Stream)
        } else {
            Err(refuse("service-path-refused", format!("{p} is under none of row {}'s prefixes", self.name)))
        }
    }
}

/// The service table, held against the provider table: a service bearer is
/// sealed in the operator's namespace under its row's name, so no provider
/// row may share that name.
pub fn table_of(c: &Credentials, trust_owner: u32) -> Result<ServiceTable, String> {
    let path = c.services.as_ref().ok_or("this broker names no service table")?;
    let owner = std::fs::symlink_metadata(path).map_err(|e| format!("service table: {e}"))?.uid();
    if owner != 0 && owner != trust_owner {
        return Err("the service table must belong to root (or the broker config's owner)".into());
    }
    let table = ServiceTable::load(path, owner)?;
    let providers = super::provider_table(&c.providers, trust_owner)?;
    if let Some(row) = table.rows.iter().find(|s| providers.rows.iter().any(|p| p.name == s.name)) {
        return Err(format!("service row {} is also a provider row: the two share the operator's namespace", row.name));
    }
    Ok(table)
}

fn table(broker: &Broker) -> Result<ServiceTable, Refusal> {
    let c = broker.config.credentials.as_ref().ok_or_else(|| refuse("credentials-not-configured", "this broker holds no credential store"))?;
    if c.services.is_none() {
        return Err(refuse("services-not-configured", "this broker names no service table"));
    }
    table_of(c, broker.config.trust_owner).map_err(|e| refuse("service-table", e))
}

fn body_of(request: &Value) -> Result<Vec<u8>, Refusal> {
    let body = wire::unhex(text(request, "body")?).map_err(|e| refuse("bad-request", e))?;
    if body.len() > wire::MAX_PROVIDER_REQUEST {
        return Err(refuse("bad-request", "body must be at most MAX_PROVIDER_REQUEST bytes"));
    }
    Ok(body)
}

/// `service-authorize`: may this uid send `method` to `path` under this row
/// with a body of this digest? A yes is a durable single-use ticket.
pub fn authorize(broker: &Broker, peer: &Peer, request: &Value, note: &mut Note) -> Result<Value, Refusal> {
    exact(request, &["op", "service", "method", "path", "bodySha256"])?;
    let name = text(request, "service")?;
    let method = text(request, "method")?;
    let path = text(request, "path")?;
    let body_sha256 = sha_field(request, "bodySha256")?;
    note.set("service", name);
    note.set("method", method);
    note.set("bodySha256", body_sha256.clone());
    let table = table(broker)?;
    let row = table.row(name)?;
    if !row.uids.contains(&peer.uid) {
        return Err(refuse("service-not-yours", format!("row {name} does not name uid {}", peer.uid)));
    }
    let reply = row.admits(method, path)?;
    note.set("path", request_path(path).unwrap_or(""));
    if method == "GET" && body_sha256 != native::sha256_hex(b"") {
        return Err(refuse("service-body-refused", "a GET carries no body"));
    }
    // The bearer must open before any ticket exists.
    drop(provider::store(broker)?.unseal(Namespace::Pool, name).map_err(store_refusal)?);
    let key = ticket::service_request_key(peer.uid, name, method, path, &body_sha256);
    let answer = |t: &Ticket| {
        json!({"ok":true,"ticket":t.id,"service":t.provider,"method":t.method,"path":path,"reply":reply.name(),
            "expiresInS":t.expires.saturating_sub(ticket::now())})
    };
    let _g = broker.tickets.guard();
    if let Some(t) = broker.tickets.find_request(peer.uid, &key).map_err(|e| refuse("ticket-journal", e))? {
        note.set("ticketSha256", native::sha256_hex(t.id.as_bytes())[..16].to_owned());
        note.set("replayed", true);
        return Ok(answer(&t));
    }
    if broker.tickets.live_for(peer.uid).map_err(|e| refuse("ticket-journal", e))? >= ticket::MAX_LIVE_PER_PEER {
        return Err(refuse("ticket-bound", format!("uid {} holds {} live tickets; forward or let them expire", peer.uid, ticket::MAX_LIVE_PER_PEER)));
    }
    let minted = Ticket {
        id: provider::ticket_id()?,
        peer: peer.uid,
        request: key,
        provider: name.to_owned(),
        endpoint: format!("{}{path}", row.origin),
        models: vec![],
        model: None,
        per_call: 0,
        body_sha256,
        owner: None,
        route: "service".into(),
        owner_epoch: None,
        method: Some(method.to_owned()),
        expires: ticket::now() + ticket::TICKET_TTL_S,
        // Nothing to count: a service ticket is usable once written.
        state: State::Counted,
        settled: 0,
    };
    note.set("ticketSha256", native::sha256_hex(minted.id.as_bytes())[..16].to_owned());
    broker.tickets.put(&minted).map_err(|e| refuse("ticket-journal", e))?;
    Ok(answer(&minted))
}

/// A service ticket, held to its row as the row reads now, for one reply kind.
fn admit(broker: &Broker, peer: &Peer, t: &Ticket, body: &[u8], reply: Reply) -> Result<Plan, NotAdmitted> {
    let method = match (&t.method, t.route.as_str()) {
        (Some(m), "service") => m.clone(),
        _ => return Err(refuse("service-kind-mismatch", "a provider ticket is forwarded by provider-forward").into()),
    };
    let table = table(broker)?;
    let row = table.row(&t.provider)?;
    if !row.uids.contains(&peer.uid) {
        return Err(refuse("service-not-yours", format!("row {} no longer names uid {}", row.name, peer.uid)).into());
    }
    let path = t
        .endpoint
        .strip_prefix(row.origin.as_str())
        .filter(|p| p.starts_with('/'))
        .ok_or_else(|| refuse("service-row-changed", "the row's origin is not the one this ticket was minted for"))?;
    match row.admits(&method, path)? {
        r if r == reply => {}
        Reply::Whole => return Err(refuse("service-reply-whole", "this path's reply comes back whole: service-forward").into()),
        Reply::Stream => return Err(refuse("service-reply-streamed", "this path's reply is streamed: service-stream").into()),
    }
    if body.len() > row.max_request {
        return Err(NotAdmitted::spend(refuse("service-body-exceeds-row", format!("{} bytes exceed row {}'s maxRequestBytes {}", body.len(), row.name, row.max_request))));
    }
    if !body.is_empty() && serde_json::from_slice::<Value>(body).is_err() {
        return Err(NotAdmitted::spend(refuse("service-body-refused", "a body is sent as application/json and must be one JSON value")));
    }
    let secret = provider::store(broker)?.unseal(Namespace::Pool, &t.provider).map_err(store_refusal)?;
    Ok(Plan { endpoint: t.endpoint.clone(), method, secret: Some(secret) })
}

/// `service-forward`: the ticket's exact request, its whole reply back.
pub fn forward(broker: &Broker, peer: &Peer, request: &Value, stream: &mut UnixStream, note: &mut Note) -> Result<Value, Refusal> {
    exact(request, &["op", "ticket", "body", "timeoutMs", "maxResponseBytes"])?;
    let body = body_of(request)?;
    let timeout = Duration::from_millis(number(request, "timeoutMs")?).min(provider::MAX_TIMEOUT).max(Duration::from_secs(1));
    let max_response = (number(request, "maxResponseBytes")? as usize).min(wire::MAX_PROVIDER_RESPONSE);
    let body_sha256 = native::sha256_hex(&body);
    note.set("bodySha256", body_sha256.clone());
    journaled(
        broker,
        peer,
        text(request, "ticket")?,
        &body_sha256,
        "service",
        note,
        |t| admit(broker, peer, t, &body, Reply::Whole),
        |plan, note| match provider::send(&broker.config.spool, &plan, &body, timeout, max_response, stream)? {
            Sent::CallerGone => Ok(Settle::Uncertain(refuse("caller-gone", "the caller closed the connection; the call was stopped and the ticket is uncertain"))),
            sent => Ok(Settle::Answered(provider::answer_of(sent, note))),
        },
    )
}

/// `service-stream`: the ticket's exact request, its reply relayed as it
/// arrives; the closing summary is the answer (and what an exact retry gets).
pub fn stream(broker: &Broker, peer: &Peer, request: &Value, caller: &mut UnixStream, note: &mut Note) -> Result<Value, Refusal> {
    exact(request, &["op", "ticket", "body", "lastEventId"])?;
    let body = body_of(request)?;
    let last_event_id = match request.get("lastEventId") {
        None => None,
        Some(_) => {
            let id = text(request, "lastEventId")?;
            if id.is_empty() || id.len() > MAX_EVENT_ID || id.bytes().any(|b| !(0x21..=0x7e).contains(&b)) {
                return Err(refuse("bad-request", "lastEventId must be 1..256 printable ASCII bytes without spaces"));
            }
            Some(id)
        }
    };
    let body_sha256 = native::sha256_hex(&body);
    note.set("bodySha256", body_sha256.clone());
    journaled(
        broker,
        peer,
        text(request, "ticket")?,
        &body_sha256,
        "service",
        note,
        |t| admit(broker, peer, t, &body, Reply::Stream),
        |plan, note| relay(&broker.config.spool, plan, &body, last_event_id, caller, note).map(Settle::Answered),
    )
}

/// The withhold rule, read as the bytes pass: a reply that carries the
/// bearer is cut before any byte of that occurrence reaches the caller. Only
/// the longest tail that could still begin the bearer waits for the next
/// read to decide it; every other byte goes on at once.
pub struct Echo<'a> {
    secret: &'a [u8],
    held: Vec<u8>,
}

impl<'a> Echo<'a> {
    pub fn new(secret: &'a [u8]) -> Self {
        Echo { secret, held: Vec::new() }
    }

    /// The bytes that may go to the caller now; `None`: the bearer is in the reply.
    pub fn push(&mut self, chunk: &[u8]) -> Option<Vec<u8>> {
        let mut pending = std::mem::take(&mut self.held);
        pending.extend_from_slice(chunk);
        let s = self.secret;
        if s.is_empty() {
            return Some(pending);
        }
        if pending.windows(s.len()).any(|w| w == s) {
            wire::zero(&mut pending);
            return None;
        }
        let p = pending.len();
        let keep = (1..s.len().min(p + 1)).rev().find(|&k| pending[p - k] == s[0] && pending[p - k..] == s[..k]).unwrap_or(0);
        self.held = pending.split_off(p - keep);
        Some(pending)
    }

    /// The reply ended: a held tail can no longer become the bearer.
    pub fn finish(mut self) -> Vec<u8> {
        std::mem::take(&mut self.held)
    }
}

impl Drop for Echo<'_> {
    fn drop(&mut self) {
        wire::zero(&mut self.held);
    }
}

/// The final (non-1xx) header block at the front of `head`: its status and
/// bytes; `head` keeps what follows it. `None` until the block is whole.
fn take_head(head: &mut Vec<u8>) -> Option<(u16, Vec<u8>)> {
    loop {
        let end = head.windows(4).position(|w| w == b"\r\n\r\n")? + 4;
        let status = std::str::from_utf8(&head[..end]).ok().and_then(|h| h.split_whitespace().nth(1)).and_then(|s| s.parse::<u16>().ok()).unwrap_or(0);
        let rest = head.split_off(end);
        let block = std::mem::replace(head, rest);
        if !(100..200).contains(&status) {
            return Some((status, block));
        }
    }
}

fn frame(caller: &mut UnixStream, value: &Value) -> bool {
    wire::send(caller, value, Instant::now() + EXCHANGE).is_ok()
}

fn data(caller: &mut UnixStream, bytes: &[u8]) -> bool {
    bytes.is_empty() || frame(caller, &json!({"ok":true,"stream":"data","body":wire::hex(bytes)}))
}

/// The streamed send: curl writes the reply head and body to a pipe as they
/// arrive (`--include --no-buffer`); each read is checked and framed. Ends
/// when the upstream closes, the bearer appears, or the caller stops.
fn relay(spool: &Path, plan: Plan, body: &[u8], last_event_id: Option<&str>, caller: &mut UnixStream, note: &mut Note) -> Result<Value, Refusal> {
    let secret: &Secret = plan.secret.as_ref().ok_or_else(|| refuse("not-sent", "a service stream carries its row's bearer"))?;
    let request_path = spool.join(format!("forward-stream-{}-{}.request", std::process::id(), SEQ.fetch_add(1, Ordering::SeqCst)));
    if !body.is_empty() {
        provider::create_private(&request_path, body).map_err(|e| {
            let _ = std::fs::remove_file(&request_path);
            refuse("not-sent", e)
        })?;
    }
    let protocol = if plan.endpoint.starts_with("https://") { "=https" } else { "=http" };
    let mut command = Command::new(super::CURL);
    command
        .env_clear()
        .current_dir(spool)
        .arg("--disable")
        .args(["--silent", "--http1.1", "--no-buffer", "--include", "--request", &plan.method])
        .args(["--proto", protocol, "--noproxy", "*", "--proxy", ""])
        .args(["--max-redirs", "0", "--connect-timeout", "10"])
        .args(["--header", "Accept: text/event-stream"])
        .args(["--header", "Accept-Encoding: identity"])
        .args(["--header", "Expect:"]);
    if let Some(id) = last_event_id {
        command.arg("--header").arg(format!("Last-Event-ID: {id}"));
    }
    if !body.is_empty() {
        command.args(["--header", "Content-Type: application/json"]).arg("--data-binary").arg(format!("@{}", request_path.display()));
    }
    command.arg("--url").arg(&plan.endpoint).args(["--config", "-"]).stdin(Stdio::piped()).stdout(Stdio::piped()).stderr(Stdio::null());
    unsafe {
        command.pre_exec(|| {
            let no_core = libc::rlimit { rlim_cur: 0, rlim_max: 0 };
            if libc::setrlimit(libc::RLIMIT_CORE, &no_core) == 0 {
                Ok(())
            } else {
                Err(std::io::Error::last_os_error())
            }
        });
    }
    let mut child = match command.spawn() {
        Ok(c) => c,
        Err(e) => {
            let _ = std::fs::remove_file(&request_path);
            return Err(refuse("not-sent", format!("service transport spawn: {e}")));
        }
    };
    // The bearer reaches curl as config on stdin: never argv, never a file.
    let written = child.stdin.take().is_some_and(|mut stdin| {
        let mut line = provider::header_config(secret).into_bytes();
        let ok = stdin.write_all(&line).is_ok();
        wire::zero(&mut line);
        ok
    });
    let Some(mut out) = child.stdout.take().filter(|_| written) else {
        let _ = child.kill();
        let _ = child.wait();
        let _ = std::fs::remove_file(&request_path);
        return Err(refuse("not-sent", "service transport unavailable"));
    };
    let mut echo = Echo::new(secret.expose().as_bytes());
    let mut head = Vec::new();
    let mut status: Option<u16> = None;
    let (mut bytes, mut withheld, mut by_caller, mut eof) = (0usize, false, false, false);
    let mut buf = vec![0u8; CHUNK];
    loop {
        let mut fds = [
            libc::pollfd { fd: out.as_raw_fd(), events: libc::POLLIN, revents: 0 },
            libc::pollfd { fd: caller.as_raw_fd(), events: libc::POLLIN, revents: 0 },
        ];
        if unsafe { libc::poll(fds.as_mut_ptr(), 2, 1000) } < 0 {
            if std::io::Error::last_os_error().kind() == std::io::ErrorKind::Interrupted {
                continue;
            }
            break;
        }
        // The caller's only move after its request is to stop.
        if fds[1].revents != 0 {
            by_caller = true;
            break;
        }
        if fds[0].revents == 0 {
            continue;
        }
        let n = match out.read(&mut buf) {
            Ok(0) | Err(_) => {
                eof = true;
                break;
            }
            Ok(n) => n,
        };
        let chunk = if status.is_none() {
            head.extend_from_slice(&buf[..n]);
            let Some((code, block)) = take_head(&mut head) else {
                if head.len() > provider::MAX_HEADERS {
                    break;
                }
                continue;
            };
            let s = secret.expose().as_bytes();
            if block.windows(s.len()).any(|w| w == s) {
                withheld = true;
                break;
            }
            status = Some(code);
            if !frame(caller, &json!({"ok":true,"stream":"head","status":code,"headers":wire::hex(&block)})) {
                by_caller = true;
                break;
            }
            std::mem::take(&mut head)
        } else {
            buf[..n].to_vec()
        };
        match echo.push(&chunk) {
            None => {
                withheld = true;
                break;
            }
            Some(pass) => {
                if !data(caller, &pass) {
                    by_caller = true;
                    break;
                }
                bytes += pass.len();
            }
        }
    }
    wire::zero(&mut buf);
    let exited = if eof { child.wait().ok() } else { None };
    if !eof {
        let _ = child.kill();
        let _ = child.wait();
    }
    drop(out);
    let _ = std::fs::remove_file(&request_path);
    if eof && !withheld && status.is_some() {
        let rest = echo.finish();
        if data(caller, &rest) {
            bytes += rest.len();
        }
    }
    let complete = eof && !withheld && status.is_some() && exited.is_some_and(|s| s.success());
    note.set("complete", complete);
    note.set("responseBytes", bytes);
    note.set("closedBy", if by_caller { "caller" } else if eof { "upstream" } else { "broker" });
    let mut end = json!({"ok":true,"stream":"end","complete":complete,"bytes":bytes,"status":status});
    if withheld {
        note.set("withheld", true);
        end["withheld"] = json!(true);
    }
    Ok(end)
}

/// `service` (operator): the bearer of one service row. Set seals it; no
/// action returns it.
pub fn operator(broker: &Broker, request: &Value, note: &mut Note) -> Result<Value, Refusal> {
    let action = text(request, "action")?.to_owned();
    note.set("action", action.clone());
    let table = table(broker)?;
    let store = provider::store(broker)?;
    let result = match action.as_str() {
        "set" => {
            exact(request, &["op", "action", "service", "secret"])?;
            let name = text(request, "service")?;
            note.set("service", name);
            table.row(name)?;
            let secret = Secret::new(text(request, "secret")?.to_owned()).map_err(|e| refuse("bad-request", e))?;
            store.set(Namespace::Pool, name, &secret).map_err(store_refusal)?;
            json!({"type":"mini-service-key-set-v1","service":name,"stored":"sealed"})
        }
        "revoke" => {
            exact(request, &["op", "action", "service"])?;
            let name = text(request, "service")?;
            note.set("service", name);
            table.row(name)?;
            let removed = store.revoke(Namespace::Pool, name, None).map_err(store_refusal)?;
            json!({"type":"mini-service-key-revoke-v1","service":name,"removed":removed,
                "effect":"Future authorizations and forwards refuse; a stream already running runs until it ends."})
        }
        "ls" => {
            exact(request, &["op", "action"])?;
            let listed = store.list(Namespace::Pool).map_err(store_refusal)?;
            let sealed: Vec<&str> = listed["credentials"].as_array().map(|a| a.iter().filter_map(|c| c["provider"].as_str()).collect()).unwrap_or_default();
            let rows: Vec<Value> = table
                .rows
                .iter()
                .map(|r| {
                    json!({"service":r.name,"origin":r.origin,"paths":r.paths,"streams":r.streams,"methods":r.methods,
                        "maxRequestBytes":r.max_request,"uids":r.uids,"sealed":sealed.contains(&r.name.as_str())})
                })
                .collect();
            json!({"type":"mini-service-credentials-list-v1","services":rows})
        }
        _ => return Err(refuse("bad-request", "service action must be set, revoke or ls")),
    };
    Ok(json!({"ok":true,"result":result}))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn row() -> Value {
        json!({"name":"chat","origin":"https://api.example.test","paths":["/v1/messages"],"streams":["/v1/events"],
            "methods":["GET","POST"],"maxRequestBytes":"65536","uids":[1001]})
    }

    fn table_with(row: Value) -> Result<ServiceTable, String> {
        ServiceTable::parse(json!({"type":TABLE_TYPE,"services":[row]}).to_string().as_bytes())
    }

    #[test]
    fn a_row_names_one_origin_its_prefixes_methods_size_and_accounts() {
        let t = table_with(row()).unwrap();
        let r = t.row("chat").ok().unwrap();
        assert_eq!(r.max_request, 65536);
        assert_eq!(r.uids, vec![1001]);
        assert!(table_with(json!({"name":"lo","origin":"http://127.0.0.1:8080","paths":["/"],"methods":["POST"],"maxRequestBytes":"1","uids":[1]})).is_ok());
        for (key, value, why) in [
            ("origin", json!("http://api.example.test"), "only on loopback"),
            ("origin", json!("ftp://api.example.test"), "verified HTTPS"),
            ("origin", json!("https://api.example.test/v1"), "nothing else"),
            ("origin", json!("https://user@api.example.test"), "nothing else"),
            ("origin", json!("https://api.example.test?x"), "nothing else"),
            ("paths", json!(["/v1/../admin"]), "plain path prefixes"),
            ("paths", json!(["/v1/"]), "plain path prefixes"),
            ("paths", json!(["v1"]), "plain path prefixes"),
            ("paths", json!(["/v1/events/x"]), "overlap"),
            ("methods", json!(["CONNECT"]), "among"),
            ("methods", json!(["GET","GET"]), "repeat"),
            ("methods", json!([]), "1..5"),
            ("maxRequestBytes", json!("0"), "maxRequestBytes"),
            ("maxRequestBytes", json!("2000000"), "maxRequestBytes"),
            ("maxRequestBytes", json!("064"), "maxRequestBytes"),
            ("uids", json!([]), "uids"),
            ("uids", json!(["1001"]), "numeric"),
            ("bearer", json!("x"), "outside"),
        ] {
            let mut r = row();
            r[key] = value;
            let e = table_with(r).err().unwrap_or_default();
            assert!(e.contains(why), "{key}: {e}");
        }
        let mut neither = row();
        neither.as_object_mut().unwrap().remove("paths");
        neither.as_object_mut().unwrap().remove("streams");
        assert!(table_with(neither).err().unwrap().contains("paths or streams"));
        let twice = json!({"type":TABLE_TYPE,"services":[row(), row()]});
        assert!(ServiceTable::parse(twice.to_string().as_bytes()).err().unwrap().contains("repeats"));
    }

    #[test]
    fn a_path_is_admitted_only_under_a_prefix_by_segment_and_says_its_reply() {
        let t = table_with(row()).unwrap();
        let r = t.row("chat").ok().unwrap();
        assert_eq!(r.admits("POST", "/v1/messages").ok().unwrap(), Reply::Whole);
        assert_eq!(r.admits("POST", "/v1/messages/42?since=7&x=a%20b").ok().unwrap(), Reply::Whole);
        assert_eq!(r.admits("GET", "/v1/events?channel=general").ok().unwrap(), Reply::Stream);
        for (method, path, code) in [
            ("DELETE", "/v1/messages", "service-method-refused"),
            ("POST", "/v1/messagesX", "service-path-refused"),
            ("POST", "/v1/other", "service-path-refused"),
            ("POST", "/v1/messages/../../admin", "service-path-refused"),
            ("POST", "/v1/messages/%2e%2e/admin", "service-path-refused"),
            ("POST", "/v1//messages", "service-path-refused"),
            ("POST", "//evil.example.test/v1/messages", "service-path-refused"),
            ("POST", "/v1/messages/", "service-path-refused"),
            ("POST", "/v1/messages#x", "service-path-refused"),
            ("POST", "/v1/messages?", "service-path-refused"),
            ("POST", "/v1/messages?a b", "service-path-refused"),
            ("POST", "@evil.example.test/v1/messages", "service-path-refused"),
            ("POST", "", "service-path-refused"),
        ] {
            assert_eq!(r.admits(method, path).err().unwrap().code, code, "{method} {path}");
        }
        assert!(request_path(&format!("/{}", "a".repeat(MAX_PATH))).is_err());
    }

    fn run(secret: &str, chunks: &[&str]) -> (String, bool) {
        let mut echo = Echo::new(secret.as_bytes());
        let mut out = Vec::new();
        for c in chunks {
            match echo.push(c.as_bytes()) {
                Some(pass) => out.extend(pass),
                None => return (String::from_utf8(out).unwrap(), true),
            }
        }
        out.extend(echo.finish());
        (String::from_utf8(out).unwrap(), false)
    }

    #[test]
    fn a_bearer_in_a_stream_is_cut_before_any_of_it_passes_even_across_reads() {
        let s = "sk-service-0123456789";
        // Whole in one read; split in two; split byte by byte; split in the event's header.
        assert_eq!(run(s, &["data: a\n\n", "data: sk-service-0123456789\n\n"]), ("data: a\n\n".into(), true));
        assert_eq!(run(s, &["data: a\n\ndata: sk-ser", "vice-0123456789\n\n"]), ("data: a\n\ndata: ".into(), true));
        let line = format!("data: {s}\n\n");
        let bytes: Vec<String> = line.chars().map(String::from).collect();
        let refs: Vec<&str> = bytes.iter().map(String::as_str).collect();
        let (passed, cut) = run(s, &refs);
        assert!(cut && passed == "data: ", "{passed}");
        // A tail that only looks like the bearer's start waits for the next read, then passes.
        let mut echo = Echo::new(s.as_bytes());
        assert_eq!(echo.push(b"data: sk-se").unwrap(), b"data: ");
        assert_eq!(echo.push(b"cond\n\n").unwrap(), b"sk-second\n\n");
        // Nothing that could begin the bearer: nothing waits.
        assert_eq!(echo.push(b"data: k\n\n").unwrap(), b"data: k\n\n");
        // The reply ends on a held tail: it was never the bearer.
        assert_eq!(run(s, &["data: x\n\nsk-serv"]), ("data: x\n\nsk-serv".into(), false));
        // A prefix that repeats inside the bearer (sksk...).
        assert_eq!(run("sksk-1", &["a sks", "ksk-1"]), ("a ".into(), true));
        assert_eq!(run("sksk-1", &["a sksk", "sk-1 b"]), ("a ".into(), true));
        assert_eq!(run("sksk-1", &["a sksk", "x"]), ("a skskx".into(), false));
    }

    #[test]
    fn the_head_is_the_final_block_after_any_interim_ones() {
        let mut head = b"HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n\r\ndata: 1\n\n".to_vec();
        let (status, block) = take_head(&mut head).unwrap();
        assert_eq!(status, 200);
        assert!(block.starts_with(b"HTTP/1.1 200 OK\r\n") && block.ends_with(b"\r\n\r\n"));
        assert_eq!(head, b"data: 1\n\n");
        let mut partial = b"HTTP/1.1 200 OK\r\nX: y\r\n".to_vec();
        assert!(take_head(&mut partial).is_none());
        assert_eq!(partial, b"HTTP/1.1 200 OK\r\nX: y\r\n");
    }
}
