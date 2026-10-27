//! The grain's publishing socket: anonymous GET/HEAD of the app's `/var/www`.
//!
//! Sandstorm apps publish a static site by writing `/var/www`; the grain's
//! publishing origin (`https://<grain>-www.<base>`, `HackSessionContext.getPublicId`
//! in `spk-rpc`) serves it to anyone. The resident binds `apps/<app>/www.sock`
//! (0600, the operator's) beside the generations; the apps worker's edge connector
//! hands a connected stream to the front. The directory itself comes from the
//! app-identity launch worker (`resident_privilege`, tag 6), because the grain's
//! `/var` is the app's 0700 mount: the worker opens `www` as the app and passes the
//! descriptor back; every file under it is then opened as the operator, so only
//! what the app made world-readable is published.
//!
//! Each path component is opened with `O_NOFOLLOW` below that descriptor; `..`,
//! `.`, dotfile segments, NUL, backslash and percent-encoded separators are
//! refused before any open, so nothing outside the tree or behind a symlink is
//! reached. No session, no Mini transaction, no write.

use std::ffi::CString;
use std::fs::File;
use std::io::{self, Read, Write};
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::os::unix::fs::{FileTypeExt, MetadataExt, PermissionsExt};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

/// The largest file served (INSTALL.md §5a: 413 above it).
pub const MAX_FILE: u64 = 64 * 1024 * 1024;
const MAX_HEAD: usize = 8 * 1024;
const HEAD_DEADLINE: Duration = Duration::from_secs(10);
const WRITE_TIMEOUT: Duration = Duration::from_secs(120);
/// Concurrent publishing connections per grain; above it a request is 503.
pub const MAX_CONNECTIONS: usize = 16;

fn refuse(reason: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::PermissionDenied, reason)
}

/// `apps/<app>/www.sock` for a generation journal `apps/<app>/g<N>`.
pub fn socket_for_journal(journal: &Path) -> io::Result<PathBuf> {
    Ok(journal.parent().ok_or_else(|| refuse("generation journal has no app directory"))?.join("www.sock"))
}

/// The bound publishing socket. A stale socket from an ended generation (same
/// owner, nothing accepting) is replaced; a live one refuses the bind.
pub struct WwwListener {
    pub listener: UnixListener,
    socket: PathBuf,
    ino: u64,
    open: Arc<AtomicUsize>,
}

impl WwwListener {
    pub fn bind(socket: &Path) -> io::Result<Self> {
        let euid = unsafe { libc::geteuid() };
        match std::fs::symlink_metadata(socket) {
            Err(error) if error.kind() == io::ErrorKind::NotFound => {}
            Err(error) => return Err(error),
            Ok(old) => {
                if !old.file_type().is_socket() || old.uid() != euid || old.nlink() != 1 {
                    return Err(refuse("publishing socket identity drift"));
                }
                match UnixStream::connect(socket) {
                    Ok(_) => return Err(io::Error::new(io::ErrorKind::AlreadyExists, "publishing socket still accepting")),
                    Err(error) if error.kind() == io::ErrorKind::ConnectionRefused => std::fs::remove_file(socket)?,
                    Err(error) => return Err(error),
                }
            }
        }
        let listener = UnixListener::bind(socket)?;
        std::fs::set_permissions(socket, std::fs::Permissions::from_mode(0o600))?;
        let meta = std::fs::symlink_metadata(socket)?;
        if !meta.file_type().is_socket() || meta.uid() != euid {
            return Err(refuse("publishing socket identity drift"));
        }
        listener.set_nonblocking(true)?;
        Ok(Self { listener, socket: socket.to_owned(), ino: meta.ino(), open: Arc::default() })
    }

