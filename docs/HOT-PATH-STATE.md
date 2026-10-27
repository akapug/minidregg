# HOT-PATH lane state (lane/hot-path-codec, 2026-10-27)

Branch `lane/hot-path-codec` from `origin/integration/2026-10-26` 9525547e; Mac worktree
`/Users/ember/dev/minidregg-lanes/hot-path-codec` (its `.lake` is a hardlink seed of
`minidregg-lanes/integration/.lake` at 90315db2: good for `lake env lean Compiler/*.lean`, NOT a build of this
branch; `Kernel/NativeHost.lean` cannot be elaborated there). Design: `docs/HOT-PATH-2026-10-27.md` §2 (a), (f),
(h).

## Landed (pushed)

| sha | what | verified |
|---|---|---|
| 3717320a | (a) the resident codec Host re-applied on the moved code: `mini_sdk::consent::{ResidentKind, connect_resident_kind, serve_resident_kind}` (`native/mini-sdk/src/consent.rs`), `mini_sdk::local::Codec::frame_with` (`local.rs`), `mini codec-resident --host --settings` (`native/resource-client/src/main.rs`), `local_frame` connects unless `MINI_CODEC_RESIDENT=0` (`client_consent.rs`); the semantic authority stays `pure_host` | Mac + dregg-build: `cargo nextest run -p minidregg-mini-sdk --lib --features native -E 'test(resident) \| test(codec)'` 5/5; `cargo nextest run -p minidregg-resource-client -E 'test(client_consent) \| test(resident) \| test(codec)'` 10/10 incl. `tests/codec_resident.rs` (two real `mini` processes, one `HOST codec` child; `=0` one per process; idle exit) |
| 40152929 | J12X: raw malformed codec frames (ops 7/10/11) are refused under NO_RECORD 253 (L1 `Host/RequestRefusal.lean` exceptionAnswer, grammar verdict); `journey.d/j12x.sh` asserts the decided refusal by name (`host_refused` default 253) | dregg-build, candidate 6236826f binaries, this tree's hooks: `JOURNEY_STEPS="J0 J1 J2 J3 J12X"` → J12X PASS 20/20 |
| bef3b452 | JP2/THIN: a birth under `MINI_THIN_CONSENT=1` is refused BY NAME in `workspace.rs::birth` (thin consent has no birth arm: `Kernel/NativeThinConsent.lean` `checkPlanThin` → `.notInvocation`; a birth plan is Store-derived, `Kernel/NativeHost.lean:307` `.birth`); `jthin-consent.sh` runs its per-row env-configured proxy with `MINI_CONSENT_RESIDENT=0` (the resident kept a proxy child started under the first row's `THIN_PROXY_MODE`) | dregg-build: THIN PASS (all rows; was red `fb-capture` on r2b); JP2 FAIL 20/60 at row 19 `create` with the named refusal, rows 1–18 pass. JP2 green needs a thin BIRTH consent arm (design ruling: what thin consent SHOWS for a birth and from which served inputs its factory/authority/allocation/source slot headers are bound) — NOT (f); on the round-3 candidate JP2/THIN never ran (demo row budget 2000 s spent: KC 703 s, K12C 345 s, KIX 315 s) |
| 6e6e3a09 | `MINI_OPEN_TIMING=1` laps for every stage of the FULL open: `Compiler/DurableReceiverCore.lean` `loadChained` (read/decode/chain/checkpoint/tags/frontier/resume/roots/presence index/link index/session indexes/world fold) and `Kernel/NativeHost.lean` `openExisting` (load/validate) | `lake env lean Compiler/DurableReceiverCore.lean` green on the Mac; `Kernel/NativeHost.lean` checked only by the dregg-build Host build (see below) |

## Mid-flight: the cold reopen (design §2(h), the doc section is in this commit)

Cause (read, not yet measured): `NativeHostSession.start` (`Kernel/NativeHostSession.lean:154`) runs the FULL
open before the light one; `loadChained` (`Compiler/DurableReceiverCore.lean:1207–1340`) reads/decodes/hashes/MACs
EVERY entry and builds six indexes + `trackOf` (genesis World fold, `:953`) over every record;
`validateLoaded` (`Kernel/NativeHostContext.lean:612`) checks every cell. Only `walkFrontier`/`resumeEngine`/roots
are suffix-only. Fix (statement-first in the doc): the checkpoint body carries the indexes, the World and the
chain; the open reads/hashes/MACs only the suffix (`readFromCheckpoint`), `Exact` restated relative to the base
(writer's theorem across the seal), `trackOf` and the genesis chain → `store audit` (`NativeHost.auditWithTiming`).
Complement: port reads to the light opening (25 `session.opened` arms vs 4 `session.light` in `Host/Main.lean`).

dregg-build (`ssh -o IdentitiesOnly=yes -i ~/.ssh/id_portable lanes@178.105.4.114`; it fetches anonymously, never
pushes; load 14–18 from other lanes all day):
- worktree `/build/lanes/hot-path-codec` (detached at the pushed sha; `target/release/mini` built at bef3b452;
  `.lake/native` kernels built).
- BEFORE measurement: `/build/lanes/hot-path-codec-perf-before.sh`, PID file `/build/lanes/hot-path-codec-perf-before.pid`,
  log `/build/lanes/hot-path-codec-perf-before.log`, output `/build/lanes/hot-path-codec-perf/before-*`: births-only
  workload (`scripts/perf/workload.py --births 840 --births-only`, ≈1.7k records) with candidate 6236826f, Store at
  `/run/user/1000/hpcp-before/w` (tmpfs); 188/840 births at 15:25Z (12–24 s each under load; hours to go), STILL RUNNING under its PID file. Its `reopen` phase is
  the cold-reopen BEFORE; `before-results.tsv` has p50/p99 per (phase, op); the propose slope = births `create`
  samples over the run (per-sample order is in `before-transcript`/`before-results.json`).
- Instrumented Host build: `/build/lanes/hot-path-codec-host-build.sh` (log `hot-path-codec-host-build.log`,
  `lake build minidregg-host` under the shared lake cache) was OOM-KILLED at 15:23Z inside its `SWARM_MEM_MAX=12G`
  scope after 3643 steps (the cache restored most of the tree in 13 min; the heavy modules need more). Rerun it
  with `SWARM_MEM_MAX=24G` (edit the script's export) when the box is quieter (the pipeline's own rows run at
  MemoryMax 24 G); it writes `/build/lanes/hot-path-codec/.lake/build/bin/minidregg-host`. Nothing of it is
  running; no PID to stop.
- Attribution, staged: `/build/lanes/hot-path-codec-reopen.sh HOST LABEL [STORE_ROOT]` reopens the before-Store with
  HOST under `MINI_OPEN_TIMING=1`, prints time-to-first-read and the `LAP` lines. Run it once the before-run is DONE
  (not before: it kills the Store's server by its PID file) with the instrumented host (label `laps`) and the
  candidate's `bin/minidregg-host` (label `cand`, the paired control).

## Next three steps

1. When `hot-path-codec-perf-before.log` has `DONE`: read `before-table.txt` (reopen row = BEFORE at ~1.7k);
   compute the births slope (`create` p50 first vs last 100 births); then `./hot-path-codec-reopen.sh
   /build/lanes/hot-path-codec/.lake/build/bin/minidregg-host laps` and `… $CAND/bin/minidregg-host cand`; put the
   stage laps into §2(h) (which stage carries the seconds decides whether (h) ships whole or the World fold /
   indexes first).
2. Implement (h) on this branch, statement-first: new checkpoint body version carrying indexes + World + chain;
   `Loaded` base+suffix for all of them; `trackOf`/genesis chain → `store audit`; `rootLog` at-use; theorems as the
   doc lists. Elaborate per file with `lake env lean` (seed `.lake` from a warm build of THIS branch's base: the
   integration seed misses `Kernel.PayEnrolV2Receiver`, `Compiler.ObjectiveBendPublication`), full `lake build
   minidregg-host` on dregg-build (`swarm-build`, `SWARM_MEM_MAX=12G`, `LEAN_NUM_THREADS=4`, `. box.env`).
3. AFTER: rebuild, rerun `hot-path-codec-reopen.sh <new host> after` on the same 1.7k Store; record before/after in
   §2(h); push; report. Then the thin birth consent arm needs ember's ruling (JP2).

Standing: never kill by pattern; stop only by the PID files above; never run an unfiltered `-p <crate>` suite;
never touch the demo box.
