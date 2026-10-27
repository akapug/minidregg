//! `mini bend` — author an Objective Bend (`.obend`) program and run it in the kernel.
//!
//! A bend turn IS an activity turn (`activity.rs`, Host ops 7 author / 210 plan / 211 assemble /
//! 212 submit / 213 lookup / 214 view): this verb only builds the turn bodies, the workspace key
//! signs through `activity::submit`, and the retained-ingress / exact-retry machinery is that
//! file's, unchanged. Everything lives under `WS/bend/`:
//!
//! ```text
//! WS/bend/NAME/spec.json            the package-input spec handed to the Host's front end
//! WS/bend/NAME/source/MODULE.obend  the source the spec names (a copy of the member's @FILE)
//! WS/bend/NAME/out/                 the Host's artifact.bin, package.bin, publication.json
//! WS/bend/NAME/attempts/…           one activity attempt directory per submitted turn
//! WS/bend/objects/REF.json          which bend an object runs and its birth transaction
//! ```
//!
//! * `mini bend --action publish --dir WS --name NAME --source FILE [--entry DEF] [--account REF]`
//!   runs the workspace's Host `objective-publication SPEC activity OUT` (the Host's own Lean front
//!   end captures and lowers the source; a refusal is printed as the Host's, nothing submitted),
//!   then submits the `publish` turn paid from the member's own account and spend capability.
//! * `mini bend --action run --dir WS --name NAME --object REF [--seed JSON] [--input JSON]
//!   [--deposit N] [--state-type JSON] [--account REF]` creates the object pinning the published
//!   package (when REF has no record yet), then births its activity under a full envelope.
//! * `mini bend --action show --dir WS --object REF` reads the object back (a public view, op 214).
//!
//! The Host publishes ONE envelope figure (`limits.extractTicks`) and the front end's quote of the
//! package (`pins[].frontEnd`); both are read from the view. The five other fixed envelope figures
//! and the tariff are the Objective invocation policy's every genesis pins
//! (`activity_world.policy_of`, `scripts/author-objective-policy.sh`); the Host does not publish them,
//! so they are mirrored below and tied to `activity_world.py` by `policy_mirror_matches_the_world`.
use crate::activity::{self, Ws};
use crate::agent_reserve::field;
use crate::*;
use serde_json::{json, Value};

/// The policy's maximum envelope, member by member (`activity_world.MAXIMUM`), in its order.
const ENVELOPE_KEYS: [&str; 22] = [
    "typeFuel", "sourceTicks", "heap", "stack", "outputNodes", "outputBytes", "extractTicks", "inputBytes",
    "scalarBits", "memoryTouches", "proofWork", "feeDebit", "turnBytes", "witnessBytes", "storageBytes",
    "sideEffectCount", "networkBytes", "leaseByteBlocks", "incidences", "replayBytes", "coreBytes", "domainWork",
];
/// The fixed members a full envelope declares at the policy maximum (`activity_world.cap`).
const FIXED: [(&str, u64); 5] =
    [("heap", 200000), ("stack", 200000), ("typeFuel", 16384), ("outputNodes", 20000), ("outputBytes", 200000)];
/// Tariff edition 4 (`activity_world.TARIFF`): base, source tick, replay byte, core byte.
const BASE: u128 = 1;
const TICK_RATE: u128 = 1;
const REPLAY_RATE: u128 = 61;
const CORE_RATE: u128 = 16;
/// The source ticks a bend's birth declares (`activity_world.TICKS`) and the multiple of its price the
/// default deposit reserves (the activity acceptance's `DEPOSIT`: comfortably the first await).
const TICKS: u128 = 3000;
const DEPOSIT_PRICES: u128 = 7;
/// The declared state type `{total: Nat}` (the checker's type JSON) `Tally` and its siblings keep.
const TOTAL_STATE: &str = r#"{"tag":"field","name":"total","member":{"tag":"natural"},"tail":{"tag":"emptyRow"}}"#;

fn name_ok(name: &str) -> Result<()> {
    if name.is_empty() || name.len() > 64 || !name.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-') {
        return Err(format!("bend: `{name}` is not a bend name (1..64 ASCII letters, digits or hyphens)"));
    }
    Ok(())
}

fn text(args: &mut Args, name: &str) -> Result<String> {
    args.required(name)?.into_string().map_err(|_| format!("--{name} must be UTF-8"))
}

fn opt(args: &mut Args, name: &str) -> Result<Option<String>> {
    args.optional(name).map(|v| v.into_string().map_err(|_| format!("--{name} must be UTF-8"))).transpose()
}

fn json_flag(args: &mut Args, name: &str) -> Result<Option<Value>> {
    opt(args, name)?
        .map(|t| serde_json::from_str(&t).map_err(|e| format!("bend: --{name} is not JSON: {e}")))
        .transpose()
}

// ------------------------------------------------------------------ pure turn bodies

