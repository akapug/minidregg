# Preparing an agent route before its receipts exist

An agent session and its lifetime grant must be admitted before their history
positions are known. The SPK profile already pins the complete Host configuration
by then. Rewriting that configuration to insert positions would break the pin;
the existing compatible-upgrade route deliberately allows only its narrow
helper-image changes.

`agentLifetimeDispatchTargets` lets an operator pin the resource identities and
spending limits before provisioning. It omits only the original event22 index
and the lifetime event27 index. Actual requests still carry both indices from
their admitted receipts. The source verifier selects and checks those receipts.
No history position is guessed and no compatible-upgrade permission is widened.

## Startup configuration

Set exactly one lifetime authoring mode:

- `agentLifetimeDispatchFixed`: one existing exact-index pin.
- `agentLifetimeDispatchServices`: one to eight existing exact-index pins.
- `agentLifetimeDispatchTargets`: one to eight stable resource pins.

The new mode refuses either older lifetime mode in the same configuration. Each
target has the same fields as an indexed service, except that `legacy.issueIndex`
and `grantIssueIndex` must be absent. Duplicate target pins refuse.

This example is the planned Oracle qualification allocation, not evidence that
these resources have been admitted:

```json
{
  "agentLifetimeDispatchTargets": [{
    "legacy": {
      "ticketResource": 29520,
      "packageManifest": 9102,
      "snapshotManifest": 9103,
      "sessionObserve": 20241,
      "manifestObserve": 20279,
      "enrollmentObserve": 20243,
      "parentTask": 27920,
      "parentCapability": 20201,
      "parentObserve": 20201,
      "purseTask": 27940,
      "purseCapability": 20221,
      "purseObserve": 20221,
      "payerSubject": 20012,
      "reserveAmount": 1,
      "maximumCharge": 1
    },
    "grantResource": 29530,
    "grantObserveCapability": 20283
  }]
}
```

Put the table in the initial Host configuration before creating its pinned SPK
profile. Provision the session, original ticket and lifetime grant through their
normal source-owned paths. Build the controller and resident route custody from
the actual inspected receipts. Requests then use those real history positions
against the unchanged Host configuration.

This is a bounded startup workflow. It does not authorize editing an existing
profile or adding arbitrary resources after its configuration has been pinned.

## What still decides authority

The Host authoring matcher compares every fixed selector except the two history
positions. It does not change request codecs, source verification, signing or
final admission. The internal matcher erases the two coordinates for comparison;
its zero values are never submitted as proposed history positions.

`ApplicationAgentLifetimeDispatchPaidAuthoring.certifiedGrant` finds the actual
event27 in the verified chronology. It checks its grant resource and observe
capability, its original event22 index and ticket resource, and the original
source/receipt binding. `currentGrantCell` requires the live grant cell to match
the certified installation. `ApplicationDispatchAuthoring.prepareWithLifetimeGrant`
checks the ticket and parent, then the current application, session, enrollment,
policy and issuer lineage. The paid path also joins the admitted reserve to its
current purse and exact context. The final receiver performs fresh admission;
an unsigned plan or startup target is not permission to deliver an application
request.

The settings table is outside `NativeHost.Config`. The theorem
`Settings.config_lifetimeDispatchTargets` states that changing this table leaves
that verifier configuration exactly equal. It does not authorize changing the
complete physical configuration pin. `LifetimeDispatchPin.targets_exact_except_indices`
states that a match equals the operator's entire selector record with only its
two history positions replaced by the request's positions.

## The session participant

`allowedSessionFamilies[].participantSubject` optionally selects the configured
controller or tool subject. Omission preserves the existing tool participant.
Public tool arguments cannot supply a participant. Lean's session birth assigns
both the session and descriptor, including their four grants, to that participant;
the delegated tool remains the signed and metered creator.

For a lifetime route whose participant is the controller, set the session family
to that controller subject. Named reads of either born member verify the retained
birth source and receipt, then use the selected owner's configured key for an
ordinary current signed query. A configuration change cannot reinterpret an
old birth as belonging to a different owner: source reconstruction must still
match its retained native evidence. Duplicate static and born read names refuse
before selecting a signer. No new grant or fabricated journal entry is created.

## Qualification

Host compilation checks strict parsing, index omission, indexed-mode behavior,
duplicate/bounded lists, wrong fixed coordinates and both theorem statements.
Focused Rust tests cover the participant default and restriction, preservation
of the signed creator, selected read key/subject, unchanged query grants,
ambiguous read names, and refusal before spawning with a task mutation grant.

Those are source and construction checks. Linux compilation and actual Oracle
qualification are tracked separately. Receiving controls should show a valid
request succeeds with its admitted indices, wrong event22/event27 indices refuse,
and changed or revoked current authority and stale plans cannot deliver. Do not
report matcher checks as those receiving results.

`scripts/oracle-agent-authority-probe.py` consumes the fixed installer's hashed
controller export and one successful native application attempt. It reinspects
the retained reserve plan with the pinned Host and authenticates that reserve's
original receipt through exact read-only lookup. It then authors two canonical
variants of the same request, changing only one history index each, and requires
the resident Host's specific source-index refusals. A malformed request, transport
failure, fixed-target rejection or settled parent cannot count as a passing
negative control. The original accepted reserve is the positive control; the
probe does not reserve the already-settled parent again.

This helper submits no transaction and does not revoke authority. Its report
explicitly leaves `revocationTested` and `unsubmittedStalePlanTested` false.
Those additional receiving experiments remain outstanding until an actual
current-authority transition and a fresh unsubmitted plan are exercised.
