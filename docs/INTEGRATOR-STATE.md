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

## Main and candidates (2026-10-30 ~02:10 EDT)

Main = staging = 994e36d08 (+ this doc): hot-path codex 0b38d35a0, export TLS 69251145d/6b1c05490, spk-host export
status 6570674fa, infra's connector seed 552a316e7 and publish fix 27c274052, spk-fresh to 85d6b1798 (Forgejo,
reveal.js, MediaWiki, Mercurial, Wekan, Scrumblr, Swagger Editor, Sudoku, Blockstack, Kiwix, Navidrome), 19-pin fixture.

| candidate | verdict |
|---|---|
| a9d4ec9ba | tour 73/73; composed all but connector PASS (sheet never seeded); flatness GET PASS, submit FAIL (4.97x wall, 9.27x CPU vs 2x) |
| 91a307e70 | tour 73/73; connector past capture, red at publish (no 27c274052); its flatness ran to completion unattended |
| 994e36d08 | THE CANDIDATE. tour 73/73; composed rooms/churn/documents/apps/connector/store-restart PASS on hbox AND on infra's forge composed container; residents refused by design in sponsor mode ("owner, resident, provider witness and every request author must be distinct principals"), restart blocked behind it. Flatness pending (gate-994e36d0) |

Not shipped: ember's rule is rehearse only on a fully green gate. Residents/restart need JWORLD_MANAGEMENT=distinct,
which dies in apps at application-birth "no-grant ... (phase prepare)" (distinct births must be signed by owner 7 with 8
as owner/manager, scripts/workroom/provision.sh:151-154,292). Infra (add189844d158e3a7) took that item 02:08; it holds
994e36d08 staged for `demo-mini.sh ship` (dry run) until then. flatness-submit is ember's call (law 17).

gate10: `[HARNESS=<sha>] EDGE_REV=69c17a3 JWORLD_MANAGEMENT=sponsor KEEP_WORLD=1 PORT=.. JWORLD_ROUTE_FRONT_PORT=.. bash
gate10.sh SHA` (mode 644). Down a kept world with the candidate's scripts/spk-platform/world-down.sh RUN/inputs, then
dregg-infra-69c17a3/edge/mini/journey/jworld-scratch.sh down RUN/w (as hbox with XDG_RUNTIME_DIR/DBUS); log DOWN. No
world is kept up now. Forge composed container: on hbox `/home/hbox/lanes/infra/composed-sync CAND_DIR [EDGE]`, then
`ssh composed-box 'JWORLD_MANAGEMENT=sponsor /ci/composed-gate SRC8 CAND12 [TAG]'` (about 6 min).

## The connector red: two causes, both fixed

1. spk-browser-proxy is TLS 1.3 + X25519MLKEM768 only; the export shelled out to /usr/bin/curl (OpenSSL < 3.5 has no
   hybrid group). 69251145d/6b1c05490: the export runs on rustls/aws-lc-rs in the client (Kimi-reviewed; overflow,
   deadline and framing fixes taken).
2. Sheet jd3 was never written, so EtherCalc answered 404 and the entrance 503. Infra's 552a316e7 seeds it
   (connector:sheet step); 27c274052 makes publish print one JSON document. Connector PASS on 994e36d08.

## Market packages for the demo box

dregg-forge:/var/lib/spk-fresh/qualified-2026-10-29/out/{local.json,adopt.tsv}: 19 packages; files under
../apps/<app>/out/<app>.spk; earlier outs kept as out.prev-N (session-made, removable). Regenerate: link or copy the
package into apps/<app>/out/<app>.spk (spk-fresh's forge copies live under /srv/spk-build/<app>/out/), move out aside,
`python3 -I repo/deploy/market/fresh-index.py --apps $Q/apps --recipes $Q/repo/apps/packages --spk-tool
/var/lib/spk-fresh/tools/spk --out $Q/out`, copy local.json to native/resource-client/tests/fixtures/
fresh-local-index-2026-10-29.json, run `cargo test --bin mini -- apps::tests` (24). FEATURED still upstream: WBO
rhtntjye (wbo.json names upstream), r8y55acm, zxent02j, uws252ya. SPK-fresh (a58fcf100f4438710): Firefly III qualifying next.

## In flight

- Codex apps-agents (cx-aa) still running (worktree /Users/ember/dev/minidregg-lanes/apps-agents; land via
  target/*-commit.sh when it finishes).
- Infra (add189844d158e3a7): distinct-mode births (for residents/restart); 994e36d08 staged for the ship.

## Reds

- Flatness submit (law 17): submit wall 4.97x, propose CPU 9.27x over 1000 ops (bound 2x); GET PASS. The hot-path
  codex batch is landed; its HOT-PATH-STATE.md names the remaining costs (cold-start snapshots, persistent whole-cell
  writes). No lane is on it now; a hot-path successor starts from docs/HOT-PATH-STATE.md.
- Composed: residents (sponsor-mode refusal by design) and restart, pending distinct-mode births (infra).
- Umbrellas: Fixtures.NativeAcceptedFixture, NativeDocWriteFixture, BirthPlanPoles, Effects.Revival.EngineProofs.
- OwnTracks username normalization; Hummingbird native conversation qualification.

## Not landed / held

cx-oracle dd80466a1 and codex/oracle-v7-qualification b32f15604 (conflict; wait for oracle7); statement-fixes (WIP);
qualify-doc-contention (WIP).

## Next steps

1. Read 994e36d08's flatness line; when infra sends the distinct-birth sha, land it, rebuild, gate in distinct mode
   (hbox and composed-box); a fully green gate (flatness aside, per ember) goes to infra for the ship.
2. Land cx-aa when it finishes; Firefly's pin when spk-fresh sends it.

## Hygiene done 2026-10-29

/var/lib/mini-spk-worlds emptied through install-user-world remove (each logged in COMMANDS.log); my old rpool tree
/othersys/lanes/integ removed. Rules: named-file commits with `git commit -F`; never `git add -A` or `git stash`;
filtered tests; PID files; stop only by PID file; lake/git on hbox as hbox; disk pressure = stop and tell ember.
