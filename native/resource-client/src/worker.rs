//! The NNTP POST half: one exact article to the co-located fn node over STARTTLS
//! with a pinned certificate and AUTHINFO, its reply classified, and the one
//! repost rule. Host/Main owns every Mini decision.
use super::*;
use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::client::WebPkiServerVerifier;
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use rustls::{
    ClientConfig, ClientConnection, DigitallySignedStruct, RootCertStore, SignatureScheme,
    StreamOwned,
};
use std::net::{SocketAddr, TcpStream};
use std::sync::Arc;
use std::time::{Duration, Instant};
use x509_parser::extensions::GeneralName;
use x509_parser::prelude::{FromDer, X509Certificate};

#[derive(Debug)]
struct ExactPinnedVerifier {
    expected_der: Vec<u8>,
    signatures: Arc<WebPkiServerVerifier>,
}

impl ServerCertVerifier for ExactPinnedVerifier {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        intermediates: &[CertificateDer<'_>],
        server_name: &ServerName<'_>,
        _ocsp: &[u8],
        _now: UnixTime,
    ) -> std::result::Result<ServerCertVerified, rustls::Error> {
        if end_entity.as_ref() != self.expected_der
            || !intermediates.is_empty()
            || !matches!(server_name, ServerName::DnsName(name) if name.as_ref() == "localhost")
        {
            return Err(rustls::Error::General(
                "fn TLS certificate pin or server name differs".into(),
            ));
        }
        let (remaining, cert) = X509Certificate::from_der(end_entity.as_ref())
            .map_err(|_| rustls::Error::General("invalid pinned fn TLS certificate DER".into()))?;
        if !remaining.is_empty() || !cert.validity().is_valid() {
            return Err(rustls::Error::General(
                "pinned fn TLS certificate is outside validity".into(),
            ));
        }
        let name_matches =
            match cert.subject_alternative_name().map_err(|_| {
                rustls::Error::General("invalid pinned fn TLS subject alternative name".into())
            })? {
                Some(names) => names.value.general_names.iter().any(
                    |name| matches!(name, GeneralName::DNSName(value) if *value == "localhost"),
                ),
                None => cert
                    .subject()
                    .iter_common_name()
                    .filter_map(|name| name.as_str().ok())
                    .any(|name| name == "localhost"),
            };
        if !name_matches {
            return Err(rustls::Error::General(
                "pinned fn TLS certificate is not for localhost".into(),
            ));
        }
        Ok(ServerCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> std::result::Result<HandshakeSignatureValid, rustls::Error> {
        self.signatures.verify_tls12_signature(message, cert, dss)
    }
    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> std::result::Result<HandshakeSignatureValid, rustls::Error> {
        self.signatures.verify_tls13_signature(message, cert, dss)
    }
    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        self.signatures.supported_verify_schemes()
    }
}

pub(super) struct FnPostConfig {
    pub(super) port: u16,
    pub(super) cert_pem: Vec<u8>,
    pub(super) username: String,
    pub(super) password_file: PathBuf,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub(super) enum FnPostOutcome {
    Accepted(String),
    AlreadyStored(String),
    Conflict(String),
    ExplicitUncertain(String),
    // An ordinary 441 refuses this invocation; after any earlier uncertainty
    // it does not prove that the article was never durably stored.
    Refused(String),
    TransportUncertain(String),
}

pub(super) fn post_config(path: &Path) -> Result<FnPostConfig> {
    let meta = fs::symlink_metadata(path)
        .map_err(|error| format!("cannot inspect fn post config: {error}"))?;
    if !mini_sdk::private::file_ok(&meta) {
        return Err("fn post config must be an owner-private regular file".into());
    }
    let bytes = fs::read(path).map_err(|error| format!("cannot read fn post config: {error}"))?;
    if bytes.len() > 16_384 {
        return Err("fn post config exceeds 16 KiB".into());
    }
    let value: Value = serde_json::from_slice(&bytes)
        .map_err(|error| format!("invalid fn post config: {error}"))?;
    if value.get("type").and_then(Value::as_str) != Some("minidregg-fn-post-v1") {
        return Err("unsupported fn post config type".into());
    }
    let port = value
        .get("port")
        .and_then(Value::as_u64)
        .ok_or("fn post config lacks port")?;
    let port = u16::try_from(port).map_err(|_| "fn post port exceeds u16")?;
    if port == 0 {
        return Err("fn post port must be nonzero".into());
    }
    let cert = PathBuf::from(property(&value, "certificatePath")?);
    let password_file = PathBuf::from(property(&value, "passwordFile")?);
    if !cert.is_absolute() || !password_file.is_absolute() {
        return Err("fn post custody paths must be absolute".into());
    }
    let cert_pem =
        fs::read(&cert).map_err(|error| format!("cannot read pinned certificate: {error}"))?;
    if cert_pem.is_empty() || cert_pem.len() > 65_536 {
        return Err("pinned certificate must be 1..65536 bytes".into());
    }
    let username = property(&value, "username")?.to_owned();
    if username.is_empty()
        || username.len() > 128
        || !username
            .bytes()
            .all(|byte| byte.is_ascii_graphic() && byte != b' ')
    {
        return Err("invalid fn post auth principal".into());
    }
    Ok(FnPostConfig {
        port,
        cert_pem,
        username,
        password_file,
    })
}

fn property<'a>(value: &'a Value, key: &str) -> Result<&'a str> {
    value
        .get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| format!("wake config lacks {key}"))
}

