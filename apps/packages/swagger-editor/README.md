# Swagger Editor (Sandstorm package)

Repackage of upstream [Swagger Editor](https://github.com/swagger-api/swagger-editor)
v5.10.0 as a self-contained Sandstorm 308 grain. Replaces the 2016 store
package (2.10.4).

## Shape

Upstream v5 is a Vite/React single-page editor that builds to static assets
(`npm run build:app`; output in `build/`). The grain serves that tree with
`static-server.js` (Node 24, stdlib only — no framework) behind the Sandstorm
HTTP bridge; `bridgeConfig.apiPath = "/"` exposes an `api` interface next to
`web`. Sourcemaps (`*.map`) are excluded at pack time; the tree-sitter wasm
parsers under `node_modules/` are runtime dependencies and stay. The app is
stateless — specs live in the browser session — so the grain writes nothing
to `/var`.

## Artifacts (dregg-forge)

- Build root: `/srv/spk-build/swagger-editor` (source, build log, pack dir,
  out, pids — see `spk-notes/swagger-editor.md`).
- Signing key: `/Users/ember/.dregg-secrets/spk-keys/swagger-editor.key`
  (0600, never printed or committed); working copy
  `/srv/spk-build/swagger-editor/swagger-editor.keyring`.
- App ID: `xm16d84ksseg44ef58z7n2aw7qt1n6psk0cewzr0e0arfjk5r4fh`
  (derived from the signing key; recorded here because FEATURED pins it).

## Notes

- The icon is a drawn stand-in: the upstream tarball ships no SVG mark, only
  a 32px PNG favicon. Swap `branding/swagger-editor.svg` for the official
  mark if one lands upstream.
- `build.sh` runs on dregg-forge as root from this recipe directory; it
  asserts the keyring matches the app ID above before packing.