/// The package-input spec the Host's front end captures (`activity_world.publication`): one module,
/// named for its file, no imports; the entry is a definition of that module.
fn package_input(module: &str, source: &Path, entry: &str) -> Value {
    json!({"schema": "dregg.objective-bend.package-input.v1", "edition": "objective-bend-1",
           "modules": [{"name": module, "sourcePath": source, "imports": []}],
           "entryModule": "0", "entryDefinition": entry})
}

/// The price of a declared envelope (`Tariff.workOf`) of `ticks` source ticks and the front end's quote.
fn price(ticks: u128, replay: u128, core: u128) -> u128 {
    BASE + TICK_RATE * ticks + REPLAY_RATE * replay + CORE_RATE * core
}

/// A full envelope (`activity_world.cap`): the policy's fixed members, the extraction budget the Host
/// publishes, the front end's quote of the package, and `ticks` source ticks.
fn envelope(extract: u128, replay: u128, core: u128, ticks: u128) -> Value {
    let mut c: serde_json::Map<String, Value> = ENVELOPE_KEYS.iter().map(|k| ((*k).to_owned(), json!("0"))).collect();
    for (k, v) in FIXED {
        c.insert(k.into(), json!(v.to_string()));
    }
    c.insert("extractTicks".into(), json!(extract.to_string()));
    c.insert("replayBytes".into(), json!(replay.to_string()));
    c.insert("coreBytes".into(), json!(core.to_string()));
    c.insert("sourceTicks".into(), json!(ticks.to_string()));
    Value::Object(c)
}

fn publish_turn(artifact: &str, package: &str, payer: &str, payer_cap: &str) -> Value {
    json!({"kind": "publish", "artifact": artifact, "package": package, "payer": payer, "payerCapability": payer_cap})
}

fn create_turn(object: &str, object_cap: &str, pin: &str, state_type: &Value, seed: Option<&Value>, payer: &str, payer_cap: &str) -> Value {
    let mut turn = json!({"kind": "create", "object": object, "objectCapability": object_cap, "pin": pin,
        "stateType": state_type, "law": {"type": "all", "predicates": []}, "upgrade": {"frozen": {}},
        "payer": payer, "payerCapability": payer_cap});
    if let Some(seed) = seed {
        turn["seed"] = seed.clone();
    }
    turn
}

#[allow(clippy::too_many_arguments)]
fn birth_turn(object: &str, object_cap: &str, account: &str, account_cap: &str, pin: &str, input: &Value, envelope: &Value, deposit: u128) -> Value {
    json!({"kind": "birth", "object": object, "objectCapability": object_cap, "account": account,
        "accountCapability": account_cap, "pin": pin, "input": input,
        "envelope": envelope, "resume": envelope, "timeout": envelope, "deposit": deposit.to_string()})
}

/// What `Tally` starts from: `{init: set 0, decider: SUBJECT}` (the member answers their own awaits).
/// Any other program names its input with `--input`.
fn default_input(subject: &str) -> Value {
    json!({"tag": "record", "fields": [
        {"name": "init", "value": {"tag": "variant", "label": "set", "payload": {"tag": "natural", "value": "0"}}},
        {"name": "decider", "value": {"tag": "natural", "value": subject}}]})
}

/// A data value, as the member reads it: `3`, `{total=3}`, `set(0)`; anything else compact JSON.
fn data_text(v: &Value) -> String {
    match v.get("tag").and_then(Value::as_str) {
        Some("natural") => v.get("value").and_then(Value::as_str).unwrap_or("?").to_owned(),
        Some("record") => format!("{{{}}}", v.get("fields").and_then(Value::as_array).map(|fs| fs.iter()
            .map(|f| format!("{}={}", f.get("name").and_then(Value::as_str).unwrap_or("?"), data_text(f.get("value").unwrap_or(&Value::Null))))
            .collect::<Vec<_>>().join(", ")).unwrap_or_default()),
        Some("variant") => format!("{}({})", v.get("label").and_then(Value::as_str).unwrap_or("?"),
            data_text(v.get("payload").unwrap_or(&Value::Null))),
        _ => v.to_string(),
    }
}

/// How the Host decided a submitted turn.
#[derive(Debug, PartialEq)]
enum Decided {
    /// Admitted: height, world root, receipt (transaction, event), how it confirmed.
    Admitted { height: String, root: String, receipt: String, how: String },
    Refused(String),
    Undecided(String),
}

fn decided(outcome: &Value) -> Decided {
    let s = |k: &str| outcome.get(k).and_then(Value::as_str).unwrap_or("?").to_owned();
    if let Some(line) = crate::charged_line(outcome) {
        return Decided::Refused(line);
    }
    match outcome.get("type").and_then(Value::as_str) {
        Some("confirmed") => Decided::Admitted {
            height: s("acceptedCount"),
            root: s("worldRoot"),
            receipt: format!("tx {} event {}", s("transactionId"), s("eventId")),
            how: s("confirmation"),
        },
        Some("refused") => Decided::Refused(
            crate::refusal_line(outcome).unwrap_or_else(|| "refused: unnamed".into()).trim_start_matches("refused: ").to_owned()),
        other => Decided::Undecided(format!("Host outcome {}", other.unwrap_or("untyped"))),
    }
}

