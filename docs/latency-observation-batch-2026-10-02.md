# Coherent current observation batches

A batch lets a client read several resources against one admitted image, so
dependent reads (a room and its name index) stay consistent while unrelated
writers advance the world head.

The native batch (`Compiler/NativeObservationCodec`, `maxBatchReads` = 16) rides
authorized query (op 5) and carries 1 through 16 ordinary observation requests. It creates
all singleton challenges against one Opened image and answers all singleton
signed observations against one Opened image. Every element uses the existing
intent authentication, current exact invoked-grant admission and query projection.
A refused element discards the complete answer; partial results are never returned.
Input and output collections are bounded by `maxBatchBytes`, half the host frame
bound less a 256-byte reserve, so their canonical hex-JSON presentation fits the host frame. No singleton protocol
bytes or signatures change, and no authority survives beyond the current command.

Shared names bootstrap only an index candidate, then admit the room and candidate
index in one batch and recheck the current pointer. A changed pointer can replan
at most three times; unrelated world writes do not trigger dependency replanning.
Aliases share one coherent chain per room for a listing, with no cross-room head
requirement and no command-persistent memo.

Later reads of an opened name admit the room, index and exact pinned target in
one batch. They compare the current room pointer and the exact name/link/kind/target
or authenticated absence decision. A moved binding refuses, rather than retargeting.
They do not compare the old discovery world's global head to a later target head.
Current invoked scope and salted resource root verification remain mandatory.
Submission and exact recovery remain ordinary retained target-pinned bytes.

The same workspace signed_views helper returns existing singleton signed-envelope
paths for app readiness's current resource reads, preserving the ordinary
singleton observation predicates. Shared references expand into admitted
room/index guards deduplicated only by exact kind, target and invoked capability
inside this batch; each original binding is checked before returning its tuple.

Ephemeral shared reads track the real batch attempt and every created query source,
then clean their owned custody after recording the read journal. They create no
unused outer attempt and perform no redundant outer receipt-floor load.

The replan bound is `pair_loop` in `native/resource-client/src/shared_names.rs`. No batch
speedup is measured here.
