## A. Coherence

**The plan is a finite worklist, but not yet a coherent execution plan.** Its release conditions, dependencies and estimates disagree. I read the requested sections and spot-checked source; I did not run builds, contact hbox/Hetzner, or independently reproduce the reported measurements.

Concrete conflicts:

- **Release rule:** every composed phase must pass, and subsequent candidates must be green; §4 nevertheless says to ship on schedule with red rows. Distinguish an operator-only rehearsal from public opening, and distinguish unrelated research reds from failures on advertised surfaces. [Plan:108–123, 145–146](/Users/ember/dev/minidregg/docs/DEMO-PREFIX-2026-10-26.md:108)
- **Schedule:** phases are declared serial, but Phase 1 occupies days 2–9 and Phase 2 days 7–12. The estimate assumes six to eight parallel lanes; the table names eleven, with no resource assignment explaining that compression. [Plan:32–33, 69–106](/Users/ember/dev/minidregg/docs/DEMO-PREFIX-2026-10-26.md:69)
- **Pre-enrolment policy:** R11 requires Lean-emitted defaults before strangers enrol, but C4 installs them in Phase 3, explicitly “with strangers on the box.” [Plan:125–132, 175](/Users/ember/dev/minidregg/docs/DEMO-PREFIX-2026-10-26.md:125)
- **Tenancy:** L6’s `singleAccount` default conflicts with the intended role separation. This is substantive: that flag bypasses checks forbidding the broker’s UID/group from being client identities. It belongs in test configurations, not the public deployment. [Plan:95, 112](/Users/ember/dev/minidregg/docs/DEMO-PREFIX-2026-10-26.md:95), [server/mod.rs:340–354](/Users/ember/dev/minidregg/native/mini-keys/src/server/mod.rs:340)
- **Hermes route:** R4 accepts BYOK meanwhile, whereas the surface design explicitly excludes user routes because onboarding does not automate `onBehalfOf`. BYOK can be an operator test, not the unattended stranger path. [Plan:168](/Users/ember/dev/minidregg/docs/DEMO-PREFIX-2026-10-26.md:168), [WEB-SPK-PUBLIC:847, 894](/Users/ember/dev/minidregg/docs/review/2026-10-26-deploy/WEB-SPK-PUBLIC.md:847)
- **Latency criterion:** the plan promises p99 ≤5 seconds, but the actual growth judge requires **maximum** ≤5 seconds. These are different contracts. [Plan:29–30](/Users/ember/dev/minidregg/docs/DEMO-PREFIX-2026-10-26.md:29), [journey.sh:858–866](/Users/ember/dev/minidregg/native/resource-client/journey.sh:858)
- **Week-long operation:** a minute clock produces roughly 10,080 records before user traffic. Deferring the 10k soak to C8 contradicts the week-without-babysitting bar and HCLOUD’s explicit pre-demo risk item. [Plan:22, 136, 156](/Users/ember/dev/minidregg/docs/DEMO-PREFIX-2026-10-26.md:136), [HCLOUD-GAP:255](/Users/ember/dev/minidregg/docs/review/2026-10-26-deploy/HCLOUD-GAP.md:255)
- **JPAY6 diagnosis:** L1 treats consent as the current failing row’s cause; today’s row exits on socket-path accounting. The consent allowlist independently lacks the named fields, so investigate both rather than treating either diagnosis as exhaustive. [HBOX-CANDIDATE:85–97](/Users/ember/dev/minidregg/docs/review/2026-10-26-deploy/HBOX-CANDIDATE-a0db11f8.md:85), [ClientConsentCore.lean:180–193](/Users/ember/dev/minidregg/Host/ClientConsentCore.lean:180)
- **Baseline:** the plan repeats 136/2/6/3 as unchanged; the candidate report says its comparison baseline was 137/2/5/3, with `m6grain` changing from PASS to unexercised because of the harness path. [Plan:49–51](/Users/ember/dev/minidregg/docs/DEMO-PREFIX-2026-10-26.md:49), [HBOX-CANDIDATE:57–65](/Users/ember/dev/minidregg/docs/review/2026-10-26-deploy/HBOX-CANDIDATE-a0db11f8.md:57)
- **R2 versus R3:** the unwanted DelveTalk candidate is already committed on local main. “Side branch” followed by pushing existing main does not remove its changes. Preserve the candidate and restore superseded deployment files with a named forward commit. [MERGE:21–27, 94–98](/Users/ember/dev/dregg-infra/MERGE-2026-10-26.md:21)
- **Deletion accounting:** L1’s named amounts total **3,918**, not 3,967; the missing 49 appears in the triage subtotal. L2 names `scheduled_transport.rs` twice because it *is* traffic stack 3. The 24,400 Rust figure belongs to the triage’s different 45-row list, not an audited lane total. [Plan:90–104](/Users/ember/dev/minidregg/docs/DEMO-PREFIX-2026-10-26.md:90), [LEAN-TRIAGE:445](/Users/ember/dev/minidregg/docs/review/2026-10-26-triage/LEAN-TRIAGE.md:445), [RUST-TRIAGE:83, 122](/Users/ember/dev/minidregg/docs/review/2026-10-26-triage/RUST-TRIAGE.md:83)
- **Added surface:** L5 adds the Discord mirror, which the surface plan excludes and says requires a bot token and Message Content intent. Neither dependency appears in Phase 0. [Plan:81, 94](/Users/ember/dev/minidregg/docs/DEMO-PREFIX-2026-10-26.md:81), [WEB-SPK-PUBLIC:895](/Users/ember/dev/minidregg/docs/review/2026-10-26-deploy/WEB-SPK-PUBLIC.md:895)

