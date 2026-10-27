//! App-side transport only. Mini grants and exact dispatch admission stay in Mini.
use capnp::traits::HasTypeId;
use capnp_rpc::{rpc_twoparty_capnp, twoparty, RpcSystem};
use futures::AsyncReadExt as _;
use minidregg_spk_rpc::{api_session_capnp, grain_capnp, web_session_capnp as web};
use std::{
    net::{Ipv4Addr, SocketAddrV4},
    sync::Arc,
    time::Duration,
};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::{TcpStream, UnixStream},
    sync::Semaphore,
};
use tokio_util::compat::TokioAsyncReadCompatExt;

pub const MAX_REQUEST: usize = 16 * 1024;
pub const MAX_REPLY: usize = 2 * 1024 * 1024;
const MAX_HEADERS: usize = 16 * 1024;
const MAX_IN_FLIGHT: usize = 8;

#[derive(Clone)]
pub struct Config {
    port: u16,
    deadline: Duration,
    slots: Arc<Semaphore>,
}
impl Config {
    pub fn new(port: u16, deadline: Duration) -> Result<Self, String> {
        if port == 0 || deadline.is_zero() || deadline > Duration::from_secs(300) {
            return Err("port must be nonzero and deadline between 1ns and 300s".into());
        }
        Ok(Self {
            port,
            deadline,
            slots: Arc::new(Semaphore::new(MAX_IN_FLIGHT)),
        })
    }
}

fn failure(message: impl Into<String>) -> capnp::Error {
    capnp::Error::failed(message.into())
}

#[derive(Debug)]
struct Reply {
    status: u16,
    body: Vec<u8>,
}
impl Reply {
    fn error(status: u16, message: &str) -> Self {
        Self { status, body: serde_json::to_vec(&serde_json::json!({"outcome":"error", "error":message, "state_may_have_changed":false})).unwrap() }
    }
}

async fn exchange(config: &Config, method: &str, path: &str, body: &[u8]) -> capnp::Result<Reply> {
    let _permit = match config.slots.clone().try_acquire_owned() {
        Ok(permit) => permit,
        Err(_) => return Ok(Reply::error(429, "bridge_busy")),
    };
    tokio::time::timeout(config.deadline, http(config.port, method, path, body)).await
        .map_err(|_| failure("upstream deadline; delivery may be uncertain; retry only the original request ID and bytes"))?
        .map_err(|e| failure(format!("upstream transport failure ({e}); delivery may be uncertain; retry only the original request ID and bytes")))
}

async fn http(port: u16, method: &str, path: &str, body: &[u8]) -> Result<Reply, String> {
    let mut stream = TcpStream::connect(SocketAddrV4::new(Ipv4Addr::LOCALHOST, port))
        .await
        .map_err(|e| e.to_string())?;
    let head = format!("{method} /{path} HTTP/1.0\r\nHost: 127.0.0.1:{port}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n", body.len());
    stream
        .write_all(head.as_bytes())
        .await
        .map_err(|e| e.to_string())?;
    stream.write_all(body).await.map_err(|e| e.to_string())?;
    let mut data = Vec::new();
    let boundary = loop {
        if let Some(index) = data.windows(4).position(|w| w == b"\r\n\r\n") {
            break index + 4;
        }
        if data.len() >= MAX_HEADERS {
            return Err("headers exceed bound".into());
        }
        let mut part = [0; 1024];
        let n = stream.read(&mut part).await.map_err(|e| e.to_string())?;
        if n == 0 {
            return Err("incomplete HTTP headers".into());
        }
        data.extend_from_slice(&part[..n]);
    };
    if boundary > MAX_HEADERS {
        return Err("headers exceed bound".into());
    }
    let header = std::str::from_utf8(&data[..boundary]).map_err(|_| "invalid header encoding")?;
    let mut lines = header[..header.len() - 4].split("\r\n");
    let mut status_line = lines.next().ok_or("missing status")?.splitn(3, ' ');
    if !matches!(status_line.next(), Some("HTTP/1.0" | "HTTP/1.1")) {
        return Err("unsupported HTTP version".into());
    }
    let code = status_line.next().ok_or("missing status")?;
    if code.len() != 3 || !code.bytes().all(|b| b.is_ascii_digit()) {
        return Err("invalid status".into());
    }
    let status: u16 = code.parse().map_err(|_| "invalid status")?;
    if !(200..=599).contains(&status) {
        return Err("unsupported status".into());
    }
    let mut length = None;
    let mut mime = None;
    for line in lines {
        let (name, value) = line.split_once(':').ok_or("invalid header")?;
        if name.is_empty() || !name.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-') {
            return Err("invalid header name".into());
        }
        let value = value.trim();
        if value.bytes().any(|b| b < 32 && b != 9) {
            return Err("invalid header value".into());
        }
        if name.eq_ignore_ascii_case("transfer-encoding") {
            return Err("transfer encoding unsupported".into());
        }
        if name.eq_ignore_ascii_case("content-length") {
            if length.is_some() || value.is_empty() || !value.bytes().all(|b| b.is_ascii_digit()) {
                return Err("ambiguous content length".into());
            }
            length = Some(
                value
                    .parse::<usize>()
                    .map_err(|_| "invalid content length")?,
            );
        }
        if name.eq_ignore_ascii_case("content-type") {
            if mime.is_some() {
                return Err("duplicate content type".into());
            }
            mime = Some(value.to_owned());
        }
    }
    if mime.as_deref().and_then(|s| s.split(';').next()) != Some("application/json") {
        return Err("upstream must return JSON content type".into());
    }
    let length = length.ok_or("content length required")?;
    if length > MAX_REPLY {
        return Err("reply exceeds bound; evidence was not truncated".into());
    }
    let mut body = data.split_off(boundary);
    if body.len() > length {
        return Err("bytes beyond declared response".into());
    }
    let present = body.len();
    body.resize(length, 0);
    stream
        .read_exact(&mut body[present..])
        .await
        .map_err(|e| e.to_string())?;
    // The endpoint contract closes each response. Reject hidden trailing data.
    let mut extra = [0; 1];
    if stream.read(&mut extra).await.map_err(|e| e.to_string())? != 0 {
        return Err("bytes beyond declared response".into());
    }
    Ok(Reply { status, body })
}

