# Oracle runtime package and shared public data

Oracle7 is packaged as a signed Linux runtime SPK plus one separately published,
immutable public dataset. The package uses Mini's existing application admission
and grain lifecycle. It does not contain SPK chunks, reconstruct stores in each
grain's mutable volume, or supply a host path to mount.

The input is an immutable appliance with its original `APPLIANCE.json`. The
explicit selection in `deploy/oracle/data-selection-v5.json` names 26 public data
files: SQLite stores, the WordNet archive and Gutenberg source texts. For the
October 27 candidate-u3-v3, they total 15,046,949,326 bytes; 90,144,917 bytes of Oracle
code and other assets remain in the runtime before Python and the app bridge.
The original appliance and its receipt are preserved.

The [v5 package receipt](../deploy/oracle/runtime-v5-receipt.json) records the
actual signed artifact: 96,985,616 compressed bytes and 519,614,440 decoded bytes,
with all 15,358 members independently checked. It fits Mini's existing standard
256/768 MiB limits. The receipt is packaging evidence; the separate acceptance
journey establishes what runs through Mini's current admission and calling path.
Earlier immutable packages are preserved. V5 adds structured operation routes,
pinned sibling providers and Pillow, and repaired Oracle source. The 2,627,008-byte
`root/relstore/date_precision_v1.json` sidecar stays in the signed runtime;
the public dataset inventory is unchanged.
The host also needs the native response-header serialization fix pinned by the
composed transport tests.

## Signed attachment and path layout

The SPK contains a small regular root member named `minidregg-data.json`:

```json
{"schema":"minidregg-public-data-v1","inventory_sha256":"<64 lowercase hexadecimal characters>"}
```

Its exact bytes are covered by the existing SPK signature and raw package
identity. The native importer reads it from that verified package snapshot. The
document is limited to 4 KiB; duplicates, unknown keys, other schema values and
malformed digests are refused. There is no host path, URL or alternate mount
target in it.

The digest names the exact bytes of a public dataset inventory:

```json
{"schema":"minidregg-public-data-inventory-v1","visibility":"public","files":[{"path":"root/relstore/relations_v2.sqlite3","size":5569425408,"sha256":"<file digest>"}]}
```

The complete inventory has sorted, unique relative paths and each file's size
and SHA-256. The publisher checks the complete selected bytes before making a
protected independent copy available. Additional source files are not included.
Source hardlinks are allowed; published files do not share writable inodes with
the source. This is public reference data, not a mechanism for granting access
to private files.

Mini supplies the matching published data at the fixed read-only mount
`/opt/oracle-data`. The runtime SPK contains a real empty directory there and an
explicit signed symlink for each externalized file. For example:

```text
/opt/oracle/root/relstore/relations_v2.sqlite3
  -> /opt/oracle-data/root/relstore/relations_v2.sqlite3
```

Directories containing both code and data remain in the runtime. The adapter
continues to use `/opt/oracle` as its source and `/opt/oracle/root` as its complete
root view. Its startup check resolves every declared bulk store and checks its
presence and size. No change to Oracle's database lookup code is required.
For shared-data packages, both signed launch commands set
`NLTK_DATA=/opt/oracle-data/root/nltk_data`, allowing WordNet's resolved physical
path without disabling NLTK's path checks.
`/var/oracle-workspace` remains private persistent state for each grain.

## Build inputs and signing

`deploy/oracle/rootfs/` supplies the Linux runtime closure recipe and retained
input locks. Rootfs construction uses pinned distribution inputs and hash-locked
Python wheels in a fresh directory, followed by a Linux import check. The
stager verifies the resulting rootfs inventory. It never installs into the
operator's interpreter or modifies an existing rootfs.

The operator tool under `deploy/oracle/pack/` uses the existing generated Sandstorm
archive schema from `native/spk-package-stream` to create a genuine signed SPK.
It signs SHA-512 of the serialized archive with Ed25519, encodes the standard
signature message, and compresses both messages using liblzma. The format is
unchanged. The pinned legacy Bread writer encoded empty byte arrays as void
lists; independent verification caught that defect in an unpublished v2 package.
The generated encoder preserves empty regular and executable files correctly.
The packer refuses packages exceeding Mini's standard 256 MiB compressed or
768 MiB decoded bounds. It does not select Mini's operator import profile.

Build this small physical tool in an independent source snapshot containing both
`deploy/oracle/pack/` and `native/spk-package-stream/`, with its committed Cargo lock:

