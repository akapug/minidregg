# apps-agents lane state

Branch `lane/apps-agents`, worktree `/Users/ember/dev/minidregg-lanes/apps-agents` (2026-10-29).

Current work and evidence are in **CONTINUATION** below. The earlier sections record prior
scope and findings; their "not done" statements are historical.

## Done
- eca26cc6c: typed Hermes app tools in grain-runtime. `toolTask.typedApplications`
  (typed_applications.rs), MCP projection and worker-side executor (mcp.rs), broker op
  `__mini_typed_http_raw` over the GitWeb raw-reply pipeline, room grant bit `hermes/tools` 16
  ("apps"), named refusals typed-apps-not-granted / typed-apps-not-configured / typed-app-not-attached.
  Filtered tests: `cargo test -p minidregg-grain-runtime --bin grain-runtime typed_applications`.

## Not done
- The journey row. It needs a world with a Hermes controller and two app lifetime routes
  (Gogs, Davros). Only J14_ORACLE composes that, for one app, and it has never completed
  (docs/ROWS-OWED.md). Needs a two-app generalization of journey.d/j14-oracle.py and
  scripts/application-attachment.py (exactly-one-agent, oracle-app names), plus web sessions
  for the human browser check.
- Foreground `mini app-interface call` for typed names; DDP/conversation transports; MKCOL
  (controller parse_input method list).
- Davros file.put takes contentBase64; a text variant would suit models better.

## hbox findings (2026-10-29, candidate 2b8f75dc)
- journey.d/j14-apps.py runs the J14_ORACLE phases world, prepare_platform, prepare_application.
  Run area `/othersys/aa-run` (hbox rejects group/world-writable ancestors for the helper/bin/spk
  paths; bin must be copies, not symlinks). Wrapper: /othersys/lanes/apps-agents/run1.sh.
- world, broker-world/profile, Gogs install pass. The bootstrap ticket step fails: Gogs' descriptor
  has only a `web` interface, so an agent route must be the v4 web kind
  (mini-spk-agent-lifetime-binding-v4). spk-host has the v4 types; application-attachment.py,
  same-store-app.py and grain-runtime's LifetimeRoutePin/verify_lifetime_binding_reply are v3/api only.

