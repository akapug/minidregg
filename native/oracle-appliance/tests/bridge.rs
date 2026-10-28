use minidregg_oracle_appliance::{connection, Config, MAX_REPLY, MAX_REQUEST};
// Exercise the final native HTTP consumer, not only the Cap'n Proto decoder.
#[path = "../../spk-host/src/http_response.rs"]
mod host_http_response;
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
        tab_id: [b"mini-session-v1\0".as_slice(), &1_u64.to_be_bytes(), &2_u64.to_be_bytes(), &3_u64.to_be_bytes()].concat(),
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
        dav: Default::default(),
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
                assert_eq!(info.permissions[0].description.default_text, "Use a session-isolated workspace on a bounded shared Oracle runtime");
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
                let http_bytes = host_http_response::serialize(&reply, false).unwrap();
                let transport_status = if code >= 500 { 500 } else if code == 429 { 400 } else { code };
                assert!(http_bytes.starts_with(format!("HTTP/1.1 {transport_status} ").as_bytes()));
                assert!(String::from_utf8_lossy(&http_bytes).contains(&format!("x-sandstorm-app-http-status: {code}\r\n")));
                assert!(http_bytes.ends_with(evidence));
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
async fn json_accept_negotiation_preserves_specific_exclusions() {
    tokio::task::LocalSet::new().run_until(async {
        for accept in [vec![], vec![("*/*", 1000)], vec![("application/*", 500)],
            vec![("APPLICATION/JSON", 1000)], vec![("*/*", 0), ("application/json", 100)]] {
            let evidence = br#"{"ready":true,"busy":false}"#;
            let (port, http) = fixture(response(200, evidence)).await;
            let conn = connect(port, Duration::from_secs(1));
            let session = conn.new_api_session(&params(vec![true])).await.unwrap();
            let mut req = request(Method::Get, "health", b"");
            req.context.accept = accept.into_iter().map(|(s,q)| (s.into(), q)).collect();
            let reply = dispatch_web(&session, &req, MAX_REPLY, Duration::from_secs(2)).await.unwrap();
            assert_eq!(status(&reply), 200);
            assert_eq!(body(&reply), evidence);
            assert!(http.await.unwrap().starts_with(b"GET /health HTTP/1.0\r\n"));
        }
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let conn = connect(listener.local_addr().unwrap().port(), Duration::from_secs(1));
        let session = conn.new_api_session(&params(vec![true])).await.unwrap();
        for method in [Method::Get, Method::Post] {
            for accept in [vec![("text/html", 1000)], vec![("*/*", 0)],
                vec![("*/*", 1000), ("application/json", 0)],
                vec![("application/json", 0), ("application/*", 1000)]] {
                let mut req = request(method, if method == Method::Get { "health" } else { "query" }, b"{}");
                req.context.accept = accept.into_iter().map(|(s,q)| (s.into(), q)).collect();
                let reply = dispatch_web(&session, &req, MAX_REPLY, Duration::from_secs(1)).await.unwrap();
                assert_eq!(status(&reply), 406);
                assert!(String::from_utf8_lossy(body(&reply)).contains("json_not_acceptable"));
            }
        }
        assert!(tokio::time::timeout(Duration::from_millis(25), listener.accept()).await.is_err());
    }).await;
}