/// Record a Host's refusal (the shell and `mini` render it with its exit code) and finish the verb.
fn ending(error: String) -> Result<()> {
    if let Some(m) = error.strip_prefix("refused: ").or_else(|| error.strip_prefix("never forwarded: ")) {
        note_command_ending(CommandEnding::Refused(m.to_owned()));
        Ok(())
    } else {
        Err(error)
    }
}

/// The two shell lines that recover a turn whose answer was not read.
fn recovery(name: &str) -> String {
    format!("`bend lookup {name}` asks the Host for the decided outcome of the retained ingress (absence never submits); \
             `bend retry {name}` submits the same retained bytes again (never a new nonce)")
}

/// `ending`, with an undecided turn (a reply not read, or an earlier attempt of the same turn still
/// undecided) naming `bend lookup` and `bend retry` rather than the activity client's own verbs.
fn ending_for(name: &str, error: String) -> Result<()> {
    if error.starts_with("uncertain host") || error.starts_with("undecided: ") {
        let what = error.strip_prefix("undecided: ").unwrap_or(&error);
        let what = if what.starts_with("this turn's exact ingress") { "the last attempt of this turn may have been admitted" } else { what };
        note_command_ending(CommandEnding::Undecided(format!("{what}; {}", recovery(name))));
        Ok(())
    } else {
        ending(error)
    }
}

// ------------------------------------------------------------------ the workspace

struct Bend {
    ws: Ws,
    pin: Value,
}

impl Bend {
    fn open(root: PathBuf) -> Result<Self> {
        let bytes = fs::read(root.join("workspace.json")).map_err(|e| format!("bend: cannot read workspace.json: {e}"))?;
        let pin: Value = serde_json::from_slice(&bytes).map_err(|e| format!("bend: invalid workspace.json: {e}"))?;
        Ok(Self { ws: activity::ws(root)?, pin })
    }

    fn dir(&self, name: &str) -> PathBuf {
        self.ws.root.join("bend").join(name)
    }

    /// The member's own account and the capability that spends from it (`--account REF`, else the
    /// workspace's one account reference, as `credit` finds it).
    fn payer(&self, explicit: Option<&str>) -> Result<(String, String)> {
        let name = crate::credit::my_account(&self.ws.root, &self.pin, explicit)?;
        let reference = workspace::reference(&self.ws.root, &name)?;
        let capability = reference.get("operationCapability").or_else(|| reference.get("observeCapability"))
            .and_then(Value::as_str).ok_or_else(|| format!("bend: account reference {name} names no capability"))?;
        Ok((field(&reference, "target")?.to_owned(), capability.to_owned()))
    }

    /// The content resource REF: (object cell, its operation capability).
    fn object(&self, name: &str) -> Result<(String, String)> {
        let reference = workspace::reference(&self.ws.root, name)?;
        let capability = reference.get("operationCapability").and_then(Value::as_str)
            .ok_or_else(|| format!("bend: {name} names no operation capability (a resource you may write)"))?;
        Ok((field(&reference, "target")?.to_owned(), capability.to_owned()))
    }

    /// One turn under a fresh attempt directory, described by `meta` (retained beside it as
    /// `ATTEMPT.meta.json`, so `bend lookup` and `bend retry` know what the attempt was). With
    /// `lose`, the Host's reply to the submission is deliberately not read (the shell's lost-reply
    /// switch, `transport`): the attempt stays retained and undecided.
    fn submit(&self, name: &str, step: &str, turn: &Value, meta: &Value, lose: bool) -> Result<(Decided, Value)> {
        let attempts = self.dir(name).join("attempts");
        crate::fsio::ensure_private_dir_all(&attempts)?;
        let out = attempts.join(format!("{step}-{}", &crate::fsio::random_nonce()?[..8]));
        let mut meta = meta.clone();
        meta["step"] = json!(step);
        crate::fsio::retain_json(&attempts.join(format!("{}.meta.json", out.file_name().and_then(|n| n.to_str()).unwrap_or("attempt"))), &meta)?;
        if lose {
            std::env::set_var(mini_sdk::operator::LOSE_REPLY_ENV, mini_sdk::host_operations::ACTIVITY_SUBMIT.to_string());
        }
        let outcome = activity::submit(&self.ws, turn, &out, false, None, false);
        std::env::remove_var(mini_sdk::operator::LOSE_REPLY_ENV);
        let outcome = outcome?;
        Ok((decided(&outcome), outcome))
    }

