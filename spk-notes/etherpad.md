# Etherpad SPK repackaging

## 1. plan — done (2026-10-29)

- Upstream: Etherpad **v3.3.12**, released 2026-10-28 and maintained.
- Source: https://github.com/ether/etherpad/releases/tag/v3.3.12
  (source archive: https://github.com/ether/etherpad/archive/refs/tags/v3.3.12.tar.gz).
- Package version: `3.3.12-1`.
- Build approach: plain build directory on `dregg-forge` at
  `/srv/spk-build/etherpad`, using the Sandstorm 308 toolchain; pack/sign with
  `spk` directly rather than introducing a vagrant-spk VM. Do not touch the
  `demo` or `nano` containers. Run any long build detached with its own PID
  file and log.
- Manifest needs: the normal `web` interface plus an `api` interface by setting
  `bridgeConfig.apiPath` to `"/"`.

The planning row already contains historical packaged IDs; this run must still
fetch/build, pack/sign, and qualify before treating those IDs as this run's
result.

## 2. fetch+build — done (2026-10-29)

- Host: `dregg-forge`, x86_64. The `demo` and `nano` containers were not touched.
- Archive: `/srv/spk-build/etherpad/downloads/etherpad-v3.3.12.tar.gz`
- Archive SHA-256: `ed0632716df6e6cfd693b8b2ca314a74fceb47f18a07f4944b2a8338bcefc800`
- Source and built app tree: `/srv/spk-build/etherpad/source/etherpad-3.3.12`
  (650 MiB including dependencies and built static assets).
- Toolchain: Node `v24.22.2` at
  `/srv/spk-build/etherpad/toolchain/node`, pnpm `12.4.2` at
  `/srv/spk-build/etherpad/toolchain/bin/pnpm`.
- Build script: `/srv/spk-build/etherpad/scripts/build.sh`
  (`pnpm install --frozen-lockfile`, then `pnpm run build:etherpad`).
- Build log: `/srv/spk-build/etherpad/logs/build.log`; exit-status file:
  `/srv/spk-build/etherpad/logs/build.exit` (contains `0`).
- Detached build PID was `289110`, recorded at
  `/srv/spk-build/etherpad/pids/build.pid`; the process has finished.

## 3. pack+sign — done (2026-10-29)

- Package definition: `/Users/ember/dev/minidregg-lanes/spk-fresh/apps/packages/etherpad/sandstorm-pkgdef.capnp`;
  it uses only the self-contained `rootfs`, includes the generated manifest and
  bridge config, and declares `bridgeConfig.apiPath = "/"`. Upstream's
  `src/etherpad_icon.svg` is copied to `apps/packages/etherpad/branding/etherpad.svg`.
- Signing keyring: `/Users/ember/.dregg-secrets/spk-keys/etherpad.key`
  (0600, 128 bytes; already present from the earlier attempt, never printed or
  committed). Remote copy: `/srv/spk-build/etherpad/etherpad.keyring` (0600).
- Pack directory: `/srv/spk-build/etherpad/package-3.3.12-1`; its 903 MiB
  rootfs contains the built app, Node 24, bash/sh and their runtime libraries,
  plus the Sandstorm 308 HTTP bridge.
- Final pack PID was `301212`, recorded at
  `/srv/spk-build/etherpad/pids/pack-3.3.12-1-r2.pid`; it has finished.
  Log: `/srv/spk-build/etherpad/logs/pack-3.3.12-1-r2.log`; exit-status file:
  `/srv/spk-build/etherpad/logs/pack-3.3.12-1-r2.exit` (contains `0`).
  The first archive omitted the generated manifest and was overwritten by this
  corrected, verified pack.
- Initial signed package (superseded during qualification by repaired r3):
  `/srv/spk-build/etherpad/out/etherpad-3.3.12-1.spk` (119,307,880 bytes).
  Its verified package ID was `83e9f7746363ee3502994e3b27c02fda`; SHA-256:
  `83e9f7746363ee3502994e3b27c02fdaa91147f05c03928588f8ea7d0339f848`.
- Qualification repairs (detailed below) superseded r2–r5. Final signed
  package: `/srv/spk-build/etherpad/out/etherpad-3.3.12-1-r6.spk`
  (119,951,172 bytes). Pack PID `463273`, PID file
  `/srv/spk-build/etherpad/pids/pack-3.3.12-1-r6.pid`; log/status
  `/srv/spk-build/etherpad/logs/pack-3.3.12-1-r6.log` and `.exit` (`0`).
  `spk verify` succeeded.
- Package SHA-256: `e6d71fa0205f177c6cd7d8d49dfc79e0622d0bfde3ddb81ec0d16078dc9fbc7c`
- Package ID reported by `spk verify`: `e6d71fa0205f177c6cd7d8d49dfc79e0`
- App ID reported by `spk verify`: `ksyn7qa4szjwa14v89r7znxwrpjs0dez5q2u8s810d0awnuswmfh`

## 4. qualify — done (2026-10-29)

- Qualified final r6 on hbox as class L with `market-large-v1` (the 903 MiB
  decoded package exceeds standard-v1's 768 MiB bound). Package/declaration
  under test: `e6d71fa0205f177c6cd7d8d49dfc79e0`; app ID above. The hbox-only
  declaration was pinned for the driver; the repo declaration is step 5.
- Successful world: `/tank/lanes/spk-fresh-etherpad/r6-run/run9`; driver PID
  `3026540` (`r6-run/qualify9.pid`, finished). World-up, import-profile,
  qualification and teardown status files are all `0` under `r6-run/`.
- `qualification9/rows.tsv`: PASS create/install/share/start/enrol/page `/`
  (227 s), and PASS one beneath-HTML typed Etherpad write/read-back. Typed
  evidence: `qualification9/interface-etherpad-3100389-22165/result.json`
  (Hermes NOT_RUN). Driver log: `r6-run/qualify9.log`.
- Teardown: `WORLD DOWN store=75847b958922de35 removal_assertions=0`; log
  `r6-run/world9-down.log`.
- Earlier qualification runs drove the real packaging repairs: complete
  `mkdir` runtime closure, correct `/opt/app` launcher paths, and
  `/opt/app/var -> /var` so plugin state, generated JS and the database use
  writable grain storage. The upstream var placeholder is preserved outside
  the rootfs at `package-3.3.12-1/upstream-var-placeholder`.

## 5. land — done (2026-10-29)

- Re-pinned `apps/interfaces/etherpad.json` to package ID
  `e6d71fa0205f177c6cd7d8d49dfc79e0`; declaration SHA-256 is
  `d43bea1538fd1e811430f2941a3f44ec7de4621e48c1af7987bc50992d02cc2e`.
- FEATURED in `native/resource-client/src/apps.rs` already pointed to app ID
  `ksyn7qa4szjwa14v89r7znxwrpjs0dez5q2u8s810d0awnuswmfh`, so it needed no edit.
- Updated Etherpad's row to QUALIFIED and landed the packaging sources under
  `apps/packages/etherpad/`.
- Commit `bf49ce23a` (`Repackage Etherpad from maintained upstream`) pushed to
  `origin/lane/spk-fresh`. `git pull --rebase` was refused because unrelated
  lane files have unstaged changes; nothing was stashed, and the direct push
  succeeded.
- Appended `- bf49ce23a — Etherpad: qualified` to
  `/private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/kimi-spk/landings.md`.

## Next

All five steps are complete.
