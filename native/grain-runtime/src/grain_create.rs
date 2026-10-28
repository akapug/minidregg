//! `grain-runtime create SPEC.json`: birth one member AgentGrain (a parent
//! task and its tool task) on a live Store, delegate the worker its parent
//! witness, initialize the controller-private resource workspace, and write
//! the controller config that `serve` opens. Every signed step goes through
//! the ordinary `mini` client and is admitted by the Lean Host; this command
//! authors no native state itself.
//!
//! Lost replies: each signed step owns a fixed attempt directory under
//! ROOT/create. A rerun with the same spec never resubmits: an attempt whose
//! outcome is absent is resolved with `mini retry --mode lookup`, and only a
//! confirmed outcome lets the next step run. A different spec against an
//! existing ROOT is refused.
use crate::*;

#[derive(Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Key {
    key: PathBuf,
    subject: String,
    /// Genesis keys that commit to no next key need `--no-prerotation`.
    no_prerotation: bool,
}

#[derive(Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Grant {
    kind: String,
    target: String,
    capability: String,
}

#[derive(Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Sponsor {
    key: PathBuf,
    subject: String,
    /// The account capability that pays the births and fees.
    account_capability: String,
    /// Capabilities the birth intent presents (factory observation, account).
    grants: Vec<Grant>,
}

#[derive(Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Template {
    issuer: String,
    owner_budget: String,
    lifetime: String,
}

#[derive(Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Capabilities {
    parent_observe: String,
    parent_control: String,
    tool_observe: String,
    tool_control: String,
}

#[derive(Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Budgets {
    parent: String,
    tool: String,
    witness_max_cost: String,
}

#[derive(Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Worker {
    launcher: PathBuf,
    runtime_root: PathBuf,
    workspace: PathBuf,
    /// `none` (production: provider through the bridge) or `host` (fixture).
    network: String,
    wall_time_seconds: u64,
    reserve: String,
    charge: String,
}

#[derive(Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Charges {
    reserve: String,
    charge: String,
}

/// The provider purse: a third grain owned by its own worker subject, born
/// in the same intent, witnessed by the parent like the tool task. `gateway`
/// carries the providerTask fields the operator chooses (providers table,
/// credential broker, gateway bind, model, reserve, token and byte bounds,
/// onBehalfOf, provider row pin); the identity fields are filled here.
#[derive(Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct ProviderPurse {
    key: Key,
    task: String,
    observe_capability: String,
    control_capability: String,
    budget: String,
    gateway: serde_json::Map<String, Value>,
}

#[derive(Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct Spec {
    #[serde(rename = "type")]
    kind: String,
    mini: PathBuf,
    host: PathBuf,
    host_config: PathBuf,
    host_socket: PathBuf,
    genesis: PathBuf,
    namespace_root: PathBuf,
    root: PathBuf,
    nonce: String,
    sponsor: Sponsor,
    template: Template,
    owner: Key,
    worker_key: Key,
    task: String,
    tool_task: String,
    capabilities: Capabilities,
    budgets: Budgets,
    worker: Worker,
    tool_charges: Charges,
    #[serde(default)]
    provider: Option<ProviderPurse>,
    #[serde(default)]
    room: Option<Value>,
    /// `S`, `M` or `L`: grant upstream Hermes's sandbox toolsets up to the
    /// class bounds (docs/HERMES-TOOLS-2026-10-27.md); absent, none.
    #[serde(default)]
    sandbox: Option<String>,
}

const SPEC_TYPE: &str = "mini-grain-create-v1";

fn canonical_decimal(value: &str, what: &str) -> Result<()> {
    if value.is_empty() || !value.bytes().all(|b| b.is_ascii_digit()) || (value.len() > 1 && value.starts_with('0')) {
        return Err(format!("{what} must be canonical decimal: {value:?}"));
    }
    Ok(())
}

fn absolute(path: &Path, what: &str) -> Result<()> {
    if !path.is_absolute()
        || path.components().any(|c| !matches!(c, std::path::Component::RootDir | std::path::Component::Normal(_)))
    {
        return Err(format!("{what} must be a canonical absolute path: {}", path.display()));
    }
    Ok(())
}

fn executable(path: &Path, what: &str) -> Result<()> {
    absolute(path, what)?;
    let meta = fs::metadata(path).map_err(|e| format!("{what} {}: {e}", path.display()))?;
    if !meta.is_file() || meta.permissions().mode() & 0o111 == 0 {
        return Err(format!("{what} is not an executable file: {}", path.display()));
    }
    Ok(())
}

fn private_key(path: &Path, what: &str) -> Result<()> {
    absolute(path, what)?;
    let meta = fs::symlink_metadata(path).map_err(|e| format!("{what} {}: {e}", path.display()))?;
    if !meta.is_file() || meta.permissions().mode() & 0o077 != 0 || meta.uid() != unsafe { libc::geteuid() } {
        return Err(format!("{what} must be a regular 0600 file owned by this account: {}", path.display()));
    }
    Ok(())
}

fn readable(path: &Path, what: &str) -> Result<()> {
    absolute(path, what)?;
    if !fs::metadata(path).map_err(|e| format!("{what} {}: {e}", path.display()))?.is_file() {
        return Err(format!("{what} is not a regular file: {}", path.display()));
    }
    Ok(())
}