    /// The newest attempt of NAME that reached an ingress: (its directory, its meta).
    fn latest(&self, name: &str) -> Result<(PathBuf, Value)> {
        let attempts = self.dir(name).join("attempts");
        let mut found: Vec<(std::time::SystemTime, PathBuf, Value)> = Vec::new();
        for entry in fs::read_dir(&attempts).map_err(|_| format!("bend: {name} has no attempts here"))? {
            let entry = entry.map_err(|e| e.to_string())?;
            let file = entry.file_name().to_string_lossy().into_owned();
            let Some(stem) = file.strip_suffix(".meta.json") else { continue };
            let dir = attempts.join(stem);
            if !dir.join("ingress.bin").is_file() {
                continue;
            }
            let meta: Value = serde_json::from_slice(&fs::read(entry.path()).map_err(|e| e.to_string())?).map_err(|e| format!("bend: {file}: {e}"))?;
            found.push((entry.metadata().and_then(|m| m.modified()).map_err(|e| e.to_string())?, dir, meta));
        }
        found.sort_by(|a, b| a.0.cmp(&b.0).then_with(|| a.1.cmp(&b.1)));
        found.pop().map(|(_, dir, meta)| (dir, meta)).ok_or_else(|| format!("bend: no attempt of {name} reached the Host (nothing to look up)"))
    }
}

fn published(bend: &Bend, name: &str) -> Result<Value> {
    let path = bend.dir(name).join("out").join("publication.json");
    let bytes = fs::read(&path).map_err(|_| format!("bend: {name} is not published here: `bend publish {name} @FILE`"))?;
    serde_json::from_slice(&bytes).map_err(|e| format!("bend: {}: {e}", path.display()))
}

// ------------------------------------------------------------------ publish

fn publish(bend: &Bend, mut args: Args) -> Result<()> {
    let name = text(&mut args, "name")?;
    let source = path(args.required("source")?);
    let entry = opt(&mut args, "entry")?.unwrap_or_else(|| name.clone());
    let account = opt(&mut args, "account")?;
    let lose = lose_flag(&mut args)?;
    args.finish()?;
    name_ok(&name)?;
    let module = source.file_stem().and_then(|s| s.to_str()).filter(|s| !s.is_empty()).ok_or("bend: --source names no file")?.to_owned();
    let bytes = fs::read(&source).map_err(|e| format!("bend: cannot read {}: {e}", source.display()))?;
    let dir = bend.dir(&name);
    crate::fsio::ensure_private_dir_all(&dir.join("source"))?;
    let kept = dir.join("source").join(format!("{module}.obend"));
    let spec = package_input(&module, &kept, &entry);
    let spec_bytes = serde_json::to_vec(&spec).map_err(|e| e.to_string())?;
    let out = dir.join("out");
    if out.join("publication.json").is_file() {
        // The same bend again (a retry after a lost reply): the same spec reuses the front end's
        // output; another source under this name is another bend.
        if fs::read(dir.join("spec.json")).ok().as_deref() != Some(&spec_bytes) || fs::read(&kept).ok().as_deref() != Some(&bytes) {
            return Err(format!("bend: {name} is already published here with other source; publish the new source under another name"));
        }
    } else {
        if kept.exists() {
            fs::remove_file(&kept).map_err(|e| format!("bend: {e}"))?;
        }
        crate::fsio::create_private(&kept, &bytes)?;
        let spec_path = dir.join("spec.json");
        if spec_path.exists() {
            fs::remove_file(&spec_path).map_err(|e| format!("bend: {e}"))?;
        }
        crate::fsio::create_private(&spec_path, &spec_bytes)?;
        let output = std::process::Command::new(&bend.ws.host)
            .arg(&bend.ws.config)
            .args(["objective-publication"])
            .arg(&spec_path)
            .arg("activity")
            .arg(&out)
            .output()
            .map_err(|e| format!("bend: cannot run the Host: {e}"))?;
        if !output.status.success() {
            // The Host's front end refused the source: its diagnostic, by name; nothing was submitted.
            let said = String::from_utf8_lossy(&output.stderr);
            let said = said.trim().trim_start_matches("uncaught exception:").trim();
            note_command_ending(CommandEnding::Refused(format!(
                "front-end: the Host's Objective Bend front end refused {}: {}; nothing was submitted",
                source.display(), said.split_whitespace().collect::<Vec<_>>().join(" "))));
            return Ok(());
        }
    }
    let publication: Value = serde_json::from_slice(&fs::read(out.join("publication.json")).map_err(|e| format!("bend: {e}"))?)
        .map_err(|e| format!("bend: publication.json: {e}"))?;
    let artifact_id = field(&publication, "artifactId")?.to_owned();
    let package_id = field(&publication, "packageId")?.to_owned();
    let hex = |file: &str| fs::read(out.join(file)).map(|b| mini_sdk::hex::encode(&b)).map_err(|e| format!("bend: {file}: {e}"));
    let (payer, payer_cap) = bend.payer(account.as_deref())?;
    let turn = publish_turn(&hex("artifact.bin")?, &hex("package.bin")?, &payer, &payer_cap);
    let meta = json!({"kind": "publish", "bend": name, "artifactId": artifact_id, "packageId": package_id});
    match bend.submit(&name, "publish", &turn, &meta, lose).map(|(d, _)| d) {
        Err(e) => ending_for(&name, e),
        Ok(decided) => report(bend, &name, &meta, None, "bend publish", decided),
    }
}

