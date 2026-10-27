//! Gateway mode: interactions over Discord's WebSocket instead of an Interactions Endpoint URL.
//!
//! An application with no endpoint URL gets its `INTERACTION_CREATE` events delivered to the bot
//! over the gateway. The bot connects (`wss://gateway.discord.gg/?v=10&encoding=json`), IDENTIFYs
//! with its token and intents 0 (interactions need no intent at all, privileged or not),
//! heartbeats at HELLO's interval, and resumes after RECONNECT, an INVALID_SESSION that says it
//! may, a missed heartbeat ACK or a dropped connection, with a jittered backoff between attempts.
//! Each interaction goes to the SAME handler the HTTP mode uses (`App::handle_interaction`: the
//! roster, the bounded line, at most 4 running, ephemeral answers, durable custody); its reply is
//! POSTed to `/interactions/{id}/{token}/callback`, and a deferred line's answer PATCHes
//! `@original` exactly as in HTTP mode. No signature check: the TLS connection the bot opened to
//! Discord authenticates every event on it.
//!
//! Resumes go to the configured gateway host, never to READY's `resume_gateway_url`: the box's
//! egress allows `gateway.discord.gg` by name, and a resume Discord refuses there ends in
//! INVALID_SESSION and a fresh IDENTIFY, which loses nothing an interaction depends on.
//!
//! The bot token is read from a file (`MINI_DISCORD_BOT_TOKEN_FILE`, systemd's `LoadCredential=`)
//! and lives only in this process; it is sent only in IDENTIFY and RESUME.

use std::io::{Read, Write};
use std::net::TcpStream;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use serde_json::{json, Value};
use tungstenite::protocol::{frame::coding::CloseCode, Message, WebSocket};

use crate::server::App;

pub const GATEWAY: &str = "wss://gateway.discord.gg/?v=10&encoding=json";
/// The largest gateway message read (a READY with intents 0 is a few KiB).
const MAX_MESSAGE: usize = 1 << 20;
/// How often the read loop wakes to check the heartbeat when the socket is quiet.
const TICK: Duration = Duration::from_millis(250);

/// The parts of a `ws://` or `wss://` URL the client needs.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Url {
    pub tls: bool,
    pub host: String,
    pub port: u16,
    pub path: String,
}

impl Url {
    pub fn parse(url: &str) -> Result<Url, String> {
        let (tls, rest) = if let Some(r) = url.strip_prefix("wss://") {
            (true, r)
        } else if let Some(r) = url.strip_prefix("ws://") {
            (false, r)
        } else {
            return Err("the gateway URL is ws:// or wss://".into());
        };
        let (authority, path) = match rest.find('/') {
            Some(i) => (&rest[..i], &rest[i..]),
            None => (rest, "/"),
        };
        let (host, port) = match authority.rsplit_once(':') {
            Some((h, p)) => (h, p.parse::<u16>().map_err(|_| "the gateway URL's port is not a number")?),
            None => (authority, if tls { 443 } else { 80 }),
        };
        if host.is_empty() || !host.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'-') {
            return Err("the gateway URL's host is not a plain host name".into());
        }
        if url.len() > 2048 || !url.bytes().all(|b| b.is_ascii_graphic() && b != b'"' && b != b'\\') {
            return Err("the gateway URL has characters outside plain ASCII".into());
        }
        Ok(Url { tls, host: host.into(), port, path: path.into() })
    }
}

/// A TCP stream, or rustls over one.
pub enum Stream {
    Plain(TcpStream),
    Tls(Box<rustls::StreamOwned<rustls::ClientConnection, TcpStream>>),
}

impl Stream {
    fn tcp(&self) -> &TcpStream {
        match self {
            Stream::Plain(s) => s,
            Stream::Tls(s) => s.get_ref(),
        }
    }
}

impl Read for Stream {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        match self {
            Stream::Plain(s) => s.read(buf),
            Stream::Tls(s) => s.read(buf),
        }
    }
}

impl Write for Stream {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        match self {
            Stream::Plain(s) => s.write(buf),
            Stream::Tls(s) => s.write(buf),
        }
    }
    fn flush(&mut self) -> std::io::Result<()> {
        match self {
            Stream::Plain(s) => s.flush(),
            Stream::Tls(s) => s.flush(),
        }
    }
}

