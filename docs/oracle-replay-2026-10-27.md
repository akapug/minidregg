# STOP inspection without repeated history replay

The Oracle receiving run's first STOP took 1,049.752 seconds. Its two
`inspect-stop-claim` subprocesses each loaded and semantically replayed the
whole Store. The recorded inspections took roughly 419 and 454 seconds; a
sample of the first used 350 CPU seconds over 352 elapsed seconds. This was
active verification work, not an Oracle process waiting for a socket.

STOP's fresh claim is already admitted by the resident Host's operation 26.
That receiver keeps the exact verified successor in its session before serving
the next request. Launching another Host threw away this checked history. The
same repeated work happened when inspecting the physical stop report and when
recovering a retained fenced stop.

## Change and consumer

Operator-only operation 155 takes the exact retained STOP plan and committed
claim. Its input uses Mini's existing pair envelope: a four-byte little-endian
plan length, the plan bytes, then the committed claim bytes. Both inputs must
be nonempty and the existing Host frame bound applies. Their existing Lean
codecs and `ApplicationLifecycleStopClaimInspection.inspectVerified` remain
the only interpretation of their meaning.

The served handler calls `sessionWalked` before that same inspector. With no
new records it reuses the process-local verified chronology. With new records,
the session authenticates the physical suffix and semantically re-admits it.
The response is the inspector's unchanged JSON, bounded to the native STOP
consumer's existing 2 MiB limit.

All three native STOP call sites now use one shared helper in
`lifecycle_v3_stop_claim_native.rs`. `PrivateOperator.invoke` binds the complete
Host configuration and pinned Host image to the protected operator socket.
The helper checks the operation, framing, output size and inspection type,
then retains the exact JSON at the same artifact path as before. Existing
`StopTarget` comparisons still bind the plan, fresh claim, source receipts,
running incarnation, journal and volume before any physical fence. This
read-only operation mints no launch or stop permit and does not retry a lost
reply. It is unavailable on the public socket.

The cold CLI stays available for independent audit and comparison. A newly
started resident still computes its first semantic walk; this change removes
repeated cold walks during an already-running session, not the cold-open cost.

## Why retained history remains valid

No proof or authority verdict is deserialized from an external cache. The
resident holds `NativeHostReplay.Verified config target`, minted by the
existing verifier and indexed by the same configuration that serves the
inspection. The exact op26 successor is retained through
`sessionSetWalked` / `Session.rememberReadbackVia`; a stale predecessor cannot
replace a newer session (`rememberReadback_stale`, `rememberReadback_newer`).

Before every inspection `refreshWalked` calls `DurableReceiverIO.extendFrom`.
The existing suffix verifier checks the same genesis, rejects rollback and a
changed accepted-record prefix, and re-admits new records at their original
heights. `Session.retainWalked_image` identifies the retained opening with the
verified physical target. The configured signature verifier is snapshotted
for the resident's lifetime as before. A poisoned session still refuses and
must reopen. No current-authority answer is carried across an unchecked suffix.

These are existing statements and execution paths, not new theorem claims.
The optimization connects their existing consumer to STOP inspection. There
are no new kernel axioms or specialist-panel scores.

## Checks and reproduction

The focused Rust checks exercise exact input preservation and bounds, rejection
of old lookup/refusal/foreign response opcodes, complete output preservation,
the actual private Unix-socket Host/config envelope, config drift, and public
socket denial. The operation registry checks that 155 has one receiver and is
operator-only. Qualification commands are:

```sh
python3 scripts/host-operations.py check
cargo test -p minidregg-spk-host --lib stop_inspection
cargo test -p minidregg-resource-client stop_inspection
```

`scripts/oracle-stop-inspection-probe.py` measures resident inspections before
starting the bounded cold comparison. It requires identical response bytes and
checks malformed input, a changed claim and required public-socket denial,
then requires the original valid inspection to succeed again. Public denial
uses a valid configuration and Host-image envelope, so a malformed envelope
cannot substitute for the routing check. Malformed pair lengths and public
routing must return the exact transport refusal, `0xfe` followed by
`operation unavailable on selected socket`. Altered and canonical mismatched
claims must reach the source and return `0xff`. Busy, wrong-peer and mismatched
configuration refusals cannot satisfy these checks. It records times and source/config
hashes after each measurement. If the cold comparison reaches its deadline,
the report remains failed while preserving completed resident checks and their
times. Run it against an isolated qualification
Store with the exact new Host pinned at its private endpoint. It does not submit
a lifecycle operation or mutate a retained Store. To check refresh, inspect one
completed STOP, then START and STOP the same disposable app again while keeping
the resident Host alive. Compare the new plan and claim: an old verified history
cannot contain that new claim. On this post-append pass, supply the previous
canonical claim with `--mismatched-committed`; the mixed plan/claim must refuse,
and the report must say `canonical_wrong_claim_checked: true`. This argument
is optional only so the initial warm-up can run before a second claim exists.
Retain both reports and the accepted append evidence. Never replace a retained
Store's pinned executable to perform this comparison.

Once a separate same-Host cold comparison has qualified, `--resident-only`
performs all resident and refusal controls without launching the cold CLI. Its
report says `mode: resident-only` and `cold_comparison: not-performed`; a passing
resident report makes no cold-equivalence claim. The fresh appliance journey
uses this mode at both new STOP boundaries, retaining its distinct configuration
and Store scope alongside the separate benchmark.

Source registry and diff checks pass. On the isolated Linux snapshot, the three
STOP inspection Rust tests and one resource-client operator/public routing test
pass. The final combined `Host.Main` Lean compile passed in the isolated bounded
driver (101.8 seconds). On an isolated copied Store, cold inspection took 425.061
seconds, the first resident inspection took 421.513 seconds, and its warm repeat
took 0.414 seconds. All returned the same 89,310 JSON bytes. This measures removal
of repeated history walks; it does not measure cold-open acceleration or total
STOP duration.

The first probe retained a failed receipt because it incorrectly expected a
source refusal for malformed pair framing. A continuation on the same untouched
resident checked the precise transport refusal, canonical wrong claim, public
denial and valid output after all refusals. It compared those bytes to the saved
cold result, checked identical Host/config/input hashes and unchanged source and
copied Store/anchor hashes, and performed no second cold walk. The continuation
receipt SHA-256 is
`8b8551dececa57f1797939be7d94d7b67169e55fc8d004a71632fb87781c12ff`.
Fresh appliance STOP and append-refresh qualification remain separate work.
