# Vendored browser assets of the door

The door page loads no third-party script at runtime (the box has no egress). These files are
served by `mini-door` under `/join/assets/`, pinned by version and sha256; update a file and this
table together. `mini-door`'s `vendored_assets_match_their_pins` test re-checks the column.

| file | source | version | tarball sha1 (npm) | file sha256 |
|---|---|---|---|---|
| `web3.js` | `@solana/web3.js` `lib/index.iife.min.js` | 1.99.0 | `864ce3fefe03b258c430e31e6672b422426821f7` | `ecfdbe556175b8e7598c7b4189c5abd5b37858671bbb115799fa2b7c0b3715f4` |
| `wallet.js` | ember's sol-misc `docs/passwap/wallet.js`, with header lines and one change: `list(web3, { chain })` asks for the quote's cluster (audit INTEGRITY 7) | 2026-10-27 | — | `f59eeaabf3c9b5d2d40a882bad8d825287dd8a70b1f1a5e84afd636728bcc922` |

License: `@solana/web3.js` MIT (`LICENSE.solana-web3`); the adapter is ember's own.
