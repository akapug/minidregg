# Oracle7 package preparation

For capabilities, architecture and current integration status, start with the
[appliance overview](../../docs/oracle-appliance.md). This directory documents
the operator's packaging tools and versioned inputs.

This directory builds a signed Linux runtime SPK and the exact inventory for
its separately published shared public data. The fixed launcher, source-map
stager, canonical SPK signer and independent post-pack verifier preserve the
existing Mini application path. Packaging alone creates no Mini grant or service.

The monolithic appliance cannot fit SPK because six SQLite files exceed its
per-member limit. The split recipe keeps 26 public data files outside the SPK and
signs explicit links to the fixed `/opt/oracle-data` mount. It does not chunk or
reconstruct stores. See the [shared-data contract and recipe](../../docs/oracle-shared-data-packaging.md).

The [v5 runtime receipt](runtime-v5-receipt.json) records the actual signed Linux
artifact and independent verification of all 15,358 members. Its 97.0 MB
compressed size fits the existing 256 MiB limit; the 15 GB public stores remain
in their separately pinned shared dataset. Mini acceptance and public deployment
are separate outcomes. V5 adds structured discovery/invocation, pinned sibling
providers and Pillow, plus the repaired source and date metadata. The
[v4 receipt](runtime-v4-receipt.json) and older artifacts remain preserved.
The host must also include the native status-header serialization fix recorded
in the receipt.

[Version 6](runtime-v6.md) adds the tenant pool and browser interface, incorporating
the newer U6-v2 source composition. Its [receipt](runtime-v6-receipt.json) records
independent signature and exact-member verification. Use a fresh grain: it
requires the host's source-session identity projection and refuses legacy shared
journals. The v5 artifacts and retained recovery run remain separate.

The [earlier v4 receiving run](../../docs/oracle-shared-data-2026-10-27.md) reached
admitted Oracle queries in two grains, shared read-only data, and separate
conversation state. Full acceptance is incomplete: the wrong-inventory fixture
failed for its directory mode, and cleanup exposed an already-stopped resident
recovery limitation. The dated record preserves those failures and the remaining
restart checks; component tests and packaging receipts do not replace that run.
The newer v5 controller/agent journey has separate
[retained evidence](../../docs/evidence/oracle-u3-acceptance-2026-10-27.json);
the overview distinguishes it from subsequent unsigned Oracle candidates.

## Exact inputs

`candidate-2026-10-26.json` retains the historical monolithic candidate pin. Each
new stage takes an explicit current `APPLIANCE.json` hash. That
receipt pins every source file, adapter, corrected release patch, store and
kernel overlay. The stager verifies runtime file SHA-256, size and executable
bits, and rejects unlisted source files and symlinks. The separate publisher
checks shared data bytes against the exact inventory. These checks concern
byte identity; the adapter is untrusted computation, and earlier kernel panel
receipts do not qualify all Oracle answers.

Prepare an explicit, dedicated **Linux x86-64 rootfs**, containing Python 3.12 at
`/usr/bin/python3.12` as a regular executable. It needs the exact dependencies in
`check-runtime.py`, their transitive dependencies, the interpreter's standard
library (including SQLite and multiprocessing), `libgmp.so.10`, glibc >=2.34 and
`/lib64/ld-linux-x86-64.so.2`. Preserve package licenses. Use a digest-pinned base
image and retained hash-locked wheels/package inputs; there is no floating
distribution download or automatic pip install in this recipe.

Run the import check **inside that rootfs on Linux**, retaining stdout as build
evidence. A rootfs inventory records required versions but cannot prove that
Python imports work. For example, with an operator-owned rootfs:

```sh
chroot "$ROOTFS" /usr/bin/python3.12 -B - < deploy/oracle/check-runtime.py
python3 -B deploy/oracle/stage.py inventory --rootfs "$ROOTFS" --out "$ROOTFS_LOCK"
sha256sum "$ROOTFS_LOCK"
```

Review the resulting lock and pin its hash separately. `inventory` walks only
the explicitly supplied directory, never follows links, refuses special/setid
files, and never overwrites a lock. It is not intended for `/` or an operator's
home. Keep `/var`, `/tmp`, `/proc` and `/dev` empty real directories, plus a real
`/opt`. Links must resolve inside the image. Input inventories contain every
entry and the stager rejects discrepancies. No host credential/home directories
are automatically added. Build the bridge from `native/oracle-appliance` using
the repository's independent native build route, retain the build receipt, and
pin the resulting **Linux** ELF binary's SHA-256; a macOS development binary is
refused.

## Stage and sign

All variables are explicit operator inputs; the app and its callers cannot
select host paths or signing keys. Build the Linux closure from `rootfs/` and the
small pinned packer from `pack/` in independent source snapshots.

