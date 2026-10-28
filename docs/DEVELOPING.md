# Developing Mini

Read [the documentation index](README.md) and [Objective Bend](OBJECTIVE-BEND.md) first.
[AGENTS.md](../AGENTS.md) has the repository's working and build rules. Checking an authored
program, preparing a native method proposal and qualifying a new runtime are three different
operations, and this guide takes them in turn.

## Find the implementation you are changing

| Question | Source to follow |
| --- | --- |
| What does an Objective Bend program mean? | [OpenRecursion](../Theory/ObjectiveBendOpenRecursion.lean): `Term`, `Step`, `Evaluates` (the lazy reference semantics) |
| How does it execute? | [DemandMachine](../Theory/ObjectiveBendDemandMachine.lean): `stepRaw`, `runBounded`; [DemandData](../Theory/ObjectiveBendDemandData.lean) and [DemandCapacity](../Theory/ObjectiveBendDemandCapacity.lean): deep result extraction under a capacity policy |
| How is it typed? | [Types](../Theory/ObjectiveBendTypes.lean), [Typing](../Theory/ObjectiveBendTyping.lean): `check` returns an actual derivation |
| What does a program identity commit? | [Evaluator](../Compiler/Evaluator.lean), [Program codec](../Compiler/NockProgramCodec.lean) (the name is historical; the record identifies more than Nock programs) |
| How does a real method become checked effects? | [WorldKindMethods](../Kernel/WorldKindMethods.lean) → [ResourceTransaction](../Kernel/ResourceTransaction.lean) → [Run](../Kernel/Run.lean) → [WorldMethodTrace](../Kernel/WorldMethodTrace.lean) |
| Where do native fields and signed views come from? | [WorldKindDescriptor](../Compiler/WorldKindDescriptor.lean), [WorldKindProjection](../Kernel/WorldKindProjection.lean), [Host JSON](../Host/Json.lean) |
| Where is the client method/proposal path? | [world_kind.rs](../native/resource-client/src/world_kind.rs), [workspace.rs](../native/resource-client/src/workspace.rs), [shell.rs](../native/resource-client/src/shell.rs) |
| What owns durability? | [DurableReceiver](../Kernel/DurableReceiver.lean), [DurableReceiverIO](../Compiler/DurableReceiverIO.lean), [store contract](DURABLE-STORE.md) |
| Is there a circuit or FHE specialization? | No. The circuit, natural-number and FHE specializations of the upstream Bend kernel were deleted on 2026-10-04; deriving them from the demand machine is open work |

Objective Bend's semantics, machine and typing live in `Theory/ObjectiveBend*.lean`.
The front end is Lean: `Compiler/ObjectiveBendParse.lean` (parser),
`Compiler/ObjectiveBendElaborate.lean` (surface to core), `Compiler/ObjectiveBendFrontEnd.lean`
(driver and its checked result) and `Host/ObjectiveBendFrontEnd.lean` (capture, elaborate,
preview commands; [front end](OBJECTIVE-BEND-FRONTEND.md)). `Host/ObjectiveBendPreview.lean`
checks and runs a decoded core term; `Kernel/ObjectiveBendPreparedOutput.lean` and the adapters
`Compiler/ObjectiveBendPlanAdapter.lean`, `Compiler/ObjectiveBendResultAdapter.lean`,
`Compiler/ObjectiveBendCombinedResult.lean` and `Compiler/ObjectiveBendGenericResult.lean` turn a result into a
Plan (`Output`, `Kernel/ObjectiveBendNativeAdmission.lean:247`). The
[language guide](OBJECTIVE-BEND.md) states what each of these proves and where
the trusted boundary sits. The `Theory/ObjectiveBend*` proofs
are the separate `ObjectiveProofs` library, gated by `scripts/check-objective-proofs.sh
proofs`; a green default build re-checks none of them. A theorem that can be imported is not
installed until a native registry or profile consumes its module.

## Run an Objective Bend example