```sh
cargo build --offline --locked --manifest-path deploy/oracle/pack/Cargo.toml
cargo test --offline --locked --manifest-path deploy/oracle/pack/Cargo.toml
```

An operator may create a candidate signing identity using `minidregg-oracle-pack
keygen PRIVATE_KEY`. It creates a new 0600 seed file and prints only the public
key and application ID. Keep the key outside Git, package inputs, publication
directories and evidence bundles. It is a local candidate author identity, not
the upstream Oracle publisher's identity.

The preparation steps use explicit operator inputs:

```sh
python3 -B deploy/oracle/stage.py data-inventory \
  --appliance "$APPLIANCE" --appliance-sha256 "$APPLIANCE_RECEIPT_SHA256" \
  --selection deploy/oracle/data-selection-v5.json --out "$NEW_DATA_INVENTORY"

python3 -B deploy/oracle/stage.py stage \
  --appliance "$APPLIANCE" --appliance-sha256 "$APPLIANCE_RECEIPT_SHA256" \
  --rootfs "$ROOTFS" --rootfs-manifest "$ROOTFS_LOCK" --rootfs-sha256 "$ROOTFS_LOCK_SHA256" \
  --bridge "$LINUX_BRIDGE" --bridge-sha256 "$LINUX_BRIDGE_SHA256" \
  --data-inventory "$NEW_DATA_INVENTORY" --data-sha256 "$DATA_INVENTORY_SHA256" \
  --app-id "$SIGNING_APP_ID" --version "$PACKAGE_VERSION" --target "$NEW_STAGE"

"$PACKER" pack "$NEW_STAGE" "$REVIEWED_STAGE_SHA256" "$PRIVATE_KEY" "$NEW_RUNTIME_SPK"
```

Inventory generation derives expected data hashes from the pinned appliance
receipt. It does not claim to have published or rehashed the 15 GB dataset. The
shared-data publisher is responsible for verifying those bytes. Staging hashes
all runtime files, checks the rootfs, and creates only the small metadata,
launcher, bridge and symlink overlay. Bulk data is neither copied nor included
in its file list as regular SPK members.

`STAGE.json` records exact expected package entries and explicit physical source
mappings. The packer hashes the same receipt bytes it parses, verifies the key
matches its app ID, checks every selected file before signing, and atomically
publishes without replacing an existing output. External source directories
remain mutable: staging alone is point-in-time evidence, not a frozen snapshot.

Run the independent `stage.py verify-package` check from
`deploy/oracle/README.md` against the separately pinned stage and inspector
hashes. It verifies the actual signed package's identity and complete member
inventory, including data declaration and symlink targets. Its receipt includes
the shared-data inventory digest and exact raw package SHA-256. Mini must import
that exact package hash; a pathname alone is not its identity.

The v3, v4 and v5 post-pack checks passed with `standard-v1`. Actual installation also needs
time to materialize the members: the first v3 Mini attempt exceeded the standard
120-second intake deadline after preparing INSTALL. Use the operator-owned
broker configuration key `importProfile` with value `operator-appliance-v1`
for this runtime, giving intake 1,800 seconds. The acceptance harness sets this
through `ORACLE_IMPORT_PROFILE` and retains the selected profile in its run
evidence. This physical budget does not change the signed artifact, its
post-pack receipt, or Mini's admission checks. See the
[operator import and recovery instructions](../deploy/oracle/README.md#operator-import-and-recovery).

## Acceptance scope

The signed runtime, published dataset and post-pack receipt are inputs to the
existing Mini create/install/start/share/API-session journey, described by the
acceptance lane under `deploy/oracle/acceptance/`. Publishing data or signing an
SPK does not create a grant. Callers use the live `mini_application_api` catalog
with relative path `query`, the signed prefix `/`, and the existing `query`
permission. They cannot select an HTTP host, workspace or data mount.

At the initial timeout checkpoint, INSTALL was prepared but incomplete and no
START had occurred. The acceptance lane retained that attempt's evidence and
resumed the exact prepared record under the operator profile, with unchanged
package and inventory identities. Later v3 attempts reached START and enrollment,
then exposed the host's refusal to serialize the bridge's status header. The
host repair and subsequent bridges pass composed transport fixtures; a complete
v5 Mini receiving journey remains separate evidence.

The packaging tests exercise explicit public-data selection, preserved lookup
paths, signed symlink and attachment bytes, source-mutation refusal, genuine SPK
signing, and independent final-inventory verification. They make no claim about
specialist answer accuracy or a public deployment. Those require their own
panel and composed runtime evidence.
