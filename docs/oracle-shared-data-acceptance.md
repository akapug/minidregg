# Oracle shared-data acceptance

The current v7 agent/browser qualification is **incomplete**. Its fresh Store
installed both appliances and admitted an agent session, then refused lifetime
grant planning before submission. The dedicated grant repair and fresh-world
factory permission are pushed on `lane/oracle-lifetime-grant` and
`lane/oracle-grant-factory`. They await centralized integration and a coherent
Host/consent build; the [appliance overview](oracle-appliance.md) distinguishes
the source checks, completed 32-tenant runtime qualification and remaining
hosted journey.

The next positive run uses a fresh Store and matching current Host, consent,
native tools and helpers. It must exercise the agent tools, authority refusals,
same-grain tenant separation, actual browser interaction, restart replay and
cleanup. The existing harness supports these through its controller phases,
`ORACLE_POOLED_TENANT_PROBE=1` and `ORACLE_BROWSER_B=1` (with the required pinned
Caddy executable and browser port). Browser interaction is an additional check;
an HTTP helper response alone does not establish that the page works.

The retained v5 parent reservation is a separate unresolved recovery case:
its terminal-only repair attempt timed out during historical ticket lookup,
with no result or ACK. Do not resend it or copy that Store into the fresh
qualification. [Latest recovery evidence](evidence/oracle-hosted-recovery-2026-10-27.json)
records both stopped Stores.

## Earlier v5 and v4 attempts

The earlier v5/U3 attempt was **incomplete**. Both grains were installed and the
public dataset was published. The retained Store is `d4090a0c4c356d31` on
`dregg-build`; no v5 application START or query has occurred.

The final checked continuation repaired public-listener restart, admitted the
owner's worker policy, completed native bootstrap enrollment in 132.6 seconds,
and attached the controller. Session request
`839a6731941b62b1179b4de9c076f0df` then reached native foreground operation 13
and became uncertain: its historical grain-share issue lookup was refused by
the selected socket. The qualified source sends that recipient lookup to the
public socket while opcode 55 remains operator-only. That is a source-traced
explanation of the observed refusal, not a qualified recovery.

The attempt ended with execution 1 and cleanup 0. Services are stopped; both
volumes and journals remain. The controller retains a confirmed parent reserve
of 1 and the uncertain foreground operation, with no retained foreground result
or born session resource. Nothing was resent or acknowledged. Further work
required audited exact recovery before further operations in that Store.
The later recovery attempt is described above.
[Exact U3 evidence](evidence/oracle-u3-acceptance-2026-10-27.json)
records the receipts and separates earlier failures from these observed results.

The earlier v4 result is **partial acceptance, not a full pass**. The retained
`hbox:/othersys/oracle-acceptance-20261027/run-v4-r2` run installed and started
the signed v4 runtime in two real Mini grains, enrolled both API sessions, and
completed 13 of 16 planned POST requests through Mini’s admitted HTTP route.
Execution ended with code 1; owned cleanup ended with code 0. `report.json` was
not produced. The Store `ab7ea949ee00356f` and its journals are preserved.

Observed successes:

- Both grains used the same exact read-only public data mount at
  `/opt/oracle-data`, with separate writable `/var` devices (`7:27` and `7:39`).
- Both grains accepted the same request and conversation IDs with different
  questions: Whitman in the first grain and Austen in the second. Replaying the
  first request returned its original bytes exactly.
- The admitted answers preserved the supplied Mars periods, Shakespeare’s
  month-only birth date, Salinger’s real first-of-month date, and Austen’s exact
  sourced birth date in a pronoun follow-up. Valid date comparisons retained
  their source dates; uncertain Hildegard/Shakespeare ordering was withheld.
  The ISA temperature answer was −4.5 °C at 3,000 m; invalid altitude units
  produced clarification.
- The first grain completed a source-authorized STOP. With its dataset absent,
  the exact failed invocation named the signed inventory digest and ENOENT,
  before BEGIN; no new running or uncertain generation appeared.

