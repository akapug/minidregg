# bend-ir2-proof and objective-emit: native crate review (2026-10-26)

Reader scope: `native/bend-ir2-proof/` (Rust, 812 lines of src+tests, plus provisioning and qualification text) and `native/objective-emit/` (Python, C, TypeScript, shell and Lean harness for the Objective Bend C backend). I read every file in both directories in full. For fixtures and evidence I note size and shape only. I also read the Lean producers and consumers they name, and grepped `scripts/`, `lakefile.toml`, `.github/` and `deploy/`. Nothing was built or run. The one exception is a read-only SHA-256 comparison of the pin file against `~/dev/breadstuffs`; `provision.py` itself was not run because it creates a symlink.

## EXECUTIVE SUMMARY

**bend-ir2-proof is a dormant, unbuildable research harness.** It has not been superseded by another crate. It is an offline CLI that takes a Lean-emitted local-row IR2 descriptor plus a CSV witness, proves and verifies it with breadstuffs' `dregg-circuit` and Plonky3 `HidingFriPcs`, and binds the descriptor bytes into the transcript (protocol "V5"). It is not a workspace member (`Cargo.toml:7` declares its own `[workspace]`). It cannot compile in this tree: both path dependencies point at `../bend-proof-deps/bread/...` (`Cargo.toml:14,27-28`), and that directory does not exist. No lakefile, script or CI references it. `scripts/pipeline/prime-cargo:12` names it as the crate it skips. The "OBJECTIVE-ONLY-MIGRATION" swapped the *source language* (upstream Bend was retired for Objective Bend). It did not replace this crate. The controller tests the qualification reports describe were deleted, and the promised "native Objective controller proof" has no producer. Its Lean counterpart (`Assurance/ObjectiveBendZkClaims.lean`) is imported only by the opt-in `ResearchWip.lean:10`. The qualification evidence (R32/R33) **cannot be reproduced** on a fresh Linux box. It needs a breadstuffs source slice whose root `Cargo.toml` exists only as a hash: it matches none of the 384 commits that touched that file in the local breadstuffs history. It also needs private salt fixtures, plus a test file and a Lean emitter that were both deleted.

**objective-emit verifies; it does not author admission.** But it does contain one hand-written semantic twin: `runtime.c` (632 lines) is a manual transcription of Lean's `stepRaw`. It runs over a ROM that Lean emits (`Compiler/ObjectiveBendEmitC.lean`). No refinement theorem exists (`runtime.c:12-13`, `ObjectiveBendEmitC.lean:28-31`). The Python harness only compares the C output against Lean `runBounded`, byte for byte. CI reaches it: `.github/workflows/build.yml:310` runs `scripts/local-gates.sh`, whose gates `objective-c` and `objective-cgen` (`local-gates.sh:97-98`) drive `differential.py`. No Mini path runs the C machine (`docs/OBJECTIVE-BEND.md:840-842`). Neither crate is needed for a public demo. Neither touches the host wire (`protocol/host-operations.json`, `Host/Json.lean`: zero shared vocabulary).

---

## 1. What it is and does

### 1.1 bend-ir2-proof

| File | Lines | Role |
|---|---|---|
| `src/main.rs` | 96 | CLI `prove descriptor.json public.csv trace.csv proof.bin` / `verify descriptor.json public.csv proof.bin` (`main.rs:66-67`) |
| `src/config.rs` | 104 | Plonky3 `StarkConfig`: BabyBear, quartic extension, Poseidon2-16 hiding Merkle MMCS, `HidingFriPcs` with 4 mask rows, the `FullDegreeChallenger` wrapper. Two profiles: V4 `PROFILE` (`config.rs:31`) and V5 `ARTIFACT_PROFILE` (`config.rs:33`) |
| `src/full_degree_challenger.rs` | 146 | Challenger wrapper. It rejection-samples degree-4 extension challenges until `{1,a,a²,a³}` spans the extension (`:14-34`, `:56-70`), panicking after 128 tries (`:69`). Has 5 unit tests |
| `src/masking_budget.rs` | 32 | `REQUIRED_TRACE_MASKS = 4·2 + 19 = 27`, `MIN_TRACE_ROWS = 32` (`:9-12`). `TraceCapacity::checked` (`:17-29`) |
| `src/legacy_config.rs` | 64 | V2 profile with no transcript framing. **Not declared as a module in `main.rs`** (`main.rs:3-5`); only `short_trace_disclosure.rs [not in tree]:7-8` includes it, via `#[path]` |
| `artifact_binding.rs [not in tree]` | 36 | V5 rejects a proof once a trailing space is added to the descriptor (`:14,33`). Needs `BEND_IR2_FIXTURE` |
| `bounded_commitment.rs [not in tree]` | 55 | Runs the binary against `BEND_COMMITMENT_FIXTURE`. Wrong digest/validity publics are rejected; a flipped private wire refuses to prove (`:18-25`, `:43-54`) |
| `masking_observations.rs [not in tree]` | 88 | Gaussian-elimination falsifier that 27 linear observations are covered by 32-row masks and not by a 1-row mask |
| `quotient_masking.rs [not in tree]` | 46 | Calls the real `get_quotient_ldes` and `recompose_quotient_from_chunks`: masked chunks recombine to zero |
| `short_trace_disclosure.rs [not in tree]` | 115 | Adversarial test: a 1-row raw proof leaks the private trace from public openings (`:72-78`). Also checks capacity refusals and capacity binding |
| `test_provision.py [not in tree]` | 30 | Unit test of `provision.verify` |
| `provision.py` | 46 | Checks SHA-256 of 374 pinned files under a given breadstuffs path, then symlinks `native/bend-proof-deps/bread` to it (`:34-40`) |
| `dependencies.lock.json` | 380 | `plonky3Revision`, `scope`, `files` (374 hashes: 196 `circuit/tests`, 135 `circuit/src`, 9+7 vendor Plonky3 patches, dregg-dsl, dregg-codec, the root `Cargo.toml`) |
| `.config/nextest.toml` | 6 | Excludes the two `bounded_commitment` tests from the default profile |
| README, OBJECTIVE-ONLY-MIGRATION, QUALIFICATION-R32/R33 | 36/57/101/71 | Prose status records (see §5, §7) |

