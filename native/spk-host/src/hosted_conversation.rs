//! Physical execution of the source-checked, bounded hosted descriptor.
//! Every invocation arrives through a fresh lifetime permit and one-shot retained send.
use crate::rpc_adapter::SessionBinding;
use minidregg_spk_rpc::{
    dispatch_web, open_web_socket, send_to_app, WebRequest, WebResponse, WebResult, WebSocketOpen,
    WebSocketSession,
};
use serde_json::{json, Value};
use std::collections::{HashMap, HashSet};
use std::io::{self, Read};
use std::path::PathBuf;
use std::time::{Duration, Instant};
mod vocabulary {
    include!("../../hosted-conversation.rs");
}
pub(crate) use vocabulary::METHOD;
pub(crate) fn descriptor(body: &[u8]) -> Result<Value, &'static str> {
    vocabulary::parse(body)
}
fn invalid(s: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, s)
}
#[derive(Clone)]
pub(crate) struct Custody {
    pub directory: PathBuf,
    pub api_prefix: Option<String>,
}
struct Channel {
    binding: SessionBinding,
    endpoint: String,
    protocol: String,
    expires: Instant,
    socket: WebSocketSession,
    buffered: Vec<u8>,
    fragment: Vec<u8>,
    fragmenting: bool,
    ids: HashSet<String>,
    max_frames: usize,
    max_bytes: usize,
}
#[derive(Default)]
pub(crate) struct Pool {
    channels: HashMap<String, Option<Channel>>,
}
fn same_binding(a: &SessionBinding, b: &SessionBinding) -> bool {
    a.app == b.app
        && a.process_generation == b.process_generation
        && a.session_resource == b.session_resource
        && a.session_generation == b.session_generation
        && a.subject == b.subject
        && a.kind == b.kind
        && a.projection_fingerprint == b.projection_fingerprint
        && a.params.identity_id == b.params.identity_id
        && a.params.base_path == b.params.base_path
        && a.params.permissions == b.params.permissions
}
fn number(v: &Value, k: &str) -> usize {
    v[k].as_u64().unwrap() as usize
}
fn string<'a>(v: &'a Value, k: &str) -> &'a str {
    v[k].as_str().unwrap()
}
fn frame(text: &str) -> io::Result<Vec<u8>> {
    let mut mask = [0; 4];
    std::fs::File::open("/dev/urandom")?.read_exact(&mut mask)?;
    let mut out = vec![0x81];
    let n = text.len();
    if n < 126 {
        out.push(0x80 | n as u8);
    } else {
        out.push(0x80 | 126);
        out.extend_from_slice(&(n as u16).to_be_bytes());
    }
    out.extend_from_slice(&mask);
    out.extend(text.bytes().enumerate().map(|(i, b)| b ^ mask[i % 4]));
    Ok(out)
}
impl Channel {
    fn send_preimage(&mut self, text: &str, custody: &Custody) -> io::Result<Vec<u8>> {
        if self.max_frames == 0 || text.len() > self.max_bytes {
            return Err(invalid("hosted cumulative channel budget exhausted"));
        }
        let value: Value = if self.protocol == "ddp-v1" {
            serde_json::from_str(text).map_err(|_| invalid("DDP text is not JSON"))?
        } else {
            Value::Null
        };
        if value["msg"] == "method" {
            let id = value["id"]
                .as_str()
                .ok_or_else(|| invalid("DDP method id absent"))?;
            if !self.ids.insert(id.to_owned()) {
                return Err(invalid("DDP method id already sent on this connection"));
            }
        }
        self.max_frames -= 1;
        self.max_bytes -= text.len();
        let bytes = frame(text)?;
        crate::dispatch_native::write_new(&custody.directory, "hosted-frame.bin", &bytes)?;
        Ok(bytes)
    }
    async fn next_text(&mut self, deadline: Instant, limit: usize) -> io::Result<String> {
        loop {
            if self.buffered.len() >= 2 {
                let first = self.buffered[0];
                let second = self.buffered[1];
                if first & 0x70 != 0 || second & 0x80 != 0 {
                    return Err(invalid("unsupported server WebSocket frame flags"));
                }
                let mut offset = 2;
                let size = match second & 0x7f {
                    126 => {
                        if self.buffered.len() < 4 {
                            None
                        } else {
                            offset = 4;
                            Some(u16::from_be_bytes([self.buffered[2], self.buffered[3]]) as usize)
                        }
                    }
                    127 => {
                        if self.buffered.len() < 10 {
                            None
                        } else {
                            offset = 10;
                            Some(
                                usize::try_from(u64::from_be_bytes(
                                    self.buffered[2..10].try_into().unwrap(),
                                ))
                                .map_err(|_| invalid("WebSocket frame length overflow"))?,
                            )
                        }
                    }
                    n => Some(n as usize),
                };
                if let Some(size) = size {
                    if size > limit || self.fragment.len().saturating_add(size) > limit {
                        return Err(invalid("hosted frame byte budget exceeded"));
                    }
                    if self.buffered.len() >= offset + size {
                        let payload = self.buffered[offset..offset + size].to_vec();
                        self.buffered.drain(..offset + size);
                        match first & 0x0f {
                            1 if !self.fragmenting => {
                                self.fragment = payload;
                                self.fragmenting = true;
                            }
                            0 if self.fragmenting => self.fragment.extend(payload),
                            10 => continue,
                            8 => return Err(invalid("hosted channel closed by app")),
                            _ => return Err(invalid("hosted protocol requires text frames")),
                        }
                        if first & 0x80 != 0 {
                            self.fragmenting = false;
                            return String::from_utf8(std::mem::take(&mut self.fragment))
                                .map_err(|_| invalid("hosted text is not UTF8"));
                        }
                        continue;
                    }
                }
            }
            let remaining = deadline
                .checked_duration_since(Instant::now())
                .ok_or_else(|| {
                    io::Error::new(io::ErrorKind::TimedOut, "hosted receive deadline")
                })?;
            let bytes = tokio::time::timeout(remaining, self.socket.from_app.recv())
                .await
                .map_err(|_| io::Error::new(io::ErrorKind::TimedOut, "hosted receive deadline"))?
                .ok_or_else(|| invalid("hosted app stream ended"))?;
            if self.buffered.len().saturating_add(bytes.len()) > limit + 64 * 14 {
                return Err(invalid("hosted raw frame budget exceeded"));
            }
            self.buffered.extend(bytes);
        }
    }
}
fn response(value: Value) -> io::Result<WebResponse> {
    let body = serde_json::to_vec(&value)?;
    if body.len() > 65_536 {
        return Err(invalid("hosted response byte bound exceeded"));
    }
    Ok(WebResponse {
        result: WebResult::Content {
            status: 200,
            mime_type: "application/json".into(),
            encoding: String::new(),
            language: String::new(),
            etag: None,
            body,
            download_name: None,
        },
        headers: vec![],
        set_cookies: vec![],
    })
}
impl Pool {
    pub(crate) async fn execute(
        &mut self,
        session: &minidregg_spk_rpc::web_session_capnp::web_session::Client,
        binding: &SessionBinding,
        request: &WebRequest,
        custody: &Custody,
        deadline: Instant,
    ) -> io::Result<WebResponse> {
        let d = descriptor(
            &request
                .body
                .as_ref()
                .ok_or_else(|| invalid("hosted descriptor body absent"))?
                .bytes,
        )
        .map_err(invalid)?;
        let op = string(&d, "op");
        let id = string(&d, "channel").to_owned();
        if op == "open" {
            if self.channels.values().filter(|c| c.is_some()).count() >= vocabulary::MAX_CHANNELS
                || self.channels.len() >= vocabulary::MAX_CHANNEL_IDS
                || self.channels.contains_key(&id)
            {
                return Err(invalid("hosted channel cap or reused id"));
            }
            self.channels.insert(id.clone(), None);
            let left = Duration::from_millis(number(&d, "deadlineMs") as u64)
                .min(deadline.saturating_duration_since(Instant::now()));
            let opened = open_web_socket(
                session,
                &WebSocketOpen {
                    path_and_query: request.path_and_query.clone(),
                    context: request.context.clone(),
                    protocols: vec![],
                },
                left,
            )
            .await
            .map_err(io::Error::other)?;
            self.channels.insert(
                id.clone(),
                Some(Channel {
                    binding: binding.clone(),
                    endpoint: request.path_and_query.clone(),
                    protocol: string(&d, "protocol").to_owned(),
                    expires: Instant::now()
                        + Duration::from_millis(vocabulary::CHANNEL_LIFETIME_MS),
                    socket: opened,
                    buffered: vec![],
                    fragment: vec![],
                    fragmenting: false,
                    ids: HashSet::new(),
                    max_frames: number(&d, "maxFrames"),
                    max_bytes: number(&d, "maxBytes"),
                }),
            );
            return response(json!({"version":1,"channel":id,"op":op,"frames":[]}));
        }
        // Taking the channel makes every interrupted/uncertain command terminal.
        // No failed send, timeout or reconnect implicitly restores its socket.
        let channel = self
            .channels
            .get_mut(&id)
            .ok_or_else(|| invalid("hosted channel absent"))?;
        let mut channel = channel
            .take()
            .ok_or_else(|| invalid("hosted channel uncertain or closed"))?;
        if Instant::now() >= channel.expires {
            return Err(invalid("hosted channel lifetime exhausted"));
        }
        let deadline = deadline.min(channel.expires);
        if !same_binding(&channel.binding, binding) || channel.endpoint != request.path_and_query {
            return Err(invalid(
                "hosted channel subject generation projection or endpoint changed",
            ));
        }
        let mut result = json!({"version":1,"channel":id,"op":op,"frames":[]});
        match op {
            "send" => {
                let bytes = channel.send_preimage(string(&d, "text"), custody)?;
                send_to_app(&channel.socket.to_app, &bytes)
                    .await
                    .map_err(io::Error::other)?;
            }
            "receive" => {
                let count = number(&d, "maxFrames").min(channel.max_frames);
                let limit = number(&d, "maxBytes").min(channel.max_bytes);
                let deadline = (Instant::now()
                    + Duration::from_millis(number(&d, "deadlineMs") as u64))
                .min(deadline);
                if count == 0 || limit == 0 {
                    return Err(invalid("hosted cumulative channel budget exhausted"));
                }
                let text = match channel.next_text(deadline, limit).await {
                    Ok(text) => Some(text),
                    Err(error) if error.kind() == io::ErrorKind::TimedOut => None,
                    Err(error) => return Err(error),
                };
                if let Some(text) = text {
                    channel.max_frames -= 1;
                    channel.max_bytes -= text.len();
                    result["frames"] = json!([text]);
                }
                // Early return: typed SDK correlation can issue a separately
                // admitted pong or continue within its remaining budget.
            }
            "rendezvous" => {
                let bytes = channel.send_preimage(string(&d, "text"), custody)?;
                let http = crate::dispatch_web_input::hosted_http(
                    &d["http"],
                    binding,
                    custody.api_prefix.as_deref(),
                )?;
                crate::dispatch_native::write_new(
                    &custody.directory,
                    "hosted-http.json",
                    &serde_json::to_vec(&d["http"])?,
                )?;
                let left = Duration::from_millis(number(&d, "deadlineMs") as u64)
                    .min(deadline.saturating_duration_since(Instant::now()));
                // Wait only for byte-stream delivery, never the DDP method result.
                // The pending login and HTTP half execute concurrently in the app;
                // registration bytes are released first to avoid a pre-registration POST.
                send_to_app(&channel.socket.to_app, &bytes)
                    .await
                    .map_err(io::Error::other)?;
                let reply = dispatch_web(session, &http, number(&d, "maxBytes"), left)
                    .await
                    .map_err(io::Error::other)?;
                let raw = crate::http_response::serialize(&reply, false)?;
                let boundary = raw
                    .windows(4)
                    .position(|w| w == b"\r\n\r\n")
                    .ok_or_else(|| invalid("hosted HTTP response framing"))?;
                let status = std::str::from_utf8(&raw[..boundary])
                    .ok()
                    .and_then(|s| s.split_whitespace().nth(1))
                    .and_then(|s| s.parse::<u16>().ok())
                    .ok_or_else(|| invalid("hosted HTTP response status"))?;
                result["httpStatus"] = json!(status);
                result["httpBodyHex"] = json!(crate::canonical::hex(&raw[boundary + 4..]));
            }
            "close" => return response(result),
            _ => return Err(invalid("hosted operation absent from vocabulary")),
        }
        let response = response(result)?;
        self.channels.insert(id, Some(channel));
        Ok(response)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn descriptor_is_bounded_and_method_shape_is_closed() {
        let valid = br#"{"version":1,"op":"send","channel":"c-1","text":"{\"msg\":\"ping\"}"}"#;
        assert!(descriptor(valid).is_ok());
        let bad = String::from_utf8(valid.to_vec())
            .unwrap()
            .replace("\"send\"", "\"send-anything\"");
        assert!(descriptor(bad.as_bytes()).is_err());
        assert!(descriptor(br#"{"version":1,"op":"close","channel":"../other"}"#).is_err());
        assert!(descriptor(br#"{"version":1,"op":"close","channel":"c","subject":2}"#).is_err());
    }
}
