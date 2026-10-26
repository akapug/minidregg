# Oracle integration review — 26 October

This is a source-scoped review of in-progress changes. No builds, whole Engine runs, signed Oracle package, Mini admission or specialist panels were executed. The underlying work was changing while reviewed; these findings describe the cited code at inspection time.

## Existing qualification regresses for packages over 1 MiB

`deploy/spk-host/spk-qualify` runs with `LimitFSIZE=1048576`. The new streaming verifier (`native/spk-package-stream/src/lib.rs`, `verify` and `verify_in_private_temp`) writes complete raw and decoded snapshots as files. A valid standard SPK whose raw or decoded snapshot exceeds 1 MiB therefore cannot complete in that unit. The previous parser did not create these files. This affects existing apps as well as the larger profile. Set a bounded qualification storage profile that permits both files, and exercise the actual helper on a representative signed package.

## Larger import policy stops before the full lifecycle

The broker forwards an operator-selected profile to materialization and the image retains a protected import policy. But `native/spk-host/src/grain.rs` still caps staged source at 256 MiB; `install_v3.rs` reads a 256 MiB-bounded whole-file vector and calls standard-only qualification; and `launch_descriptor_native.rs` calls the standard-only qualifier. `spk-qualify` also enforces 256 MiB and the INSTALL helper has a 256 MiB per-file ceiling. A larger package can pass the new ingest path yet be rejected by the normal pre-install/qualification path. Propagate a physical operator-owned profile, streaming exact-byte pin checks, and matching bounded helper resources through every actual stage; do not accept a larger profile from the package or caller request.

## Signed root API path rejected by qualification helper

`deploy/oracle/stage.py` signs `apiPath = "/"`. `native/spk-rpc/src/bridge_config.rs` preserves that as `Some("/")`, and `native/spk-host/src/main.rs` prints `/`. The `deploy/spk-host/spk-qualify` jq check accepts only empty or `/repo.git/`, so it rejects the intended Oracle package after successful parsing. Validate the actual supported signed path rather than an unrelated fixed application allowlist, preserving exact identity binding.

## Per-member format limit prevents packaging the current stores

`deploy/oracle/stage.py` correctly rejects any Cap'n Proto Data member at or above 512 MiB. The current patched appliance receipt lists six SQLite files over that limit, including `relations_v1.sqlite3` (3,593,560,064 bytes) and `relations_v2.sqlite3` (5,569,425,408 bytes). Aggregate 8/20 GiB import limits alone cannot produce this package. An admitted immutable data-volume contract or a chunked representation with verified reconstruction and resource accounting is needed. Receipt inspection only; no package construction was attempted.

## Disk and interruption accounting for large imports

The larger profile caps individual compressed/decoded sizes and extracted member total, not aggregate temporary disk. In the worst case, source staging plus inbox, anonymous raw snapshot, decoded scratch, extracted tree and retained raw image coexist; the latter five can total roughly 64 GiB at profile limits. `LimitFSIZE` constrains each file, not that sum. Abnormal unit termination after stage creation bypasses ordinary Rust cleanup and can leave `.spk-stage-*`. Use an operator-owned quota or reservation covering the entire operation and identity-scoped interrupted-stage recovery; do not delete unrelated state. This is a source-derived capacity bound, not a disk-pressure experiment.

## Broker's deadline is shorter than the import unit

`native/spk-host/src/broker_endpoint.rs` waits 600 seconds for a broker response, whereas operator-appliance ingest permits 1800 seconds. Broker requests are handled synchronously. An import that takes 600–1800 seconds can time out at the caller but continue blocking the broker until its own completion. Provide operation-appropriate bounded deadlines and exact package-identity status/recovery, or decouple long ingestion from unrelated broker operations. This scenario is inferred from timeout values, not measured over a long run.

The bridge's byte-preserving JSON, permission requirement and explicit uncertain-delivery handling were inspected against `spk-rpc` response parsing. No independent integration claim follows from that inspection.

## Staging checks do not freeze package source bytes

`deploy/oracle/stage.py` verifies the rootfs and appliance inventories, then writes a source map pointing back to those external directories. `verify_stage` can detect changes when explicitly called, but neither operation makes the later `spk pack` read the previously checked snapshot. An edit between verification and packing can be signed into the package. Bind the final packed members back to the pinned inventory, or freeze/snapshot source files under custody for the full packing operation. This is a source-level time-of-check/time-of-use concern, not an observed alteration.

## Rereview dispositions

This rereview covers the current source as of 26 October, not a new live installation or whole-lifecycle test.

- **Standard qualification file limit:** corrected in source. The qualification helper now selects a bounded standard profile whose per-file allowance accommodates streaming snapshots. The agent reports a real Linux materializer test; the remaining production helper and receiving-path checks are being run separately.
- **Physical profile propagation:** corrected in source through grain staging, launch qualification, install preflight, helper limits, broker ingestion and protected retained-image policy. This is not yet an end-to-end large-package admission: `Kernel/ApplicationSpkPackageIdentity.lean:247` still imposes a 256 MiB raw package cap. The semantic cap is an explicit remaining blocker.
- **Root API path:** the unrelated helper allowlist has been removed; native bridge decoding and signed-path validation still apply. No live admitted Oracle API session is claimed.
- **Per-member format limit:** remains open. The real SQLite members exceed the 512 MiB Cap'n Proto member bound; a separately admitted immutable-data contract or verified reconstruction is still needed.
- **Disk and interrupted staging:** improved but not closed. Protected disk-backed scratch and conservative available-space checks are present; those checks are not a reservation or an aggregate quota. Recovery of named stages after abnormal termination remains required.
- **Broker timeout:** improved in source: the Ingest transport deadline is 1860 seconds against a 1800-second import unit limit. The broker remains serialized and exact status/recovery for long operations remains relevant.
- **Mutable source-map staging:** improved in source with a separately pinned stage receipt and a byte-pinned inspector that verifies the actual signed SPK snapshot, signer identity, version and complete member inventory. The resulting raw hash must be the one Mini actually imports. Source-map inputs remain mutable; the protection is the mandatory post-pack comparison, not immutability of those directories.

No additional independently confirmed standard-path or post-pack-verifier defect was found in this bounded rereview. Tests mentioned above are agent reports, not independently rerun here. A complete large-appliance Mini admission and lifecycle have not been run.
