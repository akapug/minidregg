# ntfy (sntfy adapter) package

Builds the maintained Sandstorm adapter's `v2.34.0-sandstorm-20` tag, based on
ntfy v2.34.0, using the Sandstorm 308 toolchain on `dregg-forge`. The exact
source commit and package identities are recorded in `upstream.json`.

The adapter already declares `bridgeConfig.apiPath = "/"`; the build asserts
that this remains true so the installed descriptor exposes both `web` and
`api`. The new app ID cannot use upstream's old-ID-bound PGP statement, so the
build removes that signature and keyring while retaining the adapter contact
and upstream author metadata.

The build uses a dedicated Debian 13 `systemd-nspawn` rootfs, limited to 6 GB
RAM. Upstream's `.sandstorm/setup.sh` installs its Node and checksum-pinned Go
toolchains, and `.sandstorm/build.sh` builds the web UI and static Linux
binary. Built SPKs and private keys stay outside the repository.

One-time identity setup on `dregg-forge` (the custom keyring must not already
exist):

```sh
mkdir -p /srv/spk-build/ntfy/keyhome
HOME=/srv/spk-build/ntfy/keyhome /var/lib/spk-fresh/tools/spk keygen \
  > /srv/spk-build/ntfy/app-id
mv /srv/spk-build/ntfy/keyhome/.sandstorm-keyring \
  /srv/spk-build/ntfy/ntfy.key
chmod 600 /srv/spk-build/ntfy/ntfy.key
```

Export the keyring to `~/.dregg-secrets/spk-keys/ntfy.key` with mode 0600,
then run `apps/packages/ntfy/build.sh` on `dregg-forge` as root. The signed
package is `/srv/spk-build/ntfy/out/ntfy.spk`; `verified-app-id` records the
`spk verify` result. Re-running the recipe reuses the rootfs and dependency
cache, checks out the exact tag commit, and repacks with the same application
ID.

## Qualification

On 2026-10-29, package `f1570de10690a0de3af76437ad836cd0` passed
`featured-qualify.sh` on hbox with 2/2 rows: create, install, share, start,
enrol, `GET /`, and the declaration-driven `notifications.publish` followed by
`notifications.poll` exact read-back. The installed descriptor exposed both
`web` and `api`, and the qualification world was torn down cleanly. The
qualified declaration's canonical SHA-256 is recorded in `upstream.json`.
