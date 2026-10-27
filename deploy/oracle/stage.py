#!/usr/bin/env python3
"""Physical SPK input staging. Does not admit applications or grant authority.

All external bytes come from explicit, operator-pinned inputs. Large appliance
files stay in place and enter the package only through an exact file list.
"""
import argparse
import ctypes
import hashlib
import json
import os
import re
from pathlib import Path, PurePosixPath
import shutil
import stat
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SPK_MEMBER_LIMIT = 512 * 1024 * 1024
DEPENDENCIES = {
    "sympy": "1.14.0", "mpmath": "1.3.0", "numpy": "2.4.6", "scipy": "1.17.1",
    "scikit-learn": "1.8.0", "nltk": "3.9.4", "regex": "2026.5.9", "zstandard": "0.25.0",
}
BRIDGE_CONFIG = '''(apiPath = "/", viewInfo = (
  appTitle = (defaultText = "Oracle7"),
  permissions = [(name = "query", title = (defaultText = "Ask questions"),
    description = (defaultText = "Use a session-isolated workspace on a bounded shared Oracle runtime"))],
  roles = [(title = (defaultText = "Researcher"),
    verbPhrase = (defaultText = "can ask questions"),
    description = (defaultText = "Ask questions and inspect this appliance"),
    permissions = [true], default = false)]))'''


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def name(value):
    if not isinstance(value, str) or not value or value.startswith("/") or "\\" in value:
        raise ValueError("invalid package path")
    if any(part in ("", ".", "..") for part in value.split("/")) or any(ord(c) < 32 for c in value):
        raise ValueError("noncanonical package path: " + repr(value))
    return value


def pinned(path, expected):
    if path.is_symlink() or not path.is_file() or digest(path) != expected:
        raise ValueError("pinned file mismatch: " + str(path))


def pinned_json(path, expected):
    # Hash and parse the same bounded bytes, even if the path changes afterward.
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, "rb") as source:
        if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
            raise ValueError("pinned JSON is not regular")
        data = source.read(64 * 1024 * 1024 + 1)
    if len(data) > 64 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != expected:
        raise ValueError("pinned JSON mismatch or size limit: " + str(path))
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate JSON member: " + key)
            result[key] = value
        return result
    return json.loads(data, object_pairs_hook=unique)


def inventory(root, unhashed=frozenset()):
    """Never follow symlinks, including directory links."""
    result = {}
    for directory, dirs, files in os.walk(root, followlinks=False):
        for leaf in sorted(dirs + files):
            path = Path(directory) / leaf
            relative = name(path.relative_to(root).as_posix())
            mode = path.lstat().st_mode
            if stat.S_ISLNK(mode):
                result[relative] = {"kind": "symlink", "target": os.readlink(path)}
            elif stat.S_ISDIR(mode):
                result[relative] = {"kind": "directory"}
            elif stat.S_ISREG(mode):
                if mode & (stat.S_ISUID | stat.S_ISGID):
                    raise ValueError("setid input: " + relative)
                result[relative] = {"kind": "file", "size": path.stat().st_size,
                                    "sha256": None if relative in unhashed else digest(path), "executable": bool(mode & 0o111)}
            else:
                raise ValueError("special file in rootfs: " + relative)
    return dict(sorted(result.items()))


def validate_links(entries):
    # Resolve links in the image namespace, never through the host filesystem.
    for relative, entry in entries.items():
        name(relative)
        for parent in PurePosixPath(relative).parents:
            if str(parent) != "." and entries.get(str(parent)) != {"kind": "directory"}:
                raise ValueError("entry has non-directory parent: " + relative)
        if entry["kind"] != "symlink":
            continue
        todo = relative.split("/")
        resolved = []
        followed = 0
        while todo:
            component = todo.pop(0)
            if component in ("", "."):
                continue
            if component == "..":
                if not resolved:
                    raise ValueError("symlink escapes image: " + relative)
                resolved.pop()
                continue
            resolved.append(component)
            target_entry = entries.get("/".join(resolved))
            if target_entry is None:
                raise ValueError("dangling symlink: " + relative)
            if target_entry["kind"] == "symlink":
                followed += 1
                if followed > 40:
                    raise ValueError("symlink cycle: " + relative)
                target = target_entry["target"]
                if not target or any(ord(c) < 32 for c in target):
                    raise ValueError("invalid symlink target")
                resolved.pop()
                if target.startswith("/"):
                    resolved = []
                todo = target.split("/") + todo
            elif todo and target_entry["kind"] != "directory":
                raise ValueError("symlink traverses file: " + relative)


