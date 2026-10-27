"""Narrow physical staging and actual child-lifetime fixtures; no Oracle stores."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("oracle_stage", HERE / "stage.py")
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)


def wait_for(predicate, timeout=5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.02)
    raise AssertionError("fixture deadline")


class StageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.rootfs = self.base / "rootfs"
        for directory in ("var", "tmp", "proc", "dev", "opt", "usr/bin"):
            (self.rootfs / directory).mkdir(parents=True, exist_ok=True)
        elf = b"\x7fELF\x02\x01" + b"\x00" * 12 + b"\x3e\x00"
        (self.rootfs / "usr/bin/python3.12").write_bytes(elf)
        (self.rootfs / "usr/bin/python3.12").chmod(0o755)
        self.rootfs_manifest = self.base / "rootfs.json"
        self.rootfs_manifest.write_text(json.dumps({
            "schema": "oracle-rootfs-v1", "platform": "linux-x86_64", "python": "3.12",
            "dependencies": stage.DEPENDENCIES, "entries": stage.inventory(self.rootfs)}))
        self.appliance = self.base / "appliance"
        (self.appliance / "root").mkdir(parents=True)
        (self.appliance / "adapter").mkdir()
        (self.appliance / "adapter/serve.py").write_text("# fixture only\n")
        files = {p: {k: v for k, v in e.items() if k != "kind"}
                 for p, e in stage.inventory(self.appliance).items() if e["kind"] == "file"}
        (self.appliance / "APPLIANCE.json").write_text(json.dumps({"files": files}))
        self.bridge = self.base / "bridge"
        self.bridge.write_bytes(elf)
        self.bridge.chmod(0o755)
        self.args = argparse.Namespace(
            rootfs=self.rootfs, rootfs_manifest=self.rootfs_manifest,
            rootfs_sha256=stage.digest(self.rootfs_manifest), appliance=self.appliance,
            appliance_sha256=stage.digest(self.appliance / "APPLIANCE.json"),
            bridge=self.bridge, bridge_sha256=stage.digest(self.bridge),
            app_id="fixture", version=1, capnp=Path(shutil.which("capnp") or "capnp"),
            target=self.base / "stage")

    def tearDown(self):
        self.temp.cleanup()

    @unittest.skipUnless(shutil.which("capnp"), "capnp unavailable")
    def test_stage_encodes_and_detects_source_mutation(self):
        stage.build(self.args)
        receipt = stage.verify_stage(self.args.target)
        self.assertFalse(receipt["signed"])
        self.assertIn("opt/oracle/adapter/serve.py", (self.args.target / "files.list").read_text())
        # Actual Cap'n Proto decoding, not a string-shape stand-in.
        schema = stage.REPO / "native/spk-rpc/schema/package.capnp"
        decoded = subprocess.check_output([str(self.args.capnp), "decode", str(schema), "BridgeConfig"],
                                         input=(self.args.target / "image/sandstorm-http-bridge-config").read_bytes())
        self.assertIn(b'apiPath = "/"', decoded)
        self.assertIn(b'name = "query"', decoded)
        manifest = subprocess.check_output([str(self.args.capnp), "decode", str(schema), "Manifest"],
                                          input=(self.args.target / "image/sandstorm-manifest").read_bytes())
        self.assertNotIn(b'NLTK_DATA', manifest)
        subprocess.run([str(self.args.capnp), "eval", str(self.args.target / "sandstorm-pkgdef.capnp"), "pkgdef"],
                       check=True, stdout=subprocess.DEVNULL)
        (self.appliance / "adapter/serve.py").write_text("changed")
        with self.assertRaisesRegex(ValueError, "appliance file bytes"):
            stage.verify_stage(self.args.target)

    def test_mismatch_does_not_publish(self):
        (self.rootfs / "unexpected").write_text("not pinned")
        with self.assertRaisesRegex(ValueError, "rootfs bytes"):
            stage.build(self.args)
        self.assertFalse(self.args.target.exists())

    def test_existing_target_is_preserved(self):
        self.args.target.mkdir()
        (self.args.target / "keep").write_text("another owner")
        with self.assertRaisesRegex(ValueError, "already exists"):
            stage.build(self.args)
        self.assertEqual((self.args.target / "keep").read_text(), "another owner")

    def test_links_cannot_escape_or_hide_entries(self):
        with self.assertRaisesRegex(ValueError, "escapes"):
            stage.validate_links({"bad": {"kind": "symlink", "target": "../outside"}})
        with self.assertRaisesRegex(ValueError, "non-directory parent"):
            stage.validate_links({"alias": {"kind": "symlink", "target": "/usr"},
                                  "usr": {"kind": "directory"},
                                  "alias/file": {"kind": "file"}})

    def test_large_store_is_an_explicit_format_refusal(self):
        with self.assertRaisesRegex(ValueError, "512 MiB.*root/store.sqlite"):
            stage.require_spk_members({"root/store.sqlite": {"kind": "file", "size": 512 * 1024 * 1024}})

    @unittest.skipUnless(shutil.which("capnp"), "capnp unavailable")
    def test_split_preserves_paths_and_pins_exact_public_inventory(self):
        data = self.appliance / "root/store.sqlite3"
        data.write_bytes(b"immutable data")
        receipt_path = self.appliance / "APPLIANCE.json"
        receipt = json.loads(receipt_path.read_text())
        entry = {"size": data.stat().st_size, "sha256": stage.digest(data), "executable": False}
        receipt["files"]["root/store.sqlite3"] = entry
        receipt["stores"] = [{"path": "root/store.sqlite3", "size": entry["size"], "sha256": entry["sha256"]}]
        receipt_path.write_text(json.dumps(receipt))
        self.args.appliance_sha256 = stage.digest(receipt_path)
        public = {"schema": "minidregg-public-data-inventory-v1", "visibility": "public",
                  "files": [{"path": "root/store.sqlite3", "size": entry["size"], "sha256": entry["sha256"]}]}
        self.args.data_inventory = self.base / "public-data.json"
        self.args.data_inventory.write_text(json.dumps(public))
        self.args.data_sha256 = stage.digest(self.args.data_inventory)
        stage.build(self.args)
        staged = stage.verify_stage(self.args.target)
        self.assertEqual(staged["expected_package_entries"]["opt/oracle/root/store.sqlite3"],
                         {"kind": "symlink", "target": "/opt/oracle-data/root/store.sqlite3"})
        self.assertEqual(staged["expected_package_entries"]["opt/oracle-data"], {"kind": "directory"})
        manifest = subprocess.check_output([str(self.args.capnp), "decode", str(stage.REPO / "native/spk-rpc/schema/package.capnp"), "Manifest"],
                                          input=(self.args.target / "image/sandstorm-manifest").read_bytes())
        self.assertEqual(manifest.count(b'key = "NLTK_DATA"'), 2)
        self.assertEqual(manifest.count(b'value = "/opt/oracle-data/root/nltk_data"'), 2)
        self.assertEqual(json.loads((self.args.target / "image/minidregg-data.json").read_text()),
                         {"schema": "minidregg-public-data-v1", "inventory_sha256": self.args.data_sha256})
        self.assertEqual(data.read_bytes(), b"immutable data")
        self.assertFalse(data.is_symlink())
        self.assertEqual(staged["package_sources"]["opt/oracle/root/store.sqlite3"]["root"], "image")
        self.assertEqual(staged["package_sources"]["opt/oracle/adapter/serve.py"]["root"], "appliance")
        public["files"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "differs"):
            stage.data_inventory(public, receipt)

    def test_public_inventory_cannot_redirect_or_omit_bulk_data(self):
        receipt = {"files": {"root/data": {"size": 1, "sha256": "a" * 64, "executable": False}},
                   "stores": [{"path": "root/required"}]}
        public = {"schema": "minidregg-public-data-inventory-v1", "visibility": "public",
                  "files": [{"path": "root/data", "size": 1, "sha256": "a" * 64}]}
        with self.assertRaisesRegex(ValueError, "every declared"):
            stage.data_inventory(public, receipt)
        public["files"][0]["path"] = "../host/path"
        with self.assertRaisesRegex(ValueError, "noncanonical"):
            stage.data_inventory(public, receipt)
        public["host_path"] = "/private"
        with self.assertRaisesRegex(ValueError, "invalid public"):
            stage.data_inventory(public, receipt)

    def test_final_package_rejects_mutation_extra_files_and_wrong_signer(self):
        entries = {"payload": {"kind": "file", "size": 3, "executable": False, "sha256": "expected"}}
        receipt = {"app_id": "reviewed-signer", "version": 1, "expected_package_entries": entries}
        actual = {"schema": "verified-spk-inventory-v1", "signature_verified": True,
                  "app_id": "reviewed-signer", "app_version": 1, "entries": entries}
        stage.compare_package(receipt, actual)
        with self.assertRaisesRegex(ValueError, "identity"):
            stage.compare_package(receipt, {**actual, "app_id": "other-signer"})
        with self.assertRaisesRegex(ValueError, "extra"):
            stage.compare_package(receipt, {**actual, "entries": {**entries, "unexpected": {"kind": "directory"}}})
        with self.assertRaisesRegex(ValueError, "changed"):
            stage.compare_package(receipt, {**actual, "entries": {"payload": {**entries["payload"], "sha256": "mutated-before-pack"}}})


class LifetimeTests(unittest.TestCase):
    def run_lifetime(self, crash_adapter):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            adapter = directory / "adapter.py"
            adapter.write_text('''import os, signal, subprocess, sys, time
from pathlib import Path
base = Path(sys.argv[1])
try:
    os.fstat(3)
    raise RuntimeError("fd3 leaked into adapter")
except OSError:
    pass
worker = subprocess.Popen([sys.executable, "-c", "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(300)"])
(base / "adapter-ready").write_text(str(os.getpid()) + " " + str(worker.pid))
if sys.argv[2] == "crash":
    while not (base / "bridge-ready").exists(): time.sleep(.02)
    os._exit(23)
signal.signal(signal.SIGTERM, lambda *args: sys.exit(0))
while True: time.sleep(.1)
''')
            bridge = directory / "bridge.py"
            bridge.write_text('''import os, signal, socket, sys, time
from pathlib import Path
with socket.fromfd(3, socket.AF_UNIX, socket.SOCK_STREAM) as s: s.getpeername()
Path(sys.argv[1], "bridge-ready").write_text(str(os.getpid()))
signal.signal(signal.SIGTERM, lambda *args: sys.exit(0))
while True: time.sleep(.1)
''')
            driver = '''import importlib.util, os, pathlib, sys
os.dup2(int(sys.argv[1]), 3)
spec = importlib.util.spec_from_file_location("launch", sys.argv[2]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
base = pathlib.Path(sys.argv[3])
sys.exit(m.supervise([sys.executable, str(base / "adapter.py"), str(base), sys.argv[4]],
                    [sys.executable, str(base / "bridge.py"), str(base)],
                    readiness=lambda: (base / "adapter-ready").exists(), startup=3, grace=.3))
'''
            local, remote = socket.socketpair()
            process = subprocess.Popen([sys.executable, "-B", "-c", driver, str(remote.fileno()),
                                        str(HERE / "launch.py"), str(directory), "crash" if crash_adapter else "normal"],
                                       pass_fds=(remote.fileno(),), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            remote.close()
            pids = []
            try:
                wait_for(lambda: (directory / "bridge-ready").exists() or process.poll() is not None)
                if not (directory / "bridge-ready").exists():
                    self.fail(process.communicate(timeout=2)[1].decode())
                pids = [int(x) for x in (directory / "adapter-ready").read_text().split()]
                pids += [int((directory / "bridge-ready").read_text())]
                if not crash_adapter:
                    process.terminate()
                stdout, stderr = process.communicate(timeout=5)
                self.assertEqual(process.returncode, 23 if crash_adapter else 0, stderr.decode())
                for pid in pids:
                    def stopped():
                        state = subprocess.run(["ps", "-p", str(pid), "-o", "stat="], capture_output=True, text=True)
                        return not state.stdout.strip() or state.stdout.strip().startswith("Z")
                    wait_for(stopped)
            finally:
                local.close()
                if process.poll() is None:
                    process.kill()
                    process.wait()
                # Only the fixture's recorded PIDs, in case an assertion failed.
                for pid in pids:
                    try:
                        os.kill(pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass

    def test_term_stops_adapter_bridge_and_worker_without_fd3_leak(self):
        self.run_lifetime(False)

    def test_adapter_crash_cleans_orphan_worker_and_bridge(self):
        self.run_lifetime(True)


if __name__ == "__main__":
    unittest.main()
