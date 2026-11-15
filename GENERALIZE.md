# Generic Simplex safety beyond n = 3f + 1

Ledger row: task/12305 (simbi). Lane `lane/quorum-n-ge-3f1`. This lane changes Lean proofs only.
It changes no executable definition, no Rust, and no runtime behaviour.

## What changed

The abstract safety chain used to assume `roster.card = 3 * f + 1`, with every
quorum guard at `2f + 1`. It now takes the roster size and three thresholds as
explicit parameters:

- `q` is the VOTE/COMMIT quorum (`Config.quorum = n - f`).
- `c` is the CANDIDATE count that sends a core READY.
- `r` is the READY count that clears a view, by preparing a block or disabling the view.

The relay guards (`f + 1` votes before a CANDIDATE, `f + 1` READYs before a relay READY)
are unchanged.

- `Kernel/GenericSimplexQuorum.lean`
  - `honest_intersection_of_overlap`: an `a`-set and a `b`-set drawn from an
    `n`-roster with `a + b ≥ n + f + 1` share an honest member. This holds for any `n`.
  - `Thresholds n f q c r` (Prop structure) has one field per safety use:
    `n + f + 1 ≤ q + q`, `n + f + 1 ≤ q + c`, and `f + 1 ≤ q, c, r`.
  - Three instances:
    - `thresholds_standard (3f+1 ≤ n)`: the kernel's own guards, `q = n - f` and `c = r = 2f + 1`.
    - `thresholds_legacy (n = 3f+1)`: every threshold is `2f + 1`.
    - `thresholds_small_quorum (3f+1 ≤ n)`: the stretch profile below.
  - `two_f_plus_one_quorum_unsafe_above_legacy` is a concrete counterexample. At `n = 5, f = 1`,
    two `2f+1` sets can meet only in a faulty member. So "keep `2f+1` and drop the
    size premise" was never an option: the VOTE/COMMIT quorum has to grow with `n`.
- `Kernel/GenericSimplexVAInvariant.lean`
  - `LocalFaithfulAt tr roster faulty f q c r` is the old `LocalFaithful` with the
    thresholds as parameters.
  - `LocalFaithful` is now an `abbrev` for the legacy instance `(2f+1, 2f+1, 2f+1)`. Every
    existing constructor and projection site compiles unchanged.
  - Every safety lemma has an `_at` form taking `Thresholds roster.card f q c r`, or only
    the `f + 1 ≤ ·` bounds it actually uses.
- `Kernel/GeneralSimplexReachability.lean`: `known_eq_committed_at`, `committed_not_disabled_at`,
  `known_parent_at`, `committed_ancestor_of_later_at` and `committed_prefix_consistency_at`.
  - `committed_prefix_consistency_admitted` is the headline theorem. It proves committed-prefix
    safety from `3 * f + 1 ≤ roster.card` with the kernel's `n - f` / `2f + 1` guards.
  - `known_zero` is generalized in place.
- `Kernel/GenericSimplexCertificateSafety.lean`
  - `AttributedCommitSendsAt tr roster faulty q view block` is a certificate of `q` signers.
    The old `AttributedCommitSends` is an `abbrev` for `q = 2f + 1`.
  - `EvidenceValueAt` is generalized the same way.
  - Every certificate theorem has an `_at` form, up to `attributed_commit_sends_prefix_consistent_at`
    and `certified_next_record_unique_at`.
- `Kernel/GenericSimplexReceiverSafety.lean`
  - `verifiedCommit_attributed_at` takes the native verifier's own `Config.quorum` signer
    count as the certificate quorum, with NO size premise.
  - `ordered_next_payload_unique_at` is the consumer join for any `Thresholds`.

Every old `n = 3f + 1` statement keeps its name and signature. Each is now a one-line
corollary built with `thresholds_legacy size`, or is left unchanged where it never used
`size`. The downstream modules (EngineSafety, ObservationSafety, ActualFaithful,
AgreementEvidenceRegime, SimplexQualification, Verify) are untouched.

Every new theorem carries `#assert_axioms`. That check fails on `sorryAx`, on a declared
axiom, and on `native_decide`'s compiler trust.

## Which hypotheses were weakened

- `size : roster.card = 3 * f + 1` became `th : Thresholds roster.card f q c r`.
  For the kernel's guards, that is exactly `3 * f + 1 ≤ roster.card` (`thresholds_standard`).
- The certificate quorum `2 * f + 1 ≤ signers.card` became `q ≤ signers.card`.
- The `2f + 1` VOTE/COMMIT support in `LocalFaithful` became `q`. The CANDIDATE→READY
  support became `c`. The READY→prepare/disable support became `r`.

## What is still n = 3f + 1 only (the honest boundary)

The **executable refinement layer** is still `n = 3f + 1` only. This layer proves that the
real `GenericSimplex.start/step` satisfies `LocalFaithful`. Its modules are
`GenericSimplexEmissionSupport`, `GenericSimplexActualFaithful`, `GenericSimplexEngineSafety`
(`actual_local_faithful`, `actual_committed_prefix_consistency`), `GenericSimplexObservationSafety`
and `GenericSimplexReceiverSafety.actual_*`. There are two reasons:

1. The Lean kernel's `Config.wellFormed` (Kernel/GenericSimplex.lean:33-34) admits only
   `parties == 3 * faults + 1`. Every other config fails at `start`/`step`, so a
   refinement theorem at `n ≠ 3f + 1` would be vacuously true. Widening `wellFormed` is
   a change to the oracle's runtime behaviour. That is out of this lane's layer. It
   also moves the oracle SHA that clockdag's `crates/mesh-simplex/PROVENANCE.txt` pins.
