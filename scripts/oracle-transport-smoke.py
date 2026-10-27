#!/usr/bin/env python3
"""Operator-only real OracleEngine/fd3 transport smoke; no Mini admission claim.

Uses only a new report/workspace directory. Runtime inventory checks metadata and
hashes files <= 1 MiB; it does not re-attest multi-gigabyte deployment stores.
"""
import argparse
import hashlib
import http.client
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import time

QUESTIONS = [
    "Who wrote Leaves of Grass?",
    "ISA temperature at 3,000 m altitude?",
    "ISA temperature at 3,000 m/s altitude?",
    "Who wrote Emma?",
    "When was she born?",
]
MAX_REPLY = 2 * 1024 * 1024


def digest(data):
    return hashlib.sha256(data).hexdigest()


def probe_tenant(session=3):
    """Synthetic operator probe identity; never evidence of Mini admission."""
    tab = b"mini-session-v1\0" + b"".join(n.to_bytes(8, "big") for n in (1, 2, session))
    return digest(b"mini-oracle-tenant-v1\0" + bytes([1]) * 32 + tab)


def adapter_command(args, workspace, port):
    return [str(args.python), "-B", str(args.adapter),
            "--runtime", str(args.runtime), "--data-root", str(args.runtime / "root"),
            "--workspace", str(workspace), "--port", str(port), "--tenant-pool",
            "--max-resident", "1", "--max-tenants", "8", "--max-request-bytes", "65536",
            "--query-timeout", "120", "--startup-timeout", "180"]


def inventory(root):
    entries = {}
    for path in sorted(root.rglob("*")):
        metadata = path.lstat()
        item = [metadata.st_mode, metadata.st_size, metadata.st_mtime_ns, metadata.st_ctime_ns]
        if path.is_symlink():
            item.append(os.readlink(path))
            target = path.stat()
            item.extend([target.st_size, target.st_mtime_ns, target.st_ctime_ns])
        if path.is_file() and path.stat().st_size <= 1024 * 1024:
            item.append(digest(path.read_bytes()))
        entries[str(path.relative_to(root))] = item
    return entries


def direct(port, method, path, data=None, timeout=130, tenant=None):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=timeout)
    try:
        headers = {"Content-Type": "application/json", "Connection": "close"}
        if path != "/health":
            headers["X-Mini-Oracle-Tenant"] = probe_tenant() if tenant is None else tenant
        connection.request(method, path, body=data, headers=headers)
        response = connection.getresponse()
        payload = response.read(MAX_REPLY + 1)
        if len(payload) > MAX_REPLY:
            raise RuntimeError("direct HTTP response exceeded bound")
        return response.status, payload
    finally:
        connection.close()


