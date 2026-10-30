# Hledger Web package

Packages the maintained hledger-web **1.52.4** static Linux release with the
Sandstorm 308 toolchain. The release tag, commit, asset URL and SHA-256 are
recorded in `upstream.json`; the build verifies all of them before signing.
The SVG icons and screenshots come from the same tag's `.sandstorm` directory.

The runtime contains only the official static binary, a minimal shell launcher
and its libc/loader. A grain stores its journal at `/var/journal`. Upstream's
native `--allow=sandstorm` mode maps editor, adder and viewer sharing roles to
hledger-web permissions. `bridgeConfig.apiPath = "/"` exposes both `web` and
`api` interfaces; `apps/interfaces/hledger.json` declares the JSON transaction
write and read operations.

## Build

The private key lives at `/srv/spk-build/hledger/hledger.keyring` on
`dregg-forge`, with an offline backup at
`/Users/ember/.dregg-secrets/spk-keys/hledger.key`. Both are mode 0600 and are
never printed or committed.

Copy this directory to `/srv/spk-build/hledger/recipe` on `dregg-forge` and run
`build.sh`. It downloads the pinned upstream archive if needed, verifies the
static binary from the staged root, and writes the signed package and
verification evidence to `/srv/spk-build/hledger/out/`.

## Qualification

`qualify.tsv` is an app-owned batch for
`scripts/spk-platform/featured-qualify.sh`. On hbox, prepare a mode-0700 lane
with `src` and `bin`, put only `<packageId>.spk` in its cache, and run:

```sh
bash apps/packages/hledger/qualify.sh /tank/lanes/spk-fresh-hledger /tank/lanes/spk-fresh-hledger/cache 1
```

The wrapper holds `/tank/lanes/world-up.lock` only during world creation and
tears the world down on exit. The declaration's two qualification rows add a
balanced transaction through `PUT /add`, then read it back through
`GET /transactions`; the platform gate also checks install, start and the
installed descriptor's `api` and `web` interfaces.

On 2026-10-29, package `7c0c42cbc414380ded0f0f5c1e743e06` passed both rows on
hbox: create, install, share, start, enrol and `GET /`, followed by the typed
transaction write/read-back. The installed descriptor exposed `api` and `web`.
The qualification evidence records interface digest
`ab55ab38d00e563cce995d29c7eac10231d084de86fe5be5c3843edfba0ea387`.
