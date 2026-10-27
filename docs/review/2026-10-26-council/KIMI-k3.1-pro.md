## A. Coherence

The plan is finite on paper but not yet internally executable.

- **The phases overlap despite being declared serial.** Phase 1 is days 2–9 and Phase 2 days 7–12, yet Phase 2 builds from the post-Phase-1 tip (`docs/DEMO-PREFIX-2026-10-26.md:69,86,106-110`). The plan also budgets six to eight parallel lanes but lists eleven (`:32-33,88-100`).
- **“Every surface on in week 1” contradicts the plan’s own two-week estimate** (`:32-33,155`). The underlying schedule is worse: the deploy gate is explicitly open-ended, with SPK, Lean rebuild and rooms risks (`docs/review/2026-10-26-deploy/WEB-SPK-PUBLIC.md:863-880`).
- **Stranger-safety semantics are scheduled after strangers arrive.** R11 requires replacing permit-all before enrolment, but its emitter is C4 in Phase 3, “with strangers on the box” (`docs/DEMO-PREFIX-2026-10-26.md:125,132,175`). Moreover, the actual onboarding script still writes `permit-all.json` and passes it as the account predicate; no Phase 1 lane owns changing it (`/Users/ember/dev/dregg-infra/edge/mini/mini-reenroll:43-46,86-90`).
- **R12 is backwards under ATLAS law 15.** “Lean, after the demo” leaves grain prices and settlement decisions in Rust while the economic surfaces are public (`docs/DEMO-PREFIX-2026-10-26.md:176`; `docs/review/2026-10-26-native-crates/SYNTHESIS.md:76`). That is precisely shipping a containment while deferring the real fix (`ATLAS.md:235-237`).
- **R4’s precondition is insufficient.** Pool Hermes does not become safe merely when L1(c) accepts non-200 responses. The repair also requires uncertain-provider settlement, aligned 32/64-KiB headers and subprocess deadlines (`docs/review/2026-10-26-triage/RUST-TRIAGE.md:240`). The source confirms the current non-200 throw (`Host/ProviderUsage.lean:264-281`); settlement remains later in C7.
- **R15 asserts an Oracle shipment the tree currently cannot produce.** There is no signed package, Linux runtime or complete appliance; six SQLite members exceed SPK’s per-member limit, requiring a format/materializer or immutable-store contract (`deploy/oracle/README.md:3-14,115-121`). No lane or acceptance row addresses that blocker.
- **The performance criterion is misstated.** The plan specifies p99 ≤5 s, but the actual growth gate rejects on cumulative **max** >5 s at 1,000 records (`native/resource-client/journey.sh:848-866`). A p99-passing candidate can therefore still fail deployment.
- **The deletion arithmetic undercounts Phase 1.** The advertised ~24,400 Rust lines are the “delete now” subtotal; the same report adds ~2,900 after rescue/repair, which Phase 1 also schedules (`docs/DEMO-PREFIX-2026-10-26.md:102-104`; `docs/review/2026-10-26-triage/RUST-TRIAGE.md:311-317`).
- **Two present-state items are already stale.** R2’s side-branch default conflicts with `4d866e4` already being settled on infra main without history rewriting (`/Users/ember/dev/dregg-infra/MERGE-2026-10-26.md:21-28,94-99`). Phase 0.5’s manifest repair now exists and has a 12/12 self-test; the remaining task is rerunning the composed gate (`:105-110`; `/Users/ember/dev/dregg-infra/edge/mini/lib.sh:270-300`).

## B. The fifteen rulings R1–R15

