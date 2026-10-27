# Current AWS-LC object crypto component costs

Final-source refresh measured 2026-10-02 on Apple M2 Max, Mac14,5, 12 cores, 96 GiB RAM, Darwin arm64. Single-threaded release execution; bounded two-job offline build. These are in-process production-module costs, excluding native source admission, network delivery, encrypted custody/fsync and process startup. No protocol privacy or authority claim follows from them.

Each epoch configuration has ten raw samples. Device key generation and 1 KiB messages have 100 samples each. Wall timings use `Instant`; CPU timings use process user+system `getrusage` with microsecond OS resolution. One hybrid/message primitive warm-up precedes samples. CPU scheduling/frequency were not pinned. Summary JSON also includes mean, minimum, maximum and nearest-rank p95; for ten epoch samples p95 is the maximum.

| Operation | Devices | Median wall | Median CPU |
|---|---:|---:|---:|
| Device ML-KEM/X25519 keygen | 1 | 24.500 µs | 25.000 µs |
| Epoch issue | 1 | 0.199 ms | 0.201 ms |
| Epoch issue | 10 | 1.463 ms | 1.464 ms |
| Epoch issue | 100 | 13.530 ms | 13.507 ms |
| Receive one package from full manifest | 1 | 0.148 ms | 0.148 ms |
| Receive one package from full manifest | 10 | 0.277 ms | 0.278 ms |
| Receive one package from full manifest | 100 | 1.588 ms | 1.587 ms |
| Receive all packages sequentially | 1 | 0.149 ms | 0.149 ms |
| Receive all packages sequentially | 10 | 2.812 ms | 2.812 ms |
| Receive all packages sequentially | 100 | 158.657 ms | 158.446 ms |
| Seal 1 KiB message | — | 20.520 µs | 21.000 µs |
| Open 1 KiB message | — | 40.375 µs | 41.000 µs |

Epoch issue excludes device keygen. It includes a fresh epoch key, actual per-recipient ML-KEM/X25519 hybrid encapsulation/wrapping, key-commitment checks, hex/JSON encoding and Ed25519 manifest signature. Each receive verifies the full manifest hash/signature and exact canonical JSON, scans the complete package vector and unwraps the selected key. The all-device result is accumulated work on one process, not group delivery latency: each independently receiving endpoint would normally perform one receive. Repeated full-manifest parsing makes this sequential all-device work grow faster than issuance. An immutable authenticated-manifest parsing abstraction could reduce repeated work; no such optimization is included in these measurements.

| Devices | Complete signed manifest | Canonical roster binary | Binary wraps total | Hex wrap content | Hex roster content | Other JSON metadata/delimiters |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3,946 B | 145 B | 1,192 B | 2,384 B | 290 B | 1,200 B |
| 10 | 28,814 B | 811 B | 11,920 B | 23,840 B | 1,622 B | 3,280 B |
| 100 | 277,607 B | 7,487 B | 119,200 B | 238,400 B | 14,974 B | 24,161 B |

The complete manifest additionally includes 8-byte length framing and a 64-byte Ed25519 signature. Binary wraps are 1,192 bytes each, but the current canonical JSON manifest hex-encodes them to 2,384 content bytes each. It likewise retains hex-encoded canonical roster bytes. A 1,024-byte plaintext produces a 1,318-byte message frame (294-byte overhead). Recipient public keys are 1,184-byte ML-KEM plus 32-byte X25519; they are provisioned separately and are not repeated inside each signed package.

The portable explicitly invoked harness under `native/resource-client/benchmarks/object-components` imports current production `roomkey.rs`, `object_keys_hybrid.rs`, `object_messages.rs` and `private.rs` by relative path. Its independent Cargo manifest/lock does not alter production dependencies. It does not copy their cryptographic algorithms. AWS-LC is pinned at aws-lc-rs 1.18.1/non-fips, aws-lc-sys 0.45.0. Actual generated public-key commitments populate the canonical ordered roster; every entry uses the same catalog source `2000`, matching the supported single-catalog profile. The source-owned `Compiler.ObjectAudienceRoster.encode` produced its binary preimages through one serialized qualified Lean driver invocation; no Rust recreation of that codec or source commitment hash is used. The benchmark uses the actual audience/device commitments computed by that source codec; every measured sample matches the retained digest sidecars. Fixed-width authority/history/context labels remain synthetic, keeping the benchmark independent of a live admitted authority; these fixtures are not represented as an accepted object epoch. No private key or plaintext epoch key was written to a file.

Latest raw files are retained under `docs/evidence/2026-10-02-private-object-components/2026-10-02T09-24-final-source/`: `samples.json`, `pre-epoch-samples.json`, `summary.json`, `execution.json`, `SOURCE-MANIFEST.json` and `codec-provenance.json`. There are 230 raw samples. Execution embeds exact compile-time production/harness/dependency-lock and benchmark binary hashes. The source manifest compares the original measured pins with this final source; only `object_messages.rs` drifted, from `37ff3b4553795fbc5efc500c11f22b85263cd5b7ff9593e279624c4706dabdb6` to `5b4f4e44bacd9160aa0a05133ec186ea870f6d037a5c60ba17b615036d314c12`, through addition of the bounded historical context parser. That parser is not called by this benchmark, and the measured seal/open algorithms and v1 framing are unchanged. The ML-KEM provider, hybrid wrapper, private helper and epoch package module hashes are unchanged; the prior 64 complete-envelope provider interoperability cases were not repeated. All four compiled production hashes were checked against the frozen source again after the run. Summary records hardware/compiler and complete statistics; codec provenance records actual qualified source/OLean/signature, command and public input/output hashes. Native/custody revisions and the historical CLI route are outside these component timings.

## Reproduction

The portable harness, source encoder, local/remote encoding scripts and summarizer are retained at `native/resource-client/benchmarks/object-components`; its README contains complete commands. Build only that explicitly invoked standalone workspace with `--release --locked --offline --jobs 2` and an isolated warm target. Invoke its `mini-object-components` binary with the local source encoder, qualified source checkout and a NEW output directory. For a remote build lane, its wait script preserves the matching private keys in memory while the steward performs one serialized qualified source encoding invocation; the final marker is written after all binary/digest files and provenance have arrived. The source encode remains outside timed sections.

Run `python3 summarize.py [not in tree] NEW-OUTPUT-DIRECTORY` after completion. Only the explicitly invoked benchmark binary executes this work; no slow default test or production dependency was added. The final-source scoped release build passed in 45.95 seconds with two jobs; its build.log is retained inside the dated evidence directory. The source codec wait, including a pause of the owned waiting subprocess to preserve the same in-memory keys, occurred outside measured sections. Native end-to-end phase throughput and latency are a separate journey measurement.

The original multi-source synthetic fixture run remains intact in workbox `component-costs-20261002`, including its original REPORT.md and raw/provenance files. The first supported single-catalog/actual-digest run remains intact at the top level of `docs/evidence/2026-10-02-private-object-components`. This dated final-source run adds evidence without replacing either earlier raw run. Small manifest size differences between independently generated fixtures follow variable-length canonical Nat encodings of fresh random public-key commitments, doubled by their hex representation; they do not indicate a crypto framing change.
