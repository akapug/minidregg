use minidregg_oracle_appliance::{connection, Config, MAX_REPLY, MAX_REQUEST};
use minidregg_spk_rpc::{
    dispatch_web, Body, Method, RequestContext, SessionParameters, SupervisorConnection,
    WebRequest, WebResponse, WebResult,
};
use std::time::Duration;
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::{TcpListener, UnixStream},
};

fn params(permissions: Vec<bool>) -> SessionParameters {
    SessionParameters {
        identity_id: [1; 32],
        display_name: "Fixture".into(),
        preferred_handle: "fixture".into(),
        permissions,
        tab_id: vec![],
        base_path: "/".into(),
        user_agent: "fixture".into(),
        acceptable_languages: vec![],
    }
}
fn request(method: Method, path: &str, bytes: &[u8]) -> WebRequest {
    WebRequest {
        method,
        path_and_query: path.into(),
        context: RequestContext::default(),
        body: (method == Method::Post).then(|| Body {
            mime_type: "application/json".into(),
            encoding: "".into(),
            bytes: bytes.into(),
        }),
    }
}
fn status(reply: &WebResponse) -> u16 {
    reply
        .headers
        .iter()
        .find(|h| h.name == "x-sandstorm-app-http-status")
        .unwrap()
        .value
        .parse()
        .unwrap()
}
fn body(reply: &WebResponse) -> &[u8] {
    match &reply.result {
        WebResult::Content { body, .. } => body,
        WebResult::ClientError {
            non_html: Some((mime, body)),
            ..
        }
        | WebResult::ServerError {
            non_html: Some((mime, body)),
            ..
        } => {
            assert_eq!(mime, "application/json");
            body
        }
        _ => panic!("unexpected response: {reply:?}"),
    }
}
fn connect(port: u16, deadline: Duration) -> SupervisorConnection {
    let (app, supervisor) = UnixStream::pair().unwrap();
    tokio::task::spawn_local(connection(app, Config::new(port, deadline).unwrap()));
    let (connection, rpc) = SupervisorConnection::from_connected_stream(supervisor);
    tokio::task::spawn_local(rpc);
    connection
}
async fn fixture(reply: Vec<u8>) -> (u16, tokio::task::JoinHandle<Vec<u8>>) {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = listener.local_addr().unwrap().port();
    let task = tokio::spawn(async move {
        let (mut socket, _) = listener.accept().await.unwrap();
        let mut request = vec![];
        let mut byte = [0; 1];
        while !request.ends_with(b"\r\n\r\n") {
            socket.read_exact(&mut byte).await.unwrap();
            request.push(byte[0]);
        }
        let head = String::from_utf8_lossy(&request);
        let len: usize = head
            .lines()
            .find_map(|l| l.strip_prefix("Content-Length: "))
            .unwrap()
            .parse()
            .unwrap();
        let old = request.len();
        request.resize(old + len, 0);
        socket.read_exact(&mut request[old..]).await.unwrap();
        socket.write_all(&reply).await.unwrap();
        socket.shutdown().await.unwrap();
        request
    });
    (port, task)
}
fn response(status: u16, body: &[u8]) -> Vec<u8> {
    let mut data = format!(
        "HTTP/1.0 {status} Fixture\r\nContent-Type: application/json\r\nContent-Length: {}\r\n\r\n",
        body.len()
    )
    .into_bytes();
    data.extend_from_slice(body);
    data
}
#[tokio::test(flavor = "current_thread")]
async fn supervisor_preserves_full_evidence_and_error_status() {
    tokio::task::LocalSet::new()
        .run_until(async {
            let input = br#"{"request_id":"a","conversation_id":"b","text":"test"}"#;
            let evidence =
                br#"{"outcome":"answered","evidence":{"proof":{"all":[1,2,3]}},"answer":"abc"}"#;
            for code in [200, 400, 403, 404, 409, 413, 415, 429, 502, 503, 504, 507] {
                let (port, http) = fixture(response(code, evidence)).await;
                let conn = connect(port, Duration::from_secs(2));
                let info = conn.get_view_info().await.unwrap();
                assert_eq!(info.permission_names, vec!["query"]);
                assert_eq!(info.app_title, "Oracle7");
                let session = conn.new_api_session(&params(vec![true])).await.unwrap();
                let reply = dispatch_web(
                    &session,
                    &request(Method::Post, "query", input),
                    MAX_REPLY,
                    Duration::from_secs(3),
                )
                .await
                .unwrap();
                assert_eq!(status(&reply), code);
                assert_eq!(body(&reply), evidence);
                match reply.result {
                    WebResult::Content { status, .. } => assert_eq!((code, status), (200, 200)),
                    WebResult::ClientError { status, .. } => {
                        assert_eq!(status, if code == 429 { 400 } else { code })
                    }
                    WebResult::ServerError { .. } => assert!(code >= 500),
                    _ => panic!("unexpected union"),
                }
                let sent = http.await.unwrap();
                assert!(sent.starts_with(b"POST /query HTTP/1.0\r\n"));
                assert!(sent.ends_with(input));
            }
        })
        .await;
}
#[tokio::test(flavor = "current_thread")]
async fn rejects_permissions_routes_context_and_oversize_before_http() {
    tokio::task::LocalSet::new()
        .run_until(async {
            let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
            let conn = connect(
                listener.local_addr().unwrap().port(),
                Duration::from_secs(1),
            );
            for bits in [vec![], vec![false], vec![true, true]] {
                assert!(conn.new_api_session(&params(bits)).await.is_err());
            }
            let session = conn.new_web_session(&params(vec![true])).await.unwrap();
            for (req, code) in [
                (request(Method::Get, "query", b""), 404),
                (
                    request(Method::Post, "query?target=http://evil", b"{}"),
                    404,
                ),
                (request(Method::Head, "health", b""), 405),
                (
                    request(Method::Post, "query", &vec![0; MAX_REQUEST + 1]),
                    413,
                ),
            ] {
                let reply = dispatch_web(&session, &req, MAX_REPLY, Duration::from_secs(1))
                    .await
                    .unwrap();
                assert_eq!(status(&reply), code);
            }
            let mut req = request(Method::Post, "query", b"{}");
            req.context.etag_precondition = minidregg_spk_rpc::ETagPrecondition::Exists;
            assert_eq!(
                status(
                    &dispatch_web(&session, &req, MAX_REPLY, Duration::from_secs(1))
                        .await
                        .unwrap()
                ),
                400
            );
            req.context = RequestContext::default();
            req.body.as_mut().unwrap().encoding = "gzip".into();
            assert_eq!(
                status(
                    &dispatch_web(&session, &req, MAX_REPLY, Duration::from_secs(1))
                        .await
                        .unwrap()
                ),
                415
            );
            assert!(
                tokio::time::timeout(Duration::from_millis(25), listener.accept())
                    .await
                    .is_err()
            );
        })
        .await;
}
#[tokio::test(flavor = "current_thread")]
async fn transport_failure_never_returns_partial_evidence_or_success() {
    tokio::task::LocalSet::new().run_until(async {
        for data in [b"HTTP/1.0 200 OK\r\nContent-Type: application/json\r\nContent-Length: 9\r\n\r\n{}".to_vec(),
            b"HTTP/1.0 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\nContent-Length: 2\r\n\r\n{}".to_vec(),
            format!("HTTP/1.0 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\n\r\n",MAX_REPLY+1).into_bytes(),
            response(302,b"{}"),response(201,b"{}") ] {
            let (port,http)=fixture(data).await;let conn=connect(port,Duration::from_secs(1));let session=conn.new_api_session(&params(vec![true])).await.unwrap();
            assert!(dispatch_web(&session,&request(Method::Get,"health",b""),MAX_REPLY,Duration::from_secs(2)).await.is_err());http.await.unwrap();
        }
    }).await;
}
#[tokio::test(flavor = "current_thread")]
async fn deadlines_and_global_connection_bound() {
    tokio::task::LocalSet::new()
        .run_until(async {
            let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
            let conn = connect(
                listener.local_addr().unwrap().port(),
                Duration::from_millis(300),
            );
            let session = conn.new_api_session(&params(vec![true])).await.unwrap();
            let mut pending = vec![];
            let mut sockets = vec![];
            for _ in 0..8 {
                let s = session.clone();
                pending.push(tokio::task::spawn_local(async move {
                    dispatch_web(
                        &s,
                        &request(Method::Post, "query", b"{}"),
                        MAX_REPLY,
                        Duration::from_secs(2),
                    )
                    .await
                }));
                sockets.push(
                    tokio::time::timeout(Duration::from_secs(1), listener.accept())
                        .await
                        .unwrap()
                        .unwrap()
                        .0,
                );
            }
            let reply = dispatch_web(
                &session,
                &request(Method::Post, "query", b"{}"),
                MAX_REPLY,
                Duration::from_secs(1),
            )
            .await
            .unwrap();
            assert_eq!(status(&reply), 429);
            assert!(String::from_utf8_lossy(body(&reply)).contains("bridge_busy"));
            for task in pending {
                assert!(task
                    .await
                    .unwrap()
                    .unwrap_err()
                    .to_string()
                    .contains("delivery may be uncertain"));
            }
            drop(sockets);
        })
        .await;
}
#[tokio::test(flavor = "current_thread")]
async fn executable_inherited_fd3_reaches_http() {
    use std::{
        os::{fd::AsRawFd, unix::process::CommandExt},
        process::{Child, Command},
    };
    struct ChildGuard(Child);
    impl Drop for ChildGuard {
        fn drop(&mut self) {
            let _ = self.0.kill();
            let _ = self.0.wait();
        }
    }
    tokio::task::LocalSet::new()
        .run_until(async {
            let evidence = br#"{"outcome":"answered","evidence":{"complete":true}}"#;
            let (port, http) = fixture(response(200, evidence)).await;
            let (parent, child) = std::os::unix::net::UnixStream::pair().unwrap();
            let fd = child.as_raw_fd();
            let mut command = Command::new(env!("CARGO_BIN_EXE_minidregg-oracle-appliance"));
            command.args(["--port", &port.to_string()]);
            unsafe {
                command.pre_exec(move || {
                    if libc::dup2(fd, 3) < 0 || libc::fcntl(3, libc::F_SETFD, 0) < 0 {
                        return Err(std::io::Error::last_os_error());
                    }
                    Ok(())
                });
            }
            let _child = ChildGuard(command.spawn().unwrap());
            drop(child);
            parent.set_nonblocking(true).unwrap();
            let (conn, rpc) =
                SupervisorConnection::from_connected_stream(UnixStream::from_std(parent).unwrap());
            tokio::task::spawn_local(rpc);
            let session = conn.new_api_session(&params(vec![true])).await.unwrap();
            let reply = dispatch_web(
                &session,
                &request(Method::Post, "query", b"{}"),
                MAX_REPLY,
                Duration::from_secs(2),
            )
            .await
            .unwrap();
            assert_eq!(status(&reply), 200);
            assert_eq!(body(&reply), evidence);
            http.await.unwrap();
        })
        .await;
}
#[tokio::test(flavor = "current_thread")]
async fn maximum_evidence_body_survives_supervisor() {
    tokio::task::LocalSet::new()
        .run_until(async {
            let mut evidence = vec![b' '; MAX_REPLY];
            evidence[..2].copy_from_slice(b"{}");
            let (port, http) = fixture(response(200, &evidence)).await;
            let conn = connect(port, Duration::from_secs(3));
            let session = conn.new_api_session(&params(vec![true])).await.unwrap();
            let reply = dispatch_web(
                &session,
                &request(Method::Get, "capabilities", b""),
                MAX_REPLY,
                Duration::from_secs(4),
            )
            .await
            .unwrap();
            assert_eq!(body(&reply), evidence);
            http.await.unwrap();
        })
        .await;
}
