//! `mini apps-front`: the one entrance Caddy proxies every `*.demo.dregg.online`
//! request to (docs/APP-MARKET-2026-10-27.md §5). It selects the grain by `Host`
//! and the participant route by the credential presented, then pumps the request
//! unchanged to that route's custodian socket. It terminates no TLS, holds no
//! key, calls no Mini operation and adds no authorization: the custodian keeps
//! every check (Host, Origin, cookie, `Sec-Fetch-*`, Mini admission) and the
//! front only answers the question Caddy cannot, which socket.
//!
//! Why one entrance and not one upstream per grain: a custodian socket is per
//! participant (one fixed subject, session, ticket and token set), so a grain
//! shared with a second member has two sockets, and the choice between them is
//! the token's, which Caddy cannot look up. Token *hashes* in the origin table
//! are not secrets; the tokens stay 0600 in the route directory.

use crate::web::loopback_address;
use crate::{absolute, path, Args, Result};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::io::{self, Read, Write};
use std::net::{Shutdown, TcpListener, TcpStream};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::collections::BTreeMap;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

/// The custodian's bounds: 64 KiB head, 10 s to read it, 8 MiB body.
const MAX_HEAD: usize = 64 * 1024;
const HEAD_DEADLINE: Duration = Duration::from_secs(10);
/// Class L's 128 WebSocket slots plus eight for HTTP and handshakes.
const PER_GRAIN_CONNECTIONS: usize = 136;
const TOTAL_CONNECTIONS: usize = 1024;
/// The custodian's bootstrap form is at most 128 bytes.
const MAX_BOOTSTRAP_BODY: usize = 128;
const PUMP_BUFFER: usize = 64 * 1024;
/// After the browser half-closes, the app gets this long to finish its reply.
const HALF_CLOSE_GRACE: Duration = Duration::from_secs(5);
const BOOTSTRAP_PATH: &str = "/__mini/bootstrap";
const COOKIE_NAME: &str = "__Host-mini_spk_session";
const BOOTSTRAP_FORM: &str = "<!doctype html><html><head><meta charset=\"utf-8\"><title>Private Mini sign-in</title></head><body><form method=\"post\" action=\"/__mini/bootstrap\"><label>Private bootstrap token <input name=\"token\" autocomplete=\"off\" required></label><button type=\"submit\">Sign in</button></form></body></html>";

/// One participant route of a grain, as the worker publishes it.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Route {
    pub member: String,
    pub socket: PathBuf,
    pub browser_token_sha256: String,
    pub bootstrap_token_sha256: String,
    pub api_token_sha256: String,
}

#[derive(Clone, Debug, PartialEq)]
pub(crate) struct Origin {
    pub grain: String,
    pub routes: Vec<Route>,
    /// The worker's edge socket: route sockets live under the operator's 0700
    /// state root, so the worker connects and hands the socket over SCM_RIGHTS.
    pub connector: Option<PathBuf>,
}

fn hex64(text: &str) -> bool {
    mini_sdk::hex::is_canonical_len(text, 32)
}

/// `origins/<grain>.json`, written by the worker; refused whole on any drift.
pub(crate) fn parse_origin(bytes: &[u8]) -> Result<Origin> {
    let value: Value = serde_json::from_slice(bytes).map_err(|e| format!("origin table is not JSON: {e}"))?;
    if value.get("protocol").and_then(Value::as_str) != Some("mini-apps-origin-v1") {
        return Err("origin table protocol differs".into());
    }
    let grain = value.get("grain").and_then(Value::as_str).ok_or("origin table lacks grain")?;
    if !super::valid_grain(grain) {
        return Err("origin table grain id refused".into());
    }
    let list = value.get("routes").and_then(Value::as_array).ok_or("origin table lacks routes")?;
    if list.len() > 64 {
        return Err("origin table names over 64 routes".into());
    }
    let mut routes = Vec::with_capacity(list.len());
    for route in list {
        let text = |key: &str| -> Result<String> {
            route
                .get(key)
                .and_then(Value::as_str)
                .map(str::to_owned)
                .ok_or_else(|| format!("origin route lacks {key}"))
        };
        let parsed = Route {
            member: text("member")?,
            socket: PathBuf::from(text("socket")?),
            browser_token_sha256: text("browserTokenSha256")?,
            bootstrap_token_sha256: text("bootstrapTokenSha256")?,
            api_token_sha256: text("apiTokenSha256")?,
        };
        if !parsed.socket.is_absolute()
            || !hex64(&parsed.browser_token_sha256)
            || !hex64(&parsed.bootstrap_token_sha256)
            || !hex64(&parsed.api_token_sha256)
        {
            return Err("origin route socket or token hashes refused".into());
        }
        routes.push(parsed);
    }
    let connector = match value.get("connector") {
        None | Some(Value::Null) => None,
        Some(Value::String(path)) if Path::new(path).is_absolute() => Some(PathBuf::from(path)),
        _ => return Err("origin table connector must be an absolute path".into()),
    };
    Ok(Origin { grain: grain.to_owned(), routes, connector })
}

