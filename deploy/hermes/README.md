# Hermes provider keys: whose key pays for a Hermes call

Hermes never holds a model-provider key. Each Chat Completions request Hermes
makes goes to its controller's gateway. At reserve time, the controller picks
**one row of the operator's provider table** and **one bearer** for that
request. The row's `credential` kind says where the bearer comes from, and it
is also the **route** the purse records and is charged by:

| `credential` (route) | bearer | what gates it | what the purse pays |
|---|---|---|---|
| `user` | the friend's own key (`mini key set`, sealed per friend by the broker) | the friend's grant naming this Hermes runner: a per-call output-token ceiling, an optional model, calls per UTC day, and a last block height. The broker reads the body it forwards against the grant, not what the controller says | the user route's per-operation fee, nothing else: the provider bills the friend |
| `pool` | the operator's key (`mini-keys pool --action set`, as root) | the row's `caps` (per-call output tokens, calls per UTC day per runner, and the broker's own spend ceiling on the key) and the purse: Mini must admit the provider reserve (PAY.md §2.7) | the pool fee plus the metered tariff |
| `homelab` | no `Authorization` header at all | the purse (a homelab endpoint on the operator's own network) | the homelab fee plus its metered rates |

A call with no payer (a `user` row and no key or grant) is refused before
anything is reserved.

The row is the task's pinned `provider`, or else the first row that lists the
task's model. **Nothing ever falls through from one payer to another.** A
friend whose row needs their own key, and who has none, is refused
`no-credential`; they are never silently moved onto the pool. Hermes, which
is an untrusted worker, cannot choose the row either.

## Custody: what "hosted custody" means here

> **A provider key you give Mini is held by the box's key broker.** It is
> sealed at rest (ChaCha20-Poly1305 under `/etc/mini/credentials.key`, bound to
> your subject, your workspace's public key and the provider name), and only
> the broker's own account (`mini-keys`) can read the seal key. A copy of
> `/var/lib/mini` (a backup, a tarball) does not contain a usable key; no
> session account and not the Hermes controller can unseal it: Hermes asks the
> broker, which checks your grant and makes the provider call with your key
> itself. Root on the box can still use it. This holds for every friend,
> including tier-B friends whose Mini signing key never leaves their laptop:
> *that* key is not on the box, but a provider key you `key set` is, by your
> choice. Give Mini a key you can revoke at the provider, with a spend limit
> set there.

Your credential lives in a directory named by your subject **and the public
key of your workspace's signing key**. A workspace that only *claims* your
subject number has a different key, so it lands in a different directory: it
cannot read, replace, grant or revoke your credential. The controller looks
only under the subject and public key that ember pinned for your Hermes
(`onBehalfOf`).

## What ember does (once per box)

The deployed shape is split tenancy, and its pieces are installed by
**dregg-infra**, not by this repo: the accounts (`mini-core` for the Host and
the Hermes controller, `mini-keys` for the broker, one `mini-s-NAME` per hosted
member with primary group `mini-sessions`, `mini-pubread`, `mini-door`,
`mini-grain`), `mini-keys.service` and its confinement drop-in, the root-owned
broker config `/etc/mini/keys/broker.json` (`edge/mini/mini-service-config.py`),
the client pointer `/etc/mini/keys-client.json`, the credential root with its
pre-created `_service/` and `_pool/` leaves (`mini-keys` 0700; the broker
creates nothing under a root-owned root), the namespace helper with its sudoers
rule, and the seal key. This repo ships the binary and states the contract:

- **Broker config** (`mini-keys-broker-v1`, root 0644, every ancestor root's):
  no `singleAccount` (a root-owned config cannot select it: it is the
  journeys' and tests' one-account shape); `socketGroup` = `mini-sessions`;
  peers `member` by gid, `provider` = the `mini-core` uid, `operator` = 0,
  `discord` = the mirror's uid; `credentials.hostSha256` = the candidate
  manifest's SHA-256 of `bin/minidregg-host` (the broker hashes the image once
  at start and refuses a different one: restart `mini-keys` on every candidate
  switch, with the new digest); `credentials.publicSocketUid` = the uid serving
  the Host's public socket (the only account whose operation-144 answer counts).
- **Seal key** `/etc/mini/credentials.key`: 32 random bytes, `mini-keys` 0600,
  never in a backup.
- **Provider table** `/etc/mini/providers.json`: root 0644. Every `pool` row
  carries `caps.ceilingMicroUsd` and `caps.callMicroUsd`, or a deployed broker
  refuses to start.
- **Pool key**, as root: `mini-keys pool --action set --provider pool --secret - < POOL_KEY_FILE`.
  The file is the operator's, and is deleted after; the broker seals it into
  `/var/lib/mini/credentials/_pool/pool.key` (`mini-keys` 0600).

- **Back up `/etc/mini/credentials.key` separately from `/var/lib/mini`, or
  not at all.** Without it, the store is unreadable. The cost of losing it is
  that every friend runs `key set` again. Nothing else is affected.
- **`/etc/mini/providers.json` must be owned by root and not writable by group
  or world.** The controller refuses any other table. The table decides where
  friends' keys and the operator's money are sent, so no service account may
  rewrite it.

Example table (`type` and every field are required; `caps` exactly on a
`pool` row):

```json
{"type":"mini-provider-table-v2","providers":[
  {"name":"openrouter","kind":"openai-compatible",
   "endpoint":"https://openrouter.ai/api/v1/chat/completions",
   "models":["anthropic/claude-sonnet-4.5","qwen/qwen3-coder"],
   "credential":"user"},
  {"name":"pool","kind":"openai-compatible",
   "endpoint":"https://openrouter.ai/api/v1/chat/completions",
   "models":["qwen/qwen3-coder"],
   "credential":"pool","caps":{"perCall":"4096","perDay":"200"}},
  {"name":"homelab","kind":"openai-compatible",
   "endpoint":"https://inference.tailnet.example/v1/chat/completions",
   "models":["bonsai2-27b-ptq1"],
   "credential":"homelab"}]}
```

**Rules for the table:**
- **Endpoints.** An endpoint is one exact Chat Completions URL, either
  `https://` or loopback `http://127.0.0.1:PORT`. It has no query string and
  no userinfo.
  - A plain-HTTP tailnet address is refused. Put the homelab behind
    `tailscale serve` (which gives it HTTPS), or use a loopback tunnel.
- **No prices in the table.** The Host profile's per-route tariff (below)
  prices every call; the row only names the route. A v1 table (a row
  `tariff`, or `credential: none`) refuses to load.
- **`caps`** on a `pool` row: `perCall` is the largest `max_tokens` one call
  may ask for (also never above the task's `maxOutputTokens`, which the hold
  covers), `perDay` the calls per UTC day, per runner. `ceilingMicroUsd` is
  the broker's own all-time ceiling on the key and `callMicroUsd` the worst
  case of one call (`perCall` output tokens plus the task's input bound, at the
  model's price): each authorized call is charged `callMicroUsd` before it is
  counted, and a call that would pass the ceiling refuses `spend-ceiling`. Set
  the ceiling below the provider-side hard cap (the demo: $50 at OpenRouter, a
  ceiling of at most `40000000`), so that cap is never the first line.
  `mini-keys pool --action ls` shows the charged total; `--action spend-reset
  --provider pool` resets it after the operator re-checks the provider side.
- **Each member's share** of that ceiling: `memberDayMicroUsd` and
  `memberTotalMicroUsd`, charged at the same `callMicroUsd` against the member
  a call serves. For a room resident that is the author of the request the
  prompt answers (the controller reads it from the assignment and names it to
  the broker); for anything else, the runner. A call past either refuses
  `member-day-ceiling` or `member-total-ceiling`. A row with a ceiling and no
  member caps gets **1/40 of the ceiling a day and 1/10 in all**: on the demo's
  `40000000` / `100000`, $1 a day (10 worst-case calls) and $4 in all (40
  calls) per member, so no ten members can drain the key and no one can drain
  it in a day. The numbers are the row's, so they are published with the
  table (`/etc/mini/providers.json`, world-readable). Both caps need
  `callMicroUsd <= day <= total <= ceiling`.

**The pool is optional.** Set it only if you want to fund Hermes for friends
who bring no key:

```sh
mini-keys pool --action set --provider pool --secret - < pool-key.txt   # as root
```

Its spend is bounded three times: by each Hermes grain's purse (a pool request
whose reserve Mini refuses gets `no-credit`), by the broker's own
`ceilingMicroUsd`, and by the hard spend limit on the key at OpenRouter.

## What the broker decides, and what it still trusts

The broker is the one process that holds provider keys; it acts for peers the
kernel names (`SO_PEERCRED`). What it checks itself:

- the **forwarded body**, not the controller's claims: one JSON object without
  duplicate keys, a `model` on the row (and the granted one), `max_tokens`
  (and `max_completion_tokens`, `max_output_tokens`) within the grant's or
  pool row's per-call ceiling, `n` absent or 1; otherwise
  `provider-refused:body-exceeds-grant` and nothing is sent;
- **tickets are durable** and written before the day's call is counted; an
  exact `provider-authorize` retry gets the same ticket and counts nothing; a
  forward is journaled, and an exact retry replays the retained answer
  (retained one hour, plaintext, in the broker's 0700 spool) or refuses
  `forward-uncertain`; it never calls the provider twice;
- **operation 144** (is this key the subject's current, unrevoked key) is
  accepted only from `publicSocketUid`, on a connection carrying exactly that
  query; Lean's `isCurrent` is "the current key equals the queried key"
  (`Kernel/Receivers/SubjectKeyRotation.lean` `status`);
- **slots** by role class (provider 8, operator 2, discord 2, members 20 with
  at most 4 per uid) and a first frame sized by role (a member's is 4 KiB);
- **audit**: every operation with an effect writes and syncs a `begin` line
  first; if it cannot, the operation refuses `audit-unavailable`.

What it still takes on trust, and the Lean asks that remove it (for
`lane/lean-critical`):

1. **Operation 144 should name the key and the height.** In `Host/Json.lean`,
   `subjectKeyStatusJson` takes the queried `publicKey : List UInt8` and the
   opened Store's logical height, and emits `("publicKey", hex publicKey)` and
   `("height", decimal height)`; `Host/Main.lean` (the `| 144 =>` arm) and
   `Host/SourceAgreementReader.lean` pass them. The broker already compares a
   `publicKey` it is given (`native/mini-keys/src/server/native.rs`
   `current_epoch`) and uses `height` for a grant's `notAfter`; until `height`
   is emitted, `notAfter` is checked against the controller's stated height,
   the one remaining claim.
2. **The provider reserve should bind the grant.** Lean's provider purse
   records only the route (`Kernel/ProviderRoute.lean`); no reserve receipt
   carries `(model, max_tokens, height)`, so the broker cannot check one and
   reads the body instead. A Lean-admitted member grant cell (perCall, perDay,
   notAfter, model, runner) checked at provider reserve, with the broker
   verifying the reserve receipt before it unseals, would move the grant and
   quota decisions out of Rust (SYNTHESIS §B row 9).



**Each Hermes controller** (`/var/lib/mini/hermes/controller.json`) needs these
fields in its `providerTask`:

```json
"providers":"/etc/mini/providers.json",
"credentialBroker":"/etc/mini/keys-client.json",
"onBehalfOf":{"subject":"21","publicKey":"<the friend's owner.publicKey from key set>"},
"provider":"openrouter"
```

- **`onBehalfOf`:** the friend this Hermes serves. Omit it for a Hermes that
  only uses `pool` or `homelab` rows.
- **`reserve`, `maxInputTokens`, `maxOutputTokens`:** the hold of a metered
  (pool or homelab) call and the token ceilings it must cover: `reserve` ≥ the
  route's fee + the metered charge at the ceilings, or the call is refused
  before anything is reserved. A user-route call holds exactly the user fee.
  There is no `charge` and no `metering` field any more: every call is charged
  by the Host's route quote.
- **`provider`:** optional. It pins the row, for example `"pool"`.
- **The runner.** The friend's grant names the provider task's `subject` (the
  runner). Tell the friend that number.

Then install the controller with
`deploy/grain-host/install-controller --system --service-user ACCOUNT ...`
(the system shape: `mini-grain-controller@TASK.service` plus the root
registration `/etc/mini/controllers/TASK.json`) and start that unit. The unit
has no key and no `EnvironmentFile`. The old `mini-hermes.service` is retired:
its name failed the controller's own unit proof, so no sandboxed Hermes
prompt could run under it.

## What a friend does

These commands run over ssh to the box. They are verbs of the hosted shell, so
they work for tier-B friends too.

```sh
ssh mini@BOX 'key set openrouter -' < my-openrouter-key.txt
ssh mini@BOX key grant openrouter 9 --per-call 4096 --per-day 200 --until 2000000
ssh mini@BOX key ls
ssh mini@BOX key revoke openrouter 9      # stop one runner
ssh mini@BOX key revoke openrouter        # delete the key and every grant
```

- **`key set`.** It reads the key from stdin. Use only the one-verb form shown
  above, never inside an interactive shell session, because the session owns
  stdin there. It prints `owner.publicKey`. Send that value to ember, who pins
  it as your `onBehalfOf`.
- **`key grant`.** It names the runner (Hermes's provider subject, which ember
  tells you) and three limits:
  - `--per-call`: the largest `max_tokens` one call may ask for.
  - `--per-day`: calls per UTC day.
  - `--until`: the last block height at which the grant is usable.
- **`key ls`.** It prints provider names and limits, never key values.

**When a call is refused**, Hermes gets a named refusal (HTTP 403 or 402,
`error.code`), and nothing reaches the provider:

| code | meaning |
|---|---|
| `no-route` | no table row lists this model (or the pinned row does not) |
| `no-credential` | your row needs your key, and there is no key or no grant for this runner |
| `grant-expired` | the signed height is past your `--until` |
| `per-call-cap` | the request's `max_tokens` is absent or above your `--per-call` |
| `per-day-cap` | today's calls reached your `--per-day` (or the pool row's `perDay`) |
| `member-day-ceiling` | the member this call serves spent its share of the pool row for this UTC day |
| `member-total-ceiling` | the member this call serves spent its whole share of the pool row |
| `no-credit` | the purse refused the reserve (402) |

## Charges: the Host's per-route tariff

The Host profile pins one tariff per provider task, with a row per route
(each `providerServices[].tariff`; credit units,
one credit per purse micro-unit):

```json
{"version":"1","model":"qwen/qwen3-coder","routes":{
  "user":{"perOp":"EMBER_USER_PER_OP"},
  "pool":{"perOp":"EMBER_POOL_PER_OP","inputMicroPerMillion":"EMBER_POOL_IN","outputMicroPerMillion":"EMBER_POOL_OUT"},
  "homelab":{"perOp":"EMBER_HOMELAB_PER_OP","inputMicroPerMillion":"EMBER_HOMELAB_IN","outputMicroPerMillion":"EMBER_HOMELAB_OUT"}}}
```

- **`user`** (your own key): the purse is charged only `perOp` per call. Your
  provider bills you; Mini's purse never sees a token count.
- **`pool`**: `perOp` plus `ceil((in·inputMicroPerMillion + out·outputMicroPerMillion)/10⁶)`.
- **`homelab`**: the same shape as pool, at its own rates.
- **The route is a kernel fact.** A provider purse born under this tariff
  carries a route field: the reserve records the route the controller chose
  (with the bearer, from the same table row), and the settle is charged by
  that recorded route. A call reserved as pool cannot settle as a user call
  (`Kernel/ProviderRoute.lean`).
- **The reserve is still a real hold**, on every route. It is how an uncertain
  send is never resent.
- **The fees are fixed at the purse's birth.** The purse's law carries the
  per-operation fees the Host pinned when it was born. A Host tariff with
  different fees refuses the user-route reserve (its hold must equal the law's
  fee) and fails a metered settle closed; a fee change means a new purse.

## The demo box: Hermes as a room resident

`demo/install-hermes STEP...` (run as root) is the sequence J14 runs on the
ACP room resident, with the box's paths and dregg-infra's registration
(`mini-controller-register`, `mini-grain-controller@TASK`,
`mini-grain-resident@TASK`). Two accounts act: the operator (`OPERATOR`,
default `mini-core`) for the sponsor, the founder and the concierge, and the
resident (`RESIDENT`, default `mini-h-INSTANCE`, made by `preflight`) for
Hermes's subjects, controller, resident and workers, through its own operator
route (step `route`). Steps, in order:

    install-hermes preflight route subjects room runtime create handoff summon controller dispatch resident

Its rehearsal is J14 on the same candidate with `J14_ROUTE=pool` (the
operator's sealed pool key, the metered tariff quoted from the upstream's
usage record) and `J14_HERMES_ROOT` set to the runtime root below; the default
`J14_ROUTE=user` runs a friend's own key instead.

Before it can run:

- **The Store pins Hermes's purse tariff.** `demo/provider-services.json`
  goes into genesis-params.json as `providerServices`; `genesis.sh` checks it
  and copies it into `operator.json`. It is pinned at genesis (a serving
  Store refuses a changed config), so it ships with the next re-genesis:
  `jq --slurpfile ps provider-services.json '.providerServices = $ps[0]'`. Default prices: 1 credit is about 1 micro-dollar on the pool
  route; `meta-llama/llama-3.1-8b-instruct` at 20000 / 50000 micro-credits per
  million input / output tokens (OpenRouter's $0.02 / $0.05 per million) plus
  100 per call; the user (BYOK) route pays 5 per call.
- **The worker is upstream Hermes Agent.** `build-runtime-root SOURCE OUT
  CANDIDATE` stages it from a hermes-agent checkout at 6d8a8beb with
  `hermes-agent/mini-tool-catalogue.patch` (the restricted resident admits a
  session only when Hermes reports exactly the Mini room tools) and the
  candidate's grain-runtime and grain-provider-bridge, checked against its
  manifest; `OUT/pins.json` records every digest. It needs python3 (3.11–3.13),
  uv and network on the build host. For a later candidate,
  `build-runtime-root --rebind OUT CANDIDATE` swaps the two binaries and
  rewrites the pins (no rebuild). `HERMES_ROOT` names the root at the
  `runtime` step, which refuses a root pinned to another candidate's
  grain-runtime.
- **dregg-infra's controller-entry.py** still calls `grain-runtime
  controller-write-scopes`, which no longer exists (the source parses the
  config at `controller-launch`); its registration must check the broker pin
  directly instead (the patch the L4 lane handed the infra lane).

What the steps write, and where each controller field comes from:

- `subjects`: four enrolled subjects through the sponsor workspace
  (`NODE/sponsor`): `hermes` (its room key, also the tool worker: room tools
  act in the tool task's own workspace), `hhost` (parent owner), `hprov`
  (provider worker), and `founder`, funded `FOUNDER_FUNDING` to own the room
  and summon. Keys stay in `/var/lib/mini/hermes/homes`, private to `SVC`.
- `create` writes the `mini-grain-create-v1` spec and runs `grain-runtime
  create`, which births the parent (9870001), tool task (9870002) and provider
  purse (9870003) and writes `/var/lib/mini/hermes/g/controller.json`:
  - `mini`, `host`: the archived candidate by real path.
  - `hostConfig`/`hostSocket`: `NODE/deployment/pinned-config.json` and the
    private operator socket `NODE/operator/mini.sock` (the registration
    requires exactly these).
  - `sponsor`, `template`: `/etc/mini/genesis-params.json` (sponsor subject,
    spend capability, factory observation) and `NODE/operator.json`.
  - `budgets`, `worker.reserve`/`charge`, `toolCharges`: operator prices.
  - `worker`: the materialized `bwrap` launcher (sibling `launch-gate`), the
    runtime root, `network: none` (the worker reaches the model only through
    `grain-provider-bridge` and the controller's Unix gateway).
  - `provider.gateway`: `/etc/mini/providers.json` (root-owned) pinned to its
    pool row for the model, `/etc/mini/keys-client.json`, the model, token
    caps 16000 / 1024, and `reserve` = the pool fee plus the metered charge at
    those caps under the pinned tariff (computed from the config).
  - `room`: the room's workspace and home are direct children of `stateDir`
    (the registration requires it); `restrictTools` is true by default.
- `controller` writes the summoned budget account into `controller.json`
  (it is known only after the summon) and registers it; `resident` writes
  `resident.json` (`maxPrompts: null`, one pass a minute) with the inbox the
  dispatch delivered, and re-registers with both units stopped.

One registration serves one room: summoning Hermes into another room needs its
own task and registration.

## The subscriber tier: Hermes on GLM through the Z.AI coding plan

A flat 4000 DREGG a month buys membership of the `subscribers` room, whose
resident Hermes answers on GLM through ember's Z.AI coding-plan key. It is
existing machinery: a concierge room, a second house resident, a pool row.

**The route.** The coding plan serves OpenAI Chat Completions at
`https://api.z.ai/api/coding/paas/v4/chat/completions` (measured 2026-10-27:
200, streaming, usage on the finishing chunk), so the row is the ordinary
`openai-compatible` shape and needs no adapter. The pay-as-you-go
`/api/paas/v4` is not funded (`1113`), and a 429 on the plan endpoints means a
wrong endpoint. The Host quotes its stream (it omits `finish_reason` on delta
chunks; `Host/ProviderUsageAudit.lean` holds the measured stream). The two
rows, to append to `/etc/mini/providers.json`'s `providers` as they are
(`demo/providers-zai-rows.json`):

```json
{"name":"zai-glm","kind":"openai-compatible","credential":"pool",
 "endpoint":"https://api.z.ai/api/coding/paas/v4/chat/completions",
 "models":["glm-5.3-flash"],
 "caps":{"perCall":"4096","perDay":"160","ceilingMicroUsd":"70000","callMicroUsd":"150",
         "memberDayMicroUsd":"3000","memberTotalMicroUsd":"35000"}},
{"name":"zai-byok","kind":"openai-compatible","credential":"user",
 "endpoint":"https://api.z.ai/api/coding/paas/v4/chat/completions",
 "models":["glm-5.3","glm-5.3-flash"]}
```

The key is sealed like the OpenRouter pool key (`mini-keys pool --action set
--provider zai-glm --secret - < zai-key`, as root, never in a file the repo
sees). Egress: the broker account to `api.z.ai:443` only.

**Caps, from the plan's quota.** The plan reports (`GET
/api/monitor/usage/quota/limit`) 28000 credits per 5 hours and 140000 per week
(level max). The house resident runs `glm-5.3-flash` (ember's ruling: the
flash tier spends the plan more slowly). Measured on flash, 2026-10-27, five
uncached Hermes-sized calls (8823 prompt tokens, 400 output) per batch: 24 and
51 credits a call in two batches (the quota counter lags and the account is
shared, so the higher figure is kept as typical); a call at the row's bounds
(16000 in, 4096 out) is taken as at most 150. On this row the broker's spend
units are those credits: `callMicroUsd` 150 (worst case), `ceilingMicroUsd`
70000 (half the week, the other half stays ember's; `mini-keys pool --action
spend-reset --provider zai-glm` at each weekly reset), `perDay` 160 calls
(about a third of 70000 / 150, per runner: the GLM resident, so the week's
share lasts at least three days), and per subscriber 3000 a day (20
worst-case calls, about five asks) and 35000 in all (half the ceiling) until
the weekly reset. A subscriber past either gets
`member-day-ceiling` / `member-total-ceiling` by name. The plan's three
one-time resets (valid to 2026-12-22) raise the week when used; they change
the ceiling, not the code.

**Who pays what.** The subscriber pays 4000 DREGG to the room's till (`pay
subscribers week`); the concierge delegates `member` under the room with
`notAfter = height + 43200` (30 days at one tick a minute; renewing extends),
refunds anything it does not honour, and the kernel ends the window. The GLM
resident's purse pays 1 credit a call on either route (the tariff in
`demo/provider-services.json`, purse 9871003, glm-5.3-flash: no token metering, because the
plan is flat); the room's `hermes/turn` and the summon budget are the
founder's, funded from the till. ember's plan pays Z.AI. A member's own Z.AI
plan key goes on `zai-byok` exactly as any friend key (`mini key --action
set`, `--action grant` to their own grain's runner).

**Install** (after the `hermes` resident; Store genesis carries both purse
tariffs):

    INSTANCE=glm BASE=9871000 MODEL=glm-5.3-flash ROOM=subscribers TIER=1 POOL_ROW=zai-glm \
      HERMES_ROOT=OUT demo/install-hermes preflight route subjects room concierge runtime create handoff summon controller dispatch resident

`concierge` installs `mini-concierge-subscribers.timer` (one pass a minute).

**Before a stranger can subscribe** they need a reference to the room to read
its price and pay through: the founder's observe-only guest grant (`room
invite i-NAME subscribers SUBJECT --verbs observe`, `submit`, `publish`,
`export`; the member `import subscribers REF`), as J17's payers hold. The join
flow issues it once per enrolled member.

**Subscribe** (the web form's verbs): `tariff subscribers` (price and period),
`credit` (balance), `pay subscribers week`, `room status subscribers` (the
window and its end), then once `chat join subscribers @subscribers-invite.json`.

**The roster.** A window is kernel membership; asking the room's Hermes is a
chat line, which needs a stream on the room's roster. The concierge keeps the
roster: for each subject it issues a window, it has the founder (the same
operator account) run `chat invite subscribers SUBJECT --roster-only` (a
stream and a roster row, no grant: the window is the grant, so its end ends the
posting), and leaves the window's reference in
`MEMBER_HOMES/SUBJECT/requests/subscribers-invite.json`. The subscriber joins
once: `chat join subscribers @subscribers-invite.json`; a renewal is adopted by
`room status subscribers`.

Whether the coding plan's terms permit serving others' agents is for the join
page to state.

## State (lane L4b, 2026-10-28)

**The room resident (J14)** passes whole on the lane (run 24, 153/153 rows; upstream Hermes
Agent 6d8a8beb in the gated worker, pool route, `--network none` plus the bridge). The subscriber
tier row's six tier-7 reds are fixed, unrun: bcd78780 (the turn count in a workroom), 2dfefa66
(a failed prompt refused by the controller's typed record is closed and counted, so later passes are
not blocked) and 65eca3e4 (the tier row's journey bound is 5400 s).

**Sandbox tools** (docs/HERMES-TOOLS-2026-10-27.md, the design and the containment argument). A
founder grants upstream Hermes's file, terminal and Python tools with room field 1014
`hermes/tools` (bits 1/2/4), within the operator's `controller.json` `sandbox` ceiling (grain create
`sandbox: S|M|L`). The worker gets a class-sized `/scratch` tmpfs, the class memory, task and CPU
bounds, `LimitFSIZE`, `--disable-userns --cap-drop ALL --new-session`, and still no network.
The catalogue check admits exactly Mini's tools plus the granted names. The gate records the
worker's CPU (`UNIT.cpu`), and the resident pays ceil(CPU / `hermes/compute` seconds) as
`hermes/turn` payments. Commits: fc2cf37a, 84637ef9, 17619fa2, 6240d0e9, 9b8a9ac8, 05b69e7e,
3ffe040a, ec6f7307, 68394077. Controller tests passed on dregg-build (30/30).
J14_TOOLS has not run: it needs a host built at or after bc88a5ab (genesis frame v8), and no
candidate on dregg-build had one when this was written.

**The await bridge** (645fa559): `bend await OBJECT TRANSACTION` / `bend answer SLOT @FILE`, and
the resident tools `mini_pending_awaits` / `mini_answer_await`. A member announces
`await OBJECT TRANSACTION` in the room; that is the allowance. The kernel decides who may answer
(notDecider) and refuses a second answer. Row: J14_AWAIT=1.

**The Oracle through Hermes:**
- Room field `hermes/tools` bit 8 grants the oracle.
- A restricted resident is offered `mini_oracle_discover` and `mini_oracle_call` (never the raw
  `mini_application_api`) when the operator's toolTask binds an Oracle lifetime route
  (docs/oracle-agent-tools.md).
- Every call goes through Mini's application dispatch and purse settlement. In a room without the
  bit, the call is refused `oracle-not-granted` before any dispatch.
- The answer comes back as Hermes's paid reply. Row: J14_ORACLE=1, with J14_ORACLE_TOOLTASK naming
  the route fragment issued for this world's Hermes task. Issuing that fragment inside J14's world
  (codex's `issue-grant` / `prepare-route` against the J14 controller) is the open seam.

**Running J14 on dregg-build.** `/build/lanes/hermes-tier-run/tools-run.sh RUN_DIR` builds the
lane binaries into `/build/lanes/hermes-tier-target` (CARGO_BUILD_JOBS=4), rebuilds the runtime
root with `build-runtime-root` from `/build/lanes/hermes-live-run/hermes-agent` (6d8a8beb) against
those binaries, and runs J0-J5 and J14 keep-going with J14_TOOLS=1 on the pool route. Set `C=` in it
to a candidate whose host carries bc88a5ab, and add `J14_AWAIT=1` for the bridge rows. Constraints:
- Run directories must sit under `/build/lanes/hermes-live-run/` (the sudo rule for the root-owned
  provider table names it).
- J14 holds the user unit `mini-grain-controller@9870001`, so only one J14 runs per account.
- The manifest's `shell` must be the lane `mini`.
- A runtime root built before 05b69e7e needs a full rebuild, not `--rebind`.

**The resident's tools** are added in `resource_tools.rs`:
- the schema goes in `room_tool_specs()`, which is also the provider's function list and the
  catalogue the worker must report;
- reads go in `RoomTools::read`;
- writes go in `ROOM_WRITE_TOOLS`, `validate_room_write` and `write_with_reply_guard`;
- each write is paid (one `hermes/turn`) and journaled as a `room_attempt` before it runs, and its
  exact lookup is `RoomTools::lookup`.

**One uid per resident (L4b; coordinator rulings 2026-10-27: least-privilege route, fix the journal).**
- **Accounts:** `install-hermes` acts as the operator (`mini-core`: sponsor, founder, concierge) and
  as `mini-h-INSTANCE` (system user + same-named group, nologin, home `/var/lib/mini/INSTANCE`,
  linger, one supplementary group = the key broker's socket group). Ownership: instance root and
  runtime root root's; `operator/` the operator's; the rest the resident's.
- **The route** (`cae52528`): step `route` renders `mini-resident-operator-INSTANCE.socket`
  (`run/mini.sock` fd3, `run/mini.control` fd4, `SocketUser` the resident) and `.service`
  (`mini serve-resident-operator-proxy` as the operator). Only the resident uid connects; Host
  frames pass only if the public relay would pass them AND the operation is in
  `transport::RESIDENT_OPERATIONS` (0-11, 17, 19, 30, 31, 96-102, 144, 151, 153, 180); the rest
  are refused by name. The control listener passes `status` only. The route is a strict subset of
  the public surface, so it needs no Lean-side statement. Clients pin the listener creator with
  `MINI_OPERATOR_PEER_UID=0` (or `--operator-peer-uid`, now accepted on every command).
  The list is seeded from run 24's retained custody; **confirm it** from `host-ops.txt` of the first
  J14 on a v8 candidate (the lane's mini already speaks genesis v8: on 23861533 and 3315a908 every
  world bootstrap refuses `unknown field platform`).
- **Create split:** `grain-runtime create SPEC --birth-socket OPERATOR-SOCKET` (operator: the
  sponsor-signed birth only), root `chown -R` the root, then the resident's `create SPEC`.
- **Journal retention** (`history_compaction.rs`): after each prompt record, when the quiescence
  census is empty, decided operations' files (`attempt-`, `query-`, `provider-*`, `policy-*`,
  `source-`, `current-author-`) and decided room-workspace attempts become one line each in
  `state/history.jsonl` (names, exact outcome, source digest); superseded chat reads and
  `sources/q-*.json` go. `retained_outcome` answers exact lookup across the prune (filtered tests).
  Kept: journal, `resident-*`, `prompt-outcome-*`, gates, proposals, `requests/`,
  `room-operations/` (RoomTools::lookup), undecided attempts.
- **Measured before / projected after** (J14 run 24, 3 prompts, 11 paid calls): before 43 MiB and
  8,700 inodes; what compaction keeps there is about 5.4 MiB and 770 inodes, growing about
  40 inodes per prompt (room-operations, requests, resident records) plus about 80 KiB per prompt
  of `state.db` and history lines. **Owed: measure it** (footprint.tsv on the v8 candidate run;
  the target is 32 MiB and about 2,000 inodes over a full summon budget), then send infra (ae95a4eac63b0715e; aed5ecf506cf840af is stopped) one
  batch: the figure, the unit text above, and its four items (controller-entry per-registration
  serviceUid with `User=`/`Group=`/`Requires=user@UID`/`Environment=MINI_OPERATOR_PEER_UID=0` for a
  resident registration; the resident uids as broker provider peers; per uid the user@ drop-in
  `RestrictNamespaces=` + `Delegate=cpu cpuset io memory pids` and a `user-UID.slice` wall;
  `/var/lib/mini/glm` among the allowed write roots).
- **The sandbox threshold** is its own figure (`sandbox.workspaceMib` S 64 / M 128 / L 256 MiB,
  beside `scratchMib` S 16 / M 64 / L 128). The demo's install-hermes grants no sandbox today.
- **Verification so far:** filtered tests on dregg-build (warm `hermes-tier`, branch
  `lane/hermes-b`): grain-runtime `sandbox_`, `history_compaction`, `quiescence`, `grain_create`;
  mini `resident_`, `operator_peer`, `agent_operator`. install-hermes has not run anywhere: it needs
  the demo box with infra's items.

**Quest 2 on the first v8 candidate 0ce31391** (`/build/lanes/hermes-tier-run/hb-q2.sh RUN_DIR` =
tools-run.sh with `C=` that candidate, J14_TOOLS=1 J14_AWAIT=1, root `hroot-q2`; run dirs
`/build/lanes/hermes-live-run/hb-q2-N`):
- run 1: J14 row 8, alice's 200000000 await funding exceeded the J14 sponsor's 100000; fixed
  (b740e6f0, sponsor funded under J14_AWAIT).
- run 2: 122/133, stopped at row 133. Row 122: the room write was refused at the tail bound (head 257
  certified 0 bound 256); J14 never certified its World. Fixed (2aa94b0c, the operator certifies
  before each resident pass). Compaction never ran (journal.providerSettlement persists as the next
  call's anchor); fixed (2aa94b0c, keep from the latest settlement and prompt). `host-ops.txt`:
  1, 2, 3, 4, 5, 17, 19, 96, 97, 98, 144, all on the allowlist; 0, 6-11, 30, 31, 99-102, 151,
  153, 180 unused (narrow after the await rows run). Footprint before compaction: g 63.5 MiB /
  13,329 inodes for 4 prompts and 14 model calls.
- run 3: 126/137, stopped at row 137. Row 126: the tools pass ran out of budget at compute turn
  57 of 180. The gate wrote no CPU record because the controller's stop killed it, so 1800 s was
  charged. Fixed in 1d947aa9 (unverified): systemd's CPUUsageNSec is recorded before the kill.
  **Open, undiagnosed:** the tools pass selected bob's earlier nogrant request ("please append
  'typo fixed' to cell ..."), not his sandbox ask. Hermes was offered the seven sandbox tools
  (provider.shown.jsonl) but answered the old request, so the test provider never took its sandbox
  branch (hermes-test-provider `sandbox_reply_for` keys on `selectedRequest.text` containing
  "sandbox"). Look at the resident's request selection after the nogrant pass
  (`resident/requests.json` in the run's g/state).
- run 4 (`hb-q2-4`, PID file `/build/lanes/hermes-tier-run/hb-q2-4.pid`): filtered tests, then the
  same J14 on 1d947aa9. Its J5 red is a stale harness (a tree before rows-ledger 0a05ab6ba;
  main's journey.sh and journey-stranger.py give J5 8/8 on 0ce31391). Read its J14 rows only.
- From now on (coordinator): every J14 pass runs from main's scripts, and from the next candidate's
  source (it carries the install fix 25cfb86bd and the consent fix) against that candidate's
  binaries. lane/hermes-b equals main at bbbc8277; check the warm `hermes-tier` tree out at
  that candidate's sha before the next run.

**Owed:**
- Run J14_TOOLS and J14_AWAIT on a candidate carrying bc88a5ab and this lane (L4b quest 2:
  `/build/lanes/hermes-tier-run/tools-run.sh`, `C=` the candidate). The same run yields `host-ops.txt`.
- The redteam row's 7 reds (lane/redteam-q2 REDTEAM.md):
  - planted calls 0-3 never reach the controller, because Hermes drops the names first;
  - planted call 7 was not performed;
  - a stale `created-by` check;
  - the injection spent 8 paid turns against a bound of 4.
- The join flow must give each enrolled member an observe reference to `subscribers`.
- A hard `/workspace` quota (a project quota per task directory) is an infra item; the code refuses
  a prompt over the class volume.
