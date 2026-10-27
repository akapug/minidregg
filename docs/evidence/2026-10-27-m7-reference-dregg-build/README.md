# M7 reference for a0db11f8, built cold on dregg-build (2026-10-27)

M7 (`native/resource-client/journey.d/m7.sh`) requires a second, independent build of the candidate's commit.
Its full output SHA-256 map must equal the candidate's. This directory records that reference build for
`a0db11f8a8bcbc99b5a35ced44f46ab9717ee51d`, what reproduced, what did not, and why. It also records the first clean
cold-build timing of the 787-module Host closure.

## The two builds

| | candidate C | reference R |
|---|---|---|
| box | hbox (Ubuntu, 24 CPU, co-tenant) | dregg-build (Hetzner ccx33, Debian 13, 8 vCPU / 32 GB, SSD) |
| route | `deploy/candidate/lane-build.sh host/consent/rust/pack` in a warm-base lane | `deploy/candidate/build.sh --source-archive` from `git archive a0db11f8`, cold |
| Lean | warm replay (0 modules compiled) | all 787 modules compiled, shared Lake artifact cache off (`LAKE_ARTIFACT_CACHE=false`, empty `LAKE_CACHE_DIR`) |
| rustc | 1.98.0-nightly (8b6558a02 2026-06-20), LLVM 22.1.7 | the same |
| linker in the Rust ELFs | rust-lld 22.1.7 | the same |
| system GCC (crt/libgcc objects) | `GCC: (Ubuntu 14.2.0-4ubuntu2) 14.2.0` | `GCC: (Debian 14.2.0-19) 14.2.0` |
| source tree | `9acac41434a84432bba607018f1e90575c3bb72a` | the same |
| SHA256SUMS sha256 | `adfbfe56428f997b…` | `03393378110c74bd…` |

## Cold build timings (R, dregg-build, box otherwise nearly idle, load 3 to 7)