/// The trust anchors: the system bundle (Debian's `/etc/ssl/certs/ca-certificates.crt`).
pub fn tls_config(ca_file: &std::path::Path) -> Result<Arc<rustls::ClientConfig>, String> {
    let pem = std::fs::read(ca_file).map_err(|e| format!("{}: {e}", ca_file.display()))?;
    let mut roots = rustls::RootCertStore::empty();
    for cert in rustls_pemfile::certs(&mut pem.as_slice()) {
        let cert = cert.map_err(|e| format!("{}: {e}", ca_file.display()))?;
        let _ = roots.add(cert);
    }
    if roots.is_empty() {
        return Err(format!("{} holds no trust anchor", ca_file.display()));
    }
    let provider = Arc::new(rustls::crypto::ring::default_provider());
    let config = rustls::ClientConfig::builder_with_provider(provider)
        .with_safe_default_protocol_versions()
        .map_err(|e| e.to_string())?
        .with_root_certificates(roots)
        .with_no_client_auth();
    Ok(Arc::new(config))
}

fn connect(url: &Url, tls: Option<&Arc<rustls::ClientConfig>>) -> Result<WebSocket<Stream>, String> {
    use std::net::ToSocketAddrs;
    let addr = (url.host.as_str(), url.port)
        .to_socket_addrs()
        .map_err(|e| format!("resolve {}: {e}", url.host))?
        .next()
        .ok_or_else(|| format!("{} resolves to nothing", url.host))?;
    let tcp = TcpStream::connect_timeout(&addr, Duration::from_secs(10)).map_err(|e| format!("connect {}: {e}", url.host))?;
    tcp.set_read_timeout(Some(Duration::from_secs(10))).map_err(|e| e.to_string())?;
    tcp.set_write_timeout(Some(Duration::from_secs(10))).map_err(|e| e.to_string())?;
    let stream = if url.tls {
        let config = tls.ok_or("a wss:// gateway needs the TLS configuration")?.clone();
        let name = rustls::pki_types::ServerName::try_from(url.host.clone()).map_err(|e| e.to_string())?;
        let conn = rustls::ClientConnection::new(config, name).map_err(|e| e.to_string())?;
        Stream::Tls(Box::new(rustls::StreamOwned::new(conn, tcp)))
    } else {
        Stream::Plain(tcp)
    };
    let request = format!("{}://{}:{}{}", if url.tls { "wss" } else { "ws" }, url.host, url.port, url.path);
    let config = tungstenite::protocol::WebSocketConfig::default()
        .max_message_size(Some(MAX_MESSAGE))
        .max_frame_size(Some(MAX_MESSAGE));
    let (socket, _) = tungstenite::client::client_with_config(request.as_str(), stream, Some(config))
        .map_err(|e| format!("gateway handshake: {e}"))?;
    socket.get_ref().tcp().set_read_timeout(Some(TICK)).map_err(|e| e.to_string())?;
    Ok(socket)
}

/// What survives a connection: enough to RESUME.
#[derive(Debug, Default, Clone)]
pub struct Session {
    pub id: Option<String>,
    pub seq: Option<u64>,
}

/// Why a connection ended.
#[derive(Debug, PartialEq, Eq)]
pub enum End {
    /// Reconnect and RESUME.
    Resume,
    /// Reconnect and IDENTIFY afresh (the session is gone).
    Fresh,
    /// Do not reconnect: the token or the configuration is refused (close codes 4004, 4010-4014).
    Fatal(String),
    /// The caller asked to stop.
    Stopped,
}

pub struct Gateway {
    pub app: Arc<App>,
    pub url: Url,
    pub token: String,
    pub tls: Option<Arc<rustls::ClientConfig>>,
    pub stop: Arc<AtomicBool>,
}

fn jitter(max: Duration) -> Duration {
    let mut b = [0u8; 2];
    let _ = std::fs::File::open("/dev/urandom").and_then(|mut f| f.read_exact(&mut b));
    max.mul_f64(u16::from_le_bytes(b) as f64 / u16::MAX as f64)
}

fn send(socket: &mut WebSocket<Stream>, v: &Value) -> Result<(), String> {
    socket.send(Message::text(v.to_string())).map_err(|e| format!("gateway send: {e}"))
}