def verify_rootfs(root, manifest_path, expected):
    document = pinned_json(manifest_path, expected)
    if document.get("schema") != "oracle-rootfs-v1" or document.get("platform") != "linux-x86_64":
        raise ValueError("expected Linux x86-64 rootfs lock")
    if document.get("python") != "3.12" or document.get("dependencies") != DEPENDENCIES:
        raise ValueError("rootfs must declare the pinned Python 3.12 dependency environment")
    entries = document["entries"]
    require_spk_members(entries)
    validate_links(entries)
    for relative, entry in entries.items():
        if relative in ("sandstorm-manifest", "sandstorm-http-bridge-config", "minidregg-data.json") or any(relative == p or relative.startswith(p + "/") for p in ("opt/oracle", "opt/oracle-bin", "opt/oracle-data")):
            raise ValueError("reserved appliance path in rootfs: " + relative)
        if relative.split("/")[0] in ("var", "tmp", "proc", "dev") and "/" in relative:
            raise ValueError("rootfs mount points must be empty: " + relative)
    for mount in ("var", "tmp", "proc", "dev", "opt"):
        if entries.get(mount) != {"kind": "directory"}:
            raise ValueError("missing real rootfs directory: " + mount)
    if entries.get("usr/bin/python3.12", {}).get("kind") != "file" or not entries["usr/bin/python3.12"].get("executable"):
        raise ValueError("rootfs needs a regular executable /usr/bin/python3.12")
    if inventory(root) != entries:
        raise ValueError("rootfs bytes, modes, links or inventory differ from lock")
    linux_binary(root / "usr/bin/python3.12")
    return entries


def verify_appliance(root, expected, external_files=frozenset()):
    receipt_path = root / "APPLIANCE.json"
    receipt = pinned_json(receipt_path, expected)
    entries = receipt["files"]
    for relative in entries:
        name(relative)
    # External bytes are checked by the shared-data publisher. This stage signs
    # only their expected hashes and symlink names, so do not re-read 15 GB here.
    actual = inventory(root, unhashed=external_files)
    actual_files = {}
    for relative, entry in actual.items():
        if entry["kind"] == "symlink":
            raise ValueError("symlink in appliance")
        if entry["kind"] == "file" and relative != "APPLIANCE.json":
            if relative in external_files:
                entry["sha256"] = entries[relative]["sha256"]
            actual_files[relative] = {k: v for k, v in entry.items() if k != "kind"}
    if actual_files != entries:
        raise ValueError("appliance file bytes, executable bits or inventory differ from APPLIANCE.json")
    if "adapter/serve.py" not in entries or "root" not in actual:
        raise ValueError("missing adapter or data root")
    return actual, receipt


def data_inventory(document, appliance_receipt):
    if set(document) != {"schema", "visibility", "files"} or document["schema"] != "minidregg-public-data-inventory-v1" or document["visibility"] != "public":
        raise ValueError("invalid public data inventory")
    files = document["files"]
    if not isinstance(files, list) or not 1 <= len(files) <= 4096:
        raise ValueError("invalid public data file count")
    result = {}
    previous = ""
    for entry in files:
        if not isinstance(entry, dict) or set(entry) != {"path", "size", "sha256"}:
            raise ValueError("invalid public data entry")
        path = name(entry["path"])
        parts = path.split("/")
        if path <= previous or not re.fullmatch(r"[A-Za-z0-9_./-]+", path) or len(path) > 1024 or len(parts) > 16 or any(len(part) > 255 for part in parts):
            raise ValueError("public data paths must be sorted, unique and bounded")
        previous = path
        if type(entry["size"]) is not int or not 0 <= entry["size"] <= 2**64 - 1 or not isinstance(entry["sha256"], str) or not re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]):
            raise ValueError("invalid public data size or digest")
        original = appliance_receipt["files"].get(path)
        if not path.startswith("root/") or original != {"size": entry["size"], "sha256": entry["sha256"], "executable": False}:
            raise ValueError("shared data differs from non-executable appliance member: " + path)
        result[path] = entry
    if sum(entry["size"] for entry in files) > 64 * 1024**3:
        raise ValueError("shared data exceeds 64 GiB")
    if any(store["path"] not in result for store in appliance_receipt.get("stores", [])):
        raise ValueError("shared inventory must include every declared bulk store")
    return result


