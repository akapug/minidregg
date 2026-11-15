# What an append costs as history grows

State on `lane/append-growth`. One cause of growth is fixed (the allocation check); the others
are measured, attributed to the code that does them, and not fixed. "Next" at the end is the
order of work. Numbers are from hbox, a shared box, one replica of the four-source fixture
unless a line says otherwise; times are microseconds.

## How to measure

- `MINI_STORE_PHASES=1` (environment of the receiving process) prints to stderr, per record:
  `store judge` (the executor and the gates, run once more to be timed), `store index` (the two
  steps of the journal index apply, with key counts), `store prepare` (index root, index rows,
  `Loaded.extend`, entry; record bytes and node rows), `store confirm` (read-back, checkpoint),
  `birth admit` (the parts of the native birth admission) and `birth prepare` (the parts of
  `prepareBirth`, run once more to be timed: a run with this flag pays the preparation twice, so
  its hand-off times are not the row's).
- `MINI_APPEND_TIMING=1` prints the ordered receiver's five phases; `MINI_APPLY_PHASES=1` the
  hand-off's.
- `scripts/gates/check-generic-simplex BIN` with `GENERIC_SIMPLEX_FLAT_HEIGHTS=200` and
  `GENERIC_SIMPLEX_ROW_LOGS=DIR` keeps the flat row's whole output in `DIR/four-source-flat.log`.
  The fixture seals a checkpoint every 8 records (the product every 64).
- `MINI_FLAT_BORN=account` makes every birth of the flat row register an account, so the Book
  gains one per birth.
- `minidregg-host CONFIG store-bench index N` times the journal index's row operations on a trie
  of N keys; `store-bench trie N` one `set` of the private index.
- `scripts/perf/flatness-bench.py --bin CANDIDATE/bin --root NEW --src TREE --n 100 --lo 10` is
  the product's row (100 appends to one document through the client). `MINI_TRACE=/abs/file`
  makes the client write one line per exchange.

## Where the time went before any fix (main at `74d653514`)

Heights 40, 120 and 200 are checkpoint heights in the fixture; 41, 121 and 199 are not.

| part of `receiveLoadedDetailed` | 1 | 40 | 120 | 200 | 41 | 121 | 199 |
|---|---|---|---|---|---|---|---|
| executor (`Loaded.prepare`) | 13 | 22 | 28 | 20 | | | |
| gates (`Loaded.judge`) | 50 | 47 | 56 | 54 | | | |
| index root (head tag MAC) | 1 | 79 | 86 | 79 | | | |
| journal index rows (`applyIndex`) | 11,505 | 14,424 | 18,271 | 18,597 | 15,677 | 20,380 | 16,232 |
| `Loaded.extend` and the World's turn | 1,976 | 2,523 | 3,137 | 3,138 | 2,759 | 3,191 | 2,883 |
| leaf, frontier, tag MAC | 256 | 614 | 801 | 818 | | | |
| the Store's append call | 357 | 1,147 | 1,724 | 1,818 | | | |
| read-back | 96 | 102 | 163 | 106 | | | |
| checkpoint seal and put | 0 | 5,870 | 24,373 | 55,007 | 1 | 2 | 2 |
| whole store phase | 14,489 | 25,209 | 49,278 | 80,517 | 21,288 | 26,999 | 22,045 |
| node rows written | 35 | 117 | 146 | 154 | | | |
| `deriveVerified` | 14,601 | 17,283 | 24,378 | 37,880 | 17,735 | 32,361 | 31,962 |

`deriveVerified` for a birth: the credential bundle (the signature verifier) is 12,300 to 13,500
at every height; `prepareBirth` was 1,010 at the first birth and 16,400 to 20,700 at the two
hundredth. Inside it `preparePreAuthority` 31, the grant batch 49, the candidate law 500 and the
authority writes 85 are level; `preparePostAuthority` was 72 / 622 / 2,638 / 11,510 / 17,380 at
births 1 / 34 / 78 / 167 / 200: quadratic.

## Fixed: the allocation check (`Directory.used`)

`Theory.CellRegistry.Directory.used` was a `Finset CellId`. `Directory.insert` computed
`before.used ∪ {cellId}`, which is `List.union` (every old identifier re-inserted by a scan), once
per create request, and `CellRegistry.create` and `LifecycleImage.view` decided `cellId ∈ used` by
a linear scan. `used` is now the set's characteristic function `CellId → Bool`, as `slots`
already is a function: an insertion adds one case, the directory of held images answers from the
image (`everUsed`, one map lookup), and `HeldImages.used`, `usedExact` and
`CompiledListOps.usedSet` are deleted. Statements are rephrased pointwise
(`allocate_success_used : ∀ cellId, after.used cellId = (before.used cellId || decide (cellId ∈
requests.map cellId))`, `allocate_success_fresh`, `create_success_iff`, `view_used`,
`view_fresh_iff`). No statement needed the set to be finite: the whole build is green without it.

After it `preparePostAuthority` is 61 to 75 at every height and `deriveVerified` is 14,693 at
height 1 and 15,799 at height 200. The flat row's median hand-off is 40,911 over the first 8
births and 52,707 over the last 8 (before: 41 to 54 ms and 67 to 89 ms).

With it, `PrivateCellRoot.indexStep` is compiled as `indexStepOnce` (`indexStep_eq_once`): an
insert evaluates the address's path once, for the walk and for the leaf digest.

## Measured, not fixed

- **The checkpoint seals the whole state.** `storeCheckpoint` encodes and MACs the whole `State`
  and the World's system store (`DurableCheckpointCodec.sealedBytesAt`) at every height that is
  a multiple of `checkpointEvery`: 5,870 / 24,373 / 55,007 at heights 40 / 120 / 200, about 0.27
  ms per birth of state. The system store (`Kernel.World.sysLayout`) has six namespaces; `journal`
  (one entry per record) and `spent` (one per nullifier) only grow, so the seal is O(history), not
  only O(state). The accepted direction: the checkpoint becomes a small sealed head and the cells
  are rows the append writes in its own transaction. The design message for it is owed before
  any of it is built (the keystone, what an open costs before and after, how a past height reads,
  what retires old cell versions, which formats move).
- **The journal index apply is the largest steady term**: 11 to 18 ms for a birth's 14 keys (150
  rows at height 200), levelling like a log; 1.4 to 2.4 ms for a document append's 3 keys. The
  rows are held (`heldIndexRows` answers), so there is no Store round trip. On a trie of 1,000
  keys (`store-bench index 1000`; 20,000 in brackets): `bitsOf` 16.6 (24.1); the digest of a leaf
  10.4, of a branch 5.4 (the private index's is 1.6: here a digest is a number, converted from
  and to 32 bytes around every hash); `openingOf` 19.0 (35.5); `lookupRows` 161.7 (227.8);
  `set` of a new key 564.5 (1,149.1); `set` over a held key 326.8 (454.0); `setAll` of twelve new
  keys 10,932 (18,362), that is 911 per key. Read from `Compiler/DurableIndex.lean`, each key
  pays: `lookupRows` then `set` (`IndexRows.insert`), so two walks and two verifications of
  about 20 hashes; `bitsOf` (65 bytes to 520 booleans) once per walk, per verification and per
  set; `here ++ [bit]` and `bits[here.length]?` at every level of a walk; a leaf digest per
  leaf sibling (`siblingSub`); in `split`, `(List.range 520).filter fun i => … bits[i]? ≠
  otherBits[i]?`, 520 list reads of up to 520 steps; the climb's 20 hashes; and in `setAll` and
  `insert` an `overlay` closure per key searched by `List.find?` and a quadratic
  `later ++ rows.filter (!later.any …)` over the rows written.
