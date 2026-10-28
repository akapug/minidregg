//! Bounded DDP data state, independent of authority and physical WebSocket I/O.
//! Each state belongs to one admitted member/session/channel; never reconnect or
//! resend a mutating method to recover a lost result/updated pair.
use super::app_interface::{Refusal, Result};
use serde_json::{json, Value};
use std::collections::{BTreeMap, BTreeSet};
fn error(name: &str) -> Refusal {
    Refusal {
        name: name.into(),
        uncertain: false,
    }
}
#[derive(Default, Debug)]
pub struct DdpState {
    documents: BTreeMap<(String, String), Value>,
    results: BTreeMap<String, Value>,
    updated: BTreeSet<String>,
    received_bytes: usize,
    pub connected: bool,
    ready: BTreeSet<String>,
    refused: BTreeSet<String>,
}
impl DdpState {
    /// Apply an exact received frame; return a required pong if any. Limits cover
    /// unrelated messages as well as the requested method/publication.
    pub fn frame(&mut self, raw: &str, limit: usize) -> Result<Option<Value>> {
        if raw.len() > 1048576 {
            return Err(error("ddp-frame-invalid-or-oversize"));
        }
        self.received_bytes = self
            .received_bytes
            .checked_add(raw.len())
            .ok_or_else(|| error("ddp-buffer-over-bound"))?;
        if self.received_bytes > 4 * 1048576 {
            return Err(error("ddp-buffer-over-bound"));
        }
        let m: Value = serde_json::from_str(raw).map_err(|_| error("ddp-frame-invalid"))?;
        if !m.is_object() {
            return Err(error("ddp-frame-invalid"));
        }
        let kind = m["msg"]
            .as_str()
            .ok_or_else(|| error("ddp-frame-invalid"))?;
        for name in ["methods", "subs", "cleared"] {
            if let Some(v) = m.get(name) {
                if !v.as_array().is_some_and(|a| a.iter().all(Value::is_string)) {
                    return Err(error("ddp-frame-invalid"));
                }
            }
        }
        match kind {
            "connected" => self.connected = true,
            "ping" => {
                let mut pong = json!({"msg":"pong"});
                if let Some(id) = m.get("id") {
                    if !id.is_string() {
                        return Err(error("ddp-frame-invalid"));
                    }
                    pong["id"] = id.clone();
                }
                return Ok(Some(pong));
            }
            "result" => {
                let id = m["id"].as_str().ok_or_else(|| error("ddp-frame-invalid"))?;
                if m.get("error").is_some_and(|v| !v.is_object()) {
                    return Err(error("ddp-frame-invalid"));
                }
                self.results.insert(id.into(), m);
            }
            "updated" => {
                if let Some(a) = m["methods"].as_array() {
                    for id in a {
                        self.updated.insert(id.as_str().unwrap().into());
                    }
                }
            }
            "ready" => {
                if let Some(a) = m["subs"].as_array() {
                    for id in a {
                        self.ready.insert(id.as_str().unwrap().into());
                    }
                }
            }
            "nosub" => {
                let id = m["id"].as_str().ok_or_else(|| error("ddp-frame-invalid"))?;
                self.refused.insert(id.into());
            }
            "added" | "changed" | "removed" => {
                let id = m["id"].as_str().ok_or_else(|| error("ddp-frame-invalid"))?;
                let coll = m["collection"]
                    .as_str()
                    .ok_or_else(|| error("ddp-frame-invalid"))?;
                if m.get("fields").is_some_and(|v| !v.is_object()) {
                    return Err(error("ddp-frame-invalid"));
                }
                let key = (coll.into(), id.into());
                if kind == "removed" {
                    self.documents.remove(&key);
                } else {
                    if kind == "added" {
                        self.documents.insert(key.clone(), json!({"id":id}));
                    }
                    let doc = self
                        .documents
                        .get_mut(&key)
                        .ok_or_else(|| error("ddp-change-without-document"))?
                        .as_object_mut()
                        .ok_or_else(|| error("ddp-frame-invalid"))?;
                    if let Some(fields) = m["fields"].as_object() {
                        for (k, v) in fields {
                            doc.insert(k.clone(), v.clone());
                        }
                    }
                    if let Some(fields) = m["cleared"].as_array() {
                        for k in fields {
                            doc.remove(k.as_str().unwrap());
                        }
                    }
                    doc.insert("id".into(), json!(id));
                }
                if self.documents.len() > limit
                    || serde_json::to_vec(&self.documents.values().collect::<Vec<_>>())
                        .map_err(|_| error("ddp-frame-invalid"))?
                        .len()
                        > 1048576
                {
                    return Err(error("ddp-snapshot-over-bound"));
                }
            }
            "failed" | "error" => return Err(error("ddp-protocol-refused")),
            _ => {}
        }
        if self.results.len() + self.updated.len() + self.ready.len() + self.refused.len()
            > limit.saturating_mul(2)
        {
            return Err(error("ddp-buffer-over-bound"));
        }
        Ok(None)
    }
    pub fn method_waiting_for(&self, id: &str) -> &'static str {
        if self.results.contains_key(id) {
            "updated"
        } else {
            "result"
        }
    }
    pub fn method_result(&self, id: &str) -> Result<Option<Value>> {
        let Some(result) = self.results.get(id) else {
            return Ok(None);
        };
        if result.get("error").is_some() {
            return Err(error("ddp-method-refused"));
        }
        if self.updated.contains(id) {
            Ok(Some(result.get("result").cloned().unwrap_or(Value::Null)))
        } else {
            Ok(None)
        }
    }
    pub fn snapshot(&self, id: &str, collections: &[String]) -> Result<Option<Value>> {
        if self.refused.contains(id) {
            return Err(error("ddp-subscription-refused"));
        }
        if !self.ready.contains(id) {
            return Ok(None);
        }
        let mut out = serde_json::Map::new();
        for coll in collections {
            out.insert(
                coll.clone(),
                Value::Array(
                    self.documents
                        .iter()
                        .filter(|((c, _), _)| c == coll)
                        .map(|(_, v)| v.clone())
                        .collect(),
                ),
            );
        }
        Ok(Some(Value::Object(out)))
    }
}