fn directory(path: &Path, what: &str) -> Result<()> {
    absolute(path, what)?;
    if !fs::metadata(path).map_err(|e| format!("{what} {}: {e}", path.display()))?.is_dir() {
        return Err(format!("{what} is not a directory: {}", path.display()));
    }
    Ok(())
}

impl Spec {
    /// Refuse every missing or malformed input before anything is signed.
    fn check(&self, phase: &Phase) -> Result<()> {
        self.check_values()?;
        self.check_paths(phase)
    }

    /// The birth is signed by the operator's sponsor; a resident running as
    /// its own uid never holds that key, so once the birth is confirmed the
    /// sponsor key is no longer asked for.
    fn birth_confirmed(&self) -> Result<bool> {
        confirmed(&self.root.join("create/birth/outcome.json"))
    }

    /// Values only: no filesystem access.
    fn check_values(&self) -> Result<()> {
        if self.kind != SPEC_TYPE {
            return Err(format!("spec type must be {SPEC_TYPE}"));
        }
        for (value, what) in [
            (&self.nonce, "nonce"), (&self.sponsor.subject, "sponsor.subject"),
            (&self.sponsor.account_capability, "sponsor.accountCapability"),
            (&self.template.issuer, "template.issuer"), (&self.template.owner_budget, "template.ownerBudget"),
            (&self.template.lifetime, "template.lifetime"), (&self.owner.subject, "owner.subject"),
            (&self.worker_key.subject, "workerKey.subject"), (&self.task, "task"), (&self.tool_task, "toolTask"),
            (&self.capabilities.parent_observe, "capabilities.parentObserve"),
            (&self.capabilities.parent_control, "capabilities.parentControl"),
            (&self.capabilities.tool_observe, "capabilities.toolObserve"),
            (&self.capabilities.tool_control, "capabilities.toolControl"),
            (&self.budgets.parent, "budgets.parent"), (&self.budgets.tool, "budgets.tool"),
            (&self.budgets.witness_max_cost, "budgets.witnessMaxCost"),
            (&self.worker.reserve, "worker.reserve"), (&self.worker.charge, "worker.charge"),
            (&self.tool_charges.reserve, "toolCharges.reserve"), (&self.tool_charges.charge, "toolCharges.charge"),
        ] {
            canonical_decimal(value, what)?;
        }
        if self.sponsor.grants.is_empty() {
            return Err("sponsor.grants must name the capabilities the birth presents".into());
        }
        for grant in &self.sponsor.grants {
            canonical_decimal(&grant.target, "sponsor.grants[].target")?;
            canonical_decimal(&grant.capability, "sponsor.grants[].capability")?;
            if !matches!(grant.kind.as_str(), "object" | "account") {
                return Err("sponsor.grants[].kind must be object or account".into());
            }
        }
        if let Some(p) = &self.provider {
            for (value, what) in [(&p.key.subject, "provider.key.subject"), (&p.task, "provider.task"),
                (&p.observe_capability, "provider.observeCapability"), (&p.control_capability, "provider.controlCapability"),
                (&p.budget, "provider.budget")] {
                canonical_decimal(value, what)?;
            }
            if [&self.task, &self.tool_task].contains(&&p.task)
                || [&self.owner.subject, &self.worker_key.subject].contains(&&p.key.subject) {
                return Err("provider task and subject must be distinct from the parent and tool".into());
            }
            for owned in ["task", "subject", "capability", "queryCapability", "custodyKey", "parentCapability", "parentObserveCapability"] {
                if p.gateway.contains_key(owned) {
                    return Err(format!("provider.gateway must not set {owned}; create fills it"));
                }
            }
        }
        if self.task == self.tool_task {
            return Err("task and toolTask must differ".into());
        }
        let caps = [&self.capabilities.parent_observe, &self.capabilities.parent_control,
            &self.capabilities.tool_observe, &self.capabilities.tool_control];
        if caps.iter().collect::<std::collections::BTreeSet<_>>().len() != caps.len() {
            return Err("the four capability IDs must be distinct".into());
        }
        if !matches!(self.worker.network.as_str(), "none" | "host") {
            return Err(format!("worker.network must be none or host, not {:?}", self.worker.network));
        }
        if self.worker.wall_time_seconds == 0 || self.worker.wall_time_seconds > 3600 {
            return Err("worker.wallTimeSeconds must be in 1..=3600".into());
        }
        if self.owner.key == self.worker_key.key || self.owner.subject == self.worker_key.subject {
            return Err("owner and worker must be distinct subjects with distinct keys".into());
        }
        if let Some(class) = &self.sandbox {
            crate::sandbox_tools::Sandbox::for_class(class)?;
            if self.worker.network != "none" || self.room.is_none() {
                return Err("sandbox tools need worker.network none and a room".into());
            }
        }
        Ok(())
    }

