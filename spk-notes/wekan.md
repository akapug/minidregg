# Wekan repackage — state

Seat: spk-fresh-glm-4 (earlier attempts: glm-3 + at least one unrecorded). One step
per session. Doc row: `docs/SPK-FRESH-2026-10-29.md` line 52.

## Step 1: plan — DONE (2026-10-29)

Upstream Wekan **v12.68** (released 2026-10-29, maintained). Interface is DDP
(websocket `/websocket`, `loginWithSandstorm`, `/.sandstorm-login`), all
root-relative ⇒ `apiPath "/"` valid. Manifest needs `bridgeConfig.apiPath "/"`
so an `api` interface appears next to `web`.

## Step 2: fetch+build — DONE (2026-10-29, glm-4: found complete on disk from the
prior crashed session; verified, NOT rerun)

All on dregg-forge under `/srv/spk-build/wekan/`:

- **Approach** (deviation from the meteor-spk plan — better provenance): the
  reproducible recipe `recipe/build.sh` + `recipe/adapt_pkgdef.py` fetches the
  upstream v12.68 source tarball AND upstream's own official signed
  `wekan-12.68-sandstorm.spk` (both sha256-pinned in the script), `spk unpack`s
  the official image, deletes its signed `sandstorm-manifest` +
  `sandstorm-http-bridge-config`, adapts upstream's in-tree
  `sandstorm-pkgdef.capnp` to our appId, and re-packs with the shared 308
  toolchain (`/var/lib/spk-fresh/tools/spk`, includes
  `/var/lib/spk-fresh/tools/sandstorm-308/usr/include`).
- `downloads/wekan-v12.68.tar.gz` (sha256 94f77ae1…08c5) and
  `downloads/wekan-12.68-sandstorm.spk` (sha256 8c8c4b82…2043), both checked OK
  in `logs/build.log`.
- `package/sandstorm-pkgdef.capnp` = adapted pkgdef actually packed
  (`apiPath = "/"` at line 217, `saveIdentityCaps = true`; bridge config
  synthesized from it at pack time).
- **`out/wekan.spk`** — 181,681,092 bytes, built 2026-10-29T09:07:07Z, sha256
  `8c2f7c710744bdc97012a21f37cebcd19447b2193d630067f207e72ceb23de18`
  (also in `out/wekan.spk.sha256`). `spk verify --details` output in
  `out/verify.txt`.
- Build ran detached: PID was **324151** (`logs/build.pid`), now exited; nothing
  running. Log: `logs/build.log`.

## Step 3: pack+sign — ARTIFACTS COMPLETE ON DISK (same prior session); nothing
left to build — next session just confirms and moves on

- Signed with the new key `/Users/ember/.dregg-secrets/spk-keys/wekan.key`
  (exists locally, 0600, 128 B, created Oct 29 04:57; never printed/committed).
  Forge keyring copy: `/srv/spk-build/wekan/wekan.keyring` (0600).
- **New appId**: `wpe8yvzdpjsst9314ucecmpmyzju0830ujm815ew5mjuen173kg0`
  (upstream's was `m86q05rdvj14yvn78ghaxynqz7u2svw6rnttptxx49g1785cdv1h`,
  recorded in `out/upstream-app-id`).
- **packageId**: `8c2f7c710744bdc97012a21f37cebcd1`.
- `out/verified-app-id` == new appId (spk verify passed). Manifest:
  version 1268, marketingVersion `12.68~2026-10-29`, MIT, wekan.github.io.
- Worktree pin `apps/interfaces/wekan.json` was ALREADY re-pointed by the prior
  session to exactly these new appId/packageId/appVersion (status
  `prototype-unqualified`, git-diff visible). Step 5 verifies it, not rewrites.
- If a rebuild is ever needed: `ssh dregg-forge` then
  `bash /srv/spk-build/wekan/recipe/build.sh` (idempotent, re-verifies fetches).

## Step 4: qualify — **DONE (2026-10-30, verified this session; the qualifying
run itself was made by a later crashed session as "qualification-6" and never
recorded here)**

Unblock confirmed: `f581efa96` (second-rendezvous DDP fix) IS in origin/main
(tip `c0de8f2a4`); the wekan lane's bin symlink
`/tank/lanes/spk-fresh-wekan/bin` → integ candidate
`/home/hbox/lanes/integ/candidates/8cb74aba593663adf5fb42b49c5bf1b6329f16c1/bin`
(built Oct 29 13:22, verified ⊇ f581efa96). Against that bin, qualification-6:

- Driver PID 1630412 (`qualification-6.pid`), exited; log
  `/tank/lanes/spk-fresh-wekan/qualification-6.log`. World-6 UP clean and DOWN
  clean: `WORLD DOWN store=6c380ea858902a41 removal_assertions=0`.
- Lifecycle **PASS**: create/install/share/start/enrol/page `/` — 202 s.
- Typed beneath-HTML write/read-back **PASS**:
  `qualification-6/interface-wekan-1792610-615/result.json` → `status: PASS`,
  `row: typed-write-readback`, packageId `8c2f7c710744bdc97012a21f37cebcd1`
  (ours), runId `ai-8b6d88b98f67427f84ab`, transport `member-browser-route`,
  hermes NOT_RUN; log line: "descriptor lists api and web
  (bridgeConfig.apiPath /)".
- `featured: 2 PASS of 2 rows` ⇒ the step-4 gate (lifecycle + beneath-HTML
  read-back) is MET.
- History: runs 1–3 first-rendezvous stall (native, not our repack; old market
  package failed identically); run 4 isolated the ~11.7 s SECOND-rendezvous
  admission stall (`qualification-4/interface-wekan-914154-20238/requests.jsonl`
  on hbox); native fix f581efa96 landed; 6 qualified. Nothing left to run.

## Step 5: land — TODO (unblocked; step 4 above is the qualification evidence)

- Verify/keep the already-re-pointed `apps/interfaces/wekan.json` (refresh any
  digest field if the format wants the spk sha256:
  `8c2f7c710744bdc97012a21f37cebcd19447b2193d630067f207e72ceb23de18`).
- FEATURED (`native/resource-client/src/apps.rs`): replace old appId
  `m86q05rdvj14yvn78ghaxynqz7u2svw6rnttptxx49g1785cdv1h` →
  `wpe8yvzdpjsst9314ucecmpmyzju0830ujm815ew5mjuen173kg0`.
- Minimal edit to Wekan's row in docs/SPK-FRESH; named-file `git commit -F`;
  `pull --rebase`; push lane/spk-fresh; append
  `- <sha> — Wekan: qualified` to
  /private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/kimi-spk/landings.md.