fn read_password(path: &Path) -> Result<Vec<u8>> {
    let meta =
        fs::symlink_metadata(path).map_err(|e| format!("cannot inspect NNTP password: {e}"))?;
    if !mini_sdk::private::file_ok(&meta) {
        return Err("NNTP password must be an owner-private regular file".into());
    }
    let mut bytes = fs::read(path).map_err(|e| format!("cannot read NNTP password: {e}"))?;
    while bytes.last().is_some_and(|c| *c == b'\r' || *c == b'\n') {
        bytes.pop();
    }
    if bytes.is_empty() || bytes.len() > 256 || !bytes.iter().all(|c| (33..=126).contains(c)) {
        return Err("invalid NNTP password length or bytes".into());
    }
    Ok(bytes)
}

fn line<R: Read>(
    reader: &mut R,
    mut set_timeout: impl FnMut(Duration) -> io::Result<()>,
    deadline: Instant,
) -> Result<Vec<u8>> {
    let mut out = Vec::new();
    while out.len() < 4096 {
        let remaining = deadline.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            return Err("NNTP response deadline exceeded".into());
        }
        set_timeout(remaining).map_err(|e| format!("cannot set NNTP read timeout: {e}"))?;
        let mut byte = [0];
        reader
            .read_exact(&mut byte)
            .map_err(|e| format!("cannot read NNTP response: {e}"))?;
        out.push(byte[0]);
        if out.ends_with(b"\r\n") {
            return Ok(out);
        }
    }
    Err("NNTP response line exceeds 4096 bytes".into())
}

struct FnAccess<'a> {
    port: u16,
    cert_pem: &'a [u8],
    username: &'a str,
    password_file: &'a Path,
}

