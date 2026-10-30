# Audit: the door's vendored Solana SDK (web3.js, wallet.js, pay page)

Target: `/Users/ember/dev/minidregg-lanes/web-frontend` @ `43533e6d6950c9f3c2fb9ca239f46543b652d0b3`, audited read-only 2026-10-27. Question: is the upstream blob "harboring some awful oversight"? **Answer: no — it is byte-identical to the published, attested `@solana/web3.js@1.99.0` iife bundle, carries no advisory, and shows no suspicious behaviour. Two real gaps are on our side, not the blob's: the page never re-verifies the *signed* transaction against the quote, and the wallet adapter trusts whatever injects into `window` (by design).**

## 1. Identity

- `shasum -a 256 …/assets/vendor/web3.js` → `ecfdbe556175b8e7598c7b4189c5abd5b37858671bbb115799fa2b7c0b3715f4` = the pin in `VENDOR.md:9`.
- Registry metadata (`curl https://registry.npmjs.org/@solana/web3.js/1.99.0`): `dist.shasum = 864ce3fefe03b258c430e31e6672b422426821f7` (matches VENDOR.md:9's tarball sha1); `dist.integrity` sha512, **two registry signatures, and a SLSA-v1 provenance attestation** — the publish is supply-chain-attested.
- Downloaded tarball to scratch: `shasum -a 1` → `864ce3fe…` ✓; `openssl dgst -sha512 -binary | base64` → `QZYQ2T1z…DRgxow==` ✓ equals `dist.integrity`.
- Extracted and compared: `shasum -a 256 package/lib/index.iife.min.js` → `ecfdbe55…` ✓ and `cmp` → **BYTES-IDENTICAL**. The vendored file corresponds exactly to `lib/index.iife.min.js` (the header `var solanaWeb3=function(exports){…` and trailer `sourceMappingURL=index.iife.min.js.map` confirm which artifact). The `.map` is not vendored (harmless DevTools 404).
- Publish date (packument `time`): **1.99.0 = 2026-09-08T16:22:13Z**. The December 2024 compromise: 1.95.6/1.95.7 published 2024-12-03 15:10/15:20Z, patched 1.95.8 the same day 20:25Z.
- Advisory status: npm's bulk advisory endpoint (`POST /-/npm/v1/security/advisories/bulk`, versions 1.95.6/1.95.7/1.95.8/1.99.0/2.0.0) returns exactly one — **GHSA-jcxm-7wvp-g6p5** "Modified package published to npm, containing malware that exfiltrates private key material", `vulnerable_versions: ">=1.95.6 <1.95.8"`. Querying **1.99.0 alone returns `{}` — no published advisory affects it**. (Registry `dist-tags`: `latest` = 3.1.1, so 1.99.0 is the last stable of the 1.x line.)

## 2. Static red team of the vendored bundle (484,077 bytes, 19 lines, minified)

Every grep below was `rg` over the vendored file:

| Pattern | Hits | Verdict |
|---|---|---|
| `eval(` / `new Function` | 0 / 0 | clean — no dynamic code |
| `document.cookie` `localStorage` `sessionStorage` `postMessage` `sendBeacon` `importScripts` | 0 | clean — no storage/cookie/exfil-channel access |
| `XMLHttpRequest` | 0 | clean |
| `WebSocket` | 53 | **normal SDK**: the RPC subscription transport (`function WebSocket(address,options)` browser impl) plus `_rpcWebSocketHeartbeat=setInterval(()=>notify("ping"),5e3)` — pings the RPC endpoint the *caller* configured, every 5 s. No hard-coded peer. The pay flow never opens one (no subscriptions used). |
| `btoa` / `atob` | 1 / 0 | the one `btoa` base64-encodes error-code context params (`…map(encodeObjectContextEntry).join("&");return btoa(searchParamsString)`), not code or URLs. |
| `setInterval` / `setTimeout` | 1 / 7 | the heartbeat above; the timeouts are RPC retry/backoff. No phoning home. |
| string-literal `http(s)://…` | 6 | only `api.{devnet,testnet,mainnet-beta}.solana.com` (http+https), the `clusterApiUrl(cluster,tls)` defaults — **normal SDK**; our page never calls `clusterApiUrl` (it passes `quote.rpc`). |
| base64-ish blobs ≥100 chars | 0 | nothing hidden |
| `appendChild` `innerHTML` `createElement` `WebAssembly` `.src=` | 0 | clean — no DOM writes, no script/wasm injection |
| `secretKey` | 71 | all local ed25519 (noble) keypair/signature machinery (`getPublicKey(secretKey)`, `sign(msg,secretKey,options)`, `lengths={secretKey:_size…}`). `rg 'fetch.{0,300}secretKey|secretKey.{0,300}fetch'` (and the WebSocket variant) produced **no output** — no secret-key byte ever flows toward a network primitive. |
| `fetch(` sites | 2 shapes | `RpcClient` JSON-RPC to the caller's URL (`await fetch(...modifiedFetchArgs)`) and a 429 retry loop — **normal SDK**. |

## 3. What our page exposes

- The quote is embedded server-side: `mini-door.rs:254-262` writes `<script type="application/json" id="quote">` with `</` escaped (`:258`). `rpc` comes from the processor's record, rejected unless https, defaulting to `https://solana-rpc.publicnode.com` (`mini-door-process.rs:111-115`).
- Bootstrap (`mini-door.rs` `WALLET_PAGE`, lines ~127-140): `quote` parsed from that script tag, `conn = new web3.Connection(quote.rpc, "confirmed")`, then `makeDoorPay(web3, quote, {conn, fetch}).pay(wallet, say)`.
- `pay.js` hands the SDK: recipient/mint/tokenProgram/decimals/amountAtomic/memo/id validated non-empty (`:19-21`); a `TransferChecked` (discriminator 12, 8-byte LE amount, decimals byte) with keys [owner ATA (w), mint, recipient ATA (w), owner (signer)] and a Memo-v2 instruction carrying the exact memo UTF-8 (`:28-41`); feePayer=owner and a `confirmed`-level recent blockhash (`:58-61`).
- Private keys: **the page never has one.** The wallet signs; the fake-wallet test (`tests/pay-page.test.mjs:31`) uses a throwaway `Keypair` *in the test process* and asserts `tx.verifySignatures()` (`:52`).
- Guards before signing: recipient ATA must exist — the page refuses to create it (`pay.js:50-52`) — and payer balance ≥ quote amount (`:54-57`). The test asserts the full instruction shape byte-for-byte (`:39-50`) and the exact posted body (`:54-56`).
- A malicious SDK could: swap recipient/amount before signing (the wallet UI is then the only review surface), swap the RPC endpoint, or return a different signed transaction. It **cannot steal keys — none exist page-side**. Blast radius: misdirected payment or DoS, not theft.
- **Gap (ours):** `pay.js:63-65` — after `provider.signTransaction(tx)` the returned `signed` is serialized and sent (`sendRawTransaction`) with no re-check that its instructions equal the quote. Same in the test: it asserts the *built* tx, and posts whatever the (fake) wallet returned.

## 4. The wallet adapter (`assets/vendor/wallet.js`, 64 lines)

- Discovery: listens for `wallet-standard:register-wallet` (`:11`), dispatches `app-ready` rescans with 250+100 ms waits (`:12-13,54`); then legacy injections `window.talismanSol`, `window.phantom.solana`, `window.solflare`, `window.backpack`, `window.glow`, `window.solana` (`:44-49`). It trusts **any** script that injects those globals — which is the extension trust model itself; the wallet's name is shown on the button, and its own UI shows the transaction. No network, eval, storage or DOM access in the adapter.
- It serializes to the wallet with `requireAllSignatures:false, verifySignatures:false` (`:17`) and reconstructs the wallet's answer via `web3.Transaction.from(out.signedTransaction)` (`:31`) — again without re-checking instructions (same gap as §3).
- Minor: `chain` defaults to `solana:mainnet` (`:27`) even when the quote's network is devnet/testnet — the wallet is told mainnet; derive it from `quote.network`. `signAllTransactions` funnels all inputs through one `signTransaction` call (`:32`) — interop quirk, not security.

## 5. Recommendation (ranked)

1. **Keep the SDK, pinned as is.** Identity is proven byte-identical to an attested publish; no advisory covers 1.99.0; the pin is machine-checked (`vendored_assets_match_their_pins`, `mini-door.rs:589`, per `VENDOR.md:5`).
2. **Regardless, add the one check:** after `provider.signTransaction` returns (`pay.js:63`), re-decode and assert `signed.instructions` equal `instructions(owner)` — programId, key order/flags, data bytes — before `:65` sends. ~10 lines; the test already proves the machinery exists. This closes the "wallet/SDK swapped the transaction" gap, which no amount of pinning addresses.
3. *Middle option, most on-ethos:* hand-write the serializer for exactly this shape. The wire format is small — 3-byte header + compact-u16 key table + blockhash + compact-u16 instructions (programIdIndex, account indices, length-prefixed data), then compact-u16 signature list; ~200-300 lines including base58 and the sha256 needed for ATA PDA derivation. That deletes the entire 484 KB blob — RPC client, websockets, all program codecs, and every `secretKey` primitive the page never uses (it never signs).
4. `@solana/kit` minimal packages: tree-shakeable but bundler/ESM-shaped; the door serves static files from a no-egress box with no build step, so the single pinned blob fits better.

**Bottom line for the owner:** the blob is exactly what npm published, attested and advisory-free; it can't exfiltrate anything this page doesn't have. The two things worth changing are ours: the post-signing re-decode assert (§5.2) and the adapter's mainnet chain default (§4).