    fn check_paths(&self, phase: &Phase) -> Result<()> {
        executable(&self.mini, "mini")?;
        executable(&self.host, "host")?;
        readable(&self.host_config, "hostConfig")?;
        absolute(&self.host_socket, "hostSocket")?;
        let live = match phase { Phase::Birth { socket } => socket, Phase::Whole => &self.host_socket };
        if !fs::metadata(live).map(|m| m.file_type().is_socket()).unwrap_or(false) {
            return Err(format!("the Host socket is not a live socket: {}", live.display()));
        }
        readable(&self.genesis, "genesis")?;
        directory(&self.namespace_root, "namespaceRoot")?;
        absolute(&self.root, "root")?;
        // Linux sockaddr_un holds 108 bytes including NUL; the control and
        // admin sockets live in ROOT/state.
        if self.root.join("state/control.sock").as_os_str().len() >= 100 {
            return Err("root is too long for the controller's Unix sockets".into());
        }
        if matches!(phase, Phase::Birth { .. }) || !self.birth_confirmed()? {
            private_key(&self.sponsor.key, "sponsor.key")?;
        }
        if matches!(phase, Phase::Birth { .. }) {
            // The operator's part: everything else belongs to the resident.
            return Ok(());
        }
        private_key(&self.owner.key, "owner.key")?;
        private_key(&self.worker_key.key, "workerKey.key")?;
        if let Some(p) = &self.provider {
            private_key(&p.key.key, "provider.key.key")?;
        }
        executable(&self.worker.launcher, "worker.launcher")?;
        if self.worker.launcher.file_name().and_then(|n| n.to_str()) != Some("bwrap") {
            return Err("worker.launcher must be the bwrap launcher".into());
        }
        directory(&self.worker.runtime_root, "worker.runtimeRoot")?;
        executable(&self.worker.runtime_root.join("hermes-acp"), "worker.runtimeRoot/hermes-acp")?;
        directory(&self.worker.workspace, "worker.workspace")?;
        match self.worker.network.as_str() {
            "none" => {
                if self.provider.is_some() {
                    executable(&self.worker.runtime_root.join("grain-provider-bridge"),
                        "worker.runtimeRoot/grain-provider-bridge (required by --network none with a provider)")?;
                }
            }
            "host" => {
                if self.provider.as_ref().is_some_and(|p| p.gateway.get("localFixtureHostNetwork") != Some(&json!(true))) {
                    return Err("worker.network host is a fixture topology; a provider task then needs localFixtureHostNetwork".into());
                }
            }
            _ => unreachable!("checked in check_values"),
        }
        Ok(())
    }

    fn birth_intent(&self, genesis: &Value) -> Value {
        let mut workers = vec![json!(self.worker_key.subject)];
        let mut resources = vec![
            json!({"kind":"object","storage":"grain","target":self.task,"owner":self.owner.subject,
                "ownerCapability":self.capabilities.parent_observe,"controlCapability":self.capabilities.parent_control,
                "budget":self.budgets.parent,"workerGeneration":"1"}),
            json!({"kind":"object","storage":"grain","target":self.tool_task,"owner":self.worker_key.subject,
                "ownerCapability":self.capabilities.tool_observe,"controlCapability":self.capabilities.tool_control,
                "budget":self.budgets.tool}),
        ];
        if let Some(p) = &self.provider {
            workers.push(json!(p.key.subject));
            resources.push(json!({"kind":"object","storage":"grain","target":p.task,"owner":p.key.subject,
                "ownerCapability":p.observe_capability,"controlCapability":p.control_capability,"budget":p.budget}));
        }
        resources[0]["workerSubjects"] = json!(workers);
        let resources = Value::Array(resources);
        json!({"subject":self.sponsor.subject,"nonce":self.nonce,
            "birth":{"genesis":genesis,
                "template":{"issuer":self.template.issuer,"ownerBudget":self.template.owner_budget,"lifetime":self.template.lifetime},
                "creator":self.sponsor.subject,"nonce":self.nonce,
                "resources":resources,
                "sourceCapabilities":[self.sponsor.account_capability],"funding":[],"feePayer":self.sponsor.subject},
            "grants":self.sponsor.grants})
    }

    fn controller(&self, witness: &str, provider_witness: Option<&str>) -> Value {
        let state = self.root.join("state");
        let mut args = vec![
            "--workspace".to_owned(), self.worker.workspace.display().to_string(),
            "--runtime-root".to_owned(), self.worker.runtime_root.display().to_string(),
            "--network".to_owned(), self.worker.network.clone(),
        ];
        args.extend(["--".to_owned(), "/agent/hermes-acp".to_owned()]);
        let mut tool = json!({"task":self.tool_task,"subject":self.worker_key.subject,
            "capability":self.capabilities.tool_observe,"queryCapability":self.capabilities.tool_observe,
            "custodyKey":self.worker_key.key,"parentCapability":witness,"parentObserveCapability":witness,
            "reserve":self.tool_charges.reserve,"charge":self.tool_charges.charge,"allowedPublications":[],
            "resourceWorkspace":state.join("resource-workspace")});
        if let Some(room) = &self.room {
            tool["room"] = room.clone();
        }
        let mut config = json!({"mini":self.mini,"host":self.host,"hostConfig":self.host_config,
            "hostSocket":self.host_socket,"custodyKey":self.owner.key,"stateDir":state,
            "controlSocket":state.join("control.sock"),"cwd":self.root,"task":self.task,
            "subject":self.owner.subject,"capability":self.capabilities.parent_observe,
            "queryCapability":self.capabilities.parent_observe,
            "policyControlCapability":self.capabilities.parent_control,"toolTask":tool,
            "commands":[{"name":"hermes-acp","program":self.worker.launcher,"args":args,
                "systemdScope":true,"wallTimeSeconds":self.worker.wall_time_seconds,
                "reserve":self.worker.reserve,"charge":self.worker.charge}]});
        if let (Some(provider), Some(witness)) = (&self.provider, provider_witness) {
            let mut task = provider.gateway.clone();
            for (key, value) in [("task", json!(provider.task)), ("subject", json!(provider.key.subject)),
                ("capability", json!(provider.observe_capability)), ("queryCapability", json!(provider.observe_capability)),
                ("custodyKey", json!(provider.key.key)), ("parentCapability", json!(witness)),
                ("parentObserveCapability", json!(witness))] {
                task.insert(key.into(), value);
            }
            config["providerTask"] = Value::Object(task);
        }
        if let Some(class) = &self.sandbox {
            let sandbox = crate::sandbox_tools::Sandbox::for_class(class).expect("sandbox class checked in validate");
            config["sandbox"] = serde_json::to_value(sandbox).expect("sandbox serializes");
        }
        config
    }
}