impl Gateway {
    /// Connect, and keep connecting with backoff, until stopped or refused for good.
    pub fn run(&self) -> Result<(), String> {
        let mut session = Session::default();
        let mut backoff = Duration::from_secs(1);
        while !self.stop.load(Ordering::SeqCst) {
            let started = Instant::now();
            let end = match connect(&self.url, self.tls.as_ref()) {
                Ok(mut socket) => self.connection(&mut socket, &mut session),
                Err(e) => {
                    eprintln!("mini-discord: gateway: {e}");
                    End::Resume
                }
            };
            match end {
                End::Stopped => return Ok(()),
                End::Fatal(why) => return Err(why),
                End::Fresh => session = Session::default(),
                End::Resume => {}
            }
            if started.elapsed() > Duration::from_secs(60) {
                backoff = Duration::from_secs(1);
            }
            let wait = backoff + jitter(backoff);
            eprintln!("mini-discord: gateway: reconnecting in {} ms", wait.as_millis());
            let until = Instant::now() + wait;
            while Instant::now() < until && !self.stop.load(Ordering::SeqCst) {
                std::thread::sleep(Duration::from_millis(50));
            }
            backoff = (backoff * 2).min(Duration::from_secs(60));
        }
        Ok(())
    }

    /// One connection: HELLO, IDENTIFY or RESUME, then events until it ends.
    pub fn connection(&self, socket: &mut WebSocket<Stream>, session: &mut Session) -> End {
        let deadline = Instant::now() + Duration::from_secs(20);
        let interval = loop {
            match self.next(socket) {
                Ok(Some(v)) if v["op"] == 10 => match v["d"]["heartbeat_interval"].as_u64() {
                    Some(ms) if ms > 0 => break Duration::from_millis(ms),
                    _ => return End::Resume,
                },
                Ok(Some(_)) => {}
                Ok(None) if Instant::now() < deadline && !self.stop.load(Ordering::SeqCst) => {}
                Ok(None) => return if self.stop.load(Ordering::SeqCst) { End::Stopped } else { End::Resume },
                Err(end) => return end,
            }
        };
        let hello = match (&session.id, session.seq) {
            (Some(id), Some(seq)) => json!({"op":6,"d":{"token":self.token,"session_id":id,"seq":seq}}),
            _ => json!({"op":2,"d":{"token":self.token,"intents":0,
                "properties":{"os":"linux","browser":"mini-discord","device":"mini-discord"}}}),
        };
        if let Err(e) = send(socket, &hello) {
            eprintln!("mini-discord: gateway: {e}");
            return End::Resume;
        }
        // The first heartbeat comes after interval * jitter, the rest every interval.
        let mut beat_at = Instant::now() + jitter(interval);
        let mut acked = true;
        loop {
            if self.stop.load(Ordering::SeqCst) {
                let _ = socket.close(None);
                return End::Stopped;
            }
            if Instant::now() >= beat_at {
                if !acked {
                    // A zombied connection: no ACK for the last heartbeat.
                    eprintln!("mini-discord: gateway: no heartbeat ACK; reconnecting to resume");
                    let _ = socket.close(Some(tungstenite::protocol::CloseFrame { code: CloseCode::Library(4000), reason: "".into() }));
                    return End::Resume;
                }
                if let Err(e) = send(socket, &json!({"op":1,"d":session.seq})) {
                    eprintln!("mini-discord: gateway: {e}");
                    return End::Resume;
                }
                acked = false;
                beat_at = Instant::now() + interval;
            }
            let v = match self.next(socket) {
                Ok(Some(v)) => v,
                Ok(None) => continue,
                Err(end) => return end,
            };
            if let Some(s) = v["s"].as_u64() {
                session.seq = Some(s);
            }
            match v["op"].as_u64() {
                Some(11) => acked = true,
                // The gateway asks for a heartbeat now.
                Some(1) => {
                    if let Err(e) = send(socket, &json!({"op":1,"d":session.seq})) {
                        eprintln!("mini-discord: gateway: {e}");
                        return End::Resume;
                    }
                }
                Some(7) => {
                    eprintln!("mini-discord: gateway: RECONNECT");
                    let _ = socket.close(Some(tungstenite::protocol::CloseFrame { code: CloseCode::Library(4000), reason: "".into() }));
                    return End::Resume;
                }
                Some(9) => {
                    eprintln!("mini-discord: gateway: INVALID_SESSION (resumable: {})", v["d"]);
                    let _ = socket.close(None);
                    if v["d"] == true {
                        return End::Resume;
                    }
                    // Discord asks for 1-5 s before a fresh IDENTIFY.
                    std::thread::sleep(Duration::from_secs(1) + jitter(Duration::from_secs(4)));
                    return End::Fresh;
                }
                Some(0) => match v["t"].as_str() {
                    Some("READY") => {
                        session.id = v["d"]["session_id"].as_str().map(str::to_owned);
                        eprintln!("mini-discord: gateway: READY as {}", v["d"]["user"]["username"].as_str().unwrap_or("?"));
                    }
                    Some("RESUMED") => eprintln!("mini-discord: gateway: RESUMED at {:?}", session.seq),
                    Some("INTERACTION_CREATE") => self.interaction(&v["d"]),
                    _ => {}
                },
                _ => {}
            }
        }
    }

