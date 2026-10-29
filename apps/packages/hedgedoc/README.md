# HedgeDoc Sandstorm package

This recipe packages the official HedgeDoc 1.12.0 stable release for Sandstorm.
It uses the upstream release archive's prebuilt web assets, Node 22.23.4 LTS,
and production dependencies resolved by the patched upstream Yarn lockfile.

## Pinned inputs

- Upstream release: <https://github.com/hedgedoc/hedgedoc/releases/tag/1.12.0>
- Upstream tag commit: `b9335040716278d029b5872e3825b92821d9cb70`
- Source: <https://github.com/hedgedoc/hedgedoc/releases/download/1.12.0/hedgedoc-1.12.0.tar.gz>
- Source SHA-256: `e84c4ea2e635a84f8a3d77e2a1797e01ecbe695ae1277724af2ce7e6aa40b6e5`
- Node: <https://nodejs.org/dist/v22.23.4/node-v22.23.4-linux-x64.tar.xz>
- Node SHA-256: `1805bcd35e6815559bd2eb97db438d3fdb0eb3a5e6a977b7c1badca76337e9ce`
- Original Sandstorm adaptations: <https://github.com/zenhack/sandstorm-hedgedoc>
  at commit `1d9fc22fab810519b7771bcf83ac0bb8eca08af2`.

The patch retains upstream `POST /new` and `POST /new/:noteId` markdown creation
(for `text/plain` and `text/markdown` bodies) and `GET /<note>/download`
markdown export. Named-note creation is enabled in the production configuration
for the declaration-driven API. The patch changes only Sandstorm process
compatibility, single-note navigation, authentication, and hiding extra
new-note controls. HedgeDoc 1.12.0 requires Node 20.17 or newer; the previous
package's Node 16 toolchain is therefore not reused.

## Reproduce on dregg-forge

Keep the signing key outside the repository. The recipe expects it at
`/var/lib/spk-fresh/apps/hedgedoc/hedgedoc.keyring`, with the offline backup at
`/Users/ember/.dregg-secrets/spk-keys/hedgedoc.key` (mode 0600), and the
PGP-verified `spk` tool at `/var/lib/spk-fresh/tools/spk`.

```sh
scp -r apps/packages/hedgedoc dregg-forge:/var/lib/spk-fresh/apps/hedgedoc/recipe
ssh dregg-forge /var/lib/spk-fresh/apps/hedgedoc/recipe/build.sh
```

The script works only below `/var/lib/spk-fresh/apps/hedgedoc` by default,
uses no global package installation, verifies both pinned archives, installs
production modules into the build tree, copies runtime shared-library
dependencies and the ELF interpreter into the package, and writes:

- `/var/lib/spk-fresh/apps/hedgedoc/out/hedgedoc.spk`
- `/var/lib/spk-fresh/apps/hedgedoc/out/verify.txt`
- `/var/lib/spk-fresh/apps/hedgedoc/out/sha256.txt`

Set `WORKDIR` to relocate a build. A clean build replaces only the generated
`build/source`, `runtime/node`, `runtime/loader`, and `package` directories
below `WORKDIR`.

## Mini qualification

`qualify.tsv` and `qualify-writes/hedgedoc.sh` form an app-owned batch for
`scripts/spk-platform/featured-qualify.sh`. On hbox, prepare a fresh mode-0700
lane whose `src` and `bin` point at the current source and built platform
binaries, and place the candidate in a quarantine directory as
`8452968c1fc59a324106009faa14dedd.spk`. Then run:

```sh
bash apps/packages/hedgedoc/qualify.sh /tank/lanes/spk-fresh-hedgedoc /tank/lanes/spk-fresh-hedgedoc/cache 1
```

Use a new attempt number for each run. The wrapper holds
`/tank/lanes/world-up.lock` only around world creation, stops the grain after
its write, and tears the world down on every exit. A passing row requires the
declaration-driven named-note create and exact markdown read-back, plus an
installed `descriptor-inspection.json` containing both `api` and `web`.