def write_data_inventory(args):
    receipt = pinned_json(args.appliance / "APPLIANCE.json", args.appliance_sha256)
    selection = json.loads(args.selection.read_text())
    if selection.get("schema") != "oracle-shared-data-selection-v1":
        raise ValueError("invalid explicit data selection")
    paths = selection["paths"]
    if paths != sorted(set(paths)):
        raise ValueError("data selection must be sorted and unique")
    document = {"schema": "minidregg-public-data-inventory-v1", "visibility": "public",
                "files": [{"path": path, "size": receipt["files"][path]["size"],
                           "sha256": receipt["files"][path]["sha256"]} for path in paths]}
    data_inventory(document, receipt)
    raw = (json.dumps(document, sort_keys=True, separators=(",", ":")) + "\n").encode()
    if len(raw) > 1024 * 1024:
        raise ValueError("public data inventory exceeds 1 MiB")
    with args.out.open("xb") as out:
        out.write(raw)
    print(json.dumps({"inventory_sha256": hashlib.sha256(raw).hexdigest(), "files": len(paths),
                      "bytes": sum(entry["size"] for entry in document["files"]),
                      "scope": "Expected public data from pinned appliance receipt; publisher must verify actual file bytes."}))


def linux_binary(path):
    with path.open("rb") as stream:
        header = stream.read(20)
    if len(header) != 20 or header[:6] != b"\x7fELF\x02\x01" or header[18:20] != b"\x3e\x00":
        raise ValueError("expected Linux x86-64 ELF input: " + str(path))


def require_spk_members(entries, prefix=""):
    oversized = [(prefix + path, entry["size"]) for path, entry in entries.items()
                 if entry.get("kind", "file") == "file" and entry["size"] >= SPK_MEMBER_LIMIT]
    if oversized:
        details = "; ".join(f"{path}: {size} bytes" for path, size in oversized)
        raise ValueError("SPK Cap'n Proto Data members must be below 512 MiB; " + details +
                         ". A separately admitted immutable-data contract or a format change is required.")


def publish(source, target):
    # Atomic no-replace publication, including against another builder.
    libc = ctypes.CDLL(None, use_errno=True)
    if sys.platform == "linux":
        result = libc.renameat2(-100, os.fsencode(source), -100, os.fsencode(target), 1)
    elif sys.platform == "darwin":
        result = libc.renamex_np(os.fsencode(source), os.fsencode(target), 4)
    else:
        raise RuntimeError("no atomic no-replace publisher for this platform")
    if result:
        raise OSError(ctypes.get_errno(), "cannot publish stage", str(target))


