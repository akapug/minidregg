# Oracle7 / veri7vn appliance

The appliance brings Oracle7's question answering and specialist tools into a
Mini grain. It combines a pinned Oracle7 slim release, reviewed source repairs,
selected veri7vn kernels, Workbench and companion providers. The source and
appliance recipes live in [veri7vn](https://github.com/emberian/veri7vn);
Mini owns package admission, isolation, agent authority and lifecycle.

## What callers can do

Use conversational queries for supported calculations and sourced facts, or
discover a direct operation with its input schema and limits. The packaged
providers include specialist calculations, symbolic mathematics, relations,
weather, table and passage analysis, simulations, forecast checks, image
descriptors and sprite composition. Some workflows remain partial: a named
component does not imply unrestricted browser execution, external connectors,
device access or every upstream asset library.

Agents use `mini_oracle_discover` and `mini_oracle_call` on an established
application lifetime route. Discovery reports the deployed package's actual
operations and availability. Calls retain answer evidence and request identity;
an exact retry returns its retained result. Current Mini admission and purse
settlement still apply. The [agent guide](oracle-agent-tools.md) supplies the
configuration and request examples.

## Runtime, data and state

- **Signed runtime SPK:** Linux Python environment, Oracle code, selected kernels,
  providers, launcher and the Mini bridge. The new v7 package is about 97 MB compressed.
- **Shared public data:** 26 files, about 15 GB, published once by the operator.
  The runtime's signed declaration binds their inventory digest. Mini mounts the
  matching revision read-only at `/opt/oracle-data`; the app cannot choose a host
  path or another dataset. No chunking or reassembly is needed.
- **Private state:** each grain has a separate writable `/var` for conversation
  and request history. The new hosted build divides this into private workspaces
  for each authenticated source session, with separate request journals. The
  installed v5 package predates this pool and retains one workspace per grain.

Publication hashes the data; startup checks protected custody metadata. This
assumes a trusted operator and filesystem. Only deliberately published public
data is supported. A private dataset would need its own access-control design.
The [packaging guide](oracle-shared-data-packaging.md) describes the existing
contract without requiring changes to the SPK format.

## Shared hosting

The new hosted build serves many users and agents from one grain. Mini derives
the tenant identity from the authenticated principal and source session; callers
cannot select another tenant by changing a request or conversation ID. A new
source session gets a new workspace. Two agents using the very same source
session intentionally share its workspace.

The worker pool bounds resident computation independently of tenant count. The
initial class-L configuration permits one resident Oracle worker and 128
persistent workspaces. Idle workers retire before a replacement starts; busy
capacity returns a retryable refusal. Increasing concurrent workers also needs
an appropriate memory budget. Runtime files and the public dataset remain
shared and read-only, while each resident worker has separate process state.

Completed requests replay from disk without starting a worker. Oracle loses
some conversational context when its worker exits, so a new turn after eviction
requires a fresh conversation ID and supplied context. The service reports this
explicitly rather than silently answering without the earlier context.

A completed Linux run exercised arithmetic queries in 32 tenant workspaces with
one observed resident Engine worker. Peak total cgroup memory was 750,977,024 bytes (about 716 MiB)
under the 2 GiB limit. All 32 exact retries returned their retained replies;
conflicting reuse was refused. Restart replay and stale-conversation refusal
started no Engine, and both shutdowns completed. This was a runtime qualification
under shared host load, not a complete Mini receiving journey. The
[qualification report](https://github.com/emberian/veri7vn/blob/dev/project/lanes/U7-tenancy-qualification.md)
records the sampling limits and evidence.
Switching tenants still pays worker startup: first calls took 7.51–103.05 seconds
on that contended host, while exact retries took 1.22–25.98 milliseconds.

The new browser page offers questions, operation discovery and direct calls
through the same routes agents use. It retains exact request bytes for manual
retry and makes conversation resets explicit. These changes are signed in
[version 7](../deploy/oracle/runtime-v7.md), whose complete archive and signature
passed independent verification. A real Linux Engine/bridge run also passed
tenant separation and exact replay through restart. Mini receiving and the
full agent lifecycle still need qualification. Version 7 requires a fresh grain;
it refuses a legacy shared journal rather than guessing its tenant owner.
See the [bridge contract](oracle-appliance-bridge.md) for the identity boundary.

Version 7 also defers operation-catalog construction until the first discovery
or new direct call. Ordinary queries and retained replays avoid that cost;
capabilities reports unknown counts until construction succeeds. A real Engine
check passed discovery, direct calls and byte-identical retries. Observed
readiness was 10.8 seconds, with 8.4 seconds paid later on first discovery;
these are measurements under shared host load, not latency guarantees.

## Checked state — 27 October 2026

The earlier v4 receiving run installed and started two grains, answered through
Mini's admitted API, demonstrated independent conversation state and exact reply
replay, and completed a clean STOP and missing-data refusal. Its full recovery
journey did not pass; the [retained result](oracle-shared-data-2026-10-27.md)
records the failure and scope.

The v5 agent run has both runtimes installed and its shared dataset published.
Controller account recovery, consent storage repair, public listener restart,
actual worker-policy installation and native controller enrollment now pass.
Historical lookup now passes through the selected public socket. A subsequent
recovery guard checked the wrong field of the signed query response and refused
before birth. The corrected runtime preserves all original root and balance
checks. Its next attempt reached session creation, which the fixture's factory
policy refused before submission. Tool cleanup completed, but the parent hold
still needs definite-error settlement; no request was resent or acknowledged.
The qualified native refusal-recovery repair is now integrated. Its one
terminal-only attempt hit the Host frame-read deadline during historical ticket
lookup. The original parent reservation remains held, with no result or ACK.
All owned services are stopped and the namespace is preserved; another attempt
must account for that failure rather than resend the original operation.

The fresh v7 run installed both appliances and admitted a real agent session.
Lifetime-grant planning then refused: its source creates three grants while the
ordinary birth validator requires two. The repair is available on
`lane/oracle-lifetime-grant`: a dedicated frame admits exactly the source's owner,
controller and read-only participant observer; ordinary births retain their
existing restriction. `lane/oracle-grant-factory` adds the separate fresh-world
policy permission for the allocated grant resource. Earlier scoped checks passed
for the production modules, observer boundary and factory predicate. The corrected
source fixture, current dependency closure and codec census still need the
central integrator's validation. No grant was submitted, application started,
or Oracle/browser call made in that run. Cleanup passed and the stopped Store
is preserved. The next positive journey uses a fresh world on a coherent repaired
Mini build. Agent discovery/calls and the complete restart journey remain open.
The [recovery record](evidence/oracle-hosted-recovery-2026-10-27.json) distinguishes
both stopped runs and their exact evidence. The
[factory evidence](evidence/oracle-grant-factory-2026-10-27.json) records its
682 predicate checks and their limits. A subsequent
[provisioning simplification](evidence/oracle-provisioning-configuration-2026-10-27.md)
replaces source-text configuration and enrollment rewrites with explicit inputs
and fixed provisioner phases. The workroom uses the shared genesis template;
its five focused composition/allocation/birth checks now pass on dregg-ref.
The fresh hosted qualification remains in
[ROWS-OWED](ROWS-OWED.md#oracle-appliance), including a new-Host STOP receipt
and an actual browser driver.

The veri7vn U5 v2 source composition has 351 direct operations. Its focused
57-request Engine run observed 37 completed tasks, 13 appropriate refusals or
clarifications, seven valid tasks still incomplete, and no wrong answers. It
includes conversation, geometry and transfer-time repairs beyond installed v5;
that composition is now included in signed v7 with the newer tenant adapter,
but has not yet completed the new Mini receiving journey. Versioned
operation counts are not specialist-panel scores or proof of every answer.

Repeated STOP-history inspection on a retained Store fell from roughly 425 s to
0.414 s with identical output. First inspection still pays the history walk;
see the [replay record](oracle-replay-2026-10-27.md) and
[cold-replay investigation](oracle-cold-replay-investigation-2026-10-27.md).
No result here establishes a public deployment.

## Where to continue

Use [deploy/oracle](../deploy/oracle/README.md) for preparation, signing and import;
its versioned receipts identify actual artifacts. Use the
[acceptance guide](oracle-shared-data-acceptance.md) and retained v5 evidence for
the lifecycle checks. The [market/deployment design](ORACLE-GRAIN-2026-10-27.md)
is a separate consumer of this package; its older pins are not the latest
appliance qualification. Broader upstream coverage and the remaining kernel
refresh are tracked in
[veri7vn's current checkpoint](https://github.com/emberian/veri7vn/blob/dev/project/CONTINUE-2026-10-27.md).