- **The Book is written whole.** With `MINI_FLAT_BORN=account` the record is 5,144 / 5,260 /
  5,502 / 5,747 bytes at births 1 / 40 / 120 / 200 and its largest write, the Book, 108 / 196 /
  436 / 676: three bytes per account. The bound on a birth's complete record is false.
- **`ExactReadback.ofAppended` prepares and extends a second time**: 2.6 to 3.9 ms, level.
- **The product's flat row is another path.** `flatness-bench.py` appends to one document; it
  makes no birth, and the allocation fix does not move it: the median propose and submit wall
  times over operations 1 to 10, 46 to 55 and 91 to 100 are 9.9 / 30.3 / 48.3 and 23.5 / 48.0 /
  54.7 ms on main and 10.8 / 33.3 / 49.2 and 31.9 / 67.4 / 59.2 ms on the lane (one run each).
  By the client's exchange trace over 80 operations, comparing operations 9 to 16 with the last
  8: Host operation 5 answers 9,426 bytes early and 66,950 late (2.5 to 8.3 ms); the client then
  makes five codec exchanges of operation 8 over that answer (1.6 to 4.7 ms each); Host
  operation 2, whose request is 2,415 bytes throughout, takes 19.1 ms early and 43.4 late; Host
  operation 1 is level at 9 ms. So the client reads something that grows by about 720 bytes per
  append and recodes it five times per proposal, and the Host's handling of operation 2 grows by
  0.3 ms per append of history. Neither is read in the code yet; the serving Host's append does
  not go through `prepareAppend` (only its index apply printed, 1.4 to 2.4 ms, level).

## What ran on `5e05cf4fc`

Whole `swarm-build lake build Minidregg minidregg-host` with the fixture and the gate
executables, rc 0, 13,062 jobs. `check-import-boundary.sh` OK. `check-bytes-repr.sh` 5033 against
the ceiling 5032: the one new occurrence is `digWithPath`'s node argument, `NodeIn (Address L)
(List UInt8) Inner`, the private index's existing node type. Native Host: overlay candidate
`d2eb8f7d8c4f` over the builder's `74d653514`. `scripts/pipeline/lane-journey-selftest` passes
on hbox. The Simplex gate at 200 heights with the phase prints: every row passes. Through
`lane-journey` on that candidate: J0 to J8 and THIN pass; KW 20/20, J12 139 rows, JPAY4 26/26 and
JROT 34/34 pass in one world, and K10C passes 184 rows in its own world. (In one world after KW,
K10C finds the world's socket closed and fails 147 rows at its first `enroll`: an order of steps
the earlier runs never made, not read further.) JPAY4's two Hosts and two residents, which live
in the run's short socket directory, were stopped by PID file by the runner.

## Next, in this order

1. The journal index apply: one walk and one verification per key, the key's bits once, no
   per-level list rebuilding, `split`'s first differing bit by one pass, the overlay as a map,
   each proved equal to the stated function (`@[csimp]`); then the digest without the number
   conversions. Target: the store phase off a checkpoint under 3 ms.
2. The checkpoint design message, then the checkpoint as a sealed head and cell rows.
3. The Book split, the same move.
4. Read the product row's two growing exchanges (Host operations 5 and 2) in the code.
