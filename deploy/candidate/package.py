#!/usr/bin/env python3
"""Package role binaries as a Mini candidate: the one shipping format.

  package.py --roles ROLES.json --source-archive SOURCE.tar --out NEW_DIR [--toolchains T.json]
             [--host-build-manifest MANIFEST.txt] [--into-existing]
  package.py --rust-roles        one line per Rust role: ROLE CRATE BINARY (the builders' list)
  package.py --fixture-roles     one line per journey fixture: ROLE CRATE BINARY (built beside, never shipped)

A candidate directory (deploy/candidate/INTERFACES.md) is what every consumer
reads: edge/mini/ship.sh, verify.sh, service-upgrade.sh, run.sh, the journey's
M7 step. It holds bin/<role binary>, SHA256SUMS, provenance.json
(minidregg-candidate-provenance-v1, one 40-hex source commit), source.tar,
logs/source-files.sha256, the operator scripts from the SAME archive (run.sh,
lib.sh, genesis.sh, genesis-params.example.json, INTERFACES.md) and
manifest.json (the journey-format manifest: absolute paths + SHA-256 pins for
this directory).

--roles: ROLES.json is a journey-format manifest of already-built binaries:
  {"sourceCommit": "<40 hex>", "host": "/abs/...", "mini": "/abs/...", ...,
   "sha256": {"host": "<hex>", ...}}
The archive's commit (git get-tar-commit-id) must equal sourceCommit: every
binary is claimed to be built from exactly that commit, and nothing else.
build.sh calls this after building (with --into-existing, the binaries already
in NEW_DIR/bin); a lane build on hbox calls it with its own role manifest.

ABI: every ELF's non-weak GLIBC version needs (readelf -V) are recorded in
provenance.json .abi; ship.sh refuses a box whose glibc is older than
.abi.glibcRequired, and the box's own loader checks every binary before
publication.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time

# role -> file name under bin/. Aliases (shell = mini, hermes = grainRuntime,
# browserProxy = spkBrowserProxy) are names for these, never separate bytes.
ROLES = {
    "host": "minidregg-host",
    "consent": "minidregg-client-consent",
    "mini": "mini",
    "store": "minidregg-link-sqlite-store",
    "verifier": "minidregg-credential-signature-verifier",
    "grainRuntime": "grain-runtime",
    "grainProviderBridge": "grain-provider-bridge",
    "inferenceScheduler": "mini-inference-scheduler",
    "spkHost": "spk-host",
    "spkBrowserProxy": "spk-browser-proxy",
    "spkBroker": "mini-spk-broker",
    "spkVolumeHelper": "mini-spk-volume-helper",
    "discord": "mini-discord",
    # The self-serve door (deploy/door/README.md): the /join form and its root processor.
    "door": "mini-door",
    "doorProcess": "mini-door-process",
    # The room mirror ships so it can be enabled; it is off unless configured (deploy/discord/README.md).
    "discordMirror": "mini-discord-mirror",
    "payWatcher": "pay-watcher",
    "keys": "mini-keys",
    # The grain launch gate: deploy/grain-host/install-controller and bwrap require it beside the
    # launcher, so it is a product binary (native/launch-gate builds deploy/grain-host/launch-gate.rs).
    "launchGate": "launch-gate",
    # The web front end (deploy/web-frontend/INSTALL.md): the gateway and its root session helper.
    "web": "mini-web",
    "webSpawn": "mini-web-spawn",
    # The research-labelled four-party private compute demo (native/private-backend, feature `demo`):
    # the `mini private-compute` verb and the jprivate row run it.
    "privateCompute": "mini-private-compute",
}
# The Rust roles, role -> crate (the binary is ROLES[role]). The ONE list both builders read
# (`package.py --rust-roles`): build.sh and lane-build.sh each kept their own copy, and the lane
# copy silently lacked mini-keys and mini-spk-broker. host and consent are Lean roles.
RUST_ROLES = (("mini", "resource-client"), ("store", "hyperdocument-link-sqlite-store"),
              ("verifier", "credential-signature-verifier"), ("grainRuntime", "grain-runtime"),
              ("grainProviderBridge", "grain-runtime"), ("inferenceScheduler", "inference-scheduler"),
              ("spkHost", "spk-host"), ("spkBrowserProxy", "spk-host"), ("spkBroker", "spk-host"),
              ("spkVolumeHelper", "spk-host"),
              ("discord", "discord-entrance"), ("door", "discord-entrance"), ("doorProcess", "discord-entrance"), ("discordMirror", "discord-entrance"),
              ("payWatcher", "pay-watcher"),
              ("keys", "mini-keys"), ("launchGate", "launch-gate"),
              ("web", "mini-web"), ("webSpawn", "mini-web-spawn"),
              ("privateCompute", "private-backend"))
# Cargo features a Rust role's binary requires (its [[bin]] required-features), printed as the fourth
# column of `--rust-roles`; both builders pass it as `--features`.
RUST_ROLE_FEATURES = {"privateCompute": "demo"}
# Journey fixtures: built from the tip they test by the journey tooling (lane-build.sh rust puts them in
# LANE_DIR/fixtures, pack copies them to OUT/fixtures/ with their own SHA256SUMS; journey-runner reads
# $set/fixtures/<binary>; scripts/check-journey.sh builds them from the tree), never in bin/, the
# manifest or the shipped SHA256SUMS: the deterministic OpenAI-compatible provider is not a product.
FIXTURES = (("testProvider", "hermes-test-provider", "mini-hermes-test-provider"),)
# consent is required: a candidate whose friends cannot sign (the client refuses to sign without a
# locally selected consent pair) is not shippable, so a roles manifest without it is refused.
# keys is required: split tenancy (step B) is the box's shape, and install.sh under split has no
# broker without bin/mini-keys, so a candidate without it cannot be installed there.
REQUIRED = ("host", "consent", "mini", "store", "verifier", "keys")
ALIASES = {"shell": "mini", "hermes": "grainRuntime", "browserProxy": "spkBrowserProxy", "consentHost": "consent"}
# The Linux friend bundle (W1.9 consent shipping): one directory a friend copies
# whole, hard links to bin/ (every candidate carries the consent pair).
LINUX = "x86_64-unknown-linux-gnu"
BUNDLE = ("mini", "minidregg-host", "minidregg-client-consent",
          "minidregg-credential-signature-verifier", "minidregg-link-sqlite-store")
# The operator scripts travel with the binaries, from the same archive.
SCRIPTS = {"check-tamper.sh": ("deploy/candidate/check-tamper.sh", 0o555),
           "run.sh": ("deploy/candidate/run.sh", 0o555), "lib.sh": ("deploy/candidate/lib.sh", 0o555),
           "params.sh": ("deploy/candidate/params.sh", 0o555),
           "genesis.sh": ("native/resource-client/genesis.sh", 0o555),
           "genesis-params.example.json": ("native/resource-client/genesis-params.example.json", 0o444),
           "INTERFACES.md": ("deploy/candidate/INTERFACES.md", 0o444)}
HEX40 = re.compile(r"[0-9a-f]{40}")
HEX64 = re.compile(r"[0-9a-f]{64}")


def die(message):
    print("package: " + message, file=sys.stderr)
    raise SystemExit(1)


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def tar_commit(archive):
    with open(archive, "rb") as stream:
        out = subprocess.run(["git", "get-tar-commit-id"], stdin=stream, capture_output=True, text=True)
    commit = out.stdout.strip()
    if out.returncode != 0 or not HEX40.fullmatch(commit):
        die(f"{archive} carries no commit id; create it with `git archive <commit>`")
    return commit


def archive_tree(archive):
    """The git tree id of the archive's files, written in a throw-away repository. It needs no
    checkout of the commit, and for `git archive COMMIT` (the tree has no export-subst or
    export-ignore attributes) it equals COMMIT^{tree}."""
    with tempfile.TemporaryDirectory(prefix="package-tree-") as tmp:
        tmp = Path(tmp)
        work = tmp / "files"
        work.mkdir()
        subprocess.run(["tar", "-xf", str(Path(archive).resolve()), "-C", str(work)], check=True)
        env = {**os.environ, "GIT_DIR": str(tmp / "git"), "GIT_WORK_TREE": str(work),
               "GIT_INDEX_FILE": str(tmp / "index"), "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull}
        def git(*args):
            out = subprocess.run(["git", *args], cwd=work, env=env, capture_output=True, text=True)
            if out.returncode:
                die(f"{archive}: cannot compute its tree (git {' '.join(args)}): {out.stderr.strip()}")
            return out.stdout.strip()
        init = subprocess.run(["git", "init", "-q", "--bare", str(tmp / "git")], capture_output=True, text=True,
                              env={k: v for k, v in env.items() if k not in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE")})
        if init.returncode:
            die(f"{archive}: cannot compute its tree (git init): {init.stderr.strip()}")
        for key, value in (("core.filemode", "true"), ("core.symlinks", "true"), ("core.autocrlf", "false")):
            git("config", key, value)
        git("add", "-A", "-f", ".")
        tree = git("write-tree")
    if not HEX40.fullmatch(tree):
        die(f"{archive}: no tree id computed")
    return tree


def version_key(v):
    return tuple(int(x) for x in v.split("."))


def abi(path):
    """Non-weak GLIBC version needs of one ELF, from its verneed section."""
    with open(path, "rb") as stream:
        if stream.read(4) != b"\x7fELF":
            return None
    out = subprocess.run(["readelf", "-V", "--wide", str(path)], capture_output=True, text=True)
    if out.returncode != 0:
        die(f"readelf -V failed on {path}: {out.stderr.strip()}")
    strong, weak = set(), set()
    for line in out.stdout.splitlines():
        m = re.search(r"Name: GLIBC_([0-9]+(?:\.[0-9]+)+)\s+Flags: (\S+)", line)
        if m:
            (weak if "WEAK" in m.group(2) else strong).add(m.group(1))
    needed = subprocess.run(["readelf", "-d", "--wide", str(path)], capture_output=True, text=True).stdout
    libs = sorted(set(re.findall(r"\(NEEDED\)\s+Shared library: \[([^\]]+)\]", needed)))
    top = max(strong, key=version_key) if strong else None
    return {"glibcRequired": top, "glibcStrong": sorted(strong, key=version_key),
            "glibcWeakOnly": sorted(weak - strong, key=version_key), "needed": libs}


def source_file_list(archive, out):
    """sha256sum lines of every archived file, the format build.sh writes
    (`find . -type f ! -path './.lake/*' | sort -z | xargs sha256sum`)."""
    rows = []
    with tarfile.open(archive) as tar:
        for member in tar.getmembers():
            if not member.isfile():
                continue
            name = member.name if member.name.startswith("./") else "./" + member.name
            if name.startswith("./.lake/"):
                continue
            data = tar.extractfile(member).read()
            rows.append((name.encode(), hashlib.sha256(data).hexdigest()))
    rows.sort(key=lambda r: r[0])
    with open(out, "wb") as stream:
        for name, digest in rows:
            stream.write(digest.encode() + b"  " + name + b"\n")


def extract(archive, member, target, mode):
    with tarfile.open(archive) as tar:
        try:
            info = tar.getmember(member)
        except KeyError:
            die(f"{archive} lacks {member}")
        data = tar.extractfile(info).read()
    Path(target).write_bytes(data)
    os.chmod(target, mode)


def roles_from_manifest(manifest, label):
    """Shipped roles of a journey-format manifest, each pinned and present."""
    pins = manifest.get("sha256", {})
    chosen = {}
    for role in ROLES:
        if role not in manifest:
            continue
        path = Path(manifest[role])
        if not path.is_absolute():
            die(f"{label}: .{role} is not an absolute path")
        want = pins.get(role)
        if not (isinstance(want, str) and HEX64.fullmatch(want)):
            die(f"{label}: .sha256.{role} is not a SHA-256")
        if not path.is_file():
            die(f"{label}: .{role} {path} is not a file")
        got = sha(path)
        if got != want:
            die(f"{label}: {role} {path} is {got}, pinned {want}")
        chosen[role] = (path, want)
    missing = [r for r in REQUIRED if r not in chosen]
    if missing:
        die(f"{label}: required role(s) absent: {', '.join(missing)}")
    for alias, role in ALIASES.items():
        if alias in manifest and role in chosen and pins.get(alias) not in (None, chosen[role][1]):
            die(f"{label}: alias {alias} pins other bytes than {role}")
    return chosen


def build_identity(archive, commit, toolchains):
    """Require builder evidence; never substitute the packager's compiler for it."""
    rustc = toolchains.get("rustc", "")
    flags = toolchains.get("buildFlags")
    if not isinstance(rustc, str) or not all(x in rustc for x in
            ("rustc ", "commit-hash:", "host:", "release:", "LLVM version:")):
        die("build provenance requires the builder's rustc -vV")
    if not isinstance(flags, dict) or not flags.get("rust") or not flags.get("native"):
        die("build provenance requires buildFlags.rust and buildFlags.native")
    tree = archive_tree(archive)
    # A repository that holds the commit (lane-build, a checkout) must agree with the archive's own
    # tree: the archive is `git archive COMMIT` or it is refused. Without one (build.sh
    # --source-archive in an extracted tree) the archive's tree is the identity.
    repo = subprocess.run(["git", "rev-parse", "--verify", "-q", commit + "^{tree}"], capture_output=True, text=True)
    if repo.returncode == 0 and repo.stdout.strip() != tree:
        die(f"{archive}: its files hash to tree {tree}, but {commit[:12]}^{{tree}} in this repository is "
            f"{repo.stdout.strip()}: the archive is not `git archive {commit[:12]}`")
    with tarfile.open(archive) as tar:
        try:
            lean = tar.extractfile("lean-toolchain").read().decode()
        except KeyError:
            die("source archive lacks lean-toolchain")
        try:
            locks = {"Cargo.lock": hashlib.sha256(tar.extractfile("Cargo.lock").read()).hexdigest()}
        except KeyError:
            die("source archive lacks workspace Cargo.lock")
    return {"sourceTree": tree, "rustcVerbose": rustc,
            "leanToolchain": lean, "cargoLockSha256": locks, "flags": flags}


