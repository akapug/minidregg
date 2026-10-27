# Vendored browser assets of the door

The door page loads no third-party script at runtime (the box has no egress). These files are
served by `mini-door` under `/join/assets/`, pinned by version and sha256; update a file and this
table together. `mini-door`'s `vendored_assets_match_their_pins` test re-checks the column.

| file | source | version | tarball sha1 (npm) | file sha256 |
|---|---|---|---|---|
| `web3.js` | `@solana/web3.js` `lib/index.iife.min.js` | 1.99.0 | `864ce3fefe03b258c430e31e6672b422426821f7` | `ecfdbe556175b8e7598c7b4189c5abd5b37858671bbb115799fa2b7c0b3715f4` |
| `wallet.js` | ember's sol-misc `docs/passwap/wallet.js` (three header lines added) | 2026-10-27 | — | `ac2b4d8fe50f87c5ab9fa5c8cb50ee0a6030a9b454c997cfc0c5608979727d49` |

License: `@solana/web3.js` MIT (`LICENSE.solana-web3`); the adapter is ember's own.