With the pinned Lean toolchain and the imported `Theory` modules compiled under the
[bounded build policy](#build-and-verify-without-disturbing-another-run), from the
repository root:

```sh
lake env lean --run tests/objective-bend-source/CheckDemandData.lean
lake env lean --run tests/objective-bend-source/CheckDemandCapacity.lean
scripts/check-objective-examples.sh
```

The first two are unit tests of the demand machine: deep result extraction and its
failures (budget, duplicate field, closure leaked into data, cycle), and a capacity
policy that suspends and later resumes a computation. They report through their exit
status and printed lines. The third runs the typed examples in
[examples/objective-bend-world/reference/](../examples/objective-bend-world/reference/)
(GenericExtensionReuse, EvenOddTen, TwiceReview, LazySharedField). Each embeds the
typed packet the current front end produces for its `.obend` source
(`<Name>.typed.json`) and states the observation as a theorem: the packet passes
`check`, `runBounded` finishes with the pinned result, and the proof rests on
`native_decide`, which `#assert_compiled` re-runs. The script fails if a packet is
stale against the front end (`--refresh` rewrites it), if a driver does not
elaborate, if its printed summary differs from the `preview-cohort.json` row, or if
the whole preview cohort fails (`--no-cohort` skips that last row). It needs `bun`,
and takes the toolchain and built `Theory` modules from `LAKE_ROOT` (default: this
repository); it compiles `Theory.AssertCompiled` and `Host.ObjectiveBendPreview`
itself into a scratch directory, so neither has to be built first. The source-to-execution route
(capture, elaborate, check, run) is the preview tooling described in the
[language guide](OBJECTIVE-BEND.md#writing-a-program).

None of these commands installs a method, creates an instance, spends credits,
emits a world effect or verifies a private backend.

## Use existing native methods

These commands use the native world-object interface; they do not publish arbitrary
Objective Bend source. You need an enrolled workspace and a matching Host and
configuration. Enrolment and reference import are in the
[client README](../native/resource-client/README.md); importing a reference never creates a
grant.

To see the shell's help for one verb:

```sh
mini shell --socket "$SOCKET" --host "$HOST" --config "$CONFIG" \
  --workspace "$WORKSPACE" --home "$SESSION_HOME" --line 'help instance'
```

The variables are your deployment's absolute paths. Inside the shell, with names from your
own workspace:

```text
kind show KIND
instance show INSTANCE
instance call PROPOSAL INSTANCE METHOD
submit PROPOSAL
retry PROPOSAL
```

`instance show` exposes the signed instance and its methods. `instance call`
prepares a retained proposal; `submit` attempts the actual invocation. Repeating
the same method proposal ID retains its intent and consent rather than computing
a new one. `retry` uses the retained attempt for exact-call recovery. If the
outcome is uncertain, preserve that attempt; a new proposal is a new operation.

For explicit compute funding the supported form is:

```text
instance call PROPOSAL INSTANCE METHOD --fund ACCOUNT --max-compute-credits N
```

The two funding options go together. The compute ceiling is separate from the command's
byte cost, and the account, capability, law and quote still apply; an unfunded request
never consents to an arbitrary payment. The
[world programmer guide](../native/resource-client/WORLD-PROGRAMMER.md) gives
native definition and program authoring details, including a real poll method.

## Trace a proposed feature all the way through

For a new authored method or reusable spec:

1. Define its input/result types and its required and provided methods. Include
   a composition that is incomplete until another author supplies a requirement.
   `requires` is not yet checked at composition; say so in the test.
2. Retain the original source, locked imports and elaborated core. Check the
   actual core term with the Objective Bend checker and run that same term.
3. Specify exact typed Plan outputs, dependencies, ordering, charge and independent
   return schema. Missing samples refuse; placeholder zeroes are not bindings.
4. Follow those bytes into actual native prepared effects and current authority.
   Preserve read guards, accounting, exact retry and durable outcome. Add a new
   shared effect only at its semantic owner, then connect its consumers.
5. Exercise a successful receiving path and a relevant refusal: stale source,
   missing requirement, changed root, wrong audience or insufficient funding.
   Scope the check to the changed contract; a prose edit needs no compiler rebuild.

For a new backend, retain the same semantic statement and bind its real verifier
or execution evidence to exact code, input, output and profile. An enum variant,
backend label or a theorem conditional on an uninhabited adapter is not a joined
execution route. Use the arithmetic and privacy requirements in
[Objective Bend](OBJECTIVE-BEND.md#backends-and-privacy).

## Build and verify without disturbing another run

The build script's help is the current list of options:

```sh
scripts/build-native-host.sh --help
```

The native route runs in an independent snapshot with independent writable
package/build state. Lake builds the import closure in parallel; every real Lean
process holds one of the host's `MINIDREGG_LEAN_SEATS` seats (shared by every build
under `MINIDREGG_LEAN_SEAT_ROOT`), which is the only bound on concurrent compilers.
`MINIDREGG_LEAN_THREADS` (threads per Lean) and `MINIDREGG_NATIVE_JOBS` (concurrent C
compiles) take positive integers. `LEAN_NUM_THREADS` alone does not limit Lake's
process fanout. A full deliberate qualification uses:

```sh
scripts/build-native-host.sh --umbrella \
  --output "$FRESH_BUILD_DIR" --binary "$FRESH_BUILD_DIR/minidregg-host"
```

When a narrow source check or the script's prefix and suffix reuse answers the question, use
that; a documentation change or a disconnected leaf never needs a full rebuild.
[NATIVE-HOST.md](NATIVE-HOST.md) has the build contract.

The native acceptance entrypoint is:

```sh
native/resource-client/journey.sh MANIFEST.json NEW_RUN_ROOT
```

It starts a fresh private Store, so the run root must be new. The manifest names absolute
`host`, `mini`, `store` and `verifier` executables, optionally with their hashes. The script
has no `--help`; its header lists the steps and inputs ([JOURNEY.md](JOURNEY.md) explains
them). The verdict is `journey-result.json` and its first step that did not pass, not the
exit status of a pipeline.

The world-method hooks are not journey steps; the
[world programmer guide](../native/resource-client/WORLD-PROGRAMMER.md) has their fixtures,
which need a profile, activation and funding. A dated journey or runbook is evidence for the
candidate it ran on, not for whatever executable is on your PATH.

## Recording a result

An evidence entry names the source and artifact identity, the exact command, the inputs, the
outcome, the receiver and the claim it supports. Keep a failure when it shows a real boundary.
Keep keys, private URLs and messages to particular people out of the repository. When
behaviour changes, update the contract document that owns it and its example.
