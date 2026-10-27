# Oracle provisioning uses configuration values

Main's new genesis platform record added a `grainBirthTariff` occurrence. The
Oracle member wrapper expected exactly six occurrences in a rewritten shell
script, so the extra field would stop it before bootstrap. Counting source text
does not establish that the intended configuration was produced.

The workroom provisioner now accepts the payload-byte tariff and factory
predicate as explicit inputs. The member and grain-host wrappers pass operator
policy as JSON, while the positive-byte fixture passes balances and tariff as
configuration variables. Their configuration steps no longer rewrite shell
source, count keywords or require an embedded source-file hash. Each run still
records hashes of its actual sources and configuration; package signatures and
runtime identity checks are unchanged.

The genesis platform record derives its budget, lifetime, grain tariff and
custodian key from the final operator configuration. Caller-supplied conflicting
custody, management, allocated targets or grain tariff are refused; unrelated
allowed policy fields are preserved. The final native pinned configuration is
checked against the requested policy. Native parsing and admission remain the
authority for the resulting genesis and births.

This does not remove the separate source injection used to insert member and
agent enrollment/birth steps. Its phase-location checks remain, and replacing
those hooks is separate work. Other legacy fixture wrappers also retain their
own source pins; this change covers the Oracle grain provisioning chain.

## Central validation still required

No new tests or builds ran: validation is centralized under main c44b7d5be.
The earlier 682 predicate guards and two composition tests in
[factory evidence](oracle-grant-factory-2026-10-27.json) describe the preceding
implementation, not this refactor. The factory predicate itself is unchanged.

Run these focused checks centrally, then the fresh coherent agent journey:

```sh
python3 -B scripts/test-oracle-agent-lifetime-journey.py \
  HarnessTests.test_complete_grain_store_overlay_before_bootstrap \
  HarnessTests.test_actual_factory_allocation_guard
```

The first check stops at mocked bootstrap and examines the actual generated
operator/genesis JSON. It includes changed whitespace and unrelated keywords,
policy preservation, custody/target conflicts, extra JSON documents and forbidden
operator fields. It also checks the platform policy and initial balances. The
second retains the malformed and colliding allocation cases. Restoring the old
keyword count fails the changed-source cases; dropping policy propagation fails
the generated JSON assertions. Neither check proves native admission.
