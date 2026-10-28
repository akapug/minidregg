#!/usr/bin/env python3
"""Attach an existing native application to an existing controller in one Store.

Operator orchestration only: Mini authors and admits every source, signature,
and transition. JSON coordinates select existing authority; they confer none.
An exclusive phase directory retains all attempts. Failed/uncertain phases are
never retried automatically; status exposes retained paths for native lookup.

Input protocol: mini-application-attachment-v1. All paths are absolute.
  allocation: integrated allocation JSON selecting one controller and application
  paths: mini, host, spkHost, hostConfig, participantSocket, operatorSocket,
         profile, repo, controllerConfig, controllerHome, outputDir (new directory)
  application: birthSource, birthAttempt, bootstrapTicketRequest,
               bootstrapTicketAttempt, packageDirectory
  issuer: subject, keyPath, payer, funding, sourceCapabilities, reserveAmount,
          tool and parent (each task, capability, observeCapability)
  signers: [{keyId, keyEpoch, algorithm, keyPath, publicKeyPath}]
  sessionProfile: native allowedSessionFamilies profile, including genesis,
                  template, factory/payer selectors and grain tariff
  names (optional): application, family, route, display, handle, serviceProtocol
For a private controller home, paths.controllerHostConfigExport may select the
root installer's controller-host-config-export snapshot instead of directly
reading the controller's private Host metadata file.

prepare-config emits an installable update and nextTool. Install it through the
controller's supported account route before invoking mini_create_application_session.
The optional create-session phase needs paths.grainRuntime and legitimate direct
access to that controller's private socket; a split-UID deployment invokes its
supported controller wrapper instead and supplies the retained result to
issue-grant. prepare-route consumes the controller layout; activate consumes the
actual native START result and emits a second installable update. No phase
installs files into the controller account or starts its service itself.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys

def read(path):
    return json.loads(Path(path).read_text())


def write(path, value):
    data = (json.dumps(value, indent=2) + "\n").encode() if not isinstance(value, bytes) else value
    with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb") as out:
        out.write(data)
        out.flush()
        os.fsync(out.fileno())


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def receipt(value):
    if value.get("type") != "confirmed" or value.get("confirmation") not in ("installed", "replayed"):
        raise ValueError("native confirmation absent")
    return {key: value[key] for key in ("transactionId", "eventId", "acceptedCount", "worldRoot")}


def require_current_start(start, status):
    """Reject stale caller records before using their native unit selection."""
    if status.get("protocol") != "mini-spk-grain-status-v2" or status.get("app") != start["app"]:
        raise ValueError("current native status names a different application")
    running = [run for run in status["runs"] if run["state"] == "running"]
    if len(running) != 1 or any(running[0].get(key) != start.get(key) for key in ("generation", "unit")) or running[0].get("unitActiveState") != "active":
        raise ValueError("START record is not the current active native generation")


def controller_host_metadata(path):
    """Copy only the fresh world's public settings and protected-file paths."""
    raw = Path(path).read_bytes()
    value = json.loads(raw)
    allowed = {"domain", "federation", "factoryId", "resourceBookId", "authorityCellId", "issuer",
               "ownerBudget", "lifetime", "birthSlack", "tariffBase", "tariffPerBirth", "tariffPerGrant",
               "tariffPerInitialPayloadByte", "collector", "asset", "genesisHeight", "expectedSeed",
               "storageBinary", "storageRoot", "signatureBinary", "checkpointKey", "checkpointEvery",
               "grainBirthTariff", "completionCustodianKey", "lifecycleManagement",
               "agentLifetimeDispatchTargets", "nockFSync", "disabledEvaluators", "providerServices"}
    if any(value[key] is not None for key in set(value) - allowed):
        raise ValueError("fresh Host settings include unreviewed controller-visible fields")
    for name in ("storageBinary", "storageRoot", "signatureBinary", "checkpointKey"):
        if value.get(name) is not None and (not isinstance(value[name], str) or not Path(value[name]).is_absolute()):
            raise ValueError("Host storage/checkpoint setting must remain an absolute path, never key bytes")
    public = value.get("completionCustodianKey")
    if public is not None and (not isinstance(public, str) or len(public) != 64 or bytes.fromhex(public).hex() != public):
        raise ValueError("completion custodian public key shape differs")
    return raw


def append_named(config, field, value, key="name"):
    values = config.setdefault(field, [])
    if any(item.get(key) == value[key] for item in values):
        raise ValueError(f"{field} already contains {value[key]}; refusing replacement")
    values.append(value)


