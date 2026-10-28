//! Display metadata from the same package-bound declarations used by agent tools.
//! A declaration is not a successful qualification or a package admission verdict.
use serde_json::{json, Value};
use std::sync::OnceLock;

fn declarations() -> &'static [Value] {
    static DECLARATIONS: OnceLock<Vec<Value>> = OnceLock::new();
    DECLARATIONS.get_or_init(|| {
        let sources: &[&str] = include!(concat!(env!("OUT_DIR"), "/app-interfaces.rs"));
        sources.iter().filter_map(|s| {
            let value: Value = serde_json::from_str(s).expect("valid app interface JSON");
            (value["format"] == "mini-app-interface-v1").then_some(value)
        }).collect()
    })
}

pub(super) fn summary(app_id: &str, package_id: &str) -> Value {
    let Some(d) = declarations().iter().find(|d| d["appId"] == app_id && d["packageId"] == package_id) else {
        return Value::Null;
    };
    json!({"version":d["interfaceVersion"], "status":d["status"], "$defs":d["$defs"], "operations":d["operations"]
        .as_object().into_iter().flatten().map(|(name, op)| json!({
            "name":name,"description":op["description"],"input":op["input"],
            "output":op["output"],"write":op["write"]
        })).collect::<Vec<_>>()})
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn operations_are_package_bound_and_keep_the_declared_status() {
        assert!(!declarations().is_empty());
        for d in declarations() {
            let app = d["appId"].as_str().unwrap();
            let package = d["packageId"].as_str().unwrap();
            let found = summary(app, package);
            assert_eq!(found["status"], d["status"]);
            assert_eq!(found["operations"].as_array().unwrap().len(), d["operations"].as_object().unwrap().len());
            assert!(summary(app, "another-package").is_null());
            assert!(summary("another-app", package).is_null());
        }
    }
}