/// `--lose-reply-once`: the shell's lost-reply switch, armed for the turn's submission only.
fn lose_flag(args: &mut Args) -> Result<bool> {
    Ok(opt(args, "lose-reply-once")?.as_deref() == Some("true"))
}

/// Print the Host's decision on an attempt described by `meta`, or record its refusal / undecided ending.
/// `lead` names the verb (`bend publish`, `bend lookup`, `bend retry`).
fn report(bend: &Bend, name: &str, meta: &Value, transaction: Option<String>, lead: &str, d: Decided) -> Result<()> {
    let m = |k: &str| meta.get(k).and_then(Value::as_str).unwrap_or("?").to_owned();
    match d {
        Decided::Refused(r) => ending(format!("refused: {r}")),
        Decided::Undecided(r) => ending_for(name, format!("undecided: {r}")),
        Decided::Admitted { height, root, receipt, how } => match m("kind").as_str() {
            "publish" => {
                println!("admitted: {lead} {name} ({how}): artifact {} package {}, height {height}, world root {root}, receipt {receipt}", m("artifactId"), m("packageId"));
                Ok(())
            }
            "run" => {
                let tx = transaction.ok_or("bend: the attempt names no transaction")?;
                finish_run(bend, name, meta, &tx, &format!("{lead} {name} ({how}) on {}", m("objectRef")), &height, &root, &receipt, None, None)
            }
            _ => {
                println!("admitted: {lead} {name} ({how}): {} turn, height {height}, world root {root}, receipt {receipt}", m("kind"));
                Ok(())
            }
        },
    }
}

/// The birth transaction an attempt's plan names (Host inspection of its retained `plan.bin`).
fn transaction_of(bend: &Bend, dir: &Path) -> Result<String> {
    let plan = fs::read(dir.join("plan.bin")).map_err(|e| format!("bend: {}: {e}", dir.join("plan.bin").display()))?;
    let inspected = activity::inspect(&bend.ws, "objective-activity-plan", &plan)?;
    inspected.pointer("/command/transaction").map(|t| t.as_str().map(str::to_owned).unwrap_or_else(|| t.to_string()))
        .ok_or_else(|| "bend: the plan names no transaction".to_owned())
}

/// `bend lookup NAME`: the receipt-only lookup (op 213) of NAME's last attempt's retained ingress.
fn lookup_cmd(bend: &Bend, mut args: Args, retry: bool) -> Result<()> {
    let name = text(&mut args, "name")?;
    args.finish()?;
    name_ok(&name)?;
    let (dir, meta) = bend.latest(&name)?;
    let ingress = dir.join("ingress.bin");
    let outcome = if retry { activity::resubmit(&bend.ws, &ingress) } else { activity::lookup(&bend.ws, &ingress) };
    let outcome = match outcome {
        Ok(o) => o,
        Err(e) => return ending_for(&name, e),
    };
    let d = decided(&outcome);
    let transaction = if matches!(d, Decided::Admitted { .. }) && meta.get("kind").and_then(Value::as_str) == Some("run") { Some(transaction_of(bend, &dir)?) } else { None };
    report(bend, &name, &meta, transaction, if retry { "bend retry" } else { "bend lookup" }, d)
}

// ------------------------------------------------------------------ run

fn balance(view: &Value, account: &str) -> Option<u128> {
    view.get("balances")?.as_array()?.iter().find(|b| b.get("account").and_then(Value::as_str) == Some(account))?
        .get("balance")?.as_str()?.parse().ok()
}

fn cell_of<'a>(view: &'a Value, cell: &str) -> Option<&'a Value> {
    view.get("cells")?.as_array()?.iter().find(|c| c.get("cell").and_then(Value::as_str) == Some(cell))
}

fn decimal_of(v: &Value, ptr: &str) -> Option<u128> {
    v.pointer(ptr)?.as_str()?.parse().ok()
}

