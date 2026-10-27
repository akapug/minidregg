# Mini

> **The Dragon's Egg repositories.**
>
> - [`dregg`](https://github.com/emberian/dregg): the whole system built first (working name *breadstuffs*), waiting to be resumed or composted.
> - [`minidregg`](https://github.com/emberian/minidregg): the production demoland and the spec/battleground the rebuild measures itself against.
> - [`nanodregg`](https://github.com/emberian/nanodregg): the single-writer rebuild: twelve laws, a judge that refuses, meaningful theorems.
> - [`zkml-research`](https://github.com/emberian/zkml-research): the zero-knowledge / machine-learning research line.
> - [`degg-research`](https://github.com/emberian/degg-research): dark coordination: MPC/FHE swarm coordination research.
> - [`delvetalk`](https://github.com/emberian/delvetalk): the conversations and design talks behind all of it.

**Mini is one shared world in which people, applications and agents submit writes to the
same Lean-owned admission path.** An admitted write yields a durable world root. A refused
write is explained by the clause that refused it and by the request that would have passed.
An attempt whose reply was lost stays undecided and keeps its exact retry, so nothing is done
twice. Documents, authority, money, programs and applications share that one path, and a
computation can propose a change without acquiring permission to make it
([what the demo is](docs/DEMO-EXPERIENCE-2026-10-27.md) §0).

## The design in one paragraph

**Lean owns semantics and admission; Rust owns the physical boundary.** Every change is a
signed proposal that the Lean Host admits or refuses against the subject's key, its
capabilities, the target's law and the charge, and an admitted change is appended to a
durable, MAC-chained log whose root every receipt names. Rust supplies the clients, signing
and custody, the Store, transport, the browser gateway, the grain sandbox and the hosted
service adapters, and decides nothing semantic. Computation proposes; authority admits: a
correct calculation cannot grant itself permission, a reference is not ownership, and a lost
reply keeps the original attempt and its exact retry rather than licensing a second one. In
the literature's terms, an object-capability world whose reference monitor is a Lean function
with theorems, over an authenticated append-only log
([SYNTHESIS](docs/review/2026-10-26-native-crates/SYNTHESIS.md) §E).

```text
 shell and web verbs (one grammar) · Objective Bend programs · app and resident tool calls
                                         ↓
        signed Command {subject, nonce, targets}        Kernel/ResourceTransaction.lean
                                         ↓
     Lean admission: signature → capability → law → charge        Kernel/World.lean, Pred/
                ↓                        ↓                          ↓
     admitted: log entry,     refused: the clause and       undecided (reply lost):
     world root, receipt      slot values; `can --any`      retained attempt, exact retry
                              prints a request that passes  (`lookup`, `retry`)
```

`World.admit` is the reference transition; plan item C1 puts it in gate mode on the Host's
receive path so the theorems are about the function the writer runs
([plan](docs/DEMO-PREFIX-2026-10-26.md) §3, `Kernel/HostRefinesWorldCore.lean`).

## What you can do

The tour's spine, from a browser with nothing installed
([DEMO-EXPERIENCE](docs/DEMO-EXPERIENCE-2026-10-27.md) §1). Each step is a place in the web
front end ([WEB-FRONTEND](docs/WEB-FRONTEND-2026-10-27.md) §1) and the same verbs in `mini shell`.

1. **Land**: the public world, the laws page (the operation registry, Lean's emitted default
   laws), the receipts stream and the operations room. Surface: `/`, `/registry`.
2. **Join**: a name at the door; the box makes a hosted key and issues one session link; ssh
   key, Discord link and pay-to-enrol come after. Surface: `/join`, `mini-door`, `mini-web-spawn`.
3. **Write, and watch a transclusion move**: `doc new/append/link/transclude/edit`, each
   ending in one outcome (admitted, height, root, receipt). Surface: `/doc`, `history`.
4. **Be refused, and get the yes**: `why` names the clause; `can --any` prints the request
   the law admits; paste it and it is admitted. Surface: `/receipts`, `/grants`, `/laws`.
5. **Delegate, bounded, to an agent**: `delegate --until H` to a Hermes resident, `summon`,
   `ask`; its turns are paid, admitted writes; an out-of-grant attempt lands as a refusal
   receipt; `revoke`, `dismiss`. Surface: `/room/N/resident`, `/purse`.
6. **Lose a reply on purpose**: `--lose-reply-once`; the outcome is undecided; one link is the
   exact retry; the world shows one effect and one charge. Surface: `/receipts/ID`.
7. **Install an application**: `mini apps search/install/open` from the Sandstorm index under
   the request law (`Kernel/AppsRequest.lean`), opened on its own origin
   `<grain>.demo.dregg.online`. Surface: `/apps`, `/grain`.

The doors off the spine: the oracle (veri7vn as a grain), Discord (`/mini link CODE`), the
terminal and ssh, a story room under its sealed law, changing the rules (`law`, `law check`,
`kind`, `program`, `instance`), and the operations room where the box posts its own ships and
drills as a member. **Parity**: everything the shell can do is a form in the browser, derived
from one structured command grammar.

## What is live

From the integrator's latest cut report (2026-10-27) and the plan's §2. Box paths are on
`dregg-build`.

| surface | state | evidence |
|---|---|---|
| Rehearsal ship #2 on `dregg-demo` | serving since 2026-10-27 10:54 UTC, every login closed, reds in the login notice; `mini-health` OK, door on 8796 (`/join` held closed), key broker in the split shape, web gateway and root helper, app front reaching the store (98 apps); restart, certifier and backup drills green (backup pushed, restore check OK) | [plan](docs/DEMO-PREFIX-2026-10-26.md) §2 |
| Discord | live on the box over the gateway, READY as Dragon's Egg; no inbound route | plan §2; `native/discord-entrance` |
| Standing rows, round 3 (candidate `6236826f`) | PASS 131 / FAIL 5 / UNCONFIGURED 9 / UNJUDGED 3 (round 2: 112 / 25 / 8 / 3); reds: `demo` (J12X, K12I), `activity`, `m3`, `hermes` phase E (a 300 s timeout), `jserve` (timing) | `/build/candidates/6236826f…`; rows in `scripts/pipeline/journey-rows` |
| Cut 4 gate (integration `a94bed71`, merged to main at `6b824270`) | FAIL, two reds: the tour's world refuses genesis at J0 with `completionCustodianKeyUnfilled` (the journey bootstrap does not fill the completion key `run.sh init` fills; owner L13); the composed scenario stops at `enroll seal member-4` with "enrollment Plan inspection changed before signing" (owner L1 with the L2 successor) | `/build/candidates/a94bed71…`, `/build/CANDIDATE-a94bed71.md` |
| Web front end, JWF row | 35/35 | `native/resource-client/journey.d/jweb-frontend.sh` |
| Parity (structured command grammar) | 203 leaves dry-run through the real handlers: 0 usage and 0 world refusals; face coverage, not outcome tests | plan §2; `native/resource-client/src/shell_grammar.rs`, `src/web/verbs.rs` |
| Reproducible build (M7) | PASS: a cold build on a second Debian 13 box reproduces all 26 outputs byte for byte | [evidence](docs/evidence/2026-10-27-m7-round2-dregg-ref/) |
| SPK sandbox floor on Debian 13 | audit PASS | [evidence](docs/evidence/2026-10-27-sandbox-floor-dregg-build/) |
| Private-constructor census (`TokenCensus`) | 374 private constructors reviewed as of 2026-10-27, each minted only at home (23 are open `defect` rows, not yet fixed); the census catches a planted forgery for every one of the 374 and 11 scripted fault kinds, red-proving inside `lake build TokenCensus`. Regenerate with `scripts/token-census-count.sh` | [`TokenCensus/Table.lean`](TokenCensus/Table.lean); [`TokenCensus/SelfTest.lean`](TokenCensus/SelfTest.lean) |
| fn transport | The fn transport is not on this demo; the exchange row runs in the nightly against a loopback peer when its image exists. | [AFFORDANCES](docs/review/2026-10-26-deploy/AFFORDANCES.md) §1.7 |
| Lost reply and exact retry | the custody record and its crash tests; the tour's lose-reply, exact-retry and `can --any` paste-back rows PASS on the build box | plan §2; `native/mini-sdk/src/custody.rs` |
| The `public` member | **not live**: its `enroll plan` goes stale while the clock writes, so the front page answers 502 to the public reader. Owner: the client lane | plan §2 |
| Hermes residents on the box | **not live**: the controller is not stood up and `HERMES-LIVE` has not run through the pool route. Owner: L4 | plan §2, §5 R4 |
| Apps on the box | **not live**: the apps world's metered tasks wait on L13's bootstrap verb; Etherpad and TT-RSS qualify from the real store (`japps --box` 22/22), units and ports staged on the box | plan §2; [APP-MARKET](docs/APP-MARKET-2026-10-27.md) |
| The oracle | **not live**: the veri7vn appliance is landing as a grain through the same grain gate. Owner: the oracle lane (ember's codex session) | [Appliance overview](docs/oracle-appliance.md); [ORACLE-GRAIN](docs/ORACLE-GRAIN-2026-10-27.md); plan §5 R15 |
| Pay-to-enrol | **not live**: mainnet endpoints and the enrolment address are configured on the box; the payment observer is fixed at genesis and arrives with rehearsal #3's re-genesis; 50 DREGG a week from the first open day | [enrol-terms.json](deploy/pay/enrol-terms.json); plan §1 |

A row's state is the run it cites, not this commit. The public-opening contract (plan §1) is
measured on the demo box itself.

## How it is built

- **Lean owns semantics.** `Theory/` is candidate-independent (`scripts/check-import-boundary.sh`
  enforces it); `Kernel/` is admission (resources, capabilities, laws, the Book, durable
  receiving); `Pred/` the one predicate algebra for laws; `Compiler/` codecs and the
  arithmetization spine; `Host/` the native receiving process (`Host.Main` is
  `minidregg-host`). The datamodel on one page is
  [AFFORDANCES](docs/review/2026-10-26-deploy/AFFORDANCES.md) §4: one World of cells of 18 kinds,
  persisted as an append-only SQLite `durable_log` with MAC'd checkpoints.
- **Rust owns the boundary.** `native/` holds the `mini` client (`resource-client`), the
  custody machine (`mini-sdk`), the web gateway (`mini-web`, `mini-web-spawn`), the grain
  runtime and SPK host, the key broker (`mini-keys`), the Store helper, the Discord entrance and
  door, and the pay watcher. Hot kernels are Rust under `@[extern]` with `_eq_native` theorems
  (`native/mini-kernels`, [HOT-PATH](docs/HOT-PATH-2026-10-27.md)).
- **The derived path is the only path.** Nothing lands beside what it supersedes; the twin is
  deleted. The operation registry ([`protocol/host-operations.json`](protocol/host-operations.json))
  is checked against the Host's receivers; the default laws are emitted from `Kernel/DefaultLaw.lean`
  by `scripts/gen-default-laws.sh` (and `--check` refuses drift); the shell's verbs are one
  structured grammar that parsing, `help`, completion and the web forms all consume.
- **Statement first.** A keystone enters as a `Prop` with its satisfiable, teeth and
  premise-inhabitation witnesses before proof work, and gets an adversarial audit
  ([`docs/review/2026-10-27-platform-cell-statements/`](docs/review/2026-10-27-platform-cell-statements/)).

The founding map and the sixteen design laws are [ATLAS.md](ATLAS.md) (§1 the diagnosis, §2 the
thesis, §6 the laws, §7 the carve). What the demo is: [DEMO-EXPERIENCE](docs/DEMO-EXPERIENCE-2026-10-27.md).
The work and the opening contract: [DEMO-PREFIX](docs/DEMO-PREFIX-2026-10-26.md). How the project
is developed: [COORDINATION](docs/COORDINATION-2026-10-27.md). Where to start:
[HANDOFF.md](HANDOFF.md). The evidence behind all of it: the review corpus under
[`docs/review/`](docs/review/), including what Mini should become against the literature
([SYNTHESIS](docs/review/2026-10-26-native-crates/SYNTHESIS.md) §E.11: a Lean-authored protocol
projected into one Rust custody machine, capabilities as leases, policy as Lean-emitted tables,
the TCB exhibited, receipts with inclusion) and how to unpin genesis
([GENESIS-COUPLING](docs/review/2026-10-27-genesis-coupling/GENESIS-COUPLING.md) §E).

## Running it

One worktree per lane on a `lane/<name>` branch under `/Users/ember/dev/minidregg-lanes/<name>`
(or `/build/lanes/<name>` on `dregg-build`); never the main worktree, never `git stash`,
named-file commits ([COORDINATION](docs/COORDINATION-2026-10-27.md) §3).

```sh
lake env lean Kernel/World.lean            # one Lean module (a warm .lake)
lake build Minidregg                       # the integration gate, once per round
scripts/build-mini-kernels.sh              # the Rust kernels the compiled Lean links
scripts/build-native-host.sh --help        # the native Host in a snapshot, bounded seats
cargo nextest run -p <crate> -E 'test(<pattern>)'   # filtered, never a whole suite
scripts/check-import-boundary.sh           # Theory/ stays candidate-independent
```

Linux checks, Lean builds and the integration build run on `dregg-build` (`ssh dregg-build`),
every build under `swarm-build`, Lean fan-out bounded by `MINIDREGG_LEAN_SEATS`
([COORDINATION](docs/COORDINATION-2026-10-27.md) §5). A candidate and its journey
([deploy/candidate/INTERFACES.md](deploy/candidate/INTERFACES.md)):

```sh
deploy/candidate/build.sh --out /srv/mini/candidate-<commit>
C=/srv/mini/candidate-<commit>
$C/params.sh fill-genesis /srv/mini/genesis-params.json
$C/run.sh init  --manifest $C/manifest.json --params /srv/mini/genesis-params.json --state /srv/mini/store-a
$C/run.sh start --state /srv/mini/store-a
native/resource-client/journey.sh $C/manifest.json /srv/mini/journey-1
```

Read `journey-result.json` and the first step that did not pass, not the exit status alone
([JOURNEY.md](docs/JOURNEY.md)). The standing rows are `scripts/pipeline/journey-rows`; the
developer guide is [docs/DEVELOPING.md](docs/DEVELOPING.md) and the repository rules
[AGENTS.md](AGENTS.md).

## The demo

`https://demo.dregg.online` on `dregg-demo` (Hetzner, fsn1, Debian 13), with each installed
grain on its own origin under `*.demo.dregg.online`. Rehearsal ships run there now with every
login closed; the **opening target is 2026-10-29**, announced when the public-opening contract
holds (plan §1). The join page is `/join` (the door, [deploy/door](deploy/door/README.md)): a
name, a hosted key, one session link; pay-to-enrol is on mainnet from the first open day. The
demo shuts down on **2026-11-11**, the date written on the join page; the build box
`dregg-build` goes with it. nano's testground runs on the same box at
`https://nano.demo.dregg.online/`.

## Sibling repositories

- [`nanodregg`](https://github.com/emberian/nanodregg): the object of study; its laws are the
  target shape of this tree's consolidation.
- [`dregg`](https://github.com/emberian/dregg) (breadstuffs): the whole first system that
  ATLAS diagnoses.
- [`zkml-research`](https://github.com/emberian/zkml-research) and
  [`degg-research`](https://github.com/emberian/degg-research): where this tree's proof-system
  and MPC research moves.
- [`fn`](https://github.com/emberian/fn): the NNTP transport, used for the fn exchange
  between Mini nodes.
- `veri7vn` (`o7vn`): the oracle, arriving here as an SPK appliance (`deploy/oracle/`).
- `dregg-infra`: the box truth (the demo VM, the build box, `ship.sh`), outside this repository.
