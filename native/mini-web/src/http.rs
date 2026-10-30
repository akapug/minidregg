//! Bounded HTTP/1.1, the same shape `mini web` and `mini-door` hand-roll: one request per
//! connection, a 16 KiB head, a 192 KiB body, `Connection: close` on every answer. The tree has no
//! HTTP framework and this adds none.

use std::io::{self, Read, Write};

pub const MAX_HEAD: usize = 16 * 1024;
pub const MAX_BODY: usize = 192 * 1024;

#[derive(Debug, Clone, Default)]
pub struct Request {
    pub method: String,
    pub path: String,
    pub query: String,
    pub headers: Vec<(String, String)>,
    pub body: Vec<u8>,
}

impl Request {
    pub fn header(&self, name: &str) -> Option<&str> {
        self.headers.iter().find(|(k, _)| k == name).map(|(_, v)| v.as_str())
    }

    pub fn headers_named<'a>(&'a self, name: &'a str) -> impl Iterator<Item = &'a str> + 'a {
        self.headers.iter().filter(move |(k, _)| k == name).map(|(_, v)| v.as_str())
    }

    pub fn cookie(&self, name: &str) -> Option<String> {
        for line in self.headers_named("cookie") {
            for part in line.split(';') {
                let part = part.trim();
                if let Some((k, v)) = part.split_once('=') {
                    if k == name {
                        return Some(v.to_owned());
                    }
                }
            }
        }
        None
    }

    /// `application/x-www-form-urlencoded` pairs, decoded.
    pub fn form(&self) -> Vec<(String, String)> {
        if !self.header("content-type").is_some_and(|t| t.starts_with("application/x-www-form-urlencoded")) {
            return Vec::new();
        }
        let text = String::from_utf8_lossy(&self.body);
        text.split('&')
            .filter(|p| !p.is_empty())
            .map(|p| {
                let (k, v) = p.split_once('=').unwrap_or((p, ""));
                (percent_decode(k), percent_decode(v))
            })
            .collect()
    }

    pub fn form_value(&self, key: &str) -> Option<String> {
        self.form().into_iter().find(|(k, _)| k == key).map(|(_, v)| v)
    }

    /// The page's JavaScript asks for the stage region only.
    pub fn fragment(&self) -> bool {
        self.header("x-mini-fragment") == Some("1")
    }

    /// The path's segments, each `[A-Za-z0-9_.-]+`; None when any segment is not.
    pub fn segments(&self) -> Option<Vec<&str>> {
        let parts: Vec<&str> = self.path.split('/').filter(|s| !s.is_empty()).collect();
        if parts.iter().all(|s| s.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_' || b == b'.') && *s != "." && *s != "..") {
            Some(parts)
        } else {
            None
        }
    }
}

/// Read a request head and body from `stream` (the caller has set its timeouts). The returned
/// bytes after the head that are not the body are discarded: one request per connection.
pub fn read_request(stream: &mut impl Read) -> Result<Request, (u16, String)> {
    let (head, mut rest) = read_head(stream).map_err(|e| (400, e))?;
    let mut request = parse_head(&head).map_err(|e| (400, e))?;
    if request.header("transfer-encoding").is_some() {
        return Err((411, "chunked requests are not accepted; send Content-Length".into()));
    }
    let length = match request.headers_named("content-length").collect::<Vec<_>>().as_slice() {
        [] => 0,
        [one] => one.parse::<usize>().map_err(|_| (400, "Content-Length is not a number".to_owned()))?,
        _ => return Err((400, "more than one Content-Length".into())),
    };
    if length > MAX_BODY {
        return Err((413, format!("the body exceeds {MAX_BODY} bytes")));
    }
    if request.method != "POST" && length > 0 {
        return Err((400, "only POST carries a body".into()));
    }
    while rest.len() < length {
        let mut buffer = vec![0u8; (length - rest.len()).min(8192)];
        let n = stream.read(&mut buffer).map_err(|e| (408, format!("reading the body: {e}")))?;
        if n == 0 {
            return Err((400, "the body ended early".into()));
        }
        rest.extend_from_slice(&buffer[..n]);
    }
    rest.truncate(length);
    request.body = rest;
    Ok(request)
}

