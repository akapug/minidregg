//! Lossless role-relevant ViewInfo projection for Lean canonical authoring.
//! This is app-supplied descriptor input, not an effective permission grant.
use crate::ViewInfo;
use serde_json::{json, Value};

const MAX_SOURCE_BYTES: usize = 1024 * 1024;

/// Projects the exact ordered role-relevant fields from a captured Cap'n Proto
/// ViewInfo. Names, counts, masks and defaults are validated only by Lean's
/// `Schema.valid` (Kernel/ApplicationPermissionSchema.lean); this projection
/// carries no copy of those bounds. `version` is an explicit controller input because Sandstorm's
/// ViewInfo does not contain a schema version. The resulting JSON must be
/// parsed/validated by Lean's authoring route; this Rust value has no authority.
pub fn permission_schema_source(info: &ViewInfo, version: u64) -> Result<Value, String> {
    Ok(json!({
        "type": "minidregg-application-permission-schema-source-v1",
        "version": version.to_string(),
        "permissions": info.permissions.iter().map(|p| json!({
            "name": p.name,
            "obsolete": p.obsolete,
        })).collect::<Vec<_>>(),
        "roles": info.roles.iter().map(|r| json!({
            "permissions": r.permissions,
            "obsolete": r.obsolete,
            "default": r.default,
        })).collect::<Vec<_>>(),
        "denied": info.denied_permissions,
    }))
}

/// A bounded transport notation; canonical bytes/root are authored by Lean.
pub fn permission_schema_source_bytes(info: &ViewInfo, version: u64) -> Result<Vec<u8>, String> {
    let bytes = serde_json::to_vec(&permission_schema_source(info, version)?)
        .map_err(|error| error.to_string())?;
    if bytes.len() > MAX_SOURCE_BYTES {
        return Err("permission schema source exceeds byte bound".into());
    }
    Ok(bytes)
}