fn run(command: &mut Command, what: &str) -> Result<Vec<u8>> {
    // A timeout is a lost reply: the signed step is then resolved by lookup.
    let output = deadline::output(command.stdin(Stdio::null()), deadline::NATIVE_CALL)
        .map_err(|e| deadline::describe(what, e))?;
    if !output.status.success() {
        return Err(format!("{what} exited {}: {}", output.status, String::from_utf8_lossy(&output.stderr).trim()));
    }
    Ok(output.stdout)
}

fn confirmed(outcome: &Path) -> Result<bool> {
    let bytes = match fs::read(outcome) {
        Ok(bytes) => bytes,
        Err(e) if e.kind() == io::ErrorKind::NotFound => return Ok(false),
        Err(e) => return Err(format!("{}: {e}", outcome.display())),
    };
    let value: Value = serde_json::from_slice(&bytes).map_err(|e| format!("{}: {e}", outcome.display()))?;
    match value["type"].as_str() {
        Some("confirmed") => Ok(true),
        Some("refused") => Err(format!("the Host refused this step ({}): {}", outcome.display(), value)),
        _ => Ok(false),
    }
}

/// Resolve one signed step. A fresh attempt directory runs `submit`; an
/// existing one without a confirmed outcome is only ever looked up.
fn signed_step(spec: &Spec, attempt: &Path, what: &str, submit: impl FnOnce() -> Result<()>) -> Result<()> {
    signed_step_on(spec, &spec.host_socket, attempt, what, submit)
}

fn signed_step_on(spec: &Spec, socket: &Path, attempt: &Path, what: &str, submit: impl FnOnce() -> Result<()>) -> Result<()> {
    let outcome = attempt.join("outcome.json");
    if !attempt.exists() {
        // A submitter may exit nonzero after the reply was lost; the outcome
        // file and the lookup below decide, not its status.
        if let Err(error) = submit() {
            eprintln!("grain-runtime create: {what}: {error}; resolving by exact lookup");
        }
    }
    if confirmed(&outcome)? {
        return Ok(());
    }
    if !attempt.join("call.bin").exists() {
        return Err(format!("{what}: no signed call was retained at {}; nothing was submitted, remove only that attempt directory after inspecting it", attempt.display()));
    }
    run(Command::new(&spec.mini).arg("retry").arg("--attempt").arg(attempt).args(["--mode", "lookup"])
        .arg("--socket").arg(socket), &format!("{what} lookup"))?;
    if confirmed(&outcome)? {
        return Ok(());
    }
    Err(format!("{what}: undecided after exact lookup; rerun `grain-runtime create` with the same spec to look it up again (attempt {})", attempt.display()))
}

/// How many fresh observe-and-author generations one create tries before it
/// stops and says so; each costs one signed read and one Host authoring, no fee.
const AUTHOR_GENERATIONS: usize = 8;

/// The one object grant in the sponsor's presented grants that observes the
/// factory: it signs the read that authorizes the current-height authoring.
fn factory_grant<'a>(spec: &'a Spec, genesis: &Value) -> Result<(String, &'a Grant)> {
    let factory = match &genesis["factoryId"] {
        Value::String(text) => text.clone(),
        Value::Number(number) => number.to_string(),
        _ => return Err("genesis names no factoryId".into()),
    };
    let mut matching = spec.sponsor.grants.iter().filter(|g| g.kind == "object" && g.target == factory);
    match (matching.next(), matching.next()) {
        (Some(grant), None) => Ok((factory, grant)),
        _ => Err(format!("sponsor.grants must name exactly one object grant on the factory {factory}")),
    }
}

/// Generation directories `g0001`, `g0002`, ...: the newest, or a first one.
fn author_generation(base: &Path, fresh: bool) -> Result<PathBuf> {
    let mut count = 0usize;
    for entry in fs::read_dir(base).map_err(|e| format!("{}: {e}", base.display()))? {
        let name = entry.map_err(|e| e.to_string())?.file_name();
        let name = name.to_str().ok_or("non-UTF-8 birth authoring generation")?;
        let digits = name.strip_prefix('g').filter(|d| d.len() == 4 && d.bytes().all(|b| b.is_ascii_digit()))
            .ok_or_else(|| format!("unknown entry in {}: {name}", base.display()))?;
        count = count.max(digits.parse::<usize>().map_err(|e| e.to_string())?);
    }
    if count == 0 || fresh {
        count += 1;
        fs::DirBuilder::new().mode(0o700).create(base.join(format!("g{count:04}")))
            .map_err(|e| format!("birth authoring generation: {e}"))?;
    }
    Ok(base.join(format!("g{count:04}")))
}