/// The custodian socket for a route: directly, or through the worker's connector.
fn connect_route(origin: &Origin, route: &Route) -> io::Result<UnixStream> {
    let Some(connector) = &origin.connector else {
        return UnixStream::connect(&route.socket);
    };
    let mut edge = UnixStream::connect(connector)?;
    edge.set_read_timeout(Some(Duration::from_secs(10)))?;
    let request = format!("{{\"verb\":\"connect\",\"grain\":\"{}\",\"route\":\"{}\"}}\n", origin.grain, route.member);
    edge.write_all(request.as_bytes())?;
    let (reply, socket) = super::worker::receive_with_fd(&edge).map_err(io::Error::other)?;
    match socket {
        Some(socket) => Ok(socket),
        None => Err(io::Error::other(reply.get("refused").and_then(Value::as_str).unwrap_or("connector refused").to_owned())),
    }
}

/// The grain's publishing socket, through the worker's connector (`www`). The
/// refusal names why: `grainStopped` when no resident is listening.
fn connect_www(origin: &Origin) -> std::result::Result<UnixStream, String> {
    let connector = origin.connector.as_ref().ok_or("noConnector")?;
    let mut edge = UnixStream::connect(connector).map_err(|_| "connectorUnavailable".to_owned())?;
    edge.set_read_timeout(Some(Duration::from_secs(10))).map_err(|e| e.to_string())?;
    edge.write_all(format!("{{\"verb\":\"www\",\"grain\":\"{}\"}}\n", origin.grain).as_bytes()).map_err(|e| e.to_string())?;
    let (reply, socket) = super::worker::receive_with_fd(&edge)?;
    socket.ok_or_else(|| reply.get("refused").and_then(Value::as_str).unwrap_or("connector refused").to_owned())
}

/// The grain of a publishing origin `a4501-www.demo.dregg.online`.
pub(crate) fn www_grain_of_host(host: &str, domain: &str) -> Option<String> {
    let name = host.split(':').next()?.to_ascii_lowercase();
    let label = name.strip_suffix(domain)?.strip_suffix('.')?.strip_suffix("-www")?;
    super::valid_grain(label).then(|| label.to_owned())
}

fn token_hash(token: &str) -> String {
    let digest = Sha256::digest(token.as_bytes());
    mini_sdk::hex::encode(&digest)
}

fn valid_token(token: &str) -> bool {
    hex64(token)
}

/// The grain label of `Host`: `a4501.demo.dregg.online` under the configured
/// domain, port stripped; anything else is not a grain origin.
pub(crate) fn grain_of_host(host: &str, domain: &str) -> Option<String> {
    let name = host.split(':').next()?.to_ascii_lowercase();
    let label = name.strip_suffix(domain)?.strip_suffix('.')?;
    super::valid_grain(label).then(|| label.to_owned())
}

/// The parsed head: enough to dispatch, nothing is rewritten.
#[derive(Debug, PartialEq)]
pub(crate) struct Head {
    pub method: String,
    pub target: String,
    pub host: Option<String>,
    pub cookie_token: Option<String>,
    pub bearer_token: Option<String>,
    pub content_length: usize,
    pub upgrade: bool,
}

pub(crate) fn parse_head(head: &[u8]) -> Result<Head> {
    let text = std::str::from_utf8(head).map_err(|_| "request head is not UTF-8")?;
    let mut lines = text.split("\r\n");
    let request_line = lines.next().ok_or("empty request")?;
    let mut parts = request_line.split(' ');
    let method = parts.next().filter(|m| !m.is_empty()).ok_or("request line lacks a method")?.to_owned();
    let target = parts.next().filter(|t| t.starts_with('/')).ok_or("request target is not a path")?.to_owned();
    if parts.next() != Some("HTTP/1.1") || parts.next().is_some() {
        return Err("only HTTP/1.1 is served".into());
    }
    let mut out = Head { method, target, host: None, cookie_token: None, bearer_token: None, content_length: 0, upgrade: false };
    for line in lines {
        if line.is_empty() {
            break;
        }
        let (name, value) = line.split_once(':').ok_or("malformed header")?;
        let name = name.trim().to_ascii_lowercase();
        let value = value.trim();
        match name.as_str() {
            "host" => {
                if out.host.is_some() {
                    return Err("duplicate Host".into());
                }
                out.host = Some(value.to_owned());
            }
            "cookie" => {
                for pair in value.split(';') {
                    if let Some((k, v)) = pair.trim().split_once('=') {
                        if k == COOKIE_NAME && valid_token(v) {
                            out.cookie_token = Some(v.to_owned());
                        }
                    }
                }
            }
            "authorization" => {
                if let Some(token) = value.strip_prefix("Bearer ") {
                    if valid_token(token.trim()) {
                        out.bearer_token = Some(token.trim().to_owned());
                    }
                }
            }
            "content-length" => {
                out.content_length = value.parse().map_err(|_| "Content-Length is not a natural")?;
            }
            "upgrade" => out.upgrade = value.eq_ignore_ascii_case("websocket"),
            _ => {}
        }
    }
    Ok(out)
}

