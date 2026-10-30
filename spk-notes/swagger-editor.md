# Swagger Editor SPK repackaging

## 1. plan — done (2026-10-29)

- SPK-FRESH row 17: old store package 2.10.4 (2016-10-26); task (a)
  repackage current Swagger Editor; P1; was queued.
- Upstream: Swagger Editor **v5.10.0**, released 2026-10-21, maintained.
- Source: https://github.com/swagger-api/swagger-editor/releases/tag/v5.10.0
  (source archive: https://github.com/swagger-api/swagger-editor/archive/refs/tags/v5.10.0.tar.gz).
- Package version: `5.10.0-1`.
- App shape: upstream v5 is a Vite/React single-page editor that builds to
  static assets; the package serves those assets over the Sandstorm 308 HTTP
  bridge (static server in the pack dir, no upstream daemon to configure).
  Confirm the package manager from the repo lockfile at fetch time (npm vs
  yarn vs pnpm) rather than assuming.
- Build approach: plain build directory on `dregg-forge` at
  `/srv/spk-build/swagger-editor`, using the Sandstorm 308 toolchain; pack/sign
  with `spk` directly rather than introducing a vagrant-spk VM. Do not touch
  the `demo` or `nano` containers. Run any long build detached with its own
  PID file and log.
- Manifest needs: the normal `web` interface plus an `api` interface by setting
  `bridgeConfig.apiPath` to `"/"`.

## 2. fetch+build — done (2026-10-29)

- Build root on dregg-forge: `/srv/spk-build/swagger-editor/{downloads,source,
  toolchain,scripts,logs,pids}` (box x86_64, 30G RAM, 530G free).
- Source fetched: `downloads/swagger-editor-5.10.0.tar.gz`
  (451,167 bytes; SHA-256
  `f36cf85d81f23dec767bfeeaa4c0a7a4ab31c423229902724503e002eb360771`),
  extracted to `source/swagger-editor-5.10.0`.
- Package manager: **npm** (`package-lock.json`; no pnpm/yarn lock).
  Build entry: `npm run build:app` (Vite; esm/umd/definitions steps are
  library artifacts, not needed). Node: no system node as root; reused
  `/srv/spk-build/etherpad/toolchain/node` (v24.22.2).
- Build script: `/srv/spk-build/swagger-editor/scripts/build.sh`
  (npm ci + build:app; exit trapped to `logs/build.exit`), ran detached
  PID 1006323 (`pids/build.pid`), log `logs/build.log`; **exit 0**,
  vite "built in 21.64s". PID has exited; file kept for reference.
- App tree: `source/swagger-editor-5.10.0/build/` (outDir is `build`, NOT
  `dist`) — index.html, manifest.json, oauth2-redirect.html, robots.txt,
  assets/ 932K, node_modules/ 220K (NOT brand assets: tree-sitter wasm
  parsers loaded at runtime by the editor — keep), static/ 86M.
- `static/js` is 85M of which ~65M is `*.js.map` sourcemaps
  (main map alone 41M); real JS ~20M. **Exclude `*.map` at pack time.**

## 3. pack+sign — done (2026-10-29)

- Packaging sources written in the repo at `apps/packages/swagger-editor/`
  (sandstorm-pkgdef.capnp, build.sh, launcher.sh, static-server.js,
  branding/swagger-editor.svg + description.md, CHANGELOG.md, README.md);
  copied to the forge at `/srv/spk-build/swagger-editor/recipe/`.
- Signing key: NEW key generated on dregg-forge
  (`spk keygen`, keyring `/srv/spk-build/swagger-editor/swagger-editor.keyring`,
  0600, 128 bytes); Mac copy
  `/Users/ember/.dregg-secrets/spk-keys/swagger-editor.key` (0600, never
  printed or committed). Note: the app ID derives from the key, NOT the old
  store package (correcting the plan note); the old 2016 package is not on
  the forge index anyway.
- **App ID: `xm16d84ksseg44ef58z7n2aw7qt1n6psk0cewzr0e0arfjk5r4fh`**
  (also baked into the pkgdef and README; FEATURED has no Swagger row yet,
  so step 5 adds/replaces it there).
- App shape: self-contained rootfs (`bin/bash+sh`, `lib`/`lib64` ldd
  closure, `/etc/localtime`, node v24.22.2 at `opt/app/node/bin/node`,
  app at `opt/app/swagger-editor` = upstream `build/` minus `*.map`,
  `sandstorm-http-bridge`) — the layout of the qualified etherpad r6
  bundle, NOT the sparse-rootfs + sandstorm-files.list variant (that one
  failed: `spk pack` died "No file found to satisfy requirement: bin").
  Static server: `static-server.js` (node stdlib, MIME incl.
  `application/wasm`, HEAD, traversal-refusal, immutable cache for
  `assets/`).
- Two failed runs for the record: r1 (sparse rootfs, log
  `logs/pack-5.10.0-1-r1-failed.log`), r2 (`/dev/fd` process-substitution
  missing under the ssh invocation; build.sh now uses a temp-file
  redirect; log `logs/pack-5.10.0-1-r2.log`).
- Successful run r3: build PID 1076536 (`pids/pack-5.10.0-1-r3.pid`,
  finished), log `logs/pack-5.10.0-1-r3.log`; smoke test passed (real
  index.html + a referenced asset + HEAD + 404 + traversal-refusal from
  the packaged tree).
- Package: `/srv/spk-build/swagger-editor/out/swagger-editor-5.10.0-1.spk`
  (44,299,200 bytes; SHA-256
  `4e67b5c18e218e6cf96591ea0efa3152acec70b623563691ef8bab27ccffdd84`).
- **Package ID: `4e67b5c18e218e6cf96591ea0efa3152`** (`spk verify
  --details`, `logs/verify-details.txt`). `spk unpack` signature check
  exit 0; archive confirmed complete (bin/bash+sh, lib/x86_64-linux-gnu
  loader closure, node, 25M app tree, no *.map, tree-sitter wasm present
  both hashed in assets/ and under node_modules/, generated
  sandstorm-manifest + sandstorm-http-bridge-config).
- bridgeConfig apiPath "/" verified by byte-comparing the binary
  `sandstorm-http-bridge-config` against the qualified etherpad r6 one:
  structurally identical; only diffs are three length bytes, each exactly
  +4 (my permission description is 4 chars longer). Icon is a drawn
  stand-in (upstream tarball ships no SVG) — see README note.
- **Correction (2026-10-30, found during qualify): the canonical package is
  the SECOND pack `5.10.0-2`**, not the `-1` above. A prior session packed
  r4 (`logs/pack-5.10.0-2-r4.log`, forge 2026-10-29 16:57 UTC): same app ID,
  version 2, CHANGELOG grown 398→829 bytes documenting the `/editor/spec`
  server-side spec store (PUT/GET, 1 MiB bound, persisted under `/var`,
  loaded via `/?url=/editor/spec`); recipe on the forge is byte-identical to
  this repo's `apps/packages/swagger-editor/` (all five files sha-matched).
  **Package ID `c8ae9b8ea081ad5b31701cd6b11292cc`**, spk
  `/srv/spk-build/swagger-editor/out/swagger-editor-5.10.0-2.spk` (44,298,324
  bytes; SHA-256
  `c8ae9b8ea081ad5b31701cd6b11292ccff1bca883296695b97cee03d43b8e253`).
  The `-1`/`4e67b5c1…` pack above remains on the forge but is superseded —
  do not ship it.

## 4. qualify — done (2026-10-30)

- **4 PASS of 4 rows** on hbox (world `q1-run/run1`, store `7385b50cf6504b92`,
  import profile standard-v1, `QUALIFY_STOP=1`). All stage exits 0:
  world1/import1/qualify1/world1-down. Teardown
  `WORLD DOWN store=7385b50cf6504b92 removal_assertions=0`
  (`q1-run/world1-down.log`).
- Driver `/tank/lanes/spk-fresh-swagger/qualify1.sh` (local mirror
  `…/scratchpad/kimi-spk/swagger-qualify/qualify1.sh`; driver PID 2288194,
  exited on its own). Table `swaggereditor.tsv` (letters j web, k api), write
  fn `swaggereditor-writes/write_SwaggerEditor.sh` (web → `typed_app_row
  swagger-editor`; api → raw Bearer curl PUT/GET `/editor/spec`).
  Rows at `/tank/lanes/spk-fresh-swagger/qualification2/rows.tsv`:
  web journey PASS 132 s; **web typed row PASS** (declaration-driven
  spec.put+spec.get, evidence `qualification2/interface-swagger-editor-2343717-7448/result.json`);
  api journey PASS 150 s; **api write PASS (PUT /editor/spec 204, GET 200,
  exact marker read-back over Bearer on the api route)** — the
  `bridgeConfig.apiPath "/"` manifest need is PROVEN: an api interface sits
  next to web and carries the same write.
- The typed row required re-pinning `apps/interfaces/swagger-editor.json`
  first (`row.py:158` refuses a declaration whose packageId ≠ the table's):
  appId `xm16d84k…`, packageId `c8ae9b8e…`, appVersion `5.10.0-2`, sources →
  upstream tag + `package:c8ae9b8e…/opt/app/static-server.js`; canonical
  declaration digest **`206a69cbb0e5a8cf03699eba9e2794907dc89df77b90d06c68236474f9f363f2`**
  (the digest in result.json matches). Operations/qualification unchanged —
  they already bound the shipped `/editor/spec` store.
- Setup facts: spk staged `cache/c8ae9b8ea081ad5b31701cd6b11292cc.spk`
  (sha256 verified = forge full sha); `bin`/`src` copied from the revealjs
  lane (spk-platform scripts checksum-identical to this tree), then the
  re-pinned interface json copied into the lane `src`. Letters queued ~2 min
  behind the scrumblr lane's world-up on `/tank/lanes/world-up.lock` —
  normal serialization, not a failure.
- Prior partial run for the record (`qualification1/`, driver
  `run1/`, exits all 0, world store `4c7b5a78aa546e9a` torn down): the
  earlier context-exhausted session had already packed `-2` and run letter b
  (web only) as a typed row against a lane-local declaration variant
  (digest `2c207939…`) whose bytes were lost when its `src` was overwritten;
  corroboration only — the binding evidence is `qualification2` above.

## 5. land — done (2026-10-30)

- **Commit `c01962462` "Repackage Swagger Editor 5.10.0 from the official
  release"** (sibling session, same shared worktree): `apps/packages/swagger-editor/**`,
  the re-pinned `apps/interfaces/swagger-editor.json` (digest `206a69cb…` —
  this session's edit rode along), FEATURED row added
  (`native/resource-client/src/apps.rs:307`, app ID `xm16d84k…`), SPK-FRESH
  row 17 → QUALIFIED. Pushed: `lane/spk-fresh` in sync with origin.
- Landings ledger line appended by this session:
  `- c01962462 — Swagger Editor: qualified` (kimi-spk/landings.md).

## Next

Nothing owed for Swagger Editor: plan, pack, qualify (web+api, typed row),
landing and ledger are all green. If the app is ever revisited: canonical
package is `5.10.0-2` `c8ae9b8ea081ad5b31701cd6b11292cc` (NOT the `-1`
`4e67b5c1…` superseded pack still sitting in the forge `out/`); the signing
key lives at `/Users/ember/.dregg-secrets/spk-keys/swagger-editor.key`.