The history recommendation was explicitly a smaller, early deployment without a composed gate. Ember’s newer every-surface instruction supersedes that scope; it does **not** preserve the smaller project’s schedule. [HISTORY:558–562](/Users/ember/dev/minidregg/docs/review/2026-10-26-history/HISTORY.md:558)

## B. The fifteen rulings R1–R15

The governing ATLAS constraints are executable reach, meaningful refusal, derived policy, and explicit evidence—not preserving the newest version number. [ATLAS:185–240, 283–284](/Users/ember/dev/minidregg/ATLAS.md:185)

| Ruling | Whose decision; default coherence; my ruling |
|---|---|
| **R1** | **Already-settled product scope.** Yes is coherent: repair Mini in place and use nano’s designs where useful. Stop asking ember to restate this request. |
| **R2** | **Engineering.** Side-branch preservation is coherent only with the forward restoration described above; no history rewriting or unrelated deployment changes. |
| **R3** | **Engineering, already authorized.** Yes: fetch, inspect both remote advances, resolve R2, then push named changes. Routine publishing is not an owner ruling. |
| **R4** | **Engineering; spending is owner-owned.** Pool after repair is coherent, but “after non-200 settles” is insufficient: require timeout/malformed-response recovery and live capped inference too. BYOK is not an onboarding substitute. |
| **R5** | **Engineering relocation within the stated scope.** Yes after the demo; preserve research history and runnable entry points. Moving files does not itself remove their semantic twins. |
| **R6** | **Engineering relocation.** Yes, using the measured dependency closure; do not count the research move as Host slimming—the report says it touches no Host module. [LEAN-TRIAGE:446–447](/Users/ember/dev/minidregg/docs/review/2026-10-26-triage/LEAN-TRIAGE.md:446) |
| **R7** | **Engineering.** “Park v3” leaves the shipping API unresolved and conflicts with wire-first. I would repair and qualify v3 for the oracle route, hoist shared transport, then remove superseded implementations; no deletion based solely on version labels. Current v3 dispatch construction and shared v2/v3 authentication exist. [application_api_tools.rs:128–141](/Users/ember/dev/minidregg/native/grain-runtime/src/application_api_tools.rs:128), [agent_api_server.rs:363–401](/Users/ember/dev/minidregg/native/spk-host/src/agent_api_server.rs:363) |
| **R8** | **Engineering recovery contract.** Keep retry, but make failed-START recovery work on v4 before calling it supported. Both the native recovery reader and Lean author currently demand v3 artifacts. [grain_export.rs:455–480](/Users/ember/dev/minidregg/native/spk-host/src/grain_export.rs:455), [ApplicationFailedStartRecoveryTools.lean:94–105](/Users/ember/dev/minidregg/Host/ApplicationFailedStartRecoveryTools.lean:94) |
| **R9** | **Engineering consolidation.** Keep stack 2 as explicitly research-only, delete its obsolete twins. Coherent provided research-only code is excluded from demo qualification claims. |
| **R10** | **Engineering.** Delete the bend pair after checking consumers; retire `runtime.c` together with its differential/mutation consumers, not by leaving broken gates. The differential harness still compiles it. [differential.py:167–174](/Users/ember/dev/minidregg/native/objective-emit/differential.py:167) |
| **R11** | **Engineering.** Yes, and move it into Phase 1. Derive policy from Lean and test cross-member refusal; no owner recovery bypass. |
| **R12** | **Engineering implementation; economic envelope belongs to ember.** “After the demo” is incoherent with ATLAS’s semantic boundary. Implement the minimal Lean-owned tariff and provider-route binding before enabling paid grain operations; defer broader economy consolidation. [SYNTHESIS:76, 333](/Users/ember/dev/minidregg/docs/review/2026-10-26-native-crates/SYNTHESIS.md:76) |
| **R13** | **Engineering.** Yes, immediately. An excluded live dependency needs its own working checks; `exclude` must not mean silently untested. |
| **R14** | **Engineering.** Yes; rewrite current claims now and update them against the shipped candidate. This follows ATLAS’s requirement to state evidence scope. |
| **R15** | **Already-requested product scope; implementation is engineering.** Yes, same admitted grain path. The default omits a format blocker and an acceptance lane; add both rather than quietly dropping the appliance. |