fn read_head(stream: &mut impl Read) -> Result<(Vec<u8>, Vec<u8>), String> {
    let mut bytes = Vec::new();
    let mut buffer = [0u8; 4096];
    loop {
        if let Some(end) = find(&bytes, b"\r\n\r\n") {
            if end > MAX_HEAD {
                return Err(format!("the request head exceeds {MAX_HEAD} bytes"));
            }
            let rest = bytes.split_off(end + 4);
            return Ok((bytes, rest));
        }
        if bytes.len() > MAX_HEAD {
            return Err(format!("the request head exceeds {MAX_HEAD} bytes"));
        }
        let n = stream.read(&mut buffer).map_err(|e| format!("reading the request: {e}"))?;
        if n == 0 {
            return Err("the connection closed before the head ended".into());
        }
        bytes.extend_from_slice(&buffer[..n]);
    }
}

pub fn find(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    haystack.windows(needle.len()).position(|w| w == needle)
}

pub fn parse_head(bytes: &[u8]) -> Result<Request, String> {
    let text = std::str::from_utf8(bytes).map_err(|_| "request head is not UTF-8".to_owned())?;
    let mut lines = text.split("\r\n");
    let line = lines.next().ok_or("empty request")?;
    let mut parts = line.split(' ');
    let (Some(method), Some(target), Some(version), None) = (parts.next(), parts.next(), parts.next(), parts.next()) else {
        return Err("malformed request line".into());
    };
    if !version.starts_with("HTTP/1.") {
        return Err("unsupported HTTP version".into());
    }
    if !target.starts_with('/') {
        return Err("the target must be a path".into());
    }
    let mut headers = Vec::new();
    for line in lines {
        if line.is_empty() {
            break;
        }
        let (name, value) = line.split_once(':').ok_or("malformed header")?;
        if value.bytes().any(|b| b.is_ascii_control() && b != b'\t') {
            return Err("control character in a header".into());
        }
        headers.push((name.trim().to_ascii_lowercase(), value.trim().to_owned()));
    }
    let (path, query) = target.split_once('?').map(|(p, q)| (p, q)).unwrap_or((target, ""));
    Ok(Request {
        method: method.to_owned(),
        path: percent_decode_path(path),
        query: query.to_owned(),
        headers,
        body: Vec::new(),
    })
}

/// `%XX` only (a path keeps its `+`).
fn percent_decode_path(text: &str) -> String {
    decode(text, false)
}

pub fn percent_decode(text: &str) -> String {
    decode(text, true)
}

fn decode(text: &str, plus_is_space: bool) -> String {
    let bytes = text.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        match bytes[i] {
            b'%' if i + 2 < bytes.len() => {
                let hex = &text[i + 1..i + 3];
                match u8::from_str_radix(hex, 16) {
                    Ok(b) => {
                        out.push(b);
                        i += 3;
                    }
                    Err(_) => {
                        out.push(b'%');
                        i += 1;
                    }
                }
            }
            b'+' if plus_is_space => {
                out.push(b' ');
                i += 1;
            }
            b => {
                out.push(b);
                i += 1;
            }
        }
    }
    String::from_utf8_lossy(&out).into_owned()
}