fn write_reply(
    mut response: web::web_session::response::Builder<'_>,
    reply: Reply,
) -> capnp::Result<()> {
    use web::web_session::response::{ClientErrorCode as C, SuccessCode as S};
    // The pinned Sandstorm union has no 429 and only one server-error variant.
    // Its whitelisted header retains the exact upstream status for API consumers.
    let mut headers = response.reborrow().init_additional_headers(1);
    headers
        .reborrow()
        .get(0)
        .set_name("x-sandstorm-app-http-status");
    headers.get(0).set_value(reply.status.to_string());
    match reply.status {
        200 => {
            let mut c = response.init_content();
            c.set_status_code(S::Ok);
            c.set_mime_type("application/json");
            c.init_body().set_bytes(&reply.body);
        }
        400..=499 => {
            let code = match reply.status {
                403 => C::Forbidden,
                404 => C::NotFound,
                405 => C::MethodNotAllowed,
                406 => C::NotAcceptable,
                410 => C::Gone,
                412 => C::PreconditionFailed,
                414 => C::RequestUriTooLong,
                418 => C::ImATeapot,
                422 => C::UnprocessableEntity,
                409 => C::Conflict,
                413 => C::RequestEntityTooLarge,
                415 => C::UnsupportedMediaType,
                _ => C::BadRequest,
            };
            let mut c = response.init_client_error();
            c.set_status_code(code);
            let mut b = c.init_non_html_body();
            b.set_mime_type("application/json");
            b.set_data(&reply.body);
        }
        500..=599 => {
            let mut b = response.init_server_error().init_non_html_body();
            b.set_mime_type("application/json");
            b.set_data(&reply.body);
        }
        _ => {
            return Err(failure(
                "unsupported success/redirect status from Oracle adapter",
            ))
        }
    }
    Ok(())
}

// This narrow API has no cookie/header/precondition semantics. Refuse these
// inputs instead of silently weakening a caller's intended conditional request.
fn plain_context(ctx: web::web_session::context::Reader<'_>) -> capnp::Result<bool> {
    Ok(ctx.get_cookies()?.is_empty()
        && ctx.get_additional_headers()?.is_empty()
        && ctx.get_accept_encoding()?.is_empty()
        && matches!(
            ctx.get_e_tag_precondition().which()?,
            web::web_session::context::e_tag_precondition::None(())
        ))
}

// JSON is the only representation. A more specific range overrides a wildcard,
// including q=0: `application/json;q=0, */*;q=1` must not receive JSON.
fn accepts_json(ctx: web::web_session::context::Reader<'_>) -> capnp::Result<bool> {
    let accept = ctx.get_accept()?;
    if accept.is_empty() {
        return Ok(true);
    }
    let mut best = None;
    for range in accept.iter() {
        let name = range.get_mime_type()?.to_str()?.to_ascii_lowercase();
        let specificity = match name.as_str() {
            "application/json" => 2,
            "application/*" => 1,
            "*/*" => 0,
            _ => continue,
        };
        let quality = range.get_q_value();
        if !quality.is_finite() || !(0.0..=1.0).contains(&quality) {
            return Ok(false);
        }
        if best.is_none_or(|(s, q)| specificity > s || (specificity == s && quality > q)) {
            best = Some((specificity, quality));
        }
    }
    Ok(best.is_some_and(|(_, quality)| quality > 0.0))
}