fn protected_auth(
    access: FnAccess<'_>,
    deadline: Instant,
) -> Result<StreamOwned<ClientConnection, TcpStream>> {
    let addr = SocketAddr::from(([127, 0, 0, 1], access.port));
    let mut raw = TcpStream::connect_timeout(&addr, Duration::from_secs(10))
        .map_err(|e| format!("cannot connect to local fn NNTP listener: {e}"))?;
    raw.set_write_timeout(Some(Duration::from_secs(10)))
        .map_err(|e| e.to_string())?;
    let reader = raw.try_clone().map_err(|e| e.to_string())?;
    let mut greeting = reader;
    let status = line(
        &mut greeting,
        |duration| raw.set_read_timeout(Some(duration)),
        deadline,
    )?;
    if !status.starts_with(b"200 ") && !status.starts_with(b"201 ") {
        return Err("fn NNTP greeting refused".into());
    }
    raw.write_all(b"STARTTLS\r\n")
        .map_err(|e| format!("cannot request STARTTLS: {e}"))?;
    let status = line(
        &mut greeting,
        |duration| raw.set_read_timeout(Some(duration)),
        deadline,
    )?;
    if !status.starts_with(b"382 ") {
        return Err("fn NNTP refused STARTTLS".into());
    }
    let certs = rustls_pemfile::certs(&mut io::Cursor::new(access.cert_pem))
        .collect::<io::Result<Vec<_>>>()
        .map_err(|e| format!("invalid pinned certificate PEM: {e}"))?;
    if certs.is_empty() {
        return Err("pinned certificate PEM is empty".into());
    }
    if certs.len() != 1 {
        return Err("fn TLS pin must contain exactly one certificate".into());
    }
    let expected_der = certs[0].as_ref().to_vec();
    let mut roots = RootCertStore::empty();
    for cert in certs {
        roots
            .add(cert)
            .map_err(|e| format!("invalid pinned certificate: {e}"))?;
    }
    let provider = Arc::new(rustls::crypto::aws_lc_rs::default_provider());
    let signatures = WebPkiServerVerifier::builder_with_provider(Arc::new(roots), provider.clone())
        .build()
        .map_err(|e| format!("cannot create fn TLS signature verifier: {e}"))?;
    let tls_config = ClientConfig::builder_with_provider(provider)
        .with_protocol_versions(&[&rustls::version::TLS13])
        .map_err(|e| format!("cannot create fn TLS config: {e}"))?
        .dangerous()
        .with_custom_certificate_verifier(Arc::new(ExactPinnedVerifier {
            expected_der,
            signatures,
        }))
        .with_no_client_auth();
    let connection = ClientConnection::new(
        Arc::new(tls_config),
        ServerName::try_from("localhost").map_err(|e| e.to_string())?,
    )
    .map_err(|e| format!("cannot create fn TLS connection: {e}"))?;
    let mut tls = StreamOwned::new(connection, raw);
    tls.sock
        .set_read_timeout(Some(Duration::from_secs(10)))
        .map_err(|e| e.to_string())?;
    let password = read_password(access.password_file)?;
    tls.write_all(b"AUTHINFO USER ")
        .and_then(|_| tls.write_all(access.username.as_bytes()))
        .and_then(|_| tls.write_all(b"\r\n"))
        .and_then(|_| tls.flush())
        .map_err(|e| format!("cannot send NNTP auth principal: {e}"))?;
    let mut response = [0u8; 4096];
    let status = tls_line(&mut tls, &mut response, deadline)?;
    if !status.starts_with(b"381 ") {
        return Err("fn NNTP refused auth principal".into());
    }
    tls.write_all(b"AUTHINFO PASS ")
        .and_then(|_| tls.write_all(&password))
        .and_then(|_| tls.write_all(b"\r\n"))
        .and_then(|_| tls.flush())
        .map_err(|e| format!("cannot send NNTP password: {e}"))?;
    let status = tls_line(&mut tls, &mut response, deadline)?;
    if !status.starts_with(b"281 ") {
        return Err("fn NNTP refused authentication".into());
    }
    Ok(tls)
}

fn encoded_post_body(carrier: &[u8]) -> Result<Vec<u8>> {
    if carrier.is_empty() || carrier.len() > 1_516_384 || !carrier.ends_with(b"\r\n") {
        return Err("exact fn carrier must be nonempty, bounded, and CRLF-terminated".into());
    }
    let mut encoded = Vec::with_capacity(carrier.len() + 1024);
    let mut offset = 0;
    while offset < carrier.len() {
        let end = carrier[offset..]
            .windows(2)
            .position(|pair| pair == b"\r\n")
            .ok_or("exact fn carrier has an unterminated line")?
            + offset;
        let line = &carrier[offset..end];
        if line.iter().any(|byte| matches!(byte, b'\r' | b'\n' | 0)) {
            return Err("exact fn carrier contains a bare line break or NUL".into());
        }
        if line.starts_with(b".") {
            encoded.push(b'.');
        }
        encoded.extend_from_slice(line);
        encoded.extend_from_slice(b"\r\n");
        offset = end + 2;
    }
    encoded.extend_from_slice(b".\r\n");
    Ok(encoded)
}

fn post_status_line(bytes: &[u8]) -> Result<String> {
    let text = std::str::from_utf8(bytes).map_err(|_| "fn POST reply is not UTF-8")?;
    text.strip_suffix("\r\n")
        .map(str::to_owned)
        .ok_or_else(|| "fn POST reply lacks CRLF".into())
}

fn classify_post_reply(line: String) -> FnPostOutcome {
    match line.as_str() {
        "240 article received OK" => FnPostOutcome::Accepted(line),
        "441 posting failed; this article is already stored here" => {
            FnPostOutcome::AlreadyStored(line)
        }
        "441 posting failed; a different article with this Message-ID is stored here" => {
            FnPostOutcome::Conflict(line)
        }
        "441 posting failed; the outcome is uncertain, do not repost" => {
            FnPostOutcome::ExplicitUncertain(line)
        }
        _ if line.starts_with("441 ") => FnPostOutcome::Refused(line),
        _ => FnPostOutcome::TransportUncertain(format!("unrecognized fn POST final reply: {line}")),
    }
}

