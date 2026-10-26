# LEAD-STATUS — native-crate review (present state)

**DONE.** `SYNTHESIS.md` is written (~14K words): executive summary; A map; B Rust-decides-semantics (30 ranked rows with Lean counterparts); C RESCUE/REPAIR/DELETE triage per crate with line counts (per ember's correction: rescue and repair first, delete only true twins/dead code/disowned routes); D cross-crate incoherences; E scholarship → concrete recommendations (11 principles, citations verified against the PL corpus where available); F finite prefix in dependency order, three tiers (demo / coherence / nice), repair lanes first, deletions last per merge; G 17 yes/no questions for ember; H sibling-lane decisions (WEB-SPK-PUBLIC §7–8, AFFORDANCES §7) and where this review adds preconditions.

Lead #2 (Fable). Notes: /private/tmp/claude-501/-Users-ember-dev-minidregg/698fc87d-1ed5-4b8d-a00d-67388a9da60b/scratchpad/lead2/notes.md. Briefs: scratchpad/lead2/reader-common.md, synth-common.md.

## Crate-level reports on disk (all read by the lead)
deploy.md, tiny-crates-and-shared-root.md, resource-client.md, grain-runtime.md, spk-host.md, private-backend.md, mini-sdk.md, scheduler-pay-linkstore.md, discord-spkrpc.md, bend-objective.md, prover.md, verifier-keys-testprovider.md

## Shard reports on disk (not read by the lead)
resource-client A–G, grain-runtime A–C, spk-host A–C, private-backend A–B

## In flight
none. All agents launched by lead #1 and lead #2 have completed.

## Not done / for the orchestrator
- commit (lead does not commit): the 13 crate-level reports, 15 shard reports, SYNTHESIS.md, LEAD-STATUS.md under docs/review/2026-10-26-native-crates/
- the private-backend synthesizer noted the home-directory disk at 96% used (297 GiB free); nothing was deleted; ember owns disk pressure
- the review brief said prover/ has shaders/; the reader found no shaders/ or GPU code
