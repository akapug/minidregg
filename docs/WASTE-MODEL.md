# The waste model

**Question (Ember, 2026-10-14):** do we need to redesign the code before it can be fast at all?
**Answer:** no. Every operation we measured does 11× to 6,700× more work than the design requires, and
none of that excess is required by the design. The excess comes from how we approach the work. This
document makes performance a property of the design, the way conservation is: for each operation it
states the work the design **requires** (§2), names every kind of work we do **beyond** that and the
approach error behind it (§3, §4), and pins the ratio `done / necessary` in a table that may only fall
(`docs/waste-model.tsv`, gate `scripts/gates/check-waste-model`). §6 lists the waste the design itself
forces, and the scale at which that forced waste would make a redesign necessary.

Tags: **MEASURED** (number plus where it came from), **DERIVED** (follows from measured numbers or code
that was read), **ASSUMED** (a constant this document sets; changing it is a decisions line, §5).

## 0. Headline (raw instructions:u, `perf stat --no-scale`, whole process tree: Host + clients + children)

Runs: workload N=32 M=32 K=16, same pass, under load. Raw counts are load-safe within 1–2% (see §5).
`before` = cand-M (`/tmp/srw-before` on hbox, Host tree 5b7cae0d = the perf-fix lane now on `next`).
`after` = STORE-ROOT cand-1 (`/tmp/srw-after`, fffb817f = perf-fix plus the compressed world trie;
not yet on `next`). Neither run includes STATE-AT (kept-checkpoint past reads), CONSENT-MODEL (the
resident consent provider) or PERF-MEMO (the front-end memo).

| operation | necessary | done (before) | ratio | done (after) | ratio | class |
|---|---|---|---|---|---|---|
| birth (resource write + create: 2 turns) | 15.2 M | 43.6 G | 2,866× | 29.4 G | **1,933×** | approach |
| · resource turn + workspace files | 7.7 M | 26.0 G | 3,380× | 18.8 G | 2,440× | approach |
| · create turn | 7.5 M | 17.5 G | 2,336× | 10.6 G | 1,414× | approach |
| update / invoke (1 turn) | 7.5 M | 37.7 G | 5,030× | 12.4 G | **1,647×** | approach |
| call + grant | 7.5 M | 42.7 G | 5,690× | 15.1 G | 2,017× | approach |
| send | 7.5 M | 45.6 G | 6,085× | 17.5 G | 2,338× | approach |
| deliver | 7.5 M | 25.0 G | 3,340× | 10.0 G | 1,328× | approach |
| current read | 1.45 M | 0.556 G | 383× | 0.559 G | **385×** | approach |
| past read (`at` h) | 1.5 M | 40.2 G | 26,812× | 10.0 G | **6,656×** | approach |
| checkpoint seal + certify | 96 M | 21.8 G | 227× | 7.9 G | **82×** | approach |
| cold open to first read | 590 M | 23.9 G | 40× | 6.5 G | **11×** | local |
| session refresh after its own commit (Host trace, wall) | ~0.003 ms | p50 58 ms | ~18,000× | p50 33 ms | ~10,000× | approach |
| consent provider per frame (client tree, CONSENT-MODEL stepbench) | 3.8 M | invoke 19.5 G | 5,100× | resident: 1.63 G | 430× | approach |
| follower fold per Turn (TURN-LOG, wall-derived) | 0.9 M | — | — | ≤0.29 G | ≤320× | approach |

Classes: **done** means within 3× of necessary. **local** means within 30×: the remaining work is local, and
the term to attack next is named in §3. **approach** means beyond 30×: the design does not allow a
term of that size, so it comes from how we do the work, and §3 names it. No operation is within 3×.
Only cold open is within 30×, and it is dominated by the one Lean process start that the design
forces (§6).

Cross-check: ROOT reports that delvetalk2's fork of this design does an update in 0.7 ms. At hbox's
sustained ~11 G instr/s (CREATE.md §0, MEASURED) that is ~7–8 M instructions, which matches the 7.5 M per
turn derived in §2.

