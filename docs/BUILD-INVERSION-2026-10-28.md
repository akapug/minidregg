# Build inversion (2026-10-28): seams, interfaces, expected rebuild counts

Iteration-speed lane. Inputs: the measured rebuild counts below (dregg-ref, warm, closure-lock, cache off,
on the module-converted tree), the import-graph census (`scratch/crit/crit.py` over
`scripts/pipeline/lean-module-rss.tsv`), ember's steer (dependency inversion: kernel modules depend on small
interface leaves; concrete instances only at assembly points; ATLAS law 5: an abstraction generalises the live
types and is instantiated in the CI closure, statements generalised never weakened, keystone statement changes
to the auditor first) and the astra structure review (`scratchpad/astra/arch.out.md`).

## What is measured (converted tree)

| edit | modules rebuilt | wall | why |
|---|---|---|---|
| proof edit (tactic to tactic), Kernel/NativeHost, `lake build Host.Main` | 1 | 16 s | proof in the private olean; public olean byte-identical |
| proof edit, Theory/Store.set_ne, Host closure | 9 | 234 s | Store + the census and its 7 non-module importers (KEEP) |
| statement edit, Kernel/NativeHost | 91 | 175 s | public interface changed: every importer must rebuild |
| one pin value, Compiler/PersistedCodecShapes | 438 | 1,531 s | Lake keys rebuilds on the transitive import closure's oleans |
| one new tag, Compiler/PersistedCodecTags | 479 | 2,114 s | same |

The same cost on the integrator's path (dregg-build, seats 4, main after the conversion): the A12d codec
regen took 2,668 s, of which two full pin-cascade passes took 1,099 s (peak 19.7 GB) and 1,098 s (peak
19.2 GB). The following incremental host stage took 660 s for 175 modules (peak 6.8 GB). One data change
therefore costs about 55 minutes end to end. The regen's confirming pass repeats the cascade; once the
pins leave the kernel's closure, both passes shrink to the assembly modules.

Consequence: proof-body edits are solved by the module system already (astra's step 2 goal, "a proof-body edit
elaborates nothing downstream", is met for Theory.Store: 631 -> 1 module of its own plus the KEEP chain).
What still costs a closure is DATA that sits high in the graph: the codec registry, the pins, and the epoch
assembled from them. A data change can only stay local if the data's module is not in the importer's
transitive closure at all. That is the inversion.

## Seam 1 (now): the codec registry and the epoch

Today: `Compiler.PersistedCodecTags` (the 646-entry registry) is imported by Kernel.WorldRoot (one tag),
Kernel.ClockCell (one tag, spelled twice: ClockCell:186 and the registry), Compiler.CanonicalCellRegistry (two),
Compiler.ObjectiveBendFrontEndIdentity (one manifest header) and Compiler.DurableCheckpointCodec (the epoch).
`Compiler.PersistedCodecShapes` (pins) is imported by DurableCheckpointCodec only, to build
`persistedCodecCorpus` and `StoreEpoch.current`; 437 modules sit below DurableCheckpointCodec.

Target (all four tag dependencies together, as astra says; graph cuts of one or two of them leave 373-467
tag-dependent Host modules):
1. Identity ownership: each identity is spelled once, in a leaf next to its codec family
   (`@[persisted_codec_tag]` stays the marker). The registry (`make_persisted_codec_manifest`) becomes an
   AGGREGATE module that imports the owner leaves; only the census, the emitters and the epoch assembly import
   it. A new tag touches its owner leaf and the aggregate.
2. Epoch assembly moves up: `persistedCodecCorpus`, `StoreEpoch.current` and the current-specialised
   definitions (`seedFrame`, `SeedEpoch.ofBytes`/`refusal`, `persistedSchemaRefs`, `foldSemantics`,
   the `seedEpoch_*` theorems) move from DurableCheckpointCodec to one assembly module. Generic checkpoint code
   keeps the existing `...For (epoch : StoreEpoch)` forms (already present: `seedFrameFor`,
   `SeedEpoch.ofBytesFor`, `seedEpoch_currentFor`, `seedEpoch_v*_refusedFor`); the current-epoch theorems stay
   by name as their instances (generalised, never weakened). Consumers that need the deployed epoch (the Host,
   ConsentAnchor's epoch theorems, journeys) import the assembly module.
3. The kernel sees identities as opaque handles where byte values are not needed; byte-level proofs
   (`native_decide`, codecs) live with the owner leaf or downstream of the aggregate.
4. ConsentAnchor -> census import cut (the census stays a build target of the gate: the umbrella and an
   explicit `Compiler.PersistedCodecTagCensusSelfTest` target); the 7 consent files leave KEEP and become
   modules. Expected: every lane closure loses the 235 s census node and the KEEP chain's rebuild-on-every-edit.

Expected after seam 1: a pin change rebuilds the pins, the assembly module and its importers (the Host
assembly points; to be counted on the resulting graph), not 438; a new tag rebuilds its owner leaf's
importers and the aggregate, not 479. Measured before/after with the same probe (`scratch/regen-probe.sh`).

## Disagreements with the astra order (with numbers)

- Store as the first seam: not needed for proof edits; the conversion measured 631 -> 9 (and 8 of the 9 are
  the census chain that seam 1 removes). A Store interface would help DEFINITION/statement edits in
  Theory/Store, which are rare (in main's last 500 commits, about 26 hours: Theory/Store 0 edits, Kernel/WorldRoot 0;
  PersistedCodecShapes 3, PersistedCodecTags 4, each a closure rebuild; since 2026-10-03, 3,000 commits:
  Theory/Store 0, Kernel/WorldRoot 5, PersistedCodecShapes 11, PersistedCodecTags 28). Seam 1 first; Store only if definition-edit counts justify it.
- Blanket `@[expose] public section` (astra's caution): correct that it propagates definition-body edits; it
  is needed today because downstream `decide`/`rfl` reduce through those bodies. Selective exposure is a
  per-seam decision inside each interface leaf, not a tree-wide change.

## Agreed and queued

- DurableIndex imports WorldRoot only for `bytesBits` (+ its length lemma): move the byte utilities to a leaf.
  DurableIndex is the 269 s head of the measured critical path (1,170 s over 51 modules), so this also lets it
  start earlier on a cold closure.
- Split heavy modules after the interfaces settle: Kernel.PayEnrolReceiver (15.5 GB+, OOM on dregg-build),
  Kernel.PayObservationReceiver (15.6 GB), Compiler.DurableIndex (native_decide probes at :1027 into a
  verification module), Kernel.Job.
- `scripts/check-host-closure.sh:4`'s premise is false (a downstream theorem can be about exactly what the Host
  runs); the gate should check dependency direction and receiving-path coverage, not closure membership.
