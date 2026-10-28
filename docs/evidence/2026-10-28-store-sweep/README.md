# First generic store sweep — 2026-10-28

Candidate: `aae3e2e372b045dd43493183144db08212d51659`, selected from the newest READY
candidate at launch and verified to contain `76758dba6`. Its immutable binaries ran on hbox.
The captured public index contains 98 apps. Three seven-app worlds plus an earlier Simple
Todos smoke judged **22 apps: 20 PASS, 2 FAIL**. PASS means install → share → start → enrol
→ authenticated GET `/` returned HTTP 2xx/3xx. No app-specific requests or writes ran.

[Every verdict](verdicts.tsv) includes the exact package, candidate, stage, import profile,
reason, timestamp and private hbox evidence path. The same records are shipped in
[`store-qualification.json`](../../../deploy/market/store-qualification.json).

The two failures are Laverna at start (runtime ViewInfo declares a write permission without
a signed bridge schema) and Telescope Nova at install (native ingest timed out after
171.240 seconds). These are this run's results, not claims about all candidates or environments.
ShareLaTeX initially hit the standard decoder's 512-segment ceiling despite fitting its byte
limits. The generic native preflight now detects its 809 segments in the world's protected
intake, selects `market-large-v1` consistently for grain and broker before any app exists,
and the retry passed installation, start, enrol and GET `/` (HTTP 303). Previous FAIL records
remain archived under `records/history/`; no app-specific exception or limit increase was added.

Private evidence root on hbox:
`/tank/lanes/cx-store-sweep/out/aae3e2e372b045dd43493183144db08212d51659`.
Full worlds: `b.CVGlu9`, `b.yABybn`, `b.G6JAlT`; smoke: `b.1aT84m`;
corrected-profile retry: `b.LOGrID`. Each world retains its actual driver and binary pins.
Raw journey evidence may contain credentials and is not committed.

## Continue the remaining 76 apps

Run as `mini-operator` on hbox from the installer-authorized source tree. This uses the
recorded full index and existing judgments; omit `--dry-run` to run its 11 remaining worlds.
Use a detached job with a PID file and `box-wait`. The driver acquires the shared world lock
for each whole world, tears it down, stops its own residents, then removes its staging.

```sh
D=/tank/lanes/cx-store-sweep
SHA=aae3e2e372b045dd43493183144db08212d51659
T=/tank/dregg-build/claude-lanes/cx-store-sweep/src
export MINI_OPERATOR_UID=1001 MINI_OPERATOR_NAME=mini-operator
"$T/scripts/spk-platform/store-sweep.sh" --candidate "$D/candidates/$SHA" \
  --out "$D/out" --staging "$D/s" --index "$D/out/$SHA/market/index.json" --dry-run
```

The default (without `--index`) refreshes the public index. Resume skips both PASS and FAIL
for the same candidate/package; explicit `--retry-stage` archives selected failures first.
Use a different candidate directory/output namespace to qualify a newer candidate.

## Focused verification

- Linux: all 10 `test-store-sweep.py` tests passed, including batching, verdict publication,
  scoped resume/retry, profile selection, broker/grain parity, and teardown recovery.
- Warm dregg-ref Rust: `cargo nextest run -p minidregg-resource-client -E
  'test(apps_store_sweep) | test(apps_search)'` passed 3 tests; 1044 skipped.
- Fault-injected checks rejected an eighth batch slot, stale package verdict inheritance,
  silent probe custody failure, inconsistent broker/grain profiles, and unscoped retries.
  Corrected implementations passed. Shellcheck passed for the sweep and profile helpers.
- Warm compiled CLI: embedded and explicit-file search JSON matched for all 98 entries
  (20 known working, 2 lifecycle failures, 76 not swept); search text and show JSON passed.
  Local ingest verdicts remained unverified. Logs: dregg-ref
  `/build/lanes/cx-store-sweep/{final-filtered,final-test}.log`.
- Resume dry-run skipped all 22 judged packages and planned 76 apps in 11 worlds.
- Every completed sweep world reported `removal_assertions=0`; its root and registry are
  absent. Own staging is empty and no process names an own sweep world path.
