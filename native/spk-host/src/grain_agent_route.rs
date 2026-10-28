//! Operator configuration of the existing source-admitted lifetime API.
//! Registration does not issue a grant or authorize a request. Immutable
//! records select the next resident generation; current resident pins stay put.
use crate::io_context::IoContext;
use super::*;
use crate::agent_api_lifetime_custody_v3::LifetimeCustodyV3;
use std::collections::{BTreeMap, BTreeSet};
use std::os::fd::AsRawFd;

use crate::agent_route_profile::AgentRouteProfile;
const MAX_CUSTODY: u64 = 16 * 1024;
const MAX_REGISTRATION: u64 = 8 * 1024;

#[derive(Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Registration {
    protocol: String,
    name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    replaces: Option<String>,
    signed_api_path: String,
    socket: PathBuf,
    controller_uid: u32,
    custody: PathBuf,
    reverse_socket: PathBuf,
    route_name: String,
    display_name: String,
    preferred_handle: String,
    reverse_timeout_seconds: u64,
    controller_worker_wall_seconds: u64,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Retained {
    registration: Registration,
    custody_hex: String,
}

fn name(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 48
        && value
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
}
fn absolute(path: &Path) -> bool {
    path.to_str().is_some_and(|s| {
        s.starts_with('/')
            && s.len() > 1
            && s[1..]
                .split('/')
                .all(|c| !c.is_empty() && c != "." && c != "..")
            && !s.chars().any(char::is_control)
    })
}
fn shape(r: &Registration, app_uid: u32) -> io::Result<()> {
    if r.protocol != "mini-spk-grain-agent-route-v1"
        || !name(&r.name)
        || r.replaces
            .as_ref()
            .is_some_and(|n| !name(n) || n == &r.name)
        || !name(&r.route_name)
        || r.controller_uid == 0
        || r.controller_uid == app_uid
        || ![&r.socket, &r.reverse_socket, &r.custody]
            .into_iter()
            .all(|p| absolute(p))
        || r.socket == r.reverse_socket
        || r.socket.as_os_str().as_encoded_bytes().len() >= 108
        || r.reverse_socket.as_os_str().as_encoded_bytes().len() >= 108
        || [&r.display_name, &r.preferred_handle]
            .into_iter()
            .any(|s| s.is_empty() || s.len() > 256 || s.chars().any(char::is_control))
        || !(60..=1740).contains(&r.reverse_timeout_seconds)
        || !(120..=1800).contains(&r.controller_worker_wall_seconds)
        || r.reverse_timeout_seconds > r.controller_worker_wall_seconds - 60
        || minidregg_signed_api_path::checked_prefix(&r.signed_api_path).is_err()
    {
        return Err(invalid("operator lifetime route shape refused"));
    }
    Ok(())
}
fn custody(bytes: &[u8], app: &str) -> io::Result<LifetimeCustodyV3> {
    if bytes.is_empty() || bytes.len() as u64 > MAX_CUSTODY {
        return Err(invalid("lifetime custody exceeds bound"));
    }
    let c: LifetimeCustodyV3 = serde_json::from_slice(bytes)?;
    c.validate()?;
    if c.lineage.app_resource != app {
        return Err(invalid("lifetime custody names another application"));
    }
    Ok(c)
}
fn decode(r: &Retained) -> io::Result<Vec<u8>> {
    if r.custody_hex.len() as u64 > 2 * MAX_CUSTODY
        || !crate::canonical::lower_hex(&r.custody_hex)
    {
        return Err(invalid("retained lifetime custody encoding refused"));
    }
    r.custody_hex
        .as_bytes()
        .chunks_exact(2)
        .map(|p| {
            u8::from_str_radix(std::str::from_utf8(p).unwrap(), 16)
                .map_err(|_| invalid("retained custody hex refused"))
        })
        .collect()
}
fn protected_parent(path: &Path, app_uid: u32) -> io::Result<()> {
    crate::sandbox::open_protected_directory(
        path.parent()
            .ok_or_else(|| invalid("route parent absent"))?,
        app_uid,
        false,
    )?;
    Ok(())
}

