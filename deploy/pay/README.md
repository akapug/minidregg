# The PAY watcher on a Mini box

The pay rail's state and rules are the Lean pay cell (`Kernel/PayCell.lean`: tariff, deposit address book,
assignments, enrolments), its observation receiver (`Kernel/PayObservation.lean`) and its self-enrollment
receiver (`Kernel/PayEnrolReceiver.lean`). Comments in that code and in `native/pay-watcher` cite
`PAY §N` and lane names such as P3b: sections and lanes of the payment design document of
2026-09-30, which lives in a planning repository outside this tree. The Lean modules are the
authority. This directory has what runs it on the box:

- `mini-pay-watcher`: one tick. It derives the watcher config from the signed pay view, runs
  `pay-watcher`, retains and archives the complete tick, and submits one report with `mini pay observe`;
  each enrollment-index record goes alone to the self-enrollment receiver (below), and while some
  wait for a tip the tick asks the watcher again.
- `mini-pay-watcher.service` / `.timer`: the tick runs as a oneshot in `mini.slice`, 60 s after
  the previous tick finished.

The watcher keeps no ledger, and no cursor except the enrollment row's (gated by receipts). The ticks connect only through the observer
workspace's retained attempts and the kernel's nullifiers.

## The price, the address and the network

Ember's ruling (2026-10-04): enrollment costs **50 DREGG per node week**. The price lives in exactly one
file, `enrol-terms.json`.

