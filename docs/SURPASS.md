# SURPASS: one transition, the World's

This is the present-state description of the part of the SURPASS design that the code cites: the
Turn cutover, §2(b). The Lean modules are the authority. Section numbers and lane names (T0 … T11)
are kept from the design of 2026-10-01 so that the `SURPASS §2(b)` citations in `Kernel/World.lean`,
`Kernel/TurnCensus.lean`, `Kernel/TurnOfIntent.lean`, `Kernel/HostRefinesWorldCore.lean` and
`Kernel/DeployedBridge.lean` resolve here. The rest of the design (consensus across machines, light
clients, the comparison with breadstuffs) is not described here and is not built.

Each item is marked **shipped** (in `main`, with the module named), **changed** (shipped, but not as
first designed: the difference is stated) or **design** (not built).

## 0. Summary

The kernel has two descriptions of one transition. The model is `World` with `World.step`
(`Kernel/World.lean`): a turn is a guarded patch per written cell. The deployed Host runs
`DurableCheckpoint.prepare` and `DurableDataIntent.execute` over `DurableReceiverIO.Loaded`, and logs
each written cell's whole post image (`canonicalPostBytes`).

What is in `main` is stage 0: the model is complete enough to hold every deployed fact, every live
admission is expressible as a turn, and the present Host is proved to refine `World.step`
(`HostRefinesWorldCore.deployed_refines_step`). No persisted byte changed. Stage 1, in which the
Host's state is a `World` and `submit` is `World.admit`, is design: its apex theorem,
`host_submit_is_step`, is written in `Kernel/HostRefinesWorldCore.lean` as a statement only, not
proved.

## 2(b). The Turn cutover

### The seven choices

1. **The turn is derived once.** **Shipped.** `Turn.ofIntent` (`Kernel/TurnOfIntent.lean`) reads
   each written cell's post image at its registry kind and emits the leg as the difference against
   the cell the world holds. `ofIntent_run` (`Kernel/SnapRepresents.lean`): running the derived
   patch yields the decoded post. `ofIntent_minimal`: its write footprint is exactly the addresses
   that differ. The derived patch is stricter than the durable layer: a rewrite of an append-only
   row has no turn (`appendOnly_rewrite_has_no_turn`). Per-family `family_patch_eq_diff` is
   design (stage 2).
2. **One home per fact.** **Changed.** `World`'s system cell holds `spent` and the `allowance`
   meter beside the journal, head, retired set and parent rows; `Turn` carries `nullifiers`,
   `charge`, `credit`, `subject`, `keyEpoch`, `capability` and its height window
   (`structure Turn`). The deployed consumed set is still the Host's, and the authority cell's
   `parent` plane (tag 13, `Compiler/CredentialAuthorityCell.lean`) is still there; deleting it is
   T7, design.
3. **The clock is the height.** **Shipped in the model** (`fold_head`; a turn's clock pin is its
   window, `step_window`). The Host still computes `clockOf` from its history length
   (`Compiler/CredentialAuthorityDomainReceiver.lean`). The K-CLOCK wall-time cell is an ordinary
   cell, unaffected.
4. **A runtime map before the Host folds.** **Changed.** No ordered-map `Store` was built. The
   durable resume runs over `Kernel/DurableEngine.lean`'s data representation instead, proved equal
   by `@[csimp]` (`resume_eq_resumeFast`).
5. **The log holds turns.** **Design.** The log still holds intent records with post images;
   `DurableReceiver`, `DurableWalHandler` and `FramedWalRefinement` are still in the tree.
6. **The charge is the patch.** **Shipped.** `World.charge_is_patch_bytes`: the storage lane of an
   admitted turn's charge is its patch bytes. On the deployed path the append refuses an intent whose
   exact charge is not its derived turn's (`Represents`' `meter` field, `HostRefinesWorldCore`).
7. **Retire, do not port.** **Design** as a flag-day deletion; the admission constructors are those
   of `NativeHostReplay.NativeAdmission`.

### The stages and lanes

| lane | what | status |
|---|---|---|
| T0 | census of the admission constructors: cells read and written, nullifiers, charge, clock pin | **shipped** as `planning/surpass/t0-receiver-census.md` in the planning repo; its content is restated per constructor in `Kernel/TurnCensus.lean` |
| T1 | the model complete, and every admission a turn | **shipped**: `Kernel/World.lean` (§"One home per fact"), `Kernel/TurnCensus.lean`: `census_shapes_admitted_at_w0` decides each of the 48 constructors' representative turns accepted and their negations refused, by name; `Compiler.TurnCensusCoverage` fails the build when the constructor lists disagree |
| T3 | `Turn.ofIntent`, `Represents`, and the present Host as an `ImplementationRefinement` of `World.step` | **shipped**: `Kernel/TurnOfIntent.lean`, `Kernel/HostRefinesWorldCore.lean` (`deployed_refines_step`, `host_trace_represents_fold`, `confirmed_represents`) |
| T3b | `Represents` over the deployed codecs; ROM births as turns | **shipped**: `Kernel/DeployedBridge.lean` (`deployed_cells_iff`); `TurnCensus.theList_empty` (no admission is left that is not a turn) |
| T4 | the Host's state is a `World`; `host_submit_is_step` | **design**. `HostRefinesWorldCore` lists, per `Represents` field, what T4 must still prove (journal digests, the height window, capability and key epoch) |
| T7 | one parent: delete the authority cell's `parent` plane | **design** |
| T9 | conservation as a property of the transition (`step_conserves`) | **changed**: `TurnCensus.step_conserves` is proved for the census Book layout only; its instance at the deployed Book cell (`Theory/CanonicalResourceKernel`) is not proved |
| T10 | the joint apex is the post world root | **design** |

Stage 1 changes the log, checkpoint and authority wire formats and needs one re-genesis. Stage 2
deletes the durable twin (T11), proves `family_patch_eq_diff` per family (T12) and reads the walk
accumulators from state (T13). All of it is design.