def stop_owned(process, grace=12):
    """Terminate our recorded child; its private process group is cleanup only."""
    if process.poll() is None:
        process.terminate()
    try:
        process.wait(timeout=grace)
    except subprocess.TimeoutExpired:
        # This session/group was created by this invocation, not discovered by name.
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=5)
    # A crashed leader can leave its worker behind. Only our created group is eligible.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--python", type=Path, required=True)
    parser.add_argument("--adapter", type=Path, help="tenant-aware serve.py; defaults to runtime/adapter/serve.py")
    parser.add_argument("--bridge", type=Path, required=True)
    parser.add_argument("--probe", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="new directory only")
    args = parser.parse_args()
    args.runtime = args.runtime.resolve()
    args.output = args.output.resolve()
    args.adapter = (args.adapter or args.runtime / "adapter/serve.py").resolve()
    if not args.adapter.is_file() or not (args.adapter.parent / "tenant_pool.py").is_file():
        parser.error("adapter must include tenant-aware serve.py and tenant_pool.py")
    for name in ("python", "bridge", "probe"):
        setattr(args, name, getattr(args, name).absolute())  # preserve virtualenv interpreter path
    if args.output == args.runtime or args.runtime in args.output.parents or args.output in args.runtime.parents:
        parser.error("output and runtime must be disjoint")
    args.output.mkdir(mode=0o700, parents=True, exist_ok=False)
    workspace = args.output / "workspace"
    before = inventory(args.runtime)
    (args.output / "inventory-before.json").write_text(json.dumps(before, sort_keys=True))
    report = {"scope": "Real OracleEngine through app fd3; not Mini admission, fleet qualification or specialist panel coverage",
              "runtime": str(args.runtime), "tenant_key": probe_tenant(),
              "adapter": str(args.adapter), "adapter_sha256": digest(args.adapter.read_bytes()),
              "tenant_pool_sha256": digest((args.adapter.parent / "tenant_pool.py").read_bytes()), "queries": [], "checks": {}, "owned_adapter_pids": [],
              "inventory_scope": "all paths/modes/sizes/mtime/ctime/link targets; SHA256 for files <=1MiB; no full store rehash",
              "binary_sha256": {name: digest(getattr(args, name).read_bytes()) for name in ("bridge", "probe")},
              "passed": False}
    adapter = None
    logs = []
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    report["port"] = port

    def start(number):
        log = (args.output / f"adapter-{number}.log").open("wb")
        logs.append(log)
        command = adapter_command(args, workspace, port)
        child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                 close_fds=True, start_new_session=True,
                                 env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
        report["owned_adapter_pids"].append(child.pid)
        deadline = time.monotonic() + 190
        try:
            while time.monotonic() < deadline:
                if child.poll() is not None:
                    raise RuntimeError(f"adapter exited {child.returncode}; see adapter-{number}.log")
                try:
                    status, payload = direct(port, "GET", "/health", timeout=0.25)
                    if status == 200:
                        report[f"health_{number}"] = json.loads(payload)
                        return child
                except (OSError, http.client.HTTPException):
                    pass
                time.sleep(0.1)
            raise TimeoutError("adapter startup exceeded 190-second smoke bound")
        except BaseException:
            stop_owned(child)
            raise

    def bridge_request(label, raw, expected_status):
        request_file = args.output / f"{label}.request.json"
        request_file.write_bytes(raw)
        child = subprocess.Popen([str(args.probe), str(args.bridge), str(port), str(request_file)],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        try:
            stdout, stderr = child.communicate(timeout=145)
        except BaseException:
            stop_owned(child)
            raise
        (args.output / f"{label}.probe.log").write_bytes(stderr)
        if not stdout.endswith(b"\n"):
            raise RuntimeError(f"{label}: probe omitted complete body: {stderr.decode(errors='replace')}")
        payload = stdout[:-1]  # probe adds exactly one newline, not part of HTTP bytes
        (args.output / f"{label}.reply.json").write_bytes(payload)
        marker = f"upstream_http_status={expected_status}\n".encode()
        if marker not in stderr or (child.returncode == 0) != (expected_status == 200):
            raise RuntimeError(f"{label}: unexpected probe result {child.returncode}: {stderr.decode(errors='replace')}")
        if len(payload) > MAX_REPLY:
            raise RuntimeError("bridge response exceeded bound")
        json.loads(payload)
        return payload

    try:
        adapter = start(1)
        status, capabilities = direct(port, "GET", "/capabilities")
        if status != 200:
            raise RuntimeError("capabilities unavailable")
        report["capabilities"] = json.loads(capabilities)
        requests, replies = [], []
        for index, question in enumerate(QUESTIONS):
            raw = json.dumps({"request_id": f"smoke-{index}", "conversation_id": "smoke-conversation",
                              "text": question}, ensure_ascii=False, separators=(",", ":")).encode()
            began = time.monotonic()
            reply = bridge_request(f"query-{index}", raw, 200)
            status, replay = direct(port, "POST", "/query", raw)
            if status != 200 or replay != reply:
                raise RuntimeError(f"query {index}: direct replay differs from bridge bytes")
            requests.append(raw)
            replies.append(reply)
            decoded = json.loads(reply)
            report["queries"].append({"question": question, "seconds": round(time.monotonic()-began, 3),
                                      "bytes": len(reply), "sha256": digest(reply), "reply": decoded,
                                      "direct_replay_identical": True})
            print(f"query {index+1}/5: {decoded.get('reply', {}).get('status')} {len(reply)} bytes", flush=True)
        report["checks"]["five_bridge_direct_replays_identical"] = True
        if bridge_request("same-process-replay", requests[0], 200) != replies[0]:
            raise RuntimeError("same-process bridge replay differs")
        report["checks"]["same_process_bridge_replay_identical"] = True
        conflict = json.loads(requests[0])
        conflict["text"] = "Who wrote Emma?"
        conflict = json.dumps(conflict, separators=(",", ":")).encode()
        conflict_reply = bridge_request("conflict", conflict, 409)
        status, direct_conflict = direct(port, "POST", "/query", conflict)
        if status != 409 or conflict_reply != direct_conflict or json.loads(conflict_reply).get("error") != "request_id_conflict":
            raise RuntimeError("changed-body conflict was not preserved")
        report["checks"]["changed_body_conflict_409"] = True
        # Same request/conversation IDs in a different source-session namespace
        # must not collide with this tenant's durable request journal.
        other_status, other_reply = direct(port, "POST", "/query", conflict, tenant=probe_tenant(4))
        if other_status != 200 or "Austen" not in json.loads(other_reply).get("reply", {}).get("response", ""):
            raise RuntimeError("another tenant inherited the first tenant's request ID or wrong answer")
        (args.output / "other-tenant.reply.json").write_bytes(other_reply)
        report["checks"]["same_ids_separate_tenant"] = True
        if bridge_request("after-other-tenant-replay", requests[0], 200) != replies[0]:
            raise RuntimeError("tenant switch changed exact original replay")
        report["checks"]["original_replay_after_tenant_switch_identical"] = True
        stop_owned(adapter)
        adapter = None
        adapter = start(2)
        for index, (raw, expected) in enumerate(zip(requests, replies)):
            if bridge_request(f"restart-replay-{index}", raw, 200) != expected:
                raise RuntimeError(f"restart bridge replay {index} differs")
        if bridge_request("restart-conflict", conflict, 409) != conflict_reply:
            raise RuntimeError("restart conflict differs")
        report["checks"]["five_replays_identical_after_adapter_restart"] = True
        report["checks"]["conflict_persists_after_restart"] = True
        # These are deliberately five smoke assertions, not specialist panel scores.
        texts = [item["reply"].get("reply", {}).get("response", "") for item in report["queries"]]
        report["checks"]["leaves_of_grass_whitman"] = "Whitman" in texts[0]
        report["checks"]["isa_3000m_minus_4_5"] = "-4.5" in texts[1]
        report["checks"]["invalid_speed_unit_not_answered"] = (report["queries"][2]["reply"].get("reply", {}).get("status") in ("withheld", "clarification") and "-4.5" not in texts[2])
        report["checks"]["emma_austen"] = "Austen" in texts[3]
        report["checks"]["pronoun_1775"] = "1775" in texts[4]
    except BaseException as error:
        report["error"] = f"{type(error).__name__}: {error}"
    finally:
        if adapter is not None:
            stop_owned(adapter)
        for log in logs:
            log.close()
        # Both adapter launches ran in private groups created by this script.
        alive = []
        for pid in report["owned_adapter_pids"]:
            deadline = time.monotonic() + 3
            while True:
                try:
                    os.killpg(pid, 0)
                except ProcessLookupError:
                    break
                if time.monotonic() >= deadline:
                    alive.append(pid)
                    break
                time.sleep(0.05)
        report["owned_groups_remaining"] = alive
        report["checks"]["owned_process_groups_stopped"] = not alive
        after = inventory(args.runtime)
        (args.output / "inventory-after.json").write_text(json.dumps(after, sort_keys=True))
        changes = sorted(k for k in before.keys() | after.keys() if before.get(k) != after.get(k))
        report["runtime_inventory_changes"] = changes
        report["runtime_inventory_entries"] = len(before)
        report["checks"]["runtime_inventory_unchanged"] = not changes
        report["passed"] = "error" not in report and bool(report["checks"]) and all(report["checks"].values())
        (args.output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"passed": report["passed"], "checks": report["checks"], "error": report.get("error"), "report": str(args.output / "report.json")}), flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