The wrong-inventory fixture then failed its own assertion. Its publication
directory was `0755`, while a genuine immutable publication must be `0555`.
Native code refused that custody mismatch before reaching the intended inventory
hash mismatch. This was an observed refusal, but it is not counted as a passing
wrong-inventory check. The harness now creates the fixture’s publication and
data directories as `0555`. A separate bounded operator audit reproduced the
old custody refusal and reached the intended signed-inventory mismatch with the
corrected modes. That narrow check did not perform Mini admission or mutate the
original publication.

Failure cleanup stopped this run’s processes, restored the original dataset,
and retained both state volumes and native journals. Grain A has a completed
STOP and a later never-begun generation. Grain B has a completed START and a
native Running record, but its exact systemd unit is now inactive with no PID,
InvocationID, or cgroup. **Source review predicts a recovery obstruction:**
although the resident classifies it as stopped-exact-needs-source-stop, the
pinned STOP fence requires the old InvocationID before fencing a Running record.
No B reconciliation was attempted, so this is not a measured STOP refusal.

Next work is to qualify source-bound reconciliation of that exact inactive
incarnation, including replacement controls and the established native pin
adoption path. Then continue from the retained package/data/state identities:
repeat the corrected wrong-inventory case, reconcile B before restart, restart
A and compare its original answer/follow-up bytes, verify B independence, and
finish native stops and cleanup. No accepted operation or uncertain request
should be blindly resent, and journals must not be erased to manufacture a
fresh start.

STOP latency is a material limitation. The first stop took **1,049.752 seconds**
(17.5 minutes). Two `inspect-stop-claim` calls replayed the durable Store history;
one observed sample had 352 seconds elapsed and 350 seconds CPU. The second
inspection then completed before the final op38 receipt; no third full-history
inspection was observed. This stayed within the original 1,800-second phase
bound, but the final restart and stop checks have not run.

The exact request/reply hashes, phase timings, native pins, prior failed
attempts, and retained artifact hashes are in
[`oracle-shared-data-2026-10-27.json`](evidence/oracle-shared-data-2026-10-27.json).
The final run used SPK SHA-256
`bded240f916b93d51ad5e90ffc12d8a8cc9985e35306105eff69f926b3333ed0`
(91,944,584 bytes, version 4) and inventory
`32bb3cf1a6337ee2c7b6ec902bb5bfdff11ba1fd5f1fa3b730dc269431b27d0a`
(26 files, 15,046,949,326 bytes). No public deployment, new specialist-panel
score, or formal answer-proof claim is made.

## Harness and operator recipe

`scripts/oracle-shared-data-journey.sh` runs the signed Oracle runtime through
Mini's existing grain receiving path in a new private Linux Store. It creates
an application, installs the signed package, issues its current share ticket,
enrolls an API session, starts the sandbox, and sends queries through the grain's
HTTP route. That route asks Mini to author and admit each dispatch before the
app receives it. The harness does not connect directly to fd 3 and does not
claim to exercise the separate `mini_application_api` agent lifetime-grant tool.

The script is an acceptance harness. Its shell and Python code do not decide
Mini authority. The qualified Lean Host, native client, broker, package verifier,
and sandbox remain the receiving path. It deploys no public service and records
no new specialist-panel score.

Run on a Linux operator account with user systemd and linger, subordinate UID
and GID allocations, the existing bwrap confinement, and permission to run the
fixed `deploy/spk-host/install-user-world` setup helper. `sudo cat` is used only
to inspect the kernel's mount table for processes in the new Store's units.

```sh
scripts/oracle-shared-data-journey.sh \
  /absolute/qualified-base/bin \
  /absolute/current-native/bin \
  /absolute/protected/new-run \
  /absolute/oracle-runtime.spk \
  /absolute/public-data-source \
  /absolute/public-data-inventory.json
```

The base directory needs `minidregg-host`, `mini`,
`minidregg-link-sqlite-store`, `minidregg-credential-signature-verifier`, and
`minidregg-client-consent`. The current native directory needs `spk-host`,
`mini-spk-broker`, `mini-spk-volume-helper`, and `spk-data-publish`. Use absolute,
canonical paths with protected ancestors; the run directory must not exist.
The Oracle harness selects the existing `operator-appliance-v1` physical import
profile up front through the private broker’s `importProfile` field. It allows
1,800 seconds for materialization. The signed runtime still has to meet Mini’s
existing 256 MiB raw-SPK admission limit. `ORACLE_IMPORT_PROFILE=standard-v1`
explicitly selects the ordinary 120-second importer for a comparison run.

