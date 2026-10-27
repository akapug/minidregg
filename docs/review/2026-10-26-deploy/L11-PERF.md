# L11 performance: where a write's seconds go, and what was done

2026-10-26/27, lane `lane/perf`, candidate of `a0db11f8`. Two boxes: hbox (co-tenant, `/tank` HDD;
`/tank/dregg-build/claude-lane-perf-20261026/`) and the quiet demo box `dregg-demo` (Hetzner ccx23,
4 dedicated EPYC vCPU, SSD; scratch Store as `mini-core` in `/var/lib/mini/scratch-perf/`, nothing
of the shipped Store touched). Scripts: `harness.sh` (start `mini serve`, N propose+submit writes,
certify every 200, per-write walls + Host CPU ticks), `drive.sh` (demo box: A/B, then the soak).
Performance is published, never a gate (ember, 2026-10-27).

## 0. Headline: on the quiet box the cost that grows is consent, not the Host

Demo box, scratch Store, B client: Host CPU per write is flat at 520-530 ms from 20 to 615 records
(`/proc/<host>/stat`); the resident consent provider (`minidregg-client-consent`, full-peer model)
costs **1051 ms CPU per write at 554 records and 1151 ms at 615**, about +1.6 ms per record, and the
propose step's wall grows with it (0.56 s at 20 records, 1.10 s at 400, 1.43 s at 615) while submit
stays at 0.8 s. Linear extrapolation: about 1.8 s of consent CPU per write at 1000 records and about
16 s at 10,000 (a week of minute ticks). The soak (section 5) is measuring that directly.

## 1. One signed write (propose + submit), broken down

**Demo box** (quiet SSD, 20-100 records, loadavg 0.7-1.3, wall p50 1.33-1.44 s, max 1.56 s):

| phase | per write | source |
|---|---|---|
| Host ops: op 2 333 ms, op 1 125, op 5 66, op 4 2x13, op 144 2x10 | ~0.57 s wall, 0.50 s Host CPU | `MINIDREGG_HOST_TRACE` in `out/ab0-*/serve.log`, n=80; `/proc` ticks |
| consent provider (resident) | 0.2 s at 20 records, growing ~1.6 ms per record (above) | `/proc` ticks of the provider |
| client custody fsyncs | 80 x 5.5 ms = ~0.4 s (A); 55 (B) | `fsprobe.tsv` p50 5.5 ms, p99 17 ms; counts from hbox strace |
| 2 `mini` processes + 2 codec Host children + local work | remainder, ~0.3 s | |

**hbox** (co-tenant HDD):

Scratch world built by the candidate's own `journey.sh` (J0-J4 + G at 10), then written by
`harness.sh`: the same propose/submit pair as growth step G. Rows are per write, medians over the
traced block (n=10, 182-201 records, loadavg 9) unless stated.

