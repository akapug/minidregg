//! Ordinary HTTP request construction for the Oracle operations protocol.
//!
//! Profiles are operator discovery hints, not grants or evidence that an
//! operation exists. Every constructed request goes through the same Mini
//! application dispatch and settlement as `mini_application_api`. This module
//! does not evaluate operations, interpret answers, or retry requests.
use serde::{Deserialize, Serialize};
use serde_json::{json, Map, Value};

pub(crate) const PROTOCOL: &str = "oracle-operations-v1";
use crate::application_api_tools::MAX_BODY_BYTES;

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct ServiceProfile {
    pub application: String,
    pub protocol: String,
}

pub(crate) fn validate_profiles(
    profiles: &[ServiceProfile],
    lifetime_names: &[String],
) -> Result<(), String> {
    if profiles.len() > 16 {
        return Err("applicationServices exceeds 16 entries".into());
    }
    let mut seen = std::collections::HashSet::new();
    for profile in profiles {
        if profile.protocol != PROTOCOL {
            return Err("applicationServices protocol is unsupported".into());
        }
        if !lifetime_names.contains(&profile.application) {
            return Err("applicationServices requires a configured lifetime API route".into());
        }
        if !seen.insert(&profile.application) {
            return Err("applicationServices has a duplicate application".into());
        }
    }
    Ok(())
}

pub(crate) fn applications(profiles: &[ServiceProfile]) -> Vec<String> {
    profiles
        .iter()
        .filter(|p| p.protocol == PROTOCOL)
        .map(|p| p.application.clone())
        .collect()
}

pub(crate) fn is_tool(name: &str) -> bool {
    matches!(name, "mini_oracle_discover" | "mini_oracle_call")
}

fn string<'a>(object: &'a Map<String, Value>, key: &str) -> Result<&'a str, String> {
    object
        .get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| format!("Oracle {key} must be a string"))
}

fn identifier(value: &str, operation: bool) -> bool {
    let max = if operation { 160 } else { 80 };
    !value.is_empty()
        && value.len() <= max
        && (!operation || value.as_bytes()[0].is_ascii_alphanumeric())
        && value.bytes().all(|b| {
            b.is_ascii_alphanumeric() || b == b'_' || b == b'-' || (operation && b == b'.')
        })
}

fn percent_encode(value: &str) -> String {
    let mut out = String::new();
    for b in value.bytes() {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') {
            out.push(b as char);
        } else {
            use std::fmt::Write;
            write!(&mut out, "%{b:02X}").unwrap();
        }
    }
    out
}

fn http(application: &str, method: &str, path: String, query: String, body: Vec<u8>) -> Value {
    let mut headers = vec![json!({"name":"accept", "value":"application/json"})];
    if method == "POST" {
        headers.push(json!({"name":"content-type", "value":"application/json"}));
    }
    let mut body_hex = String::with_capacity(body.len() * 2);
    for byte in body {
        use std::fmt::Write;
        write!(&mut body_hex, "{byte:02x}").unwrap();
    }
    json!({"application":application,"method":method,"path":path,
        "query":query,"headers":headers,"bodyHex":body_hex})
}

