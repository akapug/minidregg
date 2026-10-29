# WBO SPK-FRESH package

This directory contains the Sandstorm adaptation and reproducible build recipe
for WBO (Whitebophir), without vendoring upstream source or dependencies.

## Pinned inputs

- Upstream release: [`v2.18.26`](https://github.com/lovasoa/whitebophir/releases/tag/v2.18.26), tag commit `254753602f008d3014c5bd03c9d6492a20014d05`.
- Source archive: `https://codeload.github.com/lovasoa/whitebophir/tar.gz/refs/tags/v2.18.26`, SHA-256 `ff08e993c4758710034e1c5c131b143a4d0a2dc7128c4f4e0a925a3ab3ccaa1c`.
- Runtime: Node.js `22.23.4`, the minimum release required by this WBO version. The official Linux x64 archive is pinned by SHA-256 in `build.sh`.
- Sandstorm adapter baseline: `https://github.com/ocdtrekkie/whitebophir-sandstorm`, commit `588b68a4f3ef8c93eb011eee47c37313da27f9cf`. Its unpinned `git pull` build is replaced by the verified release archive and lockfile installation here.
- SPK tool: Sandstorm 308 at `/var/lib/spk-fresh/tools/spk` on dregg-forge.

The new app ID is `j4jvn386t7un76qu6yyw1vwc5ke50t07e38r82kzy4qqg6qq7msh`.
The package ID is `d3b06718d12bc377db7b494679440b91`; the complete candidate
SHA-256 is `d3b06718d12bc377db7b494679440b91f4e6623a96f7856f6c7ba144c4a98303`.
The signing key is deliberately absent from this repository.

## Build on dregg-forge

Copy this directory to `/var/lib/spk-fresh/apps/wbo/recipe`, keep the app key at
`/var/lib/spk-fresh/apps/wbo/wbo.key` with mode 0600, and run:

```sh
bash /var/lib/spk-fresh/apps/wbo/recipe/build.sh
bash /var/lib/spk-fresh/apps/wbo/recipe/smoke.sh 1
```

The build verifies the tag and both archive hashes, runs `npm ci` with the
upstream lockfile and production dependencies only, and stages the server,
client assets and package-local Node runtime. It carries the runtime's shared
library closure and ELF interpreter, emits `out/wbo.spk`, and verifies the signed
package with the Sandstorm 308 tool. It refuses to overwrite generated source or
staging directories; use a fresh `WORKDIR` for another clean build.

`bootstrap.mjs` creates the grain's home and history directories, sets WBO's
working directory, and starts its current ES-module server. Board history is stored
in `/var/wbo_data`; the grain opens the persistent `board` board by default. No build
or runtime global package installation is used.

## HTTP interface

The manifest sets `bridgeConfig.apiPath = "/"`, so the installed descriptor exposes
`api` beside `web`. WBO 2.18 joins a board with the socket.io query
`board=<name>&baselineSeq=0`; a `broadcast` event carries a numeric mutation (for
example tool `3`, type `1` for Rectangle create). A fresh connection replays the
board's mutations, and `GET /download/<board>` reads the persisted SVG.

There was no pre-existing `apps/interfaces/wbo.json` declaration to re-pin.

## Mini qualification on hbox

`qualify.tsv` and `qualify-writes/` form an app-owned batch for
`scripts/spk-platform/featured-qualify.sh`. Prepare a fresh mode-0700 lane whose
`src` and `bin` point at the current source and built platform binaries, and place
the candidate in its cache as `d3b06718d12bc377db7b494679440b91.spk`. Then run:

```sh
bash /tank/lanes/spk-fresh-wbo/recipe/qualify.sh \
  /tank/lanes/spk-fresh-wbo /tank/lanes/spk-fresh-wbo/cache 1
```

Use a new attempt number for each run. The wrapper holds
`/tank/lanes/world-up.lock` only around world creation, stops the grain after its
write, and tears the world down on every exit. A passing write row requires the
socket mutation's acknowledgement, exact replay from a second socket, exact ID in
the saved SVG download, and an installed descriptor containing both `api` and `web`.

On 2026-10-29 the signed candidate passed both rows on hbox. Evidence is in
`/tank/lanes/spk-fresh-wbo/qualification-2/rows.tsv`; the installed descriptor is
`wbo-descriptor-inspection.json` beside it. World `0100043aeecce1cd` was torn down
with `removal_assertions=0`.
