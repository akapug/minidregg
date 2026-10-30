# MediaWiki SPK recipe

This recipe packages the full maintained MediaWiki 1.46.2 release for Mini/Sandstorm. It uses zenhack's Sandstorm adapter at commit `e15a742e99ffb75b7e46ce680a0120d42bbb03e6` as the integration base, not as a source of old application code or runtime binaries.

## Inputs and runtime

`sources.json` records the official archive, its SHA-256, adapter commit and Sandstorm 308 toolchain evidence. The build constructs an x86_64 Debian 13 rootfs with PHP 8.4, nginx, ImageMagick and MediaWiki's PHP extensions. Exact Debian package versions from each build are written to `logs/debian-package-versions.txt`; private keys and SPKs stay outside the repository.

The Sandstorm adaptations keep the release's Composer-provided dependencies and the adapter's loaded upstream extensions (CodeEditor, WikiEditor and ParserFunctions), while excluding unactivated bundled extensions and upstream test payloads. They replace the old PHP 7.3 RDBMS calls in `SandstormAuth`, preserve stable Sandstorm identities and permissions, store every mutable resource below `/var`, and initialize a fresh SQLite wiki. `bridgeConfig.apiPath` is `/`, so package inspection exposes both `api` and `web`.

## Build on dregg-forge

Copy this directory to `/srv/spk-build/mediawiki/recipe`. Keep the app key at `/srv/spk-build/mediawiki/mediawiki.key` (0600), backed up at `/Users/ember/.dregg-secrets/spk-keys/mediawiki.key`, and its public keygen output at `/srv/spk-build/mediawiki/app-id`. Then run:

```sh
nohup bash /srv/spk-build/mediawiki/recipe/build.sh \
  > /srv/spk-build/mediawiki/logs/build.log 2>&1 < /dev/null &
echo $! > /srv/spk-build/mediawiki/logs/build.pid
```

The build checks the pinned archive, applies checked source adaptations, creates the initial database, syntax-checks the integration and runs a direct authenticated API create/read-back smoke before packing. It then runs `spk verify --details` and writes the artifact and evidence under `out/` and `logs/`. The direct smoke is not a substitute for Mini lifecycle qualification.

## Mini interface

The existing `apps/interfaces/mediawiki.json` operations target `api.php` and remain the compatibility contract: identity and CSRF reads, page create, revision-aware update, parse and exact wikitext read-back. Qualification must run those operations through Mini's member route after installing and starting the new package. This is a new app ID and does not migrate grains signed by the old MediaWiki app ID.
