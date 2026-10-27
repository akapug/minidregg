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

`scripts/oracle-stop-inspection-probe.py` compares a cold inspection with two
served reads of the exact same inputs, requires identical response bytes, and
checks malformed input, a changed claim and optional public-socket denial. It
records times and source/config hashes. Run it against an isolated qualification
Store with the exact new Host pinned at its private endpoint. It does not submit
a lifecycle operation or mutate a retained Store. To check refresh, make one
separately authorized disposable append and repeat the comparison; retain the
Host trace and both reports. Never replace a retained Store's pinned executable
to perform this comparison.

Source registry and diff checks pass. Linux build, receiving comparisons and
measured speedup are pending in the combined qualification lane; removing the
two call sites alone is not a measured latency result.
