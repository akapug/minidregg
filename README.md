# Mini

Mini is a multi-user system in which people, applications and AI agents keep their documents,
permissions, money and programs in one shared state (the *world*). Every change to the world
is a signed request, and one admission function, written in Lean, admits or refuses it:

- An admitted request produces a new world root (a hash of the whole state) and a receipt.
- A refused request says why. When a resource's *law* (the rule attached to it) refused it,
  the refusal names the clause, and `can --any` can show a write that law would admit.
- If the reply is lost, the client does not know whether the write happened. It kept the
  exact bytes it sent, so looking the call up, or retrying it, returns the original outcome;
  the world records the effect once.

A program can propose a change but cannot admit one: admission checks the proposer's grants
against the current laws.

The repository and the host binary still use the older name, minidregg.

## Try it

**The demo** is at <https://demo.dregg.online>. It runs in a browser with nothing to install.
It is temporary: it shuts down on 11 November 2026 and its data is deleted, except encrypted
backups that expire within 22 days and anything you chose to contribute for research
([the retention text](deploy/policy/RETENTION.txt)). Everything on it is world-readable, and a
hosted account's signing key is kept on the box. Logins and the join page stay closed until the
owner opens them; the public pages are readable before then.

Once you have joined, you can:

- write documents, link them, and embed a live range of someone else's document in yours;
- try an edit that a document's law forbids, see the clause that refused it, and paste the
  write that `can --any DOC` says the law would admit;
- give an AI agent that lives in one of your rooms a narrow grant and a budget, read the
  receipts of its writes and their cost, then revoke the grant and watch its next attempt
  get refused;
- install an application from the Sandstorm app store and open it on its own origin;
- play the built-in story, whose law makes impossible moves fail, or install a law on your own
  document;
- publish and run Objective Bend programs (`bend publish`, `bend run`);
- use the same commands from the web pages or from a shell over ssh
  ([deploy/shell/README.md](deploy/shell/README.md)), and post to your rooms from Discord after
  linking your account with `/mini line:link CODE`.

[The demo status page](https://emberian.github.io/minidregg/edition.html) says which of these
are built and which are still landing.

**The project site** is <https://emberian.github.io/minidregg/>, with pages on the
[language](https://emberian.github.io/minidregg/language.html), the
[laws](https://emberian.github.io/minidregg/laws.html) and the
[architecture](https://emberian.github.io/minidregg/architecture.html).

## The repository

Lean decides what is allowed. Rust handles the physical edges (clients, keys, storage,
transport, the browser gateway, the application sandbox) and makes no admission decisions.
`World.admit` in `Kernel/World.lean` is the model of a world transition;
`Kernel/HostRefinesWorldCore.lean` proves that the Host's deployed path
(`DurableDataIntent.execute`) refines it.

| Directory | Contents |
|---|---|
| `Kernel/` | Admission: resources, capabilities, laws, the world transition `World.admit`, durable receiving |
| `Pred/` | The predicate algebra laws are written in |
| `Effects/` | The effect derivation engine: an effect is declared once, and its executor, term and descriptor are derived from the declaration |
| `Compiler/` | Wire codecs, refusal reasons, the Objective Bend front end, the arithmetization compilers |
| `Theory/` | Metatheory; never imports the design it reasons about (`scripts/check-import-boundary.sh`) |
| `Selvage/`, `Assurance/` | Proof-system mathematics, and proofs that connect kernel objects to it |
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
- `mini-sdk`: the client SDK (consent-gated signing, and the record that keeps each attempt's
  exact retry). `mini-sdk-ts` is its TypeScript twin for building and signing; it has no
  transport and no consent process.
- `mini-web`, `mini-web-spawn`: the browser gateway and the helper that runs a member's
  session.
- `spk-host`, `spk-rpc`, `grain-runtime`: Sandstorm applications and agent tasks, sandboxed.
- `mini-keys`: the key broker, the one process that holds provider keys and secrets.
- `mini-kernels`: Rust implementations of hash functions the compiled Lean calls through
  `@[extern]`; Lean keeps the reference definitions and test vectors.
- `discord-entrance`, `pay-watcher`: the Discord gateway and the Solana payment watcher.

## Building and running

Lean builds need a warm Lake cache (Mathlib is a dependency). Linux x86-64 is the supported
platform. Build the Rust kernels first: Lean loads them while elaborating anything that hashes.

```sh
scripts/build-mini-kernels.sh              # the Rust kernels the compiled Lean links
lake env lean Kernel/World.lean            # check one Lean module
lake build Minidregg                       # the main umbrella target
scripts/build-native-host.sh --help        # the native Host build
cargo nextest run -p <crate> -E 'test(<pattern>)'   # a filtered Rust test run
scripts/check-import-boundary.sh           # the import boundary between layers
```

A *candidate* is a directory of pinned binaries for one commit. To build one, start a private
Store (one world's durable state) from it, and run the end-to-end journey, which starts its
own fresh Store (files, formats and prerequisites in
[deploy/candidate/INTERFACES.md](deploy/candidate/INTERFACES.md)):

```sh
deploy/candidate/build.sh --out /srv/mini/candidate-<commit>
C=/srv/mini/candidate-<commit>
cp $C/genesis-params.example.json /srv/mini/genesis-params.json   # then edit the operator's choices
$C/params.sh fill-genesis /srv/mini/genesis-params.json
$C/run.sh init  --manifest $C/manifest.json --params /srv/mini/genesis-params.json --state /srv/mini/store-a
$C/run.sh start --state /srv/mini/store-a
native/resource-client/journey.sh $C/manifest.json /srv/mini/journey-1
```

This runs a Host and its Store, not the web front end; the demo box's other services are in
`deploy/`. The journey writes `journey-result.json`. Read its first step that did not pass,
not just the exit status ([docs/JOURNEY.md](docs/JOURNEY.md)). [docs/DEVELOPING.md](docs/DEVELOPING.md) is
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
