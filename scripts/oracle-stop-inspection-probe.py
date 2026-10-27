#!/usr/bin/env python3
"""Untrusted read-only receiving probe for Mini's STOP inspection, not authority.

Compare the cold pinned Host CLI with two operator-only served inspections of
the same exact inputs. No lifecycle submission, STOP, restart, or retry occurs.
Use only an isolated qualification Store whose Host/config pins match --host.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import socket
import struct
import subprocess
import time

OP = 155
MAX_FRAME = 12_102_760
MAX_JSON = 2 * 1024 * 1024


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def receive(sock, count):
    chunks = bytearray()
    while len(chunks) < count:
        chunk = sock.recv(count - len(chunks))
        if not chunk:
            raise RuntimeError("operator closed without a complete reply")
        chunks.extend(chunk)
    return bytes(chunks)


def exchange(path, envelope, deadline):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(deadline)
        connection.connect(str(path))
        connection.sendall(struct.pack("<I", len(envelope)) + envelope)
        width = struct.unpack("<I", receive(connection, 4))[0]
        if not 1 <= width <= MAX_FRAME:
            raise RuntimeError("reply exceeds host frame bound")
        return receive(connection, width)


def cold(args, output):
    process = subprocess.Popen(
        [str(args.host), str(args.config), "inspect-stop-claim",
         str(args.plan), str(args.committed), str(output)],
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        start_new_session=True,
    )
    try:
        stdout, stderr = process.communicate(timeout=args.deadline)
    except subprocess.TimeoutExpired:
        # This process group was created and recorded by this probe alone.
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate()
        raise RuntimeError("cold inspection exceeded its deadline") from None
    (args.out / "cold.stdout").write_bytes(stdout)
    (args.out / "cold.stderr").write_bytes(stderr)
    if process.returncode:
        raise RuntimeError(f"cold inspection exited {process.returncode}")
    raw = output.read_bytes()
    if not 0 < len(raw) <= MAX_JSON:
        raise RuntimeError("cold JSON exceeds native inspection bound")
    return raw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("host", "config", "operator-socket", "plan", "committed", "out"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--public-socket", type=Path)
    parser.add_argument("--deadline", type=float, default=1200)
    args = parser.parse_args()
    if not 0 < args.deadline <= 1800:
        parser.error("deadline must be positive and at most 1800 seconds")
    args.out.mkdir(mode=0o700, parents=False, exist_ok=False)
    config, plan, committed = (p.read_bytes() for p in (args.config, args.plan, args.committed))
    host_sha = hashlib.file_digest(args.host.open("rb"), "sha256").digest()
    pair = struct.pack("<I", len(plan)) + plan + committed
    if not plan or not committed or len(pair) >= MAX_FRAME or len(config) > 65536:
        raise RuntimeError("input outside native bounds")
    binding = b"\x02" + struct.pack("<I", len(config)) + config + host_sha
    report = {"schema": "mini-stop-inspection-probe-v1", "passed": False,
              "scope": "Read-only cold/served comparison, no lifecycle operation",
              "host_sha256": host_sha.hex(), "config_sha256": digest(config),
              "plan_sha256": digest(plan), "committed_sha256": digest(committed),
              "measurements": {}}

    def measured(name, run):
        start = time.monotonic()
        raw = run()
        report["measurements"][name] = {
            "seconds": time.monotonic() - start,
            "bytes": len(raw), "sha256": digest(raw)}
        return raw

    def served(payload):
        return exchange(args.operator_socket, binding + bytes([OP]) + payload, args.deadline)

    try:
        original = measured("cold", lambda: cold(args, args.out / "cold.json"))
        for label in ("served-first", "served-repeat"):
            reply = measured(label, lambda: served(pair))
            (args.out / (label + ".bin")).write_bytes(reply)
            if reply != bytes([OP]) + original:
                raise RuntimeError(label + " differs from cold inspection bytes")
        # A canonical pair containing a changed inner frame must not inherit the
        # previous successful inspection. It still reaches Lean's inner decoder.
        for label, payload in (("trailing-claim", pair + b"\0"),
                               ("malformed-pair", b"\xff\xff\xff\xff")):
            reply = measured(label, lambda: served(payload))
            (args.out / (label + ".bin")).write_bytes(reply)
            if not reply or reply[0] != 255:
                raise RuntimeError(label + " did not return explicit refusal")
        if args.public_socket:
            reply = measured("public-denied", lambda: exchange(
                args.public_socket, bytes([OP]) + pair, args.deadline))
            (args.out / "public-denied.bin").write_bytes(reply)
            if not reply or reply[0] != 255:
                raise RuntimeError("public socket accepted STOP inspection")
        if hashlib.file_digest(args.host.open("rb"), "sha256").digest() != host_sha:
            raise RuntimeError("Host image changed during comparison")
        if args.config.read_bytes() != config:
            raise RuntimeError("Host config changed during comparison")
        report["passed"] = True
    finally:
        (args.out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
