# Bounded forward-link end-to-end benchmark

This benchmark intentionally preserves the deployed authority split instead
of inventing one native semantic controller.

`scripts/ForwardLinkSemanticBenchmark.lean` (schema v2) measures the actual
computable path on the deployed content cell
(`HyperdocumentCell.contentMaterializer`, one `StoreCodec` cell per document):

- canonical link-entry submission bytes;
- guarded-patch validity of the link allocation at the pre-store;
- validation, logical installation, and the Lean cSHAKE cell root;
- exact store-codec reopen; and
- canonical semantic link lookup.

The v1 stages `validate_insert`, `reopen_page_codec` and
`physical_page_route_query` measured the deleted four-slot page and are gone.

The native half (`forward_link_e2e_bench` over the two-file `LocalLinkStore`) went with
`native/hyperdocument-link-store` on 2026-10-26: that crate was the twin of the shipped
`native/hyperdocument-link-sqlite-store`, and it had not built since the root workspace
arrived (2026-10-08). Its committed logs here are history; the Store is measured by the
pipeline rows `births` and `perf` now.

Run the Lean surface with:

```sh
lake env lean --run scripts/ForwardLinkSemanticBenchmark.lean
```

It uses 31 measured samples, three warmups per stage, 16 repeated
operations for ordinary stages, and one operation for the cSHAKE-root stage.

## Interpretation ceiling

- `first_measured_after_warmup` is not a cold-cache measurement.
- Repeated samples are warm-process measurements only for the Lean executable;
  every native stage still pays child-process startup.
- Each native lifecycle uses a fresh directory, but OS page and filesystem
  caches are uncontrolled and are not flushed.
- Rust validates only the 4096-byte bound, same-byte retry, no-overwrite
  conflict, and exact returned bytes. It never parses a link or mints semantic
  acceptance.
- Successful `sync_all` and `hard_link` calls are observations, not proofs of
  POSIX semantics, stable media, power-loss survival, or adversarial-race
  safety.
- Lean timings do not include OS I/O, network delivery, credentials, external
  finality, UI rendering, or agent-runtime delivery.
- No per-stage memory number is reported: neither harness has a reliable,
  comparable allocator/RSS attribution for the selected stage boundary.
- Percentiles are nearest-rank order statistics over the raw measured samples;
  there is no performance threshold or throughput claim.