Seats 2 x Lean threads 2 (`build-native-host.sh` defaults under the box's 28G `swarm-build` cap), C jobs 8, cargo jobs 8.

| stage | wall |
|---|---|
| Lean packages + mathlib cache (`lake exe cache get`) | 81 s |
| Lean closure: 787 modules, every one compiled (`lean-closure 787 modules PASS`) | 4726 s (78.8 min) |
| native Host total (Lean closure + C objects + link) | 5212 s |
| consent companion (reuses the Host's modules, 13 compiled) | 436 s |
| Rust roles (19 binaries) | 195 s |
| **total `build.sh`** | **5926 s (98.8 min)** |

- Peak cgroup RSS of the whole build: 19.3 GiB (20,238,766,080 bytes).
- Per-module `lean-rss`: p50 3.7 GiB, p95 4.0 GiB, max 18.5 GiB (`Kernel.PayEnrolReceiver`; `Kernel.PayEnrolV2Receiver` 18.4 GiB).
- Longest single module: `Compiler.DurableIndex` at 285 s, 12.9 GiB. Next are `Compiler.Evaluator` (206 s) and `Kernel.Job` (202 s).
- Comparison: an hbox attempt of the same build at seats 4 x threads 2 reached 309 of 787 modules in 2 h 18 min under co-tenant
  load 55 to 87 and was stopped. Box load decides this number; a co-tenant box does not give a comparable one.

Two things went wrong on the way. (a) The first try failed in `lake exe cache get` on a transient GitHub clone error
(`quote4`: "could not read Username"), and the retry succeeded. (b) `package.py` refused with "source tree unavailable:
package in a repository containing the archive commit". `--source-archive` implies that no checkout is needed, but
`package.py` ran `git rev-parse COMMIT^{tree}` in its working directory. The packaging line was re-run from a clone
that holds the commit. The same branch as this README fixes the trap: `package.py` now derives the tree from the
archive's own files (equal to `a0db11f8^{tree}` on this archive). Where a repository holds the commit, it cross-checks
that tree and refuses an archive that is not `git archive COMMIT`.

## Reproduction: output SHA-256, C against R (23 shipped paths)

| path | C | R | |
|---|---|---|---|
| `bin/clients/x86_64-unknown-linux-gnu/mini` | `ee17b9c7dcc1123e` | `cf26904b049e18d2` | differs |
| `bin/clients/x86_64-unknown-linux-gnu/minidregg-client-consent` | `1ce338424630443c` | `1ce338424630443c` | same |
| `bin/clients/x86_64-unknown-linux-gnu/minidregg-credential-signature-verifier` | `8fb9640ef2a9f27b` | `6919177684a71d92` | differs |
| `bin/clients/x86_64-unknown-linux-gnu/minidregg-host` | `e2f5da1ee055c794` | `e2f5da1ee055c794` | same |
| `bin/clients/x86_64-unknown-linux-gnu/minidregg-link-sqlite-store` | `1f31416a1cc20b95` | `42dc8102944492ef` | differs |
| `bin/grain-provider-bridge` | `baaa5c6ca66bb737` | `a30d61587f6638fc` | differs |
| `bin/grain-runtime` | `70c0c5fa6fc664c0` | `54958d31e286f7fc` | differs |
| `bin/launch-gate` | `d93c0a0c8f3807a0` | `770762b0ef43ac9d` | differs |
| `bin/mini` | `ee17b9c7dcc1123e` | `cf26904b049e18d2` | differs |
| `bin/mini-discord` | `d946ec381d69972c` | `32ec6c5d6694a247` | differs |
| `bin/mini-hermes-test-provider` | `de899bc1ee5782d4` | `00a37cb35bff2af9` | differs |
| `bin/mini-inference-scheduler` | `26ac46cdf707e80d` | `7d8a0ab0e94da997` | differs |
| `bin/mini-keys` | `afba74e22decbc8e` | `4588ce5929dac935` | differs |
| `bin/mini-spk-broker` | `54f1b116b6d8b6fc` | `f1ebcfcfedc81597` | differs |
| `bin/mini-spk-volume-helper` | `a11e1718039726ce` | `6c0b5ff87ebb6069` | differs |
| `bin/minidregg-client-consent` | `1ce338424630443c` | `1ce338424630443c` | same |
| `bin/minidregg-credential-signature-verifier` | `8fb9640ef2a9f27b` | `6919177684a71d92` | differs |
| `bin/minidregg-host` | `e2f5da1ee055c794` | `e2f5da1ee055c794` | same |
| `bin/minidregg-link-sqlite-store` | `1f31416a1cc20b95` | `42dc8102944492ef` | differs |
| `bin/pay-watcher` | `0fee30befb365eb9` | `fb1e65b3ef1e15e2` | differs |
| `bin/spk-browser-proxy` | `b92bec882c919ab5` | `8d143db50c8d3d37` | differs |
| `bin/spk-host` | `28655fabcab868ed` | `24c9f09994bb6a55` | differs |
| `bin/spk-hostd` | `92b0cb8d5c36592d` | `ff4c5e51c6c33006` | differs |

**Same:** the Lean-built `minidregg-host` and `minidregg-client-consent` (4 paths, counting their friend-bundle copies).
**Different:** all 19 Rust binaries (21 paths). Of M7's four core roles, `host` reproduces and `mini`, `store` and
`verifier` do not: **1 of 4**. `m7.sh` step 3 compares the complete output map, so M7 against this reference is
**FAIL** ("candidate outputs do not reproduce"). The row was not run, because the table above already decides it.

## Why the Rust outputs differ

`readelf -p .comment` on `minidregg-credential-signature-verifier`:

```
C (hbox):         Linker: LLD 22.1.7 (…ec9ab9d68bf7…) | rustc version 1.98.0-nightly (8b6558a02 2026-06-20) | GCC: (Ubuntu 14.2.0-4ubuntu2) 14.2.0
R (dregg-build):  Linker: LLD 22.1.7 (…ec9ab9d68bf7…) | GCC: (Debian 14.2.0-19) 14.2.0 | rustc version 1.98.0-nightly (8b6558a02 2026-06-20)
```

The binaries come out at 685,320 bytes (C) and 685,144 bytes (R). Rust links against the host distribution's C
startup objects and libgcc (`crt1.o`, `crti.o`, `crtbegin.o`, …). Those objects differ between Ubuntu's and Debian's
GCC 14.2 builds, and they carry their own `.comment` stamp. The Lean Host is byte-identical across the two
distributions because Lean links with its own bundled toolchain and sysroot.

## Consequence (ruling, 2026-10-27)

The demo box runs Debian 13, so from round 2 on the shipped candidate is built on Debian 13 (dregg-build), and M7's
reference is a second Debian 13 box (`dregg-ref`, same provisioning), not hbox. Making the Rust link independent of
the distribution (Rust's self-contained crt or a pinned sysroot, as Lean bundles its toolchain) is a Phase 3 item.

## Where the artifacts are (both boxes die 2026-11-11)

- R: `dregg-build:/build/reference/a0db11f8/` (`provenance.json`, `manifest.json`, `SHA256SUMS`, `logs/`,
  `work/host-build/{build.log,manifest.txt,lean-module-rss.tsv}`); driver `dregg-build:/build/cand-a0db11f8/run-reference.sh`.
- C: `hbox:/tank/dregg-build/claude-candidate-20261026/C/`; report `docs/review/2026-10-26-deploy/HBOX-CANDIDATE-a0db11f8.md`.
