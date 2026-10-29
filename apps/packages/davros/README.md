# Davros package

Builds Davros 0.33.4 from the maintained source snapshot recorded in
`upstream.json`, using the Sandstorm 308 toolchain on `dregg-forge`. The upstream
manifest already declares `bridgeConfig.apiPath = "/"`; the build asserts that
this remains true so the installed descriptor exposes both `web` and `api`.
The new app ID cannot use upstream's old-ID-bound PGP statement, so the package
records Michael Nutt as `upstreamAuthor` and omits that signature and keyring.

The build uses a dedicated Debian 13 `systemd-nspawn` rootfs, limited to 4 GB
RAM. Upstream's own `.sandstorm/setup.sh` and `.sandstorm/build.sh` install and
compile the application. Built SPKs and private keys stay outside the repo.

One-time identity setup on `dregg-forge` (the custom keyring must not already
exist):

```sh
mkdir -p /srv/spk-build/davros/keyhome
HOME=/srv/spk-build/davros/keyhome /var/lib/spk-fresh/tools/spk keygen \
  > /srv/spk-build/davros/app-id
mv /srv/spk-build/davros/keyhome/.sandstorm-keyring \
  /srv/spk-build/davros/davros.keyring
chmod 600 /srv/spk-build/davros/davros.keyring
```

Export the keyring to `~/.dregg-secrets/spk-keys/davros.key` with mode 0600,
then run `apps/packages/davros/build.sh` on `dregg-forge` as root. The signed
package is `/srv/spk-build/davros/out/davros.spk`; `verified-app-id` records the
`spk verify` result. Re-running the recipe reuses the rootfs and dependency
cache, checks out the exact commit, and repacks with the same application ID.

## Qualification

On 2026-10-29, package `5485d227d04a1af26e08358dcb92accf` passed
`featured-qualify.sh` on hbox with 2/2 rows: create, install, share, start,
enrol, `GET /`, and the declaration-driven WebDAV directory/file write, move,
exact read-back and listing sequence. The installed descriptor exposed both
`web` and `api`, and the qualification world was torn down cleanly. The
qualified declaration's canonical SHA-256 is recorded in `upstream.json`.
