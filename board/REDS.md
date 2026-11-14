# Reds (owned by the builder, rewritten whole each round)

Tip: `74d6535141c7` (ratchet(bytes-repr): the ceiling is the measured count after the authority layout). Round finished 2026-11-14T23:26Z.
green: `053906870674`. Builder: hbox `/home/hbox/lanes/integ`, logs `/home/hbox/lanes/integ/builder`, gate `/home/hbox/lanes/integ/gate-74d65351`.

| stage | signature | reruns? | same place as last round? | owner | detail |
|---|---|---|---|---|---|
| umbrella-tree | running | - | yes | build-loop | the umbrellas have not finished; this file is rewritten when they do |

Suspect commits since green (`git log 053906870674..74d6535141c7`), newest first; owners are the seats whose
`Owns:` line (board/seats/*.md) names a path the commit touched:

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
- `76c7a979` private root: the empty node's digest is computed once and a node is hashed from the absorbed custom
- `705324d1` host: the trie bench names its layout and store
- `f26ea94a` host: `store-bench trie <n>` times one `set` of the kept private index and its parts
- `cc727d09` gate: j14-apps runs to `qualify` on every round and makes no model call (owner: apps-hermes, build-loop)
- `e9dc17f1` spk-host: an API `Destination` may be WebDAV's absolute path; an unprojectable dispatch is refused b (owner: apps-hermes, read-path)
- `f08fe6e5` journey KCH: the channel probe loads the kernel library; docs: what the registry line still owes (owner: apps-hermes)
- `03685404` effects: the stream append is bound at code 2; `Payload` has one constructor and the arm census is z (owner: apps-hermes, bytes-repr)
- `6031b01b` builder: REDS.md for 053906870674 (0 red) (owner: build-loop)

## Flatness (published, does not gate `green`)

| row | verdict | metric | early | late | ratio | bound | owner |
|---|---|---|---|---|---|---|---|
| flatness-submit | PASS | submit_cpu_ms | 0.161 | 0.182 | 1.126 | 1.590 | host-execution, store-retained |
| flatness-submit | FAIL | submit_wall_ms | 27.020 | 81.874 | 3.030 | 1.590 | host-execution, store-retained |
| flatness-submit | PASS | propose_cpu_ms | 0.130 | 0.165 | 1.267 | 1.590 | host-execution, store-retained |
| flatness-submit | FAIL | propose_wall_ms | 13.924 | 45.737 | 3.285 | 1.590 | host-execution, store-retained |
| flatness-get | PASS | get_cpu_ms | 0.365 | 0.335 | 0.917 | 1.856 | read-path |
| flatness-get | PASS | get_wall_ms | 406.999 | 127.603 | 0.314 | 1.856 | read-path |
| flatness-run | FAIL | no numbers: exit=1; /home/hbox/lanes/integ/gate-74d65351/flatness.log | - | - | - | - | host-execution, store-retained |