fn run_bend(bend: &Bend, mut args: Args) -> Result<()> {
    let name = text(&mut args, "name")?;
    let object_ref = text(&mut args, "object")?;
    let seed = json_flag(&mut args, "seed")?;
    let input = json_flag(&mut args, "input")?;
    let state_type = json_flag(&mut args, "state-type")?;
    let deposit = opt(&mut args, "deposit")?;
    let account = opt(&mut args, "account")?;
    let lose = lose_flag(&mut args)?;
    args.finish()?;
    name_ok(&name)?;
    let deposit: Option<u128> = deposit
        .map(|d| if mini_sdk::decimal::is_canonical_max(&d, 30) { d.parse().map_err(|_| "bend: --deposit is too large".to_owned()) } else { Err("bend: --deposit must be a canonical decimal".to_owned()) })
        .transpose()?;
    let publication = published(bend, &name)?;
    let pin = field(&publication, "artifactId")?.to_owned();
    let (payer, payer_cap) = bend.payer(account.as_deref())?;
    let (object, object_cap) = bend.object(&object_ref)?;
    let view = activity::view(&bend.ws, &json!({"objects": [&object], "pins": [&pin], "accounts": [&payer]}))?;
    let front = view.pointer("/pins/0/frontEnd").filter(|f| f.is_object()).ok_or_else(|| format!(
        "bend: the chain holds no package for {name} (artifact {pin}): its publish turn was not admitted; run `bend publish {name} @FILE` again"))?;
    let (replay, core) = (decimal_of(front, "/replayBytes").ok_or("bend: front-end quote lacks replayBytes")?,
        decimal_of(front, "/coreBytes").ok_or("bend: front-end quote lacks coreBytes")?);
    let extract = decimal_of(&view, "/limits/extractTicks").ok_or("bend: the Host published no extraction budget")?;
    let before = balance(&view, &payer);
    let object_cell = view.pointer("/objects/0/objectCell").and_then(Value::as_str).ok_or("bend: view names no object cell")?;
    let has_record = cell_of(&view, object_cell).and_then(|c| c.get("kind")).and_then(Value::as_str) == Some("object-record");
    let mut created = None;
    if !has_record {
        let state_type = state_type.unwrap_or_else(|| serde_json::from_str(TOTAL_STATE).expect("a constant"));
        let turn = create_turn(&object, &object_cap, &pin, &state_type, seed.as_ref(), &payer, &payer_cap);
        let meta = json!({"kind": "create", "bend": name, "objectRef": object_ref});
        match bend.submit(&name, "create", &turn, &meta, false) {
            Err(e) => return ending_for(&name, e),
            Ok((Decided::Admitted { height, .. }, _)) => created = Some(height),
            Ok((Decided::Refused(m), _)) => return ending(format!("refused: create {object_ref}: {m}")),
            Ok((Decided::Undecided(m), _)) => return ending_for(&name, format!("undecided: create {object_ref}: {m}")),
        }
    } else if seed.is_some() {
        return Err(format!("bend: {object_ref} already has a record; --seed is the creation's"));
    }
    let envelope = envelope(extract, replay, core, TICKS);
    let deposit = deposit.unwrap_or(DEPOSIT_PRICES * price(TICKS, replay, core));
    let input = input.unwrap_or_else(|| default_input(&bend.ws.subject));
    let turn = birth_turn(&object, &object_cap, &payer, &payer_cap, &pin, &input, &envelope, deposit);
    let meta = json!({"kind": "run", "bend": name, "objectRef": object_ref, "object": object, "pin": pin, "payer": payer, "deposit": deposit.to_string()});
    let (how, outcome) = match bend.submit(&name, "birth", &turn, &meta, lose) {
        Err(e) => return ending_for(&name, e),
        Ok((Decided::Refused(m), _)) => return ending(format!("refused: run {name} on {object_ref}: {m}")),
        Ok((Decided::Undecided(m), _)) => return ending_for(&name, format!("undecided: run {name} on {object_ref}: {m}")),
        Ok((admitted, outcome)) => (admitted, outcome),
    };
    let Decided::Admitted { height, root, receipt, .. } = how else { unreachable!("matched above") };
    let transaction = outcome.get("transaction").map(|t| t.as_str().map(str::to_owned).unwrap_or_else(|| t.to_string())).unwrap_or_default();
    finish_run(bend, &name, &meta, &transaction, &format!("bend run {name} on {object_ref}"), &height, &root, &receipt, before, created)
}

/// The admitted run's line: the Host's decision, the object's declared state and the activity's purse
/// read back through the view; the object's registry entry (`bend show` reads it).
#[allow(clippy::too_many_arguments)]
fn finish_run(bend: &Bend, name: &str, meta: &Value, transaction: &str, lead: &str, height: &str, root: &str, receipt: &str,
              before: Option<u128>, created: Option<String>) -> Result<()> {
    let m = |k: &str| meta.get(k).and_then(Value::as_str).unwrap_or("?").to_owned();
    let (object, payer, pin, object_ref, deposit) = (m("object"), m("payer"), m("pin"), m("objectRef"), m("deposit"));
    let now = activity::view(&bend.ws, &json!({"objects": [&object], "births": [{"object": &object, "transaction": transaction}], "accounts": [&payer]}))?;
    let record_cell = now.pointer("/births/0/record").and_then(Value::as_str).unwrap_or_default().to_owned();
    let purse = activity::view(&bend.ws, &json!({"accounts": [&record_cell]}))?;
    let state = now.pointer("/objects/0/stateCell").and_then(Value::as_str).and_then(|c| cell_of(&now, c))
        .and_then(|c| c.get("value")).map(data_text).unwrap_or_else(|| "(none)".into());
    let after = balance(&now, &payer);
    let mut line = format!("admitted: {lead}: height {height}, world root {root}, receipt {receipt}; state {state}; purse {}; deposit {deposit}",
        balance(&purse, &record_cell).map(|b| b.to_string()).unwrap_or_else(|| "?".into()));
    if let (Some(b), Some(a)) = (before, after) {
        line.push_str(&format!("; account {b} -> {a} (charge {})", b.saturating_sub(a)));
    }
    if let Some(h) = created {
        line.push_str(&format!("; object created at height {h}"));
    }
    let registry = bend.ws.root.join("bend").join("objects");
    crate::fsio::ensure_private_dir_all(&registry)?;
    let _ = crate::fsio::retain_json(&registry.join(format!("{}.json", workspace::ref_file(&object_ref))),
        &json!({"bend": name, "pin": pin, "object": object, "transaction": transaction, "record": record_cell}));
    println!("{line}");
    Ok(())
}