def package(chosen, archive, commit, out, toolchains, origin, host_build_manifest, into_existing):
    if tar_commit(archive) != commit:
        die(f"source archive commit is not {commit}")
    identity = build_identity(archive, commit, toolchains)
    if host_build_manifest is not None:
        args = Path(host_build_manifest).parent / "compile-args.txt"
        if not args.is_file():
            die("native build evidence lacks compile-args.txt")
        identity["flags"]["native"]["compileArgs"] = args.read_text()
        identity["flags"]["native"]["linkCommand"] = "leanc -o BINARY @OBJECT_RESPONSE_FILE"
        identity["flags"]["native"]["manifestSha256"] = sha(host_build_manifest)
    out = Path(out)
    if into_existing:
        if not (out / "bin").is_dir():
            die(f"--into-existing: {out}/bin does not exist")
    else:
        if out.exists() or out.is_symlink():
            die(f"refusing existing output: {out}")
        out.mkdir(parents=True)
        (out / "bin").mkdir()
    (out / "logs").mkdir(exist_ok=True)
    out = out.resolve()
    if tar_commit(archive) != commit:
        die(f"source archive commit is not {commit}")
    source_tar = out / "source.tar"
    if Path(archive).resolve() != source_tar:
        shutil.copyfile(archive, source_tar)
    binaries, abis = {}, {}
    for role, (path, want) in sorted(chosen.items()):
        target = out / "bin" / ROLES[role]
        if Path(path).resolve() != target:
            if target.exists():
                die(f"{target} exists and is not {role}'s source {path}")
            shutil.copyfile(path, target)
        os.chmod(target, 0o555)
        if sha(target) != want:
            die(f"{role} changed while copying")
        binaries[role] = {"path": f"bin/{ROLES[role]}", "sha256": want}
        found = abi(target)
        if found is not None:
            abis[role] = found
    for name, (member, mode) in SCRIPTS.items():
        extract(source_tar, member, out / name, mode)
    source_file_list(source_tar, out / "logs" / "source-files.sha256")
    floors = [a["glibcRequired"] for a in abis.values() if a["glibcRequired"]]
    provenance = {
        "type": "minidregg-candidate-provenance-v1",
        "source": {"commit": commit, "tree": identity["sourceTree"], "archive": "source.tar", "archiveSha256": sha(source_tar),
                   "origin": origin["type"], "fileList": "logs/source-files.sha256",
                   "fileListSha256": sha(out / "logs" / "source-files.sha256")},
        "target": "x86_64-linux",
        "toolchains": toolchains,
        "binaries": binaries,
        "abi": {"glibcRequired": max(floors, key=version_key) if floors else None, "binaries": abis},
        "packaging": origin,
        "builtUtc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    if host_build_manifest is not None:
        provenance["hostBuildManifest"] = {"path": str(host_build_manifest), "sha256": sha(host_build_manifest)}
    clients = {LINUX: {"path": "bin/mini", "sha256": binaries["mini"]["sha256"], "consent": None}}
    bundle_files = []
    bundle = out / "bin" / "clients" / LINUX
    bundle.mkdir(parents=True, exist_ok=True)
    for name in BUNDLE:
        link = bundle / name
        if not link.exists():
            os.link(out / "bin" / name, link)
        if sha(link) != sha(out / "bin" / name):
            die(f"friend bundle {name} differs from bin/{name}")
        bundle_files.append(f"bin/clients/{LINUX}/{name}")
    rel = f"bin/clients/{LINUX}"
    pin = lambda name: sha(out / "bin" / name)
    clients[LINUX]["consent"] = {
        "localHost": {"env": "MINI_LOCAL_HOST", "path": f"{rel}/minidregg-host", "sha256": pin("minidregg-host")},
        "consentHost": {"env": "MINI_CONSENT_HOST", "path": f"{rel}/minidregg-client-consent",
                        "sha256": pin("minidregg-client-consent")},
        "verifier": {"path": f"{rel}/minidregg-credential-signature-verifier",
                     "sha256": pin("minidregg-credential-signature-verifier")},
        "store": {"path": f"{rel}/minidregg-link-sqlite-store", "sha256": pin("minidregg-link-sqlite-store")}}
    extra_clients = sorted((out / "bin" / "clients").glob("*/mini")) if (out / "bin" / "clients").is_dir() else []
    for client in extra_clients:
        if client.parent.name != LINUX:
            clients[client.parent.name] = {"path": str(client.relative_to(out)), "sha256": sha(client), "consent": None}
    provenance["clients"] = clients
    # Include each physical shipping path, including the friend bundle and cross clients.
    outputs = {str(p.relative_to(out)): {"sha256": sha(p), "build": identity}
               for p in sorted((out / "bin").rglob("*")) if p.is_file()}
    provenance["outputs"] = outputs
    write_json(out / "provenance.json", provenance)
    listed = [f"bin/{ROLES[r]}" for r in sorted(chosen)] + [c["path"] for t, c in sorted(clients.items())
                                                            if c["path"] != "bin/mini"]
    listed += bundle_files + ["provenance.json", *SCRIPTS, "source.tar", "logs/source-files.sha256"]
    with open(out / "SHA256SUMS", "w") as stream:
        for rel in listed:
            stream.write(f"{sha(out / rel)}  {rel}\n")
    manifest = {role: str(out / "bin" / ROLES[role]) for role in chosen}
    pins = {role: want for role, (_, want) in chosen.items()}
    for alias, role in ALIASES.items():
        if role in chosen:
            manifest[alias] = manifest[role]
            pins[alias] = pins[role]
    manifest.update({"type": "minidregg-candidate-manifest-v2", "outputs": outputs,
                     "candidate": str(out / "provenance.json"), "sourceCommit": commit,
                     "spkHostFeatures": [],
                     "clients": {t: str(out / c["path"]) for t, c in clients.items()}})
    pins["candidate"] = sha(out / "provenance.json")
    manifest["sha256"] = pins
    write_json(out / "manifest.json", manifest)
    print(json.dumps({"candidate": str(out), "commit": commit, "roles": sorted(chosen),
                      "glibcRequired": provenance["abi"]["glibcRequired"],
                      "sha256sumsSha256": sha(out / "SHA256SUMS")}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--roles")
    parser.add_argument("--source-archive")
    parser.add_argument("--out", required=True)
    parser.add_argument("--toolchains")
    parser.add_argument("--host-build-manifest")
    parser.add_argument("--into-existing", action="store_true")
    if sys.argv[1:] == ["--rust-roles"]:
        for role, crate in RUST_ROLES:
            print(role, crate, ROLES[role], *([RUST_ROLE_FEATURES[role]] if role in RUST_ROLE_FEATURES else []))
        return
    if sys.argv[1:] == ["--fixture-roles"]:
        for role, crate, binary in FIXTURES:
            print(role, crate, binary)
        return
    a = parser.parse_args()
    if shutil.which("readelf") is None or shutil.which("git") is None:
        die("readelf (binutils) and git are required")
    if not a.roles:
        die("--roles is required")
    if not a.source_archive:
        die("--roles needs --source-archive")
    manifest = read(a.roles)
    commit = manifest.get("sourceCommit")
    if not (isinstance(commit, str) and HEX40.fullmatch(commit)):
        die("roles manifest .sourceCommit must be a 40-hex commit")
    chosen = roles_from_manifest(manifest, a.roles)
    # A builder ships every role it builds; a roles manifest missing one is a builder whose list drifted.
    absent = [r for r in ("host", "consent", *(r for r, _ in RUST_ROLES)) if r not in chosen]
    if absent:
        die(f"{a.roles}: the builders build every role; absent: {', '.join(absent)} "
            "(deploy/candidate/package.py --rust-roles is the list)")
    toolchains = read(a.toolchains) if a.toolchains else {"recorded": "none"}
    origin = {"type": manifest.get("origin", "roles-manifest"), "roles": str(Path(a.roles).resolve()),
              "rolesSha256": sha(a.roles)}
    hbm = Path(a.host_build_manifest).resolve() if a.host_build_manifest else None
    package(chosen, a.source_archive, commit, a.out, toolchains, origin, hbm, a.into_existing)


if __name__ == "__main__":
    main()
