# Reds (owned by the builder, rewritten whole each round)

Tip: `07eeb91a239d` (holder: the invariant of the held index rows, stated and proved; the hand-over only for an). Round finished 2026-11-15T03:32Z.
green: `053906870674`. Builder: hbox `/home/hbox/lanes/integ`, logs `/home/hbox/lanes/integ/builder`, gate `/home/hbox/lanes/integ/gate-07eeb91a`.

| stage | signature | reruns? | same place as last round? | owner | detail |
|---|---|---|---|---|---|
| umbrella-tree | running | - | yes | build-loop | the umbrellas have not finished; this file is rewritten when they do |

Suspect commits since green (`git log 053906870674..07eeb91a239d`), newest first; owners are the seats whose
`Owns:` line (board/seats/*.md) names a path the commit touched:

- `07eeb91a` holder: the invariant of the held index rows, stated and proved; the hand-over only for an installed
- `ef8e5a8c` receiver: an append hands the index rows it wrote to the holder; the holder is keyed by Store root
- `39689195` builder: REDS.md for 9ac0425a6f14 (1 red) (owner: build-loop)
- `9ac0425a` ratchet(bytes-repr): 5056, the index rows compiled twins repeat existing list types (owner: bytes-repr)
- `346b2d1a` docs(append-growth): the index after its compiled half; what the root still costs; the holder hand-o
- `539bc23c` index: the journal index's compiled half, by `@[csimp]` equalities to the stated definitions
- `61a6d4ff` builder: REDS.md for f264ccfdc2bc (1 red) (owner: build-loop)
- `f264ccfd` ratchet(bytes-repr): 5033, one binder of the private index node type (owner: bytes-repr)
- `3fbeca33` docs(append-growth): the product row as its own section; what compiled outside the umbrella; what is
- `362c2f8d` docs: what an append costs as history grows, measured and attributed
- `c0f71943` directory: `used` is the set's characteristic function; the private index evaluates a path once (owner: apps-hermes, read-path)
- `bd134ef4` receiver: `MINI_STORE_PHASES=1` prints where one durable append spends its time
- `c6081864` builder: REDS.md for 74d6535141c7 (1 red) (owner: build-loop)
- `74d65351` ratchet(bytes-repr): the ceiling is the measured count after the authority layout (owner: bytes-repr)
- `6b6c219d` docs(authority): the sixteen authority-writing journeys on this head
- `f21515be` docs(authority): the trie cost found and cut, the step and hand-off numbers, what ran on this head; 
- `2a95c410` fixtures: the accepted Objective call and the document write are re-recorded on the hashed-bits-firs
- `ec974928` private root: a kind with one class keys its index by the hashed address bits first
- `cd25aff2` journeys: JROT and K10C expect the refusal as the client renders it (owner: apps-hermes)
- `ac3ae025` docs(authority): the next steps, in order
- `60aa6c5b` authority: `first_write_covered`, who judges a cell's first write; the step cost is attributed to th
- `bf351a6b` host: `store-bench` times the parts of a served step alone
- `c5971f58` docs(authority): which base each validation ran on
- `45ae85ba` docs(authority): the layout doc states what was validated, the measured step cost and what is owed
- `9fb3ca81` fixtures: the accepted Objective call and the document write are re-recorded on the cell layout
- `1b4fdd3a` authority: an authority entry's first write is no birth for the naming check; the flatness row print (owner: apps-hermes)
- `ea25a8d9` authority: the thin birth statement names the update (whole `lake build Minidregg` green; the two na
- `57a83646` authority: `stepAffected` names its policy type (RED: `Kernel.NativeHostServed` and above unbuilt)
- `cf3940e5` authority: hand-off boundary (RED: `Kernel.NativeHostContext` and every module above it)
- `7e403698` authority: sourcing-step proofs, the foreign-writer pole, the design doc rewritten (RED: whole build (owner: apps-hermes)
- `6e2a3e08` authority: sealed loads and unsealed reads; incremental policy sourcing; the old layout refused by n
- `00472ddf` authority: the writer families, the gate, the issuer locator and the at-height read over the cell la (owner: apps-hermes, read-path)
- `0da76e68` authority: `Loaded`, the served authority and `Ground.authorityWrites` over the cell layout (RED: th
- `a42ac3b1` authority: the registry's `.authority` kind is the cell layout (RED: every module downstream of the  (owner: apps-hermes, read-path)
- `1f691b75` authority: `BirthAuthorityWritesBounded` is proved over the lowering
- `e2cbffb6` authority: the layout's refinement is proved; the design is rewritten as present state
- `f4651f6a` authority: the physical layout's foundation, `Compiler.CredentialAuthorityLayout` (work in progress,
- `537ce49f` builder: REDS.md for e837e57358a4 (2 red) (owner: build-loop)
- `e837e573` builder: REDS.md for cc727d09d078 (1 red) (owner: build-loop)
- `ee1f6899` pipeline: `lane-journey` tears down the world it runs; `lane-candidates prune` keeps a lane's newest

## Flatness (published, does not gate `green`)

| row | verdict | metric | early | late | ratio | bound | owner |
|---|---|---|---|---|---|---|---|
| flatness-submit | PASS | submit_cpu_ms | 0.310 | 0.217 | 0.700 | 1.849 | host-execution, store-retained |
| flatness-submit | FAIL | submit_wall_ms | 53.620 | 120.097 | 2.240 | 1.849 | host-execution, store-retained |
| flatness-submit | PASS | propose_cpu_ms | 0.271 | 0.221 | 0.815 | 1.849 | host-execution, store-retained |
| flatness-submit | FAIL | propose_wall_ms | 36.817 | 120.923 | 3.284 | 1.849 | host-execution, store-retained |
| flatness-get | PASS | get_cpu_ms | 0.472 | 0.316 | 0.671 | 1.856 | read-path |
| flatness-get | PASS | get_wall_ms | 171.701 | 132.853 | 0.774 | 1.856 | read-path |
| flatness-run | FAIL | no numbers: exit=1; /home/hbox/lanes/integ/gate-07eeb91a/flatness.log | - | - | - | - | host-execution, store-retained |
