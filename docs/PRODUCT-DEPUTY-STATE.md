# Product deputy state (present state, rewritten whole; 2026-10-27 evening)

Six product items brought forward to HEAD. One worktree per item under
`/Users/ember/dev/minidregg-lanes/pd-<item>`, branch `lane/pd-<item>`. Since c44b7d5be (ember) lanes
neither build nor validate: they push reasoned changes and the integrator validates main
centrally. Rows below say which checks ran before that rule.

| item | branch tip | state |
|---|---|---|
| 1 invite reserve + codes | lane/pd-invite 567e8db7b | done; filtered tests green on the Mac before the rule; infra wiring routed |
| 2 per-subject Host rate | lane/pd-host-rate 9f9bac798 | Host arm (the allocation-gate red fixed: ratedClaims no longer carries a `| 130 =>` arm), `rateLimited` (tag 16), outcome v7, client rendering pushed, reasoned; RefusalReason, NativeProtocolFrames, NativeHostCodec elaborated per file before the rule |
| 3 web3.js → solpay.js | lane/pd-web3 e4f3904cf | done; Wallet Standard only, paste fallback (decided) |
| 4 grain class slices | lane/pd-grain-class 577208316 | done; infra drop-ins routed |
| 5 private-compute door | lane/pd-private-compute a5b6cb6b6 | done; `mini-private-compute` in the artifact set routed |
| 6 in-system feedback | lane/pd-feedback 776756637 | verb, `reports`, web links, Discord `/feedback`; per-member `feedback-NAME` rooms; the 10-a-day limit STOPPED (new law shape) |

## Owed
- Integrator, item 2: run `scripts/codec-shapes-regen.py` (the v7 frame's pin still carries the v6
  fingerprint; any identity nesting RefusalReason moves too); the whole tree builds once.
- Item 2 next steps: rate the submit families (2, 46, 76, 26: their dispatchers return the verified
  subject); a journey row with `requestRate.limit` 3; publish the rate on the laws page (op 0).
- Infra, item 2: the Host config gains
  `"requestRate": {"limit": 300, "windowMs": 60000, "exempt": [OPERATOR_SUBJECT, SPONSOR_SUBJECT]}`.
- Item 6 decision: the day limit needs a windowed counter in the room law and a refusal name
  (`feedbackDayLimit`). Poles: the 10th report in a day is admitted, the 11th is refused, and the
  next day's first is admitted. The stream head holds only `count` and `tail` today.
- Item 6 infra: per-member enrolment lines `chat new feedback-NAME` and
  `chat invite feedback-NAME SUBJ NAME` (operator), then `chat join feedback {invitation}` (member).
  The relay polls `mini shell --line "reports --since LASTH --digest"`. `MINI_BUILD_SHA` or
  `MINI_CANDIDATE_SHA` must be set for the candidate sha. Re-register `deploy/discord/commands.json`.

Not ours: lane/un-*, L1 platform cell, hot-path, L13 app market, the web lane's per-member cap, L2 shell.
