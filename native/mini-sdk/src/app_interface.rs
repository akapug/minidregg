//! One declaration supplies native typed calls, tool schemas and qualification.
//! This layer encodes application data. Admission and exact dispatch receipts remain
//! the existing Mini application receiver's responsibility. Never retry a mutation.
use base64::{engine::general_purpose::STANDARD, Engine};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Refusal {
    pub name: String,
    pub uncertain: bool,
}
type Result<T> = std::result::Result<T, Refusal>;
fn refuse(name: &str) -> Refusal {
    Refusal {
        name: name.into(),
        uncertain: false,
    }
}
impl std::fmt::Display for Refusal {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.name)
    }
}
impl std::error::Error for Refusal {}
#[derive(Clone, Debug)]
pub struct PreparedCall {
    pub method: String,
    pub path: String,
    pub query: String,
    pub ordered_headers: Vec<(String, String)>,
    pub body: Vec<u8>,
    pub declaration_sha256: String,
    pub package_id: String,
    pub operation: String,
    pub write: bool,
}
#[derive(Clone, Debug)]
pub struct Declaration {
    value: Value,
    pub sha256: String,
    pub package_id: String,
}
fn string(v: &Value) -> Result<&str> {
    v.as_str().ok_or_else(|| refuse("declaration-invalid"))
}
fn number(v: &Value) -> Result<u64> {
    v.as_u64().ok_or_else(|| refuse("declaration-invalid"))
}
fn scalar(v: &Value) -> Result<String> {
    match v {
        Value::String(s) => Ok(s.clone()),
        Value::Number(_) | Value::Bool(_) => Ok(v.to_string()),
        _ => Err(refuse("binding-value-invalid")),
    }
}
fn canonical(v: &Value) -> Value {
    match v {
        Value::Object(o) => {
            let mut keys: Vec<_> = o.keys().collect();
            keys.sort();
            let mut out = serde_json::Map::new();
            for k in keys {
                out.insert(k.clone(), canonical(&o[k]));
            }
            Value::Object(out)
        }
        Value::Array(a) => Value::Array(a.iter().map(canonical).collect()),
        _ => v.clone(),
    }
}
fn percent(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || b"-._~".contains(&b) {
            out.push(b as char)
        } else {
            out.push_str(&format!("%{b:02X}"))
        }
    }
    out
}
fn relative(s: &str) -> Result<String> {
    if s.is_empty()
        || s.chars().any(|c| c.is_control() || "\\%?#".contains(c))
        || s.split('/').any(|p| matches!(p, "" | "." | ".."))
    {
        return Err(refuse("path-invalid"));
    }
    Ok(s.split('/').map(percent).collect::<Vec<_>>().join("/"))
}
fn path(parts: &Value, args: &Value) -> Result<String> {
    let mut out = String::new();
    for part in parts
        .as_array()
        .ok_or_else(|| refuse("declaration-invalid"))?
    {
        if let Some(s) = part.as_str() {
            out.push_str(s)
        } else {
            let value = scalar(
                args.get(string(&part["arg"])?)
                    .ok_or_else(|| refuse("input-schema"))?,
            )?;
            out.push_str(&match string(&part["encoding"])? {
                "path" => relative(&value)?,
                "segment" => {
                    if matches!(value.as_str(), "." | "..") || value.contains(['/', '\\']) {
                        return Err(refuse("path-invalid"));
                    }
                    percent(&value)
                }
                _ => return Err(refuse("binding-encoding-unsupported")),
            });
        }
    }
    Ok(out)
}
/// Resolve the closed data-binding vocabulary; no ambient host paths or identity.
pub fn resolve(x: &Value, args: &Value, context: &Value, results: &Value) -> Result<Value> {
    if let Some(o) = x.as_object() {
        if o.len() == 1 {
            if let Some(k) = o.get("arg") {
                return args
                    .get(string(k)?)
                    .cloned()
                    .ok_or_else(|| refuse("input-schema"));
            }
            if let Some(k) = o.get("context") {
                return context
                    .get(string(k)?)
                    .cloned()
                    .ok_or_else(|| refuse("context-missing"));
            }
            if let Some(p) = o.get("result") {
                let mut v = results;
                for k in p.as_array().ok_or_else(|| refuse("declaration-invalid"))? {
                    v = if let Some(i) = k.as_u64() {
                        v.get(i as usize)
                    } else {
                        v.get(string(k)?)
                    }
                    .ok_or_else(|| refuse("result-binding-missing"))?;
                }
                return Ok(v.clone());
            }
            if let Some(a) = o.get("concat") {
                let mut s = String::new();
                for v in a.as_array().ok_or_else(|| refuse("declaration-invalid"))? {
                    s.push_str(&scalar(&resolve(v, args, context, results)?)?);
                }
                return Ok(json!(s));
            }
            if let Some(p) = o.get("path") {
                return Ok(json!(path(p, args)?));
            }
        }
        let mut out = serde_json::Map::new();
        for (k, v) in o {
            out.insert(k.clone(), resolve(v, args, context, results)?);
        }
        return Ok(Value::Object(out));
    }
    if let Some(a) = x.as_array() {
        return Ok(Value::Array(
            a.iter()
                .map(|v| resolve(v, args, context, results))
                .collect::<Result<_>>()?,
        ));
    }
    Ok(x.clone())
}
impl Declaration {
    pub fn load(bytes: &[u8]) -> Result<Self> {
        if bytes.len() > 4 * 1024 * 1024 {
            return Err(refuse("declaration-over-bound"));
        }
        let value: Value =
            serde_json::from_slice(bytes).map_err(|_| refuse("declaration-invalid"))?;
        if value["format"] != "mini-app-interface-v1" {
            return Err(refuse("interface-version-unsupported"));
        }
        let package_id = string(&value["packageId"])?.to_owned();
        if package_id.len() != 32
            || !package_id
                .bytes()
                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        {
            return Err(refuse("declaration-package-invalid"));
        }
        let ops = value["operations"]
            .as_object()
            .ok_or_else(|| refuse("declaration-invalid"))?;
        if ops.is_empty() {
            return Err(refuse("declaration-invalid"));
        }
        for key in ["bodyBytes", "replyBytes"] {
            if number(&value["limits"][key])? > 1048576 {
                return Err(refuse("declaration-limit-invalid"));
            }
        }
        for op in ops.values() {
            if !op["input"].is_object() || !op["output"].is_object() || !op["write"].is_boolean() {
                return Err(refuse("declaration-invalid"));
            }
        }
        let sha256 = format!(
            "{:x}",
            Sha256::digest(
                serde_json::to_vec(&canonical(&value))
                    .map_err(|_| refuse("declaration-invalid"))?
            )
        );
        let d = Self {
            value,
            sha256,
            package_id,
        };
        for name in ops_keys(&d.value)? {
            d.dependencies(&name, &mut Vec::new())?;
        }
        Ok(d)
    }
    fn dependencies(&self, name: &str, stack: &mut Vec<String>) -> Result<()> {
        if stack.iter().any(|n| n == name) {
            return Err(refuse("declaration-cyclic-relation"));
        }
        let op = self.operation(name)?;
        stack.push(name.into());
        if let Some(reqs) = op.get("requires") {
            for req in reqs
                .as_array()
                .ok_or_else(|| refuse("declaration-invalid"))?
            {
                let n = string(&req["op"])?;
                if self.operation(n)?["write"] != false {
                    return Err(refuse("declaration-mutating-relation"));
                }
                self.dependencies(n, stack)?;
            }
        }
        stack.pop();
        Ok(())
    }
    fn operation(&self, name: &str) -> Result<&Value> {
        self.value["operations"]
            .get(name)
            .ok_or_else(|| refuse("operation-unknown"))
    }
    pub fn tools(&self) -> Result<Vec<Value>> {
        let mut tools = vec![];
        for (name, op) in self.value["operations"].as_object().unwrap() {
            let mut input = op["input"].clone();
            input["$defs"] = self.value["$defs"].clone();
            tools.push(json!({"name":format!("mini_{}_{}",string(&self.value["name"])?,name.replace('.',"_")),"description":op["description"],"inputSchema":input,"outputSchema":{"type":"object","properties":{"value":op["output"]},"required":["value"],"additionalProperties":false,"$defs":self.value["$defs"]},"operation":name,"packageId":self.package_id,"interfaceSha256":self.sha256}));
        }
        Ok(tools)
    }
    pub fn prepare(&self, name: &str, args: &Value, context: &Value) -> Result<PreparedCall> {
        let op = self.operation(name)?;
        self.validate(&op["input"], args, "input", 0)?;
        if op
            .get("requires")
            .and_then(Value::as_array)
            .is_some_and(|a| !a.is_empty())
        {
            return Err(refuse("relation-preflight-required"));
        }
        self.encode(name, args, context)
    }
    fn encode(&self, name: &str, args: &Value, context: &Value) -> Result<PreparedCall> {
        let op = self.operation(name)?;
        let b = &op["binding"];
        if b["protocol"] != "http" {
            return Err(refuse("transport-unsupported"));
        }
        let empty = json!({});
        let mut headers = resolve(
            b.get("headers").unwrap_or(&empty),
            args,
            context,
            &Value::Null,
        )?;
        let count = ["json", "base64", "text"]
            .iter()
            .filter(|k| b.get(**k).is_some())
            .count();
        if count > 1 {
            return Err(refuse("declaration-ambiguous-body"));
        }
        let body = if let Some(v) = b.get("json") {
            headers["content-type"] = json!("application/json");
            serde_json::to_vec(&resolve(v, args, context, &Value::Null)?)
                .map_err(|_| refuse("binding-json"))?
        } else if let Some(v) = b.get("base64") {
            binary(&resolve(v, args, context, &Value::Null)?)?
        } else {
            b.get("text")
                .map(string)
                .transpose()?
                .unwrap_or("")
                .as_bytes()
                .to_vec()
        };
        if body.len() as u64 > number(&self.value["limits"]["bodyBytes"])? {
            return Err(refuse("body-over-bound"));
        }
        let mut ordered_headers = vec![];
        for (k, v) in headers
            .as_object()
            .ok_or_else(|| refuse("header-invalid"))?
        {
            let s = string(v)?;
            if k.is_empty()
                || k.chars().any(|c| !c.is_ascii_alphanumeric() && c != '-')
                || s.chars().any(|c| c.is_control())
            {
                return Err(refuse("header-invalid"));
            }
            if k.starts_with("x-sandstorm-") || matches!(k.as_str(), "host" | "authorization") {
                return Err(refuse("header-identity-forbidden"));
            }
            ordered_headers.push((k.clone(), s.into()));
        }
        let q = resolve(
            b.get("query").unwrap_or(&empty),
            args,
            context,
            &Value::Null,
        )?;
        let mut query = vec![];
        for (k, v) in q.as_object().ok_or_else(|| refuse("query-invalid"))? {
            query.push(format!("{}={}", percent(k), percent(&scalar(v)?)))
        }
        Ok(PreparedCall {
            method: string(&b["method"])?.into(),
            path: path(&b["path"], args)?,
            query: query.join("&"),
            ordered_headers,
            body,
            declaration_sha256: self.sha256.clone(),
            package_id: self.package_id.clone(),
            operation: name.into(),
            write: op["write"] == true,
        })
    }
    pub fn decode(
        &self,
        p: &PreparedCall,
        status: u16,
        headers: &[(String, String)],
        body: &[u8],
    ) -> Result<Value> {
        if p.declaration_sha256 != self.sha256 || p.package_id != self.package_id {
            return Err(refuse("interface-binding-mismatch"));
        }
        let op = self.operation(&p.operation)?;
        if body.len() as u64 > number(&self.value["limits"]["replyBytes"])? {
            return Err(Refusal {
                name: "reply-over-bound".into(),
                uncertain: p.write,
            });
        }
        if !op["binding"]["status"]
            .as_array()
            .ok_or_else(|| refuse("declaration-invalid"))?
            .contains(&json!(status))
        {
            return Err(Refusal {
                name: match status {
                    401 => "app-auth-required",
                    403 => "app-permission-denied",
                    404 => "app-not-found",
                    409 => "app-conflict",
                    412 => "app-precondition-failed",
                    500..=599 if p.write => "app-server-error-after-dispatch",
                    _ => "app-http-status",
                }
                .into(),
                uncertain: p.write && status >= 500,
            });
        }
        let value = match string(&op["binding"]["decode"])? {
            "json" => {
                if !headers.iter().any(|(k, v)| {
                    k.eq_ignore_ascii_case("content-type")
                        && v.to_ascii_lowercase().contains("json")
                }) {
                    return Err(refuse("app-content-type"));
                }
                serde_json::from_slice(body).map_err(|_| refuse("app-response-invalid"))?
            }
            "base64" => json!({"contentBase64":STANDARD.encode(body)}),
            "status" => json!({"status":status}),
            "dav-multistatus" => dav(body)?,
            _ => return Err(refuse("binding-decoding-unsupported")),
        };
        self.validate(&op["output"], &value, "output", 0)?;
        Ok(value)
    }
    fn validate(&self, s: &Value, v: &Value, phase: &str, depth: usize) -> Result<()> {
        let bad = || refuse(&format!("{phase}-schema"));
        if depth > 64 {
            return Err(bad());
        }
        if let Some(r) = s.get("$ref") {
            let name = string(r)?.strip_prefix("#/$defs/").ok_or_else(bad)?;
            return self.validate(
                self.value["$defs"].get(name).ok_or_else(bad)?,
                v,
                phase,
                depth + 1,
            );
        }
        if let Some(t) = s.get("type") {
            let types: Vec<&str> = if let Some(a) = t.as_array() {
                a.iter().map(string).collect::<Result<_>>()?
            } else {
                vec![string(t)?]
            };
            if !types.iter().any(|t| match *t {
                "object" => v.is_object(),
                "array" => v.is_array(),
                "string" => v.is_string(),
                "integer" => v.as_i64().is_some() || v.as_u64().is_some(),
                "number" => v.is_number(),
                "boolean" => v.is_boolean(),
                "null" => v.is_null(),
                _ => false,
            }) {
                return Err(bad());
            }
        }
        if let Some(a) = s.get("enum") {
            if !a.as_array().ok_or_else(bad)?.contains(v) {
                return Err(bad());
            }
        }
        if let Some(c) = s.get("const") {
            if c != v {
                return Err(bad());
            }
        }
        if let Some(o) = v.as_object() {
            if let Some(required) = s["required"].as_array() {
                for k in required {
                    if !o.contains_key(string(k)?) {
                        return Err(bad());
                    }
                }
            }
            for (k, x) in o {
                if let Some(sub) = s["properties"].get(k) {
                    self.validate(sub, x, phase, depth + 1)?
                } else if s["additionalProperties"] == false {
                    return Err(bad());
                }
            }
        }
        if let Some(a) = v.as_array() {
            if s["maxItems"].as_u64().is_some_and(|n| a.len() as u64 > n)
                || s["minItems"].as_u64().is_some_and(|n| (a.len() as u64) < n)
            {
                return Err(bad());
            }
            if let Some(sub) = s.get("items") {
                for x in a {
                    self.validate(sub, x, phase, depth + 1)?
                }
            }
        }
        if let Some(text) = v.as_str() {
            let n = text.chars().count() as u64;
            if s["maxLength"].as_u64().is_some_and(|m| n > m)
                || s["minLength"].as_u64().is_some_and(|m| n < m)
            {
                return Err(bad());
            }
            if let Some(pat) = s["pattern"].as_str() {
                if !regex_lite::Regex::new(pat)
                    .map_err(|_| refuse("schema-pattern-unsupported"))?
                    .is_match(text)
                {
                    return Err(bad());
                }
            }
            if s["format"] == "relative-path" {
                relative(text)?;
            }
            if s["contentEncoding"] == "base64" {
                let bytes = binary(v)?;
                let limit = if phase == "input" {
                    "bodyBytes"
                } else {
                    "replyBytes"
                };
                if bytes.len() as u64 > number(&self.value["limits"][limit])? {
                    return Err(refuse(if phase == "input" {
                        "body-over-bound"
                    } else {
                        "reply-over-bound"
                    }));
                }
            }
        }
        if let Some(n) = v.as_f64() {
            if s["minimum"].as_f64().is_some_and(|m| n < m)
                || s["maximum"].as_f64().is_some_and(|m| n > m)
            {
                return Err(bad());
            }
        }
        Ok(())
    }
}
fn ops_keys(v: &Value) -> Result<Vec<String>> {
    Ok(v["operations"]
        .as_object()
        .ok_or_else(|| refuse("declaration-invalid"))?
        .keys()
        .cloned()
        .collect())
}
fn binary(v: &Value) -> Result<Vec<u8>> {
    let s = string(v)?;
    let bytes = STANDARD.decode(s).map_err(|_| refuse("binary-encoding"))?;
    if STANDARD.encode(&bytes) != s {
        return Err(refuse("binary-encoding"));
    }
    Ok(bytes)
}
fn dav(body: &[u8]) -> Result<Value> {
    let text = std::str::from_utf8(body).map_err(|_| refuse("dav-response-invalid"))?;
    let upper = text.to_ascii_uppercase();
    if upper.contains("<!DOCTYPE") || upper.contains("<!ENTITY") {
        return Err(refuse("dav-xml-unsafe"));
    }
    let doc = roxmltree::Document::parse(text).map_err(|_| refuse("dav-response-invalid"))?;
    let tag = |n: roxmltree::Node<'_, '_>, name: &str| n.has_tag_name(("DAV:", name));
    let root = doc.root_element();
    if !tag(root, "multistatus") {
        return Err(refuse("dav-response-invalid"));
    }
    let mut out = vec![];
    for r in root.children().filter(|n| tag(*n, "response")) {
        let href = r
            .children()
            .find(|n| tag(*n, "href"))
            .and_then(|n| n.text())
            .ok_or_else(|| refuse("dav-response-invalid"))?;
        let mut collection = None;
        let mut size = Value::Null;
        let mut etag = Value::Null;
        for ps in r.children().filter(|n| tag(*n, "propstat")) {
            let status = ps
                .children()
                .find(|n| tag(*n, "status"))
                .and_then(|n| n.text())
                .ok_or_else(|| refuse("dav-response-invalid"))?;
            let code = status
                .split_whitespace()
                .nth(1)
                .and_then(|s| s.parse::<u16>().ok())
                .ok_or_else(|| refuse("dav-response-invalid"))?;
            if code == 404 {
                continue;
            }
            if !(200..300).contains(&code) {
                return Err(refuse("dav-property-refused"));
            }
            let props = ps
                .children()
                .find(|n| tag(*n, "prop"))
                .ok_or_else(|| refuse("dav-response-invalid"))?;
            for p in props.children().filter(|n| n.is_element()) {
                if tag(p, "resourcetype") {
                    collection = Some(p.children().any(|n| tag(n, "collection")))
                } else if tag(p, "getcontentlength") {
                    size = match p.text() {
                        None => Value::Null,
                        Some(t) => json!(t
                            .parse::<u64>()
                            .map_err(|_| refuse("dav-response-invalid"))?),
                    };
                } else if tag(p, "getetag") {
                    etag = p.text().map(|t| json!(t)).unwrap_or(Value::Null)
                }
            }
        }
        out.push(json!({"href":href,"collection":collection.ok_or_else(||refuse("dav-property-missing"))?,"bytes":size,"etag":etag}));
    }
    Ok(json!(out))
}