// ------------------------------------------------------------------ show

fn show(bend: &Bend, mut args: Args) -> Result<()> {
    let object_ref = text(&mut args, "object")?;
    args.finish()?;
    let (object, _) = bend.object(&object_ref)?;
    let known: Option<Value> = fs::read(bend.ws.root.join("bend").join("objects").join(format!("{}.json", workspace::ref_file(&object_ref))))
        .ok().and_then(|b| serde_json::from_slice(&b).ok());
    let mut request = json!({"objects": [&object]});
    if let Some(k) = &known {
        request["births"] = json!([{"object": &object, "transaction": k.get("transaction")}]);
    }
    let view = activity::view(&bend.ws, &request)?;
    let cell = |ptr: &str| view.pointer(ptr).and_then(Value::as_str).and_then(|c| cell_of(&view, c));
    let Some(record) = cell("/objects/0/objectCell").filter(|c| c.get("kind").and_then(Value::as_str) == Some("object-record")) else {
        println!("{object_ref}: object cell {object}, no activity record (never created by a bend)");
        return Ok(());
    };
    let state = cell("/objects/0/stateCell");
    println!("{object_ref}: object cell {object}, pin {}, state {} (version {}), height {}",
        record.get("pin").and_then(Value::as_str).unwrap_or("?"),
        state.and_then(|c| c.get("value")).map(data_text).unwrap_or_else(|| "(none)".into()),
        state.and_then(|c| c.get("version")).map(|v| v.to_string().trim_matches('"').to_owned()).unwrap_or_else(|| "?".into()),
        view.get("height").and_then(Value::as_str).unwrap_or("?"));
    if let Some(k) = known {
        let record_cell = k.get("record").and_then(Value::as_str).unwrap_or_default();
        let purse = activity::view(&bend.ws, &json!({"accounts": [record_cell]}))?;
        let phase = cell_of(&view, record_cell).and_then(|c| c.pointer("/record/phase")).map(|p| p.to_string()).unwrap_or_else(|| "?".into());
        println!("  bend {}: activity record {record_cell}, purse {}, phase {phase}",
            k.get("bend").and_then(Value::as_str).unwrap_or("?"),
            balance(&purse, record_cell).map(|b| b.to_string()).unwrap_or_else(|| "?".into()));
    }
    Ok(())
}

