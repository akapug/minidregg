# Application protocol allocations

The `StableEvent.codecVersion` tags of the application and publication families, and the
contracts behind them. A new family takes its tag here before code uses it, so two
implementations never choose the same one.

## Stable event tags

| `StableEvent.codecVersion` | Family | Defined in |
| --- | --- | --- |
| 10 | Selected release, original v1 | none: retired |
| 11 | Application dispatch | `Kernel/ApplicationDispatchIngress`, `ApplicationDispatchAdmissionIngress` |
| 12 | Application lifecycle BEGIN | `Kernel/ApplicationLifecycleBegin{,Ingress,V2Ingress}` |
| 13 | Selected release, atom-bound v2 | `Kernel/FnSelectiveReleaseIngress` |
| 14 | Source publication authorization | `Kernel/FnSelectiveReleaseSourcePublication` |
| 15 | Application share issuance | `Kernel/ApplicationShareIssueReceiver` |
| 16 | Application lifecycle current claim | `Kernel/ApplicationLifecycleClaim{,Ingress,V2Ingress}` |
| 17 | Selected fn poll coverage | `Kernel/FnSelectedPollCoverage`, `FnConsumerFrontierCore` |
| 18 | Checked application lifecycle completion | `Kernel/ApplicationLifecycleCompletionIngress` |
| 19 | Ordered empty-page consumer progress | `Kernel/FnEmptyPollProgressV2` |
| 20 | Consumer namespace registration | `Kernel/FnConsumerNamespaceRegistration`, `FnConsumerFrontierCore` |
| 21 | Agent dispatch with a claimed reservation | `Kernel/ApplicationDispatchAgentIngress`, `ApplicationDispatchAgentReserveCore` |
| 22 | Grain-backed application share issuance | `Kernel/ApplicationShareIssueGrainReceiver` |
| 23 | Source-bound launch BEGIN v3 | `Kernel/ApplicationLifecycleBeginV3Ingress` |
| 24 | Source-bound launch claim v3 | `Kernel/ApplicationLifecycleClaimV3Ingress` |
| 25 | Source-bound launch completion v2 | `Kernel/ApplicationLifecycleCompletionV2Ingress` |
| 26 | Paid agent dispatch under an explicit persistent agent grant | `Kernel/ApplicationAgentLifetimeDispatchIngress` |
| 27 | Persistent agent grant issuance | `Kernel/ApplicationAgentLifetimeGrantSource` |
| 28 | Checked application session enrollment | `Kernel/ApplicationGrainSessionEnrollmentSource` |

Wire frame revisions, content-object type tags, nullifier codec versions, and
event tags are separate namespaces. Changing a wire frame to v2 does not mean
incrementing its event tag into another family's allocation. Each family must
retain its domain-separated canonical bytes and exact decoding checks.

Event26 carries persistent agent access across prompt generations.
Existing ticket/enrollment origin equality and event21 replay remain unchanged.
The new grant lives in an ordinary content resource, but its birth or payload
alone does not authorize app access. Event27 must atomically join installation
with explicit app delegation authorization at the original verified prefix,
binding a domain-separated signature to the exact grant, original admitted
ticket provenance, bounded permission ceiling, fixed deployment and
never-recycled parent task. Event26 must obtain that issuance certificate
through exact historical replay, then check the current installed grant and
current app delegation law/capability. Tombstones, invalid edits, revoked delegation and schema drift
must refuse. Current parent generation, reserved state, physical root and
signed DRC witness remain per-dispatch fences, distinct from historical issue
origin. Hard disconnect invalidates those in-flight witnesses without silently
turning an old generation-bound ticket into a persistent grant. Operations
72–79 carry it. A host-side generation projection is not sufficient authority.
Issuance signatures retain their exact historical
authority root, registry commitment, app root and policy revision. Do not
recheck an old signature as if signed for the current snapshot, waive those
equalities, or require a new owner signature on every ordinary prompt. Current
rule checks are separate from historical signature verification.

Event 21 is distinct from ordinary event 11: a private physical permit cannot
add payment authority absent from the admitted durable intent. Its claim must
bind the full application/session/ticket/parent/request context, current signed
payer authority, original admitted reserve, physical purse guard, and a one-use
reserve-claim nullifier. Charging remains deferred until a definite application
response or explicit audited reconciliation; admission does not imply delivery
or automatic settlement. Hard disconnect fences the caller, not the shared app.

