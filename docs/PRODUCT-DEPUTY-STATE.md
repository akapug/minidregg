# Product deputy state (present state, rewritten whole; 2026-10-27)

Five product items brought forward to HEAD (ember, 2026-10-27: no rehearsal this sprint; the next
rehearsal tests a converged sprint). One worktree per item under
`/Users/ember/dev/minidregg-lanes/pd-<item>`, branch `lane/pd-<item>` from origin/main; each
reviewed by the deputy (its filtered tests re-run on the Mac where Mac-runnable).

| item | branch tip | state | the test that goes red (planted fault) |
|---|---|---|---|
| 1 invite reserve + codes | lane/pd-invite 567e8db7b | ready for the cut; infra wiring owed | `invite_reserve_holds_twenty_of_fifty_seats_for_codes`: dropping the reserve subtraction admits m31 |
| 2 per-subject Host rate | lane/pd-host-rate 45fe7a5e8 | statement only (`Kernel/SubjectRate.lean`, `docs/PD-HOST-RATE-DESIGN.md`); STOPPED for the `rateLimited` constructor (outcome v7, StoreEpoch move: flag-day) and the defaults | `<`→`≤` in `check` reds `check_at_limit`, `check_retry_admits`, `witness_run` |
| 3 web3.js → solpay.js | lane/pd-web3 e4f3904cf | ready for the cut; real-wallet pass owed | TransferChecked tag 12→13 reds `pay-serializer.test.mjs` (live and golden) |
| 4 grain class slices | lane/pd-grain-class 577208316 | ready for the cut; infra drop-ins owed | all-L mapping reds `broker::tests::grain_class_slices_nest_by_class` (dregg-build) |
| 5 private-compute door | lane/pd-private-compute a5b6cb6b6 | ready for the cut; `mini-private-compute` in the artifact set owed | input leaked into the transcript reds `demo::tests::…names_no_input`; `JPRIVATE_PLANT=leak` reds jprivate |

## Owed outside these lanes
- infra (`edge/mini/templates/door.json`): `"inviteReserve": 20`, `"inviteCodes": "/etc/mini/invite-codes"`;
  `install -o root -g root -m 0600 <codes> /etc/mini/invite-codes` (lines `SERIAL CODE`).
- infra: `/etc/systemd/user/s<store>-mini-grains-{S,M,L}-.slice.d/60-demo-cpu.conf` with `CPUQuota=` 25/50/100 %;
  the existing `mini-grain-.service.d` prefix matches only Hermes units, never SPK grains (`mini-spk-s…-a…-g….service`).
- artifact set: `cargo build --release --features demo --bin mini-private-compute` in native/private-backend.
- decisions: item 2's constructor and defaults; whether wallets without Wallet Standard may fall back to the paste path.

Not ours: lane/un-* (untouched-areas deputy), L1 platform cell, hot-path, L13 app market, web
lane's per-member cap, L2 shell.