/// `token=<hex>` from the custodian's bootstrap form body (one field, no
/// percent-escapes needed for a hex token; anything else does not select).
pub(crate) fn bootstrap_token(body: &[u8]) -> Option<String> {
    let text = std::str::from_utf8(body).ok()?;
    text.split('&')
        .filter_map(|pair| pair.split_once('='))
        .find(|(k, _)| *k == "token")
        .map(|(_, v)| v.trim().to_owned())
        .filter(|v| valid_token(v))
}

/// Which route answers: by cookie, by bearer, or by the bootstrap token.
pub(crate) fn select_route<'a>(origin: &'a Origin, head: &Head, bootstrap: Option<&str>) -> Option<&'a Route> {
    if let Some(token) = &head.cookie_token {
        let hash = token_hash(token);
        if let Some(route) = origin.routes.iter().find(|r| r.browser_token_sha256 == hash) {
            return Some(route);
        }
    }
    if let Some(token) = &head.bearer_token {
        let hash = token_hash(token);
        if let Some(route) = origin.routes.iter().find(|r| r.api_token_sha256 == hash) {
            return Some(route);
        }
    }
    if let Some(token) = bootstrap {
        let hash = token_hash(token);
        return origin.routes.iter().find(|r| r.bootstrap_token_sha256 == hash);
    }
    None
}

struct Front {
    origins: PathBuf,
    domain: String,
    live: AtomicUsize,
    /// Live connections per grain: one noisy grain cannot take every slot.
    per_grain: Mutex<BTreeMap<String, usize>>,
}

/// A grain's connection slot, released when the connection ends.
struct GrainSlot<'a> {
    front: &'a Front,
    grain: String,
}

impl Drop for GrainSlot<'_> {
    fn drop(&mut self) {
        if let Ok(mut map) = self.front.per_grain.lock() {
            match map.get_mut(&self.grain) {
                Some(n) if *n > 1 => *n -= 1,
                _ => {
                    map.remove(&self.grain);
                }
            }
        }
    }
}

fn respond(stream: &mut TcpStream, status: &str, body: &str, html: bool) {
    let kind = if html { "text/html; charset=utf-8" } else { "text/plain; charset=utf-8" };
    let _ = stream.set_write_timeout(Some(Duration::from_secs(5)));
    let _ = write!(
        stream,
        "HTTP/1.1 {status}\r\nContent-Type: {kind}\r\nContent-Length: {}\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n{body}",
        body.len()
    );
    let _ = stream.shutdown(Shutdown::Both);
}

/// Read the head (and, for the bootstrap POST, its small body) under one deadline.
fn read_head(stream: &mut TcpStream, buffer: &mut Vec<u8>) -> io::Result<usize> {
    let deadline = Instant::now() + HEAD_DEADLINE;
    let mut chunk = [0_u8; 4096];
    loop {
        if let Some(end) = find_head_end(buffer) {
            return Ok(end);
        }
        if buffer.len() >= MAX_HEAD {
            return Err(io::Error::new(io::ErrorKind::InvalidData, "head over 64 KiB"));
        }
        let remaining = deadline
            .checked_duration_since(Instant::now())
            .ok_or_else(|| io::Error::new(io::ErrorKind::TimedOut, "head deadline"))?;
        stream.set_read_timeout(Some(remaining))?;
        let n = stream.read(&mut chunk)?;
        if n == 0 {
            return Err(io::Error::new(io::ErrorKind::UnexpectedEof, "closed before the head"));
        }
        buffer.extend_from_slice(&chunk[..n]);
    }
}

fn find_head_end(buffer: &[u8]) -> Option<usize> {
    buffer.windows(4).position(|w| w == b"\r\n\r\n").map(|p| p + 4)
}

fn pump(mut from: impl Read, mut to: impl Write) -> io::Result<u64> {
    let mut buffer = vec![0_u8; PUMP_BUFFER];
    let mut total = 0;
    loop {
        let n = match from.read(&mut buffer) {
            Ok(0) => return Ok(total),
            Ok(n) => n,
            Err(e) if e.kind() == io::ErrorKind::Interrupted => continue,
            Err(e) => return Err(e),
        };
        to.write_all(&buffer[..n])?;
        total += n as u64;
    }
}