/// The Host authors the birth at the current height (Host op 91, the path
/// `workspace create` takes): its root grants name `notBefore` = the height
/// of the image it authored against and that image's issuer epochs, so a
/// World of any age admits the birth within the template's `birthSlack`, and
/// a provider-routed grain gets its route's policy. The sponsor's signed
/// factory resource read authorizes that authoring against the exact image it
/// read. Nothing here is admitted: the signed birth that follows is the only
/// effect. An authoring the Host refused (the image moved after the read) or
/// a read that did not finish is superseded by a fresh generation.
fn author_birth(spec: &Spec, work: &Path, socket: &Path, source: &Path, genesis: &Value) -> Result<PathBuf> {
    let (factory, grant) = factory_grant(spec, genesis)?;
    let base = work.join("birth-author");
    if !base.exists() {
        fs::DirBuilder::new().mode(0o700).create(&base).map_err(|e| format!("birth authoring: {e}"))?;
    }
    let mut fresh = false;
    let mut last = String::from("no generation ran");
    for _ in 0..AUTHOR_GENERATIONS {
        let generation = author_generation(&base, fresh)?;
        fresh = true;
        let author = generation.join("author");
        let intent = author.join("intent.bin");
        match fs::read(author.join("reply.frame")) {
            // The Host's reply is an intent: finish its local retention.
            Ok(frame) if frame.first() == Some(&91) => {}
            Ok(_) => { last = format!("the Host refused authoring generation {}", generation.display()); continue; }
            Err(e) if e.kind() == io::ErrorKind::NotFound => {}
            Err(e) => return Err(format!("{}: {e}", author.display())),
        }
        let observation = generation.join("observation");
        let signed = observation.join("signed-observation.bin");
        if !signed.is_file() {
            if observation.exists() {
                last = format!("factory read {} did not finish", observation.display());
                continue;
            }
            let query = generation.join("factory-query.json");
            if !query.exists() {
                let mut nonce = [0u8; 8];
                File::open("/dev/urandom").and_then(|mut f| f.read_exact(&mut nonce)).map_err(|e| format!("nonce: {e}"))?;
                write_private_new(&query, json!({"subject":spec.sponsor.subject,"nonce":u64::from_le_bytes(nonce).to_string(),
                    "purpose":{"type":"query","kind":"object","target":factory,"view":"resource"},
                    "grants":[{"kind":"object","target":factory,"capability":grant.capability}]}).to_string().as_bytes())?;
            }
            if let Err(error) = run(Command::new(&spec.mini).arg("query").arg("--host").arg(&spec.host)
                .arg("--config").arg(&spec.host_config).arg("--socket").arg(socket).arg("--key").arg(&spec.sponsor.key)
                .arg("--intent").arg(&query).args(["--view", "resource"]).arg("--dir").arg(&observation), "factory read") {
                last = error;
                continue;
            }
        }
        match run(Command::new(&spec.mini).arg("current-resource-intent").arg("--host").arg(&spec.host)
            .arg("--config").arg(&spec.host_config).arg("--socket").arg(socket).arg("--source").arg(source)
            .arg("--signed-observation").arg(&signed).arg("--dir").arg(&author), "current birth authoring") {
            Ok(_) if intent.is_file() => return Ok(intent),
            Ok(_) => last = format!("current birth authoring left no intent in {}", author.display()),
            Err(error) => last = error,
        }
    }
    Err(format!("grain birth authoring: {AUTHOR_GENERATIONS} generations without an intent; last: {last}"))
}

fn init_workspace(spec: &Spec, key: &Key, dir: &Path) -> Result<()> {
    if dir.join("workspace.json").exists() {
        return Ok(());
    }
    if dir.exists() {
        return Err(format!("a partial workspace exists at {}; inspect it before rerunning", dir.display()));
    }
    let mut command = Command::new(&spec.mini);
    command.args(["workspace", "--action", "init", "--host"]).arg(&spec.host)
        .arg("--config").arg(&spec.host_config).arg("--socket").arg(&spec.host_socket)
        .arg("--key").arg(&key.key).arg("--subject").arg(&key.subject)
        .arg("--namespace-root").arg(&spec.namespace_root).arg("--dir").arg(dir);
    if key.no_prerotation {
        command.arg("--no-prerotation");
    }
    run(&mut command, "workspace init")?;
    Ok(())
}

fn write_private_new(path: &Path, bytes: &[u8]) -> Result<()> {
    let mut file = OpenOptions::new().write(true).create_new(true).mode(0o600).open(path)
        .map_err(|e| format!("{}: {e}", path.display()))?;
    file.write_all(bytes).and_then(|_| file.sync_all()).map_err(|e| format!("{}: {e}", path.display()))
}