    /// Accept one connection and answer it on its own thread. `www` is asked
    /// for only when a request arrives (the app may publish at any time):
    /// `Ok(None)` means the app has no `/var/www`.
    pub fn accept_one(&self, www: impl FnOnce() -> io::Result<Option<OwnedFd>>) -> io::Result<()> {
        let stream = match self.listener.accept() {
            Ok((stream, _)) => stream,
            Err(error) if error.kind() == io::ErrorKind::WouldBlock => return Ok(()),
            Err(error) => return Err(error),
        };
        stream.set_nonblocking(false)?;
        if self.open.fetch_add(1, Ordering::SeqCst) >= MAX_CONNECTIONS {
            self.open.fetch_sub(1, Ordering::SeqCst);
            let mut stream = stream;
            let _ = stream.write_all(&response("503 Service Unavailable", "text/plain; charset=utf-8", b"publishing connections exhausted\n".len() as u64, false, &[("Retry-After", "5")]));
            let _ = stream.write_all(b"publishing connections exhausted\n");
            return Ok(());
        }
        let www = www();
        let open = self.open.clone();
        let spawned = std::thread::Builder::new().name("spk-www".into()).spawn(move || {
            let _ = serve(stream, www);
            open.fetch_sub(1, Ordering::SeqCst);
        });
        if spawned.is_err() {
            self.open.fetch_sub(1, Ordering::SeqCst);
        }
        Ok(())
    }
}

impl Drop for WwwListener {
    fn drop(&mut self) {
        if std::fs::symlink_metadata(&self.socket).is_ok_and(|m| m.ino() == self.ino) {
            let _ = std::fs::remove_file(&self.socket);
        }
    }
}

/// The request line's method and path, or the refusal status.
#[derive(Debug, PartialEq)]
pub enum Request {
    Get { head_only: bool, components: Vec<String> },
    Refused(&'static str, &'static str),
}

pub fn parse(head: &[u8]) -> Request {
    let Ok(text) = std::str::from_utf8(head) else { return Request::Refused("400 Bad Request", "request head is not UTF-8\n") };
    let line = text.split("\r\n").next().unwrap_or("");
    let mut parts = line.split(' ');
    let (Some(method), Some(target), Some(version), None) = (parts.next(), parts.next(), parts.next(), parts.next()) else {
        return Request::Refused("400 Bad Request", "malformed request line\n");
    };
    if !version.starts_with("HTTP/1.") {
        return Request::Refused("400 Bad Request", "HTTP/1.x only\n");
    }
    let head_only = match method {
        "GET" => false,
        "HEAD" => true,
        _ => return Request::Refused("405 Method Not Allowed", "the publishing origin answers GET and HEAD only\n"),
    };
    let path = target.split(['?', '#']).next().unwrap_or("");
    if !path.starts_with('/') {
        return Request::Refused("404 Not Found", "no such published file\n");
    }
    match components(path) {
        Some(components) => Request::Get { head_only, components },
        None => Request::Refused("404 Not Found", "no such published file\n"),
    }
}

/// The path's components after percent-decoding, or `None` for anything that
/// could leave the tree or name a hidden file. A trailing `/` (and `/`) names
/// the directory's `index.html`.
pub fn components(path: &str) -> Option<Vec<String>> {
    let decoded = percent_decode(path)?;
    let mut out = Vec::new();
    let segments: Vec<&str> = decoded.split('/').skip(1).collect();
    for (index, segment) in segments.iter().enumerate() {
        let last = index + 1 == segments.len();
        if segment.is_empty() {
            if last {
                break;
            }
            return None;
        }
        if segment.starts_with('.') || segment.contains(['\0', '\\']) || segment.len() > 255 {
            return None;
        }
        out.push((*segment).to_owned());
    }
    if out.len() > 32 {
        return None;
    }
    if decoded.ends_with('/') {
        out.push("index.html".into());
    }
    Some(out)
}

fn percent_decode(path: &str) -> Option<String> {
    let bytes = path.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' {
            let hex = std::str::from_utf8(bytes.get(i + 1..i + 3)?).ok()?;
            let value = u8::from_str_radix(hex, 16).ok()?;
            // An encoded separator or NUL is never a path character here.
            if matches!(value, b'/' | b'\\' | 0) {
                return None;
            }
            out.push(value);
            i += 3;
        } else {
            out.push(bytes[i]);
            i += 1;
        }
    }
    String::from_utf8(out).ok()
}

