# Datasette SPK reproducibility recipe

This directory contains only the app-owned Sandstorm adaptations and lock data; upstream source is not vendored.

## Pinned inputs

- Datasette **0.65.5**, tag `0.65.5`, commit `fec885fb291ffc05c80f15c5f20bb3bb67719320`. This is the latest non-draft, non-prerelease release reported by the upstream GitHub repository and the current version on PyPI at selection time.
- `datasette-sandstorm-support` **0.2**, commit `9d2eafe1345c4aa1ae6355d511286801be8be8ff`, retained for Sandstorm actor and permission headers.
- Packaging adaptations are based on `ocdtrekkie/datasette-sandstorm` commit `1bd5e39c2cecbf4e99dd007474ad60a60aecb9ce`; the logo comes from that revision.
- `requirements.lock` pins every installed wheel, including transitive dependencies, by version and SHA-256. `upstream.json` records primary source URLs and the Datasette wheel, source archive, and support-plugin checksums.

The package targets CPython 3.13 on Linux x86_64, matching dregg-forge. It installs nothing globally and writes only below `/var/lib/spk-fresh/apps/datasette` on that host.

## Build

The new app key must already exist at `/var/lib/spk-fresh/apps/datasette/datasette.keyring` with mode 600. Keep its offline backup at `/Users/ember/.dregg-secrets/spk-keys/datasette.key` with mode 0600; never print or commit either copy.

Copy this directory to `/var/lib/spk-fresh/apps/datasette/recipe` on dregg-forge, then run:

```sh
ssh dregg-forge 'bash /var/lib/spk-fresh/apps/datasette/recipe/build.sh'
```

The script downloads only pinned inputs, builds an app-local root filesystem, runs the service from a chroot with a real SQLite fixture, checks the JSON interfaces, and uses Sandstorm 308's verified `spk` tool to sign and verify `out/datasette.spk`. It leaves verification output, response samples, the UTC build date, and the full SPK SHA-256 under `out/`.

## HTTP compatibility and deliberate scope

The smoke gate preserves these interfaces used by `apps/interfaces/datasette.json`:

- `GET /-/versions.json`: the `datasette.version` field is `0.65.5`.
- `GET /-/databases.json`: remains a JSON array of database objects.
- `GET /<db>.json?sql=...&_shape=objects&_size=1000`: retains the route and query parameters. Upstream returns an object envelope whose `rows` member is the array of row objects. `_shape=array` returns that bare array instead and is covered by the smoke gate too.

No relevant route or response-shape change was found in the upstream 0.63-to-0.65.5 changelog. In particular, the 0.63 and 0.65.5 renderer sources both give `_shape=objects` the envelope behavior, so the shared declaration's bare-array `sql.query` output schema does not match either upstream version. Consumers that need a bare array can deliberately use `_shape=array`. Dependency/version details in `/-/versions.json` naturally reflect the new runtime.

This package deliberately has a read-only HTTP surface. It does not install the old upload, insert, upsert, or general write plugins. The declaration exposes only version, database-list and read-only SQL operations; `sql.query` deliberately requests `_shape=array` to match its bare-array output schema. Qualification records the version and database-list reads beneath the HTML rather than claiming a write.

## Mini qualification

`qualify.tsv` and `qualify-writes/datasette.sh` form an app-owned batch for `scripts/spk-platform/featured-qualify.sh`. On hbox, prepare a fresh mode-0700 lane whose `src` and `bin` point at the current source and built platform binaries, and place the candidate in a quarantine directory as `daafe47b15e9c8659cff5236746e5506.spk`. Then run:

```sh
bash apps/packages/datasette/qualify.sh /tank/lanes/spk-fresh-datasette /tank/lanes/spk-fresh-datasette/cache 1
```

Use a new attempt number for each run. The wrapper holds `/tank/lanes/world-up.lock` only around world creation, stops the grain after its read-only API checks, and tears the world down on every exit. A passing row requires Datasette 0.65.5's version response, a JSON database list, and an installed `descriptor-inspection.json` containing `api` and `web`; the descriptor is copied into the qualification output.
