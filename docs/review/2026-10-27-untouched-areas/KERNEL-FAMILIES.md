# Kernel families the sprint never touched: the unreached files

Measured 2026-10-27 at origin/main plus `a710fc1f`, with `scripts/lean_imports.py` over `git ls-files`.
"Host-reached" is the import closure of `Host.Main`; "exe-reached" is the closure of any `[[lean_exe]]` root in
`lakefile.toml` (19 roots). Room*, Generic*, Contracts/ are other lanes'. Line counts are current.

Result: **no file qualifies for deletion.** Every unreached file either (a) states theorems about a Host-reached module
(proof-only, deleting it deletes the teeth), (b) has an importer in `Assurance/`, or (c) is exe-reached. No deletion was made.

| file | lines | importers (besides `Kernel.lean`) | native / script consumer | verdict |
|---|---|---|---|---|
| HyperdocumentMerge | 883 | HyperdocumentMergePublication | none; design `DISTRIBUTED-DESIGN.md` §1/§3 (anti-commutative merge) | PARKED-APP. RESCUE needs a merge verb on the Host; the six-file chain (~3.5k lines) grows the closure by about that. |
| HyperdocumentMergeAncestry | 317 | HyperdocumentTwoParentWitness | none | PARKED-APP (same chain) |
| HyperdocumentMergePublication | 644 | HyperdocumentMergeAncestry | none | PARKED-APP (same chain) |
| HyperdocumentPublication | 337 | GuardedDurableCommit; Assurance/HyperdocumentAgentOperation, HyperdocumentLinkPublicationWitness | none (`hyperdocument-link-sqlite-store` is listed for deletion in plan L9) | PARKED-APP; RESCUE only with a publish verb; do not delete (Assurance witnesses import it) |
| HyperdocumentTwoParentWitness | 863 | Assurance/HyperdocumentTwoParentHistoryWitness | none | PROOF-ONLY witness for the merge chain |
| HyperdocumentVersionEffects | 440 | HyperdocumentPublication, HyperdocumentMerge | none | PARKED-APP (same chain) |
| ContentMarks | 443 | none | `mark`/`unmark` are in the reached `ContentResource` grammar (v8) | PROOF-ONLY (K-MARKS over the reached `step`): not a twin. Keep. |
| ContentRunEdit | 484 | ContentResourceAudit | `insertRun` is in reached `ContentResource` | PROOF-ONLY (K-RUNS-RANGES refines `Theory.StableRanges`). Keep. |
| ContentResourceAudit | 419 | none | none | PROOF-ONLY audit cases for ContentRunEdit. Keep. |
| ContentResourceForestInstances | 132 | none | none | PROOF-ONLY: the two poles of `View.Forest` (teeth for the reached ContentElementTree). Keep. |
| DomainEpochStream | 186 | none | listed in `scripts/ports/full-loaded-callers.txt` | PROOF-ONLY: composes `DomainEpoch.admitAppend` into `StreamResource.computeTarget` (reached modules). Keep. |
| DomainEpochAudit | 188 | DomainEpochExport | none | PROOF-ONLY axiom pins for the epoch modules. Keep. |
| DomainEpochExport | 458 | DomainEpochAudit | `native/mini-sdk/lean-codec/closure.lean` names it | RESCUE (relay byte entry points, CHANNELS.md §2.4): wire = a Host/relay operation calling it; grows the closure by 2 modules. Not done. |
| ProviderExecutionLease | 1284 | Assurance/DreggNetProviderConsumer, HyperdocumentAgentRuntimeScheduler | none | PARKED-APP (dreggnet lease). The reached purse path is `ProviderRoute`/`ProviderMetering`; not a duplicate of it. |
| ProviderRouteConsent | 184 | Host/ClientConsentCore | `journey.d/jpay6.sh` plants it | LIVE: exe-reached by `Host.ClientConsentSession` (and 4 other exes), only not in `Host.Main`. No action. |
| ProviderRouteProofs | 57 | none | none | PROOF-ONLY: refill-then-call conservation over reached `PurseRefill` and `ProviderRoute`. Keep. |
| PrivateEscrowSettlement | 616 | Assurance/PrivateEscrowSettlementJoin, ReleaseGateRouting | none | PARKED-APP (escrow loop O25 is a separate native path) |
| PrivateRoomKeys | 577 | PrivateRoomWrapGrant | `resource-client/src/roomkey.rs:3100` re-implements `wrapAtomId` by hand, citing this file; `journey.d/jpriv1.sh` | RESCUE, and a law-1 breach on the Rust side: the wrap-atom id should come from the Lean module through `Host/RoomKeyReleaseAuthor` (Room lane owns that). Wiring grows the closure by 2 modules. |
| PrivateRoomWrapGrant | 139 | none | `jpriv1.sh` | RESCUE with PrivateRoomKeys |
| PrivateTurn | 287 | Assurance/SelvageV0Manifest | none | TWIN of `Kernel.Turn`'s `Hyperedge` at `Pub × Priv` per `KERNEL-TWIN-AUDIT.md` lines 68/542; deletable only after SelvageV0Manifest (research) moves in C2. Hold. |

Seams reported, not acted on: (1) `roomkey.rs` wrap-atom id duplicates Lean (PrivateRoomKeys). (2) A merge/publish verb is the single missing wire for the whole Hyperdocument chain. (3) DomainEpochExport's relay entry points have no caller.
