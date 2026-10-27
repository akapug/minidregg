# HP-DESIGN — Mini as a system designed for performance from the start

HP-DESIGN (Fable), 2026-10-14, for Ember's ruling: "bite the bullet, do all the changes, stop measuring every tiny
change, reorient the entire system into what it would need to look like if it was actually a high-performance
design." Tree: `next` = 0125b224. Tags: **READ** (path at `next` or a named lane tip) · **MEASURED** (number + source)
· **DERIVED** · **INFERRED** (my inference) · **ASSUMED** (a constant this document sets; Ember may move it).

This document is the target shape. `WASTE-MODEL.md [deleted 3b2aa109]` (lane/cost-model d670d30a) already proved the design is not
the problem: every operation does 11× to 6,700× the work the design requires and the excess is approach (W1–W14).
What follows says what the *approach* is, so that the running lanes stop optimising the old shape and build this one.
The style is TigerStyle (TigerBeetle `TIGER_STYLE.md [not in tree]`): safety, then performance, then developer experience;
performance decided in the design, by batching, static bounds and mechanical sympathy, not by profiling afterward;
assertions on every invariant; a limit on everything; deterministic simulation as the last line of defence.

## 0. The five decisions

1. **One resident Host per Store is the only writer and the only executor.** It holds the World, the trie, the held
   entries and the session in one process, and ingests every request from one socket. The log is Turns; the
   checkpoint is the World. The Host never re-executes its own history: the follower (`TurnLog.followFrom`) is the
   only replayer, and the consent provider re-executes only what it signs over.
2. **Admission is batched.** The loop drains the socket into a batch of ≤ `batchTurnsMax` requests, admits each into
   the in-memory World (`World.admit`, one at a time, deterministic), appends the batch's Turns and ingress bytes in one
   store transaction, one fsync, one KMAC tag at the batch end, then answers every request. Latency is the batch, not
   the fsync count.
3. **Bytes are `ByteArray` end to end, digests are 32 fixed bytes, and every codec decodes in one pass.** No
   `List UInt8` on any runtime path, no `Nat` digest on any hash input, no canonicity proved by re-encoding.
4. **Everything has a limit, and every limit and every theorem has an assertion.** `Kernel/Bounds.lean` holds the
   constants; a request past a bound is refused by name (an operating error); an invariant that a theorem promises
   and the compiled code violates is a `panic!` (a programmer error; the supervisor restarts from the checkpoint).
   Assertion density on `next` today: **0** `panic!`/`assert!` in Kernel, Compiler and Host (MEASURED, `git grep`).
5. **A deterministic simulation is the gate.** A seeded driver generates bounded random Turn sequences, drives the
   resident loop and the follower in-process, and asserts that the roots agree and every invariant holds, including
   under crash-restart at random points. It replaces per-commit measurement: measure at range ends; the waste gate
   catches regressions at landing.

Everything below is these five, said in Mini's own names.

## 1. THE RESIDENT HOST: one deterministic loop per Store

### 1.1 What it holds (the whole state, in one record)

```lean
structure Resident where                                  -- Host.Resident [not in tree] (new)
  world    : World deployedR TransactionId Digest         -- READ Kernel/World.lean:264 {cells, system}
  trie     : AuthTrie.Cache worldDig deployedIx 256       -- READ lane/store-root Theory/AuthTrieCache.lean (Cache, Holds)
  held     : LoadMemo                                     -- READ lane/perf-memo: pin-keyed CheckedEntry, bounded
  retained : Array (Nat × World …)                        -- past Worlds at seal points, ≤ retainedWorldsMax (STATE-AT keptAt)
  height   : Nat                                          -- = (world.head).1 (asserted equal after every admit)
  chain    : Digest                                       -- the log chain at height (asserted = world.head.2)
  archive  : IngressArchive                               -- ingress bytes keyed by ingress digest (TURN-LOG step 2)
  batch    : Batch                                        -- the open batch: ≤ batchTurnsMax pending (Turn, ingress, reply)
```

The `Loaded`/`Opening` twin (full open + light open, READ `Kernel/NativeHostSession.lean:154-162`, six root evaluations
per cold start at main, READ.md §3) is deleted: there is one `Resident`, and `Represents` is equality
(TURN-LOG 4a, `representsCheck_sound`). The decoded `authority` and `directory` are views of `world.cells` the kernel
asks for by cell, never a whole-world scan (JUDGE offender 5: `loadDirectory` on every admission is deleted).