impl Front {
    fn take_slot(&self, grain: &str) -> Option<GrainSlot<'_>> {
        let mut map = self.per_grain.lock().ok()?;
        let count = map.entry(grain.to_owned()).or_insert(0);
        if *count >= PER_GRAIN_CONNECTIONS {
            return None;
        }
        *count += 1;
        Some(GrainSlot { front: self, grain: grain.to_owned() })
    }

    fn origin(&self, grain: &str) -> Result<Origin> {
        let bytes = crate::fsio::read_bounded(&self.origins.join(format!("{grain}.json")), 64 * 1024)
            .map_err(|_| format!("no such grain {grain}"))?;
        let origin = parse_origin(&bytes)?;
        if origin.grain != grain {
            return Err("origin table names another grain".into());
        }
        Ok(origin)
    }

    /// The publishing origin (INSTALL.md §5a): anonymous GET/HEAD of the grain's
    /// `/var/www`, answered by its resident. Only the method and the path travel
    /// upstream: no cookie, no credential, no other header.
    fn serve_www(&self, mut client: TcpStream, head: &Head, grain: &str) {
        if head.method != "GET" && head.method != "HEAD" {
            let body = "the publishing origin answers GET and HEAD only\n";
            let _ = write!(client, "HTTP/1.1 405 Method Not Allowed\r\nAllow: GET, HEAD\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}", body.len());
            return;
        }
        if !head.target.starts_with('/') || head.target.len() > 2048 || head.target.bytes().any(|b| b <= b' ' || b == 0x7f) {
            return respond(&mut client, "404 Not Found", "no such published file\n", false);
        }
        let Ok(origin) = self.origin(grain) else {
            return respond(&mut client, "404 Not Found", "no such published site\n", false);
        };
        let Some(_slot) = self.take_slot(grain) else {
            return respond(&mut client, "503 Service Unavailable", &format!("grain {grain} has every connection slot in use ({PER_GRAIN_CONNECTIONS})\n"), false);
        };
        let mut upstream = match connect_www(&origin) {
            Ok(upstream) => upstream,
            Err(reason) if reason == "grainStopped" => {
                let body = format!("grain {grain} is stopped; its owner starts it with mini apps start --grain {grain}\n");
                let _ = write!(client, "HTTP/1.1 503 Service Unavailable\r\nRetry-After: 30\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}", body.len());
                return;
            }
            Err(_) => return respond(&mut client, "404 Not Found", "no such published site\n", false),
        };
        if write!(upstream, "{} {} HTTP/1.0\r\n\r\n", head.method, head.target).is_err() {
            return respond(&mut client, "502 Bad Gateway", "published site refused the request\n", false);
        }
        let _ = upstream.set_read_timeout(Some(Duration::from_secs(120)));
        let _ = pump(&mut upstream, &mut client);
        let _ = client.shutdown(Shutdown::Both);
    }

    fn serve(&self, mut client: TcpStream) {
        let mut buffer = Vec::with_capacity(8192);
        let head_end = match read_head(&mut client, &mut buffer) {
            Ok(end) => end,
            Err(_) => return respond(&mut client, "408 Request Timeout", "request head not received\n", false),
        };
        let head = match parse_head(&buffer[..head_end]) {
            Ok(head) => head,
            Err(reason) => return respond(&mut client, "400 Bad Request", &format!("{reason}\n"), false),
        };
        if let Some(grain) = head.host.as_deref().and_then(|h| www_grain_of_host(h, &self.domain)) {
            return self.serve_www(client, &head, &grain);
        }
        let Some(grain) = head.host.as_deref().and_then(|h| grain_of_host(h, &self.domain)) else {
            return respond(&mut client, "404 Not Found", "not a grain origin\n", false);
        };
        let origin = match self.origin(&grain) {
            Ok(origin) => origin,
            Err(reason) => return respond(&mut client, "404 Not Found", &format!("{reason}\n"), false),
        };
        let Some(_slot) = self.take_slot(&grain) else {
            return respond(&mut client, "503 Service Unavailable", &format!("grain {grain} has every connection slot in use ({PER_GRAIN_CONNECTIONS})\n"), false);
        };
        // The bootstrap POST carries its token in a 128-byte body: read it here
        // so the route can be chosen; the bytes are forwarded unchanged.
        let mut bootstrap = None;
        let is_bootstrap = head.target == BOOTSTRAP_PATH || head.target.starts_with("/__mini/bootstrap?");
        if is_bootstrap && head.method == "POST" {
            if head.content_length > MAX_BOOTSTRAP_BODY {
                return respond(&mut client, "413 Payload Too Large", "bootstrap form exceeds bound\n", false);
            }
            let deadline = Instant::now() + HEAD_DEADLINE;
            while buffer.len() < head_end + head.content_length {
                let Some(remaining) = deadline.checked_duration_since(Instant::now()) else {
                    return respond(&mut client, "408 Request Timeout", "bootstrap body not received\n", false);
                };
                let _ = client.set_read_timeout(Some(remaining));
                let mut chunk = [0_u8; 256];
                match client.read(&mut chunk) {
                    Ok(0) | Err(_) => return respond(&mut client, "400 Bad Request", "bootstrap body truncated\n", false),
                    Ok(n) => buffer.extend_from_slice(&chunk[..n]),
                }
            }
            bootstrap = bootstrap_token(&buffer[head_end..head_end + head.content_length]);
        }
        let Some(route) = select_route(&origin, &head, bootstrap.as_deref()) else {
            if is_bootstrap && head.method == "GET" {
                return respond(&mut client, "200 OK", BOOTSTRAP_FORM, true);
            }
            return respond(
                &mut client,
                "403 Forbidden",
                &format!("private grain {grain}; open it from your Mini shell: mini apps open --grain {grain}\n"),
                false,
            );
        };
        let mut upstream = match connect_route(&origin, route) {
            Ok(upstream) => upstream,
            Err(_) => return respond(&mut client, "503 Service Unavailable", "grain route not listening; the grain may be stopped or restarting\n", false),
        };
        if upstream.write_all(&buffer).is_err() {
            return respond(&mut client, "502 Bad Gateway", "grain route refused the request\n", false);
        }
        // Full duplex until both halves end: ordinary HTTP (the custodian closes
        // after one response) and a WebSocket after 101 take the same path.
        let _ = client.set_read_timeout(None);
        let client_reader = match client.try_clone() {
            Ok(c) => c,
            Err(_) => return,
        };
        let upstream_writer = match upstream.try_clone() {
            Ok(u) => u,
            Err(_) => return,
        };
        let to_app = std::thread::Builder::new().name("mini-apps-front-up".into()).spawn(move || {
            let mut writer = upstream_writer;
            let _ = pump(client_reader, &mut writer);
            let _ = writer.shutdown(Shutdown::Write);
        });
        let _ = upstream.set_read_timeout(None);
        let _ = pump(&mut upstream, &mut client);
        let _ = client.shutdown(Shutdown::Write);
        if let Ok(handle) = to_app {
            // The browser may still be sending after the app finished; give the
            // app the half-close grace, then end the connection.
            let started = Instant::now();
            while !handle.is_finished() && started.elapsed() < HALF_CLOSE_GRACE {
                std::thread::sleep(Duration::from_millis(50));
            }
            let _ = client.shutdown(Shutdown::Both);
            let _ = handle.join();
        }
    }
}