**Wire formats.**
- Descriptor: breadstuffs `parse_vm_descriptor2` JSON (ir 2). Lean emits it via `Compiler/BendTraceIR2.lean:123-129` (`Plan.toWire`, name `mini-bend-bounded-trace-ir2-v1`, `challenges:0`, one `main` table, `window_gate` with `on_transition:false`, and `pi_binding` with `row:first`). Lean deliberately preserves the field order because breadstuffs' parser is order-sensitive (`BendTraceIR2.lean:105-108`).
- Public and trace inputs: one line of comma-separated canonical BabyBear decimals with a mandatory trailing newline (`main.rs:14-25`).
- Proof: `postcard` of `Ir2BatchProof<Config>`, with trailing bytes refused (`main.rs:88-89`).
- Output: the line `PASS profile=… mode=…` on stdout (`main.rs:93`).
- Environment variables (tests only): `BEND_IR2_FIXTURE`, `BEND_COMMITMENT_FIXTURE`, `BEND_COMMITMENT_PROOF_OUTPUT`.
- No sockets, no ports, no persistent state.

**Pipeline.** `main.rs` parses the descriptor, then:
1. `check_descriptor2_wellformed`.
2. `require_subset` (`:35-53`): no challenges, hash sites or ranges; exactly one Main table; only non-transition local window gates and first-row PI pins; every public pinned exactly once.
3. Builds the config: capacity fixed at 32 rows (`:75`), `for_artifact` over the exact descriptor bytes (`:76`).
4. Prove mode replicates the single witness row 32 times (`:80`), proves, checks `degree_bits == [6]` (`:56-62`), self-verifies, then writes the proof. Verify mode parses and verifies.

The V5 transcript absorbs, in order (`config.rs:68-88`): the profile string, the FRI parameters, `4`, `8`, `2`, `27`, the capacity, then the 8-byte descriptor length and the cSHAKE256 digest under customization `"DREGG"` / `"BEND.IR2.DESCRIPTOR-BYTES/v1"` (`:37-45`).

**Lean producers that still exist.** `Host/BendTraceIR2Emit.lean` (91 lines) writes `descriptor.json`, `trace.csv`, `alternate-trace.csv`, `public.csv`=`13`, and `tampered-public.csv`=`14` (`:78-90`); these are the `BEND_IR2_FIXTURE` files. `Host/BendCommitmentIR2Emit.lean` (44) and `Verify/BendCommittedIR2Emit.lean` (47) write the `BEND_COMMITMENT_FIXTURE` shape (`descriptor`, `trace`, `public`, `wrong-digest`, `wrong-validity`). Nothing in the tree calls any of the three. They are only reachable by hand-running `lake env lean --run`.

### 1.2 objective-emit

