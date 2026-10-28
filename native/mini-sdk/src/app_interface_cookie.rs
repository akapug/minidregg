//! Per-invocation application cookies. Host session custody never enters this jar.
use crate::app_interface::{Refusal, Result};
use std::collections::BTreeMap;
use std::time::{Duration, Instant};
#[derive(Default)]
pub(crate) struct CookieJar {
    cookies: Vec<Cookie>,
}
struct Cookie {
    name: String,
    value: String,
    path: String,
    expires: Option<Instant>,
}
fn bad(name: &str) -> Refusal {
    Refusal {
        name: name.into(),
        uncertain: false,
    }
}
fn request_path(path: &str) -> String {
    format!("/{}", path.trim_start_matches('/'))
}
impl CookieJar {
    pub(crate) fn for_path(&mut self, path: &str) -> Result<BTreeMap<String, String>> {
        let now = Instant::now();
        self.cookies
            .retain(|c| c.expires.is_none_or(|end| end > now));
        let path = request_path(path);
        let mut pairs = BTreeMap::new();
        for c in self.cookies.iter().filter(|c| {
            path == c.path
                || (path.starts_with(&c.path)
                    && (c.path.ends_with('/') || path.as_bytes().get(c.path.len()) == Some(&b'/')))
        }) {
            if pairs.insert(c.name.clone(), c.value.clone()).is_some() {
                return Err(bad("app-cookie-duplicate"));
            }
        }
        Ok(pairs)
    }
    pub(crate) fn retain(&mut self, headers: &[(String, String)], request: &str) -> Result<()> {
        let request = request_path(request);
        let default_path = request
            .rsplit_once('/')
            .map(|(head, _)| if head.is_empty() { "/" } else { head })
            .unwrap_or("/");
        for (k, v) in headers {
            if !k.eq_ignore_ascii_case("set-cookie") {
                continue;
            }
            let mut parts = v.split(';');
            let (name, value) = parts
                .next()
                .unwrap_or("")
                .split_once('=')
                .ok_or_else(|| bad("app-cookie-invalid"))?;
            if name == "__Host-mini_spk_session" {
                return Err(bad("app-cookie-reserved"));
            }
            if name.is_empty()
                || name
                    .chars()
                    .any(|c| !c.is_ascii_alphanumeric() && !"_-.".contains(c))
                || value.chars().any(|c| c.is_control() || c == ';')
            {
                return Err(bad("app-cookie-invalid"));
            }
            let mut path = default_path.to_owned();
            let mut age = None;
            let mut expires_attribute = false;
            for attr in parts {
                let (key, value) = attr.trim().split_once('=').unwrap_or((attr.trim(), ""));
                if key.eq_ignore_ascii_case("domain") {
                    return Err(bad("app-cookie-domain-unsupported"));
                }
                if key.eq_ignore_ascii_case("path") {
                    if !value.starts_with('/') || value.chars().any(char::is_control) {
                        return Err(bad("app-cookie-path-invalid"));
                    }
                    path = value.into();
                }
                if key.eq_ignore_ascii_case("max-age") {
                    age = Some(
                        value
                            .parse::<i64>()
                            .map_err(|_| bad("app-cookie-max-age-invalid"))?,
                    );
                }
                if key.eq_ignore_ascii_case("expires") {
                    expires_attribute = true;
                }
            }
            if expires_attribute && age.is_none() {
                return Err(bad("app-cookie-expires-unsupported"));
            }
            self.cookies.retain(|c| c.name != name || c.path != path);
            if age.is_some_and(|n| n <= 0) {
                continue;
            }
            let expires = age
                .map(|n| {
                    Instant::now()
                        .checked_add(Duration::from_secs(n as u64))
                        .ok_or_else(|| bad("app-cookie-max-age-invalid"))
                })
                .transpose()?;
            self.cookies.push(Cookie {
                name: name.into(),
                value: value.into(),
                path,
                expires,
            });
            if self.cookies.len() > 64
                || self
                    .cookies
                    .iter()
                    .map(|c| c.name.len() + c.value.len() + c.path.len() + 3)
                    .sum::<usize>()
                    > 16384
            {
                return Err(bad("app-cookie-over-bound"));
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn path_age_and_host_custody_are_enforced() {
        let mut jar = CookieJar::default();
        jar.retain(&[("Set-Cookie".into(), "sid=one".into())], "auth/token")
            .unwrap();
        assert!(jar.for_path("other/write").unwrap().is_empty());
        assert_eq!(
            jar.for_path("auth/write")
                .unwrap()
                .get("sid")
                .map(String::as_str),
            Some("one")
        );
        jar.retain(
            &[("Set-Cookie".into(), "sid=gone; Max-Age=0".into())],
            "auth/token",
        )
        .unwrap();
        assert!(jar.for_path("auth/write").unwrap().is_empty());
        assert_eq!(
            jar.retain(
                &[(
                    "set-cookie".into(),
                    "__Host-mini_spk_session=forged; Path=/".into()
                )],
                "auth/token"
            )
            .unwrap_err()
            .name,
            "app-cookie-reserved"
        );
        assert_eq!(
            jar.retain(
                &[("set-cookie".into(), "sid=foreign; Domain=other.test".into())],
                "auth/token"
            )
            .unwrap_err()
            .name,
            "app-cookie-domain-unsupported"
        );
    }
}
