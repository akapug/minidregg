# Oracle7 in Mini — October 26 integration

Oracle's corrected engine now answers through Mini's real Sandstorm RPC
connection. This is application transport evidence, not a deployed Mini service
or a new specialist-panel score. The current full appliance still cannot be
packed as one ordinary SPK: six database files exceed the format's individual
file limit.

## What is being connected

`native/oracle-appliance` exports the app's MainView on inherited fd 3 and
serves WebSession/ApiSession requests through the fixed loopback adapter. It
requires the signed `query` permission. It preserves complete reply bytes,
including evidence, and does not retry an uncertain delivery. Sandstorm's error
union cannot express every HTTP code; the exact adapter code is retained in
`x-sandstorm-app-http-status`, alongside the unchanged error body.

Mini continues to own application/session grants, current policy, dispatch
admission, exact retry and charging. The model-facing tool is the existing
`mini_application_api`. One appliance grain has one persistent conversation
workspace; sharing a grain shares that workspace. Distinct tenants need
distinct grains. The runtime and data are immutable inputs; conversation state
belongs in the grain's `/var`.

The application source is the October 26 candidate in the sibling veri7vn
repository, pinned by `deploy/oracle/candidate-2026-10-26.json`. Its base is
Oracle7 Slim revision `083e3a6c0e2cfc131e62bdc16cb4ec1346194635`, with recorded
correctness patches and a mixed kernel overlay. These identities are not a
claim that every returned answer was proved.

## Evidence and checks

- Six bridge tests exercise the actual `SupervisorConnection`, executable fd 3,
  full 2 MiB evidence, permissions, deadlines, bounds and error projection.
- `scripts/oracle-transport-smoke.py` passed 12 checks against the real engine:
  Whitman, ISA temperature, clarification for invalid altitude units, Austen,
  and a pronoun follow-up. Replies matched direct HTTP replay byte for byte;
  all five replies and a changed-request conflict survived adapter restart.
  All 4,735 runtime inventory entries stayed unchanged and owned processes
  stopped. This macOS run used the meteorology reader, not the Linux Earth binary.
- Seven Linux intake-helper tests cover namespace custody, selected unit
  budgets, exact host arguments, unknown profiles and the standard raw-size cap.
- On hbox, 37 focused Rust tests passed: parser 8, signed inventory inspector 2,
  bridge 6, materialization/wake 1, broker 9, install 7 and launch descriptor 4.
  The real Linux qualifier also passed both helper-resource tests on a genuinely
  signed 2 MiB fixture. That fixture fails under the previous 1 MiB file limit
  and succeeds under both selected profiles, retaining the signed `/` API path.
- Eight packaging/launcher tests passed. A signed fixture also passed the
  post-pack CLI; a re-signed changed payload was refused without a receipt.
  These fixtures do not constitute a packaged Oracle runtime.

That is 54 focused tests plus the 12 real-engine smoke checks. Linux compilation
and tests ran in an independent source snapshot, with two jobs, a 4 GiB memory
ceiling and 200% CPU ceiling. No Lean rebuild or whole-system journey was run.
The Linux bridge, importer and inspector binaries are retained as local build
artifacts; hashes and the check summary are in `evidence/oracle-2026-10-26.json`.

The local full engine receipt is
`o7vn/var/mini-bridge-smoke-20261026-r2/report.json`. It contains synthetic
questions only. The reusable smoke command and its scope are documented in
`oracle-appliance-bridge.md`.

## Importing without archive-sized memory buffers

`native/spk-package-stream` snapshots and hashes the compressed input, decodes
with an independent XZ dictionary bound, verifies the real signature and archive
hash, and indexes the archive without cloning all file contents. Extraction
reads bounded blocks from private scratch. Manifest and bridge metadata come
from that same verified snapshot. The pinned Bread manifest decoder is reused.

Standard intake retains the 256 MiB compressed / 768 MiB decoded caps. An
explicit operator profile permits 8 GiB / 20 GiB, without increasing ordinary
app memory or mutable-volume classes. Package metadata and broker requests
cannot select that profile. Protected host metadata records the selected
profile for later inspection; an archive member with the same name is ignored.

The larger profile is physical preparation only: Mini's unchanged
`ApplicationSpkPackageIdentity.Descriptor.valid` still limits admitted raw SPKs
to 256 MiB. Source qualification and materialization do not bypass that rule.
An admission change needs its own descriptor/policy decision and Lean/native
validation, preferably alongside the data-attachment design below.

Larger imports need persistent disk scratch, not a RAM-backed `/tmp`. Free-space
checks are conservative preflights, not reserved capacity or a filesystem quota.
The operator must budget the source, inbox, snapshots, extracted image and
retained signed package together. Interrupted extraction can leave unpublished
staging state; it must not be mistaken for an installed image or removed by an
unrelated session. The broker currently serializes administrative requests;
bulk import can delay other broker operations even with a matching call deadline.

## Large immutable data: the next architectural change

Use a small signed runtime SPK plus a separately pinned, shared immutable data
image. This is the recommended direction, not an implemented mount capability.
Copying 15 GB into each grain's mutable volume would waste storage, slow startup
and blur the separation between data and conversation state. Merely increasing
the archive budget cannot make SPK's 29-bit Data members hold multi-gigabyte
SQLite files.

The implementation needs to join these existing boundaries:

1. Extend the signed launch input with an exact data inventory/root and fixed
   in-grain attachment point. Mini's current `ApplicationSpkLaunchDescriptor`
   binds the package and commands but has no data-attachment field. Its canonical
   identity must change when an attached data image changes.
2. Admit access to that data through current Mini policy. Content hashes locate
   bytes; knowing a hash must not grant access to another tenant's private data.
   Operator ingestion policy can be larger than user-controlled upload policy.
3. Verify and publish the data once into operator custody. The Rust sandbox
   consumes an admitted attachment handle and a verified read-only directory,
   never a model-selected host path, URL or mount option. Startup must compare
   the exact attached root with the admitted launch input.
4. Share immutable bytes across grains while keeping `/var` separate. Account
   for physical storage, retained revisions and live mounts; a running grain
   must keep its exact data revision through a concurrent update or collection.

No new Lean descriptor, data grant, sandbox attachment or public route was
created by this batch. The remaining acceptance test is a real signed runtime,
admitted immutable dataset, create/start/share/API-session and an actual
`mini_application_api` query through Mini's current authority path. The existing
`prepare-lifetime-route.sh` carries fixture identities and cannot be reused
unchanged for Oracle.

The detailed review and subsequent dispositions are in
`oracle-integration-review-2026-10-26.md`. Unrelated Mini review and Lean work
from the concurrent session remain outside this change.

## Upstream writer follow-up

The pinned Bread revision `5819115352bdfa43c5cbd329727d4f8d8a1b5be9` has an
empty-file encoding defect in `sandstorm-package/src/capnp_wire.rs:535`:
`bytes_ptr_at` writes pointer word `1` for empty Data, selecting a void list
instead of a byte list. The generated Cap'n Proto reader rejects that encoding.
Fix the writer to retain the byte element tag and test its output with an
independent decoder before updating the dependency. Mini's generated-schema
fixture already verifies that correctly encoded empty files work; it does not
make the old writer's invalid output valid. No upstream writer fix landed here.
