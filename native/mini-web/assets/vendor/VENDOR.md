# Vendored browser assets

The page loads no third-party script at runtime (the box has no egress, and the CSP names only
`'self'`). These files are copied once from the npm registry tarballs, pinned by version and
SHA-256, and served by the gateway under `/assets/vendor/`. Update by replacing the file and this
table together.

| file | package | version | tarball sha1 (npm) | file sha256 |
|---|---|---|---|---|
| `xterm.js` | `@xterm/xterm` | 5.5.0 | `275fb8f6e14afa6e8a0c05d4ebc94523ff775396` | `1f991ac3b4b283ebf96e60ae23a00a52765dd3a2e46fa6fdda9f1aab032f7495` |
| `xterm.css` | `@xterm/xterm` | 5.5.0 | (same tarball) | `ba8e6985669488981ccf40c0cefe3aba80722cb6c92de7ad628b0bd717faf2b6` |
| `addon-fit.js` | `@xterm/addon-fit` | 0.10.0 | `bebf87fadd74e3af30fdcdeef47030e2592c6f55` | `bdaefa370b1bfc42ee88d46fe6072400902a4d4b2d45cd93438dda9b23c97089` |

License: MIT (`LICENSE.xterm`). `scripts/check-vendor.sh` in this directory's crate re-checks the
sha256 column; the gateway's `assets` test does the same at build time.