/// The gateway's escaper, the same function as the body's (`resource-client`
/// `render::html::escape`; the two crates share no library, so `escapes_like_the_body` pins the
/// same vectors): the five metacharacters, and controls, bidirectional overrides/isolates and
/// invisible separators made visible.
pub fn html_escape(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    for c in text.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&#39;"),
            '\n' | '\r' | '\t' => out.push(c),
            '\u{7f}' => out.push('\u{2421}'),
            c if (c as u32) < 0x20 => out.push(char::from_u32(0x2400 + c as u32).unwrap_or('\u{fffd}')),
            '\u{80}'..='\u{9f}' | '\u{202a}'..='\u{202e}' | '\u{2066}'..='\u{2069}' | '\u{200b}' | '\u{2060}' | '\u{feff}' => {
                out.push_str(&format!("[U+{:04X}]", c as u32))
            }
            c => out.push(c),
        }
    }
    out
}

/// A same-origin path a form, a link or a redirect may name (`/…`, never `//…` or `/\…`).
pub fn same_origin_path(target: &str) -> bool {
    target.starts_with('/') && !target.starts_with("//") && !target.starts_with("/\\") && !target.chars().any(|c| c.is_control() || c == '\\')
}

#[derive(Debug, Clone)]
pub struct Response {
    pub status: u16,
    pub headers: Vec<(String, String)>,
    pub body: Vec<u8>,
}

impl Response {
    pub fn new(status: u16) -> Self {
        Response { status, headers: Vec::new(), body: Vec::new() }
    }

    pub fn html(status: u16, body: String) -> Self {
        Response::new(status).with("Content-Type", "text/html; charset=utf-8").body(body.into_bytes())
    }

    pub fn text(status: u16, text: &str) -> Self {
        Response::new(status).with("Content-Type", "text/plain; charset=utf-8").body(text.as_bytes().to_vec())
    }

    pub fn redirect(location: &str) -> Self {
        Response::new(303).with("Location", location)
    }

    pub fn with(mut self, name: &str, value: &str) -> Self {
        self.headers.push((name.to_owned(), value.to_owned()));
        self
    }

    pub fn body(mut self, body: Vec<u8>) -> Self {
        self.body = body;
        self
    }

    pub fn header(&self, name: &str) -> Option<&str> {
        self.headers.iter().find(|(k, _)| k.eq_ignore_ascii_case(name)).map(|(_, v)| v.as_str())
    }

    pub fn write(&self, stream: &mut impl Write, head_only: bool) -> io::Result<()> {
        let mut out = format!("HTTP/1.1 {} {}\r\n", self.status, status_text(self.status));
        for (k, v) in &self.headers {
            out.push_str(&format!("{k}: {v}\r\n"));
        }
        out.push_str(&format!("Content-Length: {}\r\nConnection: close\r\n\r\n", self.body.len()));
        stream.write_all(out.as_bytes())?;
        if !head_only {
            stream.write_all(&self.body)?;
        }
        stream.flush()
    }
}

/// Parse a complete HTTP/1.1 response (the body's answer to a proxied request).
pub fn parse_response(bytes: &[u8]) -> Result<Response, String> {
    let end = find(bytes, b"\r\n\r\n").ok_or("response head never ended")?;
    let head = std::str::from_utf8(&bytes[..end]).map_err(|_| "response head is not UTF-8")?;
    let mut lines = head.split("\r\n");
    let status_line = lines.next().ok_or("empty response")?;
    let status: u16 = status_line.split(' ').nth(1).and_then(|s| s.parse().ok()).ok_or("malformed status line")?;
    let mut headers = Vec::new();
    for line in lines {
        let (name, value) = line.split_once(':').ok_or("malformed response header")?;
        headers.push((name.trim().to_ascii_lowercase(), value.trim().to_owned()));
    }
    Ok(Response { status, headers, body: bytes[end + 4..].to_vec() })
}