## 1. Measured primitives (the constants every estimate is built from)

| constant | value | source |
|---|---|---|
| K: compiled Lean cSHAKE/KMAC, bulk | **128 instr/byte**, i.e. ~17.4 k per 136-byte Keccak permutation; ~170 MB/s | MEASURED 10-14: `cshake-bench 1000000` vs `2000000` (15 hashes each), raw cpu_core 1.922 G vs 3.840 G. 1.918 G / 15 MB. Binary from census-review; Keccak sources identical to `next` (last change d8f7ca48 on both) |
| H: one trie node hash (tag + 2×32 B + customization block) | ~2 permutations ≈ **35 k** | DERIVED from K |
| customization prefix | cSHAKE of 32 B = 8.1 µs vs SHAKE of 32 B = 2.9 µs in the same run | MEASURED (`cshake-bench small`, wall, loaded box: the ratio is the signal) |
| P_lean: one Lean process start (173 MB image: relocation + builtin initializers) | **0.38 G**, ~40 ms | MEASURED PERF-FIX 22:10 (~140 Host execs per run) |
| P_cli: one `mini` client process, host pin used | **0.61 M** | MEASURED PERF-CLIENT (G: unpinned 444 M) |
| decode, today | **~360 instr/byte** (11.88 M per 33,075-octet record) | MEASURED PERF-CODEC (codec-bench after shape 2) |
| decode, necessary | **8 instr/byte** | ASSUMED: one pass over a byte array with a cursor. No such decoder exists in the repo to measure |
| signature verify / sign | 0.5 M / 0.1 M | ASSUMED (native ed25519 class) |
| J: one law decision over the touched members | **1 M** | ASSUMED. JUDGE.md: law evaluation is not an offender; no isolated measurement exists. Measure it (§7) |
| sizes | record r ≈ 4 KB; post image p ≈ 4 KB; cells n ≈ 166, trie depth d ≈ 8; state S ≈ 0.7 MB; Store 1.18 MB | MEASURED: TURN-LOG (824,416 B / 199 records); PERF-FIX-4 (110 records, 166 cells); summary.json |
| instr/s on hbox, one thread | ~11 G/s | MEASURED CREATE.md §0 (used only to turn wall into instructions, marked "wall-derived") |

Sensitivity: if J were 10 M instead of 1 M, a turn would need ~25 M and the turn ratios would fall
about 3.3×, to roughly 500–700×. They would still be "approach". If the necessary decode were
40 instr/byte instead of 8, a turn would need about 0.3 M more. No conclusion changes.

## 2. Necessary work per operation (what the design says it MUST do)

The design: verification by re-execution (no proof system: each admitter re-executes each new record
once); a Lean Host that is resident per Store; one consent provider per client binding that admits
every record it signs over; a compressed authenticated trie over cells; a log of MAC'd records with a
hash chain; and checkpoints that are the World under one MAC, with the root recomputed at open (ROOT
ruling, STORE-ROOT).

**One turn, server (T_srv ≈ 3.1 M).** decode the request (r×8 = 33 k) · verify its signature (0.5 M) ·
look up the touched cells, O(log n) map steps (~1 k) · judge the law once over the touched members (J =
1 M) · derive the Turn and apply its patch (~41 k) · hash the written cell's post image for its leaf
(p×K = 0.52 M) · update the trie path (d×H = 0.28 M) · append: encode (33 k), KMAC (r×K = 0.52 M), chain
hash (35 k), the Store write syscalls (~0.1 M, ASSUMED) · respond with the receipt and opening, whose siblings are
already in the held trie (~20 k). Asymptotic class: **O(touched · log cells + bytes written)**.