pub(crate) fn run(mut args: Args) -> Result<()> {
    let action = text(&mut args, "action")?;
    let bend = Bend::open(path(args.required("dir")?))?;
    match action.as_str() {
        "publish" => publish(&bend, args),
        "run" => run_bend(&bend, args),
        "show" => show(&bend, args),
        "lookup" => lookup_cmd(&bend, args, false),
        "retry" => lookup_cmd(&bend, args, true),
        _ => Err("bend --action must be publish, run, show, lookup or retry".into()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_package_input_is_the_front_ends_spec() {
        let spec = package_input("Tally", Path::new("/ws/bend/tally/source/Tally.obend"), "tally");
        assert_eq!(spec, json!({"schema": "dregg.objective-bend.package-input.v1", "edition": "objective-bend-1",
            "modules": [{"name": "Tally", "sourcePath": "/ws/bend/tally/source/Tally.obend", "imports": []}],
            "entryModule": "0", "entryDefinition": "tally"}));
    }

    #[test]
    fn a_full_envelope_declares_the_quote_the_budget_and_the_policy_figures() {
        let e = envelope(3_200_000, 1500, 900, 3000);
        assert_eq!(e.as_object().unwrap().len(), ENVELOPE_KEYS.len());
        assert_eq!((e["sourceTicks"].as_str(), e["extractTicks"].as_str(), e["replayBytes"].as_str(), e["coreBytes"].as_str()),
            (Some("3000"), Some("3200000"), Some("1500"), Some("900")));
        assert_eq!((e["heap"].as_str(), e["typeFuel"].as_str(), e["feeDebit"].as_str()), (Some("200000"), Some("16384"), Some("0")));
        assert_eq!(price(3000, 1500, 900), 1 + 3000 + 61 * 1500 + 16 * 900);
    }

    #[test]
    fn the_turn_bodies_are_the_hosts_turns() {
        let env = envelope(1, 2, 3, 3000);
        let birth = birth_turn("90", "91", "130", "1030", "777", &default_input("40"), &env, 1234);
        assert_eq!((birth["kind"].as_str(), birth["deposit"].as_str(), birth["pin"].as_str()), (Some("birth"), Some("1234"), Some("777")));
        assert_eq!(birth["resume"], birth["envelope"]);
        assert_eq!(birth["timeout"], birth["envelope"]);
        assert_eq!(birth["input"]["fields"][1], json!({"name": "decider", "value": {"tag": "natural", "value": "40"}}));
        let state: Value = serde_json::from_str(TOTAL_STATE).unwrap();
        let create = create_turn("90", "91", "777", &state, None, "130", "1030");
        assert!(create.get("seed").is_none());
        assert_eq!(create["upgrade"], json!({"frozen": {}}));
        let seeded = create_turn("90", "91", "777", &state, Some(&json!({"tag": "natural", "value": "5"})), "130", "1030");
        assert_eq!(seeded["seed"]["value"], "5");
        let publish = publish_turn("aa", "bb", "130", "1030");
        assert_eq!(publish, json!({"kind": "publish", "artifact": "aa", "package": "bb", "payer": "130", "payerCapability": "1030"}));
    }

    #[test]
    fn data_reads_as_the_member_writes_it() {
        let state = json!({"tag": "record", "fields": [{"name": "total", "value": {"tag": "natural", "value": "3"}}]});
        assert_eq!(data_text(&state), "{total=3}");
        assert_eq!(data_text(&default_input("40")), "{init=set(0), decider=40}");
    }

    #[test]
    fn the_hosts_outcomes_are_decided_by_name() {
        let ok = json!({"type": "confirmed", "confirmation": "installed", "transactionId": "7", "eventId": "9", "acceptedCount": "12", "worldRoot": "55"});
        assert_eq!(decided(&ok), Decided::Admitted { height: "12".into(), root: "55".into(), receipt: "tx 7 event 9".into(), how: "installed".into() });
        let no = json!({"type": "refused", "reason": "notObjectHolder", "phase": "", "detail": ""});
        assert!(matches!(decided(&no), Decided::Refused(m) if m.starts_with("notObjectHolder")));
        assert!(matches!(decided(&json!({"type": "uncertain"})), Decided::Undecided(_)));
    }

    #[test]
    fn a_hosts_ending_is_not_a_client_error() {
        let _ = take_command_ending();
        assert!(ending("refused: op210: notAccountOwner".into()).is_ok());
        assert_eq!(take_command_ending().unwrap().render().0, 3);
        assert!(ending("bend: no workspace".into()).is_err());
        assert!(ending_for("tally", "bend: no workspace".into()).is_err());
    }

    #[test]
    fn an_undecided_turn_names_the_two_shell_lines_that_recover_it() {
        for error in ["uncertain host response: reply deliberately not read", "undecided: this turn's exact ingress is retained at /x/attempts/a and may have been admitted; `mini activity --action lookup`"] {
            let _ = take_command_ending();
            assert!(ending_for("tally", error.into()).is_ok());
            let (code, text) = take_command_ending().unwrap().render();
            assert_eq!(code, 4, "{text}");
            assert!(text.contains("`bend lookup tally`") && text.contains("`bend retry tally`"), "{text}");
            assert!(!text.contains("mini activity"), "{text}");
        }
    }

    #[test]
    fn bend_names_are_reference_safe() {
        assert!(name_ok("tally-2").is_ok());
        assert!(name_ok("").is_err() && name_ok("a/b").is_err() && name_ok("a b").is_err());
    }

    /// The mirrored policy figures are `activity_world.py`'s, the world every genesis pins.
    #[test]
    fn policy_mirror_matches_the_world() {
        let world = include_str!("../activity_world.py");
        for (k, v) in FIXED {
            assert!(world.contains(&format!("'{k}': {v}")), "{k}: {v} is not in activity_world.MAXIMUM");
        }
        assert!(world.contains(&format!("'replayBytes': '{REPLAY_RATE}'")) && world.contains(&format!("'coreBytes': '{CORE_RATE}'")));
        assert!(world.contains(&format!("'base': '{BASE}', 'typeFuel': '0', 'sourceTicks': '{TICK_RATE}'")));
        assert!(world.contains(&format!("TICKS = {TICKS}")));
        for k in ENVELOPE_KEYS {
            assert!(world.contains(&format!("'{k}':")), "{k} is not an envelope member of activity_world.MAXIMUM");
        }
    }
}