/// Deterministic translation. Unknown operation IDs and argument schemas are
/// deliberately left to the live appliance; a stale client must not decide
/// which operations the current runtime can execute.
pub(crate) fn http_arguments(
    name: &str,
    arguments: &Value,
    profiles: &[ServiceProfile],
) -> Result<Value, String> {
    let object = arguments
        .as_object()
        .ok_or("Oracle arguments must be an object")?;
    let application = string(object, "application")?;
    if !profiles
        .iter()
        .any(|p| p.application == application && p.protocol == PROTOCOL)
    {
        return Err("Oracle application is not in the operator service catalog".into());
    }
    match name {
        "mini_oracle_discover" => {
            if object.keys().any(|key| {
                !matches!(
                    key.as_str(),
                    "application" | "operationId" | "query" | "availability" | "offset" | "limit"
                )
            }) {
                return Err("Oracle discovery has unknown fields".into());
            }
            if object.contains_key("operationId") {
                let operation = string(object, "operationId")?;
                if !identifier(operation, true) || object.len() != 2 {
                    return Err(
                        "Oracle operationId is invalid or combined with search fields".into(),
                    );
                }
                return Ok(http(
                    application,
                    "GET",
                    format!("operations/{operation}"),
                    String::new(),
                    vec![],
                ));
            }
            let number = |key: &str, default: u64| -> Result<u64, String> {
                match object.get(key) {
                    None => Ok(default),
                    Some(value) => value
                        .as_u64()
                        .ok_or_else(|| format!("Oracle {key} must be a nonnegative integer")),
                }
            };
            let offset = number("offset", 0)?;
            let limit = number("limit", 10)?;
            if !(1..=50).contains(&limit) {
                return Err("Oracle discovery limit must be 1..50".into());
            }
            let mut query = format!("offset={offset}&limit={limit}");
            if object.contains_key("query") {
                let text = string(object, "query")?;
                if text.len() > 256 {
                    return Err("Oracle discovery query exceeds 256 UTF-8 bytes".into());
                }
                query.push_str("&q=");
                query.push_str(&percent_encode(text));
            }
            if object.contains_key("availability") {
                let availability = string(object, "availability")?;
                if !matches!(availability, "live_direct" | "text_only" | "unavailable") {
                    return Err("Oracle availability filter is invalid".into());
                }
                query.push_str("&availability=");
                query.push_str(availability);
            }
            Ok(http(application, "GET", "operations".into(), query, vec![]))
        }
        "mini_oracle_call" => {
            if object.len() != 5
                || object.keys().any(|key| {
                    !matches!(
                        key.as_str(),
                        "application"
                            | "requestId"
                            | "conversationId"
                            | "operationId"
                            | "arguments"
                    )
                })
            {
                return Err("Oracle call has missing or unknown fields".into());
            }
            let request = string(object, "requestId")?;
            let conversation = string(object, "conversationId")?;
            let operation = string(object, "operationId")?;
            if !identifier(request, false)
                || !identifier(conversation, false)
                || !identifier(operation, true)
            {
                return Err("Oracle request, conversation or operation ID is invalid".into());
            }
            let inputs = object
                .get("arguments")
                .filter(|v| v.is_object())
                .ok_or("Oracle operation arguments must be an object")?;
            let body = serde_json::to_vec(&json!({"request_id":request,
                "conversation_id":conversation,"operation_id":operation,"arguments":inputs}))
            .map_err(|e| e.to_string())?;
            if body.len() > MAX_BODY_BYTES {
                return Err("Oracle invocation exceeds 65536 bytes".into());
            }
            Ok(http(
                application,
                "POST",
                "invoke".into(),
                String::new(),
                body,
            ))
        }
        _ => Err("unknown Oracle tool".into()),
    }
}

