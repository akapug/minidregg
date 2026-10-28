# Signed observations and physical read guards

A signed observation and a durable read guard name a resource by two different roots. A
source-side refusal over a mismatch between them stays generic to the participant; source
diagnostics must not become an unsigned participant observation endpoint.

These commitments have different meanings:

- `observed.before.payload.root` identifies the materialized logical resource.
  It belongs in the existing signed observation and selected-content identity.
- `ResourceBirthCodec.physicalRoot (.live observed.before)` identifies the
  physical cell stored at that resource ID. It belongs in the durable intent's
  read guard and must equal `durable.snapshot.model.roots` at that ID.

Do not repair an equality between these two roots by dropping the guard or
changing the signed content identity to the physical root. Derive the physical
root from the exact observed cell, prove its relationship to the loaded bytes
and snapshot coherence, and retain both commitments in their proper roles.
`CanonicalCellRegistry.LoadedPolicySource.readGuard` already documents this
physical-root discipline.

`Kernel/PhysicalResourceReadGuard` is the bridge: it derives the physical root from the same
verifier-loaded directory and durable snapshot. These admission paths take their physical guards
through `ResourceBirthCodec.physicalRoot`, never from a signed observation root:

| Path | Physical guard |
| --- | --- |
| `FnSelectiveReleaseSourceAuthority.prepare` | `physicalCurrent` over the selected content cell |
| `ApplicationShareIssueDelegation.prepare` | `physicalCurrent` over the application cell |
| `ApplicationDispatchAdmission` and `ApplicationDispatchPending` | the app, manifest and enrollment reads |
| `ApplicationLifecycleBeginReceiver` | the package manifest cell |
| `ApplicationLifecycleClaimCurrent` (used by `ApplicationLifecycleClaimCore.packageGuard`) | the package observation |
