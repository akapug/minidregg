# Reds (owned by the builder, rewritten whole each round)

Tip: `cc727d09d078` (gate: j14-apps runs to `qualify` on every round and makes no model call). Round finished 2026-11-14T22:10Z.
green: `053906870674`. Builder: hbox `/home/hbox/lanes/integ`, logs `/home/hbox/lanes/integ/builder`, gate `/home/hbox/lanes/integ/gate-cc727d09`.

| stage | signature | reruns? | same place as last round? | owner | detail |
|---|---|---|---|---|---|
| umbrella-tree | running | - | no | build-loop | the umbrellas have not finished; this file is rewritten when they do |

Suspect commits since green (`git log 053906870674..cc727d09d078`), newest first; owners are the seats whose
`Owns:` line (board/seats/*.md) names a path the commit touched:

- `cc727d09` gate: j14-apps runs to `qualify` on every round and makes no model call (owner: apps-hermes, build-loop)
- `e9dc17f1` spk-host: an API `Destination` may be WebDAV's absolute path; an unprojectable dispatch is refused b (owner: apps-hermes, read-path)
- `f08fe6e5` journey KCH: the channel probe loads the kernel library; docs: what the registry line still owes (owner: apps-hermes)
- `03685404` effects: the stream append is bound at code 2; `Payload` has one constructor and the arm census is z (owner: apps-hermes, bytes-repr)
- `6031b01b` builder: REDS.md for 053906870674 (0 red) (owner: build-loop)

## Flatness (published, does not gate `green`)

| row | verdict | metric | early | late | ratio | bound | owner |
|---|---|---|---|---|---|---|---|
| flatness-submit | PASS | submit_cpu_ms | 0.251 | 0.224 | 0.894 | 1.590 | host-execution, store-retained |
| flatness-submit | PASS | submit_wall_ms | 92.250 | 100.802 | 1.093 | 1.590 | host-execution, store-retained |
| flatness-submit | PASS | propose_cpu_ms | 0.267 | 0.249 | 0.934 | 1.590 | host-execution, store-retained |
| flatness-submit | FAIL | propose_wall_ms | 26.176 | 75.236 | 2.874 | 1.590 | host-execution, store-retained |
| flatness-get | PASS | get_cpu_ms | 0.515 | 0.430 | 0.836 | 1.856 | read-path |
| flatness-get | PASS | get_wall_ms | 175.211 | 181.493 | 1.036 | 1.856 | read-path |
| flatness-run | FAIL | no numbers: exit=1; /home/hbox/lanes/integ/gate-cc727d09/flatness.log | - | - | - | - | host-execution, store-retained |
