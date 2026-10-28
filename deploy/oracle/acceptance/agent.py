#!/usr/bin/env python3
"""Operator harness for Oracle agent provisioning; Mini admits every grant.

This is not a verifier. It retains native attempts and refuses implicit retries.
It never writes a Store, controller journal, or a synthetic birth receipt.
"""
import argparse
import json
import os
from pathlib import Path
import secrets

import importlib.util

_shared_spec = importlib.util.spec_from_file_location("application_attachment", Path(__file__).resolve().parents[3] / "scripts/application-attachment.py")
_shared = importlib.util.module_from_spec(_shared_spec)
_shared_spec.loader.exec_module(_shared)
read, write, sha, receipt = _shared.read, _shared.write, _shared.sha, _shared.receipt
require_current_start, controller_host_metadata = _shared.require_current_start, _shared.controller_host_metadata


class Operator(_shared.Attachment):
    def __init__(self, run, phase="setup"):
        self.run = run
        self.root = run / "agent-lifetime"
        self.workroom = run / "world/store/base/workroom"
        self.config = self.workroom / "deployment/pinned-config.json"
        self.host = run / "bin/minidregg-host"
        self.mini = run / "bin/mini"
        self.public = run / "world/sock/participant/host.sock"
        self.operator = run / "world/sock/operator/host.sock"
        self.evidence = run / "world/evidence"
        self.allocation = read(self.root / "allocation.json")
        if len(self.allocation["agents"]) != 1:
            raise ValueError("one explicitly allocated Oracle controller required")
        self.agent = self.allocation["agents"][0]
        self.calls = self.root / ("native-" + phase)
        self.calls.mkdir(mode=0o700)
        self.allocation_path = self.root / "allocation.json"
        self.application = {
            "birthSource": str(self.evidence / "a-app-author/source.json"),
            "birthAttempt": str(self.evidence / "a-app-attempt"),
            "bootstrapTicketRequest": str(self.evidence / "a-ticket-9120/request.json"),
            "bootstrapTicketAttempt": str(self.evidence / "a-ticket-9120/issue"),
        }
        profile = read(self.evidence / "profile-result.json")
        self.profile = profile["profilePath"]
        self.application["packageDirectory"] = str(Path(profile["stateRoot"]) / "apps" / self.allocation["app"] / "install/launch-descriptor/package-v1")
        self.spk_host = run / "bin/spk-host"
        self.controller_stage = self.root / "controller-stage/controller.json"
        self.names = {"application": "oracle-app", "family": "oracle-session", "route": "oracle-agent-v1",
                      "display": "Oracle agent", "handle": "oracle-agent", "serviceProtocol": "oracle-operations-v1"}
        self.bootstrap_name = "oracle-bootstrap-app"
        self.grant_relative = Path("state/oracle-grant")
        self.ticket_name = "agent-ticket.bin"
        self.issuer = {"subject": "8", "keyPath": str(self.workroom / "tool.key"), "payer": "8", "funding": [],
                       "sourceCapabilities": ["42"], "reserveAmount": "3",
                       "tool": {"task": "7902", "capability": "81", "observeCapability": "81"},
                       "parent": {"task": "7901", "capability": "73", "observeCapability": "73"}}
        self.signers = [{"keyId": kid, "keyEpoch": "2", "algorithm": "1", "keyPath": str(directory / (role + ".key")),
                         "publicKeyPath": str(directory / (role + ".pub"))}
                        for kid, directory, role in [("8008", self.workroom, "tool"), ("7007", self.workroom, "controller")] +
                        [(self.agent[role]["keyId"], self.workroom / "agents" / self.agent["route"], role)
                         for role in ("controller", "tool", "dispatch", "provider")]]


    def dispatch_config(self, home, layout):
        a, caps = self.agent, self.agent["plannedCaps"]
        if layout["controllerHome"] != str(home):
            raise ValueError("dispatch layout names another controller home")
        return {"task": a["dispatch"]["task"], "subject": a["dispatch"]["subject"],
            "capability": caps["dispatchOwner"], "queryCapability": caps["dispatchOwner"],
            "custodyKey": str(home / "custody/dispatch.key"),
            "parentCapability": caps["parentDispatchWitness"], "parentObserveCapability": caps["parentDispatchWitness"],
            "reserve": "1", "charge": "1", "socketPath": layout["reverseSocket"], "hostUid": os.getuid(),
            "operatorSocket": layout["operatorSocket"], "operatorPeerUid": layout["operatorPeerUid"],
            "reserveSigner": {"role": "4", "index": "0",
                "publicKey": (self.workroom / "agents" / a["route"] / "dispatch.pub").read_bytes().hex(),
                "keyId": a["dispatch"]["keyId"], "keyEpoch": "2"}}

    def prepare_bootstrap_dispatch(self, layout_file):
        """Render the real dispatch role for a pre-attachment continuation."""
        layout = read(layout_file)
        home = Path(layout["controllerHome"])
        config = read(self.root / "controller-stage/controller.json")
        if config.get("dispatchTask") is not None:
            raise ValueError("bootstrap already configures dispatch; no replacement permitted")
        config["dispatchTask"] = self.dispatch_config(home, layout)
        bundle = self.calls / "controller-update"
        bundle.mkdir(mode=0o700)
        write(bundle / "controller.json", config)
        return bundle / "controller.json"

    def prepare_controller(self, home):
        """Earn discovery grants, then render an installable private candidate.

        The caller installs this candidate under a dedicated account using the
        supported operator installer. Rendering does not launch a controller.
        """
        a, caps = self.agent, self.agent["plannedCaps"]
        app_birth = read(self.evidence / "a-app-author/source.json")["applicationGrainBirth"]["applicationBirth"]["application"]
        if {key: app_birth[key] for key in ("app", "packageManifest", "snapshotManifest")} != {
            key: self.allocation[key] for key in ("app", "packageManifest", "snapshotManifest")
        }:
            raise ValueError("actual app birth differs from allocation")
        issue_dir = self.evidence / "a-ticket-9120/issue"
        issue_request = read(self.evidence / "a-ticket-9120/request.json")
        ticket = issue_request["spec"]["ticket"]
        if ticket["scope"]["app"] != app_birth["app"]:
            raise ValueError("bootstrap discovery ticket names a different app")
        grants = [
            ("app", app_birth["app"], app_birth["appOwnerCapability"], caps["appObserve"]),
            ("manifest", app_birth["packageManifest"], app_birth["packageOwnerCapability"], caps["manifestObserve"]),
            ("snapshot", app_birth["snapshotManifest"], app_birth["snapshotOwnerCapability"], caps["snapshotObserve"]),
            ("discovery-ticket", ticket["resource"], issue_request["spec"]["ticketOwnerCapability"], caps["bootstrapTicketObserve"]),
        ]
        grant_receipts = {}
        for name, target, parent, child in grants:
            grant_receipts[name] = self.delegate_observe(name, target, parent, child, a["tool"]["subject"])
        # The controller participant needs its own app and manifest reads for
        # later signed ticket/lifetime plans; these are separate capabilities.
        for name, target, parent, child in [
            ("controller-app", app_birth["app"], app_birth["appOwnerCapability"], caps["controllerAppObserve"]),
            ("controller-manifest", app_birth["packageManifest"], app_birth["packageOwnerCapability"], caps["controllerManifestObserve"]),
        ]:
            grant_receipts[name] = self.delegate_observe(name, target, parent, child, a["controller"]["subject"])
        stage = self.root / "controller-stage"
        stage.mkdir(mode=0o700)
        for name in ("custody", "state", "state/shared-app-refs", "workspace"):
            (stage / name).mkdir(mode=0o700)
        for role in ("controller", "tool", "dispatch", "provider"):
            source = self.workroom / "agents" / a["route"] / (role + ".key")
            write(stage / "custody" / (role + ".key"), source.read_bytes())
        write(stage / "host-config.json", controller_host_metadata(self.config))
        birth_call = self.evidence / "a-app-attempt/call.bin"
        issue_call = issue_dir / "ingress.bin"
        write(stage / "state/shared-app-refs/app-birth.bin", birth_call.read_bytes())
        write(stage / "state/shared-app-refs/bootstrap-ticket.bin", issue_call.read_bytes())
        born = receipt(read(self.evidence / "a-app-attempt/outcome.json"))
        issued = read(issue_dir / "receipt-anchor.json")["receipt"]
        shared = {"name": "oracle-bootstrap-app", "applicationFamily": "oracle", "appTarget": app_birth["app"],
                  "manifestTarget": app_birth["packageManifest"], "snapshotTarget": app_birth["snapshotManifest"],
                  "ticketTarget": ticket["resource"], "appObserveCapability": caps["appObserve"],
                  "manifestObserveCapability": caps["manifestObserve"], "snapshotObserveCapability": caps["snapshotObserve"],
                  "ticketObserveCapability": caps["bootstrapTicketObserve"],
                  "birth": {**born, "call": str(home / "state/shared-app-refs/app-birth.bin"), "callSha256": sha(birth_call)},
                  "issue": {**issued, "kind": "grainBackedEvent22", "ingress": str(home / "state/shared-app-refs/bootstrap-ticket.bin"),
                            "ingressSha256": sha(issue_call)}}
        profile = {"genesis": read(self.workroom / "genesis.json"),
                   "template": {"issuer": "5", "ownerBudget": "100000", "lifetime": "10000"},
                   "factoryTarget": "10", "factoryObserveCapability": a["tool"]["factoryObserveCapability"],
                   "payerAccount": a["tool"]["account"], "payerCapability": caps["toolSpend"],
                   "payerObserveCapability": caps["toolSpend"], "tariffBase": "2", "tariffPerBirth": "1"}
        family = {"name": "oracle-session", "applicationFamily": "oracle", "kind": "api",
                  "participantSubject": a["controller"]["subject"], "profile": profile,
                  "namespace": {"session": a["session"], "descriptor": a["descriptor"],
                      "sessionOwnerCapability": caps["sessionOwner"], "sessionControlCapability": caps["sessionControl"],
                      "descriptorOwnerCapability": caps["descriptorOwner"], "descriptorControlCapability": caps["descriptorControl"]},
                  "maxBirths": 1, "maxResultBytes": 65536}
        config = {"mini": str(home / "bin/mini"), "host": str(home / "bin/minidregg-host"),
                  "hostConfig": str(home / "host-config.json"), "hostSocket": str(self.public),
                  "custodyKey": str(home / "custody/controller.key"), "stateDir": str(home / "state"),
                  "controlSocket": str(home / "state/control.sock"), "cwd": str(home / "workspace"),
                  "task": a["controller"]["task"], "subject": a["controller"]["subject"],
                  "capability": caps["parentOwner"], "queryCapability": caps["parentOwner"],
                  "policyControlCapability": caps["parentControl"], "foregroundTool": {"reserve": "1", "charge": "0"},
                  "toolTask": {"task": a["tool"]["task"], "subject": a["tool"]["subject"],
                      "capability": caps["toolOwner"], "queryCapability": caps["toolOwner"],
                      "custodyKey": str(home / "custody/tool.key"), "parentCapability": caps["parentToolWitness"],
                      "parentObserveCapability": caps["parentToolWitness"], "reserve": "5", "charge": "0",
                      "allowedPublications": [], "registeredSharedApplications": [shared],
                      "allowedSessionFamilies": [family], "currentBirthHostSha256": sha(self.host)}, "commands": []}
        config["dispatchTask"] = self.dispatch_config(home, read(self.root / "controller-create.json"))
        write(stage / "controller.json", config)
        write(self.root / "controller-stage.json", {"protocol": "mini-oracle-controller-stage-v1",
              "stage": str(stage), "home": str(home), "configSha256": sha(stage / "controller.json"),
              "hostSha256": sha(self.host), "runtimeSha256": sha(self.run / "bin/grain-runtime"),
              "discoveryGrantReceipts": grant_receipts,
              "nextTool": {"name": "mini_create_application_session", "arguments": {"family": "oracle-session", "application": "oracle-bootstrap-app"}}})
        return self.root / "controller-stage.json"

    def prepare_worker_policy(self, config_file):
        """Owner-authorized narrowing for the actual initial controller roles.

        This is deliberately limited to the untouched, paused bootstrap parent.
        Native signed reads, policy authoring, consent and the ordinary install
        receiver establish the transition; this harness supplies no authority.
        """
        a, caps = self.agent, self.agent["plannedCaps"]
        config = read(config_file)
        controller = a["controller"]
        if (config.get("task"), config.get("subject"), config.get("capability"),
                config.get("queryCapability"), config.get("policyControlCapability")) != (
                controller["task"], controller["subject"], caps["parentOwner"],
                caps["parentOwner"], caps["parentControl"]):
            raise ValueError("bootstrap controller differs from allocated owner authority")
        workers = []
        for field, role in (("toolTask", "tool"), ("dispatchTask", "dispatch"), ("providerTask", "provider")):
            task = config.get(field)
            if task is not None:
                if (task.get("task"), task.get("subject")) != (a[role]["task"], a[role]["subject"]):
                    raise ValueError("bootstrap worker differs from actual allocated role")
                workers.append(task["subject"])
        if not workers or len(workers) == 3:
            raise ValueError("bootstrap repair requires a strict nonempty worker subset")
        key = self.workroom / "agents" / a["route"] / "controller.key"
        parent = self.query("parent-before-policy", controller["subject"], controller["task"], caps["parentOwner"], key)
        grain = read(parent / "view.json")["cell"]["grain"]
        if any(grain.get(k) != v for k, v in {"task": controller["task"], "generation": "0", "status": "0", "reserved": "0"}.items()):
            raise ValueError("bootstrap owner repair requires untouched paused generation zero")
        before = self.query("policy-before", controller["subject"], controller["task"], caps["parentOwner"], key, "policy")
        view = read(before / "view.json")
        if view.get("policyId") != controller["task"] or view.get("version") != "0" or view.get("previous") is not None:
            raise ValueError("bootstrap policy is not the original source policy")

        def authored(label, kind, value):
            source, output = self.calls / (label + ".json"), self.calls / (label + ".bin")
            write(source, value)
            self.call(label, [self.mini, "author", "--host", self.host, "--config", self.config,
                             "--socket", self.public, "--kind", kind, "--input", source, "--output", output])
            return output.read_bytes()

        original = {"owner": controller["subject"], "workerSubjects": [a[role]["subject"] for role in ("tool", "dispatch", "provider")], "workerGeneration": "1"}
        if authored("original-allocation-law", "grain-policy", original) != authored("current-law", "predicate", view["predicate"]):
            raise ValueError("current source policy differs from exact allocated worker law")
        desired = {"owner": controller["subject"], "workerGeneration": "1",
                   "workerSubject" if len(workers) == 1 else "workerSubjects": workers[0] if len(workers) == 1 else workers}
        expected = authored("configured-worker-law", "grain-policy", desired)
        source = dict(desired, subject=controller["subject"], intentNonce=str(secrets.randbits(120)),
                      declarationNonce=str(secrets.randbits(120)), task=controller["task"], control=caps["parentControl"],
                      domain=view["domain"], semantics=view["semantics"],
                      expectedPreRoot=read(before / "challenge.json")["authorityRoot"],
                      expectedVersion=view["version"], expectedAddress=view["address"], currentSourceHex=view["canonical"],
                      grants=[{"kind": "object", "target": controller["task"], "capability": caps["parentOwner"]}])
        intent, attempt = self.calls / "owner-policy-install.json", self.calls / "owner-policy-attempt"
        write(intent, source)
        self.call("owner-policy-install", [self.mini, "submit", "--host", self.host, "--config", self.config,
                  "--socket", self.public, "--intent", intent, "--intent-kind", "grain-policy-install-intent",
                  "--key", key, "--dir", attempt])
        confirmed = receipt(read(attempt / "outcome.json"))
        after = self.query("policy-after", controller["subject"], controller["task"], caps["parentOwner"], key, "policy")
        installed = read(after / "view.json")
        if (installed.get("policyId"), installed.get("version"), installed.get("previous")) != (controller["task"], "1", view["address"]):
            raise ValueError("installed owner policy does not extend exact observed source")
        if authored("installed-worker-law", "predicate", installed["predicate"]) != expected:
            raise ValueError("installed owner policy differs from actual configured workers")
        result = self.calls / "worker-policy.json"
        write(result, {"protocol": "mini-oracle-bootstrap-worker-policy-v1", "controllerConfigSha256": sha(config_file),
                      "workers": workers, "workerGeneration": "1", "attempt": str(attempt), "receipt": confirmed,
                      "before": str(before), "after": str(after)})
        return result



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare-controller", "prepare-bootstrap-dispatch", "prepare-worker-policy", "issue-grant", "prepare-route", "activate"])
    parser.add_argument("run", type=Path)
    parser.add_argument("input", type=Path, help="controller home for prepare; retained session tool result for issue")
    parser.add_argument("--repo", type=Path)
    args = parser.parse_args()
    if not args.run.is_absolute() or not args.input.is_absolute():
        parser.error("run and controller home must be absolute")
    os.umask(0o077)
    phase = args.command
    if phase == "activate":
        generation = read(args.input).get("generation", "")
        if not isinstance(generation, str) or not generation.isascii() or not generation.isdecimal():
            parser.error("native START generation absent")
        phase += "-" + generation
    operator = Operator(args.run, phase)
    if args.command == "prepare-controller":
        result = operator.prepare_controller(args.input)
    elif args.command == "prepare-worker-policy":
        result = operator.prepare_worker_policy(args.input)
    elif args.command == "prepare-bootstrap-dispatch":
        result = operator.prepare_bootstrap_dispatch(args.input)
    elif args.command == "issue-grant":
        result = operator.issue_grant(args.input)
    elif args.command == "prepare-route":
        result = operator.prepare_route(args.repo, args.input)
    else:
        result = operator.activate(args.repo, args.input)
    print(result)


if __name__ == "__main__":
    main()