/// The custody status word and fn's exact line for one POST outcome, as a
/// publisher retains it.
pub(super) fn post_status(outcome: FnPostOutcome) -> (&'static str, String) {
    match outcome {
        FnPostOutcome::Accepted(line) => ("accepted", line),
        FnPostOutcome::AlreadyStored(line) => ("already-stored", line),
        FnPostOutcome::Conflict(line) => ("conflict", line),
        FnPostOutcome::ExplicitUncertain(line) => ("explicit-uncertain", line),
        FnPostOutcome::Refused(line) => ("refused", line),
        FnPostOutcome::TransportUncertain(line) => ("transport-uncertain", line),
    }
}

/// Whether a retained status word and line prove fn stored the exact article:
/// fn's own 240, or its Message-ID dedupe reporting the same article stored.
pub(super) fn post_stored(status: Option<&str>, detail: Option<&str>) -> bool {
    matches!(
        (status, detail),
        (Some("accepted"), Some("240 article received OK"))
            | (Some("already-stored"), Some("441 posting failed; this article is already stored here"))
    )
}

#[derive(Debug, Eq, PartialEq)]
pub(super) enum PostAction {
    First,
    Accepted,
    Hold,
}

/// The one NNTP repost rule. A durable attempt marker precedes every POST;
/// once it exists the article is never POSTed again by the client. Only a
/// retained result that proves the exact article stored finishes; any other
/// state (no result, uncertain, refused, conflict) holds for the operator,
/// with the exact article retained. A result without a marker is corrupt.
pub(super) fn post_action(attempt: bool, stored: Option<bool>) -> Result<PostAction> {
    match (attempt, stored) {
        (false, None) => Ok(PostAction::First),
        (true, Some(true)) => Ok(PostAction::Accepted),
        (true, None | Some(false)) => Ok(PostAction::Hold),
        (false, Some(_)) => Err("fn POST result lacks preceding attempt marker".into()),
    }
}

fn bounded_tls_write(
    tls: &mut StreamOwned<ClientConnection, TcpStream>,
    bytes: &[u8],
    deadline: Instant,
) -> io::Result<()> {
    let mut offset = 0;
    while offset < bytes.len() {
        let remaining = deadline.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            return Err(io::Error::new(
                io::ErrorKind::TimedOut,
                "fn POST write deadline exceeded",
            ));
        }
        tls.sock
            .set_write_timeout(Some(remaining.min(Duration::from_secs(10))))?;
        let end = (offset + 16_384).min(bytes.len());
        let written = tls.write(&bytes[offset..end])?;
        if written == 0 {
            return Err(io::Error::new(
                io::ErrorKind::WriteZero,
                "fn POST write made no progress",
            ));
        }
        offset += written;
        tls.flush()?;
    }
    Ok(())
}

pub(super) fn post_exact_carrier(config: &FnPostConfig, carrier: &[u8]) -> Result<FnPostOutcome> {
    let body = encoded_post_body(carrier)?;
    let deadline = Instant::now() + Duration::from_secs(120);
    let mut tls = match protected_auth(
        FnAccess {
            port: config.port,
            cert_pem: &config.cert_pem,
            username: &config.username,
            password_file: &config.password_file,
        },
        deadline,
    ) {
        Ok(tls) => tls,
        Err(error) => return Ok(FnPostOutcome::TransportUncertain(error)),
    };
    if let Err(error) = bounded_tls_write(&mut tls, b"POST\r\n", deadline) {
        return Ok(FnPostOutcome::TransportUncertain(format!(
            "cannot start fn POST: {error}"
        )));
    }
    let mut response = [0u8; 4096];
    let ready = match tls_line(&mut tls, &mut response, deadline) {
        Ok(bytes) => match post_status_line(bytes) {
            Ok(line) => line,
            Err(error) => return Ok(FnPostOutcome::TransportUncertain(error)),
        },
        Err(error) => return Ok(FnPostOutcome::TransportUncertain(error)),
    };
    if !ready.starts_with("340 ") {
        return Ok(if ready.starts_with("4") || ready.starts_with("5") {
            FnPostOutcome::Refused(ready)
        } else {
            FnPostOutcome::TransportUncertain(format!("unrecognized fn POST start reply: {ready}"))
        });
    }
    if let Err(error) = bounded_tls_write(&mut tls, &body, deadline) {
        return Ok(FnPostOutcome::TransportUncertain(format!(
            "fn POST body or terminator may be incomplete: {error}"
        )));
    }
    let final_line = match tls_line(&mut tls, &mut response, deadline) {
        Ok(bytes) => match post_status_line(bytes) {
            Ok(line) => line,
            Err(error) => return Ok(FnPostOutcome::TransportUncertain(error)),
        },
        Err(error) => return Ok(FnPostOutcome::TransportUncertain(error)),
    };
    Ok(classify_post_reply(final_line))
}

