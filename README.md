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

Each row says what the next shipped build carries, and its state is one of **built** (on main),
**in progress** (being written, not on main complete), or **not in this edition**. Nothing here is
a claim about the running box except the first row. Box paths are on `dregg-build`.

| surface | state | evidence |
|---|---|---|
| The box today | rehearsal #2 is still the build serving on `demo.dregg.online`, with every login closed and `/join` held closed until the owner opens it; the next build is not shipped yet | [plan](docs/DEMO-PREFIX-2026-10-26.md) §2 |
| Admission path, receipts, refusals | built: documents, grants, money, programs and applications go through the Host's Lean-owned admission; a refusal names its clause and the web shows the one request that would have passed | [DEMO-EXPERIENCE](docs/DEMO-EXPERIENCE-2026-10-27.md) tour step 4; `native/resource-client/src/can.rs` |
| Lost reply and exact retry | built: the custody record retains the exact call before it travels, so an undecided attempt is looked up and retried byte for byte; the tour's lose-reply, exact-retry and `can --any` paste-back rows pass on the build box | `native/mini-sdk/src/custody.rs`; DEMO-EXPERIENCE tour step 6 |
| One client wire | built: operation numbers are named constants and consent frames are registered; a gate refuses a literal operation byte in Rust | commits `6445a8b48`, `9cc655c58`; `scripts/host-operations.py` |
| Platform cell | in progress: the cell kind and the install receiver are built; the genesis seed, replay, Host operations and births priced from the cell are not complete | [`Kernel/PlatformCell.lean`](Kernel/PlatformCell.lean); [`Kernel/PlatformInstallReceiver.lean`](Kernel/PlatformInstallReceiver.lean); commits `a0403a358`, `7d5019b4b` |
| Fast Store open | in progress: compaction is built (a cold open of a 483-record Store took 160 to 175 s before it); the checkpoint that carries the world, so an open replays only the records after it, is stated and being proved, and is not on main complete | commit `2421dc511`; [HOT-PATH](docs/HOT-PATH-2026-10-27.md) item (h); commit `107f040d9` |
| Browser join, free and paid routes | built: a name, a hosted key and one session link; the free route has a fixed number of seats; the paid route is 50 DREGG a week on Solana mainnet, with the pay page's audit fixes; not open to strangers until the owner opens the door | [WEB-FRONTEND](docs/WEB-FRONTEND-2026-10-27.md); [enrol-terms.json](deploy/pay/enrol-terms.json); commit `861fe953` |
| Invite codes and a reserve of free seats | built on main, not yet on the box: the last seats of the free route can need an invite code | commit `9e3d6c731`; [`deploy/door/README.md`](deploy/door/README.md) (`inviteReserve`) |
| Web pages and accessibility | built: server-rendered pages, every shell verb a form derived from the command grammar (203 leaves dry-run through the real handlers with 0 usage and 0 world refusals), live-region outcomes | `native/resource-client/src/web/verbs.rs`, `src/shell_grammar.rs`; `native/resource-client/journey.d/jweb-frontend.sh` |
| Export my world | built: one archive of a member's documents, receipts and key, streamed and deleted after download; one export per member per ten minutes | commits `370d606e`, `071aaf95`; WEB-FRONTEND |
| Research consent | built: an unchecked box at the door; the choice is a fact in the member's own world, shown and changeable on the export page | commit `0bf68599`; [`deploy/policy/RETENTION.txt`](deploy/policy/RETENTION.txt); WEB-FRONTEND |
| Stories and laws | built: the built-in tale under its sealed law, and a member can install a law on their own document and see the next write judged | [`Kernel/StoryLaw.lean`](Kernel/StoryLaw.lean); DEMO-EXPERIENCE doors 11 and 12 |
| Objective Bend | built: the `bend` verb is in this edition | [`native/resource-client/src/bend.rs`](native/resource-client/src/bend.rs); [OBJECTIVE-BEND-FRONTEND](docs/OBJECTIVE-BEND-FRONTEND.md) |
| Discord | built: the same subject and receipts over the Discord gateway as on the web; live on the box in rehearsal #2 with no inbound route | `native/discord-entrance`; DEMO-EXPERIENCE door 9 |
| Hermes residents with per-member caps | built: an agent resident in a room on a shared model key, with a per-member share of the spend ceiling (1/40 a day and 1/10 in all of the row's ceiling); not live on the box until the next build ships | [`deploy/hermes/README.md`](deploy/hermes/README.md); commit `39d802f5` |
| Subscriber tier | built: a house Hermes on the `glm-5.3-flash` route in a `subscribers` room, joined by an invitation after `pay subscribers week`, with a Subscribe page | `native/resource-client/src/web/subscribe.rs`; commit `0ac2e8df`; [`deploy/hermes/demo/provider-services.json`](deploy/hermes/demo/provider-services.json) |
| App market: featured apps | built: any Sandstorm package from the real store, 13 featured apps listed first with the interface an agent drives beneath the HTML; qualifying more apps, one write each, is in progress toward two to three dozen | [APP-MARKET](docs/APP-MARKET-2026-10-27.md) §2a; commit `f7b8fe5f` |
| WebDAV, CalDAV and git | built on main: the DAV verbs, chunked request bodies and git push and fetch; bodies over 8 MiB are designed, not built | commit `dfdecbbac`; APP-MARKET |
| Two browsers co-editing one grain | in progress: a second session's route on a running grain is refused; the cause is found and the fix is being stated | APP-MARKET (route registration note) |
| Abuse limits per member | built: connection and in-flight limits per member at the web gateway, an export cooldown, memory, CPU and task size classes for grains; a per-member request rate in the Host is stated and proved but not yet wired in | commit `90f7f959`; commit `879fc8ec1`; [`Kernel/SubjectRate.lean`](Kernel/SubjectRate.lean); [PD-HOST-RATE-DESIGN](docs/PD-HOST-RATE-DESIGN.md) |
| Effect Plans for world programs | in progress: the activity effect's keystone is stated and proved on main; transfers from a program's purse and committed writes are being finished; each new effect is still a hand-written kernel change and deriving them is owed after the demo | [`Kernel/ObjectiveActivityEffect.lean`](Kernel/ObjectiveActivityEffect.lean); commit `b1ff71950`; commit `9123503ff` |
| Reproducible build (M7) | PASS: a cold build on a second Debian 13 box reproduces all 26 outputs byte for byte | [evidence](docs/evidence/2026-10-27-m7-round2-dregg-ref/) |
| SPK sandbox floor on Debian 13 | audit PASS | [evidence](docs/evidence/2026-10-27-sandbox-floor-dregg-build/) |
| Private-constructor census (`TokenCensus`) | 374 private constructors reviewed as of 2026-10-27, each minted only at home (18 are open `defect` rows, triaged in docs/review/2026-10-27-untouched-areas/TOKEN-DEFECTS.md); the census catches a planted forgery for every one of the 374 and 11 scripted fault kinds, red-proving inside `lake build TokenCensus`. Regenerate with `scripts/token-census-count.sh` | [`TokenCensus/Table.lean`](TokenCensus/Table.lean); [`TokenCensus/SelfTest.lean`](TokenCensus/SelfTest.lean) |
| fn transport | not in this edition: the fn transport is not on this demo | plan §5 ("fn is out of this demo") |
| The oracle as a grain | not in this edition | [ORACLE-GRAIN](docs/ORACLE-GRAIN-2026-10-27.md); DEMO-EXPERIENCE door 8 |
| A networked private-computation service | not in this edition | [UNTOUCHED-DEPUTY-STATE](docs/UNTOUCHED-DEPUTY-STATE.md) (private-backend, tier 2 after the opening) |

A row's state is the evidence it cites, not this commit. The public-opening contract (plan §1) is
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
