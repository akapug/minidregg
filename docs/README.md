# Documentation index

Mini is one shared world whose writes all pass through a Lean admission function; the
[repository README](../README.md) explains it and maps the tree. This page lists the documents
by subsystem, one line each. Where a document and the source disagree, the source is right:
read the declaration it names.

## Start here

- [Objective Bend](OBJECTIVE-BEND.md): the language world programs are written in, with a
  worked composition and what is proved about it.
- [Developing Mini](DEVELOPING.md): where each part of the implementation lives, and how to
  build and check it.
- [The journey](JOURNEY.md): the end-to-end acceptance test.
- [Status](STATUS.md): what the next build carries, each row with its evidence.

## The demo

- [The demo, as a stranger meets it](DEMO-EXPERIENCE-2026-10-27.md): the tour, the web-parity
  rule, and the ranked ambitions.
- [Web front end](WEB-FRONTEND-2026-10-27.md): the browser gateway, its pages and its sessions.
- [App market](APP-MARKET-2026-10-27.md): any Sandstorm app, installed by a member on its own
  origin.
- [Hermes tools](HERMES-TOOLS-2026-10-27.md): what an agent resident's sandbox may use.
- Operator guides: [the join door](../deploy/door/README.md), [payments](../deploy/pay/README.md),
  [agent residents and provider keys](../deploy/hermes/README.md),
  [resident dispatch](../deploy/hermes-dispatch/README.md), [Discord](../deploy/discord/README.md),
  [the shell over ssh](../deploy/shell/README.md), [SPK hosting](../deploy/spk-host/README.md),
  [agent grains](../deploy/grain-host/README.md), [the demo seed](../deploy/demo-seed/README.md),
  [candidate files and formats](../deploy/candidate/INTERFACES.md).
- The Oracle: [the appliance](oracle-appliance.md), [its tools for agents](oracle-agent-tools.md),
  [the Oracle as a grain](ORACLE-GRAIN-2026-10-27.md), [operator guide](../deploy/oracle/README.md).

## Admission and the kernel

- [Hyperedge design](HYPEREDGE-DESIGN.md): a turn as a wide pullback; the design behind
  `Kernel/Turn`.
- [Kernel necessity](KERNEL-NECESSITY.md), [N2](N2-HYPEREDGE-LIMIT.md),
  [N4](N4-DISTRIBUTIVE-LAW.md): the universal properties the kernel is built to satisfy.
- [Kernel twin audit](KERNEL-TWIN-AUDIT.md): duplicated kernel structures and the decisions
  they wait on.
- [One receiver](design/RECEIVER.md): the receiving design behind `Theory.Receiving`.
- [Law composition](design/law-composition-source-codec.md) and
  [world-kind methods](design/world-kind-executable-methods.md).
- [Seats](SEATS.md): seats and invitations, with offer safety over the Book.
- [Application protocol allocations](APPLICATION-PROTOCOL-ALLOCATIONS.md): the registry of
  event codec tags.
- [Resource money operations](RESOURCE-MONEY-OPERATIONS.md) and
  [its JSON](RESOURCE-MONEY-JSON.md).
- [Per-member request rate](PD-HOST-RATE-DESIGN.md), [thin birth](THIN-BIRTH-2026-10-28.md).
- [Effects revival](EFFECTS-REVIVAL.md): deriving kernel effects from declarations.
- [Proofs at admission](ZK.md): when Mini may admit by proof, and what an Objective proof
  establishes.
- [Observation and physical roots](OBSERVATION-AND-PHYSICAL-ROOTS.md): logical world roots
  versus physical Store roots.
- [Protected authored fragments](contracts/protected-authored-fragments.md).

## The language

- [Tutorial](OBJECTIVE-BEND-TUTORIAL.md), checked by `scripts/check-objective-tutorial.ts`.
- [Front end](OBJECTIVE-BEND-FRONTEND.md): parse, elaborate, type.
- [Activities and events](OBJECTIVE-BEND-EVENTS.md), [surfaces](OBJECTIVE-BEND-SURFACE.md),
  [backends](OBJECTIVE-BEND-BACKENDS.md).
- [Modular typing](objective-bend/MODULAR-TYPING.md), [reflection](objective-bend/REFLECTION.md),
  [proof engineering](../PROOF-ENG-DESIGN.md).
- World programs: [markets and collectives](BEND-COLLECTIVE-DOMAINS.md),
  [the resident service commons](BEND-RESIDENT-SERVICE-COMMONS.md),
  [the world programmer guide](../native/resource-client/WORLD-PROGRAMMER.md).

