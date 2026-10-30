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

## Main and candidates (2026-10-30 ~03:05 EDT)

Main = staging = 21a117df3 (= 41590f420 binaries + harness: infra df0ea4252 room-operations, 21a117df3 root hand-offs; 5f18b9f50 reverted): everything below plus lane/apps-agents 06e6c30eb (native paid planner Lean, controller-world,
grain-runtime, spk-host, j14-apps green on hbox run 25), infra's residents fixes e365dd7e6 (current-height births,
owner keeps its factory capability) and c3d17f136 (chat join for a member the roster already names), Firefly III, and
the 20-pin fixture.

| candidate | verdict |
|---|---|
| 994e36d08 | tour 73/73; composed all PASS except residents (sponsor-mode refusal) and restart; flatness GET PASS, submit FAIL (7.79x CPU, 5.08x wall vs 2x) |
| 0feb2b026 | distinct mode: tour 73/73; composed residents red at the room join (fixed by c3d17f136); j14-apps red: broker-world-up refuses a group-writable output ancestor (integ/ is 775), fixed in gate12 by rooting j14 under /ci |
| 41590f420 | THE CANDIDATE. gate12 distinct: tour 73/73, j14-apps PASS (5 rows), composed rooms/churn/documents/apps/connector/store-restart PASS; residents stops at summon: the Hermes account birth refused PreparationReject.resourceBatch (batch admission, ResourceBirthController.lean:789); restart blocked |
| 5f18b9f50 | infra's dedup of source capabilities: RED (kernel pairs capabilities 1:1 with operations, NativeHost.lean:353; scratch world could not provision). Reverted on main as aa5a80b2a |

Composed authority is infra's forge composed container (hbox has no root: residents needs a root custody chain, a key
broker, a certifier). On it, distinct composed on 41590f420 reaches residents phase `cut` (balance read of the Hermes
account that the tool workspace never imported); infra (add189844d158e3a7) is doing that import, then sends candidate +
HARNESS rev. Members are funded 10000 in dregg-infra jworld-scratch.sh (the summon's resourceBatch refusal was the 1000
default). hbox gate12 covers tour, j14-apps and flatness. When those pass, the green candidate goes to infra for `demo-mini.sh ship` (rehearsal 3).
flatness-submit is reported, not blocking (root ruling; the ratchet preimage is ember's decision).

Gate scripts: gate12.sh = gate10 + j14-apps row (inputs staged once: integ/j14-hroot, rebound per candidate by
deploy/hermes/build-runtime-root --rebind; integ/j14-data davros.spk + inventory.json; integ/j14-secrets/openrouter.key).
`EDGE_REV=69c17a3 JWORLD_MANAGEMENT=distinct KEEP_WORLD=1 PORT=.. JWORLD_ROUTE_FRONT_PORT=.. bash gate12.sh SHA`.
Down a kept world with the candidate's scripts/spk-platform/world-down.sh RUN/inputs, then
dregg-infra-69c17a3/edge/mini/journey/jworld-scratch.sh down RUN/w (as hbox with XDG_RUNTIME_DIR/DBUS); log DOWN.
Forge composed container: on hbox `/home/hbox/lanes/infra/composed-sync CAND_DIR [EDGE]`, then
`ssh composed-box 'JWORLD_MANAGEMENT=distinct KEEP_WORLD=1 /ci/composed-gate SRC8 CAND12 [TAG]'`.

## The connector red: two causes, both fixed

1. spk-browser-proxy is TLS 1.3 + X25519MLKEM768 only; the export shelled out to /usr/bin/curl (OpenSSL < 3.5 has no
   hybrid group). 69251145d/6b1c05490: the export runs on rustls/aws-lc-rs in the client (Kimi-reviewed; overflow,
   deadline and framing fixes taken).
2. Sheet jd3 was never written, so EtherCalc answered 404 and the entrance 503. Infra's 552a316e7 seeds it
   (connector:sheet step); 27c274052 makes publish print one JSON document. Connector PASS on 994e36d08.

## Market packages for the demo box

dregg-forge:/var/lib/spk-fresh/qualified-2026-10-29/out/{local.json,adopt.tsv}: 20 packages; files under
../apps/<app>/out/<app>.spk; earlier outs kept as out.prev-N (session-made, removable). Regenerate: link or copy the
package into apps/<app>/out/<app>.spk (spk-fresh's forge copies live under /srv/spk-build/<app>/out/), move out aside,
`python3 -I repo/deploy/market/fresh-index.py --apps $Q/apps --recipes $Q/repo/apps/packages --spk-tool
/var/lib/spk-fresh/tools/spk --out $Q/out`, copy local.json to native/resource-client/tests/fixtures/
fresh-local-index-2026-10-29.json, run `cargo test --bin mini -- apps::tests` (24). FEATURED still upstream: WBO
rhtntjye (wbo.json names upstream), r8y55acm, zxent02j, uws252ya. SPK-fresh (a58fcf100f4438710): queue complete (Firefly last); all eight reruns pass the forged-identity row.

## In flight

- Infra (add189844d158e3a7): distinct composed residents/restart on 41590f420 (forge container).
- deploy/spk-host/tests/test_controller_world.py: 8 errors, 2 failures on hbox (ancestor custody refused under
  /home/hbox, ProtectHome=tmpfs expectation); environment or regression unknown, for lane/apps-agents.

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

1. Read gate-41590f42 (j14-apps row, composed distinct); merge infra's fix shas, rebuild, regate until residents and
   restart pass; hand the green candidate to infra for the ship.
2. Down kept worlds when done (/ci/c-41590f).

## Hygiene done 2026-10-29

/var/lib/mini-spk-worlds emptied through install-user-world remove (each logged in COMMANDS.log); my old rpool tree
/othersys/lanes/integ removed. Rules: named-file commits with `git commit -F`; never `git add -A` or `git stash`;
filtered tests; PID files; stop only by PID file; lake/git on hbox as hbox; disk pressure = stop and tell ember.
