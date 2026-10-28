# Oracle runtime cost

The accepted-grant route renderer used a detached Host process even when the
owner-private operator Host was already serving the same Store. Its
`inspectAcceptedCurrent` opens the image and calls `NativeHostReplay.verifyLoaded`:
that means re-admitting every retained signed event from genesis. It is a cold
audit, not an ordinary read of the already verified grant.

Read-only op 156 now calls the identical `inspectAcceptedVerified` projection
with `sessionWalked`'s refreshed verifier-minted chronology. New suffixes still
have to pass admission. Both application-attachment render calls select this
served path; a refused served request fails without detached fallback. The
old standalone inspection remains available for explicit operator use. This
removes two redundant full audits from an attachment's normal preparation.
No new wall-time measurement is claimed until the successor Host is built and
qualified. The reported old q3 cohort direct inspection took about 138 seconds
under contention; it is not a measurement of this change.

Independent consent is a separate cost. `ClientConsentCore.verifyInitial`
resumes a retained anchor when possible, otherwise verifies the whole history.
Ordinary consent can remain anchored. The first lifecycle plan requiring a
full chronology calls `upgrade`, so an ordinary signed readiness read did not
establish readiness for that lifecycle plan. Explicit frame 236 now performs
that same independent full verification in the signing provider, before the
active request deadline. The selected executable must advertise the feature,
and only its exact empty 236 acknowledgement produces readiness. This moves
the cold work to a suitable startup budget; it does not make that work faster.
The delegated proxy carries it to the same provider used for signing.

Both the old `aae3e2e37` and newer `349e59ef1` candidates already materialize
`DurableEngine.Engine.install`'s ten budget allowances. The seven-minute q3
cold replay cannot be explained by an absent budget-materialization fix.
Materialization removes repeated evaluation of prior subtraction closures;
it still evaluates the current intent's exact charge at each admitted prefix.
`ApplicationDispatchPending.charge` constructs the ordinary data intent and
reads its exact charges; `Engine.view` defines roots by running `rootBytes`
on the selected cell's complete bytes.

The existing 349e59ef1 SandMD profile, a different workload from Oracle startup,
found five of eight compute stacks in whole-cell Store root/codec work and
two in `receiverSemanticsFrom` over the compiled manifest. Its route calls
spent about 5.3 seconds of single-thread CPU per submit. That supports the
next bounded investigation: hold roots and receiver semantics once per exact
snapshot, then measure full replay on an independently copied stopped Store
with identical receipt bytes. The route-latency lane owns that shared change.
A byte-array codec rewrite is a larger follow-on, not the first experiment.

Old q3 measurements reported by its acceptance owner remain useful capacity
warnings: around 125 events, consent cold readiness took about seven minutes
and peaked at 1,858,396,160 bytes in its cgroup, while the controller itself was
about 57 MiB. Keeping dozens of controllers light does not make simultaneous
full consent cold starts affordable. Resident reuse and explicit startup
readiness avoid repeated work and misplaced deadlines; a measured replay
optimization is still needed to reduce the first verification's CPU and RSS.

Source: `Host/ApplicationAgentLifetimeGrantInspection.lean`,
`Host/Main.lean` op 156, `Kernel/NativeHostSession.lean`,
`Host/ClientConsentCore.lean`, `Kernel/DurableEngine.lean`,
`Kernel/ApplicationDispatchPending.lean`; existing route profile
`lane/un-route-latency:docs/review/2026-10-27-untouched-areas/ROUTE-LATENCY-STATE.md`.
