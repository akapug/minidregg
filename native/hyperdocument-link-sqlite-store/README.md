# hyperdocument-link-sqlite-store: the Store helper

The physical transport under the Lean Host's durable Store: the SQLite
`durable_log` with its MAC'd checkpoints, the history accumulator nodes, the fn
archive journal, the legacy one-slot link record, and the sibling head anchor
(`MINIANC2`) that refuses a rolled-back or replaced database. It stores opaque
bytes: Lean owns every meaning (chain, tags, checkpoints, replay).

The operator contract (files, schema 5, the kept-checkpoint policy, verbs and
exit codes, the anchor and how to back it up, enrollment) is
`docs/DURABLE-STORE.md`. Read it before backing up or moving a Store: a backup
without `STORE.head-anchor` restores to a Store that refuses.

It links the system `libsqlite3` through a hand-written FFI and depends on
`sha2` and `libc`. On Linux workers that ship only `libsqlite3.so.0`, `build.rs`
creates a private linker alias in `OUT_DIR`; it does not bundle or modify
SQLite.

The production binary `minidregg-link-sqlite-store` (`src/main.rs`) exposes the
durable, journal, legacy-record, `durable-anchor-enroll`, `database-path` and
`serve` verbs listed in `docs/DURABLE-STORE.md`, and no crash or hold verb. The
crash and hold fixtures are a separate binary,
`minidregg-link-sqlite-store-fixtures`, built only with `--features fixtures`
for the Lean probe `scripts/durable-receiver.lean`; it is never part of a
candidate. The lifecycle tests
(`tests/lifecycle.rs`, `tests/durable_anchor.rs`) run those fixtures from the
test binary itself (`tests/support`), killed at each publication boundary, and
reopen, retry and tamper against the real helper.
