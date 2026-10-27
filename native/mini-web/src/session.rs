//! Who the browser is: a cookie naming a session the helper minted from a door login code. The
//! gateway holds nothing about a member but what the helper answers to `who`. Every POST and
//! every WebSocket upgrade must come from our own origin; every POST with a session carries its
//! CSRF token.

use mini_web_spawn::{is_token, Client, Error, Request as Helper};

use crate::http::Request;

/// Over https the `__Host-` prefix binds the cookie to this host and path `/`; a dev gateway on
/// plain http cannot carry `Secure`, so it uses the plain name.
pub const COOKIE_SECURE: &str = "__Host-mini_session";
pub const COOKIE_DEV: &str = "mini_session";

#[derive(Debug, Clone)]
pub struct Who {
    pub sid: String,
    pub name: String,
    pub csrf: String,
}

impl Who {
    pub fn prefix(&self) -> String {
        mini_web_spawn::sha256_hex(self.sid.as_bytes()).chars().take(12).collect()
    }
}

pub struct Sessions {
    pub client: Client,
    pub origin: String,
    pub secure: bool,
}

impl Sessions {
    pub fn cookie_name(&self) -> &'static str {
        if self.secure { COOKIE_SECURE } else { COOKIE_DEV }
    }

    /// The live session the request's cookie names, or none (no cookie, unknown, expired).
    pub fn who(&self, request: &Request) -> Option<Who> {
        let sid = request.cookie(self.cookie_name())?;
        if !is_token(&sid) {
            return None;
        }
        match self.client.call(&Helper::Who { sid: sid.clone() }) {
            Ok(answer) if answer.words.len() == 3 => Some(Who {
                sid,
                name: answer.words[0].clone(),
                csrf: answer.words[1].clone(),
            }),
            Ok(_) => None,
            Err(Error::Refused(_)) => None,
            Err(Error::Failed(why)) | Err(Error::Transport(why)) => {
                eprintln!("mini-web: helper: {why}");
                None
            }
        }
    }

    pub fn set_cookie(&self, sid: &str, max_age: u64) -> String {
        format!(
            "{}={sid}; Path=/; HttpOnly; SameSite=Strict; Max-Age={max_age}{}",
            self.cookie_name(),
            if self.secure { "; Secure" } else { "" }
        )
    }

    pub fn clear_cookie(&self) -> String {
        format!("{}=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0{}", self.cookie_name(), if self.secure { "; Secure" } else { "" })
    }

    /// A state-changing request must come from this origin: `Origin`, when present, equals ours;
    /// `Sec-Fetch-Site`, when present, is `same-origin` or `none`. A browser sends at least one of
    /// them on every POST and every WebSocket upgrade.
    pub fn same_origin(&self, request: &Request) -> Result<(), String> {
        let mut seen = false;
        for origin in request.headers_named("origin") {
            seen = true;
            if origin != self.origin {
                return Err(format!("Origin {origin} is not {}", self.origin));
            }
        }
        for site in request.headers_named("sec-fetch-site") {
            seen = true;
            if site != "same-origin" && site != "none" {
                return Err(format!("Sec-Fetch-Site {site} refused"));
            }
        }
        if !seen && request.method == "POST" {
            return Err("a POST without Origin or Sec-Fetch-Site is refused".into());
        }
        Ok(())
    }

    /// The form's `csrf` field equals the session's token (constant time).
    pub fn csrf_ok(request: &Request, who: &Who) -> bool {
        request.form_value("csrf").is_some_and(|token| equal(&token, &who.csrf))
    }
}

pub fn equal(left: &str, right: &str) -> bool {
    left.len() == right.len() && left.bytes().zip(right.bytes()).fold(0u8, |acc, (a, b)| acc | (a ^ b)) == 0
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sessions() -> Sessions {
        Sessions { client: Client::new(std::path::Path::new("/nonexistent")), origin: "https://demo.example".into(), secure: true }
    }

    fn request(method: &str, headers: &[(&str, &str)], body: &str) -> Request {
        Request {
            method: method.into(),
            headers: headers.iter().map(|(k, v)| (k.to_string(), v.to_string())).collect(),
            body: body.as_bytes().to_vec(),
            ..Default::default()
        }
    }

    #[test]
    fn same_origin_requires_our_origin_or_fetch_site() {
        let s = sessions();
        assert!(s.same_origin(&request("POST", &[("origin", "https://demo.example")], "")).is_ok());
        assert!(s.same_origin(&request("POST", &[("sec-fetch-site", "same-origin")], "")).is_ok());
        assert!(s.same_origin(&request("POST", &[("sec-fetch-site", "none")], "")).is_ok());
        assert!(s.same_origin(&request("POST", &[("origin", "https://evil.example")], "")).is_err());
        assert!(s.same_origin(&request("POST", &[("origin", "https://demo.example"), ("sec-fetch-site", "cross-site")], "")).is_err());
        assert!(s.same_origin(&request("POST", &[], "")).is_err());
        assert!(s.same_origin(&request("GET", &[], "")).is_ok());
        assert!(s.same_origin(&request("GET", &[("origin", "https://evil.example")], "")).is_err());
    }

    #[test]
    fn csrf_and_cookies() {
        let s = sessions();
        let who = Who { sid: "x".into(), name: "alice".into(), csrf: "tok".into() };
        let ok = request("POST", &[("content-type", "application/x-www-form-urlencoded")], "a=1&csrf=tok");
        assert!(Sessions::csrf_ok(&ok, &who));
        let bad = request("POST", &[("content-type", "application/x-www-form-urlencoded")], "csrf=nope");
        assert!(!Sessions::csrf_ok(&bad, &who));
        assert!(s.set_cookie("sid", 10).starts_with("__Host-mini_session=sid; Path=/; HttpOnly; SameSite=Strict; Max-Age=10; Secure"));
        assert!(s.clear_cookie().contains("Max-Age=0"));
        let dev = Sessions { secure: false, ..sessions() };
        assert!(dev.set_cookie("sid", 10).starts_with("mini_session=sid"));
        assert!(!dev.set_cookie("sid", 10).contains("Secure"));
        assert!(s.who(&request("GET", &[("cookie", "__Host-mini_session=short")], "")).is_none());
    }
}
