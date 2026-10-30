# Etherpad SPK recipe

This app-owned recipe repackages maintained upstream Etherpad for Mini/Sandstorm. It uses the existing Sandstorm adapter for its branding and integration model, but does not carry forward the Etherpad 1.8 source or its obsolete plugin stack.

## Pinned inputs

`sources.json` is the machine-readable provenance record. The current inputs are:

- Etherpad `v3.3.12`, annotated tag object `29978fd8e06fafefb3b76827da064354884df0b4`, commit `f534756571d1c816e85af08acdc472a5822f5761`.
- The upstream source tarball and official amd64 release payload, each checked against a pinned SHA-256. The payload supplies the dependency-locked modules and built frontend; the source and payload import/export implementations are compared byte-for-byte during the build.
- Node.js `v24.22.2` from nodejs.org, checked against the upstream SHA-256.
- Sandstorm adapter commit `129febbbab38d19fcf0efd71f0cab43d233f1865` and the verified Sandstorm 308 SPK tool.

The upstream latest-release API and release page identified v3.3.12 as the current non-prerelease on 2026-10-29; its release notes describe security fixes and give a publication time of 2026-10-28T09:58:57Z.

## Rebuild on dregg-forge

Work only under `/var/lib/spk-fresh/apps/etherpad`; no global packages are needed. Copy this directory to `.../recipe`, keep the app signing keyring at `.../etherpad.keyring` (mode 0600, outside every repository), and place the public output of the one-time `spk keygen` in `.../app-id`. Then run:

```sh
nohup bash /var/lib/spk-fresh/apps/etherpad/recipe/build.sh \
  > /var/lib/spk-fresh/apps/etherpad/logs/build.log 2>&1 < /dev/null &
echo $! > /var/lib/spk-fresh/apps/etherpad/build.pid
```

The script verifies all source checksums, applies the patches, checks the Mini import/export routes against the pinned source, and runs a direct smoke test with a PID-file-managed server. The smoke test checks text import, exact text export, root redirection, and read-only denial; it is not Mini qualification. It then packs and verifies `out/etherpad.spk` and writes verification details and hashes under `logs/`.

## Sandstorm adaptations

- `/` redirects to `/p/main`, preserving the single-document grain model.
- Sandstorm user/tab IDs provide stable authorship; Sandstorm usernames initialize author names, and same-user tabs are not disconnected as duplicates.
- The `modify` permission is enforced by Etherpad's existing authorization path, including import.
- Per-grain RustyDB and generated secrets live below `/var`; the application filesystem remains read-only. An empty per-grain plugin manifest is initialized explicitly because no external plugins are bundled, avoiding any runtime pnpm migration or installation.
- Update checks and the legacy Etherpad HTTP API are disabled. The old adapter also disabled that API. Mini does not use it.

## Mini HTTP API compatibility

`apps/interfaces/etherpad.json` keeps its operation declarations and is re-pinned to the new app and package IDs. The manifest sets `bridgeConfig.apiPath = "/"`, so Mini's package descriptor exposes `api` beside `web` without changing the declaration's root-relative paths. Current upstream still implements:

- `POST /p/:pad/import`: multipart text upload; success is HTTP 200 with `code: 0` and `message: "ok"` (plus an additional `data` field, which the interface permits).
- `GET /p/:pad/export/txt`: HTTP 200 plain-text export.

The direct smoke test exercises those exact routes and expects `typed document\n` after replacement. There is no Mini interface API change to record. This is a new app ID and new grain format; it is not an in-place migration path for grains from the old 1.8.18 app.