#[tokio::test(flavor = "current_thread")]
async fn operation_routes_preserve_exact_targets_and_full_invoke_body() {
    tokio::task::LocalSet::new().run_until(async {
        let evidence = br#"{"outcome":"completed","result":{"type":"symbol","name":"x"}}"#;
        for path in ["operations", "operations?limit=50&offset=999999999&availability=live_direct&q=a%2Bb+c",
            "operations?q=%C3%A9", "operations/sibling.visual-v1"] {
            let (port, http) = fixture(response(200, evidence)).await;
            let conn = connect(port, Duration::from_secs(1));
            let session = conn.new_api_session(&params(vec![true])).await.unwrap();
            let mut req = request(Method::Get, path, b"");
            req.context.accept = vec![("*/*".into(), 1000)];
            let reply = dispatch_web(&session, &req, MAX_REPLY, Duration::from_secs(2)).await.unwrap();
            assert_eq!(status(&reply), 200);
            assert!(host_http_response::serialize(&reply, false).unwrap().ends_with(evidence));
            assert!(http.await.unwrap().starts_with(format!("GET /{path} HTTP/1.0\r\n").as_bytes()));
        }
        let mut input = br#"{"request_id":"r","conversation_id":"c","operation_id":"example","arguments":{}}"#.to_vec();
        input.resize(MAX_REQUEST, b' ');
        let (port, http) = fixture(response(200, evidence)).await;
        let conn = connect(port, Duration::from_secs(1));
        let session = conn.new_api_session(&params(vec![true])).await.unwrap();
        let reply = dispatch_web(&session, &request(Method::Post, "invoke", &input), MAX_REPLY, Duration::from_secs(2)).await.unwrap();
        assert!(host_http_response::serialize(&reply, false).unwrap().ends_with(evidence));
        let sent = http.await.unwrap();
        assert!(sent.starts_with(b"POST /invoke HTTP/1.0\r\n"));
        assert!(sent.ends_with(&input));
    }).await;
}

