# Reds (owned by the builder, rewritten whole each round)

Tip: `053906870674` (builder: REDS.md for 6594960dd02a (0 red)). Round finished 2026-11-14T21:19Z.
green: `6594960dd02a`. Builder: hbox `/home/hbox/lanes/integ`, logs `/home/hbox/lanes/integ/builder`, gate `/home/hbox/lanes/integ/gate-05390687`.

No reds: `green` moves to `053906870674`.

## Flatness (published, does not gate `green`)

| row | verdict | metric | early | late | ratio | bound | owner |
|---|---|---|---|---|---|---|---|
| flatness-submit | PASS | submit_cpu_ms | 0.162 | 0.221 | 1.363 | 1.590 | host-execution, store-retained |
| flatness-submit | FAIL | submit_wall_ms | 24.891 | 63.830 | 2.564 | 1.590 | host-execution, store-retained |
| flatness-submit | PASS | propose_cpu_ms | 0.152 | 0.205 | 1.351 | 1.590 | host-execution, store-retained |
| flatness-submit | FAIL | propose_wall_ms | 31.565 | 78.153 | 2.476 | 1.590 | host-execution, store-retained |
| flatness-get | PASS | get_cpu_ms | 0.557 | 0.479 | 0.860 | 1.856 | read-path |
| flatness-get | PASS | get_wall_ms | 274.599 | 329.386 | 1.200 | 1.856 | read-path |
| flatness-run | FAIL | no numbers: exit=1; /home/hbox/lanes/integ/gate-05390687/flatness.log | - | - | - | - | host-execution, store-retained |