class Attachment:
    def __init__(self, contract, phase):
        if phase == "status":
            self.load_retained(contract)
            return
        self.contract = read(contract)
        if self.contract.get("protocol") != "mini-application-attachment-v1":
            raise ValueError("application attachment protocol absent")
        c, paths = self.contract, self.contract["paths"]
        required = ("mini", "host", "spkHost", "hostConfig", "participantSocket", "operatorSocket", "profile",
                    "repo", "controllerConfig", "controllerHome", "outputDir")
        for field in required:
            self.absolute(paths[field])
        self.allocation_path = self.absolute(c["allocation"])
        self.allocation = read(self.allocation_path)
        if len(self.allocation["agents"]) != 1:
            raise ValueError("exactly one selected controller allocation required")
        self.agent = self.allocation["agents"][0]
        self.mini, self.host = Path(paths["mini"]), Path(paths["host"])
        self.config, self.public = Path(paths["hostConfig"]), Path(paths["participantSocket"])
        self.operator, self.spk_host = Path(paths["operatorSocket"]), Path(paths["spkHost"])
        self.profile, self.repo = Path(paths["profile"]), Path(paths["repo"])
        self.root = Path(paths["outputDir"])
        self.application, self.issuer = c["application"], c["issuer"]
        self.signers = c["signers"]
        for field in ("birthSource", "birthAttempt", "bootstrapTicketRequest", "bootstrapTicketAttempt", "packageDirectory"):
            self.absolute(self.application[field])
        self.absolute(self.issuer["keyPath"])
        if len({s["keyId"] for s in self.signers}) != len(self.signers):
            raise ValueError("duplicate signer keyId")
        for signer in self.signers:
            for field in ("keyPath", "publicKeyPath"):
                self.absolute(signer[field])
        self.names = {"application": "oracle-app", "family": "oracle-session", "route": "oracle-agent-v1",
                      "display": "Oracle agent", "handle": "oracle-agent", "serviceProtocol": "oracle-operations-v1"}
        self.names.update(c.get("names", {}))
        # Names enter private artifact paths as well as native route selectors.
        for field in ("application", "family", "route", "handle"):
            name = self.names[field]
            if not name or not name.isascii() or any(not (x.isalnum() or x == "-") for x in name):
                raise ValueError("attachment names require ASCII letters, digits or hyphens")
        if not self.names["application"].endswith("-app"):
            raise ValueError("application route name must end in -app")
        self.bootstrap_name = self.names["application"][:-4] + "-bootstrap-app"
        if len(self.bootstrap_name) > 64:
            raise ValueError("bootstrap application reference exceeds native 64-byte name bound")
        config = read(paths["controllerConfig"])
        self.validate_controller(config)
        if sha(config["host"]) != sha(self.host) or sha(config["mini"]) != sha(self.mini):
            raise ValueError("controller and attachment binaries differ")
        controller_host = paths.get("controllerHostConfigExport", config["hostConfig"])
        self.absolute(controller_host)
        if read(controller_host) != read(self.config) or config["hostSocket"] != str(self.public):
            raise ValueError("controller and attachment must use the same Store config and participant socket")
        profile = read(self.profile)
        if (read(profile["miniConfig"]) != read(self.config) or profile["miniOperatorSocket"] != str(self.operator)
                or profile["miniConfigSha256"] != sha(self.config) or profile["miniHostSha256"] != sha(self.host)):
            raise ValueError("application profile and attachment must use the same pinned Store and Host")
        expected_package = Path(profile["stateRoot"]) / "apps" / self.allocation["app"] / "install/launch-descriptor/package-v1"
        if Path(self.application["packageDirectory"]) != expected_package:
            raise ValueError("package directory differs from selected application profile")
        self.controller_stage = self.root / "controller-stage/controller.json"
        # Pin all original source artifacts and executable images across phases.
        files = {field: paths[field] for field in ("mini", "host", "spkHost", "hostConfig", "profile")}
        if "grainRuntime" in paths:
            files["grainRuntime"] = str(self.absolute(paths["grainRuntime"]))
        if "controllerHostConfigExport" in paths:
            files["controllerHostConfigExport"] = paths["controllerHostConfigExport"]
        files.update({"orchestrator": str(Path(__file__).resolve()),
                      "routeRenderer": str(self.repo / "scripts/spk-platform/prepare-lifetime-route.sh"),
                      "allocation": str(self.allocation_path),
                      "birthSource": self.application["birthSource"],
                      "bootstrapTicketRequest": self.application["bootstrapTicketRequest"]})
        for field, names in (("birthAttempt", ("call.bin", "outcome.json")),
                             ("bootstrapTicketAttempt", ("ingress.bin", "receipt-anchor.json")),
                             ("packageDirectory", ("schema-inspection.json", "descriptor-inspection.json"))):
            for name in names:
                files[field + "/" + name] = str(Path(self.application[field]) / name)
        files["launch"] = str(Path(self.application["packageDirectory"]).parent / "launch-inspection.json")
        for signer in self.signers:
            files["publicKey/" + signer["keyId"]] = signer["publicKeyPath"]
        pinned = {"contract": c, "files": files, "sha256": {key: sha(path) for key, path in files.items()}}
        if self.root.exists():
            if read(self.root / "attachment.json") != pinned:
                raise ValueError("attachment inputs changed; retain existing attempts and reconcile explicitly")
            accepted_configs = [self.root / "controller-input.json", self.controller_stage]
            accepted_configs.extend(sorted(self.root.glob("native-activate-*/controller-update/controller.json")))
            if not any(path.exists() and read(path) == config for path in accepted_configs):
                raise ValueError("controller config changed outside retained attachment updates")
        else:
            if phase == "status":
                raise ValueError("attachment has no retained state")
            self.root.mkdir(mode=0o700)
            write(self.root / "attachment.json", pinned)
            write(self.root / "controller-input.json", config)
        self.calls = self.root / ("native-" + phase)
        if phase != "status":
            self.calls.mkdir(mode=0o700)  # Exclusive: uncertain phases are never implicitly resubmitted.

    def load_retained(self, contract):
        """Status selects retained identities even if the live configuration drifted."""
        supplied = read(contract)
        self.root = self.absolute(supplied["paths"]["outputDir"])
        retained = read(self.root / "attachment.json")
        self.contract = retained["contract"]
        paths = self.contract["paths"]
        self.mini, self.operator = Path(paths["mini"]), Path(paths["operatorSocket"])
        self.pin_diagnostics = []
        if supplied != self.contract:
            self.pin_diagnostics.append({"input": "contract", "problem": "live contract differs; recovery commands use retained contract"})
        for key, expected in retained["sha256"].items():
            path = retained.get("files", {}).get(key)
            if path is None:
                self.pin_diagnostics.append({"input": key, "problem": "retained file path unavailable"})
                continue
            try:
                actual = sha(path)
            except OSError as error:
                self.pin_diagnostics.append({"input": key, "path": path, "problem": str(error)})
                continue
            if actual != expected:
                self.pin_diagnostics.append({"input": key, "path": path, "expectedSha256": expected, "actualSha256": actual})
        try:
            current = read(paths["controllerConfig"])
            candidates = [self.root / "controller-input.json", self.root / "controller-stage/controller.json"]
            candidates.extend(sorted(self.root.glob("native-activate-*/controller-update/controller.json")))
            matches = False
            for candidate in candidates:
                if candidate.exists() and read(candidate) == current:
                    matches = True
                    break
            if not matches:
                self.pin_diagnostics.append({"input": "controllerConfig", "problem": "live controller differs from retained updates"})
        except (OSError, ValueError) as error:
            self.pin_diagnostics.append({"input": "controllerConfig", "problem": str(error)})

    @staticmethod
    def absolute(value):
        path = Path(value)
        if not path.is_absolute() or ".." in path.parts:
            raise ValueError("absolute attachment path without parent traversal required")
        return path

    def role_signer(self, role):
        selected = [s for s in self.signers if s["keyId"] == self.agent[role]["keyId"]]
        if len(selected) != 1:
            raise ValueError(f"exactly one enrolled {role} signer required")
        return selected[0]

    def role_key(self, role):
        return Path(self.role_signer(role)["keyPath"])

    def validate_controller(self, config):
        a, caps = self.agent, self.agent["plannedCaps"]
        for field, role, owner in ((None, "controller", "parentOwner"), ("toolTask", "tool", "toolOwner"),
                                   ("dispatchTask", "dispatch", "dispatchOwner")):
            actual = config if field is None else config.get(field, {})
            if any(actual.get(k) != v for k, v in {"task": a[role]["task"], "subject": a[role]["subject"],
                       "capability": caps[owner], "queryCapability": caps[owner]}.items()):
                raise ValueError(f"existing {role} differs from allocated authority")
            self.role_signer(role)
        if config["task"] == config["dispatchTask"]["task"] or config["subject"] == config["dispatchTask"]["subject"]:
            raise ValueError("controller and dispatch must be distinct roles")

    def validate_layout(self, layout, config):
        self.validate_controller(config)
        dispatch = config["dispatchTask"]
        if layout["controllerUid"] in (0, os.getuid()) or os.getuid() == 0:
            raise ValueError("dedicated controller and distinct non-root operator required")
        expected = {"socketPath": layout["reverseSocket"], "hostUid": os.getuid(),
                    "operatorSocket": layout["operatorSocket"], "operatorPeerUid": layout["operatorPeerUid"]}
        if any(dispatch.get(k) != v for k, v in expected.items()):
            raise ValueError("dispatch transport differs from selected controller layout")
        if hasattr(self, "contract") and layout["controllerHome"] != self.contract["paths"]["controllerHome"]:
            raise ValueError("layout names another controller home")

    def prepare_config(self):
        """Delegate observations and extend an existing controller, preserving its other tools."""
        c, a, caps = self.contract, self.agent, self.agent["plannedCaps"]
        home = Path(c["paths"]["controllerHome"])
        config = read(c["paths"]["controllerConfig"])
        app = read(self.application["birthSource"])["applicationGrainBirth"]["applicationBirth"]["application"]
        if any(app[k] != self.allocation[k] for k in ("app", "packageManifest", "snapshotManifest")):
            raise ValueError("actual app birth differs from allocation")
        request = read(self.application["bootstrapTicketRequest"])
        ticket = request["spec"]["ticket"]
        if ticket["scope"]["app"] != app["app"]:
            raise ValueError("discovery ticket names a different application")
        for field, selected in (("registeredSharedApplications", self.bootstrap_name),
                                ("allowedSessionFamilies", self.names["family"])):
            if any(item.get("name") == selected for item in config["toolTask"].get(field, [])):
                raise ValueError(f"{field} already contains {selected}; refusing attachment before delegation")
        grants = {}
        for label, target, parent, child, role in [
            ("app", app["app"], app["appOwnerCapability"], caps["appObserve"], "tool"),
            ("manifest", app["packageManifest"], app["packageOwnerCapability"], caps["manifestObserve"], "tool"),
            ("snapshot", app["snapshotManifest"], app["snapshotOwnerCapability"], caps["snapshotObserve"], "tool"),
            ("discovery-ticket", ticket["resource"], request["spec"]["ticketOwnerCapability"], caps["bootstrapTicketObserve"], "tool"),
            ("controller-app", app["app"], app["appOwnerCapability"], caps["controllerAppObserve"], "controller"),
            ("controller-manifest", app["packageManifest"], app["packageOwnerCapability"], caps["controllerManifestObserve"], "controller"),
        ]:
            grants[label] = self.delegate_observe(label, target, parent, child, a[role]["subject"])
        stage = self.controller_stage.parent
        stage.mkdir(mode=0o700)
        refs = stage / "state/shared-app-refs"
        refs.mkdir(mode=0o700, parents=True)
        birth = Path(self.application["birthAttempt"])
        issue = Path(self.application["bootstrapTicketAttempt"])
        prefix = self.names["route"]
        birth_name, ticket_name = prefix + "-birth.bin", prefix + "-bootstrap.bin"
        write(refs / birth_name, (birth / "call.bin").read_bytes())
        write(refs / ticket_name, (issue / "ingress.bin").read_bytes())
        shared = {"name": self.bootstrap_name, "applicationFamily": "oracle",
                  "appTarget": app["app"], "manifestTarget": app["packageManifest"], "snapshotTarget": app["snapshotManifest"],
                  "ticketTarget": ticket["resource"], "appObserveCapability": caps["appObserve"],
                  "manifestObserveCapability": caps["manifestObserve"], "snapshotObserveCapability": caps["snapshotObserve"],
                  "ticketObserveCapability": caps["bootstrapTicketObserve"],
                  "birth": {**receipt(read(birth / "outcome.json")), "call": str(home / "state/shared-app-refs" / birth_name),
                            "callSha256": sha(birth / "call.bin")},
                  "issue": {**read(issue / "receipt-anchor.json")["receipt"], "kind": "grainBackedEvent22",
                            "ingress": str(home / "state/shared-app-refs" / ticket_name), "ingressSha256": sha(issue / "ingress.bin")}}
        family = {"name": self.names["family"], "applicationFamily": "oracle", "kind": "api",
                  "participantSubject": a["controller"]["subject"], "profile": c["sessionProfile"],
                  "namespace": {"session": a["session"], "descriptor": a["descriptor"],
                       **{k + "Capability": caps[k] for k in ("sessionOwner", "sessionControl", "descriptorOwner", "descriptorControl")}},
                  "maxBirths": 1, "maxResultBytes": 65536}
        append_named(config["toolTask"], "registeredSharedApplications", shared)
        append_named(config["toolTask"], "allowedSessionFamilies", family)
        config["toolTask"]["currentBirthHostSha256"] = sha(self.host)
        write(self.controller_stage, config)
        result = self.root / "controller-stage.json"
        write(result, {"protocol": "mini-application-attachment-stage-v1", "stage": str(stage), "home": str(home),
                       "configSha256": sha(self.controller_stage), "discoveryGrantReceipts": grants,
                       "nextTool": {"name": "mini_create_application_session", "arguments": {
                           "family": self.names["family"], "application": shared["name"]}}})
        return result

    def create_session(self):
        """Invoke once when this caller legitimately has direct control-socket access."""
        runtime = self.absolute(self.contract["paths"]["grainRuntime"])
        config = read(self.contract["paths"]["controllerConfig"])
        if config != read(self.controller_stage):
            raise ValueError("install the prepared controller config before creating its session")
        request_id = secrets.token_hex(16)
        arguments = self.calls / "arguments.json"
        write(arguments, read(self.root / "controller-stage.json")["nextTool"]["arguments"])
        write(self.calls / "request.json", {"requestId": request_id, "socket": config["controlSocket"],
                  "name": "mini_create_application_session", "arguments": str(arguments)})
        self.call("session", [runtime, "tool", config["controlSocket"], "hard", request_id,
                              "mini_create_application_session", arguments])
        return self.calls / "session.stdout"

    def status(self):
        """Inventory with exact read-only recovery argv; never submit replacements."""
        phases = []
        for directory in sorted(self.root.glob("native-*")):
            lookups = []
            for kind, command in (("ticket-issue", "grain-share-issue-lookup"),
                                  ("grant-issue", "agent-lifetime-grant-lookup"),
                                  ("enrollment", "session-enrollment-lookup")):
                attempt = directory / kind
                if attempt.is_dir():
                    argv = [str(self.mini), command]
                    if kind == "ticket-issue":
                        argv.extend(["--socket", str(self.operator)])
                    argv.extend(["--attempt", str(attempt)])
                    lookups.append(argv)
            for attempt in sorted(directory.iterdir()):
                if attempt.is_dir() and (attempt / "attempt.json").is_file():
                    lookups.append([str(self.mini), "retry", "--attempt", str(attempt), "--mode", "lookup"])
            request = directory / "request.json"
            if request.exists():
                try:
                    selected = read(request)
                    lookups.append([self.contract["paths"]["grainRuntime"], "tool-result", selected["socket"], selected["requestId"]])
                except (OSError, ValueError, KeyError) as error:
                    self.pin_diagnostics = getattr(self, "pin_diagnostics", []) + [{"input": str(request), "problem": str(error)}]
            phases.append({"phase": directory.name, "path": str(directory), "lookupCommands": lookups,
                           "attempts": [str(p) for p in sorted(directory.iterdir()) if p.is_dir()]})
        return {"protocol": "mini-application-attachment-status-v1", "outputDir": str(self.root), "phases": phases,
                "pinDiagnostics": getattr(self, "pin_diagnostics", []),
                "recovery": "Run the listed native lookup commands against retained attempts. No phase is retried automatically. Resolve partial observations/reservations from their retained Mini command and attempt before continuing; never replace uncertain coordinates."}

    def call(self, label, args):
        # Logs contain native source/output, never raw signing key bytes.
        write(self.calls / (label + "-command.json"), [str(x) for x in args])
        with (self.calls / (label + ".stdout")).open("xb") as out, (self.calls / (label + ".stderr")).open("xb") as err:
            result = subprocess.run([str(x) for x in args], stdout=out, stderr=err)
        write(self.calls / (label + "-exit.json"), {"returncode": result.returncode})
        if result.returncode:
            raise RuntimeError(f"{label} failed ({result.returncode}); retain attempt, do not resubmit")

    def query(self, label, subject, target, capability, key, view="resource"):
        intent = self.calls / (label + "-intent.json")
        output = self.calls / label
        write(intent, {"subject": subject, "nonce": str(secrets.randbits(120)),
                       "purpose": {"type": "query", "kind": "object", "target": target, "view": view},
                       "grants": [{"kind": "object", "target": target, "capability": capability}]})
        self.call(label, [self.mini, "query", "--host", self.host, "--config", self.config,
                         "--socket", self.public, "--intent", intent, "--key", key, "--view", view, "--dir", output])
        return output

    def delegate_observe(self, label, target, parent, child, holder):
        key = Path(self.issuer["keyPath"])
        capability = self.query(label + "-capability", self.issuer["subject"], target, parent, key, "capability")
        inspected = self.calls / (label + "-capability.json")
        self.call(label + "-inspect-capability", [self.host, self.config, "inspect", "view-object-capability",
                                                   capability / "view.bin", inspected])
        current = self.query(label + "-current", self.issuer["subject"], target, parent, key)
        head = read(inspected)["head"]
        challenge = read(current / "challenge.json")
        grant = dict(head, id=child, parent=head["id"], holder={"type": "subject", "subject": holder},
                     targets=[target], verbs=["observe"], ancestors=sorted(set(head["ancestors"] + [head["id"]])))
        intent = {"subject": self.issuer["subject"], "nonce": str(secrets.randbits(120)),
                  "purpose": {"type": "prepare", "draft": {"type": "delegate-source", "command": {
                      "kind": "object", "domain": challenge["domain"], "semantics": challenge["semantics"],
                      "subject": self.issuer["subject"], "nonce": str(secrets.randbits(120)),
                      "expectedTargetRoot": read(current / "view.json")["cell"]["root"],
                      "parentId": head["id"], "target": target, "child": grant}}},
                  "grants": [{"kind": "object", "target": target, "capability": head["id"]}]}
        source = self.calls / (label + "-intent.json")
        write(source, intent)
        attempt = self.calls / (label + "-attempt")
        self.call(label + "-submit", [self.mini, "submit", "--host", self.host, "--config", self.config,
                                     "--socket", self.public, "--intent", source, "--key", key, "--dir", attempt])
        return receipt(read(attempt / "outcome.json"))

    def slot_signers(self, slots, header_name):
        known = {s["keyId"]: s for s in self.signers}
        answer = []
        for slot in slots:
            signing = slot["signing"]
            if signing["decoded"] is not True or signing["algorithm"] != known.get(signing["keyId"], {}).get("algorithm") or signing["keyEpoch"] != known.get(signing["keyId"], {}).get("keyEpoch"):
                raise ValueError("source signing slot is outside enrolled custody")
            selected = known[signing["keyId"]]
            key, public = Path(selected["keyPath"]), Path(selected["publicKeyPath"])
            if len(key.read_bytes()) != 32 or len(public.read_bytes()) != 32:
                raise ValueError("enrolled signer key shape differs")
            header = bytes.fromhex(slot[header_name])
            if not header:
                raise ValueError("empty source signing header")
            answer.append({"role": slot["role"], "index": slot["index"], "keyId": signing["keyId"],
                           "keyEpoch": signing["keyEpoch"], "publicKey": public.read_bytes().hex(),
                           "headerSha256": hashlib.sha256(header).hexdigest(), "keyPath": str(key)})
        return answer

    def reserve_issuer_tool(self):
        key = Path(self.issuer["keyPath"])
        tool = self.issuer["tool"]
        current = self.query("issuer-tool", self.issuer["subject"], tool["task"], tool["observeCapability"], key)
        view = read(current / "view.json")
        nonce = str(secrets.randbits(120))
        intent = {"grain": {"task": tool["task"], "subject": self.issuer["subject"], "capability": tool["capability"], "observeCapability": tool["observeCapability"],
                  "schemaVersion": "1", "expectedTargetRoot": view["cell"]["root"],
                  "context": {"operationId": nonce, "payload": "Oracle agent ticket issuance"},
                  "before": {k: view["cell"]["grain"][k] for k in ("generation", "status", "remaining", "reserved")},
                  "operation": {"type": "reserve", "amount": self.issuer["reserveAmount"]}, "publications": []},
                  "grants": [{"kind": "object", "target": tool["task"], "capability": tool["observeCapability"]}], "intentNonce": nonce}
        source = self.calls / "issuer-reserve.json"
        write(source, intent)
        attempt = self.calls / "issuer-reserve"
        self.call("issuer-reserve", [self.mini, "submit", "--host", self.host, "--config", self.config,
                  "--socket", self.public, "--intent", source, "--intent-kind", "grain-intent", "--key", key, "--dir", attempt])
        receipt(read(attempt / "outcome.json"))

    def issue_grant(self, session_result):
        """Issue actual event22 and event27 from a completed runtime session tool.

        The native author rereads the actual installed session; this result
        merely selects our allocated session and links acceptance evidence.
        """
        result = read(session_result)
        if result.get("type") != "tool-complete" or result.get("isError") is not False or result["result"].get("isError") is not False:
            raise ValueError("session foreground tool did not complete")
        body = json.loads(result["result"]["text"])
        a, caps = self.agent, self.agent["plannedCaps"]
        if body.get("type") != "confirmed-mini-application-birth-v1" or body.get("route") != "session":
            raise ValueError("runtime did not return a session birth")
        if {r["target"] for r in body["bornResources"]} != {a["session"], a["descriptor"]}:
            raise ValueError("runtime session birth differs from allocated pair")
        write(self.calls / "session-tool-result.json", Path(session_result).read_bytes())
        controller_key = self.role_key("controller")
        current = self.query("controller-parent", a["controller"]["subject"], a["controller"]["task"],
                             caps["parentOwner"], controller_key)
        generation = read(current / "view.json")["cell"]["grain"]["generation"]
        self.query("agent-session", a["controller"]["subject"], a["session"], caps["sessionOwner"], controller_key)
        app = read(self.application["birthSource"])["applicationGrainBirth"]["applicationBirth"]["application"]
        app_current = self.query("issuing-app", self.issuer["subject"], app["app"], app["appOwnerCapability"], Path(self.issuer["keyPath"]))
        entries = read(app_current / "view.json")["cell"]["entries"]
        package_version = next(e["value"] for e in entries if e["key"]["field"] == "2")
        package_dir = Path(self.application["packageDirectory"])
        schema = read(package_dir / "schema-inspection.json")
        interface = next(i for i in read(package_dir / "descriptor-inspection.json")["interfaces"] if i["kind"] == "api")
        launch_root = read(package_dir.parent / "launch-inspection.json")["root"]
        ceiling = {"basis": {"type": "role", "id": "0"}, "added": [], "removed": [],
                   "roleSchemaRoot": schema["root"], "roleVersion": schema["version"]}
        request = {"spec": {"ticket": {"resource": a["ticket"],
            "scope": {"app": app["app"], "packageVersion": package_version, "packageRoot": launch_root,
                      "interfaceId": interface["id"], "interfaceVersion": interface["version"],
                      "interfaceRoot": interface["root"], "schemaRoot": schema["root"], "schemaVersion": schema["version"]},
            "participant": {"session": a["session"], "descriptorResource": a["descriptor"], "kind": "api",
                            "subject": a["controller"]["subject"], "origin": {"type": "agent", "task": a["controller"]["task"], "generation": generation},
                            "sessionCapability": caps["sessionOwner"], "appObserveCapability": caps["controllerAppObserve"],
                            "ticketObserveCapability": caps["ticketObserve"]},
            "ceiling": ceiling, "issueNonce": str(secrets.randbits(120)), "notAfter": "1000000000"},
            "issuer": self.issuer["subject"], "appDelegateCapability": app["appOwnerCapability"],
            "ticketOwnerCapability": caps["ticketOwner"], "ticketControlCapability": caps["ticketControl"]},
            "payer": self.issuer["payer"], "funding": self.issuer["funding"], "sourceCapabilities": self.issuer["sourceCapabilities"],
            "tool": self.issuer["tool"], "parent": self.issuer["parent"]}
        self.reserve_issuer_tool()
        source = self.calls / "ticket-request.json"
        write(source, request)
        preview = self.calls / "ticket-preview"
        self.call("ticket-plan", [self.mini, "grain-share-issue-plan", "--host", self.host, "--config", self.config,
                                   "--socket", self.operator, "--request", source, "--dir", preview])
        inspected = read(preview / "request-inspected.json")
        approved = {"type": "minidregg-grain-share-issue-approval-v1", "requestSha256": sha(preview / "request.bin"),
                    "canonicalSpec": inspected["canonicalSpec"], "issuer": inspected["spec"]["issuer"],
                    "participantSubject": inspected["spec"]["ticket"]["participant"]["subject"],
                    "appDelegateCapability": inspected["spec"]["appDelegateCapability"],
                    "ticketResource": inspected["spec"]["ticket"]["resource"],
                    **{key: inspected[key] for key in ("payer", "funding", "sourceCapabilities", "tool", "parent")},
                    "signers": self.slot_signers(read(preview / "plan-inspected.json")["slots"], "header")}
        approval = self.calls / "ticket-approval.json"
        write(approval, approved)
        ticket_attempt = self.calls / "ticket-issue"
        self.call("ticket-prepare", [self.mini, "grain-share-issue-prepare", "--host", self.host, "--config", self.config,
                  "--socket", self.operator, "--request", source, "--approval", approval, "--dir", ticket_attempt])
        self.call("ticket-submit", [self.mini, "grain-share-issue-submit", "--socket", self.operator, "--attempt", ticket_attempt])
        self.call("ticket-lookup", [self.mini, "grain-share-issue-lookup", "--socket", self.operator, "--attempt", ticket_attempt])
        issued = read(ticket_attempt / "receipt-anchor.json")["receipt"]
        looked_up_ticket = read(self.calls / "ticket-lookup.stdout")
        if looked_up_ticket.get("confirmation") != "replayed" or receipt(looked_up_ticket) != issued or int(issued["acceptedCount"]) <= 0:
            raise ValueError("ticket lookup differs from exact accepted issue receipt")
        issue_index = str(int(issued["acceptedCount"]) - 1)
        # Read the source-authored ticket digest; never reconstruct its hash.
        self.call("ticket-source-plan", [self.host, self.config, "inspect", "application-share-issue-grain-plan",
                                          ticket_attempt / "plan.bin", self.calls / "ticket-source-plan.json"])
        spec = read(self.calls / "ticket-source-plan.json")["request"]["spec"]
        self.delegate_observe("agent-ticket-controller", a["ticket"], caps["ticketOwner"], caps["ticketObserve"], a["controller"]["subject"])
        self.delegate_observe("agent-ticket-tool", a["ticket"], caps["ticketOwner"], caps["agentTicketToolObserve"], a["tool"]["subject"])
        grant_request = {"grant": {"source": {"resource": a["persistentGrant"], "issueIndex": issue_index,
                         "issueReceipt": issued, "ticketResource": a["ticket"], "ticketDigest": spec["ticket"]["ticketDigest"]},
                         "participant": {"app": app["app"], "session": a["session"], "subject": a["controller"]["subject"],
                         "parentTask": a["controller"]["task"], "originalGeneration": generation, "grantObserveCapability": caps["grantObserve"]},
                         "approval": {"issuer": spec["issuer"], "delegateCapability": spec["appDelegateCapability"],
                                      "ceiling": ceiling, "nonce": str(secrets.randbits(120))}},
                         "grantOwnerCapability": caps["grantOwner"], "grantControlCapability": caps["grantControl"],
                         "payer": self.issuer["payer"], "funding": self.issuer["funding"], "sourceCapabilities": self.issuer["sourceCapabilities"]}
        grant_source = self.calls / "grant-request.json"
        write(grant_source, grant_request)
        grant_attempt = self.calls / "grant-issue"
        self.call("grant-plan", [self.mini, "agent-lifetime-grant-plan", "--host", self.host, "--config", self.config,
                  "--operator-socket", self.operator, "--request", grant_source, "--dir", grant_attempt])
        plan = read(grant_attempt / "plan-inspected.json")
        if bytes.fromhex(plan["canonicalPlanHex"]) != (grant_attempt / "plan.bin").read_bytes():
            raise ValueError("source grant plan bytes differ")
        grant_approval = self.calls / "grant-approval.json"
        write(grant_approval, {"type": "minidregg-agent-lifetime-grant-approval-v1",
              "requestSha256": sha(grant_attempt / "request.bin"), "planSha256": sha(grant_attempt / "plan.bin"),
              **{key: plan[key] for key in ("request", "birthBoundary", "finalizedDraftHex")},
              "signers": self.slot_signers(plan["birthSlots"] + [plan["appSlot"]], "headerHex")})
        self.call("grant-seal", [self.mini, "agent-lifetime-grant-seal", "--attempt", grant_attempt, "--approval", grant_approval])
        self.call("grant-submit", [self.mini, "agent-lifetime-grant-submit", "--attempt", grant_attempt])
        self.call("grant-lookup", [self.mini, "agent-lifetime-grant-lookup", "--attempt", grant_attempt])
        looked_up = read(self.calls / "grant-lookup.stdout")
        confirmed = receipt(looked_up)
        if looked_up["confirmation"] != "replayed":
            raise ValueError("grant lacks exact native replay confirmation")
        write(self.root / "issued-grant.json", {"protocol": "mini-oracle-issued-agent-grant-v1", "ticketAttempt": str(ticket_attempt),
              "ticketReceipt": issued, "grantAttempt": str(grant_attempt), "grantReceipt": confirmed,
              "sessionToolResultSha256": sha(session_result), "originalGeneration": generation})
        return self.root / "issued-grant.json"

    def prepare_route(self, repo, layout_file):
        layout = read(layout_file)
        a, caps = self.agent, self.agent["plannedCaps"]
        self.validate_layout(layout, read(self.controller_stage))
        for field in ("controllerHome", "listenerSocket", "reverseSocket", "operatorSocket"):
            if not Path(layout[field]).is_absolute():
                raise ValueError("controller layout paths must be absolute")
        if not isinstance(layout["controllerUid"], int) or layout["controllerUid"] in (0, os.getuid()):
            raise ValueError("dedicated non-root controller UID required")
        issued = read(self.root / "issued-grant.json")
        grant = Path(issued["grantAttempt"])
        lookups = sorted(grant.glob("lookup-????.outcome.json"))
        if not lookups:
            raise ValueError("retained native grant lookup absent")

        def pin(role, index, actor):
            return {"role": str(role), "index": str(index), "keyId": a[actor]["keyId"], "keyEpoch": self.role_signer(actor)["keyEpoch"],
                    "publicKeyHex": Path(self.role_signer(actor)["publicKeyPath"]).read_bytes().hex(),
                    "seedPath": str(self.role_key(actor))}
        # These are operator key-selection pins, not signatures or authority.
        # NativeHost.prepareInvokeOn signs session/parent target+observation,
        # then authority; ApplicationDispatchAuthoring adds four observations.
        app_signers = [pin(role, index, "controller") for role, index in
                       [(4, 0), (4, 1), (8, 0), (8, 1), (1, 0), (9, 0), (9, 1), (9, 2), (9, 3)]]
        payer = [pin(role, 0, "dispatch") for role in (4, 8, 1)]
        for signer in payer:
            del signer["seedPath"]
        pins = {"controllerRouteName": self.names["application"], "socketPath": layout["listenerSocket"],
                "hostUid": os.getuid(), "hostUnit": None, "signedApiPath": "/",
                "packageManifest": self.allocation["packageManifest"], "snapshotManifest": self.allocation["snapshotManifest"],
                "sessionObserveCapability": caps["sessionOwner"], "manifestObserveCapability": caps["controllerManifestObserve"],
                "enrollmentObserveCapability": caps["descriptorOwner"], "parentCapability": caps["parentOwner"],
                "parentObserve": caps["parentOwner"], "purseCapability": caps["dispatchOwner"], "purseObserve": caps["dispatchOwner"],
                "purseResource": a["dispatch"]["task"], "payerSubject": a["dispatch"]["subject"],
                "reserveAmount": "1", "maximumCharge": "1", "appSigners": app_signers,
                "grantSigner": pin(9, 4, "controller"), "payerPins": payer}
        pins_file = self.calls / "operator-pins.json"
        write(pins_file, pins)
        route_dir = self.calls / "source-route"
        self.call("render-custody", ["sh", repo / "scripts/spk-platform/prepare-lifetime-route.sh", "--custody-only",
            self.host, self.config, grant, lookups[-1], pins_file, route_dir, sha(self.host),
            self.allocation_path, a["route"]])
        request = {"protocol": "mini-spk-grain-agent-route-v1", "name": self.names["route"], "signedApiPath": "/",
            "socket": layout["listenerSocket"], "controllerUid": layout["controllerUid"],
            "custody": str(route_dir / "resident-custody-v3.json"), "reverseSocket": layout["reverseSocket"],
            "routeName": self.names["application"], "displayName": self.names["display"], "preferredHandle": self.names["handle"],
            "reverseTimeoutSeconds": 1740, "controllerWorkerWallSeconds": 1800}
        request_file = self.calls / "route-request.json"
        write(request_file, request)
        profile = self.profile
        self.call("route-register", [self.spk_host, "grain", "agent-route", profile, self.allocation["app"], request_file])
        write(self.root / "registered-agent-route.json", {"protocol": "mini-oracle-registered-agent-route-v1",
            "layout": layout, "layoutSha256": sha(layout_file), "pins": str(pins_file), "sourceRoute": str(route_dir),
            "grantAttempt": str(grant), "lookup": str(lookups[-1]), "request": str(request_file),
            "registration": read(self.calls / "route-register.stdout")})
        return self.root / "registered-agent-route.json"

    def activate(self, repo, start_result):
        start = read(start_result)
        a, caps = self.agent, self.agent["plannedCaps"]
        if start.get("protocol") != "mini-spk-grain-start-v1" or start.get("app") != self.allocation["app"]:
            raise ValueError("actual native START result for selected app required")
        profile = self.profile
        def check_current(label):
            self.call(label, [self.spk_host, "grain", "status", profile, self.allocation["app"]])
            require_current_start(start, read(self.calls / (label + ".stdout")))
        check_current("current-start-before-enrollment")
        registration = read(self.root / "registered-agent-route.json")
        layout = registration["layout"]
        home = Path(layout["controllerHome"])

        # Session enrollment is source-owned and generation-specific. Renew by
        # the ordinary owner close followed by the same native event28 path.
        observed = self.query("session-before-enrollment", a["controller"]["subject"], a["session"], caps["sessionOwner"], self.role_key("controller"))
        view = read(observed / "view.json")
        fields = {entry["key"]["field"]: entry["value"] for entry in view["cell"]["entries"]}
        if fields["3"] == "5":
            nonce = str(secrets.randbits(120))
            close = {"subject": a["controller"]["subject"], "nonce": nonce,
                "grants": [{"kind": "object", "target": a["session"], "capability": caps["sessionOwner"]}],
                "purpose": {"type": "prepare", "draft": {"type": "invoke", "command": {
                    "subject": a["controller"]["subject"], "nonce": nonce, "targets": [{
                        "kind": "object", "target": a["session"], "capability": caps["sessionOwner"],
                        "observeCapability": caps["sessionOwner"], "schemaVersion": "1", "expectedTargetRoot": view["cell"]["root"],
                        "payload": {"type": "scalar", "actions": [
                            {"type": "write", "key": {"type": "object", "resource": a["session"], "field": field},
                             "expected": fields[field], "value": str(int(fields[field]) + 1)} for field in ("2", "3")]}}]}}}}
            write(self.calls / "session-close.json", close)
            self.call("session-close", [self.mini, "submit", "--host", self.host, "--config", self.config,
                "--socket", self.public, "--intent", self.calls / "session-close.json", "--key", self.role_key("controller"),
                "--dir", self.calls / "session-close"])
            receipt(read(self.calls / "session-close/outcome.json"))
        issued = read(self.root / "issued-grant.json")
        ticket = read(Path(issued["ticketAttempt"]).parent / "ticket-request.json")["spec"]["ticket"]
        request = {"issueIndex": str(int(issued["ticketReceipt"]["acceptedCount"]) - 1), "ticketResource": a["ticket"],
                   "packageManifest": self.allocation["packageManifest"], "role": ticket["ceiling"],
                   "descriptorCapability": caps["descriptorOwner"], "sessionObserveCapability": caps["sessionOwner"],
                   "descriptorObserveCapability": caps["descriptorOwner"], "manifestObserveCapability": caps["controllerManifestObserve"],
                   "nonce": str(secrets.randbits(120))}
        request_file = self.calls / "enrollment-request.json"
        write(request_file, request)
        attempt = self.calls / "enrollment"
        self.call("enrollment-plan", [self.mini, "session-enrollment-plan", "--host", self.host, "--config", self.config,
            "--operator-socket", self.operator, "--request", request_file, "--dir", attempt])
        plan = read(attempt / "plan-inspected.json")
        approval = self.calls / "enrollment-approval.json"
        write(approval, {"type": "minidregg-session-enrollment-approval-v1", "requestSha256": sha(attempt / "request.bin"),
            "planSha256": sha(attempt / "plan.bin"), "planInspectionSha256": sha(attempt / "plan-inspected.json"),
            "signers": self.slot_signers(plan["slots"], "headerHex")})
        self.call("enrollment-seal", [self.mini, "session-enrollment-seal", "--attempt", attempt, "--approval", approval])
        self.call("enrollment-submit", [self.mini, "session-enrollment-submit", "--attempt", attempt])
        self.call("enrollment-lookup", [self.mini, "session-enrollment-lookup", "--attempt", attempt])
        looked_up_enrollment = read(self.calls / "enrollment-lookup.stdout")
        accepted_enrollment = read(attempt / "receipt.json")
        if looked_up_enrollment.get("confirmation") != "replayed" or receipt(looked_up_enrollment) != {
            key: accepted_enrollment[key] for key in ("transactionId", "eventId", "acceptedCount", "worldRoot")
        }:
            raise ValueError("enrollment lookup differs from exact accepted receipt")
        pins = read(registration["pins"])
        pins["hostUnit"] = start["unit"]
        pins_file = self.calls / "operator-pins.json"
        write(pins_file, pins)
        routes = self.calls / "source-route"
        self.call("render-controller-route", ["sh", repo / "scripts/spk-platform/prepare-lifetime-route.sh",
            self.host, self.config, registration["grantAttempt"], registration["lookup"], pins_file,
            routes, sha(self.host), self.allocation_path, a["route"]])
        if (routes / "resident-custody-v3.json").read_bytes() != (Path(registration["sourceRoute"]) / "resident-custody-v3.json").read_bytes():
            raise ValueError("controller route reinspection changed registered resident custody")
        bundle = self.calls / "controller-update"
        bundle.mkdir(mode=0o700)
        grant_relative = getattr(self, "grant_relative", Path("state/attachments") / self.names["route"] / "grant")
        (bundle / "state/shared-app-refs").mkdir(mode=0o700, parents=True)
        (bundle / grant_relative).mkdir(mode=0o700, parents=True)
        ticket_name = getattr(self, "ticket_name", self.names["route"] + "-ticket.bin")
        config = read(self.controller_stage)
        reference = dict(next(ref for ref in config["toolTask"]["registeredSharedApplications"] if ref["name"] == self.bootstrap_name))
        ticket_call = Path(issued["ticketAttempt"]) / "ingress.bin"
        reference.update(name=self.names["application"], ticketTarget=a["ticket"], ticketObserveCapability=caps["agentTicketToolObserve"],
                         issue={**issued["ticketReceipt"], "kind": "grainBackedEvent22", "ingress": str(home / "state/shared-app-refs" / ticket_name),
                                "ingressSha256": sha(ticket_call)})
        append_named(config["toolTask"], "registeredSharedApplications", reference)
        write(bundle / "state/shared-app-refs" / ticket_name, ticket_call.read_bytes())
        for name in ("seal.json", "call.bin", "submit-marker.json", "receipt.json"):
            write(bundle / grant_relative / name, (Path(issued["grantAttempt"]) / name).read_bytes())
        route = read(routes / "controller-route-v3.json")
        route["grantAttemptDir"] = str(home / grant_relative)
        append_named(config["toolTask"], "allowedApplicationLifetimeRoutes", route)
        append_named(config["toolTask"], "applicationServices", {"application": self.names["application"], "protocol": self.names["serviceProtocol"]}, "application")
        config["toolTask"]["lifetimeApiHostSha256"] = sha(self.host)
        self.validate_layout(layout, config)
        check_current("current-start-before-publication")
        write(bundle / "controller.json", config)
        write(self.calls / "activation.json", {"protocol": "mini-oracle-agent-activation-v1", "bundle": str(bundle),
            "unit": start["unit"], "generation": start["generation"], "enrollmentReceipt": read(attempt / "receipt.json"),
            "configSha256": sha(bundle / "controller.json"), "next": "install stopped controller update, then start and probe"})
        return self.calls / "activation.json"


