# Correctness review: the door's "Pay with your wallet" page

Lane tree `/Users/ember/dev/minidregg-lanes/web-frontend` @ 43533e6d (branch lane/web-frontend). Read-only; experiments ran the vendored `web3.js` bundle under node with fake inputs (no network); the only network use was registry.npmjs.org and github.com for SDK versioning. Verdicts: **OK / BUG / UNVERIFIED**.

## 1. AMOUNT — OK (one display gap)

`amountAtomic` is a **string** end to end: `join_solana_v2.rs:567` writes `quote.split().amount_atomic.to_string()`; the door copies it verbatim (`mini-door-process.rs:738`); the page parses `BigInt(quote.amountAtomic)` (`assets/pay.js:23`) and writes the u64 little-endian by hand into the TransferChecked data (`pay.js:31-33`). No `Number()` ever touches it. Experiment (`exp1.mjs`): with `amountAtomic = "9007199254740993"` (2^53+1) the bytes through `Transaction.serialize()` are exact; `decimals` byte = 6. `pay-page.test.mjs` asserts the same. Displayed "Pay exactly 50000007 atomic units" (`mini-door.rs:272`) is the same string that is signed. **BUG (minor)**: `mini-door.rs:273` renders `p["amountTokens"]`, a field nothing writes (only occurrence in the tree), so the human-readable amount renders as an empty parenthesis — the stranger must convert 50.000007 DREGG themselves.

## 2. ACCOUNTS — OK

ATA derivation includes the token program (`pay.js:26`: `[owner, tokenProgram, mint]`, `ATokenGPvbd…`), correct for both Token and Token-2022; `tokenProgram` comes from the deployment pin, not a guess (`mini-door-process.rs:733`, hex→base58). TransferChecked account order (source, mint, destination, authority) matches SPL Token and is asserted by the test. The recipient ATA is **checked, never created** (`pay.js:50-52`), and the test proves nothing is signed when it is missing. Trigger if it were missing: page names the refusal and points at the paste path — safe. Install-side guarantee that the enrol ATA exists is not a step in `deploy/pay/README.md` — **UNVERIFIED** (page-side check makes it non-lossy). Sender with no token account or low balance gets a named message with wallet address and both amounts (`pay.js:54-57`). Note: only the owner's *ATA* is paid from; tokens held in an auxiliary token account read as "no account" — honest message, mild UX limit.

## 3. MEMO — OK