### 1.2 The loop (control plane and data plane)

```
loop (the only unbounded loop in the Host; asserted as such):
  drain  : read frames from the one socket until the batch holds batchTurnsMax requests or batchWaitMs elapsed;
           every frame ≤ frameBytesMax, every request ≤ framesPerRequestMax frames (refused by name past either)
  decode : one pass per frame over the ByteArray (cursor codecs); refusal names the byte
  admit  : for each request, in arrival order: Turn.ofLoaded → World.admit on `world` → trie.insert on touched
           leaves → held-entry lookup by pin → reply built; a refused request is replied and does not enter the batch
  seal?  : if the checkpoint cadence fires, hand the immutable World value to a Task that encodes + MACs it
  append : one store transaction: Turns (encodeTurnAt) ‖ ingress bytes ‖ one tag at the batch end; one fsync
  assert : read back the batch (pair assertion: what was written decodes to what was admitted)
  reply  : answer every request of the batch (receipt + opening from the held trie)
```

`admit` is pure over `(Resident, request)`; `drain`/`append`/`reply` are the only IO. The loop runs at its own pace
(TigerStyle: never act directly on an external event), which is what makes batching and the bound on work-per-tick
possible. The consent provider's and the follower's checks are *outside* this process.

### 1.3 The hot path, sketched before it is coded (TigerStyle's back of the envelope)

| resource | per turn, necessary (WASTE-MODEL §2) | per batch of B | today (WASTE-MODEL §0, after STORE-ROOT) |
|---|---|---|---|
| CPU, server | T_srv ≈ 3.1 M instr: decode 33 k · verify 0.5 M · judge J ≈ 1 M · apply 41 k · leaf hash 0.52 M · trie path d·H ≈ 0.28 M · encode+KMAC 0.55 M | B·T_srv + one tag (35 k) | 12.4 G per invoke (1,647×) |
| CPU, consent | T_con ≈ 3.8 M (resident provider, O(new records)) | — | 1.63 G resident (430×) |
| disk | ≤ turnBytesMax + ingress bytes appended; ~4 KB measured (TURN-LOG: 785,441 B / 199 turns) | one transaction, **one fsync** | one fsync + tag per record; helper exec per read (W13) |
| memory | one trie path copy (~d nodes), one World map path copy; World ≤ stateBytesMax | batch buffer ≤ B·frameBytesMax | 100 MB for 69 turns of 300 KB (List UInt8, W7) |
| network | 1 request frame in, 1 receipt frame out, over a Unix socket | — | 7 ops × 2 processes per invoke; 5 codec execs |
| process starts | **0** | 0 | 1 Lean codec child per `mini`, 1 consent cold start, sqlite helper execs |

At hbox's ~11 G instr/s one world commits ~1,400 turns/s single-threaded (WASTE-MODEL §6.2); the latency floor per
turn is `batchWaitMs` + one fsync (1–5 ms, ASSUMED SSD) against op 2's p50 of 586 ms today (W2). delvetalk2's fork of
this design measures 0.7 ms per update once the entry is held (DELVE-SCOUT §1.4, MEASURED `DT/docs/PERF.md`), which is
the same 7–8 M instructions: the number is not aspirational, it is what the design already does elsewhere.

### 1.4 The log is Turns, the checkpoint is the World

- Log entry = `encodeTurnAt w t ‖ ingressDigest` (READ lane/turn-log `Kernel/DeployedTurnCompact.lean`: digest guards +
  new values; `decodeTurnAt_encodeTurnAt`; MEASURED 0.95× the record log on 199 turns). The ingress bytes live in the
  archive keyed by digest; `lookupRecorded` reads the archive (TURN-LOG step 2). `IntentRecord`, `canonicalPostBytes`,
  `ReplayEnvelope`, `DataSnapshot.install` and `execute` are deleted at TURN-LOG R5b.
- Checkpoint = `World v1 = {cells : CellTable, system : systemStream}` under one MAC and one tag (ROOT 10-14; READ
  lane/state-at `Kernel/CellTable.lean`: `Std.ExtTreeMap Nat bytes`; TURN-LOG `Kernel/WorldSystemCodec.lean`). The
  trie is not persisted: open rebuilds it from the cells (ROOT ruling FINAL; ~2n hashes, the same order as the MAC).
