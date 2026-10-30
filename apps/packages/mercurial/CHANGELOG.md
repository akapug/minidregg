# Mercurial (hgweb) — Sandstorm repackaging

## 7.2.4-1 (2026-10-29)

- Repackaged from upstream Mercurial 7.2.4 (official release tarball) with
  CPython 3.13.5, built for the Sandstorm 308 platform.
- hgweb served over sandstorm-http-bridge; the hg wire protocol (clone, push,
  archive) is exposed as the grain's `api` interface via bridgeConfig
  apiPath "/", so agents can work beneath the HTML.