Only two owner questions remain:

1. **What total cash ceiling covers the temporary VM, provider inference and mainnet acceptance payment?**
2. **What shutdown date and backup-retention period should the demo advertise?**

Credentials and account access are provisioning inputs, not fifteen architectural decisions.

## C. Ordering and long poles

The lane subjects are mostly right; their dependency structure is wrong. The Rust synthesis explicitly orders build → units → Lean before dependent lanes. The plan flattens these into apparent independence. [SYNTHESIS:308–322](/Users/ember/dev/minidregg/docs/review/2026-10-26-native-crates/SYNTHESIS.md:308)

I would order the prefix as follows:

1. **Immediately repair the harness:** preserve/relocate the complete v2 manifest, fix JPAY6 socket accounting, run `m6grain` from an authorized tree, and obtain M7’s independent reference. Then rerun the existing candidate’s composed scenario to discover actual failures.
2. **In parallel, establish the deployment substrate:** scratch Debian VM, private operator ingress, split users, separate grain world, clock-v2/certifier integration, role-compatible Discord units. The certifier has six integration conflicts, including identity and clock semantics; this is code work, not a final installation checkbox. [MERGE:46–65](/Users/ember/dev/dregg-infra/MERGE-2026-10-26.md:46)
3. **Fix Lean interfaces early:** no-effect classification, provider recovery, consent, defaults, minimal tariff and v4 recovery. Build their changed closure early enough to inform Rust integration. “One rebuild at the end” delays discovery of the most expensive mistakes.
4. **Qualify actual surfaces and composition:** oracle and EtherCalc through their real routes; Hermes room resident; PAY-to-hosted-account; Discord; fn delivery and fleet. Then restart, certifier failure, recovery and week-scale growth.

Keep L11, but first reserve a quiet measurement window. Today’s p99 12.3 seconds and maximum 57.3 seconds were measured under competing load; neither passing nor intrinsic slowness follows for a quiet cx43. [HBOX-CANDIDATE:275–294](/Users/ember/dev/minidregg/docs/review/2026-10-26-deploy/HBOX-CANDIDATE-a0db11f8.md:275)

Cut research relocation, C-runtime retirement, exhaustive unrelated documentation work, and blanket collision-theorem rewriting from week-one’s release dependency chain. Keep targeted non-vacuity obligations for changed admission paths and adjacent deletions. Add the missing recovery/security items below, a 10k-plus workload, explicit surface acceptance, and the oracle packaging lane.

