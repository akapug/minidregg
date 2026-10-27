# Lifetime-grant issuance repair

The agent journey stopped before submission because its source creates one
resource with three capabilities (owner, controller, participant observer),
while the ordinary birth template admits two capabilities per resource.
The observer is needed by later lifetime dispatch; removing it loses authority
that the consumer needs.

The repair gives event27 a distinct inner ingress frame and an exact one-object,
three-capability template. The ordinary and reserve wire encoders are unchanged.
The generic decoder cannot choose the lifetime-grant method for any input bytes.
The special receiver still requires the complete source-derived descriptor and
independent app delegation signature. Its accepted-value theorem binds the
observer's ID, holder, singleton target, observe-only verb, policy ID, empty
ancestry/channels and absent parent to that source. Reframing preserves the
assembled descriptor and credential envelopes exactly. Both the Host planner
and operator-consent operation74 use the repaired authoring function.

## Evidence and limits

Before validation was centralized, a scoped check on dregg-build used the warm
`/build/minidregg` dependency tree (c77ef2f9b) and private lane outputs in
`/build/lanes/oracle-lifetime-grant-check`. Its `evidence/results.txt` reports
exit0 for ResourceBirthPolicyController, ApplicationAgentLifetimeGrantSource,
ApplicationAgentLifetimeGrantAdmission, ApplicationAgentLifetimeGrantAuthoring
and LifetimeGrantObserverAdversary. These are per-file results against that warm
dependency epoch, not a coherent current-main build.

The source adversary exited1 on three doccomments placed directly before
`#guard`. They are now ordinary comments; this corrected fixture has not been
rerun. No new validation was started after main c44b7d5be centralized it.
The previous checker PID3055176 exited; its logs are preserved.

The source fixture exercises actual source preparation: its three grants must
pass the special template and fail the ordinary template; an extra capability,
wrong target or extra verb must fail. Changed observer identity/holder must
change the source descriptor bytes, even though the generic shape allows them.
The decoder probes reject cross-frame encodings. Synthetic empty credentials
mean these checks do not establish live native admission. Replacing the special
method with ordinary makes the source-positive control fail; weakening the
one-object/three-grant shape defeats the additional-birth/grant refusal controls.

## Integration work

The central integrator must elaborate the final sources and both fixtures,
including direct importer Host.NativeLifecycleConsent, then build matching Host
and consent binaries. The new frame is registered in PersistedCodecTags;
source-consistent codec census generation remains outstanding. Decoder metadata
may move closure fingerprints even though ordinary/reserve encoders did not
change; pins must not be bypassed or edited by hand.

After its normal coherent dependency build, the central validator should run
these explicitly: the new fixture files are not added to an umbrella target.

```sh
lake env lean tests/lean/LifetimeGrantObserverAdversary.lean
lake env lean tests/lean/LifetimeGrantSourceAdversary.lean
lake env lean Host/NativeLifecycleConsent.lean
python3 scripts/codec-shapes-regen.py
```

Use the central build's resource wrapper and normal codec-regeneration workflow;
these commands are instructions for that validator, not additional lane jobs.

Compose this branch with lane/oracle-grant-factory (34aaf5044) for a fresh Store.
Then run the real agent/browser journey through grant issue, dispatch, answer,
restart and exact retry. No event27 submission, repaired hosted answer or current
Store upgrade is claimed by this source repair.
