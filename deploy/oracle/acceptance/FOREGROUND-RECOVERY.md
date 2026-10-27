# Retained session recovery

The v5 R3 Store has an uncertain session operation with an already confirmed
parent reservation. Preserve it. `--recover-foreground PLAN_JSON` resumes that
same native operation through the controller's private admin interface; it
does not send the session tool again or acknowledge an uncertain result.

Before execution, the integrator supplies a reviewed plan with protocol
`mini-oracle-foreground-recovery-plan-v1` and these fields:

- `run`, `store`, `request_id`, `operation_id`, `host_config_sha256`.
- `old_runtime_sha256` and `old_public_mini_sha256` from the stopped installer status.
- `predecessor_export`, `predecessor_status`, `runtime`, `public_mini`, `spk`,
  `inventory`, `benchmark`, and `qualification_manifest`, each with absolute
  `path` and `sha256`. The independent qualification manifest contains standard
  SHA-256 file rows for the exact reviewed runtime and public Mini binaries.

The harness takes the existing run lock, obtains a fresh fixed-installer export
and stopped status, and compares them to the reviewed predecessor. It checks
the exact retained request and reserve receipt, then archives the stopped
SQLite Store and anchor before any upgrade. It keeps the v5 package identity;
v6 qualification uses a separate fresh run and its own package receipts.

The fixed installer upgrades the stopped runtime and public listener with
archived old/new bytes. The listener upgrade preserves its UID, socket,
namespace and ACL pins. It can recover only those exact old/new publication
states; a different binary or registration refuses.

After service startup, `controller-recover-session STORE HELPER REQUEST_ID`
invokes only `recover foreground session REQUEST_ID` on `state/admin.sock`.
Native code decides whether the old reservation and current source state
permit recovery. The harness requires the matching retained definite result,
both native session records, and settled parent/tool holds before continuing
grant issuance and ordinary result acknowledgment. The original failed client
output stays untouched. Subsequent application discovery, calls and restart
use the ordinary journey.

A timeout, lost response or nonzero exit does not authorize another invocation.
Keep the started phase and inspect the native retained state. Harness tests
and installer publication tests do not establish that the native operation
or full hosted journey succeeded.
