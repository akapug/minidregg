//! `mini export-world --workspace DIR --home HOME --out FILE`: the member's own world as one tar,
//! for the end of the demo (11 November). Reads only: the workspace's references, each document
//! as the Host renders it to this member now (one signed read each, `doc_search::direct`, the
//! renderer `doc read` and the web body use) and its signed view, every retained attempt with its
//! standing (the SDK's own reading), the local room state under HOME/chat, the public key and the
//! hosted-custody statement, and a manifest with the world root and height of the last read.
//! Nothing is proposed or submitted; the file lands where the caller names (the body names one
//! under the member's HOME and deletes it once streamed).

use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

use serde_json::{json, Value};
use sha2::{Digest, Sha256};

use crate::render::Body;
use crate::workspace::{bounded_json, member, member_path};
use crate::{Args, Result};

/// The whole archive stays under this; a member's demo world is far smaller.
const MAX_TOTAL: u64 = 512 * 1024 * 1024;
const MAX_FILE: u64 = 16 * 1024 * 1024;

pub(crate) fn run(mut args: Args) -> Result<()> {
    let root = PathBuf::from(args.required("workspace")?);
    let home = PathBuf::from(args.required("home")?);
    let out = PathBuf::from(args.required("out")?);
    args.finish()?;
    if let Some(parent) = out.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("{}: {e}", parent.display()))?;
        fs::set_permissions(parent, std::os::unix::fs::PermissionsExt::from_mode(0o700)).map_err(|e| e.to_string())?;
    }
    let workspace = bounded_json(&root.join("workspace.json"))?;
    // Written beside, then renamed: a reader of HOME/exports sees a whole archive or a `.part`.
    let mut part = out.clone().into_os_string();
    part.push(".part");
    let part = PathBuf::from(part);
    let manifest = export(&root, &workspace, &home, &part).inspect_err(|_| {
        let _ = fs::remove_file(&part);
    })?;
    fs::rename(&part, &out).map_err(|e| e.to_string())?;
    println!("{}", serde_json::to_string_pretty(&json!({
        "type": "mini-world-export-result-v1", "out": out, "subject": manifest["subject"],
        "worldRoot": manifest["worldRoot"], "height": manifest["height"],
        "documents": manifest["documents"].as_array().map_or(0, Vec::len), "files": manifest["files"].as_array().map_or(0, Vec::len),
    })).map_err(|e| e.to_string())?);
    Ok(())
}

struct Tar {
    out: fs::File,
    files: Vec<Value>,
    total: u64,
}

impl Tar {
    fn add(&mut self, name: &str, bytes: &[u8]) -> Result<()> {
        self.total += bytes.len() as u64;
        if self.total > MAX_TOTAL {
            return Err(format!("the export exceeds {MAX_TOTAL} bytes"));
        }
        let path = format!("mini-export/{name}");
        let header = ustar_header(&path, bytes.len() as u64)?;
        self.out.write_all(&header).map_err(|e| e.to_string())?;
        self.out.write_all(bytes).map_err(|e| e.to_string())?;
        let pad = (512 - bytes.len() % 512) % 512;
        self.out.write_all(&vec![0u8; pad]).map_err(|e| e.to_string())?;
        self.files.push(json!({"path": name, "bytes": bytes.len(), "sha256": hex(&Sha256::digest(bytes))}));
        Ok(())
    }

    fn json(&mut self, name: &str, value: &Value) -> Result<()> {
        let mut bytes = serde_json::to_vec_pretty(value).map_err(|e| e.to_string())?;
        bytes.push(b'\n');
        self.add(name, &bytes)
    }