| Ruling | Owner’s call? | Default coherence and my ruling |
|---|---|---|
| **R1** | Product decision, already answered by the current brief | **Keep minidregg; nano remains the study object.** Coherent with the repair-in-place lesson (`docs/review/2026-10-26-history/HISTORY.md:546-556`). Do not re-ask. |
| **R2** | No; repository hygiene | **Keep `4d866e4` on main as an inert candidate.** The side-branch default is stale and would invite unnecessary history surgery. |
| **R3** | No; release operation | **Yes, after fresh fetches, fast-forward checks and the recorded local tests.** Coherent for the mirrors; do not treat silence as authorization to apply infrastructure changes. |
| **R4** | No, apart from ember’s spending limits | **Pool only after the complete provider-recovery repair and real `HERMES-LIVE` pass.** The stated L1(c)-only default is incoherent; BYOK must not substitute for the promised public pool surface. |
| **R5** | No | **Move unused private-backend research, but not wholesale by line count.** First resolve the named WAL/custody rescues (`docs/review/2026-10-26-native-crates/SYNTHESIS.md:340-348`). Phase 3 timing is reasonable. |
| **R6** | No | **Yes.** The measured 109,639-line upward-closed set is a sound move, provided `check-prover-glue`, generated outputs and import-boundary checks move or remain deliberately (`docs/review/2026-10-26-triage/LEAN-TRIAGE.md:413-439`). |
| **R7** | No | **Repair v3 and run it; delete v1 now and v2 only after v3 demonstrably supersedes it.** “Park never-run v3” is not a live path for Hermes/Oracle composition. |
| **R8** | No; required by the no-babysitting bar | **Keep v4 and add its failed-START recovery repair to L3.** Otherwise a failed first CREATE still demands operator/manual recovery (`docs/review/2026-10-26-triage/RUST-TRIAGE.md:252,291-293`). |
| **R9** | No for this demo | **Delete stacks 1 and 3; retain stack 2 only as disabled research outside the public candidate.** Keeping one twin is coherent; exposing an unrepaired research listener would not be. |
| **R10** | No | **Delete the bend pair now; retire `runtime.c` only after the proven-equal Lean machine is wired and differentially tested.** The default needs that wire-first sequencing (`ATLAS.md:207-209,228-231`). |
| **R11** | No | **Yes, before the door opens.** Move the minimal Lean-emitted account/room/factory defaults into Phase 1 and wire both Mini and `mini-reenroll`; the current phase ordering is incoherent. |
| **R12** | No | **Ship a minimal Lean-emitted operator tariff, ceiling and refusal/charge semantics before economic exposure; defer the full grain economy.** “Lean after the demo” violates the architecture carve. |
| **R13** | No | **Yes.** Explicit membership/exclusions plus a gate is exactly “gate the gates”; previously silent tests must be run selectively and reported (`ATLAS.md:213-216`). |
| **R14** | No | **Yes, rewritten whole as each lane lands, then once against the exact shipped candidate.** A present-state table is engineering hygiene, not an owner ruling. |
| **R15** | Already decided by ember | **Ship Oracle, but only through a new explicit large-data/package lane and a real admission journey.** The requirement is coherent; the current plan and schedule are not. |

**Shortest list for ember: one question.**

1. What exact money limits should be configured: **OpenRouter hard spend cap, sponsor total cap, per-stranger funding cap, and Solana enrolment address?** The credentials and ember’s one real mainnet payment are owner actions already in Phase 0/2, not additional rulings.

## C. Ordering and long poles

The rescue themes are right; the dependency graph is not.

- **Start the Lean critical path earlier.** The single rebuild “at the end” prevents L2/L3/L4 from testing against the new outcome and provider semantics until all parallel work is supposedly done. Land the interface-changing Lean statements first, rebuild immediately, then integrate; measure a cold or deliberately invalidated Host build now. The 35-minute candidate used warm Lean replay and supplies no cold-build estimate (`docs/review/2026-10-26-deploy/HBOX-CANDIDATE-a0db11f8.md:20-33`).
- **Create an infra/deploy lane in Phase 0–1, not during box bring-up.** It must own the composed-gate rerun, certifier/clock-v2 rebasing onto split tenancy, M7 reference construction, and Debian 13 SPK probes. Certifier rebasing is design work with six conflicts, not a serial install step (`/Users/ember/dev/dregg-infra/MERGE-2026-10-26.md:37-65`).
- **Fix the current required-row causes directly.** JPAY6 presently fails on an undeclared 70-byte consent-anchor socket path, not on the Lean allowlist (`docs/review/2026-10-26-deploy/HBOX-CANDIDATE-a0db11f8.md:84-94`; `native/resource-client/journey.d/lib/shortdir.sh:31-49`). M7 has no reference, and no lane supplies one (`HBOX-CANDIDATE-a0db11f8.md:85-89`).
- **Move the week-scale measurement before strangers.** One-minute ticks imply about 10,000 records/week; EtherCalc requests also write Store records. A 1,000-record gate alone does not support the one-week unattended claim (`docs/review/2026-10-26-deploy/HCLOUD-GAP.md:253-255`; `WEB-SPK-PUBLIC.md:890-897`). Run quiet 1,000- and 10,000-record measurements and unify max versus p99 before optimization.
- **Resolve file ownership:** L2 and L8 both touch `fleet_sign`; L4 and L6 both depend on `credentials.rs`; Oracle and L3 share SPK packaging/broker code. These need single owners or explicit sequencing.
- **Cut from the demo-critical week:** the 33 collision-theorem rewrites as a bundled L1 obligation, traffic-privacy research, non-demo custody migrations and broad strata/research consolidation. Do **not** cut any promised surface. Add the Oracle lane, clock-law repair, SQ repair and genuine external-service acceptance instead.

