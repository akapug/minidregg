# Current AWS-LC object crypto component costs

Corrected single-catalog run measured 2026-10-02 on Apple M2 Max, Mac14,5, 12 cores, 96 GiB RAM, Darwin arm64. Single-threaded release execution; bounded two-job offline build. These are in-process production-module costs, excluding native source admission, network delivery, encrypted custody/fsync and process startup. No protocol privacy or authority claim follows from them.

Each epoch configuration has ten raw samples. Device key generation and 1 KiB messages have 100 samples each. Wall timings use `Instant`; CPU timings use process user+system `getrusage` with microsecond OS resolution. One hybrid/message primitive warm-up precedes samples. CPU scheduling/frequency were not pinned. Summary JSON also includes mean, minimum, maximum and nearest-rank p95; for ten epoch samples p95 is the maximum.

| Operation | Devices | Median wall | Median CPU |
|---|---:|---:|---:|
| Device ML-KEM/X25519 keygen | 1 | 25.292 µs | 26 µs |
| Epoch issue | 1 | 0.185 ms | 0.185 ms |
| Epoch issue | 10 | 1.433 ms | 1.434 ms |
| Epoch issue | 100 | 13.406 ms | 13.370 ms |
| Receive one package from full manifest | 1 | 0.137 ms | 0.137 ms |
| Receive one package from full manifest | 10 | 0.268 ms | 0.270 ms |
| Receive one package from full manifest | 100 | 1.573 ms | 1.574 ms |
| Receive all packages sequentially | 1 | 0.137 ms | 0.137 ms |
| Receive all packages sequentially | 10 | 2.722 ms | 2.719 ms |
| Receive all packages sequentially | 100 | 156.907 ms | 156.782 ms |
| Seal 1 KiB message | — | 21.000 µs | 21 µs |
| Open 1 KiB message | — | 41.459 µs | 42 µs |

Epoch issue excludes device keygen. It includes a fresh epoch key, actual per-recipient ML-KEM/X25519 hybrid encapsulation/wrapping, key-commitment checks, hex/JSON encoding and Ed25519 manifest signature. Each receive verifies the full manifest hash/signature and exact canonical JSON, scans the complete package vector and unwraps the selected key. The all-device result is accumulated work on one process, not group delivery latency: each independently receiving endpoint would normally perform one receive. Repeated full-manifest parsing makes this sequential all-device work grow faster than issuance. An immutable authenticated-manifest parsing abstraction could reduce repeated work; no such optimization is included in these measurements.

| Devices | Complete signed manifest | Canonical roster binary | Binary wraps total | Hex wrap content | Hex roster content | Other JSON metadata/delimiters |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3,942 B | 143 B | 1,192 B | 2,384 B | 286 B | 1,200 B |
| 10 | 28,814 B | 811 B | 11,920 B | 23,840 B | 1,622 B | 3,280 B |
| 100 | 277,619 B | 7,493 B | 119,200 B | 238,400 B | 14,986 B | 24,161 B |

The complete manifest additionally includes 8-byte length framing and a 64-byte Ed25519 signature. Binary wraps are 1,192 bytes each, but the current canonical JSON manifest hex-encodes them to 2,384 content bytes each. It likewise retains hex-encoded canonical roster bytes. A 1,024-byte plaintext produces a 1,318-byte message frame (294-byte overhead). Recipient public keys are 1,184-byte ML-KEM plus 32-byte X25519; they are provisioned separately and are not repeated inside each signed package.

The portable explicitly invoked harness under `native/resource-client/benchmarks/object-components` imports current production `roomkey.rs`, `object_keys_hybrid.rs`, `object_messages.rs` and `private.rs` by relative path. Its independent Cargo manifest/lock does not alter production dependencies. It does not copy their cryptographic algorithms. AWS-LC is pinned at aws-lc-rs 1.18.1/non-fips, aws-lc-sys 0.45.0. Actual generated public-key commitments populate the canonical ordered roster; every entry uses the same catalog source `2000`, matching the supported single-catalog profile. The source-owned `Compiler.ObjectAudienceRoster.encode` produced its binary preimages through one serialized qualified Lean driver invocation; no Rust recreation of that codec or source commitment hash is used. The benchmark uses the actual audience/device commitments computed by that source codec; every measured sample matches the retained digest sidecars. Fixed-width authority/history/context labels remain synthetic, keeping the benchmark independent of a live admitted authority; these fixtures are not represented as an accepted object epoch. No private key or plaintext epoch key was written to a file.

Raw files: `component-costs-singlecatalog-20261002/samples.json`, `pre-epoch-samples.json`, `summary.json`, `execution.json`, and `codec-provenance.json`. Execution records exact compile-time source, benchmark binary and dependency-lock SHA256 hashes and sample counts; summary records compiler/hardware. All production source hashes still match the measured snapshot. Codec provenance records the actual qualified remote source/OLean/import signature, encoder driver hash, invocation and public input/output hashes. The canonical source module hash is `cf2420ce84f5ae5ca11d31f3fc5a1c25580c245cd14f0998d8db60ce7df99e34`.

## Reproduction

The portable harness, source encoder, local/remote encoding scripts and summarizer are retained at `native/resource-client/benchmarks/object-components`; its README contains complete commands. Build only that explicitly invoked standalone workspace with `--release --locked --offline --jobs 2` and an isolated warm target. Invoke its `mini-object-components` binary with the local source encoder, qualified source checkout and a NEW output directory. For a remote build lane, its wait script preserves the matching private keys in memory while the steward performs one serialized qualified source encoding invocation; the final marker is written after all binary/digest files and provenance have arrived. The source encode remains outside timed sections.

Run `python3 summarize.py [not in tree] NEW-OUTPUT-DIRECTORY` after completion. Only the explicitly invoked benchmark binary executes this work; no slow default test or production dependency was added. The corrected scoped build log is `component-costs-portable-build.log`. Native end-to-end phase throughput and latency are a separate journey measurement.

The original multi-source synthetic fixture run remains intact in `component-costs-20261002`, including its original REPORT.md and all raw/provenance files. It was not an admitted source fixture; this corrected report uses one catalog source and actual source digest bindings. The 8-byte difference between old/new 100-device manifests follows the four-byte difference in fresh random canonical roster encoding, hex-retained in the manifest, rather than a crypto framing change.