- Cadence: seal when the suffix bytes since the last seal reach `max(sealMinBytes, stateBytes / 4)` — a function of
  the log prefix, so any process computes it (INFERRED replacement for `height % 64`, which at `stateBytesMax` would
  pile seals faster than a Task drains them: 64 MiB × 128 instr/B ≈ 8.6 G ≈ 0.8 s per seal). The seal runs in a Task
  over the immutable World value; the loop continues. Past reads resume from the nearest retained World (in memory,
  ≤ `retainedWorldsMax`) or kept checkpoint (on disk, all retained: READ.md §2) plus ≤ one cadence of turns.
- Tags: one KMAC per batch end and per seal, not per entry. The chain `chain_h = H(chain_{h-1} ‖ H(turn_h))` binds every
  entry; a reader of height h verifies the chain to the next tagged height. `DREGG.DURABLE.LOG` v2→v3, checkpoint
  v3→v4, `StoreEpoch` derived (`Compiler/PersistedCodecTags.lean`): old Stores refuse by name; devnet re-genesis.

### 1.5 Zero-copy on the wire → decode → leg path

A frame arrives as one `ByteArray`; the cursor codec decodes fields by offset without copying; a Turn's legs hold
`ByteArray` slices (`Subarray`) of the frame for new values; the leaf hash and the KMAC absorb those slices directly;
the appended bytes are the frame's own bytes where the encoding is canonical (and it is: `encode_decodePrefix`,
CODEC-SHAPES item 1). The `List UInt8` ↔ `ByteArray` round trips at `Main.lean:2670` (`payload.toList`), the
`fixedStream` `octets.length` per field (CREATE.md §4) and the per-byte cons cell (W7, 16–32 B per octet) all go.

### 1.6 Static bounds

`Kernel/Bounds.lean` is one module of named constants with their relations as named theorems (`by decide`), imported
by every decoder, receiver and the client (Rust constants generated from it, as `NativeGlueGen` emits
`prover/generated/*.rs`). A bound hit is a `RefusalReason` with the bound's name and the offending size. See §6.

### 1.7 Assertions on what the theorems promise

The proofs say what `World.admit` does; the compiled code must *check* it, cheaply, so a codec, FFI or compiler
divergence is a crash and not a wrong root. Pairs (TigerStyle "it takes two"): before write and after read-back;
at admit and at follower fold; at insert and at open. The list is §6. The rule: at least two assertions per function
on the hot path, each on a fact a named theorem states, each O(touched) or O(1), never O(world).

### 1.8 What the Host never does

- **Re-execute its own history.** The only fold the Host runs is at cold open: decode the last World, fold the suffix
  since it (bounded by one cadence). After a commit the post-state *is* the session (W6: `confirm refresh` p50 33 ms
  → one head compare). `confirmed`'s cold open inside the warm server (CREATE.md N1) does not exist.
- **Spawn a process per request.** Codec verbs 7–11 are answered by the resident over the socket (`serveCodec` is
  already a loop, READ `Host/Main.lean:2692`); the credential verifier and the store are linked once per Host, not
  exec'd per read (W13: 66 verifier + 43 sqlite-store + 72 `sh` + 41 `chmod` execs per N=4 run). NativeCoprocess
  users on `next`: 3 files (MEASURED); the design has 0 on the hot path.
- **Rebuild the trie or re-derive the root** anywhere but cold open. The session's trie is the only one (STORE-ROOT
  step 3, READ: sessions already carry it).
- **Decide a turn more than once.** One `planOf` per request; header/report/outcome/verdict/frontEnd are projections
  (JUDGE offender 1: 5 decisions per plan × 2 sides → 1); `Proposal.check` consumes the gate's `Decided`.