**One turn, consent (T_con ≈ 3.8 M).** verify the challenge's opening (p×K + d×H = 0.8 M) · admit the
records since its last frame, each once (steady loop: about 1 per turn; decode + J + apply + leaf +
path ≈ 1.9 M; this is the trust floor) · decide the plan once (J) · sign (0.1 M). Class:
**O(records written since this provider's last frame)**. A per-process provider does not meet this
class: its re-admission is O(history).

**One turn, client process (0.6 M).** One `mini` process (P_cli). Its codec runs in that process
(0 extra process starts). Class O(1).

| operation | necessary | composition | class |
|---|---|---|---|
| update / invoke; call+grant; send; deliver | **7.5 M** | T_srv + T_con + P_cli. A grant is a digest compare | O(touched·log n) |
| birth | **15.2 M** | 2 turns (resource, create) + the workspace files (~0.2 M) | O(touched·log n) |
| current read | **1.45 M** | P_cli + decode/lookup/encode (~50 k) + the client verifying one opening (0.8 M) | O(log n + cell bytes) |
| past read at h | **1.5 M** | as current read, against root(h) from the log tag, with retained siblings: path-copied trie nodes are content-addressed, d×32 B per write | O(log n) |
| checkpoint seal + certify | **96 M** | encode S (5.6 M) + MAC S (S×K = 90 M) + one signature | O(state bytes), at most once per seal |
| cold open to first read | **590 M** | P_lean (0.38 G) + decode S + MAC S + recompute the root (S×K + 2n·H ≈ 0.10 G) + fold the suffix since the checkpoint (k≈4 × 1.9 M) + one read | O(state bytes + suffix) |
| session refresh after its own commit | **~35 k** | none: the commit produced the state. Compare one head | O(1) |
| consent per frame | **3.8 M** | T_con | O(new records) |
| follower fold per Turn | **0.9 M** | decode + digest-guard compares (held digests, 0 hashes) + apply + leaf + path + chain | O(touched·log n) |

## 3. What we do that we don't need to, ordered by cost

Each row is one kind of waste: re-read, re-decode, re-derivation, re-execution, copy, allocation per
byte, process start, whole-collection traversal, redundant check, or measuring by doing. Each names
the APPROACH error behind it. "Share" says how much of which operation the waste takes, with its
source.

| # | waste (kind) | approach error | share now | status / attack |
|---|---|---|---|---|
| W1 | **Consent provider started cold per CLI process** (process start + whole-Store re-read + re-decode + re-validation + re-admission of records it already admitted) | a process per request; verifying again by re-executing a prefix instead of carrying a frontier | invoke: 19.5 G of client tree (MEASURED CONSENT-MODEL stepbench) → resident provider 1.63 G (−92%); birth 18.9 → 4.7 G. Of the provider's samples: walkSuffix 30–37%, loadChained 17–26%, prefixAt 8–13% | lane/consent-model (cbea85b9 + 561e603e), **not on next** |
| W2 | **Unattributed server submit** (op 2 p50 586 ms, op 1 prepare 207 ms, op 91 author 94 ms per resource step; unchanged by the trie) | unknown: no profile since PERF-FIX 22:10, because the serving Host runs from a memfd and perf cannot symbolize it | ≤ ~10 G of the 18.8 G resource step, wall-derived | **first measurement to take**: serve from a file path, `perf record` op 2 (§7) |
| W3 | **Past read by refolding**: `at` below the session's rebased base replays from genesis; the consent provider materializes the past state again (challengeAt → StoreCodec.encode / Materializer.rootOf) | re-execution of a prefix instead of retained versions; one base where a list of kept bases (or retained trie versions) is the structure | read.at 10.0 G vs read.current 0.56 G; STATE-AT bench: genesis 27.9 s → kept 15 ms at h=7,500/10k | lane/state-at d951d57a (**not on next**); statements change (atPrefix_below, at_is_fold_prefix) |
| W4 | **Front end re-run per frame** on a content-addressed package: parse, 2 elaborations, 4 packet renders (one only to take its length), 3 checker runs, 2 identity hashes | re-derivation of an artifact whose digest is already known; work done only to measure something | invoke/call/send plan + submit; op 210 p50 44 ms ×107 (wall) | lane/perf-memo (in flight) |
| W5 | **Lean process per `mini` for its codec child** | a process per request (the codec is pure: it belongs in-process or in the resident) | 0.38 G per CLI step = **~68% of a current read** (0.38 / 0.559 G, DERIVED) | local: serve the codec verbs from a process that is already resident (the consent daemon or the serving Host's socket) |
| W6 | **Session re-verification after its own commit** (`confirm refresh`: extendFrom/light refresh/validate after op 212) | re-execution / redundant check: the commit's outcome IS the new session state | p50 33 ms ×110 per run (after; 58 before) ≈ 0.36 G each, wall-derived | B measured a wash in instructions (refresh full 26 / adopt 59 / light 71 ms); remaining: Session.adopt of the committed Loaded with no re-validation (local) |
| W7 | **Bytes as linked lists** (`List UInt8`): 16–32 B of cons cell per byte, a pointer chase per byte into every hash, decode and compare | bytes as linked lists | decode 360 instr/B against a necessary 8 (×45); follower uses 100 MB for 69 turns of ~300 KB of log (TURN-LOG, MEASURED) | DESIGN (ledger D8): `Bytes = ByteArray` in the types; the global `DecidableEq (List UInt8)` instance change (PERF-CODEC) |
| W8 | **Canonicity proved by re-encoding**: strict decoders re-encode the value and compare | proving canonicity by re-encoding instead of by construction | ~1/3 of every strict decode (PERF-CODEC D-MATCH) | DESIGN: canonical `StreamCodec.nat` (a wire change), then a canonicity theorem lets the check go via @[csimp] |
| W9 | **Digests as naturals**: node hashes encode two 256-bit Nats base-255, digit by digit, into lists before Keccak | digests as naturals | every node hash (CREATE.md, the `digestStream` note) | local: a fixed 32-byte digest stream (an encoding change → re-genesis) |
| W10 | **The customization block absorbed again on every cSHAKE call** | recomputing a constant | cSHAKE(32 B) 8.1 µs vs SHAKE(32 B) 2.9 µs: **the constant costs ~1.8× the hash** for small inputs (MEASURED §1) | local: absorb each customization string once (a constant Keccak state per tag; same bytes out) |
| W11 | **Whole-collection traversals per request**: State.snapshot rehashes every base cell's full bytes (`rootTable`, O(state bytes·H)); spent = prefix.flatMap; journal and spent lookups are linear lists; history snoc; closure-chain snapshot | closure chains instead of maps; the work scales with the whole Store when it should scale with what changed | on rebase and kept reads; Θ(h) per replayed record (STATE-AT m4: kept read grows 30 → 165 ms from 7.5k to 22.5k) | CellTable (2da79e71) + DurableEngine (state-at-dev c8a24556) |
| W12 | **Redundant checks of the same fact**: full open chain-hashes the log from height 1 (13 ms at 110); the event re-encodes the ingress and cSHAKEs it twice in replay; `authorized` re-encodes the command for cost, and again with a cSHAKE; configOf decodes the policy ~7× per plan | the same fact verified twice | JUDGE 9a/9c/8; small each | local (except chain-from-checkpoint, which removes a check: DESIGN) |
| W13 | **Helper processes per request**: credential-signature-verifier exec with copy+chmod (`withPinnedSignature`), sqlite-store helper exec per durable read, `sh`, `chmod` | a process per request | strace N=4: verifier 66, sqlite-store 43, sh 72, chmod 41 execs per run (PERF-CLIENT) | local: a resident verifier / linked store (one start per Host) |
| W14 | **Keccak permutation at ~17.4 k instructions** where a native 64-bit implementation needs ~1.2 k (ASSUMED reference) | allocation and boxing inside the compiled permutation | ×14 on every hash. **Not counted in any ratio above**: §2 prices hashes at K | local in Lean (scalar-replaced UInt64 lanes) or a verified extern |

What was removed this week, so that nobody removes it twice (all MEASURED, raw): A, the cold open per
receipt readback (births −9%, updates −19%); E+C, one decision and no unread directory (updates −8%,
judgment −22%); F, the open recomputes the root once (bench 202.7 → 155.3 G); item 1, validateServedFrom
(updates −13%); M (op 214 33 → 15 ms); G/H/I/L on the client (Host execs per N=4 run 216 → 45; reads
890 → 407 G); J and bytesEqual in the codec (−30% per decode; no workload change); the compressed world
trie (births 1394 → 940 G, updates 1207 → 395 G, reads 695 → 181 G, cold open 13.9 → 3.0 s at 4,096
cells).

## 4. Mechanical sympathy (what the hardware is asked to do)

- **Process starts per operation.** Necessary: one client process per CLI op, and zero Lean starts. Today:
  one Lean codec child per `mini` (0.38 G each), a cold consent provider per `mini` unless it is resident,
  and helper execs for signatures and Store reads (W13). A Lean start costs 0.38 G, as much as ~50 turns'
  worth of necessary work.
- **Allocation per byte.** `List UInt8` costs one heap cell per octet (16–32 B), so a 4 KB record occupies
  64–128 KB and every pass over it chases pointers. Decoding allocates twice per octet (splitAt plus
  reverse). A ByteArray take measured worse only because it round-tripped through Array and back
  (PERF-CODEC shape 3, reverted). The fix is the type, not the take.
- **Boxed values.** Digests travel as `Nat`. A 256-bit Nat is a GMP bignum on the heap, and every node
  hash first renders two of them base-255 into lists (W9).
- **Cache-unfriendly structures.** The snapshot is a closure chain (one indirect call per lookup,
  O(history) deep), and the journal and spent sets are lists. The trie, now compressed, is the one
  structure shaped like its use (~8 hashes per insert where there were 256).
- **Work that scales with the whole Store** where the design scales with what changed: the consent
  provider's full open and re-admission (W1), past reads from genesis (W3), rootTable rehashing (W11),
  and the full-log chain hash on open (W12).
- **Syscalls.** Necessary: one read of the Store head per request and one write per commit. Today a durable
  read can go through a helper exec (W13: 43 sqlite-store execs per N=4 run); not counted per op yet.

## 5. The gate (`scripts/gates/check-waste-model`, table `docs/waste-model.tsv`)

- **Input:** a `scripts/perf/workload.sh` root, which holds results.tsv, summary.json, phases.tsv,
  perf.csv (`perf stat --no-scale -I 250`), transcript/, and w/public/serve.log
  (MINIDREGG_HOST_TRACE=1). `measure` reduces the run to per-operation raw instructions. Phase rows
  are phase total / op count, with an error of one 250 ms interval per phase. Op rows come from transcript-window
  attribution: each step owns the window since the previous step ended, and each interval is spread
  uniformly over its span. On the two runs here the attribution reproduces the phase totals (invoke
  12.339 vs 12.352 G). perf's start time is read from `perf.t0` (written by workload.sh from this lane on).
  For older runs it is recovered as the t0 at which box.py's own phase attribution reproduces the
  recorded per-phase counts exactly (error 0 on both runs).
- **Load safety.** Raw `instructions:u` (`--no-scale`) is judged on any box: PERF-FIX-3 measured
  5.67/5.68/5.67 G raw against 11.0–11.3 G scaled under 8 parallel jobs, and 1487 vs 1483 G births
  between two passes. **Wall is not load-safe.** Wall rows (Host trace p50) are judged only for a run whose
  `quiet.json` (box.py quiet) was quiet. On a loaded run each wall row prints `UNCONFIGURED`, naming the
  busy units. A run whose counts were scaled is refused: summary.json must say `perfCounting: raw`, or its
  workload.sh must be a known `--no-scale` version.
- **Verdict:** RED when any load-safe ratio exceeds its row's ceiling, or a table row is not measured.
- **Ratchet:** `ratchet FROM TO` is RED when a ceiling rose, a necessary figure changed, a row's safety
  changed or a row was removed, unless `scripts/gates/waste-model-decisions.txt` gained a line in the range
  naming the row's key and its new value. A lowered ceiling needs nothing. `judge` prints
  "ceiling may fall to X" for any row running at 0.8× its ceiling or below.
- **Pins:** the ceilings are the cand-M run's ratios (the Host tree on `next`) × 1.05 for phase rows and ×1.25 for
  attributed and wall rows. The committed fixture `scripts/gates/waste-model-fixture.tsv` is that run's
  measure table. When STORE-ROOT lands, the after run's hints are the new ceilings (birth 3010 → 2030,
  invoke 5285 → 1729, read.at 33530 → 6988, certify 238 → 86, cold open 42.5 → 11.6).
- **Merge gate:** row `waste-model` in scripts/pipeline/merge-gate-checks.sh runs four things: the
  self-test (fixture green; a ceiling planted below the fixture's ratio is red by name; an undecided
  raise is red; a decided raise passes), the ratchet FROM..TO, and `judge $WASTE_MODEL_RUN` when the
  landing names a run. With no run it prints one UNCONFIGURED line. The births row (lane/births-row) runs
  workload.py without perf. Wrapping it in `perf stat --no-scale` (workload.sh already does) makes every
  landing judged (§7). This lane's workload.sh edit (perf.t0, perfCounting) changes the scripts' hash, so
  runs before and after it carry different inputKeys: compare them through `measure` tables.

## 6. Which wastes the design forces, and which our approach causes

The design's four commitments are re-execution-based verification, the Lean runtime, compiled Keccak
and resident processes. The work they force is exactly the §2 column. None of the §0 ratios is forced:
by construction, forced work is the denominator. The design itself costs the following, with the scale
at which each cost would make a redesign necessary:

1. **Re-execution multiplies J.** Every turn's law is evaluated by the server, by every consent
   provider that admits the record, and by every follower: J × (1 + providers + followers). Today J is
   assumed at 1 M and is not an offender. **Redesign trigger:** laws whose evaluation reaches J ≳ 100 M
   (~10 ms) while a world has more than a few admitters. At that point the re-execution design costs more than
   proving would, and a proof system pays for itself. This is the bar to watch as laws grow; measure J
   (§7).
2. **Serial commit floor.** One world has one append writer (CAS append). At ~7.5 M per turn and ~11 G
   instr/s, one world can commit **~1,400 turns/s** single-threaded (server half alone: ~3,500/s).
   **Trigger:** a per-world bar above ~1,000 turns/s needs parallel commit or sharded worlds. The
   process model is not what blocks it.
3. **Whole-state hashing at open and at seal.** The root is recomputed at open and the whole state is
   MAC'd at seal (ROOT: no persisted node table). That is 2 × S × 128 instr/B. At 0.7 MB it costs
   0.18 G, which is fine. At 1 GB of state it costs 256 G, ~23 s per cold open and per seal.
   **Trigger:** state above ~85 MB breaks a 1 s cold-open budget (S × 11.6 ms/MB). Past that, the open
   must trust a MAC'd node table or leaf digests. The PAUSE question STORE-ROOT asked is exactly this.
4. **Compiled Keccak throughput** (~170 MB/s per core) bounds everything that must hash its bytes.
   A 10 MB cell write costs ≥ 59 ms of hashing alone. This is a problem only at bulk-data scale, and W14 can buy
   up to ×14 back within the same design.
5. **Lean process start** (0.38 G, ~40 ms) is forced once per cold open of a resident Host and is
   negligible there. Paying it per request is approach waste (W5, W13), not design.

**Verdict:** at the current bar (a few to tens of turns per second, under 100 MB of state, laws of 1 M
order), no redesign is necessary. Every measured excess is W1–W14 and has a local or type-level fix.
The architecture stops being capable when the product bar crosses trigger 1, 2 or 3, and the figures
above say where each of those lies.

## 7. Next measurements (each one names the term it settles)

- `perf record` op 2 / op 1 on a Host served from a file path (W2: the largest unattributed term).
- J: time one `planDecision` in isolation on the workload's laws (trigger 1; the denominator).
- The births row under `perf stat --no-scale` so every landing is judged (§5).
- Consent per frame and follower fold per Turn as workload phases. Both are ungated today because
  their only sources are a stepbench (CONSENT-MODEL) and a journey (TURN-LOG), not the workload.