    fn finish(mut self) -> Result<()> {
        self.out.write_all(&[0u8; 1024]).map_err(|e| e.to_string())?;
        self.out.sync_all().map_err(|e| e.to_string())
    }
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// A POSIX ustar header for a regular file (mode 0644, owner 0, mtime 0: the archive's bytes
/// depend only on its contents). Long paths split at a '/' into prefix and name.
fn ustar_header(path: &str, size: u64) -> Result<[u8; 512]> {
    let mut h = [0u8; 512];
    let (prefix, name) = if path.len() <= 100 {
        ("", path)
    } else {
        let cut = path[..path.len().min(155)].rfind('/').filter(|&i| path.len() - i - 1 <= 100).ok_or_else(|| format!("export path too long: {path}"))?;
        (&path[..cut], &path[cut + 1..])
    };
    h[..name.len()].copy_from_slice(name.as_bytes());
    h[100..107].copy_from_slice(b"0000644");
    h[108..115].copy_from_slice(b"0000000");
    h[116..123].copy_from_slice(b"0000000");
    h[124..135].copy_from_slice(format!("{size:011o}").as_bytes());
    h[136..147].copy_from_slice(b"00000000000");
    h[148..156].copy_from_slice(b"        ");
    h[156] = b'0';
    h[257..263].copy_from_slice(b"ustar\0");
    h[263..265].copy_from_slice(b"00");
    h[345..345 + prefix.len()].copy_from_slice(prefix.as_bytes());
    let sum: u32 = h.iter().map(|&b| u32::from(b)).sum();
    h[148..155].copy_from_slice(format!("{sum:06o}\0").as_bytes());
    Ok(h)
}

/// A reference name as one path segment ('/' → '.', as the workspace spells its files).
fn segment(name: &str) -> String {
    name.chars().map(|c| if c.is_ascii_alphanumeric() || "-_.".contains(c) { c } else { '.' }).collect()
}

/// The rendered text: live lines in order; a struck line is omitted; an object or a transclusion
/// is named in brackets.
fn text_of(rendered: &crate::render::Rendered) -> String {
    let mut out = String::new();
    for line in &rendered.lines {
        match &line.body {
            Body::Text { bytes, struck: false } => {
                out.push_str(&String::from_utf8_lossy(bytes));
                out.push('\n');
            }
            Body::Object { label, bytes, struck: false } => out.push_str(&format!("[{label}, {} bytes]\n", bytes.len())),
            Body::Transclusion(_) => out.push_str("[transcluded]\n"),
            _ => {}
        }
    }
    out
}

fn regular_files(dir: &Path) -> Vec<PathBuf> {
    let mut found = Vec::new();
    let mut stack = vec![dir.to_path_buf()];
    while let Some(d) = stack.pop() {
        let Ok(entries) = fs::read_dir(&d) else { continue };
        for entry in entries.flatten() {
            let Ok(kind) = entry.file_type() else { continue };
            if kind.is_dir() {
                stack.push(entry.path());
            } else if kind.is_file() {
                found.push(entry.path());
            }
        }
    }
    found.sort();
    found
}

pub(crate) fn export(root: &Path, workspace: &Value, home: &Path, out: &Path) -> Result<Value> {
    let subject = member(workspace, "subject")?.to_owned();
    let file = fs::OpenOptions::new().write(true).create_new(true).open(out).map_err(|e| format!("{}: {e}", out.display()))?;
    let mut tar = Tar { out: file, files: Vec::new(), total: 0 };
    let mut world: (Value, Value) = (Value::Null, Value::Null);
    let mut documents = Vec::new();

    let mut names: Vec<String> = fs::read_dir(root.join("refs"))
        .map_err(|e| e.to_string())?
        .flatten()
        .filter_map(|e| e.file_name().to_str().and_then(|f| f.strip_suffix(".json")).map(crate::workspace::ref_name_of_file))
        .collect();
    names.sort();
    for name in &names {
        let reference = match crate::workspace::reference(root, name) {
            Ok(r) => r,
            Err(error) => {
                documents.push(json!({"name": name, "status": "unreadable reference", "error": error}));
                continue;
            }
        };
        let seg = segment(name);
        tar.json(&format!("refs/{seg}.json"), &reference)?;
        match crate::workspace::doc_search::direct(root, workspace, &reference) {
            Ok((view, challenge, rendered, locked)) => {
                let text = text_of(&rendered);
                tar.add(&format!("documents/{seg}.txt"), text.as_bytes())?;
                tar.json(&format!("documents/{seg}.view.json"), &view)?;
                world = (challenge["worldRoot"].clone(), challenge["height"].clone());
                documents.push(json!({"name": name, "status": "read", "target": reference["target"], "lines": rendered.lines.len(),
                    "lockedTextRows": locked, "rootRevision": rendered.root_revision, "worldRoot": challenge["worldRoot"], "height": challenge["height"]}));
            }
            // Not a document this key may read (a capability, a room cell, a revoked grant): the
            // reference stays in refs/, and why it has no text is said.
            Err(error) => documents.push(json!({"name": name, "status": "not read as a document", "error": error})),
        }
    }

    let mut attempts = Vec::new();
    for dir in fs::read_dir(root.join("attempts")).into_iter().flatten().flatten() {
        if !dir.file_type().is_ok_and(|t| t.is_dir()) {
            continue;
        }
        let id = dir.file_name().to_string_lossy().into_owned();
        let standing = match crate::workspace::retained_attempt_outcome(&dir.path()) {
            Ok(crate::workspace::AttemptOutcome::Confirmed(v)) => json!({"standing": "admitted", "outcome": v}),
            Ok(crate::workspace::AttemptOutcome::Charged(v)) => json!({"standing": "charged", "outcome": v}),
            Ok(crate::workspace::AttemptOutcome::Refused) => json!({"standing": "refused"}),
            Ok(crate::workspace::AttemptOutcome::Pending) => json!({"standing": "undecided", "retry": format!("retry {id}")}),
            Err(error) => json!({"standing": "unreadable", "error": error}),
        };
        for file in regular_files(&dir.path()) {
            if fs::metadata(&file).is_ok_and(|m| m.len() <= MAX_FILE) {
                if let (Ok(bytes), Ok(rel)) = (fs::read(&file), file.strip_prefix(root)) {
                    tar.add(&rel.to_string_lossy(), &bytes)?;
                }
            }
        }
        tar.json(&format!("attempts/{}/standing.json", segment(&id)), &standing)?;
        attempts.push(json!({"id": id, "standing": standing["standing"]}));
    }

    for file in regular_files(&home.join("chat")) {
        if fs::metadata(&file).is_ok_and(|m| m.len() <= MAX_FILE) {
            if let (Ok(bytes), Ok(rel)) = (fs::read(&file), file.strip_prefix(home)) {
                tar.add(&format!("rooms/{}", rel.to_string_lossy()), &bytes)?;
            }
        }
    }

    let public = crate::fsio::read_secret_in_private_dir(&member_path(workspace, "key")?)?.verifying_key().to_bytes();
    tar.json("key.json", &json!({"subject": subject, "publicKey": hex(&public),
        "custody": crate::shell::HOSTED_CUSTODY_BANNER,
        "note": "the secret key is not in this archive: it stays in your account's home on the box, which is destroyed with the demo"}))?;

    // The member's research-consent fact (field 1 of `research-consent`: 1 = CC0, 0 = none), as
    // a signed read now; "unrecorded" when the cell is absent or unreadable.
    let consent = crate::workspace::reference(root, "research-consent")
        .ok()
        .and_then(|reference| crate::workspace::signed_view(root, workspace, &reference, "resource").ok())
        .and_then(|(view, _, _)| {
            view["cell"]["entries"].as_array()?.iter().find(|e| e["key"]["field"] == "1")?["value"].as_str().map(str::to_owned)
        });
    let research = match consent.as_deref() {
        Some("1") => "cc0",
        Some("0") => "none",
        _ => "unrecorded",
    };
    let exported_at = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    let manifest = json!({
        "type": "mini-world-export-v1",
        "subject": subject,
        "exportedAt": exported_at,
        "worldRoot": world.0,
        "height": world.1,
        "worldRootIs": "the world root and height the Host reported to the last signed read of this export",
        "researchConsent": research,
        "researchConsentIs": "field 1 of this member's research-consent cell, read now: cc0 (contributed for research, dedicated to the public domain under CC0), none, or unrecorded",
        "coverage": "every reference held; each document as the Host renders it to this key now (text, struck lines omitted) and its signed view; every retained attempt with its standing; the local room state under HOME/chat; the public key; no secret key",
        "documents": documents,
        "attempts": attempts,
        "files": tar.files.clone(),
    });
    tar.json("manifest.json", &manifest)?;
    tar.finish()?;
    Ok(manifest)
}

#[cfg(test)]
mod tests {
    #[test]
    fn a_ustar_header_carries_size_name_and_a_valid_checksum() {
        let h = super::ustar_header("mini-export/documents/a.txt", 5).unwrap();
        assert!(h.starts_with(b"mini-export/documents/a.txt\0"));
        assert_eq!(&h[124..135], b"00000000005");
        assert_eq!(&h[257..262], b"ustar");
        let stored = u32::from_str_radix(std::str::from_utf8(&h[148..154]).unwrap(), 8).unwrap();
        let mut blank = h;
        blank[148..156].copy_from_slice(b"        ");
        assert_eq!(stored, blank.iter().map(|&b| u32::from(b)).sum::<u32>());
        let long = format!("mini-export/attempts/{}/{}", "x".repeat(90), "y".repeat(60));
        let h = super::ustar_header(&long, 0).unwrap();
        assert!(h[345..].starts_with(format!("mini-export/attempts/{}", "x".repeat(90)).as_bytes()));
    }

    #[test]
    fn rendered_text_omits_struck_lines() {
        assert_eq!(super::segment("lab/index"), "lab.index");
    }
}
