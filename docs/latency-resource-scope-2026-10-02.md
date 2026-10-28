# Shared discovery in one admitted observation

A `resource-scope` read returns the invoked grant's scope and the narrowed resource in one
signed observation. Without it, resolving one room name takes four signed observation
handshakes (scope and resource for both the room and its index), and a reference listing
repeats that pair for every alias in the room.

## Contract

The `resource-scope` query uses the ordinary authenticated observation receiver and one current resource-local admission. Its reply contains only the invoked grant's kind, identifier and field coverage alongside the already narrowed resource. Both projections come from the same admitted authority/resource context. It does not introduce a client-supplied scope, another authority database, or an authority cache across actions. The client still verifies the narrowed resource's salted root opening before using the reply.

Existing query-view tags 0/1 and resource-view bytes are unchanged. The new query-view tag is 2, with a separate `RESOURCE-SCOPE-VIEW/v1` result frame. Byte and codec lemmas retain the old resource/capability observations needed by saved preparation and exact recovery.

`shared_names::discovery_read` performs one signed handshake per target. `refs` retains admitted discovery reads only while assembling that one listing, keyed by room discovery chain, kind, target, invoked capability and required field. Room/index reads within each chain must share a world root/height; independent rooms may resolve at different heads. Repeated aliases reuse their chain's immutable request snapshot. Any later target read or write still meets its own current admission and shared-name snapshot binding.

Observation admission also consumes its already resolved `PreparedLaw.admit` through the existing complete-result equality theorem. The original refusal, evidence, current-source and axiom-guard statements remain unchanged.

## Tests

Rust shared-name tests cover explicit full/narrowed coverage, wrong grant identity, missing scope metadata, moved snapshots, revoked discovery, request-local reuse, independent room chains with different heads, authenticated absence and exact retained recovery. Lean covers the query bytes, scope-view codec roundtrip, same-admitted-grant projection and the existing observation admission proofs. No latency saving is measured here.