**The receiving address is a deployment parameter, never a literal in the repo.** At install time
`mini-enrol-keygen` (deploy/door/infra/) makes a FRESH Ed25519 key with the candidate's own `mini keygen`:
the seed stays in `/var/lib/mini-core/secret/enrol.key` (mini-core 0600, with a Solana CLI keypair copy
`enrol-solana.json` for ember to move what it receives), and it prints the base58 address. `render-enrol`
reads the public half; `mini pay book` signs it into the book (row 0, the tariff's `enrolIndex`); the
door's join page shows it from the rendered pin.

**The network is a switch.** `--network mainnet` uses the terms' DREGG mint. `--network devnet` has no
DREGG mint and needs the devnet mint and token program given explicitly; nothing defaults silently. The
RPC endpoints follow the same switch (step 4).

```
python3 deploy/pay/render-enrol --out OUT --version N --control CAP \
    --observer-capability C --enrol-capability E \
    --enrol-address-file /var/lib/mini-core/secret/enrol.pub --network mainnet \
    [--book-extra FILE] [--mint BASE58 --token-program BASE58]
```

(`CAP` is genesis `factoryControllerCapability`, `C`/`E` are `payObserver.capability` / `.enrolCapability`
of THIS genesis, `N` exceeds the installed tariff version.) It writes `book.json` and `tariff-on.json`
(for `mini pay book`, below), `enrol.json` / `enrol-v2.json` (the pins) and `watcher.env`.
`test-render-enrol.py` pins the integers and refuses an address in the terms.

**The exact integers.** The mint has 6 decimals (`decimals: 6`, READ `native/pay-watcher/README.md`) and
`creditPerAtomic` is 1, so 50 DREGG is `weekPriceAtomic = 50000000` atomic units. The tariff's unit is the
week: it stores `nodeWeekRate`, the Book credit one node week costs (`Kernel/PayTariff.lean`,
`DREGG/PAY/TARIFF/v4`), and the kernel prices an enrollment as `birthFee + nodeWeekRate`
(`Kernel/PayEnrolDecision.lean` `enrolPrice`) and a renewal as `credit / nodeWeekRate` whole weeks.
`render-enrol` writes `nodeWeekRate = weekPriceAtomic * creditPerAtomic = 50000000`: **exactly 50.000000
DREGG, no division, no floor** (the retired hourly unit stored `nodeHourRate = 297619` and could only
reach 49.999992). A payer who sends exactly 50 DREGG plus the one-time birth fee is exactly at the price,
and exactly 50 DREGG renews one whole week; one atomic unit less is below the price and is journaled
`belowPrice`. The friend never sees these integers computed on their side: `mini join --solana` prints
the Host's own quote (op 121; `join_solana.rs` takes `atomicAmount` verbatim, no client formula), which is
`birthFee + 50000000`. `render-enrol --verify-tariff FILE` refuses a tariff whose week is not exactly the
terms' price or that still carries an hourly rate; the Host refuses a `nodeHourRate` field outright and
a v3 tariff's bytes no longer decode.

The Lean `genesisDefault` carries `nodeWeekRate := 50000000` too. It is a placeholder that is invalid by
construction (`genesisDefault_invalid`: version 0, zero mint) and is replaced by the first `mini pay book`
tariff before any enrollment can be decided; it is not an operating source of the rate.

## What ember does, once

1. **Genesis names the observer.** Before bootstrap:
   - Generate the observer key on the box:
     `mini keygen --secret /etc/mini/pay/observer.key --public /etc/mini/pay/observer.pub`.
     The key file must be mode 0600, owned by `mini`.
   - Enroll the observer in the genesis source like any subject: a key record, an account, and
     its capabilities.
   - Name the observer: `"payObserver": {"subject": "<S>", "capability": "<C>",
     "controlCapability": "<K>", "enrolCapability": "<E>"}` (C, K, E unused capability
     ids). With `native/resource-client/genesis.sh`, put the observer's enrollment in
     `EXTRA_GENESIS_ENROLLMENTS` and this object in a file named by `GENESIS_PAY_OBSERVER`.

   At genesis this installs:
   - the pay cell's law: the observer may report (`observePayment`), the factory controller
     may manage the pay cell (install, revoke, delegate) and may not report;
   - the observer's root capability C: verb `observePayment`, target and policy the pay cell;
   - the controller's pay-cell capability K (replace the observer: revoke C, delegate anew);
   - `C_enrol` E: the observer's `installPolicy` on the factory, narrowed by the factory law
     to self-enrollment.

   `native/resource-client/newparticipant-acceptance.sh` does exactly this (subject 30,
   capabilities 4030/4031/4032) and is the template. A genesis without `payObserver` has no
   pay law, so every report is refused.

   `mini bootstrap` also retains `DEPLOYMENT/pay-ledger-genesis.json`. This is the issuer well
   before any payment, and `mini pay audit --offline true` needs it.
2. **The observer workspace:**

   ```
   mini workspace --action init --host HOST --config DEPLOYMENT/pinned-config.json \
     --socket PUBLIC-SOCKET --key /etc/mini/pay/observer.key --subject S \
     --dir /var/lib/mini/pay/observer
   ```

   The workspace holds `attempts/` (every report, byte for byte), `pay/receipts/` and
   `pay/quarantine/`. Back it up with the Store. If you lose it, the next tick resubmits the old
   transfers and the kernel refuses each one once. That costs extra reports; it never credits
   twice.
3. **The book and the tariff.** Render the files (above), then run this from ember's own workspace (the
   factory controller), in this order:

   ```
   mini pay book --dir EMBER-WS --source OUT/book.json       # row 0 = the receiving address; tariff N, enrolIndex null
   mini pay address --dir FLOAT-WS                           # the enrollment float takes row 0 (prints "index 0 → " and the enrollment address)
   mini pay book --dir EMBER-WS --source OUT/tariff-on.json  # tariff N+1 names the enrollment index
   ```

   The third step must come after the second: the book receiver refuses an `enrolIndex` whose row is not
   assigned (`enrolIndexUnassigned`). `book.json` has this shape (`render-enrol` writes it; the example
   shows the fields, not values to copy):

   ```
   {"control": "<factory control cap>",
    "book": ["<address base58|hex>", ...],
    "tariff": {"version": "1", "asset": "0", "mint": "<base58|hex>", "tokenProgram": "<base58|hex>",
               "decimals": "6", "creditPerAtomic": "...", "maxPerObservation": "...",
               "minTickSlots": "1500"}}
   ```

   - Rows are appended at the view's `bookSize`.
   - `"tariff": null` changes only the book.
   - A tariff's version must increase.
