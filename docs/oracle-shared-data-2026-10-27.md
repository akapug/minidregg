# Oracle runtime and shared public data

Ember authorized continuing the remaining Oracle failures and taking the runtime
plus shared-data appliance through the real Mini grain path. This batch uses a
small signed runtime SPK and separately published large files. It does not extend
SPK, chunk SQLite files, or copy the dataset into each grain's mutable volume.

## Actual result

The v4 appliance answered through Mini's admitted API in two independent grains.
The final run completed 13 of 16 planned POST requests: eleven semantic checks,
the second grain's independent answer using the same IDs, and an exact replay of
the first grain's original answer. Mars conversion, date precision, supported
date ordering, and refusal of uncertain ordering all passed. These are actual
usage checks, not new specialist-panel scores or proofs of the English answers.

Linux mount observations show both grains reading the same physical 26-file,
15,046,949,326-byte dataset read-only, with separate writable volumes. Both
installs, STARTs and API enrollments completed. The 91,944,584-byte signed runtime
is recorded in [the v4 receipt](../deploy/oracle/runtime-v4-receipt.json).

Full acceptance did not pass. After the first clean STOP and the correct
missing-data refusal, the wrong-inventory fixture used 0755 directories instead
of required 0555 directories. Mini correctly refused custody before the intended
inventory comparison; the harness's exact-cause assertion failed. The fixture is
now corrected. A narrow audit using the retained native reader confirmed that
0755 produces the custody error and 0555 reaches the intended digest mismatch.
The corrected fixture has not been rerun through resident admission.

The original publication was restored, all owned units stopped, and the failed
run retained with execution exit 1 and cleanup exit 0. There is no passing
`report.json`. Restart reply replay and the final two source-authorized stops
remain untested. The retained Store is `ab7ea949ee00356f`, under
`hbox:/othersys/oracle-acceptance-20261027/run-v4-r2`.

Recovery review found a separate native limitation. Grain B's durable record
remains Running after physical cleanup, while systemd has cleared its invocation
identity. Source inspection predicts that the pinned STOP path would reject
invocation drift before its fence. No B reconciliation or restart was attempted.
Repair and qualify this exact already-inactive recovery case, including controls
against replacement units, before continuing with established native pin adoption.
Do not replace pinned binaries in place or erase the retained lifecycle.

Control-plane performance also needs work: the first STOP took 1,049.752 seconds,
dominated by two full-history inspections. Preserve admission semantics while
improving this cost; it is separate from Oracle's calculation runtime.

The [machine-readable evidence](evidence/oracle-shared-data-2026-10-27.json)
records exact replies, binary hashes, mounts, timings, previous attempts and the
remaining work. The [acceptance instructions](oracle-shared-data-acceptance.md)
describe the full target. This was a private receiving test, not a public service
deployment or qualification of the separate agent lifetime-grant tool.

## One contract

The signed archive member `minidregg-data.json` is at most 4096 bytes and contains
exactly `schema: "minidregg-public-data-v1"` and `inventory_sha256`, a lowercase
64-digit SHA-256 of the exact inventory bytes. Unknown and duplicate fields are
refused. No caller path, URL, mount target, or resource profile is accepted.

The inventory has schema `minidregg-public-data-inventory-v1`, visibility
`public`, and a sorted `files` list with `path`, `size`, and `sha256`. Paths are
unique normalized relative paths. Publication streams regular file bytes into
operator custody and checks their lengths and hashes before atomic publication.
The physical limits are 4096 files, a 1 MiB inventory, 16 path components, and
64 GiB total data; they are operator implementation bounds, not SPK limits.

The catalog is `SPK_ROOT/public-data/sha256-DIGEST/`, alongside `packages/`.
Each revision has `inventory.json`, `receipt.json`, and `data/`. The mount is
always `/opt/oracle-data`, read-only through pinned fd7. Each grain retains its
separate writable `/var`. There is no automatic garbage collection or overwrite
of published revisions in this implementation.

## Authority and physical checks

Existing Mini package and launch identities already bind the raw signed SPK,
including the declaration. The declaration must come from the same verified
archive parse, and every START/restart must resolve that exact data revision.
This preserves the current Lean admission path; it adds no alternate launcher
or Rust authorization scheme. Lean does not interpret or prove dataset custody.

Only public application data deliberately published by the operator is supported.
Knowing a digest does not grant access to private datasets. Private attachments
would require an actual access-control contract before being exposed.

Publication verifies file contents. Startup checks the entire tree against a
protected receipt of inode, size, timestamps, ownership and mode, avoiding a
15 GB content rehash on every start. A separate audit streams the hashes again.
This relies on trusted operator/filesystem custody, as existing SPK images do;
mode bits and receipts do not protect against a malicious privileged operator.

## Ownership and acceptance

- `mini_large_import`: publication, custody module and operator CLI.
- `mini_oracle_bridge`: signed-member extraction and the admitted launch/mount path.
- `mini_oracle_package`: split staging, genuine signing and package verification.
- `appliance_provision`: isolated Linux rootfs, locked dependencies and import check.
- `mini_oracle_acceptance`: real Mini install/create/share/start/API/restart journey.
- `shared_data_review`: independent production-code attack tests and boundary review.
- Root: integration, combined builds, resource coordination and Git.

The acceptance target is a genuinely signed runtime SPK, a published real Oracle
dataset, and two independently admitted grains reading the same immutable data
while maintaining distinct conversation state. Missing or wrong revisions must
stop startup. The test must use Mini's current authority path; direct fd3 success
alone is not admission evidence. Actual results are recorded as they arrive.

The Oracle repair lanes separately address Mars-year conversion in Python and
the extracted Space kernel, and date precision with source-bound metadata.