## The Host and the Store

- [Native Host](NATIVE-HOST.md): building and operating the Host.
- [Lean qualification](LEAN-QUALIFICATION.md): the Lean build targets and what each checks.
- [Durable Store](DURABLE-STORE.md): files, schema, backup and restore.
- [Hot path](HOT-PATH-2026-10-27.md): the signed-write path and its representation.
- [Carry verifier](CARRY-VERIFIER.md), [audit phase timing](audit-phase-timing.md),
  [observation batches](latency-observation-batch-2026-10-02.md),
  [resource scope queries](latency-resource-scope-2026-10-02.md).
- [Connection bounds](NATIVE-MULTIUSER-CAPACITY.md), [async request custody](ASYNC-NATIVE-CUSTODY.md),
  [source-agreement reader](SOURCE-AGREEMENT-READER.md),
  [deployment manifest](DEPLOYMENT-MANIFEST-JOIN.md).

## Clients, keys and consent

- [The client](../native/resource-client/README.md): the `mini` command.
- [SDK](SDK.md), [SDK design](design/SDK-DESIGN.md), [post-quantum signing](SDK-PQ.md).
- [Signing consent](CLIENT-SIGNING-CONSENT.md): the client derives what a key may sign.
- [Receipt continuity](RECEIPT-CONTINUITY.md) and [custody across a carry](RECEIPT-CARRY.md).
- [Key commitment adoption](../native/resource-client/KEY-ADOPTION.md).
- [Fleet surface](FLEET-SURFACE.md) and [migrating helm to it](FLEET-MIGRATION.md).
- [Resident context](RESIDENT-CONTEXT.md), [shared room names](SHARED-NAMES.md).

## Privacy

- [Private cell](PRIVATE-CELL.md) and [private rooms](PRIVATE-ROOMS-DESIGN.txt).
- [MPC profile P2](MPC-PROFILE-P2.md), [distributed degree proofs](DZK-REFERENCE.md),
  [Sh2t-Id sharing](SH2T-ID-REFERENCE.md): the private backend.
- Traffic: [privacy profile P1](TRAFFIC-PRIVACY-PROFILE-P1.md),
  [PQ mailbox](../native/resource-client/PQ-MAILBOX.md),
  [cohort TCP](../native/resource-client/COHORT-TCP.md).

## Agreement across domains

- [Distributed design](DISTRIBUTED-DESIGN.md).
- [Generic Simplex](GENERIC-SIMPLEX-NATIVE.md): the BFT engine compiled native.
- In the opt-in research library: [portable continuation](PORTABLE-CONTINUATION.md),
  [regime-typed installs](design/regime-typed-installs.md).

## Applications and residents

- [SPK lifecycle](SPK-LIFECYCLE.md), [resident privilege boundary](SPK-RESIDENT-PRIVILEGE-BOUNDARY.md).
- [SPK RPC](../native/spk-rpc/README.md), [grain runtime](../native/grain-runtime/README.md),
  [inference scheduler](../native/inference-scheduler/README.md).

## Proof systems

- [Selvage recomposition](SELVAGE-RECOMPOSITION.md): the design ledger and its obligations.
- [Selvage completeness](SELVAGE-COMPLETE.md), [receipt encoding (OB-3)](OB3-RECEIPT-ENCODING.md),
  [proof-system survey](PROOF-SYSTEM-SURVEY.md).
- Decisions: [authenticated column history](decisions/D-0001-authenticated-column-history.md),
  [canonical hyperedge kernel](decisions/D-0002-canonical-hyperedge-kernel.md),
  [why Selvage](decisions/D-0004-why-selvage.md),
  [hyperdocuments](decisions/D-0005-hyperdocument-semantic-family.md),
  [a refuted floor](decisions/D-0006-polishchuk-spielman-unfixed-floor-refuted.md),
  [Rust-native authority](decisions/2026-08-09-rust-native-authority.md).
- [Project design](../PROJECT.md) and [the atlas](../ATLAS.md): the founding design.

## The fn transport

fn is not part of this demo. Its consumer contracts are the `FN-*.md` files in this directory.

## How the project is run

[The plan](DEMO-PREFIX-2026-10-26.md), [coordination](COORDINATION-2026-10-27.md),
[the hbox pipeline](PIPELINE-HBOX.md), [the perf workload](PERF-WORKLOAD.md),
[the backlog](BACKLOG-2026-10-27.md), and the `*-STATE.md` files. Reviews are under
[`review/`](review/) and dated evidence under [`evidence/`](evidence/); both are records of
the run or reading they name, not current descriptions.