- **Re-run the front end on a pinned package.** The held entry by pin (PERF-MEMO `LoadMemo`; DT's `PackageSession`):
  parse, elaborate, check once per `(pin, fuel, maxBytes)` per process; per request only `check applied` on `view args`.

## 2. THE CLIENT: one `mini`, two sockets, no cold start on the hot path

- One `mini` process per CLI op (P_cli = 0.61 M, MEASURED PERF-CLIENT). It talks to the resident Host over
  `<workspace>/SOCKET` and to the resident consent provider over `<anchor_dir>/r-<binding>.sock` (CONSENT-MODEL (3),
  cbea85b9). It spawns nothing: `local_process` (READ `native/resource-client/src/main.rs:1173-1191`) is deleted, and a
  workspace without a socket is an error, not a fallback.
- It never hashes the 173 MB Host image: the workspace pins `hostSha256` at creation and names it (READ.md §1: 60–85%
  of a current read today).
- An invoke is **one** process: the front-end quote is read from op 214's `pins[].frontEnd` (READ
  `Kernel/ObjectiveActivity.lean:977-982`), so `--prepare-only` probing (JUDGE offender 3) is deleted.
- The consent provider is resident per binding and keeps its own persisted frontier (CONSENT-MODEL Part B,
  `MINI-CONSENT-FRONTIER/v1`, own bases only: Part A, `Kept.own_sound`). It re-executes exactly the records since its
  last frame (the trust floor, `project-no-proof-system-in-mini-admission`), and nothing else. Its memo of held
  entries is the same `LoadMemo` as the Host's. Frontier key custody is Ember's call (CLAUDE.md pause 1): the
  recommendation on file is a subkey of the consent signing seed under `DREGG.MINI.CONSENT-FRONTIER-MAC/v1`.
- Rust decides nothing (DT's rule; Mini's `docs/README.md`): it carries bytes and custody. Its codecs are generated
  from the Lean descriptors (CODEC-SHAPES item 3; TWINS.md: 65 dual labels today, 33 unregistered).

## 3. THE DATA