fn tls_line<'a>(
    tls: &mut StreamOwned<ClientConnection, TcpStream>,
    buffer: &'a mut [u8; 4096],
    deadline: Instant,
) -> Result<&'a [u8]> {
    for index in 0..buffer.len() {
        let remaining = deadline.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            return Err("fn NNTP deadline exceeded".into());
        }
        tls.sock
            .set_read_timeout(Some(remaining))
            .map_err(|e| e.to_string())?;
        tls.read_exact(&mut buffer[index..index + 1])
            .map_err(|e| format!("cannot read protected NNTP response: {e}"))?;
        if index > 0 && buffer[index - 1..=index] == *b"\r\n" {
            return Ok(&buffer[..=index]);
        }
    }
    Err("protected NNTP response exceeds 4096 bytes".into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fn_post_repost_rule_never_reposts_after_a_marker() {
        assert_eq!(post_action(false, None).unwrap(), PostAction::First);
        assert_eq!(post_action(true, None).unwrap(), PostAction::Hold);
        assert_eq!(post_action(true, Some(false)).unwrap(), PostAction::Hold);
        assert_eq!(post_action(true, Some(true)).unwrap(), PostAction::Accepted);
        assert!(post_action(false, Some(true)).is_err());
        // Every outcome a lost or unclear reply can produce holds; only fn's
        // 240 or its exact dedupe line finishes.
        for line in [
            "441 posting failed; the outcome is uncertain, do not repost",
            "441 posting failed; a different article with this Message-ID is stored here",
            "441 something else",
            "999 surprise",
        ] {
            let (status, detail) = post_status(classify_post_reply(line.to_owned()));
            assert!(!post_stored(Some(status), Some(&detail)), "{line}");
        }
        for line in [
            "240 article received OK",
            "441 posting failed; this article is already stored here",
        ] {
            let (status, detail) = post_status(classify_post_reply(line.to_owned()));
            assert!(post_stored(Some(status), Some(&detail)), "{line}");
        }
        let (status, detail) = post_status(FnPostOutcome::TransportUncertain("lost".into()));
        assert!(!post_stored(Some(status), Some(&detail)));
    }

    #[test]
    fn exact_carrier_post_dot_stuffs_without_changing_article_lines() {
        assert_eq!(
            encoded_post_body(b"Header: value\r\n\r\n.first\r\n..second\r\n").unwrap(),
            b"Header: value\r\n\r\n..first\r\n...second\r\n.\r\n"
        );
        assert!(encoded_post_body(b"Header: value\n").is_err());
        assert!(encoded_post_body(b"Header: value\r\nline\0\r\n").is_err());
    }

    #[test]
    fn post_reply_distinguishes_durable_duplicate_conflict_and_uncertainty() {
        assert!(matches!(
            classify_post_reply("240 article received OK".into()),
            FnPostOutcome::Accepted(_)
        ));
        assert!(matches!(
            classify_post_reply("441 posting failed; this article is already stored here".into()),
            FnPostOutcome::AlreadyStored(_)
        ));
        assert!(matches!(
            classify_post_reply(
                "441 posting failed; a different article with this Message-ID is stored here"
                    .into()
            ),
            FnPostOutcome::Conflict(_)
        ));
        assert!(matches!(
            classify_post_reply(
                "441 posting failed; the outcome is uncertain, do not repost".into()
            ),
            FnPostOutcome::ExplicitUncertain(_)
        ));
        assert!(matches!(
            classify_post_reply("500 unexpected".into()),
            FnPostOutcome::TransportUncertain(_)
        ));
    }

}
