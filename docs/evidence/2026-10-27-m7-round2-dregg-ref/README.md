# M7 round 2: 45f45d15 reproduces across two Debian 13 boxes (2026-10-27)

This is the project's first M7 PASS across two machines. The integrator's candidate for
`45f45d1517389a907cd34e18663ec62925d8aa2d` was built on dregg-build. An independent cold build of the same commit was
made on dregg-ref. All 26 shipped outputs have identical SHA-256, and the `m7` journey row passes.

## The row

`scripts/pipeline/journey-runner --tip 45f45d15… --row m7 --source-tree <extract of the candidate's source.tar>`
(the tree's own runner; its self-check passed). It ran on dregg-build against the candidate, with
`MINI_M7_REFERENCE=/build/candidates/45f45d15-reference-dregg-ref/provenance.json`:

```
m7	PASS	14	M7: candidate 45f45d151738 reproduces 45f45d151738 built in another directory (all output SHA-256, identical compiled inputs, tamper refused); run.sh served its own Store
```

`m7-result.json` `.checks`, all six required by `journey-rows` `row_m7`: `sha256sums`, `journey-runs-candidate-binaries`,
`no-tmp-inputs`, `reproduces-all-outputs`, `tamper-init-and-serve-refuse`, `run.sh-init-start-sponsor-stop`.

## The two builds

| | candidate | reference |
|---|---|---|
| box | dregg-build (Hetzner ccx33, Debian 13) | dregg-ref (Hetzner ccx33, Debian 13, provisioned the same way; toolchains byte-matched: rustc 8b6558a02, Lean 4.30.0 d024af09, glibc 2.41, gcc 14.2.0-19) |
| built by | the integrator (round 2) | this lane: `deploy/candidate/build.sh --source-archive` from `git archive 45f45d15`, shared Lake cache off, run in an extracted tree with no repository |
| provenance | `dregg-build:/build/candidates/45f45d1517389a907cd34e18663ec62925d8aa2d/provenance.json` | built at `dregg-ref:/build/reference/45f45d15/provenance.json`, copied (without `work/`) to `dregg-build:/build/candidates/45f45d15-reference-dregg-ref/provenance.json`, manifest paths relocated as `check-tamper.sh` does |
| source tree | `835ea80de6deb8994fb90b5a58f5af0743843c2e` | the same |
| SHA256SUMS sha256 | `fc1111ed3a098d4b9ea7f62fea8ab79770576aa44f92d24cbcc44dcaa4292cf9` | `703029f647b43343c2b49c7f25acf00f9c0ea7536a2e3da8caa300b5815b6eca` (also covers `provenance.json`, which records build paths and timings; M7 compares the output map) |

The reference build also exercised c851d8c4. `package.py` packaged the extracted tree by deriving the source tree from
the archive, where the a0db11f8 reference had needed a repository.

## Output SHA-256, candidate against reference (26 paths)

| path | sha256 (candidate = reference) | |
|---|---|---|
| `bin/clients/x86_64-unknown-linux-gnu/mini` | `9db5758f50587e3eb9df18a904094717974a4ddce750e1077fd103ef58c0d650` | same |
| `bin/clients/x86_64-unknown-linux-gnu/minidregg-client-consent` | `1e4269843dcecbc3494d527a047fd6a4b6a991190089a51a2395f443180df45e` | same |
| `bin/clients/x86_64-unknown-linux-gnu/minidregg-credential-signature-verifier` | `93774037602dde3dd975576c3ca6230cc877c4a963a28bb68e677848021e0f51` | same |
| `bin/clients/x86_64-unknown-linux-gnu/minidregg-host` | `b2c86d80a148305c7c7e19515b6f100f56ab9a8de858fa3c424f58a067927eed` | same |
| `bin/clients/x86_64-unknown-linux-gnu/minidregg-link-sqlite-store` | `a094087be7a32b40f299d47a2ced2e23581d18fbd2be9d47759583af40e77206` | same |
| `bin/grain-provider-bridge` | `86588430bcbe6ee699fa00e7247bb13e795af2fd2dd4730f1b37c045bbf0eb9f` | same |
| `bin/grain-runtime` | `b5582c52211bb48b303d80625880d9e4f0fbc99ef433e5dd6310138152e5dbb8` | same |
| `bin/launch-gate` | `7412d039df9d7f46cedcabb1bc33dba1e63e9a347337e3cd6b402f90075b452d` | same |
| `bin/mini` | `9db5758f50587e3eb9df18a904094717974a4ddce750e1077fd103ef58c0d650` | same |
| `bin/mini-discord` | `cacedb04a5c46dea6d8d4ff27b7491662e1fbad86fbe97286a869f99bcd887bb` | same |
| `bin/mini-discord-mirror` | `2d03f125e4b0c6498858e9a0fe5d87df6bfcdfe0a7f7a1068cf6a77bf3cb31f7` | same |
| `bin/mini-door` | `451f357810e1233ef7dc416a7c06ecb2b0f472ace02cbea7306bb54a55c710d6` | same |
| `bin/mini-door-process` | `1361dd1e5222b48646286339dc05a06e41e38305cf0838db21d9ec77c31214c2` | same |
| `bin/mini-inference-scheduler` | `7d8a0ab0e94da99714e37e8a1036a27a48fb1e94414ec115edf44b45b9fd5adc` | same |
| `bin/mini-keys` | `ba93167f1cd4294ebe0f053f401838c729991ed9758dc2d5c595e7a870277785` | same |
| `bin/mini-spk-broker` | `76aec2dad5557bfb1b1305c12550c203246980422cfdc116b6bbd96828e109e1` | same |
| `bin/mini-spk-volume-helper` | `9d8529713ccaef01457252e29095238ede7b0b09eebdb980cdc46234068b3e1f` | same |
| `bin/mini-web` | `e9908c0537a7aeb36a4731e742d53b8135112c9dc2e2d07d76b0223390a2cef6` | same |
| `bin/mini-web-spawn` | `1d271dea96117490d19992c0e4248604df1f20cb6522544e2b839881bd2d5bd1` | same |
| `bin/minidregg-client-consent` | `1e4269843dcecbc3494d527a047fd6a4b6a991190089a51a2395f443180df45e` | same |
| `bin/minidregg-credential-signature-verifier` | `93774037602dde3dd975576c3ca6230cc877c4a963a28bb68e677848021e0f51` | same |
| `bin/minidregg-host` | `b2c86d80a148305c7c7e19515b6f100f56ab9a8de858fa3c424f58a067927eed` | same |
| `bin/minidregg-link-sqlite-store` | `a094087be7a32b40f299d47a2ced2e23581d18fbd2be9d47759583af40e77206` | same |
| `bin/pay-watcher` | `a7fdb8f56ca7665847667ef990d0077665df91d1617fe1a674fdc041afeb5a63` | same |
| `bin/spk-browser-proxy` | `0b1b3979ee96951ae417ced0474c6ee53caee54c2d32cc304b085d5c0fdea426` | same |
| `bin/spk-host` | `c619bf56b966d95163cebeabfde3204829f6ebc1ffeab67605f7ddfaf57d251f` | same |

All four of M7's core roles (`host`, `mini`, `store`, `verifier`) reproduce, and so does every other output.

## Cold-build timings

Both builds are `build.sh` from a `git archive`, with the shared Lake artifact cache off. Both ran on a ccx33
(8 vCPU / 32 GB) under `swarm-build` (28G cap), with the builder defaults: 2 Lean seats x 2 Lean threads,
memory-weighted from `scripts/pipeline/lean-module-rss.tsv`.

| stage | a0db11f8 on dregg-build | 45f45d15 on dregg-ref |
|---|---|---|
| Lean packages + mathlib cache | 81 s | 108 s |
| Lean closure | 787 modules, all compiled: 4726 s (78.8 min) | 790 modules, 785 compiled: 2148 s (35.8 min) |
| native Host total | 5212 s | 2574 s |
| consent companion | 436 s | 306 s |
| Rust roles | 195 s | 187 s |
| **total** | **5926 s (98.8 min)** | **3177 s (53.0 min)** |
| box | another lane's `lake build Minidregg` and `Host.Main` running for the first ~40 min (load 3 to 7) | idle (load about 2) |
| seat weighting | 784 modules weighted from the table; unrecorded modules take both seats | 1311 modules weighted |

The causes of the 2.2x difference were not isolated. At a0db11f8 the RSS table already weighted 784 of the 787
compiled modules, so at most three modules took both seats. The sharing on dregg-build is the more plausible cause.
The longest single modules are the same in both builds: `Compiler.DurableIndex` (285 s, then 188 s), `Kernel.Job`
(202 s, then 196 s), `Compiler.Evaluator` (206 s, then 171 s).

**Peak memory.** Per-module `lean-rss` is the same in both: p50 3.7 GiB, p95 4.0 GiB, max 18.5 GiB
(`Kernel.PayEnrolReceiver`; `Kernel.PayEnrolV2Receiver` 18.4 GiB). The `swarm-build` cgroup `memory.peak` was 19.3 GiB
for a0db11f8 and 28.0 GiB for 45f45d15. The second figure equals the 28G cap, and cgroup `memory.peak` counts page
cache, so it is an upper bound and not the build's working set. The largest single Lean process is the measured
18.5 GiB.

## Ruling (2026-10-27)

The demo box runs Debian 13, so the shipped candidate is built on Debian 13 (dregg-build), and M7's reference is a
second Debian 13 box (dregg-ref). The cross-distribution attempt (a0db11f8, hbox Ubuntu against dregg-build Debian,
`docs/evidence/2026-10-27-m7-reference-dregg-build/`) reproduced only the Lean outputs. Rust links against the
distribution's GCC startup objects. Making the Rust link independent of the distribution (Rust's self-contained crt
or a pinned sysroot, as Lean bundles its toolchain) is a Phase 3 item.

## Where the artifacts are (both boxes die 2026-11-11)

- reference build with its evidence (`logs/`, `work/host-build/{build.log,manifest.txt,lean-module-rss.tsv}`):
  `dregg-ref:/build/reference/45f45d15/`; its driver is `dregg-ref:/build/cand-r2/run-reference.sh`.
- reference beside the candidate: `dregg-build:/build/candidates/45f45d15-reference-dregg-ref/`.
- m7 row run: `dregg-build:/build/cand-m7r2/` (`run-m7.sh`, `m7.log`, `journeys/45f45d15…/rows/m7/`).
