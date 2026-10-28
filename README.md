# Mini

Mini is a shared world where people, applications and agents all change state through one
admission function, written in Lean. Every write is admitted or refused:

- An admitted write produces a new world root and a receipt.
- A refused write names the law clause that refused it, and Mini can show the request that
  would have been admitted instead.
- If the reply to a write is lost, the write stays undecided. The client kept the exact bytes
  it sent, so the retry is the same call and the effect happens at most once.

Documents, grants, money, programs and installed applications all go through that same path.
A program can propose a change, but it cannot admit one: admission checks the proposer's
authority against the current laws.

The repository and the host binary still use the older name, minidregg.

## Try it

**The demo** is at <https://demo.dregg.online>. It runs in a browser with nothing to install.
It is temporary: it shuts down on 11 November 2026 and everything on it is erased. Everything
on it is world-readable, and a hosted account's signing key is kept on the box. Logins and the
join page stay closed until the owner opens them; the public pages are readable before then.

Once you have joined, you can:

- write documents, link them and transclude a live range of someone else's;
- try an edit you have no grant for, see the clause that refused it, and paste the request
  that `can --any` says would pass;
- give an agent resident a narrow grant and a budget, watch its writes land as paid receipts,
  then revoke the grant and watch its next attempt get refused;
- install an application from the Sandstorm app store and open it on its own origin;
- play the built-in story under its sealed law, or install a law on your own document;
- run an Objective Bend program with `bend`;
- use the same commands from the web pages or from `mini shell` over ssh, and post to your
  rooms from Discord.

[What this edition carries](https://emberian.github.io/minidregg/edition.html) says which of
these are built and which are still landing.

**The project site** is <https://emberian.github.io/minidregg/>, with pages on the
[language](https://emberian.github.io/minidregg/language.html), the
[laws](https://emberian.github.io/minidregg/laws.html) and the
[architecture](https://emberian.github.io/minidregg/architecture.html).

## The repository

Lean decides what is allowed. Rust handles the physical edges (clients, keys, storage,
transport, the browser gateway, the application sandbox) and makes no admission decisions.

| Directory | Contents |
|---|---|
| `Kernel/` | Admission: resources, capabilities, laws, the world transition `World.admit`, durable receiving |
| `Pred/` | The predicate algebra laws are written in |
| `Effects/` | The effect derivation engine: an effect is declared once, and its executor, term and descriptor are derived from the declaration |
| `Compiler/` | Wire codecs, refusal reasons, the Objective Bend front end, the arithmetization compilers |
| `Theory/` | Metatheory; never imports the design it reasons about (`scripts/check-import-boundary.sh`) |
| `Selvage/`, `Assurance/` | Proof-system mathematics, and the one place kernel objects meet proof-system objects |
| `Host/` | The native Host; `Host.Main` builds the `minidregg-host` executable |
| `TokenCensus/` | The census of private constructors: each must be minted only in its home module, and a planted forgery must be caught |
| `protocol/` | The registry of Host operations, checked against the Host's receivers |
| `native/` | The Rust crates (below) |
| `prover/` | Native arithmetic, hash and sumcheck kernels used by the Lean side |
| `world/` | Example world programs in Objective Bend (`.obend`): stories, markets, ballots, bounties; `scripts/check-world-cohorts.sh` checks their expected outcomes |
| `examples/`, `tests/`, `Fixtures/`, `Verify/`, `testing/` | Worked Objective Bend examples, tests, recorded fixtures and verification harnesses |
| `deploy/` | What runs on the demo box: the candidate build, the join door, the web front end, agent residents, the app market, payments, the policy text |
| `scripts/` | Build, generation and check scripts |
| `docs/` | Design documents and dated evidence; [`docs/README.md`](docs/README.md) is the index |
| `website/` | The project site, plain HTML |

The main crates under `native/`:

- `resource-client`: the `mini` command, its shell, and the server-rendered web pages.
- `mini-sdk`, `mini-sdk-ts`: the client SDK (consent-gated signing, and the record that keeps
  each attempt's exact retry).
- `mini-web`, `mini-web-spawn`: the browser gateway and the helper that runs a member's
  session.
- `spk-host`, `spk-rpc`, `grain-runtime`: Sandstorm applications and agent tasks, sandboxed.
- `mini-keys`: the key broker, the one process that holds provider keys and secrets.
- `mini-kernels`: Rust implementations of hash functions the compiled Lean calls through
  `@[extern]`; Lean keeps the reference definitions and test vectors.
- `discord-entrance`, `pay-watcher`: the Discord gateway and the Solana payment watcher.

## Building and running

Lean builds need a warm Lake cache (Mathlib is a dependency). Linux is the supported platform.

```sh
lake env lean Kernel/World.lean            # check one Lean module
lake build Minidregg                       # the whole Lean tree
scripts/build-mini-kernels.sh              # the Rust kernels the compiled Lean links
scripts/build-native-host.sh --help        # the native Host build
cargo nextest run -p <crate> -E 'test(<pattern>)'   # a filtered Rust test run
scripts/check-import-boundary.sh           # the import boundary between layers
```

To build a candidate, start a Store from it and walk the end-to-end journey (files and formats
in [deploy/candidate/INTERFACES.md](deploy/candidate/INTERFACES.md)):

```sh
deploy/candidate/build.sh --out /srv/mini/candidate-<commit>
C=/srv/mini/candidate-<commit>
$C/params.sh fill-genesis /srv/mini/genesis-params.json
$C/run.sh init  --manifest $C/manifest.json --params /srv/mini/genesis-params.json --state /srv/mini/store-a
$C/run.sh start --state /srv/mini/store-a
native/resource-client/journey.sh $C/manifest.json /srv/mini/journey-1
```

The journey writes `journey-result.json`. Read its first step that did not pass, not just the
exit status ([docs/JOURNEY.md](docs/JOURNEY.md)). [docs/DEVELOPING.md](docs/DEVELOPING.md) is
the developer guide.

## Read next

- [The architecture page](https://emberian.github.io/minidregg/architecture.html): admission,
  laws, receipts, consent, private rooms.
- [docs/README.md](docs/README.md): the documentation index, by subsystem.
- [docs/STATUS.md](docs/STATUS.md): what the next build carries, each line with its evidence.
- [Objective Bend](docs/OBJECTIVE-BEND.md): the language world programs are written in.
- [The app market](docs/APP-MARKET-2026-10-27.md) and
  [agent residents](deploy/hermes/README.md).
- [The Oracle appliance](docs/oracle-appliance.md): question answering with checked evidence,
  and [its tools for agents](docs/oracle-agent-tools.md).
- [ATLAS.md](ATLAS.md): the founding diagnosis and the sixteen design laws.
- Contributors: [HANDOFF.md](HANDOFF.md), then [AGENTS.md](AGENTS.md).

## Sibling repositories

- [`dregg`](https://github.com/emberian/dregg): the first, much larger system (working name
  *breadstuffs*) that this tree rebuilds.
- [`nanodregg`](https://github.com/emberian/nanodregg): a single-writer rebuild whose laws are
  the target shape for this tree; its testground runs at <https://nano.demo.dregg.online/>.
- [`zkml-research`](https://github.com/emberian/zkml-research): zero-knowledge and
  machine-learning research.
- [`degg-research`](https://github.com/emberian/degg-research): multi-party computation and
  homomorphic encryption for coordination.
- [`fn`](https://github.com/emberian/fn): an NNTP transport for exchange between Mini nodes; not
  part of this demo.
- [`delvetalk`](https://github.com/emberian/delvetalk): the conversations and design talks behind
  the project.