/// The owner delegates RECIPIENT observe+mutate on the parent (its witness).
fn delegate_witness(spec: &Spec, work: &Path, owner_ws: &Path, id: &str, recipient: &str) -> Result<String> {
    let proposal = owner_ws.join(format!("proposals/{id}/proposal.json"));
    if !proposal.exists() {
        let request = work.join(format!("{id}-request.json"));
        if !request.exists() {
            write_private_new(&request, json!({"type":"minidregg-workspace-proposal-v1","action":"delegate",
                "name":"parent","recipient":recipient,"verbs":["observe","mutate"],
                "maxCost":spec.budgets.witness_max_cost}).to_string().as_bytes())?;
        }
        run(Command::new(&spec.mini).args(["workspace", "--action", "propose", "--dir"]).arg(owner_ws)
            .arg("--request").arg(&request).args(["--proposal-id", id]), &format!("propose {id}"))?;
    }
    let attempt = owner_ws.join(format!("attempts/{id}"));
    signed_step(spec, &attempt, &format!("{id} delegation"), || {
        run(Command::new(&spec.mini).args(["workspace", "--action", "submit", "--dir"]).arg(owner_ws)
            .arg("--intent").arg(owner_ws.join(format!("proposals/{id}/intent.json")))
            .arg("--attempt").arg(&attempt), &format!("submit {id}")).map(|_| ())
    })?;
    let value: Value = serde_json::from_slice(&fs::read(&proposal).map_err(|e| format!("{id} proposal: {e}"))?)
        .map_err(|e| format!("{id} proposal: {e}"))?;
    let child = value["delegation"]["childCapability"].as_str()
        .ok_or_else(|| format!("{id} proposal names no childCapability"))?.to_owned();
    canonical_decimal(&child, "witness capability")?;
    Ok(child)
}

/// Who runs this create. `Whole` is the ordinary single-account create (and
/// the resident's part once the birth is confirmed). `Birth` is the
/// operator's part for a resident under its own uid: only the sponsor-signed
/// birth, through the operator's own socket; root then gives ROOT to the
/// resident, which runs `Whole` through its own operator route.
pub(crate) enum Phase { Whole, Birth { socket: PathBuf } }

pub(crate) fn create(spec_path: &Path) -> Result<Value> {
    create_phase(spec_path, Phase::Whole)
}

pub(crate) fn create_phase(spec_path: &Path, phase: Phase) -> Result<Value> {
    let spec_bytes = fs::read(spec_path).map_err(|e| format!("spec {}: {e}", spec_path.display()))?;
    let spec: Spec = serde_json::from_slice(&spec_bytes).map_err(|e| format!("spec: {e}"))?;
    spec.check(&phase)?;
    let spec_sha = sha256_bytes(&spec_bytes)?;
    let work = spec.root.join("create");
    // An existing EMPTY root is a fresh one: root pre-creates it for the
    // operator's birth phase in a directory the operator may not write.
    let empty_root = fs::read_dir(&spec.root).is_ok_and(|mut d| d.next().is_none());
    if spec.root.exists() && !empty_root {
        let recorded = fs::read_to_string(work.join("spec.sha256")).map_err(|_| {
            format!("root {} exists and is not a create of this spec; refusing to overwrite retained state", spec.root.display())
        })?;
        if recorded.trim() != spec_sha {
            return Err("root was created from a different spec; refusing".into());
        }
    } else {
        if !empty_root {
            fs::DirBuilder::new().mode(0o700).create(&spec.root).map_err(|e| format!("root: {e}"))?;
        }
        fs::DirBuilder::new().mode(0o700).create(&work).map_err(|e| format!("root/create: {e}"))?;
        write_private_new(&work.join("spec.json"), &spec_bytes)?;
        write_private_new(&work.join("spec.sha256"), format!("{spec_sha}\n").as_bytes())?;
    }

    // 1. The birth: both grains in one sponsor-signed intent.
    let genesis: Value = serde_json::from_slice(&fs::read(&spec.genesis).map_err(|e| format!("genesis: {e}"))?)
        .map_err(|e| format!("genesis: {e}"))?;
    let intent_path = work.join("birth-intent.json");
    if !intent_path.exists() {
        write_private_new(&intent_path, &serde_json::to_vec(&spec.birth_intent(&genesis)).map_err(|e| e.to_string())?)?;
    }
    let birth = work.join("birth");
    let birth_socket = match &phase { Phase::Birth { socket } => socket.clone(), Phase::Whole => spec.host_socket.clone() };
    // An existing birth attempt holds its exact signed call: it is only looked up.
    let authored = if birth.exists() { None } else { Some(author_birth(&spec, &work, &birth_socket, &intent_path, &genesis)?) };
    signed_step_on(&spec, &birth_socket, &birth, "grain birth", || {
        let authored = authored.as_ref().ok_or("grain birth: no authored intent")?;
        run(Command::new(&spec.mini).arg("submit").arg("--host").arg(&spec.host)
            .arg("--config").arg(&spec.host_config).arg("--socket").arg(&birth_socket)
            .arg("--intent").arg(authored).args(["--intent-kind", "binary"])
            .arg("--key").arg(&spec.sponsor.key).arg("--dir").arg(&birth), "mini submit birth").map(|_| ())
    })?;

    if matches!(phase, Phase::Birth { .. }) {
        return Ok(json!({"type":"mini-grain-birth-v1","task":spec.task,"root":spec.root,
            "birthOutcome":birth.join("outcome.json"),
            "next":"give ROOT to the resident account, then run `grain-runtime create SPEC` as the resident"}));
    }

    // 2. The owner delegates the worker its parent witness.
    let owner_ws = work.join("owner-workspace");
    init_workspace(&spec, &spec.owner, &owner_ws)?;
    if !owner_ws.join("refs/parent.json").exists() {
        run(Command::new(&spec.mini).args(["workspace", "--action", "import", "--dir"]).arg(&owner_ws)
            .args(["--name", "parent", "--kind", "object", "--target"]).arg(&spec.task)
            .arg("--observe-capability").arg(&spec.capabilities.parent_observe)
            .arg("--control-capability").arg(&spec.capabilities.parent_control), "import parent")?;
    }
    let witness = delegate_witness(&spec, &work, &owner_ws, "witness", &spec.worker_key.subject)?;
    let provider_witness = match &spec.provider {
        Some(p) => Some(delegate_witness(&spec, &work, &owner_ws, "provider-witness", &p.key.subject)?),
        None => None,
    };

    // 3. The controller's private state and the tool subject's workspace.
    let state = spec.root.join("state");
    if !state.exists() {
        fs::DirBuilder::new().mode(0o700).create(&state).map_err(|e| format!("state: {e}"))?;
    }
    init_workspace(&spec, &spec.worker_key, &state.join("resource-workspace"))?;
    // A room's tools keep their own home inside stateDir (the controller
    // refuses one elsewhere); create makes it, private.
    if let Some(home) = spec.room.as_ref().and_then(|r| r["home"].as_str()).map(PathBuf::from) {
        if home.parent() != Some(state.as_path()) {
            return Err("room.home must be a direct child of ROOT/state".into());
        }
        if !home.exists() {
            fs::DirBuilder::new().mode(0o700).create(&home).map_err(|e| format!("room home: {e}"))?;
        }
    }

    // 4. The controller config, decoded through the controller's own type.
    let config = spec.controller(&witness, provider_witness.as_deref());
    let typed: Config = serde_json::from_value(config.clone()).map_err(|e| format!("controller config refused by its own type: {e}"))?;
    // The same checks `serve` runs at open, so a bad config refuses here.
    crate::validate(&typed).map_err(|e| format!("controller config refused by the controller's validation: {e}"))?;
    let config_path = spec.root.join("controller.json");
    let bytes = serde_json::to_vec_pretty(&typed).map_err(|e| e.to_string())?;
    match fs::read(&config_path) {
        Ok(existing) if existing == bytes => {}
        Ok(_) => return Err(format!("{} exists with different contents; refusing", config_path.display())),
        Err(e) if e.kind() == io::ErrorKind::NotFound => write_private_new(&config_path, &bytes)?,
        Err(e) => return Err(format!("{}: {e}", config_path.display())),
    }
    Ok(json!({"type":"mini-grain-created-v1","task":spec.task,"toolTask":spec.tool_task,
        "owner":spec.owner.subject,"worker":spec.worker_key.subject,"witnessCapability":witness,
        "config":config_path,"configSha256":sha256_bytes(&bytes)?,
        "providerWitnessCapability":provider_witness,"birthOutcome":birth.join("outcome.json"),
        "next":format!("install-controller --config {} ... (user shape) or --system --service-user ACCOUNT (root registration)", config_path.display())}))
}