pub fn status_text(status: u16) -> &'static str {
    match status {
        101 => "Switching Protocols",
        200 => "OK",
        204 => "No Content",
        303 => "See Other",
        304 => "Not Modified",
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        405 => "Method Not Allowed",
        408 => "Request Timeout",
        409 => "Conflict",
        411 => "Length Required",
        413 => "Payload Too Large",
        421 => "Misdirected Request",
        426 => "Upgrade Required",
        429 => "Too Many Requests",
        500 => "Internal Server Error",
        502 => "Bad Gateway",
        503 => "Service Unavailable",
        504 => "Gateway Timeout",
        _ => "Status",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn requests_parse_with_bounds() {
        let bytes = b"POST /doc/a%20b/append?x=1 HTTP/1.1\r\nHost: h\r\nCookie: a=1; mini=xyz\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: 12\r\n\r\ntext=hi+%26x".to_vec();
        let request = read_request(&mut &bytes[..]).unwrap();
        assert_eq!(request.path, "/doc/a b/append");
        assert_eq!(request.query, "x=1");
        assert_eq!(request.cookie("mini").as_deref(), Some("xyz"));
        assert_eq!(request.form_value("text").as_deref(), Some("hi &x"));
        assert!(request.segments().is_none(), "a space is not a segment byte");
        let big = format!("GET / HTTP/1.1\r\nX: {}\r\n\r\n", "a".repeat(MAX_HEAD));
        assert_eq!(read_request(&mut big.as_bytes()).unwrap_err().0, 400);
        let long = format!("POST / HTTP/1.1\r\nContent-Length: {}\r\n\r\n", MAX_BODY + 1);
        assert_eq!(read_request(&mut long.as_bytes()).unwrap_err().0, 413);
        let chunked = b"POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n";
        assert_eq!(read_request(&mut &chunked[..]).unwrap_err().0, 411);
        let two = b"POST / HTTP/1.1\r\nContent-Length: 1\r\nContent-Length: 1\r\n\r\nx";
        assert_eq!(read_request(&mut &two[..]).unwrap_err().0, 400);
        let get_body = b"GET / HTTP/1.1\r\nContent-Length: 1\r\n\r\nx";
        assert_eq!(read_request(&mut &get_body[..]).unwrap_err().0, 400);
    }

    #[test]
    fn responses_write_and_parse() {
        let mut out = Vec::new();
        Response::html(200, "<p>hi</p>".into()).with("X-Mini-Title", "Hi").write(&mut out, false).unwrap();
        let text = String::from_utf8(out.clone()).unwrap();
        assert!(text.starts_with("HTTP/1.1 200 OK\r\n"));
        assert!(text.contains("Connection: close\r\n"));
        let parsed = parse_response(&out).unwrap();
        assert_eq!(parsed.status, 200);
        assert_eq!(parsed.header("x-mini-title"), Some("Hi"));
        assert_eq!(parsed.body, b"<p>hi</p>");
        assert_eq!(html_escape("<a href=\"x\">&'</a>"), "&lt;a href=&quot;x&quot;&gt;&amp;&#39;&lt;/a&gt;");
        assert_eq!(percent_decode("a%2Fb+c%zz"), "a/b c%zz");
    }

    #[test]
    fn escapes_like_the_body() {
        for (input, want) in [
            ("<script>alert(1)</script>", "&lt;script&gt;alert(1)&lt;/script&gt;"),
            ("\"><img src=x onerror=alert(1)>", "&quot;&gt;&lt;img src=x onerror=alert(1)&gt;"),
            ("evil\u{202e}gnp.exe", "evil[U+202E]gnp.exe"),
            ("ali\u{200b}ce", "ali[U+200B]ce"),
            ("\u{1b}]52;c;x\u{7}", "\u{241b}]52;c;x\u{2407}"),
            ("a\nb\tc", "a\nb\tc"),
            ("\u{200d}\u{200f}", "\u{200d}\u{200f}"),
        ] {
            assert_eq!(html_escape(input), want, "{input:?}");
        }
        for (path, ok) in [("/doc/a", true), ("/", true), ("//evil.example", false), ("/\\evil", false), ("javascript:x", false), ("https://evil.example", false), ("/a\r\nSet-Cookie: x", false)] {
            assert_eq!(same_origin_path(path), ok, "{path:?}");
        }
    }
}