**Two weeks is a target, not an evidence-backed commitment.** The 35-minute candidate built zero Lean modules; changed-closure elaboration remains unmeasured. The composed gate never ran, M6 was unexercised, and HCLOUD estimated several weeks for web plus SPK before adding the oracle. [HBOX-CANDIDATE:24–33, 303–307](/Users/ember/dev/minidregg/docs/review/2026-10-26-deploy/HBOX-CANDIDATE-a0db11f8.md:24), [HCLOUD-GAP:291–297](/Users/ember/dev/minidregg/docs/review/2026-10-26-deploy/HCLOUD-GAP.md:291)

## D. What the plan gets wrong or misses

1. **The oracle is not packageable yet.** Six SQLite members exceed SPK’s <512 MiB member limit; the candidate explicitly records `spk_packable: false`. A Linux rootfs, bridge, signing tool/key and immutable-data integration remain outstanding. The stager actually rejects oversized files. This requires a format/materializer decision or a separately admitted immutable-data contract, with disk/RSS measurement and end-to-end acceptance. [deploy/oracle/README.md:3–14, 115–121](/Users/ember/dev/minidregg/deploy/oracle/README.md:3), [stage.py:183–189](/Users/ember/dev/minidregg/deploy/oracle/stage.py:183)

2. **The manifest fix is understated.** Adding `.type` alone cannot work: Mini also requires a nonempty `outputs` map equal to provenance outputs, with source/build bindings. Infra currently emits neither. Preserve the producer’s full contract and test both scratch publication and actual ship preparation. [infra/lib.sh:233–243](/Users/ember/dev/dregg-infra/edge/mini/lib.sh:233), [candidate/lib.sh:37–56](/Users/ember/dev/minidregg/deploy/candidate/lib.sh:37)

3. **Provider recovery is larger than HTTP 429.** The triage also identifies upstream timeout, malformed headers and post-send crashes; its proposed uncertain-settlement transition is postponed to C7. That leaves ordinary external failures requiring babysitting. Implement explicit bounded recovery without converting “lookup absent” into “never happened.” [RUST-TRIAGE:240](/Users/ember/dev/minidregg/docs/review/2026-10-26-triage/RUST-TRIAGE.md:240), [SYNTHESIS:77, 108](/Users/ember/dev/minidregg/docs/review/2026-10-26-native-crates/SYNTHESIS.md:77)

4. **Several public-path defects disappeared during synthesis:** PAY pagination/dust loss, nullifier attribution and stuck-tick quarantine; Discord’s split-mode `NoNewPrivileges` conflict; retained rotation secrets; SPK auxiliary-fd failures; and SQ bound-error/read-fsync behavior. These are named failures, not speculative hardening. Assign them explicitly. [RUST-TRIAGE:235–248](/Users/ember/dev/minidregg/docs/review/2026-10-26-triage/RUST-TRIAGE.md:235)

5. **fn’s public ACK authority remains unresolved.** Public routing currently accepts operations 13/15 with only decimal-shape checks. The triage recommends operator-only routing pending the authority answer; L8 omits it. [transport.rs:334–339](/Users/ember/dev/minidregg/native/resource-client/src/transport.rs:334), [RUST-TRIAGE:250](/Users/ember/dev/minidregg/docs/review/2026-10-26-triage/RUST-TRIAGE.md:250)

6. **The formal claim needs qualification now.** The refinement theorem assumes a successfully derived turn in `HostStep.derived`; its existence does not prove every receiver acceptance satisfies World admission. Measure and resolve the refusing-path gap, or explicitly limit the demo’s claim. I have not verified that the proposed 300–800-line gate closes every gap. [HostRefinesWorldCore.lean:418–434](/Users/ember/dev/minidregg/Kernel/HostRefinesWorldCore.lean:418), [LEAN-TRIAGE:290–319](/Users/ember/dev/minidregg/docs/review/2026-10-26-triage/LEAN-TRIAGE.md:290)

## E. The three changes you would make to the plan first

1. **Replace the fifteen-owner-ruling checkpoint with the engineering decisions above**, leaving only budget and lifetime questions.
2. **Replace serial phases with explicit dependencies and one public-opening contract:** advertised surfaces work, tenancy holds, uncertain effects recover safely, and the stated performance/week-scale criteria pass.
3. **Start three uncertainty-reduction tasks immediately:** repair and rerun the existing candidate gate; exercise split tenancy plus certifier integration; resolve oracle packaging. Re-estimate the delivery date from those results.