def render_host_config(config_path, allocation_path, output):
    """Render operator authoring selectors only, before Host/profile installation.

    This neither changes native Config semantics nor establishes authority. The
    operator installs the resulting settings on its stopped Host and repins the
    application profile before opening an attachment. Native admission remains
    responsible for the grant, ticket, payer and participant relationships.
    """
    config, allocation = read(config_path), read(allocation_path)
    if len(allocation["agents"]) != 1:
        raise ValueError("one selected controller allocation required")
    a = allocation["agents"][0]
    caps = a["plannedCaps"]
    def natural(value):
        if not isinstance(value, str) or not value.isascii() or not value.isdecimal() or value.startswith("0"):
            raise ValueError("canonical positive decimal selector required")
        return int(value)
    target = {"legacy": {key: natural(value) for key, value in {
        "ticketResource": a["ticket"], "packageManifest": allocation["packageManifest"],
        "snapshotManifest": allocation["snapshotManifest"], "sessionObserve": caps["sessionOwner"],
        "manifestObserve": caps["controllerManifestObserve"], "enrollmentObserve": caps["descriptorOwner"],
        "parentTask": a["controller"]["task"], "parentCapability": caps["parentOwner"], "parentObserve": caps["parentOwner"],
        "purseTask": a["dispatch"]["task"], "purseCapability": caps["dispatchOwner"], "purseObserve": caps["dispatchOwner"],
        "payerSubject": a["dispatch"]["subject"]}.items()},
        "grantResource": natural(a["persistentGrant"]), "grantObserveCapability": natural(caps["grantObserve"])}
    target["legacy"].update(reserveAmount=1, maximumCharge=1)
    existing = config.get("agentLifetimeDispatchTargets") or []
    overlap = [entry for entry in existing if entry["grantResource"] == target["grantResource"] or
               entry["legacy"]["ticketResource"] == target["legacy"]["ticketResource"]]
    if overlap and overlap != [target]:
        raise ValueError("existing lifetime target conflicts with selected grant or ticket")
    config["agentLifetimeDispatchTargets"] = existing if overlap else existing + [target]
    write(output, config)
    return output


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "render-host-config":
        if len(sys.argv) != 5:
            raise SystemExit("usage: application-attachment.py render-host-config CONFIG ALLOCATION NEW_OUTPUT")
        os.umask(0o077)
        paths = [Attachment.absolute(p) for p in sys.argv[2:]]
        print(render_host_config(*paths))
        return
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("contract", type=Path, help="absolute mini-application-attachment-v1 JSON input")
    parser.add_argument("phase", choices=("prepare-config", "create-session", "issue-grant", "prepare-route", "activate", "status"))
    parser.add_argument("--input", type=Path, help="retained session tool result, controller layout, or native START result")
    args = parser.parse_args()
    if not args.contract.is_absolute() or (args.input is not None and not args.input.is_absolute()):
        parser.error("contract and phase input must be absolute")
    if args.phase in ("issue-grant", "prepare-route", "activate") and args.input is None:
        parser.error("this phase requires --input")
    phase = args.phase
    if phase == "activate":
        generation = read(args.input).get("generation", "")
        if not isinstance(generation, str) or not generation.isascii() or not generation.isdecimal():
            parser.error("native START generation absent")
        phase += "-" + generation
    os.umask(0o077)
    attachment = Attachment(args.contract, phase)
    if args.phase == "prepare-config":
        result = attachment.prepare_config()
    elif args.phase == "create-session":
        result = attachment.create_session()
    elif args.phase == "issue-grant":
        result = attachment.issue_grant(args.input)
    elif args.phase == "prepare-route":
        result = attachment.prepare_route(attachment.repo, args.input)
    elif args.phase == "activate":
        result = attachment.activate(attachment.repo, args.input)
    else:
        result = attachment.status()
    print(json.dumps(result, indent=2) if isinstance(result, dict) else result)


if __name__ == "__main__":
    main()