struct MainView(Config);
impl grain_capnp::ui_view::Server for MainView {
    async fn get_view_info(
        self: capnp::capability::Rc<Self>,
        _: grain_capnp::ui_view::GetViewInfoParams,
        mut results: grain_capnp::ui_view::GetViewInfoResults,
    ) -> capnp::Result<()> {
        let mut info = results.get();
        info.reborrow().init_app_title().set_default_text("Oracle7");
        let mut p = info.reborrow().init_permissions(1).get(0);
        p.set_name("query");
        p.reborrow().init_title().set_default_text("Ask questions");
        p.init_description()
            .set_default_text("Use this appliance's shared conversation workspace");
        let mut r = info.init_roles(1).get(0);
        r.reborrow().init_title().set_default_text("Researcher");
        r.reborrow()
            .init_verb_phrase()
            .set_default_text("can ask questions");
        r.reborrow()
            .init_description()
            .set_default_text("Ask questions and inspect this appliance");
        r.init_permissions(1).set(0, true);
        Ok(())
    }
    async fn new_session(
        self: capnp::capability::Rc<Self>,
        params: grain_capnp::ui_view::NewSessionParams,
        mut results: grain_capnp::ui_view::NewSessionResults,
    ) -> capnp::Result<()> {
        let params = params.get()?;
        let kind = params.get_session_type();
        if kind != web::web_session::Client::TYPE_ID
            && kind != api_session_capnp::api_session::Client::TYPE_ID
        {
            return Err(capnp::Error::unimplemented(
                "only WebSession/ApiSession supported".into(),
            ));
        }
        let permissions = params.get_user_info()?.get_permissions()?;
        if permissions.len() != 1 || !permissions.get(0) {
            return Err(failure("query permission is required"));
        }
        let session: web::web_session::Client = capnp_rpc::new_client(Session(self.0.clone()));
        results.get().set_session(grain_capnp::ui_session::Client {
            client: session.client,
        });
        Ok(())
    }
}
impl grain_capnp::main_view::Server<capnp::data::Owned> for MainView {}
struct Session(Config);
impl grain_capnp::ui_session::Server for Session {}
impl web::web_session::Server for Session {
    async fn get(
        self: capnp::capability::Rc<Self>,
        params: web::web_session::GetParams,
        mut results: web::web_session::GetResults,
    ) -> capnp::Result<()> {
        let params = params.get()?;
        let path = params.get_path()?.to_str()?;
        let reply = if !plain_context(params.get_context()?)? {
            Reply::error(400, "context_unsupported")
        } else if !accepts_json(params.get_context()?)? {
            Reply::error(406, "json_not_acceptable")
        } else if !matches!(path, "health" | "capabilities") {
            Reply::error(404, "route_not_found")
        } else if params.get_ignore_body() {
            Reply::error(405, "head_unsupported")
        } else {
            exchange(&self.0, "GET", path, &[]).await?
        };
        write_reply(results.get(), reply)
    }
    async fn post(
        self: capnp::capability::Rc<Self>,
        params: web::web_session::PostParams,
        mut results: web::web_session::PostResults,
    ) -> capnp::Result<()> {
        let params = params.get()?;
        let content = params.get_content()?;
        let bytes = content.get_content()?;
        let reply = if !plain_context(params.get_context()?)? {
            Reply::error(400, "context_unsupported")
        } else if !accepts_json(params.get_context()?)? {
            Reply::error(406, "json_not_acceptable")
        } else if params.get_path()?.to_str()? != "query" {
            Reply::error(404, "route_not_found")
        } else if bytes.len() > MAX_REQUEST {
            Reply::error(413, "request_too_large")
        } else if content.get_mime_type()?.to_str()? != "application/json"
            || !content.get_encoding()?.is_empty()
        {
            Reply::error(415, "json_required")
        } else {
            exchange(&self.0, "POST", "query", bytes).await?
        };
        write_reply(results.get(), reply)
    }
}

/// Drive this future on a LocalSet until fd3 disconnects. No listener is opened.
pub fn connection(stream: UnixStream, config: Config) -> RpcSystem<rpc_twoparty_capnp::Side> {
    let main: grain_capnp::main_view::Client<capnp::data::Owned> =
        capnp_rpc::new_client(MainView(config));
    let (read, write) = stream.compat().split();
    let net = twoparty::VatNetwork::new(
        futures::io::BufReader::new(read),
        futures::io::BufWriter::new(write),
        rpc_twoparty_capnp::Side::Client,
        capnp::message::ReaderOptions {
            traversal_limit_in_words: Some(2 * 1024 * 1024),
            nesting_limit: 64,
        },
    );
    RpcSystem::new(Box::new(net), Some(main.client))
}