| File | Lines | Role |
|---|---|---|
| `runtime.c` | 632 | Hand-defunctionalized `stepRaw`/`runBounded` in C. Unbounded little-endian 32-bit-limb naturals (`:61-145`), arena with no frees (`:50-60`), single-cell undo log for exact capacity suspension (`:197-214`), the `objective-state.v1` codec writer (`:427-498`) and reader (`:505-594`), and a per-tick FNV fingerprint over (control tag, heap length, stack length) (`:598-604`). CLI: `prog HEAP STACK TICKS OUT_STATE [RESUME_STATE [FIRST_RESPONSE]]` (`:23-25`, `:606-632`). Prints one JSON line |
| `differential.py` | 213 | For each packet: Lean `typing` → Lean `suite` (emits `program.c` and `cases.json` with the expected outcome, ticks, fingerprint, heap, stack, bytes, resumes and State bytes) → `cc -O2 -std=c11 -Wall -Werror` → one C run per case → compare 8 fields plus State bytes (`:58`, `:155-157`). Exit 0 iff no FAIL. Supports `--serve` (a long-lived Lean worker), `--jobs`, `--max-fail`, `--runtime` (mutants) |
| `cdiff_minimize.py` | 123 | Delta-debugs a failing generated program through `objective-cdiff-gen shrink`, keeping the same failure signature |
| `cdiff-mutants.py` | 63 | 7 exact-text mutants of `runtime.c`; each must match exactly once (`:53-55`) |
| `transparency.py` | 80 | Runs `scripts/ObjectiveCheckpointTransparency.lean` on each activity packet. Requires the kernel-checkpoint chain and the lazy chain to agree, and the checkpoint byte count to stay constant over a growth window |
| `packets.ts` | 37 | Bun script. Builds `package-input.json` and calls the Lean front end (`tests/objective-bend-source/front.ts` → `Host/ObjectiveBendFrontEndMain.lean`) for `capture` and `elaborate`. Writes `index.json` |
| `build-lean-native.sh` | 18 | Compiles `Compiler/ObjectiveBendEmitCRun.lean` together with `.lake/build/ir` C files into `objective-lean-native`, using `leanc -O3` |
| `fastmachine/build.sh` | 32 | Builds `objective-machine-reference` and `objective-machine-fast` from `MachineRun.lean`, generating a sed-edited copy into `.lake/fastmachine/` (`:12-14`) |
| `fastmachine/MachineRun.lean` | 148 | `cases` and `bench` driver. `forceReference` is a hand "verbatim copy" of `forceWith` (`:29-37`) |
| `fastmachine/MachineDiag.lean` | 144 | Per-tick profiler (`profile`, `time`) |
| `fastmachine/differential.py` | 62 | Diffs the reference binary against the fast one |
| `fastmachine/DIAGNOSIS.md` | 86 | The FASTMACHINE lane's write-up on why compiled Lean was 500–2900× slower |
| `Stress.obend` | 35 | count/work/sharedWork/power/listSum workloads |
| `extra-cohort.json` | 7 | 5 stress items |
| `activity-cohort.json` | 828 (15 KB) | 1 item, `TallyTwelve`, with 14 typed responses and `expectedTurns: 14` |
| `fixtures/index.json` + `fixtures/SharedEffect/source.core.json` | 3 + 7 | Hand-built negative core term `(\x.x)(perform 1)` that must refuse `sharedEffect` |
| `evidence/*.log` | 13 files, 452 KB | Differential runs from 2026-10-04: 01/02 at 224/224, 03-cohort at 300/300, fixtures 5/5, stress 28/28, stresscount 7/7 (340 total), plus `-DOB_MUTATE_*` controls (25/63/3/243 FAIL), and `bench-01.log` |

**ROM and ABI.** Lean emits C tables (`ob_tag[]`, `ob_a..d[]`, pairs, limbs, labels, `ob_entry`, `ob_bound_zero`, `ob_responses[]`), declared `extern` in `runtime.c:32-36`. The tag numbering is written twice by hand: once in `runtime.c:38-43` (the `T_*`, `P_*`, `R_*` enums) and again in `ObjectiveBendEmitC.lean:326-332, 402-403, 425-430`. The two currently agree, including the gap at primitive code 9.

---

## 2. What it assumes of its surroundings

**Host wire.** Neither crate emits or parses a single host operation. I grepped `protocol/host-operations.json` and `Host/Json.lean` for `objective-state.v1`, `dregg.objective-bend.core.v2`, `package-input.v1`, `argument-values.v1`, `mini-bend-bounded-trace-ir2-v1`, `bend-ir2` and `BEND.IR2`: zero hits. **Neither crate has any host vocabulary, so there is nothing to mismatch.**

**bend-ir2-proof assumes:**
- **The breadstuffs source slice.** `dregg_circuit::descriptor_ir2` must provide `parse_vm_descriptor2`, `check_descriptor2_wellformed`, `prove_vm_descriptor2_for_config` and `verify_vm_descriptor2_with_config` (present at `~/dev/breadstuffs/circuit/src/descriptor_ir2.rs:1924, 2308, 7624, 7714`) and the constants `IR2_FRI_LOG_BLOWUP=6`, `NUM_QUERIES=19`, `QUERY_POW_BITS=16`, `COMMIT_POW_BITS=0` (`descriptor_ir2.rs:7269-7294`).
- **The two vendored Plonky3 patches** at rev `82cfad73` (`Cargo.toml:26-28`).
- **A Lean descriptor inside the local-row grammar.** `Compiler/BendTraceIR2.lean:117-121` emits exactly the two constraint shapes `require_subset` admits (`main.rs:43-47`). That matches.
- **The `artifact_digest` domain string `BEND.IR2.DESCRIPTOR-BYTES/v1` is Rust-only.** No Lean module computes or names it (grep found none). Any future Lean verifier or descriptor-pinning receiver has nothing to agree with.
- **The profile strings `…artifact-cshake-v5` and `…full-degree-trace-budget-v4` are Rust-only.**