Event 20 selects a consumer lineage explicitly. Unrelated historical tag-9
records cannot claim or poison another namespace through copied scope fields.
Fresh registration starts at zero; adopting legacy progress requires the exact
authenticated receipt named by the signed registration. A transport ACK is not
an initial authority witness. The current receiver and replay require a fixed
operator gateway pin for the deployment. That pin is not encoded in runtime
parameters today: changing it can invalidate historical replay even when a new
namespace is selected. In-deployment rotation therefore remains unimplemented;
it needs authenticated historical issuer provenance and an explicit migration
rule. A new namespace alone does not implement rotation or justify a cursor reset.

## Native stdio operations

Opcodes 20–85 are this family's operations, and all are active. Their symbols, routes and
receivers are in `protocol/host-operations.json`, which `scripts/host-operations.py` checks
against `Host/Main.lean`. Each family has a submit, a receipt-only lookup (never a delivery
permit), and where a participant signs, a current-image signing plan plus a detached-signature
assembly that commits nothing.

Event28 uses the participant's existing session and descriptor mutation rights,
and a separately signed app observation with a physical read guard. The app is
not an ordinary mutation target: only Alice has the app owner capability in
the integrated allocation. Bob and both agents have allocated app-observe IDs
that require admitted observe-only delegations. Their ticket-observe and
manifest-observe IDs likewise need current grants to the joint command subject;
separate envelopes do not change that subject. Admission must select the original event22 ticket from verified
history, check the installed manifest role schema and ceiling, and atomically
guard the current serving app generation alongside the joint edit. The stable
descriptor atom is created on first enrollment and edited against its exact
old record on renewal. Operations82/83 construct and assemble the current
signed proposal; 84 alone submits through event28, and 85 is receipt-only.

Operations80/81 prepare the separately signed reserve before the ordinary
native invoke. Operations78/79 cover only the post-reserve dispatch plan. Neither
authorizes Rust to encode Mini's ordinary invoke frame.

Events23–25 and operations66–71 carry the source-bound first-create and
continued-launch contract. Submit/lookup pairs22/23,26/27,38/39 may accept the new ingress only through
strict version dispatch preserving old canonical bytes and original replay.
The reusable signed package descriptor commits creation actions and the
continue command; per-grain volume identity belongs to the launch binding,
not the package root. First-create claim consumes its one-use attempt marker;
successful checked completion establishes exact completed-create evidence.
An unresolved attempt does not authorize another create. Continuation requires
verified creation lineage for the same grain volume plus current lifecycle
authority. Rust maps the admitted volume/action to protected physical custody;
an empty directory or operator flag cannot choose the semantic action.

Operations60–65 carry the fn integration continuation. The selected variant must
bind both the originally admitted event13 release and its event17 coverage;
the empty variant uses event19 and the same verifier-derived frontier. ACK
requires the accepted progress receipt and exact retained local poll evidence,
with a fresh pinned-consumer check. Neither a historical lookup nor a transport
cursor permits installation or physical delivery. Existing adjacent-only CLI
behavior must not be relaxed before the coverage receiving path is connected.

Operations58/59 author an ordinary signed reserve bound to the full event21
context and a preallocated reserve operation ID. They do not submit it or
authorize delivery. Operations48/49 subsequently author the paid dispatch using
the admitted reserve; these two stages must not share a digest-only legacy nonce.

Event22 and operations54–57 are additive. Existing event15 and operations28/29
retain their original meaning. Dispatch may consume a grain-backed ticket only
after Replay has admitted that exact variant against its original prefix and
produced corresponding historical issuance evidence. Reusing an event15 tag or
loosening the factory's grain-backed-only rule is not this migration.

The fresh event21 response must have its own strict committed-permit frame and
source inspector. Agent callers cannot substitute the human event11 operations
34/36/37 or convert an operation47 historical receipt into physical delivery.

Selected fn coverage must bind the configured local consumer scope, prior ACK,
bounded first-match scan, exact projected article and an originally admitted
selected-release transaction. A transport cursor alone is not authority to
advance Mini progress or install content. Coverage says what the pinned local
consumer observed; it does not prove that a remote provider delivered every
article.

Replay must decode the original ingress, admit it against its original verified
prefix, and compare the entire derived intent, including writes, read guards,
charges, event and nullifiers. A recognized tag or an equal journal event alone
does not establish admission. A lifecycle receipt records pending work; physical
launch additionally requires a current claim and generation check.
