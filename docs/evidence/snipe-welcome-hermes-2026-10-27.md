# snipe-welcome-hermes: welcomecontinuity + hermes

One shared root, both rows: the enrollment `seal` step is red on the candidate the ledger last
ran. Most probable window: main 07:56–08:54 (pin `6ef778450` landed, seal's plan-file fix
`ed595f2c` not yet) — every seal failed instantly ("enrollment Plan inspection changed before
signing"). Fits every entry: welcome 6 s = setup + instant fail; hermes 14 s = bootstrap+birth+
witness+plan then `set -e` exits via the trap, so the ledger saw only "services stopped";
m3/m4-J1/m8/fleetsign same-step reds fit identically. Client seal path cut7→HEAD checked
commit-by-commit (O40 constants by value, pair framing bounds-only, strict hex on Host-produced
sites only): semantics-preserving; fix already merged at cut 6, enrol-resume-acceptance green at
cut 7 incl. pinned seal across ticks. Fix landed here: `hermes-journey.sh` now names each
friend-enrollment step (`fail` + evidence into `$EV`) — the defect that made the red unactionable.
Ran (Mac, `target-mac`): filtered enrollment unit tests 14/14; `bash -n` + `shellcheck -S error`
on both drivers, `genesis.sh`, `newparticipant-acceptance.sh`: clean; hermes genesis-enrollment
JSON replayed through genesis.sh's jq validators (with the fixture's publicKey fill): passes.
Owed (needs a built candidate world — none exists): `JR welcomecontinuity`, `JR hermes` on a
≥cut-6 candidate; any remaining red's byte is `$OUT/logs/enrollment-seal.err` (welcome) or
`$EV/friend-seal.stderr` (hermes). If the ledger's runs were cut-14-era instead, suspect a fresh
host-side regression (`107f040d9` open v4, `bc88a5aba` frame v8, `a468ccad0` rate gate) — the
same re-run discriminates; cut 12's enrol-resume (pre-v8) cannot. No Lean files touched.
