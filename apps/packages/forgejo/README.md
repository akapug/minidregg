# Forgejo SPK reproducibility recipe

This recipe packages the official Forgejo **17.0.1** Linux x86_64 release as the maintained successor to Gogs. It vendors neither upstream source nor a private key. The source archive supplies the upstream license and logo; the binary contains Forgejo's web assets and SQLite support.

## Pinned inputs and runtime

- Forgejo release tag `v17.0.1`, published 2026-10-26; binary and source archive SHA-256 values are in `upstream.json` and checked by `build.sh`.
- Sandstorm **308** supplies `spk`, the Cap'n Proto schemas, and `sandstorm-http-bridge`.
- dregg-forge's Debian 13 Git **2.47.3**, Bash, Dash, and the small coreutils set used by the launcher and Forgejo's generated Git hooks are copied into an app-local rootfs with their closed dynamic-library dependency set. No host system directory is recursively packaged.
- The legacy `cem/gogs-sandstorm` revision recorded in `upstream.json` is a configuration reference only, not a build input.

The manifest sets `bridgeConfig.apiPath = "/"` and enables Forgejo reverse-proxy authentication for web and API requests. Only an editor role is offered: Forgejo does not enforce Sandstorm's `X-Sandstorm-Permissions` header, so advertising a read-only viewer role would be incorrect.

## Build

Work only under `/srv/spk-build/forgejo` on dregg-forge. Keep the new keyring at `forgejo.key` with mode 0600 and its offline backup at `/Users/ember/.dregg-secrets/spk-keys/forgejo.key`; never print or commit either copy. The public output of `spk keygen` belongs in `app-id` and must be `3g05nj7mpryyd3a0erndy30my7fsr72s3xghnhewkqw7km08g34h`.

Copy this directory to `/srv/spk-build/forgejo/recipe`, then run:

```sh
ssh dregg-forge 'bash /srv/spk-build/forgejo/recipe/build.sh'
```

The script verifies pinned inputs, stages the rootfs, starts that rootfs in a chroot as an unprivileged UID inside a private mount namespace, and performs an HTTP write/read-back scenario on an isolated smoke port. The scenario matches the Gogs-compatible declaration: user identity, repository creation, issue creation, comment creation, and exact issue/comment reads. Only after that gate does it sign `out/forgejo.spk` with Sandstorm 308 and write verification details and checksums under `out/`.

This direct smoke gate does not replace Mini qualification: install, start, the generated `api` descriptor, and the declaration-driven write/read-back still have to pass on a standing world.

## Mini qualification

`qualify.tsv` and `qualify-writes/forgejo.sh` form an app-owned batch for `scripts/spk-platform/featured-qualify.sh`. On hbox, prepare a fresh mode-0700 lane whose `src` and `bin` point at the current source and built platform binaries, and place the candidate in a quarantine directory as `a7e86129810afc3d9e498fbc0232c639.spk`. Then run:

```sh
bash apps/packages/forgejo/qualify.sh /home/hbox/spk-fresh-forgejo /tank/lanes/spk-fresh-forgejo/cache 1
```

Use a new attempt number for each run. The wrapper holds `/tank/lanes/world-up.lock` only around world creation, stops the grain after its write, and tears the world down on every exit. A passing row requires both the declaration-driven repository/issue/comment scenario and an installed `descriptor-inspection.json` containing `api` and `web`; the descriptor is copied into the qualification output.