| phase | count per write | time per write | source |
|---|---|---|---|
| client custody fsyncs (file + its directory, ~35-40 files) | **80** | **1.71 s, 59% of wall** | `strace -e fsync,fdatasync` on both `mini` processes, `out/ab-At/trace` |
| Host op 2 (admission + durable append; includes the store helper's 7 syncs) | 1 | 0.43 s (max 2.9 s) | `MINIDREGG_HOST_TRACE`, serve logs of 6 untraced blocks, n=90 |
| store helper syncs inside op 2 (`journal_mode=DELETE`, `synchronous=EXTRA`, head anchor) | 7 | 0.08-0.53 s | strace of `mini serve`, `out/t1/trace/serve.*` |
| other Host ops (op 1 plan 87 ms, op 5 read 36 ms, op 4 x2, op 144 x2) | 6 | 0.15 s | same |
| local consent provider (resident; first frame after a new record) | 2 frames | ~0.21 s + ~0.01 s | strace connect timestamps, `out/t2/trace` (22 records) |
| `mini` processes + codec Host children (159 MB image, `codec` mode) | 2 + 2 | ~0.07-0.20 s each child to first answer; remainder of wall ~0.5 s | strace execve timestamps |
| Host process spawns per write | **0** | — | the served Host is resident; the only spawns are the client's codec children |

Wall p50 of that block: 3.04 s. On a quiet disk each fsync is one ZIL write (8.2 ms, one rotation
of the 7200 rpm mirror), so the same 80 cost ~0.7 s.

## 2. What makes the tail (the judge is write **max** <= 5 s)

`/tank` is a 2-disk HDD mirror (HUA723030ALA640) with no log device, shared with every
co-tenant. Each of the 80 serial client fsyncs (and the 7 server syncs) waits for a ZIL commit,
and under co-tenant write load those stretch from 8 ms to 0.2-1 s:

- 1 Hz fsync probe beside the runs (`fsprobe.tsv`, n=519): p50 42 ms, p90 104 ms, p99 446 ms,
  max 1.0 s.
- The slowest A/B write (18.1 s, `ab-A3` #15) coincided with probe fsyncs averaging 0.20 s over
  its window: 80 x 0.2 s is 16 s.
- The gate's 57.3 s write (`steps/G`, g887 at 19:08: propose 37.0 s + submit 20.2 s) sits in a
  cluster g881-g897 of slow writes, with no certify near it, while `sar` for 19:00-19:10 shows
  loadavg 22, sda/sdc 69% util, await 28.5 ms, queue 3.5. It is an I/O episode, not a height
  effect. Its p50 was flat across 0-1000 records (4.0 -> 4.3 s), so history size is not the driver
  up to 1000.
- During this lane's own cargo build a write took 138 s; its attempt-file mtimes show 34 s and
  67 s gaps around single-file publications (`challenge.bin`, `challenge.json`).

The gate's write wall also includes a certify on every 252nd write (3.3-3.9 s there).

## 3. The fix (Rust): directory fsyncs coalesced to the Host-request barrier

Commit `perf(L11): coalesce custody directory fsyncs` on `lane/perf`:
`mini_sdk::durable` defers only the directory fsync. Each file is still staged and fsynced before
its name is committed, so complete-or-absent holds at every crash point; a name becomes durable
at the next barrier. Barriers: before every byte to a Host (`transport::exchange_unix`,
`invoke_inner`, `invoke_pinned_deadline`), the existing `sync_retained_call` before an external
submit, `sync_dir`/`sync_parent`/`sync_ancestors`, and process exit. Opt-in for `mini workspace`
only. Wire bytes unchanged; consent unchanged (the signer still verifies the exact prefix).

A/B, same world, interleaved blocks within the same minutes, loadavg 8-10 throughout:

| block | records | A (candidate) wall p50 / max | B (lane) wall p50 / max |
|---|---|---|---|
| 1 | 92-121 | 2.71 / 3.56 | 2.20 / 2.94 |
| 2 | 122-151 | 2.96 / 4.16 | 1.99 / 3.03 |
| 3 | 152-181 | 4.42 / 18.14 | 3.48 / 3.90 |
| traced | 182-201 | 3.04 / 4.42 | 2.52 / 3.12 |

Per phase (traced block): client fsyncs 80 -> 55 (propose 40 -> 23, submit 45 -> 32), fsync
seconds p50 1.71 -> 1.02; Host op times unchanged (op 2 454 vs 434 ms, op 1 104 vs 96 ms). The tail
scales with the fsync count, so its exposure falls by the same ~31%; it is not removed.

Tests (hbox, filtered): `minidregg-mini-sdk durable` 9/9 including two new rows (a kill at every
stage in a deferring child still leaves old-or-new; the barrier syncs by directory identity after a
rename or removal); `minidregg-resource-client transport::tests` 60/60.

## 4. What remains, by owner

**L2 custody (the one signing path)**: the 55 remaining client fsyncs are one content fsync per
custody file, ~35 files per write (`.bin` + `.json` twins of intent, challenge, observation
signatures, plan, transaction signatures, call, outcome; plus a full custody attempt for the
propose step's signed read). One custody record per phase, with the JSON renderings derived on
read, brings this to about 6. That is the remaining structural cut.

**Store helper** (`native/hyperdocument-link-sqlite-store/src/lib.rs:470-473`): rollback journal
with `synchronous=EXTRA` costs 5 syncs per commit plus 2 for the head anchor. `journal_mode=WAL`
with `synchronous=FULL` is still durable at commit with 1 sync. The header names the rollback
journal as the observed transaction boundary, so this is the store owner's contract decision
(`DURABLE-STORE.md`), not changed here.

**L9 gate**: growth on `/tank` measures co-tenant HDD contention times the fsync count; the demo
VM is cloud SSD (fsync ~1-2 ms: 87 syncs ~0.15 s). Put the growth world on SSD, or record an fsync
probe beside it so a FAIL names its cause.

**L7 / Rust serve**: one Host thread per world with `HOST_STATE_OP_BUDGET` 600 s
(`transport.rs:53`); per-peer queue shares exist (`queue_job`). A per-op-class budget is the
Rust half of the fairness fix.

**Lean lane** (each change is a representation change under an existing statement):

1. `Host/Main.lean` `serveSession` (`serveFrame ... payload.toList`) and `serveCodec`
   (`body.toList.drop 1`): every request becomes a `List UInt8` at the frame boundary (W7, ~360
   instructions per byte). Dispatch on `ByteArray` with the existing cursor codec (`58b3ae50`);
   safe because decoding a `ByteArray` cursor is equal to decoding its `toList`, which is the lemma
   to state.
2. O(history) shapes on the image: `Compiler/NativeHostCodec.lean:66` builds world-root entries as
   `image.cellIds.map (image.currentBytes ·)`, where `Image.currentBytes` is
   `accepted.reverse.findSome?` (`Kernel/DurableReceiver.lean:266`), `Image.cellIds` is a
   `flatMap`+`eraseDups` over all accepted records (`:185`) and `Image.append` is
   `accepted ++ [r]` (`:179`). If the served path still evaluates these after the CellTable
   engine (`995c2bdb`), op 2 is O(cells x history). Route it through the engine's indexed table
   with a refinement lemma `image.currentBytes c = table.lookup c`. The discriminating number is
   op 2's `host-trace` ms across the soak's levels (below): flat means the engine already
   covers it.
3. A declared per-op cost class (`Kernel/Bounds`) so the Rust budget can drop from 600 s for
   ordinary state ops; the batched resident loop (HP-DESIGN §1) stays the end state.
4. **Consent refresh is O(history) per write (the week-scale blocker).** `Host/ClientConsentCore.lean`
   `refresh` (l.310) claims to admit only the appended records, yet the provider's CPU per write
   grows ~1.6 ms per record (1051 ms at 554, 1151 ms at 615). Suspects on that path: 
   `DurableReceiverIO.extendFrom` and `Basis.extendAppended` over the list-shaped image
   (`image.accepted ++ suffix`, `old.1.image.accepted.length`, a world-root recomputation over
   `Image.cellIds`/`Image.currentBytes`), and `storeReader`/`readerOf` per refresh. The fix
   is to make refresh O(new records) under the same `ConsentAnchor.Basis` statement; the
   alternative is the thin consent already built (`MINI_THIN_CONSENT=1`, frames 230-232, journey
   step THIN), which reads no Store but changes what the signer checks, so it needs a ruling.

## 5. Week scale: the 10k soak

`soak.sh` (under `swarm-build`, PID file `soak.pid`) grows the same Store with the lane client in
1000-write chunks; each chunk restarts `mini serve` (its first signed read is the cold-reopen
sample), certifies every 200 writes (wall recorded apart from the writes), and logs every write's
propose/submit wall and loadavg, plus Host op times (`MINIDREGG_HOST_TRACE`) and a 1 Hz fsync
probe (`fsprobe-soak.tsv`). Progress: `soak-progress.log`; per chunk `out/soak-N/`.

Running on the demo box (`systemd-run` scope `l11-perf-drive`, `MemoryMax=4G`, PID file
`/var/lib/mini/scratch-perf/drive.pid`; progress `progress.log`; per chunk `out/soak-N/` with
`writes.tsv` = index, acceptedCount, propose s, submit s, loadavg, Host pid, Host CPU ticks;
`certifies.tsv`; `serve.log` host-trace; reopen in `summary`). A/B blocks are taken at 1k, 5k and 10k.
Partial, at 615 records: wall p50 1.70 s, p99 2.02 s, max 2.05 s over 371 writes (loadavg 1.5),
op 2 p50 352 -> 363 ms between records 100 and 470 (flat), certify 0.34-1.0 s, reopen 1.06-3.9 s.
The hbox soak was stopped at 595 records (loadavg 30: not informative).

Reading it: `python3` over `out/soak-*/writes.tsv` for wall max/p99 per 1000, `host-trace op 2`
per chunk for Lean admission vs size, Host CPU ticks per write; the consent provider's ticks can
be sampled from `/proc/$(pgrep -u mini-core -x minidregg-clien)/stat` alongside acceptedCount.