**“Every surface in ~2 weeks” is not credible as a commitment.** The candidate has unmet required rows, failed growth, an unexercised composed scenario and unexercised SPK; no real Discord, Hermes or SPK external run is recorded (`HBOX-CANDIDATE-a0db11f8.md:57-97,257-294`; `HCLOUD-GAP.md:291-297,315-318`). Oracle adds an unbounded format change. The SSH core is close; the complete demo’s date should be evidence-gated after Phase 0 spikes rather than promised now.

## D. What the plan gets wrong or misses

1. **The clock-law bypass is absent from L1/L5.** Lean’s own registry says PayObservation and PayEnrol advance the clock “WITHOUT judging that law” (`Compiler/CanonicalCellRegistry.lean:108-112`). This is a live semantic bypass on a public PAY path, not later cleanup.
2. **Several ranked pre-stranger repairs disappeared.** SQ bound violations can livelock appends and reads can fail on full/read-only disks (`docs/review/2026-10-26-triage/RUST-TRIAGE.md:248`); mini-keys retains global-slot, allocation and unauditable-operation holes (`:242`); Discord’s retry can double-execute and its split-mode unit conflicts with `NoNewPrivileges` (`:243`). The corresponding plan lanes cover only subsets.
3. **The door still lacks an explicit safe-custody contract.** Current `mini-reenroll` copies the member key into sponsor custody before enrolment (`/Users/ember/dev/dregg-infra/edge/mini/mini-reenroll:56-64`). The repair report requires the existing `possess` flow and deletion of retained rotation/sponsor copies (`RUST-TRIAGE.md:235`); the plan’s generic “custody retention” does not specify either.
4. **The deploy gate does not demonstrate “every surface on.”** Existing composed phases omit Oracle, real Discord linking and real fn transport. One EtherCalc browser run does not test two-client co-editing or restart/recovery (`docs/DEMO-PREFIX-2026-10-26.md:108-120`). M7 and Oracle currently have no route to green at all.
5. **Key environment assumptions remain unverified:** Debian 13 bwrap/user-namespace behavior, Caddy cookie routing and static-snapshot cost (`docs/review/2026-10-26-deploy/WEB-SPK-PUBLIC.md:945-959`). I did not rerun builds, contact live boxes or verify external services; those remain evidence gaps, not passing prerequisites.

## E. The three changes you would make first

1. **Replace Phase 0 with an evidence spike:** rerun the composed gate using the completed manifest fix, repair JPAY6’s socket declaration, supply M7, exercise m6grain, measure cold Lean and quiet 1,000/10,000-record growth, and spike Debian 13 SPK plus Oracle’s large-member design. Publish the date only after these results.
2. **Rebuild Phase 1 around pre-public invariants:** early Lean interfaces; one custody path; Lean-emitted defaults and minimal tariff; clock-law repair; split tenancy plus `possess`; certifier compatibility; SQ, mini-keys and Discord safety. Move proof-only and research consolidation off the critical path without dropping surfaces.
3. **Add Oracle and an all-surface acceptance lane:** one owner for the SPK/Oracle shared files, a signed package and immutable-data contract, two-browser EtherCalc, real Discord link, real Hermes pool/homelab calls, one mainnet enrolment, actual fn exchange, restart/certifier/backup drills. No public announcement until that candidate—not an earlier one—passes the complete gate.