#[tokio::test(flavor = "current_thread")]
async fn operation_routes_refuse_invalid_targets_before_http() {
    tokio::task::LocalSet::new().run_until(async {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let conn = connect(listener.local_addr().unwrap().port(), Duration::from_secs(1));
        let session = conn.new_api_session(&params(vec![true])).await.unwrap();
        let mut invalid = vec!["operations/".to_owned(), "operations/a/b".into(), "operations/%61".into(),
            "operations/a?limit=1".into(), "operations?limit=0".into(), "operations?limit=51".into(),
            "operations?offset=-1".into(), "operations?offset=1000000000".into(),
            "operations?availability=other".into(), "operations?q=a&q=b".into(), "operations?host=evil".into(),
            "operations?q=%ZZ".into(), "operations?q=%FF".into(), "operations?q=%0d%0a".into(),
            "operations?q=a b".into(), "operations?limit=1&".into()];
        invalid.push(format!("operations/{}", "a".repeat(161)));
        invalid.push(format!("operations?q={}", "a".repeat(257)));
        for path in invalid {
            let reply = dispatch_web(&session, &request(Method::Get, &path, b""), MAX_REPLY, Duration::from_secs(1)).await.unwrap();
            assert_eq!(status(&reply), 400, "{path}");
            assert!(host_http_response::serialize(&reply, false).unwrap().starts_with(b"HTTP/1.1 400 "));
        }
        assert!(dispatch_web(&session, &request(Method::Get, "operations?q=a#fragment", b""), MAX_REPLY, Duration::from_secs(1)).await.is_err());
        let reply = dispatch_web(&session, &request(Method::Post, "invoke", &vec![b' '; MAX_REQUEST + 1]), MAX_REPLY, Duration::from_secs(1)).await.unwrap();
        assert_eq!(status(&reply), 413);
        let reply = dispatch_web(&session, &request(Method::Post, "invoke?target=evil", b"{}"), MAX_REPLY, Duration::from_secs(1)).await.unwrap();
        assert_eq!(status(&reply), 404);
        assert!(tokio::time::timeout(Duration::from_millis(25), listener.accept()).await.is_err());
    }).await;
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

#[tokio::test(flavor = "current_thread")]
async fn authenticated_session_scopes_tenant_header_across_bridge_restart() {
    tokio::task::LocalSet::new().run_until(async {
        let input=br#"{"request_id":"same","conversation_id":"same","text":"test","tenant":"forged"}"#;
        let mut observed=vec![];
        for case in 0..5 {
            let (port,http)=fixture(response(200,b"{}")).await;
            let conn=connect(port,Duration::from_secs(2));
            let mut p=params(vec![true]);
            if case==1 {p.tab_id[39]=4;} // Same principal, another source session.
            if case==2 {p.identity_id=[2;32];}
            if case==3 {p.display_name="Untrusted new label".into();p.preferred_handle="other".into();}
            let session=if case==4 {conn.new_web_session(&p).await.unwrap()} else {conn.new_api_session(&p).await.unwrap()};
            dispatch_web(&session,&request(Method::Post,"query",input),MAX_REPLY,Duration::from_secs(3)).await.unwrap();
            let bytes=http.await.unwrap();assert!(bytes.ends_with(input));
            let head=std::str::from_utf8(&bytes[..bytes.windows(4).position(|w| w==b"\r\n\r\n").unwrap()]).unwrap();
            let headers=head.lines().filter_map(|l|l.strip_prefix("X-Mini-Oracle-Tenant: ")).collect::<Vec<_>>();
            assert_eq!(headers.len(),1);assert_eq!(headers[0].len(),64);observed.push(headers[0].to_owned());
        }
        assert_ne!(observed[0],observed[1]);assert_ne!(observed[0],observed[2]);
        assert_eq!(observed[0],observed[3]);assert_eq!(observed[0],observed[4]);
        use sha2::{Digest,Sha256};
        let p=params(vec![true]);let mut h=Sha256::new();h.update(b"mini-oracle-tenant-v1\0");h.update(p.identity_id);h.update(p.tab_id);
        let expected:String=h.finalize().iter().map(|b|format!("{b:02x}")).collect();
        assert_eq!(observed[0],expected);
    }).await;
}

#[tokio::test(flavor = "current_thread")]
async fn missing_source_binding_and_header_spoof_refuse_before_backend() {
    tokio::task::LocalSet::new().run_until(async {
        let listener=TcpListener::bind("127.0.0.1:0").await.unwrap();
        let conn=connect(listener.local_addr().unwrap().port(),Duration::from_secs(2));
        for which in 0..3 {
            let mut p=params(vec![true]);
            if which==0 {p.identity_id=[0;32];} else if which==1 {p.tab_id.clear();} else {p.tab_id[0]=b'x';}
            assert!(conn.new_api_session(&p).await.is_err());
        }
        let session=conn.new_api_session(&params(vec![true])).await.unwrap();
        let mut req=request(Method::Post,"query",b"{}");
        req.context.additional_headers.push(minidregg_spk_rpc::Header {name:"x-mini-oracle-tenant".into(),value:"a".repeat(64)});
        assert!(dispatch_web(&session,&req,MAX_REPLY,Duration::from_secs(3)).await.is_err());
        req.context.additional_headers[0].name="x-csrftoken".into();
        let response=dispatch_web(&session,&req,MAX_REPLY,Duration::from_secs(3)).await.unwrap();
        assert_eq!(status(&response),400);
        assert!(tokio::time::timeout(Duration::from_millis(30),listener.accept()).await.is_err());
    }).await;
}

#[tokio::test(flavor = "current_thread")]
async fn browser_root_and_identity_encoding_do_not_require_backend() {
    tokio::task::LocalSet::new().run_until(async {
        let listener=TcpListener::bind("127.0.0.1:0").await.unwrap();
        let conn=connect(listener.local_addr().unwrap().port(),Duration::from_secs(2));
        let session=conn.new_web_session(&params(vec![true])).await.unwrap();
        let mut req=request(Method::Get,"",&[]);
        req.context.accept=vec![("text/html".into(),1000),("*/*".into(),800)];
        req.context.accept_encoding=vec![("gzip".into(),1000),("br".into(),1000)];
        let reply=dispatch_web(&session,&req,MAX_REPLY,Duration::from_secs(2)).await.unwrap();
        match reply.result {WebResult::Content {mime_type,body,..}=>{
            assert_eq!(mime_type,"text/html; charset=utf-8");
            assert!(String::from_utf8(body).unwrap().contains("Oracle"));
        },other=>panic!("unexpected root response: {other:?}")}
        req.context.accept_encoding=vec![("identity".into(),0),("*".into(),1000)];
        let reply=dispatch_web(&session,&req,MAX_REPLY,Duration::from_secs(2)).await.unwrap();
        assert_eq!(status(&reply),406);
        assert!(tokio::time::timeout(Duration::from_millis(30),listener.accept()).await.is_err());
    }).await;
}