Run the harness within a bounded operator unit. The broker is limited to
512 MiB and one CPU; each of the two class-L grains has the existing 2 GiB
memory limit. Data publication has a one-hour deadline and every journey phase
has a thirty-minute deadline. The publisher copies the data once, so budget
space for that copy, the input package, its imported image, and two 2 GiB state
volumes before running it.

The runtime's signed `minidregg-data.json` fixes the exact public inventory:

```json
{"schema":"minidregg-public-data-v1","inventory_sha256":"<64 lowercase hex digits>"}
```

The operator publishes the dataset at
`SPK_ROOT/public-data/sha256-<inventory hash>`. The native receiver verifies that
exact revision and mounts it at `/opt/oracle-data`, read only. Conversation
state remains under each grain's separate `/var/oracle-workspace`.

The acceptance checks these behaviors:

- Both grains mount the same physical data revision read only and different
  physical `/var` volumes, as observed in Linux mount tables. Resident UID/GID
  maps are retained, and host root must be unmapped in the resident namespace.
- A finished, nonfailed import unit names the selected profile. Native install
  completion binds the exact SPK, and the imported image retains that profile.
- The same request and conversation IDs accept different questions in different
  grains; a later replay in the first grain retains its original answer.
- Whitman, Austen, the pronoun follow-up, and the ISA temperature questions cross
  the admitted API route. Invalid altitude units do not become a numeric answer.
- Supplied orbital periods remain in the Mars conversion (three Mars years using
  687 and 365.25 days gives about 5.64271047 Earth years). Shakespeare’s birth
  retains month precision and an unspecified day; Salinger retains his real
  first day of January 1919. Salinger/Carter and Shakespeare/Newton ordering
  retain their source dates; uncertain Hildegard/Shakespeare ordering produces
  a terminal refusal instead of continuing to an unverified answer.
- With the first grain stopped, withholding its dataset or substituting a wrong
  inventory at its exact catalog slot causes a prompt refusal. No running or
  uncertain lifecycle is accepted as a refusal success. The exact failed
  invocation must report custody refusal for the signed inventory digest, with
  the missing-directory or wrong-inventory cause appropriate to that case.
- Restoring the original directory preserves its file identities. Restart uses
  the same signed runtime and persistent state, and returns the exact original
  reply bytes. The second grain remains independent.

All mutation in the negative cases is confined to the publication created by
this run. The original directory is renamed aside and restored, never rewritten.
The harness does not retry an uncertain Mini operation or delete its journal.
It retains native lifecycle receipts, request/reply artifacts, mount observations,
source and binary hashes, stderr, and a machine-readable report. Cleanup stops
only this Store's processes and removes only this run's helper, registry, and
scratch namespace after success. A failed journey stops its processes and
unmounts its volumes, then retains its own namespace, registry, helper, and
state for diagnosis or recovery. It does not erase uncertain native journals.
An unsuccessful unmount also prevents namespace removal.

A passing `report.json` must be accompanied by `exit.json` with both execution
and cleanup exits zero. A harness file or successful syntax check is not a
passing Mini journey. The dated evidence file records the actual execution
status and is updated only from retained artifacts.

`--resume` supports only a prepared but incomplete INSTALL with no START. It
checks the retained package/inventory/binary hashes and original native archive,
then resumes native materialization/completion. It is not a recovery command for
the final retained Store. Replacing a pinned executable in place is not a native
upgrade procedure.


The checkpoint continuation accepts only its explicitly checked, unstarted
phase boundary. It holds an exclusive per-run lock through cleanup, archives
prior evidence before effects, and writes durable started/completed phase
records. A started source operation without a validated native outcome is
inspect-only; a wrapper's successful exit never establishes source admission.
The retained final checkpoint is uncertain and is not eligible for automatic
continuation.