**objective-emit assumes:**
- **Lean drivers** `Compiler/ObjectiveBendEmitCRun.lean` (`suite`, `typing`, `serve`; `:293-328`) and `Compiler/ObjectiveBendCDiffGen.lean` (`gen`, `shrink`; `:738-740`), built as lake exes `objective-cdiff` and `objective-cdiff-gen` (`lakefile.toml:147-153`).
- **The Lean front end** `Host/ObjectiveBendFrontEndMain.lean`, reached through `front.ts`.
- **`scripts/ObjectiveCheckpointTransparency.lean`.**
- **Theory modules** `ObjectiveBendOpenRecursion`, `DemandMachine`, `Types`, `Typing`, `Checkpoint`, `DemandData`, `DemandMachineFast`, located by compiled C path under `.lake/build/ir` (`build-lean-native.sh:16-17`, `fastmachine/build.sh:22-25`).
- **Toolchain:** bun (pinned to 1.3.11 in CI), cc, python3 and lake.
- **The JSON schema `dregg.objective-bend.core.v2`** (fixture `:2`), matched by `Compiler/ObjectiveBendCDiffGen.lean`, `Compiler/ObjectiveBendFrontEnd.lean` and `Host/ObjectiveBendFrontEnd.lean`.
- **The `objective-state.v1` codec**, owned by `Compiler/ObjectiveBendEmitC.lean`, which `runtime.c` re-implements by hand in both directions.
- **`activity-cohort.json`** loads `../../world/activity/Tally.obend` and `../../tests/objective-activity/TallyFromZero.obend`; both exist.
- **The vestigial `expectedTurns` key.** `activity-cohort.json:827` has it, but neither `packets.ts` nor `transparency.py` reads it. Only `tests/objective-bend-source/check-preview.ts:44` reads that key, and it reads it from a different cohort.

---

## 3. Does it decide anything semantic?

Neither crate sits on an admission, authority, funding, retry, identity, ordering, dedup or pricing path. No code path from host, Kernel or deploy reaches either one. Decisions found, ranked by weight:

1. **`runtime.c` is a hand-written second implementation of the machine's semantics.** This is the real design-law tension (ATLAS §7: "Authors nothing"; law 13: delete the twin). Every transition, refusal reason and ordering choice is hand-transcribed. Examples:
   - `perform` checks for an update frame before allocating the plan (`:309-322`).
   - `F_UPDATE` refuses `invalidUpdate` when the cell is not evaluating (`:331-340`).
   - The shadowing filter in `extend` (`:363-373`).
   - Truncated subtraction and `a/0=0`, `a%0=a` (`:97-139`).
   - Capacity decided by post-step size with undo (`:622-624`).

   Lean counterparts: `Theory/ObjectiveBendDemandMachine.lean` (`stepRaw`, `runBounded`) and `perform_under_update_refused`, as named in the fixture note. The mitigation is real: Lean computes the ROM, including `fix`/`mix` bodies read off `stepRaw` by probing (`ObjectiveBendEmitC.lean:9-17`), and every result is differential-checked against Lean. **Still, the derived path is not the only path.** The C switch is authored, not emitted. `docs/OBJECTIVE-BEND-BACKENDS.md:16` names the theorem path (a Lean model of the defunctionalized machine plus simulation, then generate the switch), and it is undone. The C machine has no consumer. It is a performance experiment that the csimp fast machine has since overtaken (§5).
2. **The per-tick fingerprint covers only control tag, heap length and stack length** (`runtime.c:598-604`; Lean `ObjectiveBendEmitC.lean:408-411`). The harness decides what "same trace" means. Both sides authored it identically, so this is a harness choice, not a semantic one.
3. **bend-ir2-proof derives a security parameter in Rust.** The mask budget is 27, and the minimum capacity of 32 rows is fixed for every proof (`masking_budget.rs:9-12`, `main.rs:75`). The README calls it "source-derived". I found no Lean statement producing 27 or 32: grep of `*.lean` for the constant or name came back empty. `Theory/BendQuotientMasking`, `BendQuotientSelectors` and `BendMaskingDescent` prove algebraic facts but do not export this number.
4. **bend-ir2-proof's descriptor-grammar gate `require_subset` is a Rust policy** over what the prover accepts (`main.rs:35-53`). It agrees with what Lean emits, but Lean does not export it.
5. **`FullDegreeChallenger` changes the Fiat–Shamir protocol in Rust** (`full_degree_challenger.rs:56-70`). It has no Lean model. R32 lines 65-67 concede that its "distribution bound assumes uniform extension draws".
6. **"Success"** for bend-ir2-proof is the `PASS` line with exit 0. That is fine for an offline harness. If a receiver were ever wired, it would be a Rust-side verdict with no Lean admission counterpart. The README says "Existing reexecution admission remains in force" (`README.md:36`).