## 2026-10-29 later
- Landed or pending with the integrator (lane/apps-agents tip merged with integration/staging):
  eca26cc6c typed Hermes tools (on main 2b8f75dcb); 289e0088b dispatch linkage clauses (op36 red,
  a managed app's manager as ticket issuer); d707dd84d Davros text helpers; e6c5d4da4 web-kind agent
  route v4 (spk-host registration without a package apiPath, prepare-lifetime-route.sh route pins,
  grain-runtime v4 binding); application-attachment.py `route` and `typed` options.
- Davros is repackaged with an api interface (package 5485d227..., staging 3d81c44d8), so the first
  row can use the api kind. Forgejo is not in yet.
- Not done: the end-to-end j14-apps phases after prepare_application (worker, room, attach, probe):
  j14-oracle.py's attach uses oracle names and its probe asks Oracle questions; a Davros probe, the
  real-provider route (OpenRouter pool row), the human browser check on the same grain and the
  unauthorized-call refusal row. The test provider has only scripted modes (no typed-app mode).
- hbox: run area /othersys/aa-run (no group/world-writable ancestors; bin must be copies);
  wrapper /othersys/lanes/apps-agents/run1.sh; `world-down.sh` over a copied recovery.json tears a
  world down.

## CONTINUATION (codex, 2026-10-30; run 25 green)

Goal: j14-apps green on hbox: a Hermes room resident gets an actual typed-tool refusal
without hermes/tools bit 16, then puts and gets a Davros text file in one task through
Mini admission/settlement, followed by a separate human WebSession read of that grain.
Run 25 passed all five rows, including the separate human read, and tore down cleanly.
Evidence: `/home/hbox/aa-run/step25/oracle/result.json` and `teardown/result.log`.

### Causes traced and fixes

- **Consent transport loss (run 9, worker create).** The service journal reported permission
  denied reading `/home/hbox/aa-run/bin/minidregg-credential-signature-verifier`. Installed
  consent and candidate consent were byte-identical (SHA256
  `f72cb9d23009fa789852388ff2ce4be0913554c3d2e8533033b68ebec916d195`). The typed pin edit
  was not the cause. `ProtectHome=yes` hid configured executables and replaceable Store
  anchor/checkpoint files; ReadWritePaths does not unhide those ancestors. Installation
  now validates/snapshots signature and Store executables into root-owned
  `controller/consent-dependencies`, verifies their digests, and uses `ProtectHome=tmpfs`
  with exact dependency, Store-parent and transport-directory binds. Native full readiness
  passed against run 14's retained Store (`step14/oracle/world/consent-mount-probe`).
  Worker create and subsequent room setup have repeatedly passed in the live journey.
- **Typed attachment admission.** Controller publication accepts bounded private declaration
  files; Rust still validates declaration/package identity. Native application enrollment
  accepts one typed attachment with its matching new reference/route, preserving existing
  bindings on refresh. Broker configuration receives the exact resident home file/socket
  inventory needed by its sandbox.
- **Birth evidence removed by compaction (run 18).** Native stderr identified missing
  `source-0000000000000031.json`. The journal still referenced that admitted birth, but
  compaction had removed its exact source/attempt/author files. Compaction now retains
  journal-referenced operation groups and workspace evidence while pruning unrelated later
  operations. The real birth verifier passes after compaction and rejects a changed preimage.
  Source 31 also survived the first completed live turn in run 21.
- **Unsigned paid-plan selection (run 22).** Run 21 reached an admitted dispatch reserve,
  then spk-host obscured op78's outcome as `lifetime paid native reply opcode/frame drift`.
  Added durable op78/79 frame retention and Lean-owned outcome inspection; this is diagnostic
  only and does not discharge an admitted hold. Run 22 revealed the precise native refusal:
  `lifetime paid app selector missing`. `preparePaidVerified` was selecting from the unsigned
  ingress's deliberately empty signed-command placeholder. It now uses the current source
  session root and observation capability, and checks that the reconstructed command exactly
  equals the existing source signing plan. Final signed admission is unchanged.
  Raw evidence: `step22/oracle/native-paid-evidence/agent-lifetime-dispatch-op-183`.

- **Davros write role (run 23).** Both agent calls reached definite event26 admission and
  settlement, then the app returned PUT 403 / GET 404. The attachment helper hard-coded
  permission role 0. Native inspection of the signed package (`davros-permission-inspection.json`)
  confirms role 0 is `[view=true, edit=false]`, role 1 is `[view=true, edit=true]`.
  Added optional pinned `roleId` to the attachment contract (default 0); j14-apps selects 1.
  Mini still validates the role/schema/issuer and issues the ticket and lifetime grant.
  Four focused role/attachment tests passed locally and on hbox. Run 23 evidence is
  `step23/oracle/application-attempts.json`, `granted-tool-results.json`, and the bounded
  controller exports. Store `c08a717fca3b452b` teardown=0. Run 24 uses this role correction.

- **Agent-first human counter initialization (run 24).** The missing-grant refusal,
  PUT 201, GET 200, exact marker readback, and admission/reply/settlement joins passed.
  The separate human GET returned 503. Resident stderr says
  `dispatch operation counter missing after use`: agent delivery wrote shared physical
  dispatch markers before the human allocator had ever created its counter.
  The physical journal now establishes/validates that counter under its existing lock
  before the first delivery marker, including externally numbered agent calls. It never
  resets a missing counter beside historical evidence. Regression checks cover agent-first
  then human delivery, missing counters, interrupted initialization, and retained one-shot
  fences. `build-counter3.log`: 37 journal tests passed, three disposable-unit harness
  probes ignored, release built under the pinned toolchain/modest caps. Two older human
  fence fixtures now allocate their ID before creating the attempt, matching the actual
  `dispatch_delivery` call order. Missing-counter rejection was not weakened.
  Run 24 Store `b23632ee8dbd0f57` tore down with removal_assertions=0; evidence is in
  `step24/oracle/application-attempts.json`, `granted-replies.json`, and its resident teardown log.

### Journey and cleanup

- The founder publishes a focused app-assistant program through native `doc edit`, submit
  and signed readback. This avoids spending the unchanged six-request provider allowance
  on the inherited librarian's unrelated maintenance. The real OpenRouter model remains
  `anthropic/claude-sonnet-4.5`; no fixture provider stands in for it.
- Refusal evidence links the actual provider tool call and returned `typed-apps-not-granted`,
  and requires no application dispatch. Run 25 passed this check before enabling the grant.
- Granted evidence checks retained request/reply digests, PUT and GET of `dav/notes.txt`,
  definite admission, and exact joining of operation/binding/fingerprint/receipt/settlement.
  A separately provisioned human WebSession reads `/dav/notes.txt` and checks the exact
  agent-written marker. Run 25 passed both the agent receiving path and the separate human read.
- `controller-export ... application` retains only journal, resident state, provider requests
  and application request/reply files, within the existing 4096-file/8-MB-file/32-MB-total
  and custody bounds. Failure captures logs and export before teardown.
- World-up alone holds `flock -o /tank/lanes/world-up.lock`. Finally cleanup stops our public
  listener, removes the controller before its world, handles partial broker registration,
  and stops loaded/restarting brokers. Absent legacy sockets are tolerated; replaced inodes
  are refused. Shared helpers may remain; our grains root and registry must disappear.
- Initial leftover `ccf03eb175bf8943` was removed. Every subsequently started world through
  run 25 has been torn down; latest: `563a91a19caf4850`, `removal_assertions=0`.
  A final privileged check found neither its volume registry entry nor the initial ccf03eb entry.
  No uncertain call was replayed. Run 22's read-only op78 probe after teardown correctly
  refused `lifetime parent is not currently reserved`; the parent had left its reserved
  state when that turn ended. Evidence is `paid-plan-probe/outcome.json`; it is not a
  successful regression of the paid planner. Run 25 supplies the successful fresh-turn
  receiving evidence.

### Current hbox run and verification

All paths here are under `/home/hbox/aa-run` unless absolute. Secrets remain private in
`secrets/openrouter.key`; never print them. Source for orchestration/Rust is `src`.

- **Run 25 green:** `run25.sh`, `run25.pid`, `run25.log`, `step25/oracle`.
  Base newest READY candidate selected: `994e36d0800da42152e0078c3631703cf466ac6e`.
  Copied roles and relocated manifest: `bin-counter`, `cand-counter/manifest.json`; original manifest
  retained. All 26 candidate role digests checked before explicit overlays. Runtime root
  `hroot` rebound to the same bundle (`rebind25.json`).
  `result.json`: all five rows passed. Actual tool-result evidence names
  `typed-apps-not-granted` before the grant and has no application dispatch then.
  Granted operation 183 PUT returned 201; operation 217 GET returned 200, both definite
  with exact native admission/reply/settlement joins. `human-read.json`: separate
  session 9893001, subject 7, app 9890001, GET `/dav/notes.txt` returned 200 and the
  exact `Hermes was here 563a91a19caf4850` marker (body SHA256
  `e59d1625f3a384e3043c34b9a42f461cf359caaf20e5f3045b7b88285ebd609d`).
  World-down command 0118 exited 0; `teardown/result.log` reports zero removal assertions.
  Small review copies are local `target/aa/run25-{result,human-read}.json` and
  `target/aa/run25-teardown.log`. The full bounded exports remain on hbox.
- grain-runtime overlay SHA256
  `a62684a9291da25629095be2fdf2094ed445e256b9230c756db1e8ace1ab41a6`.
  Enrollment tests: 10 passed, one external retained-capture fixture unavailable/ignored
  (`build-enrollment2.log`). Typed translation/native HTTP parser: 13 passed
  (`build-dispatch.log`). Compaction/real birth verification: 4 passed (`build-retention2.log`).
- Native Host SHA256 `680830fa170579e7bfd014f599d8428f7917e1e68cac0ac86130781770c5d53c`;
  consent SHA256 `d8dedf15edf910275f5d155593b8a3ab6479fe13f7eee37ab1c7e589e1b251af`.
  Independent warm copy `lean-paid` has source at 7f6666525 plus the one planner edit;
  all Lean sources are unchanged between that candidate and 994e36d08. Live Lean check:
  zero errors (`lean-paid-check2.log`). Recorded native builder with Host.Main gate and
  consent companion passed (`build-native-paid.log`, `host-paid-out`, `consent-paid-out`).
  Two Lean seats, two C jobs, 12-GB swarm cap; only 17 Host closure modules re-elaborated.
  dregg-build SSH rejected authentication; hbox is the authorized warm fallback.
- spk-host overlay includes the native refusal diagnostics and latest candidate's export
  status diagnostic. `build-paid-verified.log`: two native library checks passed and release
  built using the repository's pinned Rust toolchain. Earlier CLI filter selected zero tests;
  a subsequent library run from outside the tree used the box default toolchain, so the
  final verification was rerun from the source directory. The counter fix was then built
  and tested in `build-counter3.log`: 37 passed, three explicitly installed-unit probes
  ignored. Run 25 spk-host SHA256:
  `65c5bcab93749013d7c7ba77a45353509b0767b869b84aecc7d9d2ab984a46b2`.
- Focused custody/mounts, installer source pin, socket teardown, attachment paths/options,
  bounded export checks passed on hbox. Four apps-driver evidence/cleanup checks and all
  26 attachment-helper tests passed locally.
  These checks alone are not end-to-end receiving evidence.

### Integration

Local tip is root's checkpoint `d5824cf2d79797b7bbe7bbed2f78c13f5c5c04ee`, based on
`2b9debe99`. Preserve that checkpoint. The requested merge of origin/main failed because
this sandbox cannot write the worktree's Git metadata (`ORIG_HEAD.lock` outside writable
roots). No stash/reset or metadata workaround was used.

`target/aa-commit.sh` is the parent entrypoint: merge origin/main, inspect/stage named paths
only, commit with the required `Co-Authored-By: codex (gpt-6-astra)` trailer, then push
`origin lane/apps-agents`. It includes the Lean planner, native diagnostics, follow-up
journey changes, shared dispatch-counter initialization, untracked `test_j14_apps.py`,
and this continuation. The requested hbox journey is complete; no world from this lane
remains running. The parent owns the Git merge/commit/push and whole-tree integration/tour
verification. This lane result does not claim the composed tour or nightly passed.