pub(crate) fn tool_specs(applications: &[String]) -> Vec<Value> {
    if applications.is_empty() {
        return vec![];
    }
    let application = json!({"type":"string","enum":applications});
    let operation =
        json!({"type":"string","maxLength":160,"pattern":"^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$"});
    let request = json!({"type":"string","maxLength":80,"pattern":"^[A-Za-z0-9_-]{1,80}$"});
    vec![
        json!({"name":"mini_oracle_discover",
            "description":"Find operations in an Oracle appliance, including inputs, units, sources, examples and current availability. Search by query and follow next_offset; use operationId alone for details. Only live_direct operations are directly callable. Every discovery request uses the application's current Mini grant and purse.",
            "inputSchema":{"type":"object","properties":{
                "application":application,"operationId":operation,
                "query":{"type":"string","maxLength":256},
                "availability":{"type":"string","enum":["live_direct","text_only","unavailable"]},
                "offset":{"type":"integer","minimum":0},
                "limit":{"type":"integer","minimum":1,"maximum":50,"default":10}},
                "required":["application"],"additionalProperties":false}}),
        json!({"name":"mini_oracle_call",
            "description":"Call a discovered Oracle operation with its declared arguments. Discover the input schema first. Keep requestId and arguments unchanged for an appliance replay; an uncertain Mini delivery requires exact lookup before any new dispatch. A completed refusal is not an answer, and returned evidence retains its original scope.",
            "inputSchema":{"type":"object","properties":{
                "application":application,"operationId":operation,"requestId":request,
                "conversationId":request,"arguments":{"type":"object"}},
                "required":["application","requestId","conversationId","operationId","arguments"],
                "additionalProperties":false}}),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    fn profiles() -> Vec<ServiceProfile> {
        vec![ServiceProfile {
            application: "oracle-app".into(),
            protocol: PROTOCOL.into(),
        }]
    }
    fn call() -> Value {
        json!({"application":"oracle-app","requestId":"r-1","conversationId":"c_1",
            "operationId":"specialist.astronomy-v3.answer","arguments":{"text":"three Mars years"}})
    }
    #[test]
    fn oracle_profile_requires_named_lifetime_route_and_known_protocol() {
        assert!(validate_profiles(&profiles(), &["oracle-app".into()]).is_ok());
        assert!(validate_profiles(&profiles(), &["other-app".into()]).is_err());
        let mut p = profiles();
        p.push(p[0].clone());
        assert!(validate_profiles(&p, &["oracle-app".into()]).is_err());
        p.truncate(1);
        p[0].protocol = "arbitrary-proxy".into();
        assert!(validate_profiles(&p, &["oracle-app".into()]).is_err());
    }
    #[test]
    fn oracle_discovery_percent_encodes_query_and_cannot_select_a_host_path() {
        let input = http_arguments(
            "mini_oracle_discover",
            &json!({"application":"oracle-app",
            "query":"mars & q=雪#","availability":"live_direct","offset":2,"limit":3}),
            &profiles(),
        )
        .unwrap();
        assert_eq!(input["path"], "operations");
        assert_eq!(
            input["query"],
            "offset=2&limit=3&q=mars%20%26%20q%3D%E9%9B%AA%23&availability=live_direct"
        );
        assert_eq!(input["bodyHex"], "");
        crate::application_api_tools::parse_input(&input, &["oracle-app".into()]).unwrap();
        for operation in ["../secret", "op?x=1", "op%2fsecret", "/etc/passwd", ""] {
            assert!(http_arguments(
                "mini_oracle_discover",
                &json!({"application":"oracle-app","operationId":operation}),
                &profiles()
            )
            .is_err());
        }
        assert!(http_arguments(
            "mini_oracle_discover",
            &json!({"application":"oracle-app","operationId":"core.math.answer","limit":1}),
            &profiles()
        )
        .is_err());
    }
    #[test]
    fn oracle_calls_use_existing_http_parser_and_lifetime_dispatch_exact_bytes() {
        let value = http_arguments("mini_oracle_call", &call(), &profiles()).unwrap();
        let input =
            crate::application_api_tools::parse_input(&value, &["oracle-app".into()]).unwrap();
        assert_eq!(input.method, "POST");
        assert_eq!(input.path, "invoke");
        assert_eq!(
            serde_json::from_slice::<Value>(&input.body).unwrap(),
            json!({"request_id":"r-1","conversation_id":"c_1",
            "operation_id":"specialist.astronomy-v3.answer","arguments":{"text":"three Mars years"}})
        );
        let forward =
            crate::application_api_tools::lifetime_dispatch_request(77, &"a".repeat(64), &input)
                .unwrap();
        assert_eq!(forward["bodyHex"], value["bodyHex"]);
        assert_eq!(forward["path"], "invoke");
        assert_eq!(forward["type"], "dispatch-v3");
        assert_eq!(
            value,
            http_arguments("mini_oracle_call", &call(), &profiles()).unwrap()
        );
        let mut changed = call();
        changed["arguments"]["text"] = json!("four Mars years");
        assert_ne!(
            value["bodyHex"],
            http_arguments("mini_oracle_call", &changed, &profiles()).unwrap()["bodyHex"]
        );
    }
    #[test]
    fn oracle_input_bounds_and_operator_catalog_are_enforced() {
        for key in ["requestId", "conversationId"] {
            let mut value = call();
            value[key] = json!("bad/id");
            assert!(http_arguments("mini_oracle_call", &value, &profiles()).is_err());
        }
        let mut value = call();
        value["application"] = json!("other-app");
        assert!(http_arguments("mini_oracle_call", &value, &profiles()).is_err());
        value = call();
        value["ticket"] = json!("invented");
        assert!(http_arguments("mini_oracle_call", &value, &profiles()).is_err());
        value = call();
        value["arguments"] = json!({"text":"x".repeat(MAX_BODY_BYTES)});
        assert!(http_arguments("mini_oracle_call", &value, &profiles()).is_err());
        for limit in [json!(0), json!(51), json!(-1), json!(1.5), Value::Null] {
            assert!(http_arguments(
                "mini_oracle_discover",
                &json!({"application":"oracle-app","limit":limit}),
                &profiles()
            )
            .is_err());
        }
    }
    #[test]
    fn oracle_full_native_body_composes_with_the_existing_api() {
        let mut value = call();
        value["arguments"] = json!({"text":""});
        let empty = http_arguments("mini_oracle_call", &value, &profiles()).unwrap();
        let overhead = empty["bodyHex"].as_str().unwrap().len() / 2;
        value["arguments"]["text"] = json!("x".repeat(MAX_BODY_BYTES - overhead));
        let http = http_arguments("mini_oracle_call", &value, &profiles()).unwrap();
        let input =
            crate::application_api_tools::parse_input(&http, &["oracle-app".into()]).unwrap();
        assert_eq!(input.body.len(), 65_536);
        let frame =
            crate::application_api_tools::lifetime_dispatch_request(7, &"a".repeat(64), &input)
                .unwrap();
        assert_eq!(frame["bodyHex"], http["bodyHex"]);
        value["arguments"]["text"] = json!("x".repeat(MAX_BODY_BYTES - overhead + 1));
        assert!(http_arguments("mini_oracle_call", &value, &profiles())
            .unwrap_err()
            .contains("65536 bytes"));
    }

    #[test]
    fn oracle_unknown_operation_is_forwarded_for_live_runtime_decision() {
        let mut value = call();
        value["operationId"] = json!("future.component.operation");
        assert_eq!(
            http_arguments("mini_oracle_call", &value, &profiles()).unwrap()["path"],
            "invoke"
        );
        assert!(tool_specs(&[]).is_empty());
        assert_eq!(tool_specs(&["oracle-app".into()]).len(), 2);
    }
}