```sh
python3 -B deploy/oracle/stage.py data-inventory \
  --appliance "$APPLIANCE" --appliance-sha256 "$APPLIANCE_RECEIPT_SHA256" \
  --selection deploy/oracle/data-selection-v5.json --out "$NEW_DATA_INVENTORY"

python3 -B deploy/oracle/stage.py stage \
  --rootfs "$ROOTFS" --rootfs-manifest "$ROOTFS_LOCK" --rootfs-sha256 "$ROOTFS_LOCK_SHA256" \
  --appliance "$APPLIANCE" --appliance-sha256 "$APPLIANCE_RECEIPT_SHA256" \
  --bridge "$LINUX_BRIDGE" --bridge-sha256 "$LINUX_BRIDGE_SHA256" \
  --data-inventory "$NEW_DATA_INVENTORY" --data-sha256 "$DATA_INVENTORY_SHA256" \
  --app-id "$SIGNING_APP_ID" --version "$PACKAGE_VERSION" \
  --target "$NEW_STAGE"
python3 -B deploy/oracle/stage.py verify "$NEW_STAGE"
"$PACKER" pack "$NEW_STAGE" "$REVIEWED_STAGE_SHA256" "$PRIVATE_KEY" "$NEW_RUNTIME_SPK"
```

The source-map stage uses an exact `files.list`; it has no recursive
`alwaysInclude` and does not duplicate the corpus. Only the small bridge,
launcher, schemas, symlink overlay and binary metadata are copied. Publication is an
atomic no-replace rename. An existing target is preserved. The stage contains
binary `sandstorm-manifest`, binary `sandstorm-http-bridge-config`, the
`sandstorm-pkgdef.capnp:pkgdef` package definition and an unsigned `STAGE.json`
receipt. Keep inputs in immutable operator snapshots while packing: hash checks
are not a filesystem snapshot and cannot prevent concurrent mutation.
`STAGE.json` records the exact expected final member inventory, including source,
shared-data links and declaration, rootfs, launcher, bridge and binary metadata.
Packaging schema sources remain outside the image; their hashes and the encoded
metadata hashes are retained. Pin the hash of `STAGE.json` separately **before**
packing. An unsigned stage or a successful recheck of its external paths cannot
establish what a subsequently signed package actually contains.

The `pack/` tool uses Mini's existing generated Sandstorm archive schema and
signs the exact selected members, then compresses the signed payload. It refuses output above
Mini's standard size limits. Retain its binary hash, Cargo lock and key's public
identity. Never store signing keys in the stage or image. An upstream Sandstorm
`spk` builder can also use the generated package definition; either producer
must pass the same independent final-inventory check.
After packing, use the `inspect` example from `native/spk-package-stream`, built
in an independent native snapshot. Pin the inspector binary hash as an operator
input. The example verifies a private snapshot's signature and streams each
regular member into SHA-256, retaining at most 16 MiB of inventory JSON. Its
explicit protected scratch directory must be disk-backed with room for the raw
and decoded package; do not use a small tmpfs for appliance imports.
The wrapper parses the same receipt bytes it hashes and executes a private
hash-checked copy of the inspector, so replacing either input path afterward
does not change this verification.

```sh
python3 -B deploy/oracle/stage.py verify-package \
  --stage "$NEW_STAGE" --stage-sha256 "$REVIEWED_STAGE_SHA256" \
  --inspector "$INSPECTOR" --inspector-sha256 "$INSPECTOR_SHA256" \
  --package "$SIGNED_SPK" --scratch "$PROTECTED_DISK_SCRATCH" \
  --profile standard-v1 --out "$NEW_POST_PACK_RECEIPT"
```

This checks the signature-derived application identity, version, every member's
path/type/size/hash/executable flag or link target, and absence of extra members.
It rejects packing-time changes even if inputs were restored before a later
source recheck. The receipt binds the exact verified package SHA-256 to the
separately pinned stage and inspector. A package path may change afterward:
Mini's importer must import **that same raw SHA-256**, verify its signature, and record its
application/manifests; `STAGE.json` does not substitute for that admission.

Mini's shared-data publisher verifies and protects the external stores before
launch. The runtime package's signed `minidregg-data.json` pins that exact public
inventory; Mini mounts its matching published contents at `/opt/oracle-data`.
Missing or corrupt data is a launch refusal. The runtime cannot supply a host
path or grant itself access to another dataset.

## Operator import and recovery

Keep `--profile standard-v1` for the post-pack verification above: the v5
artifact passed those archive bounds. That check does not establish how long
Mini needs to materialize its 15,358 members. For this runtime, select
`"importProfile": "operator-appliance-v1"` in the operator-owned broker
`config.json`. The intake deadline is then 1,800 seconds instead of the default
120 seconds. This is a physical intake budget selected by the operator, not a
package declaration or caller parameter; signature, package identity and Mini
admission still apply. The runtime remains within the standard 256 MiB raw
package cap.

The acceptance harness selects that broker setting through
`ORACLE_IMPORT_PROFILE=operator-appliance-v1` (its current default). Its first
v3 attempt used the standard profile and timed out during materialization after
creating a prepared INSTALL record. At that checkpoint, INSTALL was prepared
but incomplete and no START had occurred. The package and post-pack receipt
remain unchanged.