4. **`/etc/mini/pay/rpc.env`** (root 0600, read by systemd): the endpoints, which carry the API key.
   The demo's provider is Helius; its key lives in ember's `~/.helius-key` and the infra lane installs
   this file from it on the box. It is never in git, argv or a log.

   ```
   # --network mainnet
   PAY_RPC_ENDPOINTS=https://mainnet.helius-rpc.com/?api-key=KEY https://api.mainnet-beta.solana.com
   # --network devnet
   PAY_RPC_ENDPOINTS=https://devnet.helius-rpc.com/?api-key=KEY https://api.devnet.solana.com
   ```

   The watcher requires every configured endpoint to agree (`minEndpoints` defaults to 2), so a second,
   independent endpoint stands beside Helius; the public cluster endpoint is the default second. With one
   endpoint only, `PAY_MIN_ENDPOINTS=1` in `watcher.env` is an explicit weakening (one provider's word
   decides what is final).
5. **`/etc/mini/pay/watcher.env`:** `render-enrol` writes it (installed with
   `mini-config install pay-watcher-env`). The enrollment variables are all or none:

   ```
   PAY_OBSERVER_WS=/var/lib/mini/pay/observer
   PAY_OBSERVER_CAPABILITY=C                 # genesis payObserver.capability
   PAY_WATCH_ENROL=yes                       # watch the enrollment row
   PAY_ENROL_CAPABILITY=E                    # genesis payObserver.enrolCapability (C_enrol)
   PAY_OPERATOR_SOCKET=/var/lib/mini/store/node/operator/mini.sock
   ```

   (`MINI`, `PAY_WATCHER` and `PAY_STATE` are the unit's, set from the candidate; they do not go here.)
   The file holds neither the address, the rate, the enrollment row nor the journal floor: the tick
   reads all four from the Host's signed pay view (`mini pay watch-config --enrol tariff`), i.e. from
   what step 3 installed. A floor taken from an operator variable could drift from the tariff's and
   skip real enrollments for good, so `PAY_ENROL_INDEX`/`PAY_JOURNAL_FLOOR` are refused by name.

   **Self-enrollment needs the Host's operator socket.** Ops 117-120 (the self-enrollment plan,
   assembly, submit and lookup) are admitted only on an owner-private operator socket, never on the
   public one (op 117 runs the native verifier twice per call). On the box the socket is
   `/var/lib/mini/store/node/operator/mini.sock`, served by `mini serve-operator` (`store-entry.sh`)
   in a `0700` directory (`mini-service-config` creates it) owned by the Store's uid, with the public
   socket a filtered relay (`mini-public-ingress`) over it. That is the **ingress topology**
   (`/etc/mini/ingress.json`, written by `install.sh` on a clean frame and at `ship.sh --regenesis`).
   The old single-socket entry (`run.sh serve`, DEPLOY-2b's `5688775a`) has no operator socket, so
   self-enrollment cannot run there. The operator socket checks the peer UID: the tick must run as the
   Store's uid (`mini`; in split tenancy `install.sh` runs every Mini unit as `mini-core`, tick
   included). `mini-pay-watcher.service` keeps `ReadWritePaths=/var/lib/mini/pay`; connecting to that socket needs no write access
   to its directory. Without `PAY_ENROL_CAPABILITY` and `PAY_OPERATOR_SOCKET`, an
   enrollment-index record is left undecided every tick (`enrol-unconfigured`, exit 3) and holds the
   enrollment cursor.

   `PAY_RPC_FIXTURES="DIR_A DIR_B"` replaces the endpoints for a rehearsal on recorded answers.
