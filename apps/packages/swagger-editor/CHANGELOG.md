## 5.10.0-2

- The grain's specification is stored server-side: `PUT /editor/spec`
  replaces it (1 MiB bound), `GET /editor/spec` reads it back byte-exact,
  persisted under `/var`. This is the beneath-HTML data API the interface
  declaration (`apps/interfaces/swagger-editor.json`) binds, the role the
  2016 Sandstorm port's service played; the editor loads it with
  `/?url=/editor/spec`. Browser session state is unchanged.

## 5.10.0-1

- Repackaged from upstream Swagger Editor v5.10.0 (released 2026-10-21).
- Serves the upstream Vite build statically over the Sandstorm 308 HTTP
  bridge; `bridgeConfig.apiPath = "/"` exposes an `api` interface next to
  `web`.
- Sourcemaps (`*.map`, ~65 MiB) are excluded from the package; the
  tree-sitter wasm parsers under `node_modules/` are runtime dependencies
  and are kept.