    /// The next JSON message; `Ok(None)` when the socket was quiet for a tick.
    fn next(&self, socket: &mut WebSocket<Stream>) -> Result<Option<Value>, End> {
        match socket.read() {
            Ok(Message::Text(text)) => match serde_json::from_str::<Value>(text.as_str()) {
                Ok(v) => Ok(Some(v)),
                Err(e) => {
                    eprintln!("mini-discord: gateway: unreadable message ({e})");
                    Ok(None)
                }
            },
            Ok(Message::Close(frame)) => {
                let code = frame.as_ref().map(|f| u16::from(f.code)).unwrap_or(1000);
                eprintln!("mini-discord: gateway: closed by Discord ({code})");
                Err(match code {
                    4004 => End::Fatal("the gateway refused the bot token (4004)".into()),
                    4010..=4014 => End::Fatal(format!("the gateway refused the configuration ({code})")),
                    4007 | 4009 => End::Fresh,
                    _ => End::Resume,
                })
            }
            Ok(_) => Ok(None),
            Err(tungstenite::Error::Io(e))
                if matches!(e.kind(), std::io::ErrorKind::WouldBlock | std::io::ErrorKind::TimedOut) =>
            {
                Ok(None)
            }
            Err(e) => {
                eprintln!("mini-discord: gateway: {e}");
                Err(End::Resume)
            }
        }
    }

    /// One `INTERACTION_CREATE`: the HTTP mode's handler, its reply POSTed to the callback, and
    /// a deferred line run (on its own thread) only once the callback was accepted.
    fn interaction(&self, d: &Value) {
        let (Some(id), Some(token)) = (d["id"].as_str(), d["token"].as_str()) else {
            eprintln!("mini-discord: gateway: an interaction without id or token");
            return;
        };
        if !crate::interaction::is_snowflake(id) || !crate::interaction::is_token(token) {
            eprintln!("mini-discord: gateway: a malformed interaction id or token");
            return;
        }
        let body = d.to_string();
        let (reply, job) = self.app.handle_interaction(body.as_bytes(), crate::now_s());
        if reply.content_type != "application/json" {
            // A refusal the HTTP mode answers with a status code (409, 400): Discord shows the
            // interaction as failed; nothing ran.
            eprintln!("mini-discord: gateway: interaction {id}: {} {}", reply.status, String::from_utf8_lossy(&reply.body).trim());
            return;
        }
        let url = format!("{}/interactions/{id}/{token}/callback", self.app.api_base());
        match self.app.poster().send("POST", &url, &reply.body) {
            Ok(code) if (200..300).contains(&code) => {
                if let Some((job, guard)) = job {
                    let app = self.app.clone();
                    std::thread::spawn(move || app.accept_and_run(job, guard));
                }
            }
            Ok(code) => eprintln!("mini-discord: gateway: callback for {id} answered HTTP {code}; line not run"),
            Err(e) => eprintln!("mini-discord: gateway: callback for {id} failed ({e}); line not run"),
        }
    }
}

/// Gateway mode's entry: the token, the TLS configuration, and the loop.
pub fn serve(app: Arc<App>, cfg: &crate::server::Config) -> Result<(), String> {
    let file = cfg.bot_token_file.as_ref().ok_or("gateway mode needs MINI_DISCORD_BOT_TOKEN_FILE")?;
    let token = std::fs::read_to_string(file).map_err(|e| format!("{}: {e}", file.display()))?.trim().to_owned();
    if token.is_empty() || token.len() > 200 || !token.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'-' | b'_')) {
        return Err(format!("{} does not hold one bot token", file.display()));
    }
    let url = Url::parse(&cfg.gateway_url)?;
    let tls = if url.tls { Some(tls_config(&cfg.ca_file)?) } else { None };
    let gateway = Gateway { app, url, token, tls, stop: Arc::new(AtomicBool::new(false)) };
    gateway.run()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn urls() {
        assert_eq!(Url::parse(GATEWAY).unwrap(), Url { tls: true, host: "gateway.discord.gg".into(), port: 443, path: "/?v=10&encoding=json".into() });
        assert_eq!(Url::parse("ws://127.0.0.1:9/x").unwrap().port, 9);
        for bad in ["https://x", "wss://", "wss://a b/", "wss://x:port/"] {
            assert!(Url::parse(bad).is_err(), "{bad}");
        }
    }
}
