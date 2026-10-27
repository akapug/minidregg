//! Operator integration probe: actual bridge subprocess/fd3 and SupervisorConnection.
//! This deliberately bypasses Mini admission and is not a user-facing command.
use minidregg_spk_rpc::{
    dispatch_web, Body, Method, RequestContext, SessionParameters, SupervisorConnection,
    WebRequest, WebResult,
};
use std::{
    os::{fd::AsRawFd, unix::process::CommandExt},
    process::{Child, Command},
    time::Duration,
};
struct ChildGuard(Child);
impl Drop for ChildGuard {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}
#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args.len() != 3 {
        return Err(
            "usage: query BRIDGE_BINARY PORT REQUEST_JSON_FILE (operator test only)".into(),
        );
    }
    let input = std::fs::read(&args[2])?;
    if input.len() > minidregg_oracle_appliance::MAX_REQUEST {
        return Err("request too large".into());
    }
    let (parent, child) = std::os::unix::net::UnixStream::pair()?;
    let fd = child.as_raw_fd();
    let mut cmd = Command::new(&args[0]);
    cmd.args(["--port", &args[1]]);
    unsafe {
        cmd.pre_exec(move || {
            if libc::dup2(fd, 3) < 0 {
                return Err(std::io::Error::last_os_error());
            }
            if libc::fcntl(3, libc::F_SETFD, 0) < 0 {
                return Err(std::io::Error::last_os_error());
            }
            Ok(())
        });
    }
    let _child = ChildGuard(cmd.spawn()?);
    drop(child);
    parent.set_nonblocking(true)?;
    let stream = tokio::net::UnixStream::from_std(parent)?;
    tokio::task::LocalSet::new()
        .run_until(async move {
            let (conn, rpc) = SupervisorConnection::from_connected_stream(stream);
            tokio::task::spawn_local(rpc);
            let info = conn.get_view_info().await?;
            eprintln!(
                "app={} permissions={:?}",
                info.app_title, info.permission_names
            );
            let session = conn
                .new_api_session(&SessionParameters {
                    identity_id: [1; 32],
                    display_name: "Operator integration probe".into(),
                    preferred_handle: "operator".into(),
                    permissions: vec![true],
                    tab_id: [b"mini-session-v1\0".as_slice(), &1_u64.to_be_bytes(), &2_u64.to_be_bytes(), &3_u64.to_be_bytes()].concat(),
                    base_path: "/".into(),
                    user_agent: "operator-probe".into(),
                    acceptable_languages: vec![],
                })
                .await?;
            let response = dispatch_web(
                &session,
                &WebRequest {
                    method: Method::Post,
                    path_and_query: "query".into(),
                    context: RequestContext::default(),
                    body: Some(Body {
                        mime_type: "application/json".into(),
                        encoding: String::new(),
                        bytes: input,
                    }),
                    dav: Default::default(),
                },
                minidregg_oracle_appliance::MAX_REPLY,
                Duration::from_secs(140),
            )
            .await?;
            let original = response
                .headers
                .iter()
                .find(|h| h.name == "x-sandstorm-app-http-status")
                .ok_or("missing original HTTP status")?;
            eprintln!("upstream_http_status={}", original.value);
            let bytes = match response.result {
                WebResult::Content {
                    status: 200, body, ..
                } => body,
                WebResult::ClientError {
                    non_html: Some((_, body)),
                    ..
                }
                | WebResult::ServerError {
                    non_html: Some((_, body)),
                    ..
                } => body,
                other => return Err(format!("unexpected response: {other:?}").into()),
            };
            use std::io::Write;
            std::io::stdout().write_all(&bytes)?;
            std::io::stdout().write_all(b"\n")?;
            if original.value != "200" {
                return Err(format!("adapter returned HTTP {}", original.value).into());
            }
            Ok::<_, Box<dyn std::error::Error>>(())
        })
        .await
}