pub(crate) fn serve(listener: TcpListener, origins: PathBuf, domain: String) -> Result<()> {
    let front = Arc::new(Front { origins, domain, live: AtomicUsize::new(0), per_grain: Mutex::new(BTreeMap::new()) });
    for stream in listener.incoming() {
        let mut stream = match stream {
            Ok(stream) => stream,
            Err(error) => {
                eprintln!("mini apps-front: accept: {error}");
                continue;
            }
        };
        if front.live.fetch_update(Ordering::AcqRel, Ordering::Acquire, |n| (n < TOTAL_CONNECTIONS).then_some(n + 1)).is_err() {
            respond(&mut stream, "503 Service Unavailable", "busy\n", false);
            continue;
        }
        struct Permit(Arc<Front>);
        impl Drop for Permit {
            fn drop(&mut self) {
                self.0.live.fetch_sub(1, Ordering::AcqRel);
            }
        }
        let permit = Permit(front.clone());
        let worker = front.clone();
        if std::thread::Builder::new()
            .name("mini-apps-front".into())
            .spawn(move || {
                let _permit = permit;
                worker.serve(stream);
            })
            .is_err()
        {
            eprintln!("mini apps-front: cannot spawn a connection thread");
        }
    }
    Ok(())
}

/// `mini apps-front --listen 127.0.0.1:8797 --origins DIR [--domain demo.dregg.online]`
pub(crate) fn run(mut args: Args) -> Result<()> {
    let listen = args.required("listen")?.into_string().map_err(|_| "--listen must be UTF-8".to_owned())?;
    let origins = absolute(&path(args.required("origins")?))?;
    let domain = args
        .optional("domain")
        .map(|d| d.into_string().map_err(|_| "--domain must be UTF-8".to_owned()))
        .transpose()?
        .unwrap_or_else(|| "demo.dregg.online".to_owned())
        .to_ascii_lowercase();
    args.finish()?;
    if !origins.is_dir() {
        return Err(format!("--origins {} is not a directory", origins.display()));
    }
    let address = loopback_address(&listen)?;
    let listener = TcpListener::bind(address).map_err(|e| format!("cannot bind {address}: {e}"))?;
    println!(
        "mini apps-front: *.{domain} -> {} by Host and credential; origins {}",
        listener.local_addr().map_err(|e| e.to_string())?,
        origins.display()
    );
    io::stdout().flush().map_err(|e| e.to_string())?;
    serve(listener, origins, domain)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::net::UnixListener;

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("mini-apps-front-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn origin_json(grain: &str, routes: &[(&str, &Path, &str, &str, &str)]) -> String {
        let routes: Vec<String> = routes
            .iter()
            .map(|(m, s, b, boot, a)| {
                format!(
                    r#"{{"member":"{m}","socket":"{}","browserTokenSha256":"{}","bootstrapTokenSha256":"{}","apiTokenSha256":"{}"}}"#,
                    s.display(),
                    token_hash(b),
                    token_hash(boot),
                    token_hash(a)
                )
            })
            .collect();
        format!(r#"{{"protocol":"mini-apps-origin-v1","grain":"{grain}","routes":[{}]}}"#, routes.join(","))
    }

    const ALICE: &str = "a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1";
    const ALICE_BOOT: &str = "b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0";
    const ALICE_API: &str = "c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1";
    const BOB: &str = "d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2d2";
    const STRANGER: &str = "e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3e3";

    #[test]
    fn apps_front_parses_heads_and_hosts() {
        let head = parse_head(
            b"GET /pad?x=1 HTTP/1.1\r\nHost: a4501.demo.dregg.online\r\nCookie: other=1; __Host-mini_spk_session=a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1\r\nUpgrade: websocket\r\n\r\n",
        )
        .unwrap();
        assert_eq!(head.method, "GET");
        assert_eq!(head.cookie_token.as_deref(), Some(ALICE));
        assert!(head.upgrade);
        assert_eq!(grain_of_host("a4501.demo.dregg.online:443", "demo.dregg.online").as_deref(), Some("a4501"));
        assert_eq!(grain_of_host("A4501.Demo.Dregg.Online", "demo.dregg.online").as_deref(), Some("a4501"));
        assert_eq!(grain_of_host("demo.dregg.online", "demo.dregg.online"), None);
        assert_eq!(grain_of_host("calc.demo.dregg.online", "demo.dregg.online"), None);
        assert_eq!(grain_of_host("a4501.other.example", "demo.dregg.online"), None);
        assert_eq!(grain_of_host("x.a4501.demo.dregg.online", "demo.dregg.online"), None);
        assert!(parse_head(b"GET /x HTTP/1.0\r\n\r\n").is_err());
        assert!(parse_head(b"GET /x HTTP/1.1\r\nHost: a\r\nHost: b\r\n\r\n").is_err());
        assert!(parse_head(b"GET x HTTP/1.1\r\n\r\n").is_err());
        let bearer = parse_head(b"GET / HTTP/1.1\r\nAuthorization: Bearer c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1\r\n\r\n").unwrap();
        assert_eq!(bearer.bearer_token.as_deref(), Some(ALICE_API));
        assert_eq!(bootstrap_token(b"token=b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0").as_deref(), Some(ALICE_BOOT));
        assert_eq!(bootstrap_token(b"token=short"), None);
        assert_eq!(bootstrap_token(b"other=1"), None);
    }

    #[test]
    fn apps_front_selects_the_route_by_credential_only() {
        let dir = scratch("select");
        let a = dir.join("alice.sock");
        let b = dir.join("bob.sock");
        let origin = parse_origin(origin_json("a4501", &[("alice", &a, ALICE, ALICE_BOOT, ALICE_API), ("bob", &b, BOB, BOB, BOB)]).as_bytes()).unwrap();
        let cookie = parse_head(format!("GET / HTTP/1.1\r\nHost: a4501.demo.dregg.online\r\nCookie: {COOKIE_NAME}={BOB}\r\n\r\n").as_bytes()).unwrap();
        assert_eq!(select_route(&origin, &cookie, None).unwrap().member, "bob");
        let api = parse_head(format!("GET / HTTP/1.1\r\nHost: a4501.demo.dregg.online\r\nAuthorization: Bearer {ALICE_API}\r\n\r\n").as_bytes()).unwrap();
        assert_eq!(select_route(&origin, &api, None).unwrap().member, "alice");
        let none = parse_head(format!("GET / HTTP/1.1\r\nHost: a4501.demo.dregg.online\r\nCookie: {COOKIE_NAME}={STRANGER}\r\n\r\n").as_bytes()).unwrap();
        assert!(select_route(&origin, &none, None).is_none());
        assert_eq!(select_route(&origin, &none, Some(ALICE_BOOT)).unwrap().member, "alice");
        assert!(select_route(&origin, &none, Some(STRANGER)).is_none());
        assert!(parse_origin(br#"{"protocol":"mini-apps-origin-v1","grain":"4501","routes":[]}"#).is_err());
        assert!(parse_origin(origin_json("a4501", &[("x", Path::new("relative.sock"), ALICE, ALICE, ALICE)]).as_bytes()).is_err());
    }

    /// A fake custodian: one request per connection, echoes the head it saw;
    /// on a WebSocket upgrade it answers 101 and echoes frames until EOF.
    fn fake_custodian(socket: &Path) -> std::thread::JoinHandle<Vec<Vec<u8>>> {
        let listener = UnixListener::bind(socket).unwrap();
        std::thread::spawn(move || {
            let mut seen = Vec::new();
            for stream in listener.incoming().take(4) {
                let mut stream = stream.unwrap();
                let mut buffer = Vec::new();
                let mut chunk = [0_u8; 1024];
                while find_head_end(&buffer).is_none() {
                    let n = stream.read(&mut chunk).unwrap();
                    if n == 0 {
                        break;
                    }
                    buffer.extend_from_slice(&chunk[..n]);
                }
                let head = parse_head(&buffer[..find_head_end(&buffer).unwrap()]).unwrap();
                let end = find_head_end(&buffer).unwrap();
                while buffer.len() < end + head.content_length {
                    let n = stream.read(&mut chunk).unwrap();
                    buffer.extend_from_slice(&chunk[..n]);
                }
                seen.push(buffer.clone());
                if head.upgrade {
                    stream.write_all(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n").unwrap();
                    stream.write_all(b"first-frame").unwrap();
                    let mut echo = [0_u8; 1024];
                    loop {
                        let n = stream.read(&mut echo).unwrap();
                        if n == 0 {
                            break;
                        }
                        stream.write_all(b"echo:").unwrap();
                        stream.write_all(&echo[..n]).unwrap();
                    }
                    let _ = stream.write_all(b"bye");
                } else {
                    let body = format!("custodian saw {} {}", head.method, head.target);
                    write!(stream, "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}", body.len()).unwrap();
                }
                let _ = stream.shutdown(Shutdown::Both);
                if seen.len() == 4 {
                    break;
                }
            }
            seen
        })
    }

    fn start_front(origins: PathBuf) -> std::net::SocketAddr {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        std::thread::spawn(move || serve(listener, origins, "demo.dregg.online".into()));
        address
    }

    fn request(address: std::net::SocketAddr, bytes: &[u8]) -> String {
        let mut stream = TcpStream::connect(address).unwrap();
        stream.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
        stream.write_all(bytes).unwrap();
        let _ = stream.shutdown(Shutdown::Write);
        let mut out = Vec::new();
        let _ = stream.read_to_end(&mut out);
        String::from_utf8_lossy(&out).into_owned()
    }

    #[test]
    fn apps_front_serves_the_publishing_origin_through_the_connector() {
        assert_eq!(www_grain_of_host("a4501-www.demo.dregg.online", "demo.dregg.online").as_deref(), Some("a4501"));
        assert_eq!(www_grain_of_host("a4501.demo.dregg.online", "demo.dregg.online"), None);
        assert_eq!(www_grain_of_host("x-www.demo.dregg.online", "demo.dregg.online"), None);
        let dir = scratch("www");
        let origins = dir.join("origins");
        std::fs::create_dir_all(&origins).unwrap();
        let connector = dir.join("edge.sock");
        let edge = UnixListener::bind(&connector).unwrap();
        // The fake connector: the first www request finds the grain stopped, every
        // later one is handed a site that echoes the one line it was sent.
        std::thread::spawn(move || {
            for (n, stream) in edge.incoming().enumerate() {
                let stream = stream.unwrap();
                let mut line = String::new();
                std::io::BufRead::read_line(&mut std::io::BufReader::new(stream.try_clone().unwrap()), &mut line).unwrap();
                assert!(line.contains("\"verb\":\"www\"") && line.contains("a4501"), "{line}");
                if n == 0 {
                    (&stream).write_all(b"{\"refused\":\"grainStopped\"}\n").unwrap();
                    continue;
                }
                let (front_end, mut site) = UnixStream::pair().unwrap();
                std::thread::spawn(move || {
                    let mut got = Vec::new();
                    let mut chunk = [0_u8; 512];
                    while !got.ends_with(b"\r\n\r\n") {
                        let k = site.read(&mut chunk).unwrap();
                        if k == 0 { break; }
                        got.extend_from_slice(&chunk[..k]);
                    }
                    let seen = String::from_utf8_lossy(&got).replace("\r\n", "|");
                    let _ = write!(site, "HTTP/1.1 200 OK\r\nContent-Length: {}\r\n\r\n{seen}", seen.len());
                });
                super::super::worker::send_with_fd(&stream, &serde_json::json!({"state":"connected"}), std::os::fd::AsRawFd::as_raw_fd(&front_end)).unwrap();
            }
        });
        let table = origin_json("a4501", &[]).replace("\"routes\"", &format!("\"connector\":\"{}\",\"routes\"", connector.display()));
        std::fs::write(origins.join("a4501.json"), table).unwrap();
        let address = start_front(origins);
        let host = "Host: a4501-www.demo.dregg.online";
        let stopped = request(address, format!("GET / HTTP/1.1\r\n{host}\r\n\r\n").as_bytes());
        assert!(stopped.starts_with("HTTP/1.1 503") && stopped.contains("Retry-After: 30") && stopped.contains("mini apps start --grain a4501"), "{stopped}");
        let page = request(address, format!("GET /deck/ HTTP/1.1\r\n{host}\r\nCookie: {COOKIE_NAME}={ALICE}\r\n\r\n").as_bytes());
        assert!(page.starts_with("HTTP/1.1 200") && page.ends_with("GET /deck/ HTTP/1.0||"), "{page}");
        assert!(!page.contains("Cookie"), "no credential travels upstream: {page}");
        let post = request(address, format!("POST / HTTP/1.1\r\n{host}\r\nContent-Length: 0\r\n\r\n").as_bytes());
        assert!(post.starts_with("HTTP/1.1 405") && post.contains("Allow: GET, HEAD"), "{post}");
        let unknown = request(address, b"GET / HTTP/1.1\r\nHost: a9-www.demo.dregg.online\r\n\r\n");
        assert!(unknown.starts_with("HTTP/1.1 404") && unknown.contains("no such published site"), "{unknown}");
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn apps_front_dispatches_over_real_sockets_and_pumps_a_websocket() {
        let dir = scratch("serve");
        let origins = dir.join("origins");
        std::fs::create_dir_all(&origins).unwrap();
        let alice_sock = dir.join("alice.sock");
        let custodian = fake_custodian(&alice_sock);
        std::fs::write(origins.join("a4501.json"), origin_json("a4501", &[("alice", &alice_sock, ALICE, ALICE_BOOT, ALICE_API)])).unwrap();
        let address = start_front(origins);

        let unknown = request(address, b"GET / HTTP/1.1\r\nHost: a9.demo.dregg.online\r\n\r\n");
        assert!(unknown.starts_with("HTTP/1.1 404"), "{unknown}");
        let not_grain = request(address, b"GET / HTTP/1.1\r\nHost: demo.dregg.online\r\n\r\n");
        assert!(not_grain.starts_with("HTTP/1.1 404"), "{not_grain}");
        let anonymous = request(address, b"GET /pad HTTP/1.1\r\nHost: a4501.demo.dregg.online\r\n\r\n");
        assert!(anonymous.starts_with("HTTP/1.1 403") && anonymous.contains("mini apps open --grain a4501"), "{anonymous}");
        let form = request(address, b"GET /__mini/bootstrap HTTP/1.1\r\nHost: a4501.demo.dregg.online\r\n\r\n");
        assert!(form.starts_with("HTTP/1.1 200") && form.contains("name=\"token\""), "{form}");
        let wrong_cookie = request(address, format!("GET /pad HTTP/1.1\r\nHost: a4501.demo.dregg.online\r\nCookie: {COOKIE_NAME}={STRANGER}\r\n\r\n").as_bytes());
        assert!(wrong_cookie.starts_with("HTTP/1.1 403"), "{wrong_cookie}");

        let cookie = request(address, format!("GET /pad HTTP/1.1\r\nHost: a4501.demo.dregg.online\r\nCookie: {COOKIE_NAME}={ALICE}\r\n\r\n").as_bytes());
        assert!(cookie.starts_with("HTTP/1.1 200") && cookie.ends_with("custodian saw GET /pad"), "{cookie}");
        let bearer = request(address, format!("GET /api HTTP/1.1\r\nHost: a4501.demo.dregg.online\r\nAuthorization: Bearer {ALICE_API}\r\n\r\n").as_bytes());
        assert!(bearer.ends_with("custodian saw GET /api"), "{bearer}");
        let body = format!("token={ALICE_BOOT}");
        let bootstrap = request(
            address,
            format!("POST /__mini/bootstrap HTTP/1.1\r\nHost: a4501.demo.dregg.online\r\nOrigin: https://a4501.demo.dregg.online\r\nContent-Length: {}\r\n\r\n{body}", body.len()).as_bytes(),
        );
        assert!(bootstrap.ends_with("custodian saw POST /__mini/bootstrap"), "{bootstrap}");
        let wrong_bootstrap = request(
            address,
            format!("POST /__mini/bootstrap HTTP/1.1\r\nHost: a4501.demo.dregg.online\r\nContent-Length: 70\r\n\r\ntoken={STRANGER}").as_bytes(),
        );
        assert!(wrong_bootstrap.starts_with("HTTP/1.1 403"), "{wrong_bootstrap}");

        // WebSocket: 101 and bytes both ways, the first frame beside the head included.
        let mut ws = TcpStream::connect(address).unwrap();
        ws.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
        ws.write_all(format!("GET /ws HTTP/1.1\r\nHost: a4501.demo.dregg.online\r\nCookie: {COOKIE_NAME}={ALICE}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n").as_bytes()).unwrap();
        let mut got = Vec::new();
        let mut chunk = [0_u8; 1024];
        while !String::from_utf8_lossy(&got).contains("first-frame") {
            let n = ws.read(&mut chunk).unwrap();
            assert!(n > 0, "upstream closed before the first frame: {}", String::from_utf8_lossy(&got));
            got.extend_from_slice(&chunk[..n]);
        }
        assert!(String::from_utf8_lossy(&got).starts_with("HTTP/1.1 101"));
        ws.write_all(b"hello").unwrap();
        let mut echo = Vec::new();
        while !String::from_utf8_lossy(&echo).contains("echo:hello") {
            let n = ws.read(&mut chunk).unwrap();
            assert!(n > 0);
            echo.extend_from_slice(&chunk[..n]);
        }
        ws.shutdown(Shutdown::Write).unwrap();
        let mut rest = Vec::new();
        let _ = ws.read_to_end(&mut rest);
        assert!(String::from_utf8_lossy(&rest).ends_with("bye"), "{}", String::from_utf8_lossy(&rest));
        let seen = custodian.join().unwrap();
        assert_eq!(seen.len(), 4);
        let bootstrap_seen = String::from_utf8_lossy(&seen[2]).into_owned();
        assert!(bootstrap_seen.contains("Origin: https://a4501.demo.dregg.online") && bootstrap_seen.ends_with(&body), "forwarded unchanged: {bootstrap_seen}");
        let _ = std::fs::remove_dir_all(&dir);
    }
}
