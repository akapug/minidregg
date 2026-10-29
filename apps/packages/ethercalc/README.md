# EtherCalc SPK-FRESH package

This directory contains only the app-owned Sandstorm adaptation and build recipe;
it does not vendor EtherCalc or its dependencies.

## Pinned inputs

- Upstream release: [`0.20261026.0`](https://github.com/audreyt/ethercalc/releases/tag/0.20261026.0), published 2026-10-26.
- Tag commit: `964efab030d17a78fb2d9b2358c4cd8ef4c6af93`.
- Source: `https://codeload.github.com/audreyt/ethercalc/tar.gz/refs/tags/0.20261026.0`
- Source SHA-256: `3a1a78145743be6dabdddedab31b84ef329417ca25909f9f4983d64661f01316`.
- Sandstorm adaptation base: `https://github.com/sandstorm-org/ethercalc-sandstorm`, commit `ed7ad6b6dc5872121bce666752b252a6dab503be`, plus the tagged upstream's newer workerd/Sandstorm implementation.
- Runtime: Bun `1.3.14` and workerd `1.20260714.1` from the upstream lockfile. The Bun archive SHA-256 is `951ee2aee855f08595aeec6225226a298d3fea83a3dcd6465c09cbccdf7e848f`; its official release checksum file also verifies the archive.
- SPK tool: Sandstorm 308 at `/var/lib/spk-fresh/tools/spk` on dregg-forge.

The new app ID is `umpy9re0saa7vtckd6mnprv6mc5vjgr0qh5qucs4na3qjrxrrzch`.
The signing key is deliberately absent from this repository.

## Build on dregg-forge

Copy these files to `/var/lib/spk-fresh/apps/ethercalc/packaging/`, keep the app
keyring at `/var/lib/spk-fresh/apps/ethercalc/ethercalc.keyring` with mode 600,
and run in order:

```sh
BASE=/var/lib/spk-fresh/apps/ethercalc bash /var/lib/spk-fresh/apps/ethercalc/packaging/build.sh
BASE=/var/lib/spk-fresh/apps/ethercalc bash /var/lib/spk-fresh/apps/ethercalc/packaging/smoke.sh
BASE=/var/lib/spk-fresh/apps/ethercalc bash /var/lib/spk-fresh/apps/ethercalc/packaging/package.sh
```

`build.sh` refuses to overwrite an existing `work/build-src`; use a fresh app
build directory for a rebuild rather than deleting an existing artifact. It
installs no global packages. Build outputs and logs stay under the app directory.
The package script emits `out/ethercalc.spk`, `out/verify.txt`, and
`out/package.sha256`.

## Packaging adaptations

- Uses the tagged upstream's TypeScript worker, curated assets, standalone
  workerd configuration, and legacy dump migrator. The compiled worker is bundled;
  the compiler, test dependencies, and `node_modules` are not shipped.
- `run_grain.sh` differs from upstream only in using package-local
  `runtime/workerd` and putting package-local `runtime/bun` on `PATH`.
- `sandstorm-pkgdef.capnp` carries the new app ID and version
  `2026.10.26.0+sandstorm1` / `202610260`. Unused PGP author fields were removed
  rather than copying another packager's identity.
- `DESCRIPTION.mkdn` comes from the existing Sandstorm adaptation. `CHANGELOG.mkdn`
  adds this release to that history.
- `package.sh` generates a concrete file list. The three virtual Sandstorm entries
  (`sandstorm-manifest`, `sandstorm-http-bridge`, and
  `sandstorm-http-bridge-config`) are explicit; this avoids `alwaysInclude = ["."]`,
  which would vendor the entire build tree. Runtime shared-library dependencies
  are resolved on the build box and included in the list.

## Interface compatibility and API changes

The manifest sets `bridgeConfig.apiPath = "/"`, so Mini's package descriptor
exposes `api` beside `web` and the declaration's root-relative routes remain valid.
`apps/interfaces/ethercalc.json` is pinned to app ID
`umpy9re0saa7vtckd6mnprv6mc5vjgr0qh5qucs4na3qjrxrrzch` and package ID
`da9d64ca90e51cdf2643c3271f9ee9b1`.

The smoke test exercises the behavior used by `apps/interfaces/ethercalc.json`:

- `PUT /_/<sheet>` with `text/csv` returns `201` (accepted by the interface's
  `200|201|202` status set) and replaces the sheet.
- `GET /_/<sheet>/csv` returns CSV.
- `GET /_/<sheet>/csv.json` returns an array of arrays of display strings.
- SocialCalc export from `GET /_/<sheet>` imports through
  `PUT /_/<sheet>` with `text/x-socialcalc`; the round trip preserves cells.
- A formula cell `=1+2` exports through CSV/CSV-JSON as the display string `3`.
- There is still no compare-and-swap or safe automatic retry contract.

Material upstream changes are the TypeScript/workerd runtime, SQLite-backed
Durable Object persistence, the multi-sheet default workbook (`sheet` with its
TOC), built-in legacy dump migration, private-room/passkey support (not enabled
by the grain launcher), and release security hardening. Command batches now have
a 200,000-cell declared-area limit and can return `413`; the existing interface's
8 KiB CSV writes do not approach that limit. The three legacy routes and their
response shapes used by Mini are preserved. On 2026-10-29 the signed package
passed Mini's install/share/start/enrol/page lifecycle and the declaration's
typed CSV write/read-back on hbox; its installed descriptor lists `web` and `api`.
