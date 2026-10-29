# PERF-ROOTS state (lane/perf-roots), 2026-10-28

Goal: compute a cell's root once per distinct cell image, not once per query.

## Design (done in code)
1. `Kernel/DurableEngine.lean`: the type is now `Engine (rootBytes)`, and it carries `roots : RootTable` (`Std.ExtTreeMap Nat (Thunk Digest)`) with `rootsExact`, plus `absentRoot`/`absentRootExact`.
   - `ofState` and `ofIndexed` root their cells lazily (`rootsOf`).
   - `install` inserts each write's `exactPost`, which `postRootsBound` proves exact.
   - `view` and `light` read `Engine.root`, a lookup. `root_eq` proves it equals `rootBytes (bytes id)`.
   - `ofState` and `ofIndexed` now take `rootBytes` first. Follow-on edits: `DurableEngineSuffix`, `Compiler/DurableReceiverCore`, `scripts/oracle-cold-replay-budget.lean`.
2. `Theory/CellState.lean`: `Materialized` gains the fields `bytesCache`/`bytesExact` and `rootCache`/`rootExact`.
   - The definitions of `Materialized.bytes` and `.root` are unchanged.
   - `@[csimp] bytes_eq_bytesCached` and `root_eq_rootCached` make compiled code read the caches.
   - `materialize` hashes its cached bytes, so a cell is encoded once.
   - `materializeCanonical` and `materializeCanonical_eq` cover a cell decoded from canonical bytes, which then keeps those bytes.
   - `Materialized.ext` needs no funext. It uses Unit-function eta, so no Quot.sound.
3. `Theory/CellSlot.lean`:
   - `PackedCell.bytes` reads `payload.bytes`, which is definitionally the same.
   - `@[csimp] decode_eq_decodeFast`: decoded cells keep their payload bytes via `decodePayload`, using the registry's `materializer_canonical`.
   - Effect: the `physicalRoot` of directory cells costs one cSHAKE and no encode, and `snapshot.cell.root` / `validate M pre pre.root` are cache reads.
4. Proof fixes:
   - `CredentialAuthorityDomain.load_cell`: `materialize M c.logical` is no longer defeq to `c`, so the proof uses `Materialized.ext`.
   - `CellSlot.bytes_of_decode`: the simp set now uses `materialize_bytes`.

## Checked
- Round 1 (dregg-ref) surfaced 3 reds; all are fixed above.
- Round 2 built 3117 modules with no error, then was OOM-killed at 12G with the default -j.
- `decodeFast` and `materializeCanonical` were proved in a probe (`lake env lean`), with axioms `[propext, Quot.sound]` for the csimp.
- NOT yet elaborated together: the round-3 build. Host.Main, NativeHost and NativeHostReplay have not been built.

## Build on dregg-ref
- Tree: `/srv/lanes/perf-roots` (root fs; `/build` is at 96%). `.lake` is seeded from un-enroll-renew.
- Edits are synced as uncommitted files on origin/main 2cc5e9a9e.
- Script: `/srv/lanes/perf-roots-b1.sh`. It runs `closure-lock swarm-build lake build` on the narrow modules, then NativeHostReplay, NativeHost and `+Host.Main:leanArts`.
- Round 3 FAILED AT ONCE: lake has no `-j` flag (`unknown short option '-j'`), so nothing built. Before rerunning, delete `-j 3` from the script and cap parallelism with the env var `LEAN_NUM_THREADS=3` instead; round 2 was OOM-killed at 12G without a cap.
- Unit: `perf-roots-b3` (user lanes). PID file: `/srv/lanes/perf-roots-b3.pid`. Log: `/srv/lanes/perf-roots-b1.log` (EXIT= line). Earlier logs: `*.round1.log`, `*.round2.log`.

## Next
- Read the round-3 log. Fix reds: expect more `materialize c.logical = c` rfl sites, fixed with `Materialized.ext rfl`.
- Then run the full umbrella on the integrator.
- Measure: in `.lake/build/ir`, check that `Materialized_root` call sites became `rootCached`, and that the `Engine.view` roots closure calls `Engine_root`.
- Not done: `WorldKindLawDependencies.loadTarget` and `LoadedPolicySource.readGuard` still hash the lifecycle bytes on each call. They could read `durable.snapshot.model.roots` (now a lookup; `PhysicalResourceReadGuard.current` is the exactness lemma), but that needs a rooted-directory parameter across about 30 receivers.
- Also not done: `PhysicalLawResolution.readGuards` re-runs `loadTarget` (the whole law graph) after `judge`.
