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

/// A body answer that is a file to save (`Content-Disposition: attachment`, the member's export):
/// the gateway streams it from the body to the browser and never holds it whole.
pub struct Download {
    pub content_type: String,
    pub disposition: String,
    pub length: Option<u64>,
    /// Bytes already read past the body's response head.
    pub first: Vec<u8>,
    pub stream: UnixStream,
}

pub enum Answer {
    Page(Fragment),
    Download(Download),
}

pub enum Target<'a> {
    Session(&'a str),
    Public,
}

pub fn fetch(client: &Client, target: Target, request: &Request) -> Result<Answer, (u16, String)> {
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
    // The `csrf` field is the gateway's (it put it into every form it served and has checked it);
    // the body sees the form the member filled and nothing of the gateway's.
    let body = if request.method == "POST" && request.header("content-type").is_some_and(|k| k.starts_with("application/x-www-form-urlencoded")) {
        without_field(&request.body, "csrf")
    } else {
        request.body.clone()
    };
    head.push_str(&format!("Content-Length: {}\r\n\r\n", body.len()));
    stream.write_all(head.as_bytes()).and_then(|_| stream.write_all(&body)).map_err(|e| (502, format!("writing to the body: {e}")))?;
    let mut bytes = Vec::new();
    let mut buffer = [0u8; 16384];
    let mut decided = false;
    loop {
        match stream.read(&mut buffer) {
            Ok(0) => break,
            Ok(n) => {
                bytes.extend_from_slice(&buffer[..n]);
                if !decided {
                    if let Some(end) = bytes.windows(4).position(|w| w == b"\r\n\r\n") {
                        decided = true;
                        if let Some((content_type, disposition, length)) = download_head(&bytes[..end + 4]) {
                            let first = bytes[end + 4..].to_vec();
                            return Ok(Answer::Download(Download { content_type, disposition, length, first, stream }));
                        }
                    }
                }
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
    Ok(Answer::Page(Fragment {
        status: response.status,
        title: response.header("x-mini-title").unwrap_or("Mini").to_owned(),
        html: String::from_utf8_lossy(&response.body).into_owned(),
        location: response.header("location").map(str::to_owned),
    }))
}

/// A 200 head naming an attachment, with a content type and a safe file name (no quote, no
/// path, no control byte), is a download: (content type, disposition, length); anything else is a page.
fn download_head(head: &[u8]) -> Option<(String, String, Option<u64>)> {
    let text = std::str::from_utf8(head).ok()?;
    let mut lines = text.split("\r\n");
    if !lines.next()?.starts_with("HTTP/1.1 200 ") {
        return None;
    }
    let (mut kind, mut disposition, mut length) = (None, None, None);
    for line in lines {
        let Some((k, v)) = line.split_once(':') else { continue };
        match k.trim().to_ascii_lowercase().as_str() {
            "content-type" => kind = Some(v.trim().to_owned()),
            "content-disposition" => disposition = Some(v.trim().to_owned()),
            "content-length" => length = v.trim().parse().ok(),
            _ => {}
        }
    }
    let disposition = disposition?;
    let name = disposition.strip_prefix("attachment; filename=\"")?.strip_suffix('"')?;
    if name.is_empty() || !name.bytes().all(|b| b.is_ascii_alphanumeric() || b"-_.".contains(&b)) {
        return None;
    }
    Some((kind?, disposition, length))
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
    fn only_a_200_attachment_with_a_plain_file_name_is_a_download() {
        let h = |s: &str| download_head(s.as_bytes());
        assert_eq!(h("HTTP/1.1 200 OK\r\nContent-Type: application/x-tar\r\nContent-Disposition: attachment; filename=\"mini-alice.tar\"\r\nContent-Length: 10\r\n\r\n"),
            Some(("application/x-tar".into(), "attachment; filename=\"mini-alice.tar\"".into(), Some(10))));
        assert_eq!(h("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n"), None);
        assert_eq!(h("HTTP/1.1 500 X\r\nContent-Type: application/x-tar\r\nContent-Disposition: attachment; filename=\"a.tar\"\r\n\r\n"), None);
        assert_eq!(h("HTTP/1.1 200 OK\r\nContent-Type: application/x-tar\r\nContent-Disposition: attachment; filename=\"../a.tar\"\r\n\r\n"), None);
    }

    #[test]
    fn the_target_is_reencoded() {
        let request = Request { path: "/doc/a b/é".into(), query: "x=1".into(), ..Default::default() };
        assert_eq!(target_of(&request), "/doc/a%20b/%C3%A9?x=1");
    }
}

/// A urlencoded form body without the pairs named `name` (the gateway's own field).
fn without_field(body: &[u8], name: &str) -> Vec<u8> {
    let prefix = format!("{name}=");
    body.split(|b| *b == b'&')
        .filter(|pair| !pair.starts_with(prefix.as_bytes()) && *pair != name.as_bytes())
        .collect::<Vec<_>>()
        .join(&b'&')
}

#[cfg(test)]
mod body_tests {
    #[test]
    fn the_csrf_field_is_the_gateways_and_never_reaches_the_body() {
        assert_eq!(super::without_field(b"csrf=abc&text=hello%26more&csrf=again", "csrf"), b"text=hello%26more".to_vec());
        assert_eq!(super::without_field(b"text=only", "csrf"), b"text=only".to_vec());
        assert_eq!(super::without_field(b"csrfs=notme&csrf", "csrf"), b"csrfs=notme".to_vec());
    }
}