- **World** = `{cells : ExtTreeMap CellId Cell, system : Store (sysLayout TxId Digest)}` in memory (READ
  `Kernel/World.lean:264`; the deployed cells decoded once at open), with the trie beside it as a cache whose `Holds`
  is a Prop, never a runtime entries list (STORE-ROOT: `RootsExact = Holds`; D4 deleted). The six system namespaces
  (journal, head, retired, parent, spent, allowance) are the one home of replay index, clock, spent set, parentage and
  meter (FD-1's eleven two-home facts collapse to one home each: TURN-LOG design table).
- **Turn** (READ `Kernel/World.lean:370`): `{txId, creates, legs, retires, event, nullifiers, charge, subject,
  keyEpoch, capability, notBefore, validUntil, absent}`. Persisted compact: digest guards (`readRoot`-class reads of
  the held cell's digest) and new values only; old values elided; `decodeLegAt_other` proves the dishonest half
  (lane/turn-log b1152e5d). Charge = `storageOf(creates + legs) + H.eventBytes event` (TURN-LOG CHARGE decision:
  no persisted number; the archive holds the event).
- **Canonical codecs, one pass.** Every `StreamCodec` carries `encode_decodePrefix` (CODEC-SHAPES 89ad1f23: 20
  non-canonical decoders found and fixed, encodings unchanged); the strict re-encode wrapper is deleted (STRICT-DEL).
  Decoders are cursors over `ByteArray` with a budget: a decode of n bytes does ≤ c·n work and allocates O(fields).
  Necessary decode is ~8 instr/B against ~360 today (WASTE-MODEL §1).
- **Digests are 32 fixed bytes.** `Digest := {bytes : ByteArray // bytes.size = 32}` at the spec level; the `Nat` view
  (`toNat`, for index bits and ordering) is a function with `toNat_injective`. `Theory.TypedAuthorization.Digest
  {value : Nat}` (READ `:53`) and `Digest256 := Fin (256^32)` (READ `Compiler/Tower256ConcreteBackend.lean:401`) are
  replaced, not bridged: a GMP bignum rendered base-255 digit by digit into a list before every node hash (W9) is
  the sin, and a bridge keeps it. Scale: 509 files mention `Digest` (MEASURED, INFERRED ~half are the spec type).
- **Bytes.** `List UInt8` 5,065 vs `ByteArray` 372 on `next` (MEASURED). Specs may keep `List UInt8` where a theorem
  is about lists; every runtime function is over `ByteArray` with a `@[csimp]` or definitional bridge. The global
  `DecidableEq (List UInt8)` instance change (PERF-CODEC) is the first step and lands with the cursor.
- **Persisted shapes from one source.** Every persisted type's codec is derived; its tag is `H(structural
  descriptor)`, content-addressed; `StoreEpoch = H(sorted descriptor hashes)`; the census fails the build when a
  shape moved without its tag (CODEC-SHAPES item 3, `#emit_persisted_codec_shapes`). Two lanes changing two types never
  touch one counter (E2: 4 of 5 ejections were two lanes on `StoreEpoch`).

## 4. VERIFICATION STAYS, and gains a simulation

- **Every fast structure is attached to its spec by an equality theorem**, the pattern this week: `CellTable.get_ofList`
  (= `Seed.lookup`), `AuthTrieCache.digest_eq` (cache digest = `tree`), `resume_eq_resumeFast` (`@[csimp]`, STATE-AT
  Engine), `replayPackage_eq` (PERF-MEMO), `decodeTurnAt_encodeTurnAt`, `followFrom_sound` (the follower IS
  `World.fold`), `representsCheck_sound`. `implemented_by` stays at 2 (MEASURED) and never grows; `@[csimp]` is 51.
- **The totality pole** (`Host/ObjectiveTurnTotalityRunner.lean`, 422/422) and **the follower journey**
  (`scripts/kern/turn-log-follower.sh`, 7/7 Stores, plants red by height) stay as rows.
- **Deterministic simulation** (new, `Host/WorldSim.lean`, exe `world-sim SEED STEPS`): a seeded PRNG generates Turn
  sequences within `Bounds` (creates, legs with guards, retires, nullifiers, charges, absent pins; valid and invalid,
  since the negative space is where bugs live), feeds them to the resident loop over an in-memory transport, and in
  the same process to `TurnLog.followFrom` over the bytes the loop appended. Asserts after every batch: roots equal;
  `admit`'s verdict equals the loop's reply; every refusal is one the model gives; every bound hit is a named refusal;
  the World's `WF`. Every K steps it kills the loop at a random point and restarts from the last seal, asserting the
  reopened Resident equals the follower's World. Cheap because the loop is a pure function of `(Resident, request)`:
  one seed, one process, no sockets, minutes. It is the gate for every range below and runs nightly over fresh seeds.

## 5. THE RANGES

### 5.1 Where today's lanes land in this shape

| lane (tip) | part of the design | status / what changes for it |
|---|---|---|
| TURN-LOG-3 (b1152e5d + 4a in tree) | §1.4 the log is Turns, the checkpoint is the World; `Resident.world` | continue 4a → CHARGE → step 1 (World checkpoint) → 2 (archive, LOG v3) → 3 (`recordsOf` view) → 4b. Tags per batch end, not per entry, is HP-3's; TURN-LOG keeps per-entry tags until it lands |
| STATE-AT-2 (9da33212; Engine on state-at-dev) | §3 the World's engine: `CellTable`, HashSet spent, journal index; §1.4 retained Worlds for past reads | the Engine IS `Resident.world`'s representation; `view : Engine → DataSnapshot` dies with the twin at R5b. `keptAt` becomes "nearest retained World or kept checkpoint" |
| STORE-ROOT-2 (81269fd3, rebased rb) | §1.1 the trie; §3 `Holds` as Prop | landed shape. Remaining: rebase onto next; `openSealedRooted` fold; leaf digests of touched cells become §6 assertions |
| CODEC-SHAPES (89ad1f23) | §3 canonical codecs (item 1), ByteArray cursor (item 2), content-addressed tags (item 3) | item 2 is HP-2's spine: the cursor lands with `Bytes := ByteArray`, not beside it |
| PERF-MEMO (815e97c3) | §1.1 `held : LoadMemo` | pin-keyed, bounded by `heldBytesMax` with single-key eviction (DT `Memo.lean`); the same memo serves the consent provider |
| CONSENT-MODEL-2 (84ebbddf; Part A in tree) | §2 the resident provider with its own frontier | Part A lands; Part B waits on the custody ruling; (2) the memo is PERF-MEMO's module |
| COST-MODEL (d670d30a) | §5.3 the waste gate | ceilings fall at each range end; judged at landing, never per commit |
| PERF-FIX / PERF-CLIENT / PERF-CODEC (on next) | local removals already in the floor | done; nothing more is measured there |

### 5.2 What is MISSING: new ranges, ordered by what they unblock

Each ≤ ~10 files, one commit, its gate named. Lanes converge forward in parallel; no locking.

- **HP-1 BOUNDS** (unblocks HP-3, HP-5, HP-6, HP-2's fixed buffers). `Kernel/Bounds.lean` (constants + relation
  theorems); `Compiler/RefusalReason.lean` (`pastBound name size`); `Kernel/DeployedTurnCompact.lean` (decoder refuses
  past `turnBytesMax`/`legsPerTurnMax`/`cellsTouchedMax`); `Compiler/DurableReceiverIO.lean` (`prepareAppend` refuses
  past `cellBytesMax`, `nullifiersPerTurnMax`); `Host/Main.lean` (`serveFrame` refuses past `frameBytesMax`,
  `framesPerRequestMax`); `Compiler/NativeGlueGen.lean` (emit the constants to Rust); one generated Rust file;
  `bounds.tsv [not in tree]` (the table in §6, checked against the module). Gate: a plant one byte over each bound is
  refused by that bound's name; the 56 `partial def`s (MEASURED) are each either the loop or rewritten with a fuel from
  `Bounds`.
- **HP-3 LOOP** (the resident loop with batched durability; needs TURN-LOG step 2 for Turn entries, can start on the
  record log). `Host.Resident [not in tree]` (the record of §1.1), `Host.ResidentLoop [not in tree]` (§1.2; the only `partial def`),
  `Compiler/DurableReceiverIO.lean` (`appendBatch`: one transaction, one fsync, one tag), the linked store
  (`native/hyperdocument-link-sqlite-store`: a linked call, not an exec, one transaction per batch; tags table keyed
  by batch-end height), `Kernel/NativeHostSession.lean` (Session := Resident; `NativeHostLight` deleted),
  `Host/Main.lean` (`serveSession` → the loop; ops 7–11 answered in-process), `docs/DURABLE-STORE.md` (tags at batch
  ends). Theorems: `appendBatch` fold = `fold_append`; a batch's replies are the sequential admits. Gate: follower
  journey 7/7; `strace -f -e execve` on one invoke = 0 execs after start.
- **HP-6 SIM** (needs HP-1, HP-3). `Kernel/TurnGen.lean` (seeded generator within Bounds; valid and invalid),
  `Host/WorldSim.lean` + exe, `scripts/gates/world-sim` (row: 3 seeds × 10⁴ steps, with crash-restart every 500),
  `docs/JOURNEY.md` (the row). Gate: a planted divergence (flip a guard check in the loop) is caught by seed 1 within
  the first K steps; the row is red on it.
- **HP-4 CLIENT** (independent of Lean; needs CONSENT (3), on lane/consent-model). `native/resource-client/src/
  {main.rs, transport.rs, client_consent.rs, workspace.rs, activity.rs}`, `activity_world.py` (probe deleted),
  `scripts/perf/workload.py`. Gate: `op.read.current` ≤ 3× necessary (1.45 M) in the waste table; zero execs per op.
- **HP-5 ASSERT** (needs HP-1, HP-3; then ongoing: every range adds its rows). The §6 rows marked *runtime*, placed
  in `ResidentLoop`, `appendBatch` read-back, `AuthTrieCache.insert`, the codec cursor, `TurnLog.followFrom`. Gate:
  `scripts/gates/assertion-density` ≥ 2 per hot-path function; the simulation runs with assertions on.
- **HP-2 BYTES+DIGEST** (one flag-day range after TURN-LOG 4b and CODEC-SHAPES item 1 land, so it rewrites the
  surviving tree once; mechanical by `ast-grep` in a day, not by hand over weeks). `Compiler/Tower256ConcreteBackend.lean`
  (cursor over `ByteArray`), `Kernel.Digest [not in tree]` (new: the 32-byte digest, `toNat`), `Theory/TypedAuthorization.lean`
  (Digest replaced), `Theory/Sp800185*.lean` (absorb `ByteArray`; customization absorbed once per tag, W10),
  `Kernel/WorldRoot.lean`, `Kernel/DeployedTurnCompact.lean`, `Kernel/CellTable.lean` (bytes = `ByteArray`), the
  `DecidableEq` instance, `Host/Main.lean` frame boundary, the Rust `Digest` twin. Re-genesis (hash inputs change).
  Gate: codec-bench ≤ 40 instr/B; follower 7/7; the waste rows `op.*` fall ≥ 3× (DERIVED from W7+W9 shares).
- **HP-7 KECCAK** (after HP-2; local). Scalar-replaced `UInt64` lanes in `Theory/Sp800185Cshake256Fast.lean` (W14:
  ~17.4 k → ~1.2 k instr per permutation, ASSUMED reference). Gate: `cshake-bench` and `#assert_compiled` on the
  existing fixtures.

The first three: **HP-1 BOUNDS, HP-3 LOOP, HP-6 SIM.** They are small, they do not collide with the five running
lanes' files (BOUNDS touches edges of two; LOOP replaces `NativeHostSession`/`NativeHostLight`, which no lane edits),
and once SIM exists every later range has a gate that is not a measurement.

### 5.3 What to STOP

- **Measuring per commit.** One bench at each range end, run once, on hbox, filtered (`cshake-bench`, `codec-bench`,
  `kn2-store-bench`, the workload N=32 M=32 K=16 under `perf stat --no-scale`). The waste gate judges every landing on
  the workload run it names; a ratio above its ceiling is red by row. Nothing else is measured.
- **The growth row per candidate.** G runs nightly on `next`, parameterised over (cells, records, cell size) with
  creates as a row (SINS G3); never on a lane candidate.
- **Re-pins per lane commit.** The objective-manifest ratchet is pinned once by INTEGRATOR at merge (decided 10-14);
  the 60 MB `objective-contract-changes.txt` of attributions is not a gate this design reads.
- **Single-file `lake env lean` checks as evidence.** A range is green when its umbrella and SIM are; one-file checks
  are for the author's loop, not the report.
- **Optimising the old shape.** No more work on `Loaded`/`Opening` refresh, `confirmed`, `atPrefix` bases, per-entry
  tags, `List UInt8` takes, `fixedStream` lengths, codec children or the probe protocol: each is deleted by a range
  above, and a lane that polishes one is building the thing the next range removes.

## 6. THE INVARIANTS AND LIMITS

**Limits** (`Kernel/Bounds.lean`; values ASSUMED from measured sizes: record ≈ 4 KB, cell ≈ 4 KB, 166 cells, state
0.7 MB at the workload; DT's `Bounds.entryCacheBytes` 64 MiB; WASTE-MODEL §6.3's 85 MB cold-open trigger).

| name | bound | refused where (by name) | relation theorem |
|---|---|---|---|
| `frameBytesMax` | 8 MiB (a publish carries source) | `serveFrame` | `turnBytesMax ≤ frameBytesMax` |
| `framesPerRequestMax` | 16 | the loop's drain | — |
| `turnBytesMax` | 1 MiB (compact encoding) | `decodeTurnAt` | `legsPerTurnMax · cellBytesMax ≥ turnBytesMax` is NOT required: a turn is refused by bytes first |
| `legsPerTurnMax` | 256 | `decodeTurnAt`, `prepareAppend` | `cellsTouchedMax ≥ legsPerTurnMax` |
| `cellsTouchedMax` (creates+legs+retires+absent) | 512 | `prepareAppend` | footprint ≤ `cellsTouchedMax` |
| `cellBytesMax` | 1 MiB | `prepareAppend` (post bytes) | — |
| `nullifiersPerTurnMax` | 64 | `decodeTurnAt` | — |
| `batchTurnsMax` / `batchWaitMs` | 64 / 2 ms | the loop | `batchTurnsMax · frameBytesMax` bounds the batch buffer |
| `stateBytesMax` | 64 MiB this epoch | creates refused `storeFull` past it | seal ≤ 64 MiB × 128 instr/B ≈ 8.6 G |
| `sealMinBytes` | 1 MiB | cadence | one seal per ≥ `stateBytes/4` appended |
| `heldBytesMax` | 64 MiB | memo eviction (single key) | — |
| `retainedWorldsMax` | 8 | the retained ring | — |
| `trieDepth` | 256 (keys are 256-bit indexes) | `AuthTrie.verify` siblings ≤ 256 | `deployedIx_length` |
| `tailBound L` | 256 (READ `Host/ApplicationBirthAuthoringCheck.lean:44`) | `tailBound` refusal (exists) | — |
| meter lanes | 10, fixed (`meterLanes`) | — | `meterLanes_nodup`, `mem_meterLanes` (exist) |

**Invariants** (R = runtime assertion in the loop/follower, pair-placed; S = simulation asserts; P = proof only).

| invariant | asserted | cost | theorem it mirrors (READ unless marked) |
|---|---|---|---|
| after admit, `world.head = some (height+1, chain')` and `Resident.height/chain` agree | R (after admit; follower after fold) | O(1) | `sysPost_head`, `fold_head` (`Kernel/World.lean`) |
| journal: `world.journal t.txId = some (height, H t)` after admit; refused `replayedTransaction` before | R | O(1) | `sysPost_journal`, `journal_exact` |
| every `n ∈ t.nullifiers` is spent after and unspent before | R | O(nullifiers) | `sysPost_spent`, `Reject.nullifierSpent` |
| absent pins: `cells c = none ∧ retired c = none` | R (loop) | O(absent) | `absentCheck_eq_none_iff` |
| rooms: a create's room is present | R | O(creates) | `step_parent_exists` |
| meter: allowance ≥ charge before, debited exactly after | R | O(lanes) | `sysPost_allowance`, `Reject.chargeAboveAllowance` |
| charge = `storageOf(creates+legs) + eventBytes` | R (before append) | O(legs) | `charge_eq` (TURN-LOG `Kernel/DeployedCharge.lean`, in tree) |
| touched cells: present ⇒ not retired (WF on the footprint) | R | O(touched) | `step_wf`; whole-World `WF`: S, `fold_wf` |
| ROM preserved on touched cells | R | O(touched) | `step_rom_preserved`, `rom_cell_immutable_after_birth` |
| untouched cells unchanged (frame) | P; S compares whole Worlds | — | `step_frame`, `step_leg` |
| trie leaf of each touched cell = `cellDigest` of the held cell | R (after insert) | 1 hash per touched cell | `digest_eq`, `insert_holds`, `Cache.Holds` (store-root) |
| trie root = `deployedRoot (entries of world)` | R at open and at seal (full); S every batch | O(n) hashes | `AuthTrieCache.digest_eq`, `build_holds` |
| opening completeness: an honest opening verifies | S (random cells per batch) | O(d) | `Cache.opening_complete` |
| codec pair: `decodeTurnAt w (encodeTurnAt w t) = some t` | R before append (one decode) | ~33 k | `decodeTurnAt_encodeTurnAt` |
| canonical: `encode v ++ s = bytes` for every decode | R on read-back of the batch | O(bytes) | `encode_decodePrefix` (codec-shapes) |
| chain: `chain_h = H(chain_{h-1} ‖ H(turn_h))`; tag at the batch end verifies | R (append) / follower | 1–2 hashes | `logChain`, `followFrom_sound` |
| batch = sequential: replies of a batch are the sequential admits | S | — | `fold_append`, `fold_snoc` |
| `Represents` is equality: `snapshot = ofWorld world` | R at open and rebase; S every batch | O(cells) | `representsCheck_sound` (TURN-LOG 4a) |
| follower root = Host root at every tagged height | S; the follower journey | O(1) | `followFrom_writeLog` |
| seal reopens to the World it sealed | R at open (MAC, then root) ; S crash-restart | O(state) once | `toWorld_ofWorld` (TURN-LOG `WorldCheckpoint`, in tree) |
| held entry answers the pure function of its pin | R: `entry.stored = stored` on lookup | O(1) | `replayPackage_eq` (perf-memo) |
| consent: refresh at the held height compares the Store's head tag | R (provider) | O(1) | `checkStore_eq_checkStored` (consent 561e603e) |
| consent: past states only from own bases | R (provider) | — | `Kept.own_sound`, `atPrefix_own` (consent Part A, in tree) |
| the loop is the only unbounded loop; every other loop has a `Bounds` fuel | gate `partial def` census = 1 | — | — |
| zero execs per request after start | gate (`strace` row) | — | — |
| every bound above refuses by its name, one byte over | S + plant row | — | — |

Marked INFERRED: the seal cadence rule, the specific bound values, the "~half of 509 files" Digest scale, and the
claim that BOUNDS/LOOP/SIM do not collide with running lanes' files (checked against the lane logs' file lists, not
against their working trees).