6. **Install the units:**

   ```
   install -m 755 mini-pay-watcher /usr/local/lib/mini/
   install -m 644 mini-pay-watcher.service mini-pay-watcher.timer /etc/systemd/system/
   systemctl daemon-reload && systemctl enable --now mini-pay-watcher.timer
   ```

   `journalctl -u mini-pay-watcher` shows one summary per tick, for example
   `pay observe: tip S reports R credited C already-credited A quarantined Q [waiting REASON]`.
   `/var/lib/mini/pay/tick/ticks/ID.json` holds each acknowledged tick, including all
   watcher events, observations, tip, and cursor transition. A tick awaiting an exact
   observer decision stays in `tick/pending.json`; it is retained before the cursor advances.
   Existing `journal/YYYY-MM-DD.jsonl` files are historical and remain untouched.

   A pending tick the observer can never settle stalls every later payment. After reading why
   (`tick/pending.json`, the observer workspace's last attempt), move it aside with
   `mini-pay-watcher --quarantine-tick ID REASON...`: it lands whole in `tick/quarantine/ID.json`
   and the next tick re-reads its unreceipted transfers at a fresh tip (native/pay-watcher/README.md).

   To inspect retained events (including an unresolved pending tick):

   ```sh
   find /var/lib/mini/pay/tick -type f \( -path '*/ticks/*.json' -o -name pending.json \) \
     -exec jq -c '.observations.tip as $tip | .id as $tick | .events[] | . + {tick:$tick, tip:$tip}' {} +
   ```

   These event records explain watcher decisions, including dust below the journal floor.
   Credit acceptance is established separately by `mini pay audit` and the retained
   observer attempts/receipts. A watcher event alone is not proof of credit.

## What one tick decides

- **One report per tip.** Every record the watcher read at tip T goes into one report. The
  report spends T's tick nullifier, so no other report can be accepted at T.
- **The report is signed against a fresh view.** The client re-reads the pay view (op 107)
  immediately before each report, because every report writes the pay cell.
- **How the client acts on the Host's answer:**

  | Host answer | client action |
  |---|---|
  | `confirmed` | Credited. Each record gets a receipt, `pay/receipts/SIGNATURE.ADDRESS` → the attempt. |
  | `stalePay` / `staleAuthority` | An assignment or tariff change landed after the read. Re-read and re-sign once. |
  | `tickTooSoon` / `tipBehindClock` | Wait for the next tick. |
  | `alreadyConsumed` while the clock is at the tip (in the view read before the submit, or in a view read after the refusal and retained as `after-refusal/`) | That tip is already reported, possibly by another report. Wait. |
  | `alreadyConsumed` with the clock behind the tip in both views, or a per-observation refusal | Probe the records one per report (below). |
  | anything else | Stop: exit 3 (refused) or 4 (undecided). |

  - **Probing.** A refused report consumes nothing, so the client submits the records one per
    report. A spent record is "already credited" and gets a receipt linking the refusing
    attempt. A record refused on its own merits (for example `unassignedIndex` or `wrongMint`)
    is quarantined. The first record that is accepted spends the tip; any records left wait
    for the next tick.
- **A crash mid-submit is settled first.** A report with a submit marker but no outcome is
  looked up exactly (op 111) before anything new is sent. If it was confirmed, its records get
  their receipts. If it is `absent`, its records are simply observed again.

## What one tick decides at the enrollment index

- **Never in a report.** A record at the tariff's `enrolIndex` is routed out of the report (the
  observation receiver would refuse the whole report: `enrolIndexNeedsReceiver`). Each one is
  submitted ALONE through ops 117-120 under `C_enrol`, and the kernel's `decideEnrol` decides:
  **enrol** (a new subject, its account funded `amount − price`, its own book index, one or more
  node weeks of lease, its ssh key), **renew** (the same memo again: the lease extends from its
  end), or **journal** (memo missing, malformed or unverifiable, below the price, an ssh key
  already taken: nothing minted, kept for ember to comp). The client decides nothing; it reads
  which one happened back from the public enrollment view (op 112) and prints
  `enrolled|renewed|journalled INDEX SIG… detail ATTEMPT`.
