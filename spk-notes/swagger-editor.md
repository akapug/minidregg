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

## 4. qualify — not started

## 5. land — not started

## Next

Step 4 (qualify): on hbox with the repo's scripts/spk-platform tooling,
world-ups under `flock -o /tank/lanes/world-up.lock` around world-up only.
Install+start `/srv/spk-build/swagger-editor/out/swagger-editor-5.10.0-1.spk`
(package ID `4e67b5c18e218e6cf96591ea0efa3152`, app ID
`xm16d84ksseg44ef58z7n2aw7qt1n6psk0cewzr0e0arfjk5r4fh`), do a
write+read-back beneath the HTML (type into the editor DOM; the app is
stateless — specs live in the browser session), then tear the world down.
Decoded size ~170M fits `standard-v1` (768M bound).

Step 5 (land): no `apps/interfaces/swagger-editor.json` exists to re-pin
(unlike etherpad) — check whether one should be created. FEATURED
(native/resource-client/src/apps.rs) has NO Swagger Editor row: add the new
app ID there. Commit `apps/packages/swagger-editor/**`, update the
SPK-FRESH row (17), pull --rebase, push lane/spk-fresh, append the landing
line to landings.md.
