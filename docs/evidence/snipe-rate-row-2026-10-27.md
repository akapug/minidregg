# snipe-rate-row — per-subject request rate row (lane/snipe-rate-row @ 3e0b59b9c)

- Row `rate` registered in `scripts/pipeline/journey-rows` (`# world:` genesis): driver
  `native/resource-client/rate-journey.sh` — genesis `requestRate {limit 3, windowMs 20000, exempt [7]}`
  through scenario-genesis.sh, subjects 8/9 enrolled as application-acceptance.sh enrols them, one
  `mini serve` (PID file, stopped by that PID). Nine sub-rows: pinned-config, admitted-1..3, refused-4th
  (`rate-limited` + `retry in N s (phase op 5)` under NO_RECORD, N bounded by the window), other-subject,
  sponsor-exempt (5 reads past the limit), after-window.
- jfeedback checked line-by-line against chat.rs/shell.rs/RefusalReason.lean: body sound (holder check →
  `no-grant`; reports/tail rendering, invite/join/ref shapes, petname loop all match). Its header was
  JCHAT's copy (five friends, mirror, latency) and required a phantom `JFEEDBACK_DISCORD_DIR`; header
  rewritten to the built surface, ROWS-OWED cells fixed for both rows.
- Ran on the Mac (read + shell only, once per batch): exact refusal line vs `main.rs refusal_line`; the jq
  overlay on the real `genesis-params.example.json` under genesis.sh's own `check_request_rate`; the
  sed/grep seconds extraction; the awk row-count guard — which caught its own n==8 vs the driver's 9
  (fixed, re-verified). `sh -n`/`bash -n`/`shellcheck` clean.
- NOT run: the rows themselves (no built candidate world). Exact commands when one exists:
  `JR rate` and `JS "JFEEDBACK"`.
