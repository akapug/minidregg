# Oracle provisioning uses configuration values

The member and agent enrollment path now configures the workroom provisioner.
It no longer generates shell snippets or searches source lines to insert
key generation, enrollment, birth or delegation steps. The old
`agent-genesis-overlay.sh` generator is replaced by a data-only allocation
checker and the fixed `scripts/workroom/agent-enrollment.sh` library.

The workroom accepts `WORKROOM_INCLUDE_MEMBER=0|1`, `MEMBER_INITIAL_BALANCE`
(default 100), and an optional absolute `WORKROOM_AGENT_ALLOCATION` JSON path.
Its explicit phases prepare enrollment records, extend the first birth, and
verify the admitted resources and parent delegations. Each library phase has
subshell scope so its local shell variables cannot overwrite provisioner state.
The existing tariff, balance, operator-policy and factory-predicate inputs stay
configuration values. Runtime hashes identify the actual inputs, rather than
requiring a hardcoded digest or a count of source keywords.

The workroom also uses `native/resource-client/scenario-genesis.sh`, which calls
the shared `genesis.sh` template. It no longer serializes a second genesis
format. The shared template accepts whitelisted `operatorPolicy` settings
before computing the native profile and derives the platform record from that
same final operator configuration. Duplicate settings must agree. The
workroom's dedicated clock has subject/account 70 and capabilities 4071–4074;
allocation checks reserve those coordinates. Member and agent roles retain
their existing coordinates. A fresh Store is required; old stopped Stores stay
preserved.

The SPK `prepare.sh` / `run-base.sh` consumer now passes the same kind of
structured policy, with current `lifecycleManagement` settings. Its optional
`WORKROOM_EXPECTED_OPERATOR_CONFIG` requires the complete generated configuration
to match the pre-Store qualification config after pure profiling and before
bootstrap. Actual code hashes are retained; stale code-hash constants and
profile-line insertion are gone. Signed-package and descriptor pins remain.

Native parsing and admission remain authoritative. This refactor does not
change the factory permission or lifetime-grant template. Separate
application-session source generation in `agent-session-overlay.sh` remains;
this change removes enrollment and provisioner-policy injection, not every
legacy fixture rewrite in the repository.

## Scoped checks and remaining qualification

After Mini lifted the lane-validation ban, the five focused checks listed in
[ROWS-OWED](../ROWS-OWED.md#oracle-appliance) passed on dregg-ref: 5 tests,
5.422 seconds, exit 0. Source was `ce27ff402` (cleanup `45f5d04ab` merged with
main `cacefcba8`); retained output is
`/build/lanes/oracle-enrollment-ce27ff402/focused.log`. No Lean build or live
Store was involved. Earlier predicate receipts remain scoped to their earlier
implementations.

A separate real-journey preflight regression passed there in 0.171 seconds
(exit 0, one test with matching-Host, old-Host and failed-receipt cases; retained
`preflight.log`). The journey now rejects an old STOP benchmark before creating
a Store or copying shared data. A matching receipt proceeds to the next
independent preflight check. Its full cold/served controls still belong to the
final report; the new early check does not qualify the benchmark itself.

The composition checks inspect the actual operator/genesis JSON at mocked
bootstrap, with both member and agent configurations, changed source formatting,
policy conflicts and preservation, the shared clock and initial balances. Data
checker cases cover malformed/colliding allocations and multiple documents.
A birth-phase case checks actual allocation-to-resource composition. These
fixtures cannot establish native admission or the hosted lifecycle; the
receiving journey must do that on matching current binaries.
