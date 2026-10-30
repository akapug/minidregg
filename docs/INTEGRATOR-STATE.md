# Integrator state

Present-state record of the integration lane, rewritten whole when its shape changes. A successor reads this,
then `hbox:/home/hbox/lanes/integ/COMMANDS.log` (every build stage, gate verdict and tidy act, one line each).
dregg-build and dregg-ref were deleted 2026-10-28; their history is in this file's git history.

## Shape

One integrator (Opus). Kimi (`claude-kimi -p`, read-only) reviews a batch of landings every few plus anything big or
risky. Kimi cannot read the session scratchpad: put a patch inline in the prompt (keep it under ~60 KB) or ask it to
read repo paths. Lanes push branches and send shas; the integrator merges into `integration/staging` on the Mac,
builds staging's tip on hbox, moves main to it once its host stage is green, gates, reports. No codec pins/census.
Statements may be rephrased, never weakened. ATLAS law 17: never slower over time (flatness bench = the one perf
gate; hot-path sends it, wire it into the gate).

## Where things are

- Mac landing worktree `/Users/ember/dev/minidregg-lanes/integration-r2` (branch `integ/main` = staging, pushed to
  `origin/integration/staging`); a scratch worktree of main at the session scratchpad `integ2/wt-main`.
  Mac checks: `CARGO_TARGET_DIR=/Users/ember/dev/minidregg-lanes/target-integ`, filtered `cargo test --bin mini -- apps::`
  etc. (the apps_front connector test fails only inside the group).
- hbox tree `/home/hbox/lanes/integ/src` (NVMe `/`; rpool/othersys is not ours). Build `integ-build2.sh SHA`
  (pid file integ/build.pid): rust-check, host, consent, umbrellas (non-fatal), rust, pack -> `integ/candidates/<sha>/READY`.
  Run with `SEATS=4 MEM=40G`; keep combined Lean caps on hbox near 60 GB so ~30 GB stays for test worlds, and stagger
  host stages with the hot-path lane (a9bba0bc5f114fc06). Incremental build 6-10 min; a deep StoreCodec change ~40-60 min.
- Gate `integ/gate9.sh SHA` (newest; never edit a script in place, number the next one). Env: PHASES ("tour composed
  enrol"), SUF, HARNESS (overlay scripts/ + resource-client scripts + journey.d from a sha), EDGE_REV=69c17a3 (dregg-infra
  tree integ/dregg-infra-<rev>), PORT and JWORLD_ROUTE_FRONT_PORT unique per concurrent run, JWORLD_MANAGEMENT=sponsor
  (distinct breaks app births; see reds), JWORLD_ROOT_HANDOFFS=1 default, TOUR_FROM, KEEP_WORLD=1 (leave the composed world
  up; the log line says how to take it down). Results integ/gate-<sha8><SUF>/; runs under /ci. Playwright
  /tank/dregg-build/rows-0ce31391/pw/node_modules (browsers ~/.cache/ms-playwright). Infra also offers `ssh composed-box`
  (a container on dregg-forge) for composed if hbox root setup gets crowded; not used yet.

## Main and candidates (2026-10-30, after ember's flight)

Main 8fd079de2 (gated: tour 73/73, composed connector red, flatness absent from harness). Staging
(`integration/staging`) 3b7d6c9b2 = main + hot-path codex 0b38d35a0 (persistent receipt index, flat-cell preimage
proof, flatness-gate.sh; merge 7f6666525) + the export TLS fix 69251145d + spk-fresh c668c5e2f (MediaWiki, Mercurial,
Wekan, Scrumblr, Swagger Editor; merge 247a22c6a) + 15-pin fixture 3b7d6c9b2.

| candidate | verdict |
|---|---|
| 8cb74aba5 | tour 70/73 (rate-limit reds, fixed by demo-path 1200/min), composed connector red |
| c4264f9cb | tour 73/73; composed rooms/churn/documents/apps/store-restart PASS, connector red; flatness absent |
| ebaeb14c7 | export diagnostic build (curl exit + http status) |
| 8fd079de2 | MAIN. tour 73/73; connector red diagnosed: curl exit 35 / NoKxGroupsInCommon (kept world taken down 00:39) |
| 7f6666525 | BUILDING since 00:23 (deep: hot-path StoreCodec, 796-module closure, SEATS=4 MEM=40G; pid integ/build.pid) |