/// Open `components` below `root`, each with `O_NOFOLLOW`; a directory at the
/// end reads its `index.html`. Returns the file, or the refusal status.
pub fn open_beneath(root: &OwnedFd, components: &[String]) -> Result<(File, u64, String), (&'static str, &'static str)> {
    let not_found = ("404 Not Found", "no such published file\n");
    let mut current = dup(root).map_err(|_| not_found)?;
    let mut names: Vec<String> = components.to_vec();
    if names.is_empty() {
        names.push("index.html".into());
    }
    let mut index = 0;
    loop {
        let name = CString::new(names[index].as_bytes()).map_err(|_| not_found)?;
        let fd = unsafe { libc::openat(current.as_raw_fd(), name.as_ptr(), libc::O_RDONLY | libc::O_NOFOLLOW | libc::O_CLOEXEC | libc::O_NONBLOCK) };
        if fd < 0 {
            return Err(not_found);
        }
        let file = unsafe { File::from_raw_fd(fd) };
        let meta = file.metadata().map_err(|_| not_found)?;
        let last = index + 1 == names.len();
        if meta.is_dir() {
            current = OwnedFd::from(file);
            if last {
                if names.len() > 33 {
                    return Err(not_found);
                }
                names.push("index.html".into());
            }
            index += 1;
            continue;
        }
        if !last || !meta.is_file() {
            return Err(not_found);
        }
        if meta.len() > MAX_FILE {
            return Err(("413 Payload Too Large", "published file exceeds 64 MiB\n"));
        }
        let name = names[index].clone();
        return Ok((file, meta.len(), name));
    }
}

fn dup(fd: &OwnedFd) -> io::Result<OwnedFd> {
    let duplicated = unsafe { libc::fcntl(fd.as_raw_fd(), libc::F_DUPFD_CLOEXEC, 3) };
    if duplicated < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(unsafe { OwnedFd::from_raw_fd(duplicated) })
}

/// `Content-Type` by extension; unknown types are served as bytes.
pub fn content_type(name: &str) -> &'static str {
    let extension = name.rsplit_once('.').map(|(_, e)| e.to_ascii_lowercase()).unwrap_or_default();
    match extension.as_str() {
        "html" | "htm" => "text/html; charset=utf-8",
        "css" => "text/css; charset=utf-8",
        "js" | "mjs" => "text/javascript; charset=utf-8",
        "json" | "map" => "application/json",
        "txt" | "md" => "text/plain; charset=utf-8",
        "xml" => "application/xml",
        "svg" => "image/svg+xml",
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "ico" => "image/x-icon",
        "pdf" => "application/pdf",
        "woff" => "font/woff",
        "woff2" => "font/woff2",
        "ttf" => "font/ttf",
        "otf" => "font/otf",
        "wasm" => "application/wasm",
        "mp4" => "video/mp4",
        "webm" => "video/webm",
        "mp3" => "audio/mpeg",
        "ogg" => "audio/ogg",
        _ => "application/octet-stream",
    }
}

fn response(status: &str, content_type: &str, length: u64, svg: bool, extra: &[(&str, &str)]) -> Vec<u8> {
    let mut head = format!(
        "HTTP/1.1 {status}\r\nContent-Type: {content_type}\r\nContent-Length: {length}\r\nX-Content-Type-Options: nosniff\r\nCache-Control: no-cache\r\nReferrer-Policy: no-referrer\r\nConnection: close\r\n"
    );
    if svg {
        // An SVG opened directly may carry script; it is shown, never run.
        head.push_str("Content-Security-Policy: sandbox\r\n");
    }
    for (name, value) in extra {
        head.push_str(&format!("{name}: {value}\r\n"));
    }
    head.push_str("\r\n");
    head.into_bytes()
}