pub(crate) fn client(args: &[std::ffi::OsString]) -> Result<()> {
    let result = match args {
        [spec] => create(Path::new(spec))?,
        [spec, flag, socket] if flag == "--birth-socket" =>
            create_phase(Path::new(spec), Phase::Birth { socket: PathBuf::from(socket) })?,
        _ => return Err("usage: grain-runtime create /absolute/spec.json [--birth-socket OPERATOR-SOCKET]".into()),
    };
    println!("{result}");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn spec_json() -> Value {
        json!({"type":SPEC_TYPE,"mini":"/m","host":"/h","hostConfig":"/c","hostSocket":"/s","genesis":"/g",
            "namespaceRoot":"/n","root":"/r","nonce":"22000",
            "sponsor":{"key":"/k","subject":"7","accountCapability":"41","grants":[{"kind":"account","target":"7","capability":"41"}]},
            "template":{"issuer":"5","ownerBudget":"100000","lifetime":"10000"},
            "owner":{"key":"/o","subject":"8","noPrerotation":true},
            "workerKey":{"key":"/w","subject":"9","noPrerotation":true},
            "task":"8751","toolTask":"8752",
            "capabilities":{"parentObserve":"8761","parentControl":"8762","toolObserve":"8771","toolControl":"8772"},
            "budgets":{"parent":"100","tool":"50","witnessMaxCost":"50000"},
            "worker":{"launcher":"/l/bwrap","runtimeRoot":"/rt","workspace":"/ws","network":"none",
                "wallTimeSeconds":600,"reserve":"3","charge":"1"},
            "toolCharges":{"reserve":"2","charge":"1"}})
    }

    #[test]
    fn create_spec_refuses_every_missing_field_and_unknown_field() {
        let full = spec_json();
        serde_json::from_value::<Spec>(full.clone()).unwrap();
        for field in full.as_object().unwrap().keys() {
            let mut partial = full.clone();
            partial.as_object_mut().unwrap().remove(field);
            assert!(serde_json::from_value::<Spec>(partial).is_err(), "missing {field} accepted");
        }
        let mut extra = full.clone();
        extra["typo"] = json!(1);
        assert!(serde_json::from_value::<Spec>(extra).is_err());
        let mut nested = full;
        nested["worker"].as_object_mut().unwrap().remove("network");
        assert!(serde_json::from_value::<Spec>(nested).is_err());
    }

    #[test]
    fn create_writes_a_config_the_controller_type_accepts() {
        let spec: Spec = serde_json::from_value(spec_json()).unwrap();
        let config = spec.controller("8790", None);
        let typed: Config = serde_json::from_value(config.clone()).unwrap();
        assert_eq!(typed.task, "8751");
        assert_eq!(config["toolTask"]["parentCapability"], "8790");
        assert_eq!(config["commands"][0]["args"][5], "none");
        assert_eq!(config["controlSocket"], "/r/state/control.sock");
        let intent = spec.birth_intent(&json!({"g":1}));
        assert_eq!(intent["birth"]["resources"][1]["owner"], "9");
        assert_eq!(intent["birth"]["resources"][0]["workerSubjects"], json!(["9"]));
        let mut with = spec_json();
        with["provider"] = json!({"key":{"key":"/p","subject":"10","noPrerotation":true},"task":"8753",
            "observeCapability":"8781","controlCapability":"8782","budget":"50",
            "gateway":{"providers":"/etc/mini/providers.json","credentialBroker":"/etc/mini/keys-client.json",
                "gatewayBind":"127.0.0.1:18761","model":"m","reserve":"30000","maxInputTokens":1000,
                "maxOutputTokens":100,"maxRequestBytes":1048576,"maxResponseBytes":8388608,"timeoutSeconds":600}});
        let spec: Spec = serde_json::from_value(with.clone()).unwrap();
        spec.check_values().unwrap();
        let intent = spec.birth_intent(&json!({}));
        assert_eq!(intent["birth"]["resources"][0]["workerSubjects"], json!(["9", "10"]));
        assert_eq!(intent["birth"]["resources"][2]["owner"], "10");
        let config = spec.controller("8790", Some("8791"));
        assert_eq!(config["providerTask"]["parentCapability"], "8791");
        assert_eq!(config["providerTask"]["subject"], "10");
        serde_json::from_value::<Config>(config).unwrap();
        with["provider"]["gateway"]["task"] = json!("1");
        assert!(serde_json::from_value::<Spec>(with).unwrap().check_values().unwrap_err().contains("must not set task"));
    }

    #[test]
    fn create_check_refuses_bad_values_before_touching_the_filesystem() {
        let mut bad = spec_json();
        bad["task"] = json!("08751");
        let spec: Spec = serde_json::from_value(bad).unwrap();
        assert!(spec.check_values().unwrap_err().contains("task must be canonical"));
        serde_json::from_value::<Spec>(spec_json()).unwrap().check_values().unwrap();
        let mut wrong = spec_json();
        wrong["type"] = json!("other");
        assert!(serde_json::from_value::<Spec>(wrong).unwrap().check_values().unwrap_err().contains("spec type"));
        let mut same = spec_json();
        same["workerKey"]["subject"] = json!("8");
        assert!(serde_json::from_value::<Spec>(same).unwrap().check_values().unwrap_err().contains("distinct"));
        let mut caps = spec_json();
        caps["capabilities"]["toolControl"] = json!("8761");
        assert!(serde_json::from_value::<Spec>(caps).unwrap().check_values().unwrap_err().contains("distinct"));
        let mut net = spec_json();
        net["worker"]["network"] = json!("bridge");
        assert!(serde_json::from_value::<Spec>(net).unwrap().check_values().is_err());
    }

    #[test]
    fn birth_authoring_signs_its_read_with_the_one_factory_grant() {
        let mut with = spec_json();
        with["sponsor"]["grants"] = json!([{"kind":"object","target":"10","capability":"54"},
            {"kind":"account","target":"7","capability":"41"}]);
        let spec: Spec = serde_json::from_value(with.clone()).unwrap();
        let (factory, grant) = factory_grant(&spec, &json!({"factoryId":10})).unwrap();
        assert_eq!((factory.as_str(), grant.capability.as_str()), ("10", "54"));
        assert_eq!(factory_grant(&spec, &json!({"factoryId":"10"})).unwrap().1.capability, "54");
        // No grant on this genesis's factory, or two: refused before any read.
        assert!(factory_grant(&spec, &json!({"factoryId":"11"})).is_err());
        assert!(factory_grant(&spec, &json!({})).is_err());
        with["sponsor"]["grants"][1] = json!({"kind":"object","target":"10","capability":"55"});
        let two: Spec = serde_json::from_value(with).unwrap();
        assert!(factory_grant(&two, &json!({"factoryId":"10"})).is_err());
    }

    #[test]
    fn birth_authoring_generations_resume_the_newest_and_supersede_by_number() {
        let base = std::env::temp_dir().join(format!("grain-author-gen-{}-{}", std::process::id(),
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()));
        fs::create_dir(&base).unwrap();
        assert_eq!(author_generation(&base, false).unwrap(), base.join("g0001"));
        assert_eq!(author_generation(&base, false).unwrap(), base.join("g0001"));
        assert_eq!(author_generation(&base, true).unwrap(), base.join("g0002"));
        assert_eq!(author_generation(&base, false).unwrap(), base.join("g0002"));
        fs::create_dir(base.join("stray")).unwrap();
        assert!(author_generation(&base, false).is_err());
        fs::remove_dir_all(&base).unwrap();
    }
}