Next build: staging tip 3b7d6c9b2 (Rust-only over 7f6666525), then gate10 (`EDGE_REV=69c17a3 JWORLD_MANAGEMENT=sponsor
bash gate10.sh SHA`, unique PORT/JWORLD_ROUTE_FRONT_PORT; gate10.sh is mode 644). The hot-path batch brings
scripts/perf/flatness-gate.sh, so flatness runs for the first time; codex measured GET PASS (1.54x CPU) and submit
FAIL (9.59x CPU against a 2x bound), so expect flatness-submit red (law 17; hot-path owns the remaining submit
costs: cold-start snapshots, persistent whole-cell writes, see docs/HOT-PATH-STATE.md).

## The connector red, and its fix

spk-browser-proxy serves TLS 1.3 with X25519MLKEM768 only (db8abb598). The app-document export shelled out to
/usr/bin/curl, so it could only reach the entrance where the machine's OpenSSL is at least 3.5. hbox has 3.3.1; the
demo container on forge has 3.5.7. 69251145d moves the fetch onto rustls/aws-lc-rs in the client (hybrid group first,
same bounds; resource-client's rustls feature ring -> aws_lc_rs, lock unchanged). Mac filtered: app_document 15/15,
worker:: 14/14. Kimi review running (scratchpad integ2/kimi-export.md).

## Market packages for the demo box

dregg-forge:/var/lib/spk-fresh/qualified-2026-10-29/out/{local.json,adopt.tsv}: 15 packages (Datasette, Davros,
DokuWiki, EtherCalc, Etherpad, Forgejo, HedgeDoc, Hledger, MediaWiki, Mercurial, ntfy, reveal.js, Scrumblr, Swagger
Editor, Wekan); files under ../apps/<app>/out/<app>.spk. Regenerate by adding apps/<app>/out/<app>.spk and rerunning
`python3 -I repo/deploy/market/fresh-index.py --apps $Q/apps --recipes $Q/repo/apps/packages --spk-tool
/var/lib/spk-fresh/tools/spk --out $Q/out` (move the old out aside), then copy local.json to
native/resource-client/tests/fixtures/fresh-local-index-2026-10-29.json and run apps::tests.
FEATURED still on upstream ids: WBO rhtntjye (wbo.json names upstream), r8y55acm, zxent02j, uws252ya (no declarations).
SPK-fresh (a58fcf100f4438710) continues: Kiwix, Navidrome, Sudoku, Blockstack, Firefly.

## In flight

- Codex apps-agents (cx-aa) still running (worktree /Users/ember/dev/minidregg-lanes/apps-agents; land via its
  target/*-commit.sh when it finishes). Demo-path and hot-path codex batches are landed.
- Infra (add189844d158e3a7) has c4264f9cb as the last READY handed over; send it the next green-or-best candidate.

## Reds

- Composed connector: fixed by 69251145d, unproven until the next gate (residents and restart run after it).
- Flatness submit (law 17), as above.
- Umbrellas: Fixtures.NativeAcceptedFixture, NativeDocWriteFixture, BirthPlanPoles (re-records), Effects.Revival
  EngineProofs:45 materialize_logical.
- OwnTracks package username normalization; Hummingbird native conversation qualification (demo-path).
- apps_front connector unit test fails only inside the apps:: group on the Mac (known).

## Not landed / held

cx-oracle dd80466a1 and codex/oracle-v7-qualification b32f15604 (conflict with main; wait for the oracle7 batch);
statement-fixes (WIP); qualify-doc-contention (WIP).

## Next steps

1. 7f6666525 host green -> build 3b7d6c9b2 -> move main -> gate10 -> hand infra the candidate with the verdict.
2. If connector passes, read residents/restart; if flatness-submit is the only red, say so to infra and ember.
3. Land cx-aa; keep the fixture current with spk-fresh's shas.

## Hygiene done 2026-10-29

/var/lib/mini-spk-worlds emptied through install-user-world remove (each logged in COMMANDS.log); my old rpool tree
/othersys/lanes/integ removed. Rules: named-file commits with `git commit -F`; never `git add -A` or `git stash`;
filtered tests; PID files; stop only by PID file; lake/git on hbox as hbox; disk pressure = stop and tell ember.