Recovery uses `scripts/oracle-shared-data-journey.sh --resume` with the same six
original arguments. It checks the retained package, inventory, binaries and
prepared INSTALL bytes, then retries physical image preparation and completion
for that existing record. Do not create a replacement install or edit its
prepared claim. The original failure evidence is retained under the run's
`initial-attempt/`, including `evidence/install-a.stderr`, `install-status.json`,
`native-state.tar` and `input-sha256.txt`. The observed timeout is recorded here;
this checkpoint does not establish a passing acceptance result. Later v3
attempts reached START and enrollment but exposed the HTTP response-header
refusal addressed by the host fix and v4 composed transport tests. V4 receiving
acceptance remains a separate run.

## Inside the grain

Both first launch and restart execute `/usr/bin/python3.12 -B
/opt/oracle-bin/launch.py`, with a fixed environment. The launcher takes no
arguments, confirms connected supervisor fd 3, and starts:

```text
/usr/bin/python3.12 -B /opt/oracle/adapter/serve.py
  --runtime /opt/oracle --data-root /opt/oracle/root
  --workspace /var/oracle-workspace --port 7070
  --max-request-bytes 65536
/opt/oracle-bin/minidregg-oracle-appliance --port 7070
```

Python and its engine receive no supervisor fd. After bounded adapter health
readiness, only the Rust bridge receives fd 3. Each child has its own process
group. Shutdown signals the leaders for journal/engine cleanup, then kills only
the groups this launcher created; Linux subreaping collects orphan descendants.
An adapter crash also tears down the bridge and remaining engine workers. Mini's
existing process namespace/cgroup lifecycle remains the outer cleanup boundary.

Mini mounts the package read-only; `/opt/oracle` holds source and stores. `/var`
is the grain's private persistent volume, and `/tmp` is the host's bounded
temporary mount. The adapter's HTTP socket is namespace-local loopback only,
not an exposed host listener. One grain means one conversation workspace shared
by its grant holders; use separate grains for separate tenants.

The signed API prefix is `/`. Permission zero is `query`, title `Ask questions`,
description `Use this appliance's shared conversation workspace`. Role zero is
`Researcher`, verb `can ask questions`, description `Ask questions and inspect
this appliance`, permission `[true]`, default false. These match the bridge's
`getViewInfo`; the package cannot grant this permission to itself.

## Reach it through Mini

After actual signed import and the existing Mini create/start/share/API-session
operations, configure the operator route catalog from the returned application,
session, current grants, purse and subject. Record these real returned values in
the deployment receipt alongside the signed package hash, selected workspace,
signed prefix and exact permission metadata. The fixture-specific
`scripts/spk-platform/prepare-lifetime-route.sh` is not a ready-made Oracle
deployment: its fixture identities and `/repo.git/` prefix cannot be reused.

Agents use the existing `mini_application_api` tool with the application name
present in that tool's live enum. For example, construct its arguments from the
actual catalog name and freshly chosen Oracle request IDs:

```python
body = b'{"request_id":"q1","conversation_id":"research","text":"Who wrote Leaves of Grass?"}'
arguments = {
    "application": actual_catalog_application_name,
    "method": "POST", "path": "query", "query": "",
    "headers": [{"name": "content-type", "value": "application/json"}],
    "bodyHex": body.hex(),
}
```

No model-supplied URL, host path, socket or invented grant ID appears here.
`GET health` and `GET capabilities` use empty headers/body. Mini rechecks current
authority and purse settlement on each call. Preserve exact bytes for retries:
the same request ID with different bytes conflicts; a lost reply may still have
executed. The bridge's original HTTP status header and complete JSON reply
preserve busy/failure outcomes. Mini may omit large bodies from model text
presentation while retaining the exact native response.

The signed v5 runtime also exposes relative `GET operations` (bounded filters and
pagination), `GET operations/<id>`, and `POST invoke` for structured operations.
The request ceiling is 65,536 bytes in both the bridge and signed launcher.
See the [bridge route contract](../../docs/oracle-appliance-bridge.md) for exact
query fields and ID grammar. Its receiving journey has separate acceptance
evidence; the immutable v4 receipt does not claim these routes.

## Narrow verification

```sh
python3 -B -m unittest discover -s deploy/oracle -p test_stage.py -v
# In an independent native source snapshot:
cargo test --offline -p minidregg-spk-package-stream --example inspect
cargo test --offline --locked --manifest-path deploy/oracle/pack/Cargo.toml
```

Ten Python fixtures cover actual child processes (fd exclusion, graceful termination,
adapter crash and orphan-worker cleanup), Cap'n Proto encoding/decoding and
package-definition evaluation, changed/unlisted bytes, input link boundaries,
no overwrite, explicit oversized-store refusal and final-inventory mutation,
extra-file and wrong-signer refusal, split links, exact data inventory and bulk
coverage. Three Rust packer tests cover real signing, selected members, changed
inputs, no-overwrite publication and independent decoding of empty regular and
executable members. Two Rust inspector tests use a real signed
Bread SPK fixture to check streamed member hashes and signature-derived identity,
snapshot retention after source replacement, and bounded output. They neither run specialist
panels nor establish a signed/deployed Linux appliance.