/// Serializes route publication with the resident-config snapshot, not with
/// the long-running native START. No manager or source admission occurs here.
pub(super) fn lock(app_dir: &Path) -> io::Result<File> {
    private_dir(app_dir)?;
    let f = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .mode(0o600)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(app_dir.join(".agent-routes.lock")).ctx("open", &(app_dir.join(".agent-routes.lock")))?;
    let m = f.metadata()?;
    if !m.is_file()
        || m.nlink() != 1
        || m.uid() != unsafe { libc::geteuid() }
        || m.mode() & 0o777 != 0o600
    {
        return Err(invalid("agent route lock custody refused"));
    }
    if unsafe { libc::flock(f.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(f)
}
fn retained(app_dir: &Path, app: &str, app_uid: u32, policy: AgentRouteProfile) -> io::Result<BTreeMap<String, Retained>> {
    let root = app_dir.join("agent-routes");
    if !exists(&root)? {
        return Ok(BTreeMap::new());
    }
    private_dir(&root)?;
    let mut records = BTreeMap::new();
    let mut history_bytes = 0u64;
    for (index, entry) in fs::read_dir(&root).ctx("list", &root)?.enumerate() {
        if index >= policy.revisions() {
            return Err(invalid("agent route revision bound exceeded"));
        }
        let path = entry?.path();
        let bytes = read_private(&path, MAX_JSON)?;
        history_bytes += bytes.len() as u64;
        if history_bytes > policy.history_bytes() {
            return Err(invalid("agent route history byte budget exceeded"));
        }
        let r: Retained = serde_json::from_slice(&bytes)?;
        shape(&r.registration, app_uid)?;
        if path.file_name().and_then(|p| p.to_str())
            != Some(&format!("{}.json", r.registration.name))
        {
            return Err(invalid("agent route filename differs from registration"));
        }
        custody(&decode(&r)?, app)?;
        if records.insert(r.registration.name.clone(), r).is_some() {
            return Err(invalid("duplicate agent route name"));
        }
    }
    Ok(records)
}
fn selected(records: &BTreeMap<String, Retained>, policy: AgentRouteProfile) -> io::Result<Vec<&Retained>> {
    let mut replaced = BTreeSet::new();
    for r in records.values() {
        if let Some(old) = &r.registration.replaces {
            if !records.contains_key(old) || !replaced.insert(old) {
                return Err(invalid("agent route replacement absent or forked"));
            }
        }
        let mut seen = BTreeSet::new();
        let mut cursor = Some(r.registration.name.as_str());
        while let Some(n) = cursor {
            if !seen.insert(n) {
                return Err(invalid("agent route replacement cycle"));
            }
            cursor = records
                .get(n)
                .and_then(|r| r.registration.replaces.as_deref());
        }
    }
    let active: Vec<_> = records
        .values()
        .filter(|r| !replaced.contains(&r.registration.name))
        .collect();
    if active.len() > policy.active() {
        return Err(invalid("active lifetime route bound exceeded"));
    }
    for (i, r) in active.iter().enumerate() {
        let a = &r.registration;
        if active[..i].iter().any(|prior| {
            let b = &prior.registration;
            a.socket == b.socket
                || a.reverse_socket == b.reverse_socket
                || a.controller_uid == b.controller_uid
                || a.route_name == b.route_name
                || a.socket.parent() == b.socket.parent()
        }) {
            return Err(invalid("active lifetime transport route duplicated"));
        }
    }
    Ok(active)
}
fn signed_path(placement: &Placement) -> io::Result<String> {
    let package = verify_installed_spk(&placement_image_dir(placement)?, placement.app_uid)?;
    if package.raw_sha256 != placement.raw_sha256 {
        return Err(invalid("lifetime route package pin differs"));
    }
    let bytes = package
        .signed_bridge_config
        .as_deref()
        .ok_or_else(|| invalid("signed API bridge absent"))?;
    minidregg_spk_rpc::decode_bridge_config(bytes)
        .map_err(io::Error::other)?
        .api_path
        .ok_or_else(|| invalid("signed application has no API path"))
}
fn physical(r: &Registration, c: &LifetimeCustodyV3, app_uid: u32) -> io::Result<()> {
    protected_parent(&r.socket, app_uid)?;
    protected_parent(&r.reverse_socket, app_uid)?;
    for pin in c.app_signers.iter().chain(std::iter::once(&c.grant_signer)) {
        protected_parent(&pin.seed_path, app_uid)?;
        read_private(&pin.seed_path, 4096)?;
        let key = crate::dispatch_author::private_signing_key(&pin.seed_path)?;
        let public: String = key
            .verifying_key()
            .to_bytes()
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect();
        if public != pin.public_key_hex {
            return Err(invalid(
                "agent route signing key differs from pinned public key",
            ));
        }
    }
    Ok(())
}

fn binding(c: &LifetimeCustodyV3, placement: &Placement, app: &str) -> io::Result<()> {
    if placement.selector.app != app
        || c.lineage.app_resource != app
        || c.package_manifest != placement.selector.package_manifest
        || c.snapshot_manifest != placement.selector.snapshot_manifest
    {
        return Err(invalid(
            "agent route differs from installed application manifests",
        ));
    }
    Ok(())
}

pub(super) fn register(host: &Host, app: &str, request: &Path) -> io::Result<Value> {
    if !broker::decimal(app) {
        return Err(invalid("agent route app is not decimal"));
    }
    let app_dir = host.app_dir(app);
    let _lock = lock(&app_dir)?;
    let placement = load_placement(&app_dir.join("placement.json"))?;
    protected_parent(request, placement.app_uid)?;
    let r: Registration = serde_json::from_slice(&read_private(request, MAX_REGISTRATION)?)?;
    shape(&r, placement.app_uid)?;
    protected_parent(&r.custody, placement.app_uid)?;
    let bytes = read_private(&r.custody, MAX_CUSTODY)?;
    let c = custody(&bytes, app)?;
    binding(&c, &placement, app)?;
    physical(&r, &c, placement.app_uid)?;
    if r.signed_api_path != signed_path(&placement)? {
        return Err(invalid("agent route differs from signed API path"));
    }
    let policy = host.profile.agent_route_profile.unwrap_or_default();
    let mut records = retained(&app_dir, app, placement.app_uid, policy)?;
    if records.len() >= policy.revisions() || records.contains_key(&r.name) {
        return Err(invalid(
            "agent route name already registered or revision bound exceeded",
        ));
    }
    if let Some(old) = &r.replaces {
        if !selected(&records, policy)?
            .iter()
            .any(|p| &p.registration.name == old)
        {
            return Err(invalid("replacement must name a selected agent route"));
        }
    }
    let name = r.name.clone();
    records.insert(
        name.clone(),
        Retained {
            registration: r,
            custody_hex: bytes.iter().map(|b| format!("{b:02x}")).collect(),
        },
    );
    authority_coordinates(&selected(&records, policy)?, app)?;
    let root = app_dir.join("agent-routes");
    private_directory(&root)?;
    let record = root.join(format!("{name}.json"));
    // One atomic private record includes the exact custody bytes. No caller's
    // mutable custody file is dereferenced by a later resident generation.
    derived_file(&record, &serde_json::to_vec_pretty(&records[&name])?)?;
    Ok(
        json!({"protocol":"mini-spk-grain-agent-route-registered-v1","app":app,"name":name,
        "registration":record,"activation":"next-resident-generation","grantIssued":false}),
    )
}

pub(super) fn configs(
    app_dir: &Path,
    app: &str,
    placement: &Placement,
    journal: &Path,
    policy: AgentRouteProfile,
) -> io::Result<Vec<Value>> {
    let records = retained(app_dir, app, placement.app_uid, policy)?;
    let active = selected(&records, policy)?;
    if active.is_empty() {
        return Ok(vec![]);
    }
    authority_coordinates(&active, app)?;
    let path = signed_path(placement)?;
    let mut out = vec![];
    for record in active {
        let r = &record.registration;
        if r.signed_api_path != path {
            return Err(invalid(
                "registered agent path differs from current signed package",
            ));
        }
        let bytes = decode(record)?;
        let c = custody(&bytes, app)?;
        binding(&c, placement, app)?;
        physical(r, &c, placement.app_uid)?;
        let custody = journal.join(format!("agent-{}-custody.json", r.name));
        let attempt = journal.join(format!("agent-{}-attempts", r.name));
        derived_file(&custody, &bytes)?;
        private_directory(&attempt)?;
        out.push(json!({"protocol":"mini-spk-agent-api-v3","socket":r.socket,"controllerUid":r.controller_uid,
            "custody":custody,"reverseSocket":r.reverse_socket,"routeName":r.route_name,
            "attemptDir":attempt,"displayName":r.display_name,"preferredHandle":r.preferred_handle,
            "reverseTimeoutSeconds":r.reverse_timeout_seconds,"controllerWorkerWallSeconds":r.controller_worker_wall_seconds}));
    }
    Ok(out)
}

fn authority_coordinates(active: &[&Retained], app: &str) -> io::Result<()> {
    let mut seen = BTreeSet::new();
    for record in active {
        let c = custody(&decode(record)?, app)?;
        for (kind, value) in [
            ("session", c.lineage.session_resource),
            ("ticket", c.lineage.ticket_resource),
            ("parent", c.lineage.parent_task),
            ("purse", c.lineage.purse_task),
        ] {
            if !seen.insert((kind, value)) {
                return Err(invalid("selected lifetime authority route duplicated"));
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::symlink;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn registration(n: &str, replaces: Option<&str>) -> Registration {
        Registration {
            protocol: "mini-spk-grain-agent-route-v1".into(),
            name: n.into(),
            replaces: replaces.map(str::to_owned),
            signed_api_path: "/".into(),
            socket: format!("/operator/{n}/api.sock").into(),
            controller_uid: 1001,
            custody: "/operator/custody.json".into(),
            reverse_socket: format!("/operator/reverse-{n}/rpc.sock").into(),
            route_name: n.into(),
            display_name: "Oracle".into(),
            preferred_handle: "oracle".into(),
            reverse_timeout_seconds: 120,
            controller_worker_wall_seconds: 180,
        }
    }
    fn custody_bytes() -> Vec<u8> {
        serde_json::to_vec(&json!({
            "protocol":"mini-spk-agent-lifetime-custody-v3",
            "lineage":{
                "appResource":"800","sessionResource":"801","participantSubject":"8","ticketResource":"802",
                "originalParentTask":"700","originalParentGeneration":"1","originalIssueIndex":"2",
                "originalIssueReceipt":{"transactionId":"11","eventId":"12","acceptedCount":"3","worldRoot":"13"},
                "originalDescriptorSha256":"ab".repeat(32),"grantResource":"803","grantIssueIndex":"3",
                "grantDigest":"123","grantInitializedRoot":"456",
                "grantIssueReceipt":{"transactionId":"21","eventId":"22","acceptedCount":"4","worldRoot":"23"},
                "parentTask":"700","purseTask":"701"
            },
            "packageManifest":"10","snapshotManifest":"11","sessionObserveCapability":"12",
            "manifestObserveCapability":"13","enrollmentObserveCapability":"14","parentCapability":"15",
            "parentObserve":"16","purseCapability":"17","purseObserve":"18","grantObserveCapability":"19",
            "payerSubject":"20","reserveAmount":"100","maximumCharge":"10",
            "appSigners":[{"role":"1","index":"0","keyId":"2","keyEpoch":"3","publicKeyHex":"cd".repeat(32),"seedPath":"/operator/app.seed"}],
            "grantSigner":{"role":"2","index":"0","keyId":"4","keyEpoch":"5","publicKeyHex":"ab".repeat(32),"seedPath":"/operator/grant.seed"},
            "payerPins":[{"role":"4","index":"0","keyId":"5","keyEpoch":"6","publicKeyHex":"ef".repeat(32)}]
        })).unwrap()
    }
    fn record(n: &str, replaces: Option<&str>) -> Retained {
        Retained {
            registration: registration(n, replaces),
            custody_hex: custody_bytes().iter().map(|b| format!("{b:02x}")).collect(),
        }
    }
    fn records(items: &[(&str, Option<&str>)]) -> BTreeMap<String, Retained> {
        items
            .iter()
            .map(|(n, old)| ((*n).into(), record(n, *old)))
            .collect()
    }
    struct Fixture(PathBuf);
    impl Fixture {
        fn new() -> Self {
            let path = std::env::temp_dir().join(format!(
                "mini-agent-route-{}-{}",
                std::process::id(),
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            private_directory(&path).unwrap();
            Self(path)
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            fs::remove_dir_all(&self.0).unwrap();
        }
    }

    #[test]
    fn agent_route_shape_rejects_authority_and_noncanonical_paths() {
        let good = registration("oracle", None);
        shape(&good, 100000).unwrap();
        let mut unknown = serde_json::to_value(&good).unwrap();
        unknown["admitted"] = json!(true);
        assert!(serde_json::from_value::<Registration>(unknown).is_err());
        for path in [
            "relative",
            "/operator/../api.sock",
            "/operator/./api.sock",
            "/operator//api.sock",
            "/operator/api.sock/",
        ] {
            let mut bad = good.clone();
            bad.socket = path.into();
            assert!(shape(&bad, 100000).is_err(), "{path}");
        }
        for uid in [0, 100000] {
            let mut bad = good.clone();
            bad.controller_uid = uid;
            assert!(shape(&bad, 100000).is_err());
        }
        let mut bad = good.clone();
        bad.replaces = Some(bad.name.clone());
        assert!(shape(&bad, 100000).is_err());
        let mut bad = good.clone();
        bad.reverse_timeout_seconds = 121;
        assert!(shape(&bad, 100000).is_err());
        let mut bad = good;
        bad.signed_api_path = "/api//".into();
        assert!(shape(&bad, 100000).is_err());
    }

    #[test]
    fn agent_route_successor_preserves_old_bytes_and_rejects_forks_cycles() {
        let mut all = records(&[("one", None)]);
        let original = serde_json::to_vec(&all["one"]).unwrap();
        all.insert("two".into(), record("two", Some("one")));
        assert_eq!(selected(&all, AgentRouteProfile::Standard).unwrap()[0].registration.name, "two");
        assert_eq!(serde_json::to_vec(&all["one"]).unwrap(), original);
        all.insert("three".into(), record("three", Some("one")));
        assert!(selected(&all, AgentRouteProfile::Standard).is_err());
        assert!(selected(&records(&[("one", Some("missing"))]), AgentRouteProfile::Standard).is_err());
        assert!(selected(&records(&[("one", Some("two")), ("two", Some("one"))]), AgentRouteProfile::Standard).is_err());
    }

    #[test]
    fn agent_route_parallel_routes_refuse_duplicate_transport_and_authority() {
        let mut all = records(&[("one", None), ("two", None)]);
        assert!(selected(&all, AgentRouteProfile::Standard).is_err()); // Same controller identity.
        all.get_mut("two").unwrap().registration.controller_uid = 1002;
        let active = selected(&all, AgentRouteProfile::Standard).unwrap();
        assert_eq!(active.len(), 2);
        assert!(authority_coordinates(&active, "800").is_err()); // Same session/ticket/purses.
        let second = &mut all.get_mut("two").unwrap().registration;
        second.socket = "/operator/one/api.sock".into();
        assert!(selected(&all, AgentRouteProfile::Standard).is_err());
    }

    #[test]
    fn agent_route_custody_is_exact_and_bound_to_the_app() {
        let r = record("one", None);
        assert_eq!(decode(&r).unwrap(), custody_bytes());
        custody(&decode(&r).unwrap(), "800").unwrap();
        assert!(custody(&decode(&r).unwrap(), "801").is_err());
        let mut bad = record("one", None);
        bad.custody_hex.push('a');
        assert!(decode(&bad).is_err());
        let mut bad = record("one", None);
        bad.custody_hex = "AA".into();
        assert!(decode(&bad).is_err());
        let mut value: Value = serde_json::from_slice(&custody_bytes()).unwrap();
        value["lineage"]["parentTask"] = json!("999");
        assert!(custody(&serde_json::to_vec(&value).unwrap(), "800").is_err());
    }

    #[test]
    fn agent_route_retention_refuses_rewrite_symlink_and_public_custody() {
        let f = Fixture::new();
        let _lock = lock(&f.0).unwrap();
        let dir = f.0.join("agent-routes");
        private_directory(&dir).unwrap();
        let path = dir.join("one.json");
        let bytes = serde_json::to_vec(&record("one", None)).unwrap();
        derived_file(&path, &bytes).unwrap();
        assert_eq!(retained(&f.0, "800", 100000, AgentRouteProfile::Standard).unwrap().len(), 1);
        assert!(derived_file(&path, b"replacement").is_err());
        assert_eq!(read_private(&path, MAX_JSON).unwrap(), bytes);
        fs::set_permissions(&path, fs::Permissions::from_mode(0o644)).unwrap();
        assert!(retained(&f.0, "800", 100000, AgentRouteProfile::Standard).is_err());
        fs::set_permissions(&path, fs::Permissions::from_mode(0o600)).unwrap();
        let external = f.0.join("source.json");
        fs::rename(&path, &external).unwrap();
        symlink(&external, &path).unwrap();
        assert!(retained(&f.0, "800", 100000, AgentRouteProfile::Standard).is_err());
    }

    fn placement() -> Placement {
        serde_json::from_value(json!({
            "protocol":"mini-spk-grain-placement-v2",
            "selector":{"app":"800","packageManifest":"10","snapshotManifest":"11","appCapability":"1",
                "appObserveCapability":"2","packageCapability":"3","packageObserveCapability":"4"},
            "rawSha256":"a".repeat(64),"appUid":100000,"appGid":100000,"volumeResource":"800","volumeMib":512,"class":"S"
        })).unwrap()
    }

    #[test]
    fn agent_route_default_empty_does_not_require_an_api_package() {
        let f = Fixture::new();
        assert!(configs(&f.0, "800", &placement(), &f.0.join("g2"))
            .unwrap()
            .is_empty());
    }

    #[test]
    fn agent_route_rechecks_placement_and_manifest_binding() {
        let c = custody(&custody_bytes(), "800").unwrap();
        let mut p = placement();
        binding(&c, &p, "800").unwrap();
        assert!(binding(&c, &p, "801").is_err());
        p.selector.app = "801".into();
        assert!(binding(&c, &p, "800").is_err());
        p = placement();
        p.selector.package_manifest = "999".into();
        assert!(binding(&c, &p, "800").is_err());
        p = placement();
        p.selector.snapshot_manifest = "999".into();
        assert!(binding(&c, &p, "800").is_err());
    }

    #[test]
    fn shared_agent_route_profile_accepts_dozen_controllers_without_weakening_isolation() {
        let mut all = BTreeMap::new();
        for i in 0..64 {
            let n = format!("shared-{i}");
            let mut r = record(&n, None);
            r.registration.controller_uid = 1001 + i;
            let mut c: Value = serde_json::from_slice(&decode(&r).unwrap()).unwrap();
            for (offset, field) in ["sessionResource", "ticketResource", "parentTask", "purseTask"].into_iter().enumerate() {
                c["lineage"][field] = json!((10_000 + i as usize * 10 + offset).to_string());
            }
            c["lineage"]["originalParentTask"] = c["lineage"]["parentTask"].clone();
            r.custody_hex = serde_json::to_vec(&c).unwrap().iter().map(|b| format!("{b:02x}")).collect();
            all.insert(n, r);
        }
        assert!(selected(&all, AgentRouteProfile::Standard).is_err());
        assert_eq!(selected(&all, AgentRouteProfile::Shared64).unwrap().len(), 64);
        authority_coordinates(&selected(&all, AgentRouteProfile::Shared64).unwrap(), "800").unwrap();
        all.get_mut("shared-1").unwrap().registration.controller_uid = 1001;
        assert!(selected(&all, AgentRouteProfile::Shared64).is_err());
        all.get_mut("shared-1").unwrap().registration.controller_uid = 1002;
        let mut extra = record("extra", None);
        extra.registration.controller_uid = 2000;
        all.insert("extra".into(), extra);
        assert!(selected(&all, AgentRouteProfile::Shared64).is_err());
    }

    #[test]
    fn agent_route_active_and_revision_counts_are_bounded() {
        let mut all = BTreeMap::new();
        for i in 0..=AgentRouteProfile::Standard.active() {
            let n = format!("route-{i}");
            let mut r = record(&n, None);
            r.registration.controller_uid = 1001 + i as u32;
            all.insert(n, r);
        }
        assert!(selected(&all, AgentRouteProfile::Standard).is_err());
        let f = Fixture::new();
        let dir = f.0.join("agent-routes");
        private_directory(&dir).unwrap();
        for i in 0..=AgentRouteProfile::Standard.revisions() {
            let n = format!("revision-{i}");
            derived_file(
                &dir.join(format!("{n}.json")),
                &serde_json::to_vec(&record(&n, None)).unwrap(),
            )
            .unwrap();
        }
        assert!(retained(&f.0, "800", 100000, AgentRouteProfile::Standard)
            .err()
            .unwrap()
            .to_string()
            .contains("bound"));
    }
}
