# Wekan package

Packages the maintained upstream's signed Wekan 12.68 Sandstorm release under a
new minidregg application identity, using the pinned Sandstorm 308 `spk` tool on
`dregg-forge`. This is the current 2026-10-29 release artifact, not the stale
store package. The build verifies both pinned artifact hashes and the upstream
SPK signature, takes the package definition from the same tagged source, removes
the old-ID-bound PGP statement, preserves `bridgeConfig.apiPath = "/"`, and packs
a fresh SPK. The installed descriptor therefore exposes both `web` and `api`.

`upstream.json` records the exact source and binary inputs, output identity and
canonical declaration digest. Built packages and private keys stay outside the
repository. The key backup is `~/.dregg-secrets/spk-keys/wekan.key` (0600).

On `dregg-forge`, copy this directory to `/srv/spk-build/wekan/recipe`, keep the
key at `/srv/spk-build/wekan/wekan.keyring`, and its public keygen output at
`/srv/spk-build/wekan/app-id`. Then run:

```sh
bash /srv/spk-build/wekan/recipe/build.sh
```

The signed output is `/srv/spk-build/wekan/out/wekan.spk`; `verify.txt`,
`verified-app-id` and `wekan.spk.sha256` record its verification.

## Qualification

Copy the package to an hbox lane's cache as `<packageId>.spk`, update
`apps/interfaces/wekan.json`, install `app-interface/requirements.txt` in
`<lane>/venv`, and run `qualify.sh <lane> <cache> 1`. The recipe
selects `market-large-v1` (the decoded archive is about 849 MiB, above the
standard 768 MiB profile) and uses `featured-qualify.sh` for create, install,
share, start, enrol and page load,
then the declaration-driven DDP scenario creates a board, list, swimlane and card
and requires exact card read-back. It also checks the installed descriptor for
both API kinds and tears down its world.