def encode(capnp, schema, kind, text, target):
    result = subprocess.run([str(capnp), "encode", str(schema), kind], input=text.encode(),
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    target.write_bytes(result.stdout)


def build(args):
    rootfs = args.rootfs.resolve(strict=True)
    appliance = args.appliance.resolve(strict=True)
    bridge = args.bridge.resolve(strict=True)
    schema = REPO / "native/spk-rpc/schema/package.capnp"
    if args.target.exists():
        raise ValueError("stage already exists")
    declaration = pinned_json(appliance / "APPLIANCE.json", args.appliance_sha256)
    external = {}
    if getattr(args, "data_inventory", None) is not None:
        if args.data_inventory.stat().st_size > 1024 * 1024:
            raise ValueError("public data inventory exceeds 1 MiB")
        external = data_inventory(pinned_json(args.data_inventory, args.data_sha256), declaration)
    elif getattr(args, "data_sha256", None) is not None:
        raise ValueError("data digest requires inventory")
    # Detect the format blocker from the pinned declaration before reading stores.
    require_spk_members({p: e for p, e in declaration["files"].items() if p not in external}, "opt/oracle/")
    rootfs_entries = verify_rootfs(rootfs, args.rootfs_manifest, args.rootfs_sha256)
    appliance_entries, receipt = verify_appliance(appliance, args.appliance_sha256, external)
    require_spk_members(rootfs_entries)
    require_spk_members({p: e for p, e in appliance_entries.items() if p not in external}, "opt/oracle/")
    pinned(bridge, args.bridge_sha256)
    linux_binary(bridge)
    if not bridge.stat().st_mode & 0o111:
        raise ValueError("bridge input is not executable")
    if not args.app_id or any(c not in "0123456789abcdefghijklmnopqrstuvwxyz" for c in args.app_id):
        raise ValueError("app ID must be the existing spk keygen ID")
    if not 0 <= args.version <= 0xffffffff:
        raise ValueError("app version outside UInt32")
    target = args.target.absolute()
    temporary = Path(tempfile.mkdtemp(prefix=".oracle-stage-", dir=target.parent))
    try:
        image = temporary / "image"
        binary = image / "opt/oracle-bin"
        binary.mkdir(parents=True)
        if external:
            (image / "opt/oracle-data").mkdir()
            attachment = {"schema": "minidregg-public-data-v1", "inventory_sha256": args.data_sha256}
            (image / "minidregg-data.json").write_text(json.dumps(attachment, sort_keys=True, separators=(",", ":")) + "\n")
            for path in external:
                link = image / "opt/oracle" / path
                link.parent.mkdir(parents=True, exist_ok=True)
                link.symlink_to("/opt/oracle-data/" + path)
        shutil.copyfile(HERE / "launch.py", binary / "launch.py")
        shutil.copyfile(bridge, binary / "minidregg-oracle-appliance")
        (binary / "minidregg-oracle-appliance").chmod(0o755)
        pinned(binary / "minidregg-oracle-appliance", args.bridge_sha256)
        command = '''(argv = ["/usr/bin/python3.12", "-B", "/opt/oracle-bin/launch.py"],
          environ = [(key = "PATH", value = "/usr/bin:/bin"),
          (key = "HOME", value = "/var"), (key = "TMPDIR", value = "/tmp"),
          (key = "PYTHONDONTWRITEBYTECODE", value = "1"),
          (key = "PYTHONIOENCODING", value = "utf-8"),
          (key = "LANG", value = "C.UTF-8")])'''
        if external:
            command = command.replace('environ = [', 'environ = [(key = "NLTK_DATA", value = "/opt/oracle-data/root/nltk_data"), ')
        manifest = f'''(appTitle = (defaultText = "Oracle7"), appVersion = {args.version},
          appMarketingVersion = (defaultText = "4.9 repaired appliance"),
          actions = [(input = (none = void), nounPhrase = (defaultText = "Oracle7 workspace"), command = {command})],
          continueCommand = {command})'''
        encode(args.capnp, schema, "Manifest", manifest, image / "sandstorm-manifest")
        encode(args.capnp, schema, "BridgeConfig", BRIDGE_CONFIG, image / "sandstorm-http-bridge-config")
        (temporary / "manifest.txt").write_text(manifest + "\n")
        (temporary / "bridge-config.txt").write_text(BRIDGE_CONFIG + "\n")
        generated = inventory(image)
        require_spk_members(generated)
        expected_package = dict(rootfs_entries)
        for path, entry in generated.items():
            if path in expected_package and expected_package[path] != entry:
                raise ValueError("generated/rootfs package path collision: " + path)
            expected_package[path] = entry
        expected_package["opt/oracle"] = {"kind": "directory"}
        expected_package.update({"opt/oracle/" + p: entry for p, entry in appliance_entries.items() if p not in external})
        paths = set(rootfs_entries) | set(generated) | {"opt/oracle"}
        paths.update("opt/oracle/" + p for p in appliance_entries)
        (temporary / "files.list").write_text("\n".join(sorted(paths)) + "\n")
        (temporary / "schema").mkdir()
        for source in schema.parent.glob("*.capnp"):
            shutil.copyfile(source, temporary / "schema" / source.name)
        q = json.dumps
        definition = f'''@0xeab81bacda911e95;
using Spk = import "schema/package.capnp";
const pkgdef :Spk.PackageDefinition = (
  id = {q(args.app_id)}, fileList = "files.list",
  sourceMap = (searchPath = [
    (sourcePath = "image"),
    (packagePath = "opt/oracle", sourcePath = {q(str(appliance))}),
    (sourcePath = {q(str(rootfs))})]));
'''
        (temporary / "sandstorm-pkgdef.capnp").write_text(definition)
        package_sources = {}
        for path, entry in expected_package.items():
            if path in generated:
                package_sources[path] = {"root": "image", "path": path}
            elif path.startswith("opt/oracle/"):
                package_sources[path] = {"root": "appliance", "path": path[len("opt/oracle/"):]}
            else:
                package_sources[path] = {"root": "rootfs", "path": path}
        stage_receipt = {
            "schema": "oracle-package-stage-v1", "signed": False,
            "app_id": args.app_id, "version": args.version,
            "inputs": {"appliance": str(appliance), "appliance_sha256": args.appliance_sha256,
                       "rootfs": str(rootfs), "rootfs_manifest": str(args.rootfs_manifest.resolve()),
                       "rootfs_sha256": args.rootfs_sha256, "bridge_sha256": args.bridge_sha256},
            "source_revision": receipt.get("source_revision"),
            "expected_package_entries": dict(sorted(expected_package.items())),
            "package_sources": package_sources,
            "shared_data": None if not external else {
                "inventory_sha256": args.data_sha256, "inventory": str(args.data_inventory.resolve()),
                "files": list(external.values()), "mount": "/opt/oracle-data",
                "verification": "Publisher verifies external bytes; runtime package pins exact inventory and symlinks."},
            "validation_scope": "Point-in-time input validation; external source directories remain mutable.",
            "generated_files": inventory(temporary),
            "schema_files": {p.name: digest(p) for p in sorted(schema.parent.glob("*.capnp"))},
            "notes": "No final signed-package claim until verify-package compares its signature and exact member inventory to this separately pinned receipt. No Mini admission.",
        }
        (temporary / "STAGE.json").write_text(json.dumps(stage_receipt, sort_keys=True, indent=2) + "\n")
        publish(temporary, target)
    except BaseException:
        shutil.rmtree(temporary)
        raise
    print(json.dumps({"stage": str(target), "signed": False, "files": len(paths)}))


def verify_stage(stage):
    receipt = json.loads((stage / "STAGE.json").read_text())
    if receipt.get("schema") != "oracle-package-stage-v1":
        raise ValueError("unknown stage schema")
    actual = inventory(stage)
    actual.pop("STAGE.json", None)
    if actual != receipt["generated_files"]:
        raise ValueError("generated package files changed")
    inputs = receipt["inputs"]
    verify_rootfs(Path(inputs["rootfs"]), Path(inputs["rootfs_manifest"]), inputs["rootfs_sha256"])
    shared = receipt.get("shared_data")
    external = {}
    if shared:
        declaration = pinned_json(Path(inputs["appliance"]) / "APPLIANCE.json", inputs["appliance_sha256"])
        external = data_inventory(pinned_json(Path(shared["inventory"]), shared["inventory_sha256"]), declaration)
    verify_appliance(Path(inputs["appliance"]), inputs["appliance_sha256"], external)
    schema_dir = REPO / "native/spk-rpc/schema"
    if {p.name: digest(p) for p in sorted(schema_dir.glob("*.capnp"))} != receipt["schema_files"]:
        raise ValueError("pinned package schemas changed")
    return receipt


def compare_package(receipt, actual):
    if actual.get("schema") != "verified-spk-inventory-v1" or actual.get("signature_verified") is not True:
        raise ValueError("inspector did not verify a signed SPK")
    if actual.get("app_id") != receipt["app_id"] or actual.get("app_version") != receipt["version"]:
        raise ValueError("signed package identity or version differs from pinned stage")
    expected = receipt["expected_package_entries"]
    found = actual["entries"]
    if found != expected:
        missing = sorted(set(expected) - set(found))[:5]
        extra = sorted(set(found) - set(expected))[:5]
        changed = sorted(p for p in set(expected) & set(found) if expected[p] != found[p])[:5]
        raise ValueError(f"signed package inventory differs: missing={missing}, extra={extra}, changed={changed}")


def verify_package(args):
    if args.out.exists():
        raise ValueError("post-pack receipt already exists")
    stage_path = args.stage / "STAGE.json"
    receipt = pinned_json(stage_path, args.stage_sha256)
    if receipt.get("schema") != "oracle-package-stage-v1":
        raise ValueError("unknown stage schema")
    # Inspector itself bounds output to 16 MiB and streams regular member hashes.
    # Its verifier snapshots package bytes before signature checking.
    # Execute a private, byte-pinned inspector copy rather than re-opening a
    # mutable tool path after hashing it. This copy contains no corpus data.
    with tempfile.TemporaryDirectory(prefix="oracle-inspector-", dir=args.scratch) as directory:
        executable = Path(directory) / "inspect"
        fd = os.open(args.inspector, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd, "rb") as source, executable.open("xb") as target:
            if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
                raise ValueError("inspector is not regular")
            count = 0
            for block in iter(lambda: source.read(1024 * 1024), b""):
                count += len(block)
                if count > 256 * 1024 * 1024:
                    raise ValueError("inspector exceeds 256 MiB")
                target.write(block)
        pinned(executable, args.inspector_sha256)
        executable.chmod(0o700)
        result = subprocess.run([str(executable.resolve()), str(args.package.resolve()),
                                 str(args.scratch.resolve()), args.profile],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=1800)
        if result.returncode:
            raise ValueError("signed-package inspector refused: " + result.stderr[:4096].decode("utf-8", "replace"))
    if len(result.stdout) > 16 * 1024 * 1024:
        raise ValueError("inspector inventory exceeds 16 MiB")
    actual = json.loads(result.stdout)
    compare_package(receipt, actual)
    final = {"schema": "oracle-post-pack-verification-v1", "signature_verified": True,
             "exact_inventory_verified": True, "stage_sha256": args.stage_sha256,
             "inspector_sha256": args.inspector_sha256,
             "shared_data_inventory_sha256": (receipt.get("shared_data") or {}).get("inventory_sha256"),
             **{key: actual[key] for key in ("app_id", "app_version", "public_key_hex", "raw_sha256", "raw_bytes", "profile")},
             "inventory_sha256": hashlib.sha256(json.dumps(actual["entries"], sort_keys=True, separators=(",", ":")).encode()).hexdigest(),
             "scope": "Signed snapshot matches pinned stage; Mini must import this exact raw_sha256. No Mini admission or deployment."}
    with args.out.open("x") as out:
        json.dump(final, out, indent=2, sort_keys=True)
        out.write("\n")
    print(json.dumps(final, sort_keys=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="operation", required=True)
    inv = sub.add_parser("inventory", help="write a proposed lock; review before pinning its hash")
    inv.add_argument("--rootfs", type=Path, required=True)
    inv.add_argument("--out", type=Path, required=True)
    data = sub.add_parser("data-inventory", help="derive expected public data from pinned receipt and explicit selection")
    data.add_argument("--appliance", type=Path, required=True)
    data.add_argument("--appliance-sha256", required=True)
    data.add_argument("--selection", type=Path, default=HERE / "data-selection.json")
    data.add_argument("--out", type=Path, required=True)
    stage = sub.add_parser("stage")
    for field in ("rootfs", "rootfs-manifest", "appliance", "bridge", "target"):
        stage.add_argument("--" + field, type=Path, required=True)
    for field in ("rootfs-sha256", "appliance-sha256", "bridge-sha256", "app-id"):
        stage.add_argument("--" + field, required=True)
    stage.add_argument("--version", type=int, required=True)
    stage.add_argument("--capnp", type=Path, default=Path(shutil.which("capnp") or "capnp"))
    stage.add_argument("--data-inventory", type=Path)
    stage.add_argument("--data-sha256")
    verify = sub.add_parser("verify")
    verify.add_argument("stage", type=Path)
    postpack = sub.add_parser("verify-package")
    for field in ("stage", "inspector", "package", "scratch", "out"):
        postpack.add_argument("--" + field, type=Path, required=True)
    for field in ("stage-sha256", "inspector-sha256"):
        postpack.add_argument("--" + field, required=True)
    postpack.add_argument("--profile", choices=("standard-v1", "operator-appliance-v1"), default="standard-v1")
    args = parser.parse_args()
    if args.operation == "inventory":
        document = {"schema": "oracle-rootfs-v1", "platform": "linux-x86_64", "python": "3.12",
                    "dependencies": DEPENDENCIES, "entries": inventory(args.rootfs.resolve(strict=True))}
        validate_links(document["entries"])
        # This inventory records required versions, not proof they are installed.
        with args.out.open("x") as target:
            json.dump(document, target, indent=2, sort_keys=True)
            target.write("\n")
    elif args.operation == "stage":
        build(args)
    elif args.operation == "data-inventory":
        write_data_inventory(args)
    elif args.operation == "verify-package":
        verify_package(args)
    else:
        verify_stage(args.stage.resolve(strict=True))
        print("stage and external input hashes match")


if __name__ == "__main__":
    main()
