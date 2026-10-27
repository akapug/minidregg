//! The body: `mini web --body` running as the member (or as the public reader), reached through a
//! connected stream the helper hands over for each request. The gateway never addresses a socket
//! by path. The body answers the stage region (`X-Mini-Title` names the page), or a redirect.

use std::io::{Read, Write};
use std::os::unix::net::UnixStream;
use std::time::Duration;

use mini_web_spawn::{Client, Error, Request as Helper};

use crate::http::{parse_response, Request, Response};

/// The Host may take ten seconds on a write; the body's deadline is longer than the browser's
/// patience only so a slow answer is a decoded outcome, not a dropped one.
pub const BODY_TIMEOUT: Duration = Duration::from_secs(120);
pub const MAX_ANSWER: usize = 8 * 1024 * 1024;

/// A proxied answer: status, the stage HTML (or a redirect target), the title.
#[derive(Debug)]
pub struct Fragment {
    pub status: u16,
    pub title: String,
    pub html: String,
    pub location: Option<String>,
}

pub enum Target<'a> {
    Session(&'a str),
    Public,
}

pub fn fetch(client: &Client, target: Target, request: &Request) -> Result<Fragment, (u16, String)> {
    let ask = match target {
        Target::Session(sid) => Helper::Body { sid: Some(sid.to_owned()) },
        Target::Public => Helper::Body { sid: None },
    };
    let answer = match client.call(&ask) {
        Ok(answer) => answer,
        Err(Error::Refused(why)) => return Err((403, why)),
        Err(Error::Failed(why)) => return Err((502, format!("the body could not be started or reached: {why}"))),
        Err(Error::Transport(why)) => return Err((502, format!("the helper did not answer: {why}"))),
    };
    let fd = answer.fd.ok_or((502, "the helper passed no body stream".to_owned()))?;
    let mut stream = UnixStream::from(fd);
    stream.set_read_timeout(Some(BODY_TIMEOUT)).map_err(|e| (502, e.to_string()))?;
    stream.set_write_timeout(Some(Duration::from_secs(10))).map_err(|e| (502, e.to_string()))?;
    let mut head = format!("{} {} HTTP/1.1\r\nHost: mini-body\r\nX-Mini-Fragment: 1\r\n", request.method, target_of(request));
    if let Some(kind) = request.header("content-type") {
        head.push_str(&format!("Content-Type: {kind}\r\n"));
    }
    head.push_str(&format!("Content-Length: {}\r\n\r\n", request.body.len()));
    stream.write_all(head.as_bytes()).and_then(|_| stream.write_all(&request.body)).map_err(|e| (502, format!("writing to the body: {e}")))?;
    let mut bytes = Vec::new();
    let mut buffer = [0u8; 16384];
    loop {
        match stream.read(&mut buffer) {
            Ok(0) => break,
            Ok(n) => {
                bytes.extend_from_slice(&buffer[..n]);
                if bytes.len() > MAX_ANSWER {
                    return Err((502, "the body's answer exceeds the limit".into()));
                }
            }
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock || e.kind() == std::io::ErrorKind::TimedOut => {
                return Err((504, "the body did not answer in time".into()));
            }
            Err(e) => return Err((502, format!("reading the body's answer: {e}"))),
        }
    }
    let response: Response = parse_response(&bytes).map_err(|e| (502, e))?;
    Ok(Fragment {
        status: response.status,
        title: response.header("x-mini-title").unwrap_or("Mini").to_owned(),
        html: String::from_utf8_lossy(&response.body).into_owned(),
        location: response.header("location").map(str::to_owned),
    })
}

fn target_of(request: &Request) -> String {
    // Re-encode the decoded path so the body sees exactly one spelling.
    let mut path = String::new();
    for b in request.path.bytes() {
        if b.is_ascii_alphanumeric() || b"-_.~/".contains(&b) {
            path.push(b as char);
        } else {
            path.push_str(&format!("%{b:02X}"));
        }
    }
    if request.query.is_empty() { path } else { format!("{path}?{}", request.query) }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_target_is_reencoded() {
        let request = Request { path: "/doc/a b/é".into(), query: "x=1".into(), ..Default::default() };
        assert_eq!(target_of(&request), "/doc/a%20b/%C3%A9?x=1");
    }
}