2. `EmissionSupport.EventSupported` (lines 42-55) records the READY-core, READY-prepare and
   disable supports at `c.quorum` and not at `2 * c.faults + 1`. Those are equal only when
   `n = 3f + 1`, which is why `argumentRules_invariant` needs `size`.

The next slice, mapped:
- In `EventSupported`, put those three thresholds at `2 * c.faults + 1`. Then
  `argumentRules_invariant` no longer needs `size`.
- Drop `size` from the `progressView`/`pass`/`pump`/`step` invariants (about 8 sites in
  EmissionSupport and about 28 `size` sites across Engine/Observation/ActualFaithful/GlobalEmission).
- Have `localFaithful_of_supported` produce `LocalFaithfulAt … (n - f) (2f+1) (2f+1)`.
- Widen `Config.wellFormed` to the Rust NF admission (`n ≥ 4`, `f = (n-1)/3`, keeping `n = 1`).
- Estimate: about 80-140 LoC of proof edits, plus the oracle-hash re-pin and a rerun of the
  `Verify/GenericSimplex*` harnesses. Widening `wellFormed` is the runtime decision this lane
  does not make.

Also not generalized: `LocalCommitOutputAttestations` and its two theorems. The file itself
marks them historical, superseded by the COMMIT-send certificate. `GenericSimplexReconfig`
(churn) is also not generalized.

## Stretch: the smaller quorum q = ⌈(n + f + 1) / 2⌉

`thresholds_small_quorum` proves that this profile satisfies `Thresholds`, so every `_at`
safety theorem applies to it:

- VOTE/COMMIT quorum `q = (n + f + 2) / 2`. At `n = 6, f = 1` that is 4, against 5 for `n - f`.
  At `n = 600, f = 199` it is 400, against 401.
- **The CANDIDATE→READY guard must rise** from `2f + 1` to `c = n + f + 1 - q = ⌊(n + f + 1) / 2⌋`.
  That is 4 instead of 3 at `n = 6`, and 400 instead of 399 at `n = 600`. Safety needs
  `q + c ≥ n + f + 1`: a committed block's `q` COMMIT senders must meet any `c` CANDIDATE
  senders in an honest member. Without the raise, the small quorum is unsafe.
- The READY→clear guard may stay at `2f + 1`. Safety needs only `r ≥ f + 1`, and `2f + 1`
  keeps Bracha READY totality.
- The `f + 1` relay guards stay unchanged.
- Liveness is NOT proved, here or anywhere for Generic Simplex in this repo. The informal
  threshold argument holds: honest parties alone reach every guard when `q, c, r ≤ n - f`,
  and `q ≥ 2f + 1` lets a vote quorum's honest voters (at least `q - f ≥ f + 1`) drive every
  honest party to CANDIDATE(x). Both hold for `n ≥ 3f + 1`. A real liveness proof is a
  separate obligation.

## Fabric evidence

All Lean builds ran on the Fabric. None ran on the laptop hub.

| job | node | tree | command | exit |
|---|---|---|---|---|
| `job_d1a7799fae6b6c63d2d9d99f` | droopy | origin/main `01f25eec2` (baseline) | `lake build Kernel.GenericSimplexReceiverSafety Kernel.GenericSimplexObservationSafety Kernel.AgreementEvidenceRegime SimplexQualification Verify.GenericSimplexAxioms` | 0 (3395 jobs) |
| `job_ec23fd445233085bc2d166cf` | lassie | lane `251218990b5a` (all Lean changes) | `set -o pipefail; lake build Kernel.GenericSimplexQuorum Kernel.GenericSimplexVAInvariant Kernel.GeneralSimplexReachability Kernel.GenericSimplexCertificateSafety Kernel.GenericSimplexReceiverSafety Kernel.GenericSimplexObservationSafety Kernel.GenericSimplexEngineSafety Kernel.AgreementEvidenceRegime SimplexQualification Verify.GenericSimplexAxioms` | 0 (3395 jobs) |
| `job_ca2ab9ddc1d80aacf30573f2` | lassie | `7bfcc0db` plus an uncommitted probe file | `lake build Kernel.GenericSimplexReceiverSafety Kernel.GenericSimplexEngineSafety && lake env lean .qprobe/QuorumProbe.lean` (`#check` and `#print axioms` of the headline theorems) | 0 |

The probe job printed `#print axioms` for `committed_prefix_consistency_admitted`,
`certified_next_record_unique_at` and `ordered_next_payload_unique_at`, and all three depend
only on `[propext, Classical.choice, Quot.sound]`. `thresholds_small_quorum` and
`two_f_plus_one_quorum_unsafe_above_legacy` depend only on `[propext, Quot.sound]`. The legacy
`committed_prefix_consistency` and `actual_committed_prefix_consistency` still state
`roster.card = 3 * f + 1` and `c.parties = 3 * c.faults + 1` respectively.

The second job's build passed every `#assert_axioms` line, the new ones and the old ones.
It also compiled every unchanged downstream user of the legacy names: EngineSafety,
ObservationSafety, ActualFaithful, AgreementEvidenceRegime, SimplexQualification and
Verify.GenericSimplexAxioms.

The added lines contain no `sorry`, `admit`, `axiom` or `native_decide`. This command
prints nothing and exits 1:

    git diff origin/main -U0 -- '*.lean' | grep -n "^+.*\b\(sorry\|admit\|axiom\|native_decide\)\b"