The page writes `TextEncoder().encode(quote.memo)` — the exact string, UTF-8, **no trailing newline** (`pay.js:25`); the test asserts byte equality with the quote. The memo itself is assembled and verified kernel-side (`pay_memo_v2.rs:556-557`, `SignedMemo::parse_and_verify`), so what the page holds is already the canonical bytes; the door appends `\n` only to the ssh armour file (`mini-door.rs` POST handler), before assembly. Memo program written: v2 `MemoSq4gq…` (`pay.js:18`) — correct id; the watcher reads v1+v2 and reports bytes **verbatim** (`pay-watcher/src/memo.rs:44-48`, `MEMO_PROGRAMS`), never re-parsing. The memo must ride the *same* transaction as the transfer (fixture `enrol-memo-other-tx`: memo in a transfer-less tx → `zeroDelta`, no join). A wallet that dropped the memo (none do; they sign the page's bytes) would surface as `memoMissing` → the 7-day "not seen" message — observable, not silent.

## 4. TIME — BUG (medium): stale quote has no client-side guard

Blockhash is fetched immediately before signing (`pay.js:60-63`); a user who sits minutes in the wallet gets `BlockhashNotFound` on send, a named error, buttons re-enabled — OK. The quote's `expiryHour` is chain-hour+1 at handout (`join_solana_v2.rs:316-321`); the kernel refuses an expired quote at observation (`Kernel/PayClaimQuote.lean:240` `if terms.expiryHour < tip.hour then .error .expired`), which becomes a *pending claim*, and the door answers "the payment did not enrol this account … Ember can comp a journalled payment" (`mini-door-process.rs:756-759`). **Trigger**: load the pay page, leave the tab open three hours, click Pay — the transaction lands on mainnet, enrolment does not. The page shows "before chain hour N" (`mini-door.rs:275`) but never checks staleness; it has `expiryHour` but not the current chain hour. After a successful send the page says the door decides within a minute and reloads at 65 s (`WALLET_PAGE`, mini-door.rs:137-139) onto a status page that names the waiting state — not silent.

## 5. CLUSTER — OK

`quote.rpc` is server-controlled (`mini-door-process.rs:111-115`, default `https://solana-rpc.publicnode.com` on mainnet; `pay.network` must be mainnet|devnet, `mini-door-process.rs:107-109`); the page builds its own connection (`WALLET_PAGE`: `new web3.Connection(quote.rpc, "confirmed")`) and sends itself, so the wallet's selected cluster cannot redirect the payment; a devnet wallet simply fails the mainnet balance check with the named message. No wrong-cluster send path exists. Note: the default is a public third-party RPC — a 429 there shows as a raw error, and publicnode sees strangers' transactions (any RPC does).

## 6. IDEMPOTENCY AND RETRY — BUG (highest harm): the POST result is ignored

`pay.js:66-69` posts the signature and returns `{status: res.status}`; the page never looks at it and always says "Sent and posted: …". But the door refuses: a repeated step is 409 "this step was already submitted" (`door.rs:367-368`, `O_EXCL` spool), and the per-IP budget is **3 POSTs/hour by default** (`mini-door.rs:437`, `MINI_DOOR_POSTS_PER_HOUR`) — the happy path alone consumes all three (`/join`, `/join/sign`, `/join/paid`). **Trigger**: two strangers behind one NAT (or one person reloading and resubmitting) → the 4th POST is 429 → the page still claims "Sent and posted" → the 65 s reload shows the *awaiting-payment* page again → the stranger quite reasonably pays a second time. Also: if `sendRawTransaction` succeeds but the POST throws (network), the catch shows the error **without the signature**, buttons re-enable, and the natural next action is Pay again — a genuine second on-chain payment. The back-ends are sound: the door binds one memo to one signature (`join_solana_v2.rs:731-743` `retain_json`, refusing a differing one with "differs from retained" → comp message), the kernel's tick nullifier prevents double credit, so a double payment is money paid twice for one enrolment — stuck until ember comps it.

## 7. SIGNATURE HANDLING — OK

The posted string is format-checked (base58, 64 bytes: `door.rs:118-119,244-245`); the door does not verify it against the transaction and does not need to — the kernel consumes only the watcher's finalized observations, and `join --wait --signature` looks the exact signature up through the Host (`join_solana_v2.rs:744-816`), matching amount against the retained record (`:778`), the SSH key and subject. Commitment: every watcher RPC call asks `finalized`, and the fixture transport *proves* each request does (`transport.rs:79-131`), so a confirmed-then-dropped transaction can never enter. The door waits `--timeout 5` per processor tick and retries until 7 days (`PAID_TTL_S`, `mini-door-process.rs:31,611,761`).

## 8. FEES — OK (message is jargon)

`feePayer = owner` (`pay.js:59`); the page does not pre-check SOL, so a user with DREGG but no SOL gets the RPC's "insufficient lamports … for fee" simulation failure in the status line — shown, but raw. No priority-fee instruction: fine for a 2-instruction transaction; if congestion strands it unconfirmed nothing lands and nothing is lost.

## 9. ERRORS AND UI — OK apart from §6

Every throw in `pay()` carries a named message (missing recipient ATA, no/low balance, quote field gaps); the page catch prints `e.message` and re-enables buttons; a failure to start keeps the paste path alive (`WALLET_PAGE` catch). The paste path is a plain form, always rendered (`mini-door.rs:278-281`), and `<noscript>` says so (`:270`); a no-JS visitor can still pay from any wallet that can build the transfer itself. Wallet discovery covers Wallet Standard and legacy injections (`wallet.js:41-51`); deep-link-only mobile wallets without injection fall back to paste. The empty `amountTokens` parenthesis is §1.

## 10. THE SDK (vendored 1.99.0) — OK

Experiments on the vendored bundle: `serialize` → `Transaction.from` → `serialize` is byte-identical; account keys dedup with fee-payer first (6 unique keys); compact-u16 header (1,0,3) correct; the u64 amount is exact at 2^53+1; memo bytes round-trip exactly. `@solana/web3.js` 1.99.0 is the **final** 1.x release (npm dist-tags; no 1.x patch after it), so nothing known is unfixed ahead of it; the issue tracker of `solana-foundation/solana-web3.js` shows no open `sendRawTransaction`-titled issue. The legacy `Transaction` API is deprecated in favour of 2.x but internally consistent here; `getLatestBlockhash`'s `lastValidBlockHeight` is ignored, harmless given the fetch-then-sign placement. The fake-wallet test exercises exactly the page's call graph.

## 11. THE WATCHER — OK

It finds payments by listing the enrol token account's signatures (`getSignaturesForAddress`, finalized, `limit ≤ 1000`, paged to a persistent cursor with no window bound — `watch.rs:296-304`; the enrol index cannot lose a payment to dust, README "the dust hole"), then `getTransaction` jsonParsed, memo verbatim. Two endpoints (Helius + public mainnet), `minEndpoints 2`, every endpoint must agree; disagreement or lag holds the cursor and retries on the next 60 s tick — delay, not loss; fewer than two responding endpoints refuses the whole run (`watch.rs:456-466`). Exact-once: one report per tip (tick nullifier), per-signature receipts, one-per-report probing, crash-mid-submit settled by exact lookup (`deploy/pay/README.md`, "What one tick decides"). The public endpoint's rate limits are the practical ceiling; a 429 there delays the tick, it does not lose the payment.

## Five fixes, ranked by harm to an honest user

1. **Check `res.ok` and show the door's refusal** — `assets/pay.js:66-69`: a 409/429 POST is reported as "Sent and posted", which sends the stranger back to pay a second time.
2. **Show the signature the moment it exists** — `assets/pay.js:64-65`: after a successful send with a failed POST, the stranger holds nothing to paste and will likely pay again.
3. **Refuse a stale quote** — serve the current chain hour in the quote (`mini-door-process.rs:738`) and compare it to `expiryHour` in `assets/pay.js:19-24`, so a tab left open past the hour cannot turn a payment into a comp-needing pending claim.
4. **Raise or exempt the pay flow's POST budget** — `mini-door.rs:437`: the 3/hour per-IP default is consumed by the happy path alone; one shared NAT bricks the second stranger for an hour.
5. **Fill `amountTokens`** — `mini-door-process.rs:738` (read at `mini-door.rs:273`, written by no one): "50.000007 DREGG" belongs where the empty parenthesis is.
