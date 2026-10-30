//! A one-shot plain-HTTP client for the endpoint tests and `examples/fake-discord.rs`
//! (included by path from both; the shipped library carries no client).

use std::io::{Read, Write};
use std::net::TcpStream;
use std::time::Duration;

fn find_head_end(buf: &[u8]) -> Option<usize> {
    buf.windows(4).position(|w| w == b"\r\n\r\n")
}

#[allow(dead_code)]
/// One plain-HTTP request to a loopback address; returns (status, body).
/// Used by the fake Discord and the tests, never by the endpoint itself.
pub fn client_request(
    addr: &str,
    method: &str,
    path: &str,
    headers: &[(&str, &str)],
    body: &[u8],
) -> Result<(u16, Vec<u8>), String> {
    let mut stream = TcpStream::connect(addr).map_err(|e| format!("connect {addr}: {e}"))?;
    let _ = stream.set_read_timeout(Some(Duration::from_secs(30)));
    let mut head = format!("{method} {path} HTTP/1.1\r\nHost: {addr}\r\nConnection: close\r\n");
    for (k, v) in headers {
        head.push_str(&format!("{k}: {v}\r\n"));
    }
    head.push_str(&format!("Content-Length: {}\r\n\r\n", body.len()));
    stream.write_all(head.as_bytes()).map_err(|e| e.to_string())?;
    stream.write_all(body).map_err(|e| e.to_string())?;
    let mut out = Vec::new();
    stream.read_to_end(&mut out).map_err(|e| format!("read response: {e}"))?;
    let end = find_head_end(&out).ok_or("response has no head")?;
    let head = String::from_utf8_lossy(&out[..end]);
    let status = head
        .split(' ')
        .nth(1)
        .and_then(|s| s.parse().ok())
        .ok_or("response has no status")?;
    Ok((status, out[end + 4..].to_vec()))
}
