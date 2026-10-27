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
  providers, launcher and the Mini bridge. The new v6 package is about 97 MB compressed.
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

The new browser page offers questions, operation discovery and direct calls
through the same routes agents use. It retains exact request bytes for manual
retry and makes conversation resets explicit. These changes are signed in
[version 6](../deploy/oracle/runtime-v6.md), whose complete archive and signature
passed independent verification. A real Linux Engine/bridge run also passed
tenant separation and exact replay through restart. Mini receiving and the
full agent lifecycle still need qualification. Version 6 requires a fresh grain;
it refuses a legacy shared journal rather than guessing its tenant owner.
See the [bridge contract](oracle-appliance-bridge.md) for the identity boundary.

## Checked state — 27 October 2026

The earlier v4 receiving run installed and started two grains, answered through
Mini's admitted API, demonstrated independent conversation state and exact reply
replay, and completed a clean STOP and missing-data refusal. Its full recovery
journey did not pass; the [retained result](oracle-shared-data-2026-10-27.md)
records the failure and scope.

The v5 agent run has both runtimes installed and its shared dataset published.
Controller account recovery, consent storage repair, public listener restart,
actual worker-policy installation and native controller enrollment now pass.
The latest continuation stopped at an uncertain session operation: historical
lookup was unavailable on the selected socket. Cleanup succeeded and the world
and request are retained. Agent discovery/calls and the complete restart journey
still need to pass. Do not resend that uncertain request as a new operation.
The [v5 evidence](evidence/oracle-u3-acceptance-2026-10-27.json) holds exact state.

The veri7vn U5 v2 source composition has 351 direct operations. Its focused
57-request Engine run observed 37 completed tasks, 13 appropriate refusals or
clarifications, seven valid tasks still incomplete, and no wrong answers. It
includes conversation, geometry and transfer-time repairs beyond installed v5;
that composition is now included in signed v6 with the newer tenant adapter,
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