- **One decision per tip.** Every self-enrollment spends the tip's tick nullifier, as a report
  does. Ordinary records go first, exactly as before; with no ordinary record, the enrollment is
  the tip's submission (it advances the clock as a heartbeat would). Records left over print
  `enrol-pending N`, and the tick script runs the watcher again for a newer finalized tip, at
  most `PAY_ENROL_ROUNDS` (default 8) more times, stopping when the tip does not move.
- **How the client acts on the Host's answer** (op 119, the observer's signed channel, named reasons):

  | Host answer | client action |
  |---|---|
  | `confirmed` | Decided (enrolled, renewed or journalled). Receipt `pay/receipts/SIGNATURE.ADDRESS` → the attempt; the enrollment cursor may pass it. |
  | `alreadyConsumed` at a newer tip than the clock | Decided before (`already-decided`). Receipt. Next record at the same tip. |
  | `alreadyConsumed` with the clock at the tip (either view, as above), `tipBehindClock` | Wait for the next tip. |
  | `stalePay` / `staleAuthority` | Re-read and re-sign once. |
  | `verifier:…` (the native verifier failed) | Nothing decided or consumed: wait, exit 4, retry next tick. |
  | `decision:…`, `keyTaken`, `allocation`, … (refused, nothing consumed) | Quarantined, no receipt (read again next tick). Next record. |
  | anything else | Stop: exit 3 (refused) or 4 (undecided; settled by op 120 before anything new). |
- **Audit.** `mini pay audit --operator-socket S` replays every decided self-enrollment through op
  120. An enrolment or renewal mints `creditFor amount` into the enrollment float exactly as a
  credited report does, so the offline identity is `-well_now = -well_genesis + Σ reports + Σ
  enrolments/renewals`; a journal row mints nothing.
- **What the friend runs** is `mini join --solana|--wait|--renew` (deploy/shell/FRIENDS.md,
  "joining by yourself"). The pin it reads (`--enrol enrol.json`; `--memo-version v2` reads
  `enrol-v2.json`) is rendered from `enrol-terms.json` and published with the friend bundle. The client
  refuses a pin whose address differs from the box's book row at the enrollment index, and refuses an
  unset one (`EMBER_ENROL_ADDRESS`). The roster sync reads the same view with
  `mini enrollment-view --socket PUBLIC/mini.sock --host HOST` (the v2 envelope pins the Host image).

## What a friend sees

```
mini> pay address
index 7 → 9xQeWvG8…3k
send the token with mint XkeT…pump (token program TokenzQd…) to this address from a wallet you control.
1 atomic unit (6 decimals) = 1 credit; at most 10000000000 atomic units are credited per payment.
mini> pay status
account 8811  index 7  address 9xQeWvG8…3k
credit 1000000000  (asset 0)
clock slot 312004391  blockTime 1759261382
tariff v1  valid true
```

- `pay address` is idempotent. The index is retained in the friend's workspace
  (`pay/address-ACCOUNT.json`), because the public view does not publish the assignment map.
- `pay status` cannot list the friend's individual transfers: the observation journal is the
  operator's.

## Published paid-member workspace context

Include a `minidregg-participant-birth-context-v1` file in the friend bundle, with
`genesis` copied exactly from the bootstrap's `deployment/genesis-source.json` and
`template` copied from the pinned Host's `profile.template`. These are public
deployment data; never include private keys. A reconstructed genesis cannot be
substituted: the Host checks its identity against the deployment seed.

`mini join --wait ... --birth-context birth-context.json` creates
`JOIN-DIR/workspace` and imports the member's account and factory observation.
It retains the exact genesis/template and uses only the member's own derived
payer and grants. Repeating the same command resumes local setup and refuses
changed identities, configuration, or context. Enter with
`mini shell --workspace JOIN-DIR/workspace --home JOIN-DIR/home`.

The exact admission price buys enrollment and the first week. A member needs an
additional deposit or renewal remainder to pay for resource/app creation. The
v1 enrollment memo has no next-key commitment; it does not provide prerotation
recovery merely because ordinary `mini keygen` supports that feature.