---

## 4. Flaws, each with a failure scenario

**F1 (bend-ir2-proof will not build).** `Cargo.toml:14,27-28` need `native/bend-proof-deps/bread/`, which is absent. **Scenario:** any `cargo build` or `cargo metadata` in the crate fails on the missing path. Anyone who trusts the README's reproduction commands is blocked. Running `provision.py` against the current `~/dev/breadstuffs` also fails, because 373 of 374 pins match but the root `Cargo.toml` hash does not. **Harm:** the qualification claims cannot be re-checked by anyone.

**F2 (the pinned root `Cargo.toml` exists nowhere).** `dependencies.lock.json` `scope` says "root workspace membership narrowed to three crates; not an upstream release pin". I hashed `Cargo.toml` at all 384 commits touching it in the local breadstuffs history: no match. **Scenario:** a fresh box with a breadstuffs checkout must hand-write a narrowed manifest that hashes to an unknown preimage. That is effectively impossible. **Harm:** R32/R33 are non-reproducible by construction.

**F3 (R32's headline test is gone).** `QUALIFICATION-R32.txt:20-24, 89-96` and `R33:36-41` rest on `controller_commitment.rs [not in tree]` and `Verify.BendControllerCommitmentEmit [deleted 008fd5e7]`. Both were retired (`OBJECTIVE-ONLY-MIGRATION.txt:39-44`) and are absent from the tree. **Scenario:** a reviewer runs `cargo nextest … --test controller_commitment` and gets "no such test target". **Harm:** the files still sit in the crate root, presenting as current qualification.

**F4 (the default nextest profile is red without fixtures).** `.config/nextest.toml:3` excludes only the two `bounded_commitment` tests. `artifact_binding.rs:12`, `short_trace_disclosure.rs:28-29` and `short_trace_disclosure.rs:94` `unwrap()`/`expect()` the `BEND_IR2_FIXTURE` env var. **Scenario:** a plain `cargo nextest run` on a provisioned box reports 3 panics. A lane reads that as a backend regression.

**F5 (test constants are hard-coded, not imported).** `masking_observations.rs:56-57` hard-codes LDE log-blowup `6` and `19` queries, and `:69` hard-codes `27`. Meanwhile `masking_budget.rs` derives the same numbers from `IR2_*`. **Scenario:** breadstuffs changes `IR2_FRI_NUM_QUERIES`. `masking_budget` adapts, but the observation falsifier keeps testing the old map and stays green. **Harm:** a silent false pass on the privacy budget.

**F6 (verify mode needs OS entropy).** `main.rs:76` builds the config with `ProofRng::from_os()` (`config.rs:51,67`) even for `verify`. **Scenario:** a sandboxed verifier without getrandom fails with "proof entropy unavailable". This is minor, but a verifier should be deterministic.

**F7 (the verifier trusts the caller's descriptor).** V5 binds the bytes the caller supplies (`config.rs:98-103`), as the README concedes. **Scenario:** if this were ever wired, a caller who picks the descriptor picks the statement. Pinning which descriptor is authoritative belongs to Lean admission, and that has no producer (`OBJECTIVE-ONLY-MIGRATION.txt:24-29`).

**F8 (the C decoder trusts lengths it reads).** In `runtime.c`:
- `get_env` mallocs `len*8` from an untrusted u64 and never checks for NULL (`:525-527`).
- `get_value`'s record case computes `sizeof(Fields)+n*sizeof(Field)` with an unchecked multiply (`:538`).
- `get_pairs` does the same (`:546-548`).
- `ftell` is never checked for `-1` (`:553`).

**Scenario:** a corrupted or adversarial `RESUME_STATE` (n ≈ 2^60) wraps the size, allocates a small arena block, and the loop then writes past it, giving heap memory corruption. Today only the harness feeds state files, so the harm is limited to harness crashes. Any future "resume a stored checkpoint in C" use would turn this into an RCE-class parser.

**F9 (quadratic state dump).** `put_origin` calls `rom_find_nat` for every literal-origin cell. That function scans the whole ROM and allocates a fresh `nat_rom` copy per comparison in a never-freed arena (`runtime.c:443-453`). **Scenario:** StressCount leaves about 20K predecessor cells, so the dump costs about 20K × |ROM| allocations. That is harmless at today's sizes and super-linear for large heaps.

**F10 (tag ABI written by hand on both sides).** `runtime.c:38-43` and `ObjectiveBendEmitC.lean:326-332, 425-430`. **Scenario:** someone adds a Core4 primitive in Lean (as happened twice on 2026-10-04) and forgets the C enum. The ROM then carries code 11 and `F_BINRIGHT` falls through to `refuse(wrongValue)`. The differential catches this only if a cohort program uses the new primitive. Lean could emit the enum as a header.

**F11 (the committed evidence predates the current runtime).** All `evidence/*.log` files are from 2026-10-04 01:00–02:18, written by a `differential.py` without the `runtime=` header field. After that, commits `0afaf7f2` (subtract/divide/less/lessEqual) and `606e4e17` (modulo) changed `runtime.c`. **Scenario:** `docs/OBJECTIVE-BEND-BACKENDS.md:16` cites "340/340" as current evidence, but those logs never ran `P_SUB`/`P_DIV`/`P_MOD`/`P_LESS*`. The live gate does cover them (if green). The stale logs should be labelled historical or deleted.

**F12 (`transparency.py` has no timeout).** `transparency.py:49` calls `subprocess.run` with no `timeout=`, unlike `differential.py:106,149`. **Scenario:** a Lean regression that loops in `ObjectiveCheckpointTransparency.lean` hangs the gate indefinitely.

**F13 (`fastmachine/build.sh` writes into the shared `.lake/`).** It writes `.lake/fastmachine/MachineRunFast.lean` (`:12-14`) and runs `lake build` inside the repo. **Scenario:** two sessions running `check-objective-machine-perf.sh` at once race on the same generated file. This breaks the concurrent-orchestrator etiquette.

**F14 (a hand-copied oracle).** `MachineRun.lean:29-37` keeps `forceReference` as a "verbatim copy" of `forceWith`. It is identical today (`Theory/ObjectiveBendDemandData.lean:53-60`), but nothing enforces that. **Scenario:** `forceWith` changes. The reference then diverges, and the Lean-vs-Lean differential compares against a stale oracle and reports spurious FAILs, or masks a real one.

**F15 (Serve-mode Lean stderr is discarded).** `differential.py:69-70` sends worker stderr to `/dev/null`. **Scenario:** a Lean panic in serve mode shows up only as "lean worker died or timed out", with no diagnostic.

**F16 (docstring drift).** `MachineDiag.lean:3` advertises the mode `boundedcopy`, which `main` does not implement (`:132-136`). `cdiff-mutants.py:3` cites "the burn job's canary", but there is no burn job anywhere in the tree (grep).

---

## 5. Unwired / undone / dead / twins

**bend-ir2-proof (the whole crate is unwired):**
- Not in the workspace members (`/Users/ember/dev/minidregg/Cargo.toml:3`).
- No reference from `lakefile.toml`, `.github/`, `scripts/` (except the skip notice at `scripts/pipeline/prime-cargo:12`) or `deploy/`.
- The only live mentions are in `docs/BEND-GENERAL-ZKVM-PATH-20261003.txt` and `docs/construction/source-intake-20261003.json`. That intake file still lists the deleted `unrolled_controller.rs [not in tree]` and `controller_commitment.rs`.
- `src/legacy_config.rs` is dead code for the binary: it is not a `mod` of `main.rs`. It survives only as a regression oracle in `short_trace_disclosure.rs`.
- `config::for_capacity` and V4 `PROFILE` are reachable only from tests (`artifact_binding.rs:26`, `quotient_masking.rs:18`, `short_trace_disclosure.rs:39,100,109`).

**Is it live or superseded?** Neither. The migration file swaps language routes: upstream Bend was deleted on 2026-10-04 (`git show b91abe35`, which kept `artifact_binding.rs [not in tree]` after reading it). The crate's stated next step, "a real Objective native execution proof awaits the actual packed controller producer" (`OBJECTIVE-ONLY-MIGRATION.txt:53-55`), has no producer. The Lean side of that route (`Assurance/ObjectiveBendZkClaims.lean`, `Compiler/BendCommitted*.lean`, `Theory/BendQuotient*`, `Theory/BendMaskingDescent`) is imported only from `ResearchWip.lean`. That is the opt-in library (`lakefile.toml`, "Source-first research is an explicit opt-in build"). Its named theorems do exist: `arithmetic_observes_source` (`Assurance/ObjectiveBendCommittedSource.lean:37`), `direct_forces_both_success`, `accepted_run`, `prepare_exact`, `prepare_payload_aliases`.

**Twin.** minidregg's chosen proof system is Selvage (`prover/`, "Selvage sumcheck engine", `prover/Cargo.toml:5`). bend-ir2-proof is a second, unrelated backend: breadstuffs' Plonky3 STARK. It depends directly on `dregg-circuit`, the 271K-line breadstuffs component that the mission names as the #1 collapse target. Keeping it means a second prover stack with its own masking theory (`Theory/BendQuotient*`).

**objective-emit:**
- **Wired:**
  - The gates `objective-c` (preview cohort + `extra-cohort.json` + `fixtures/`) and `objective-cgen` (1000 generated seeds, with the 2 text mutants `spec-apply-metadata` and `add-carry`) run via `scripts/local-gates.sh:84,97-98` in CI (`.github/workflows/build.yml:310`). They are not in the merge gate: `scripts/pipeline/merge-gate-checks.sh:121` runs only `objective-proofs`.
- **Wired only manually:**
  - `transparency` (`check-objective-proofs.sh transparency|all`). It is not in the `local-gates` `GATES` list (`local-gates.sh:84`), so the "executed cross-check of forcingTransparent_of_yieldedPlan" never runs in CI.
  - `check-objective-machine-perf.sh [deleted 3b2aa109]`, which uses `fastmachine/build.sh`, `Stress.obend` and `packets.ts`. It is not in `GATES`.
- **No caller at all:**
  - `cdiff_minimize.py` (a developer tool).
  - `build-lean-native.sh` (cited only in docs).
  - `fastmachine/differential.py` (cited only in `docs/OBJECTIVE-BEND-BACKENDS.md:66`).
  - `fastmachine/MachineDiag.lean`: no build script compiles it, and it is outside every `lean_lib`, so it can rot unnoticed.
  - 5 of the 7 `cdiff-mutants.py` mutants (only 2 are used, at `check-objective-proofs.sh:364`).
- **Twin mutation mechanisms.** `runtime.c` carries compile-time mutants `OB_MUTATE_SHARED`/`PERFORM`/`UPDATE`/`EXTEND` (`:310-320, 334-337, 364-366`) that no script passes as `-D`; only the 2026-10-04 evidence used them. Separately, `cdiff-mutants.py` does text-replacement mutants. Test-only control code therefore sits in the artifact source. Pick one.
- **Twin machine.** The runtime is the third executor of Core4: the specification `stepRaw`, the csimp-proved `stepRawFast` (`Theory/ObjectiveBendDemandMachineFast.lean`, proven equal and installed as `@[csimp]`), and hand C. Per `DIAGNOSIS.md:74-79`, fast Lean runs StressWork in 41–43 ms against C's 20 ms. The C machine's raison d'être (500–2900× speed) is gone, and it has "no Mini path that invokes it".
- **Not committed:** the FASTMACHINE logs referenced in `DIAGNOSIS.md:5` live on hbox at `/tank/dregg-build/claude-lanes/fastmachine/logs/`.

---

## 6. Size and shape; DEMO-MINIMAL cut

**bend-ir2-proof.**
- Rust: src 442 lines (`config` 104, `full_degree_challenger` 146, `legacy_config` 64, `main` 96, `masking_budget` 32), tests 340, Python 76.
- Prose: 265 lines. `Cargo.lock`: 1,178 lines covering 111 packages, including about 30 `p3-*` crates (`p3-keccak`, `p3-goldilocks`, `p3-koala-bear`, `p3-poseidon1-*`, …), `rayon`, `blake3`, `rmp-serde`, `tracing`.
- Path dependencies: breadstuffs `dregg-circuit` (135 src files pinned), `dregg-dsl`, `dregg-codec`, two vendored Plonky3 crates, and `native/bend-proof-entropy` (92 lines; `rand =0.10.3`, `getrandom =0.3.4`).

**objective-emit.**
- Python 541, C 632, TypeScript 37, shell 50, Lean 292, Markdown 86, obend 35.
- Cohort and fixture JSON: about 845 lines. Evidence: 452 KB across 13 logs.

**DEMO-MINIMAL** (public Hetzner box with ssh shell, docuverse, SPK grains, Hermes residents, PAY and Discord): **zero files from either crate are needed.** Neither one is in `deploy/` or a candidate role, and neither is invoked by any runtime. Admission and preview run Lean `runBounded`, compiled through csimp.

**Could be deleted today**, with Git and the dated records preserving history:
- The whole of `native/bend-ir2-proof/` and `native/bend-proof-entropy/`, if the ZK-over-Plonky3 research route is abandoned in favour of Selvage. If it is kept, at minimum delete `QUALIFICATION-R32.txt` and `QUALIFICATION-R33.txt`: their reproduction steps reference deleted files, and they can move under `docs/` as history.
- `native/objective-emit/evidence/` (stale relative to the current runtime, F11).
- `build-lean-native.sh` and `fastmachine/MachineDiag.lean` (no callers).
- The `OB_MUTATE_*` ifdefs in `runtime.c` (no callers).
- The unused 5 mutants.

**Policy question for the owner:** the whole C machine (`runtime.c`, `differential.py`, `cdiff*`, `Compiler/ObjectiveBendEmitC*.lean`, `ObjectiveBendCDiffGen.lean`, and gates `objective-c`/`objective-cgen`). The C machine is an undeployed twin, and the CI cost of `cgen` (1000 programs, two mutant sweeps) is paid on every push.

**Keep:**
- `packets.ts`, `Stress.obend`, `extra-cohort.json` and `fastmachine/{build.sh,MachineRun.lean}`, which `check-objective-machine-perf.sh` needs to guard the fast-machine regression.
- `transparency.py` and `activity-cohort.json`. They are the only executed check of the stored-checkpoint transparency contract and should be *wired into `GATES`*, not deleted.

---

## 7. Deployability on a small public Linux VM

**bend-ir2-proof is not deployable and not meant to be** ("not a world proof-admission endpoint", `README.md:3`; `main.rs:1`).
- **Build blockers on fresh Debian:** the missing `bend-proof-deps` (F1), the unreproducible root `Cargo.toml` pin (F2), and network access to `github.com/Plonky3/Plonky3` for the git dependencies. `--offline --locked` works only after `cargo fetch`, which `prime-cargo` skips for this crate.
- **Toolchain:** edition 2024 needs Rust ≥ 1.85.
- **Runtime:** a static CLI. It needs no privileges and no ports, and keeps no state beyond the files it is given. It does need `getrandom`, even to verify.
- **Hardware:** the README asks for "a leased, capped, warm build host", and R32's heavy test took 66–68 s on hbox. Dev profile builds of Plonky3 at 241K columns would be slow on a small VM.

**What "qualification" means here:** dated, lane-written records (r31/r32/r33, 2026-10-03). Each lists which Lean theorems exist, which native test passed (name and wall time on the pinned warm host), the exact Plonky3 revision and lock hash, and an explicit list of open obligations. Examples of those obligations: PCS verification ⇒ arithmetic acceptance; FRI/Merkle transcript hiding; Fiat–Shamir/QROM; "No 128-bit/PQ claim" (`R33:57-63`).

**Is the evidence reproducible on a fresh Linux box?** **No.**
1. The pinned breadstuffs slice cannot be reconstructed (F2).
2. The R32 heavy test and its Lean emitter are deleted (F3).
3. Fixtures with private 32-byte salt are deliberately unpublished (`R32:98-99`).

Only `quotient_masking` (no fixture) and `artifact_binding` would be re-runnable, and only once provisioning works. The fixture comes from hand-running `Host/BendTraceIR2Emit.lean`.

**objective-emit is not a service.** On a Linux build box it needs:
- elan/lake plus Mathlib (the full build, roughly 9,500 Lake jobs per `build.yml:7-8`);
- bun 1.3.11 (CI pins it by SHA, `build.yml:256-268`);
- cc (C11) and python3.

It writes only to the given work directories, apart from `fastmachine/build.sh`'s write into `.lake/` (F13). CI already runs `objective-c` and `objective-cgen` on hosted ubuntu, so that evidence *is* reproducible on Linux; the committed logs are not current (F11). The FASTMACHINE timings are hbox-specific and their logs are uncommitted. **Nothing here belongs on a public VM.**

---

## 8. Questions for the Lean side

1. **Does Lean own the ZK route that bend-ir2-proof serves, or is the route dead?** The Lean half (`ObjectiveBendZkClaims`, `BendCommitted*`, `BendQuotient*`, `BendMaskingDescent`) lives only in `ResearchWip`. Will it ever be retargeted at Selvage (`prover/`), or is the Plonky3/`dregg-circuit` stack retired, letting `native/bend-ir2-proof` and `native/bend-proof-entropy` be deleted?
2. **If the route is kept, which Lean definition owns the trace-mask budget?** That is `27 = ext_degree·2 + num_queries`, rounded to a 32-row capacity (`masking_budget.rs:9-12`). Today Rust derives it and no Lean declaration states it.
3. **If the route is kept, who emits the descriptor-binding domain?** That is `"DREGG"` / `"BEND.IR2.DESCRIPTOR-BYTES/v1"` and the V5 transcript framing order (`config.rs:37-45, 68-88`). It should be a Lean export, so that a future Lean-side descriptor pin and the Rust transcript cannot drift.
4. **Will `Compiler/ObjectiveBendEmitC.lean` emit the C tag, primitive, refusal and control enums as a header**, replacing the hand-kept `runtime.c:38-43`? Better still: is the simulation theorem from `OBJECTIVE-BEND-BACKENDS.md:16` (a model of the defunctionalized machine plus `R s r → R (stepRaw s) (stepRef r)`, then generating the switch) still planned? If it is not, should the C machine be retired now that csimp `stepRawFast` is within 2× of C?
5. **Should `objective-transparency` be a `local-gates` gate?** The proved `forcingTransparent_of_yieldedPlan` (`Kernel/ObjectiveResumeContract`) has its only executed cross-check outside CI.
6. **Can `forceReference` in `fastmachine/MachineRun.lean:29-37` be replaced by importing the specification `forceWith`** from a module that does not pull in the csimp lemmas? That would remove the hand copy (F14).
7. **Should the `objective-state.v1` codec state its decoder bounds** (maximum env length, record arity, label length) in Lean, so that any non-Lean decoder (today `runtime.c:505-594`) has a specified refusal for oversized lengths (F8)?
8. **Does a typed receiver for `dregg.objective-bend.core.v2` refuse terms like `fixtures/SharedEffect`** (an Activity in argument position) at the kernel boundary? Or is `perform_under_update_refused` at machine level the only defence?
