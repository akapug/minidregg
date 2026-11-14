# Reds (owned by the builder, rewritten whole each round)

Tip: `e837e57358a4` (builder: REDS.md for cc727d09d078 (1 red)). Round finished 2026-11-14T22:39Z.
green: `053906870674`. Builder: hbox `/home/hbox/lanes/integ`, logs `/home/hbox/lanes/integ/builder`, gate `/home/hbox/lanes/integ/gate-e837e573`.

| stage | signature | reruns? | same place as last round? | owner | detail |
|---|---|---|---|---|---|
| ratchets | rc=1 see /home/hbox/lanes/integ/logs/ratchets.log | - | no | suspects' owners | /home/hbox/lanes/integ/logs/ratchets.log |
| umbrella-tree | running | - | yes | build-loop | the umbrellas have not finished; this file is rewritten when they do |

Suspect commits since green (`git log 053906870674..e837e57358a4`), newest first; owners are the seats whose
`Owns:` line (board/seats/*.md) names a path the commit touched:

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
| flatness-submit | PASS | submit_cpu_ms | 0.171 | 0.196 | 1.142 | 1.590 | host-execution, store-retained |
| flatness-submit | FAIL | submit_wall_ms | 31.838 | 80.180 | 2.518 | 1.590 | host-execution, store-retained |
| flatness-submit | PASS | propose_cpu_ms | 0.150 | 0.188 | 1.253 | 1.590 | host-execution, store-retained |
| flatness-submit | FAIL | propose_wall_ms | 18.842 | 65.197 | 3.460 | 1.590 | host-execution, store-retained |
| flatness-get | PASS | get_cpu_ms | 0.576 | 0.625 | 1.086 | 1.856 | read-path |
| flatness-get | PASS | get_wall_ms | 184.672 | 247.201 | 1.339 | 1.856 | read-path |
| flatness-run | FAIL | no numbers: exit=1; /home/hbox/lanes/integ/gate-e837e573/flatness.log | - | - | - | - | host-execution, store-retained |