fn read_head(stream: &mut UnixStream) -> io::Result<Vec<u8>> {
    let deadline = Instant::now() + HEAD_DEADLINE;
    let mut buffer = Vec::with_capacity(1024);
    let mut chunk = [0_u8; 1024];
    loop {
        if let Some(end) = buffer.windows(4).position(|w| w == b"\r\n\r\n") {
            buffer.truncate(end);
            return Ok(buffer);
        }
        if buffer.len() > MAX_HEAD {
            return Err(refuse("request head exceeds 8 KiB"));
        }
        let remaining = deadline.checked_duration_since(Instant::now()).ok_or_else(|| refuse("request head deadline"))?;
        stream.set_read_timeout(Some(remaining))?;
        match stream.read(&mut chunk)? {
            0 => return Err(refuse("request head truncated")),
            n => buffer.extend_from_slice(&chunk[..n]),
        }
    }
}

/// Answer one request on `stream` from the published tree `www`.
pub fn serve(mut stream: UnixStream, www: io::Result<Option<OwnedFd>>) -> io::Result<()> {
    stream.set_write_timeout(Some(WRITE_TIMEOUT))?;
    let refused = |stream: &mut UnixStream, status: &str, body: &str, extra: &[(&str, &str)]| -> io::Result<()> {
        stream.write_all(&response(status, "text/plain; charset=utf-8", body.len() as u64, false, extra))?;
        stream.write_all(body.as_bytes())
    };
    let head = match read_head(&mut stream) {
        Ok(head) => head,
        Err(_) => return refused(&mut stream, "400 Bad Request", "request head not received\n", &[]),
    };
    let (head_only, components) = match parse(&head) {
        Request::Get { head_only, components } => (head_only, components),
        Request::Refused(status, body) => {
            let allow: &[(&str, &str)] = if status.starts_with("405") { &[("Allow", "GET, HEAD")] } else { &[] };
            return refused(&mut stream, status, body, allow);
        }
    };
    let root = match www {
        Ok(Some(root)) => root,
        Ok(None) => return refused(&mut stream, "404 Not Found", "no such published site\n", &[]),
        Err(_) => return refused(&mut stream, "503 Service Unavailable", "the grain's published tree is unavailable\n", &[("Retry-After", "30")]),
    };
    let (mut file, length, name) = match open_beneath(&root, &components) {
        Ok(found) => found,
        Err((status, body)) => return refused(&mut stream, status, body, &[]),
    };
    let kind = content_type(&name);
    stream.write_all(&response("200 OK", kind, length, kind == "image/svg+xml", &[]))?;
    if head_only {
        return Ok(());
    }
    let copied = io::copy(&mut (&mut file).take(length), &mut stream)?;
    if copied != length {
        return Err(refuse("published file changed length while served"));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::symlink;

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("spk-www-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn root(dir: &Path) -> OwnedFd {
        OwnedFd::from(File::open(dir).unwrap())
    }

    fn ask(www: &Path, request: &str) -> String {
        let (mut client, server) = UnixStream::pair().unwrap();
        let fd = root(www);
        let handle = std::thread::spawn(move || serve(server, Ok(Some(fd))));
        client.write_all(request.as_bytes()).unwrap();
        let mut out = String::new();
        client.read_to_string(&mut out).unwrap();
        let _ = handle.join();
        out
    }

    #[test]
    fn www_publish_parses_paths_and_refuses_escapes_by_name() {
        assert_eq!(components("/"), Some(vec!["index.html".to_owned()]));
        assert_eq!(components("/a/b.css"), Some(vec!["a".to_owned(), "b.css".to_owned()]));
        assert_eq!(components("/deck/"), Some(vec!["deck".to_owned(), "index.html".to_owned()]));
        assert_eq!(components("/a%20b.html"), Some(vec!["a b.html".to_owned()]));
        for bad in ["/../etc/passwd", "/a/../b", "/.git/config", "/a//b", "/%2e%2e/x", "/a%2fb", "/a%00", "/a\\b", "/%zz"] {
            assert_eq!(components(bad), None, "{bad}");
        }
        assert_eq!(parse(b"POST / HTTP/1.1"), Request::Refused("405 Method Not Allowed", "the publishing origin answers GET and HEAD only\n"));
        assert!(matches!(parse(b"GET /x?y=1 HTTP/1.1\r\nHost: a1-www"), Request::Get { head_only: false, .. }));
        assert!(matches!(parse(b"HEAD / HTTP/1.0"), Request::Get { head_only: true, .. }));
    }

    #[test]
    fn www_publish_serves_the_tree_and_never_follows_a_symlink() {
        let base = scratch("serve");
        let www = base.join("www");
        std::fs::create_dir_all(www.join("deck")).unwrap();
        std::fs::write(www.join("index.html"), "<h1>hi</h1>").unwrap();
        std::fs::write(www.join("deck/index.html"), "deck").unwrap();
        std::fs::write(www.join("pic.svg"), "<svg/>").unwrap();
        std::fs::write(base.join("secret"), "private").unwrap();
        symlink(base.join("secret"), www.join("link.txt")).unwrap();
        symlink(&base, www.join("up")).unwrap();

        let page = ask(&www, "GET / HTTP/1.1\r\nHost: a1-www.demo\r\n\r\n");
        assert!(page.starts_with("HTTP/1.1 200 OK\r\n") && page.contains("text/html") && page.ends_with("<h1>hi</h1>"), "{page}");
        assert!(!page.contains("Content-Security-Policy"));
        let deck = ask(&www, "GET /deck HTTP/1.1\r\n\r\n");
        assert!(deck.ends_with("deck"), "{deck}");
        let svg = ask(&www, "GET /pic.svg HTTP/1.1\r\n\r\n");
        assert!(svg.contains("Content-Security-Policy: sandbox"), "{svg}");
        let head = ask(&www, "HEAD /index.html HTTP/1.1\r\n\r\n");
        assert!(head.contains("Content-Length: 11") && head.ends_with("\r\n\r\n"), "{head}");
        for path in ["/link.txt", "/up/secret", "/missing", "/.hidden"] {
            let answer = ask(&www, &format!("GET {path} HTTP/1.1\r\n\r\n"));
            assert!(answer.starts_with("HTTP/1.1 404") && !answer.contains("private"), "{path}: {answer}");
        }
        let post = ask(&www, "POST / HTTP/1.1\r\n\r\n");
        assert!(post.starts_with("HTTP/1.1 405") && post.contains("Allow: GET, HEAD"), "{post}");
        let _ = std::fs::remove_dir_all(&base);
    }

    #[test]
    fn www_publish_without_a_tree_says_no_published_site() {
        let (mut client, server) = UnixStream::pair().unwrap();
        let handle = std::thread::spawn(move || serve(server, Ok(None)));
        client.write_all(b"GET / HTTP/1.1\r\n\r\n").unwrap();
        let mut out = String::new();
        client.read_to_string(&mut out).unwrap();
        handle.join().unwrap().unwrap();
        assert!(out.starts_with("HTTP/1.1 404") && out.ends_with("no such published site\n"), "{out}");
    }

    #[test]
    fn www_publish_listener_replaces_a_stale_socket_and_refuses_a_live_one() {
        let base = scratch("bind");
        let socket = base.join("www.sock");
        let first = WwwListener::bind(&socket).unwrap();
        assert!(WwwListener::bind(&socket).is_err());
        let stale = std::os::unix::net::UnixListener::bind(base.join("other.sock")).unwrap();
        drop(stale);
        drop(first);
        assert!(!socket.exists());
        std::fs::rename(base.join("other.sock"), &socket).unwrap();
        let second = WwwListener::bind(&socket).unwrap();
        assert_eq!(std::fs::metadata(&socket).unwrap().permissions().mode() & 0o777, 0o600);
        drop(second);
        let _ = std::fs::remove_dir_all(&base);
    }
}
