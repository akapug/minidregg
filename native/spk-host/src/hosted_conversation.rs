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
    use std::os::unix::fs::DirBuilderExt;
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
    struct NoSession;
    impl minidregg_spk_rpc::grain_capnp::ui_session::Server for NoSession {}
    impl minidregg_spk_rpc::web_session_capnp::web_session::Server for NoSession {}
    struct FailingStream(std::sync::Arc<std::sync::atomic::AtomicUsize>);
    impl minidregg_spk_rpc::web_session_capnp::web_session::web_socket_stream::Server
        for FailingStream
    {
        async fn send_bytes(
            self: capnp::capability::Rc<Self>,
            _params: minidregg_spk_rpc::web_session_capnp::web_session::web_socket_stream::SendBytesParams,
        ) -> capnp::Result<()> {
            self.0.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
            Err(capnp::Error::failed("intentional lost send reply".into()))
        }
    }
    fn binding() -> SessionBinding {
        SessionBinding {
            app: 1,
            process_generation: 2,
            session_resource: 3,
            session_generation: "4".into(),
            subject: 5,
            projection_fingerprint: [6; 32],
            ticket_resource: None,
            kind: crate::rpc_adapter::SessionKind::Web,
            params: minidregg_spk_rpc::SessionParameters {
                identity_id: [7; 32],
                display_name: "member".into(),
                preferred_handle: "member".into(),
                permissions: vec![true],
                tab_id: vec![],
                base_path: "https://member.example.test".into(),
                user_agent: "Mini".into(),
                acceptable_languages: vec![],
            },
        }
    }
    fn channel(
        binding: SessionBinding,
        counter: std::sync::Arc<std::sync::atomic::AtomicUsize>,
    ) -> (Channel, tokio::sync::mpsc::Sender<Vec<u8>>) {
        let (tx, rx) = tokio::sync::mpsc::channel(16);
        (
            Channel {
                binding,
                endpoint: "websocket".into(),
                protocol: "ddp-v1".into(),
                expires: Instant::now() + Duration::from_secs(30),
                socket: WebSocketSession {
                    protocols: vec![],
                    to_app: capnp_rpc::new_client(FailingStream(counter)),
                    from_app: rx,
                },
                buffered: vec![],
                fragment: vec![],
                fragmenting: false,
                ids: HashSet::new(),
                max_frames: 64,
                max_bytes: 65536,
            },
            tx,
        )
    }
    fn request(value: Value) -> WebRequest {
        WebRequest {
            method: minidregg_spk_rpc::Method::HostedConversation,
            path_and_query: "websocket".into(),
            context: Default::default(),
            body: Some(minidregg_spk_rpc::Body {
                mime_type: "application/json".into(),
                encoding: String::new(),
                bytes: serde_json::to_vec(&value).unwrap(),
            }),
            dav: Default::default(),
        }
    }
    #[test]
    fn hosted_receiving_keeps_intervening_frames_and_refuses_changed_generation() {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap();
        tokio::task::LocalSet::new().block_on(&runtime,async {
            let counter=std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(0));
            let binding=binding();let (channel,tx)=channel(binding.clone(),counter.clone());
            let mut pool=Pool::default();pool.channels.insert("c".into(),Some(channel));
            let first=r#"{"msg":"updated","methods":["m"]}"#;
            let second=r#"{"msg":"result","id":"m","result":null}"#;
            let mut raw=vec![0x81,first.len() as u8];raw.extend(first.as_bytes());
            raw.extend([0x81,second.len() as u8]);raw.extend(second.as_bytes());
            tx.send(raw[..3].to_vec()).await.unwrap();tx.send(raw[3..].to_vec()).await.unwrap();
            let req=request(json!({"version":1,"op":"receive","channel":"c","condition":{"msg":"any"},"maxFrames":64,"maxBytes":65536,"deadlineMs":100}));
            let custody=Custody {directory:PathBuf::new(),api_prefix:None};
            let session=capnp_rpc::new_client(NoSession);
            for expected in [first,second] {
                let result=pool.execute(&session,&binding,&req,&custody,Instant::now()+Duration::from_secs(1)).await.unwrap();
                let WebResult::Content {body,..}=result.result else {panic!("content expected")};
                let body:Value=serde_json::from_slice(&body).unwrap();assert_eq!(body["frames"][0],expected);
            }
            let mut changed=binding.clone();changed.session_generation="5".into();
            assert!(pool.execute(&session,&changed,&req,&custody,Instant::now()+Duration::from_secs(1)).await.is_err());
            assert!(pool.channels["c"].is_none());assert_eq!(counter.load(std::sync::atomic::Ordering::SeqCst),0);
        });
    }
    #[test]
    fn hosted_uncertain_send_retains_exact_frame_and_never_replays() {
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap();
        tokio::task::LocalSet::new().block_on(&runtime, async {
            let counter = std::sync::Arc::new(std::sync::atomic::AtomicUsize::new(0));
            let binding = binding();
            let (channel, _tx) = channel(binding.clone(), counter.clone());
            let mut pool = Pool::default();
            pool.channels.insert("c".into(), Some(channel));
            let text = r#"{"msg":"method","method":"write","id":"m","params":[]}"#;
            let req = request(json!({"version":1,"op":"send","channel":"c","text":text}));
            let directory = std::env::temp_dir().join(format!(
                "cx-hosted-send-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            std::fs::DirBuilder::new()
                .mode(0o700)
                .create(&directory)
                .unwrap();
            crate::dispatch_native::private_dir(&directory).unwrap();
            let custody = Custody {
                directory: directory.clone(),
                api_prefix: None,
            };
            let session = capnp_rpc::new_client(NoSession);
            for _ in 0..2 {
                assert!(pool
                    .execute(
                        &session,
                        &binding,
                        &req,
                        &custody,
                        Instant::now() + Duration::from_secs(1)
                    )
                    .await
                    .is_err());
            }
            assert_eq!(counter.load(std::sync::atomic::Ordering::SeqCst), 1);
            assert!(pool.channels["c"].is_none());
            let frame = std::fs::read(directory.join("hosted-frame.bin")).unwrap();
            assert_eq!(frame[0], 0x81);
            let mask = &frame[2..6];
            let payload: Vec<_> = frame[6..]
                .iter()
                .enumerate()
                .map(|(i, b)| b ^ mask[i % 4])
                .collect();
            assert_eq!(payload, text.as_bytes());
            std::fs::remove_dir_all(directory).unwrap();
        });
    }
}
