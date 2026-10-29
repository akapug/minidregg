# DokuWiki SPK recipe

This recipe packages the maintained DokuWiki 2026-07-14c release for Mini/Sandstorm. It uses johnbintz's Sandstorm adapter at commit `180dd4343573ff0b3af78b1daea42793b471bf87` as the integration base, not as a source of old application code or runtime binaries.

## Inputs and runtime

`sources.json` records the official release archive and digest, adapter commit and Sandstorm 308 toolchain evidence. The build constructs an x86_64 Debian 13 rootfs with PHP 8.4 and nginx. Exact Debian package versions are written to `logs/debian-package-versions.txt`; private keys and SPKs stay outside the repository.

The Sandstorm authentication plugin now uses the current namespaced DokuWiki extension API and JSON files beneath `/var`, replacing the old PHP 7 LevelDB dependency. Configuration, pages, media, plugins and templates are mutable beneath `/var`; application code stays in the read-only package. `bridgeConfig.apiPath` is `/`, so descriptor inspection exposes both `api` and `web`.

## Build on dregg-forge

Copy this directory to `/srv/spk-build/dokuwiki/recipe`. Keep the app key at `/srv/spk-build/dokuwiki/dokuwiki.key` (0600), backed up at `/Users/ember/.dregg-secrets/spk-keys/dokuwiki.key`, and its public keygen output at `/srv/spk-build/dokuwiki/app-id`. Then run:

```sh
nohup bash /srv/spk-build/dokuwiki/recipe/build.sh \
  > /srv/spk-build/dokuwiki/logs/build.log 2>&1 < /dev/null &
echo $! > /srv/spk-build/dokuwiki/logs/build.pid
```

The build checks the pinned archive, syntax-checks the integration, runs a direct authenticated form edit and exact raw-page read-back smoke, then packs and verifies the signed SPK. The direct smoke is not a substitute for Mini lifecycle qualification.

## Mini qualification

On hbox, arrange a lane with the repository at `src/`, the pinned Mini binaries at `bin/`, and the candidate at `cache/f6af420324fd459439330089819c9c27.spk`. Run `apps/packages/dokuwiki/qualify.sh <lane> <lane>/cache <attempt>` from this recipe. It holds the world-up lock only around world creation, stops the grain after its write, and tears the world down on every exit. A passing run requires both lifecycle rows and an installed descriptor containing `api` and `web`.

## Mini interface

The existing `apps/interfaces/dokuwiki.json` `page.read` operation uses `doku.php?do=export_raw` and remains the compatibility contract. Mini qualification separately performs the current edit form's authenticated POST beneath the HTML and reads the raw page back exactly. This is a new app ID and does not migrate grains signed by the old DokuWiki app ID.
