# Mini

Mini is one shared world in which people, applications and agents submit writes to the same
admission path, and that path is written in Lean. An admitted write yields a durable world
root; a refused write names the clause that refused it and the request that would have passed;
a write whose reply was lost stays undecided and keeps its exact retry, so nothing is done
twice. Documents, authority, money, programs and applications all go through that one path,
and computation proposes; authority admits: a program can propose a change without gaining
permission to make it ([the demo, as a stranger meets it](docs/DEMO-EXPERIENCE-2026-10-27.md) §0).

The repository and the host binary keep the older name, minidregg.

## Try it

- **The demo**: <https://demo.dregg.online>, in a browser with nothing installed. It is
  temporary and shuts down on 11 November 2026, when everything on it is erased. The join page
  stays closed until the owner opens it; the public pages are readable before then.
- **The project site**: <https://emberian.github.io/minidregg/>, with pages on the
  [language](https://emberian.github.io/minidregg/language.html), the
  [laws](https://emberian.github.io/minidregg/laws.html) and the
  [architecture](https://emberian.github.io/minidregg/architecture.html).

## The repository

Lean owns meaning and admission; Rust handles the physical boundary (clients, keys, storage,
transport, the browser gateway, the application sandbox) and decides nothing about what is
allowed.

| Directory | What it is |
|---|---|
| `Kernel/` | Admission in Lean: resources, capabilities, laws, the world transition `World.admit`, durable receiving |
| `Pred/` | The one predicate algebra that laws are written in |
| `Compiler/` | Wire codecs, refusal reasons, and the arithmetization compilers |
| `Theory/` | The metatheory, which never imports the design it reasons about (`scripts/check-import-boundary.sh` checks this) |
| `Selvage/`, `Assurance/` | The proof-system mathematics, and the only place where kernel objects and proof-system objects meet |
| `Host/` | The native receiving process; `Host.Main` builds the `minidregg-host` executable |
| `protocol/` | The registry of Host operations, checked against the Host's receivers |
| `native/` | The Rust crates: `resource-client` (the `mini` command and its web pages), `mini-sdk` and `mini-sdk-ts` (the client SDK: consent-gated signing and the record that keeps each attempt's exact retry), `mini-web` and `mini-web-spawn` (the browser gateway), `mini-kernels` (hot Rust kernels behind Lean `@[extern]`), `grain-runtime` and `spk-host` (Sandstorm applications), `mini-keys`, `discord-entrance`, `pay-watcher` |
| `prover/` | Native arithmetic, hash and sumcheck kernels used by the Lean side |
| `world/` | Example world programs in Objective Bend (`.obend`): stories, markets, ballots, bounties; most carry a cohort of expected outcomes that `scripts/check-world-cohorts.sh` checks |
| `deploy/` | Everything that runs on the demo box: the candidate build and its run script, the join door, the web front end, agent residents, payments, the policy text |
| `scripts/` | Build, generation and check scripts |
| `docs/` | Design documents, the plan, reviews and dated evidence; [`docs/README.md`](docs/README.md) is the index |
| `website/` | The project site, plain HTML |

## Running it

Lean modules and builds need a warm Lake cache (Mathlib is a dependency); Linux builds are the
supported path.

```sh
lake env lean Kernel/World.lean            # check one Lean module
lake build Minidregg                       # the whole Lean tree
scripts/build-mini-kernels.sh              # the Rust kernels the compiled Lean links
scripts/build-native-host.sh --help        # the native Host
cargo nextest run -p <crate> -E 'test(<pattern>)'   # a filtered Rust test run
scripts/check-import-boundary.sh           # the import boundary between layers
```

A full candidate, its Store and the end-to-end journey
([deploy/candidate/INTERFACES.md](deploy/candidate/INTERFACES.md)):

```sh
deploy/candidate/build.sh --out /srv/mini/candidate-<commit>
C=/srv/mini/candidate-<commit>
$C/params.sh fill-genesis /srv/mini/genesis-params.json
$C/run.sh init  --manifest $C/manifest.json --params /srv/mini/genesis-params.json --state /srv/mini/store-a
$C/run.sh start --state /srv/mini/store-a
native/resource-client/journey.sh $C/manifest.json /srv/mini/journey-1
```

The journey's verdict is `journey-result.json` and its first step that did not pass, not the
exit status alone ([docs/JOURNEY.md](docs/JOURNEY.md)). The developer guide is
[docs/DEVELOPING.md](docs/DEVELOPING.md).

## Read next

- [What the demo is](docs/DEMO-EXPERIENCE-2026-10-27.md): the tour a stranger takes and what it shows.
- [The plan](docs/DEMO-PREFIX-2026-10-26.md): the work and the conditions for opening the demo.
- [The architecture page](https://emberian.github.io/minidregg/architecture.html): admission, laws, receipts, consent, private rooms.
- [docs/STATUS.md](docs/STATUS.md): what the next build carries, each line with its evidence.
- [ATLAS.md](ATLAS.md): the founding diagnosis and the design laws.
- For contributors: [HANDOFF.md](HANDOFF.md), then [how the project works](docs/COORDINATION-2026-10-27.md) and [AGENTS.md](AGENTS.md).

## Sibling repositories

- [`dregg`](https://github.com/emberian/dregg): the whole first system (working name *breadstuffs*) that this tree rebuilds at a fraction of its size.
- [`nanodregg`](https://github.com/emberian/nanodregg): a single-writer rebuild whose laws are the target shape for this tree; its testground runs at <https://nano.demo.dregg.online/>.
- [`zkml-research`](https://github.com/emberian/zkml-research): zero-knowledge and machine-learning research.
- [`degg-research`](https://github.com/emberian/degg-research): multi-party computation and homomorphic encryption for coordination.
- [`fn`](https://github.com/emberian/fn): an NNTP transport for exchange between Mini nodes, not part of this demo.
- [`delvetalk`](https://github.com/emberian/delvetalk): the conversations and design talks behind all of it.
