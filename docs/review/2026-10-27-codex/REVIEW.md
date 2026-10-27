# Composition review at a75d89d6

Reviewed `a75d89d69b4569be2d7a9a981ae11e47b3c49bd5`: the platform cell,
activity effect Plans, and checkpoint v4 as they meet their real consumers.
This is a source review with one isolated parser/comparison reproduction,
not a built-candidate or deployed-system qualification. No production code
was changed. The oracle grant repair proceeds separately.

## P2: Store audit can report physical row checks it did not perform

`Compiler/DurableStoreAudit.lean:178–195` requests accumulator and index rows,
then checks `expected.zip read.nodes`. A short response silently shortens the
checks; an empty response performs none. Success at line 221 reports the
expected row counts, not the number actually compared. The loops also ignore
returned space/key identities and version bounds.

`Compiler/DurableReceiverCore.lean:336–363` accepts a well-framed 24-byte history
response with zero entries and zero nodes, and returns it without relating it
to the request. If the remaining log, MAC, checkpoint and replay checks pass,
omitting rows from these two transport responses skips their physical-node
coverage while retaining a successful audit report.

**Limit:** the actual Rust producer at
`native/hyperdocument-link-sqlite-store/src/lib.rs:1097–1109` returns one element
for every requested node, including `None` for a missing row. Removing an
ordinary SQLite row therefore still fails the value comparison. This finding
requires a faulty/substituted helper, a custom Transport, or malformed output
outside that normal producer. Honest physical transport is an existing stated
assumption; this is a consumer-contract weakness, not a demonstrated deployed
exploit or a refutation of cryptographic replay.

Require exact node count and position-wise space/key identity before comparing
values; bound returned versions by the requested height. Validate the response
head according to the caller: ordinary historical reads may return a current
head greater than the requested height. Preserve sparse entry semantics for
other callers. After coverage is checked, expected counts can truthfully serve
as compared counts.

**Check:** [audit-coverage-repro.lean](audit-coverage-repro.lean) extracts the
actual framing parser and byte helpers, then exercises the audit's zip/value
comparison primitive with already encoded values. Core Lean 4.30.0 exited 0:
omission checked 0/2 rows, a short prefix checked 1/2, and incorrect identity
with the correct value passed; a nonempty wrong value and trailing bytes
refused. This ran on the Mac before the later no-local-Lean instruction; no
further local checks were started. It does not execute the whole Store audit.
The production fragments are unchanged between the review pin and the witness
worktree. The receiving test still owed is a substituted history response in
the actual audit: both a missing row and the planted short response must refuse.

## Checkpoint/light receiver: a known invariant gap remains

The full writer refuses a failed World advance before append
(`Compiler/DurableReceiverIO.lean:188–192`). The light writer appends first,
then folds in its confirmation path and converts a fold error to `none`
(`Compiler/DurableServed.lean:1068–1088`); a due checkpoint can retain that
absence. Light open/refresh also propagates an optional World. Actual Host
renounce/revoke/delegate/install/invoke routes use this writer.

No native-admitted request that triggers this failure was established here.
The simple arbitrary wrong-charge example is not enough: concrete receivers
derive their storage charge, and `Kernel/DeployedCharge.lean:59–80` proves its
equality under representation and derivation premises. The broader coverage
gap was already noted in `2026-10-26-council/ASTRA-codex.md:80`. This is an owner
follow-up, not a new reproduced corruption finding: establish the held-World
invariant and pre-append preservation, or enforce the full advance check before
the physical write. A successful executor-only comparison is not that proof.

## What remained connected, and what is already owned

- **Platform:** registry and reference receiver are present, but Host operations
  240–243, genesis seeding, replay integration and cell-priced births remain L1's
  named work. The local receiver's replay is not evidence of Host reachability.
  No new independent defect was established beyond that disclosed incompleteness.
- **Effects:** transfer posts join the same Book/record/state batch; resumption
  uses the stored verdict, and chronological replay re-admits the original
  ingress rather than appending a second transfer. The two-octet verdict wire
  avoids the suspected settled/refused reserve-size mismatch. No new defect was
  established in those traces. The deputy already owns the purse/account alias
  correction (`purseApart`, `FundsAgree`) and remaining proof/codec/native checks.
- **Checkpoint:** the body MAC covers the system store and fold identity;
  genesis audit compares complete expected checkpoint encodings, including
  that system store. The standalone fast-forward lemmas are useful, but the
  deployed implementation's full `Spec` instance is still the hot-path owner's
  work. This review does not upgrade those lemmas to end-to-end assurance.

**Batch for the integrator:** route the audit-response coverage repair to the
durable transport/audit owner; keep the light-World obligation with hot-path;
run effects verdict/law-refusal/exact-replay/reopen checks on the eventual built
candidate. The review ran no Host closure, server, provider call or Store journey.
