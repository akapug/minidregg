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

## CONTINUATION (codex, 2026-10-30; active verification)

Goal: j14-apps green on hbox: a Hermes room resident receives a real typed-tool refusal
without hermes/tools bit 16, then puts and gets a Davros text file in one task through
Mini admission/settlement, followed by a separate human web-session read of that grain.

### Diagnosis and changes
- Read run 9's actual system journal before changing the consent path. The consent process
  reported `permission denied` reading `/home/hbox/aa-run/bin/minidregg-credential-signature-verifier`.
  Its installed consent executable and candidate copy have identical SHA256
  `f72cb9d23009fa789852388ff2ce4be0913554c3d2e8533033b68ebec916d195`.
  `ProtectHome=yes` hid the configured signature/storage executables; the service exposed
  its Store directory only. The typedApplications pin was not the cause of this failure.
- The installer now checks and snapshots the two configured executables into a root-owned
  `controller/consent-dependencies` directory, records their digests, verifies them on use,
  and binds only those files read-only at their configured paths. `ProtectHome=tmpfs`
  hides other home content while explicit binds expose the pinned Store parent (including
  its replaceable anchor/checkpoint key) and exact transport directories. `ProtectHome=yes`
  plus ReadWritePaths was insufficient: direct native probes reproduced exec/key failures.
- Typed declaration JSON files now have a bounded private attachment-file route through
  controller config publication. Native Rust still validates declaration/package identity.
- Native application enrollment now permits one typed attachment with its matching new
  reference/route, instead of requiring a legacy service profile. Existing typed bindings
  remain immutable on refresh. The broker receives an exact inventory of resident home
  files/socket parents; the previous empty inventory refused the resident's host binary.
- `world-down.sh` removes the controller before removing its root world. Controller removal
  tolerates an already-unlinked legacy public socket, but refuses a replacement inode.
  j14-apps stops its own public listener before teardown, then tears down its world even on failure.
- j14-apps provisions an additional web session and checks its exact read of `/dav/notes.txt`.
  The probe checks linked provider tool-result evidence for refusal, definite application
  dispatch receipts and settlement, retained request/reply digests, and both PUT and GET.
  Real-provider runs no longer require an unused test-provider or data-publisher fixture.
  World creation uses `flock -o /tank/lanes/world-up.lock` only around world-up.

### hbox evidence and run inputs
- Newest READY candidate selected: `f34b03095c5c440ddce4a1d1c1c875b05d792692` under
  `/home/hbox/lanes/integ/candidates`. Its manifest still names `.tmp/bin` paths; verified
  copies and relocated manifest are `/home/hbox/aa-run/bin-f34b03095` and `cand-f34b03095`.
  The original manifest is retained beside the relocated one. `spk-ingest` is the tracked
  deployment script, installed separately. No dummy publisher or older native binary is used.
- Native enrollment overlay: `/home/hbox/aa-run/bin-enrollment` and `cand-enrollment/manifest.json`,
  with grain-runtime SHA256 `d934a9fa2a557d9c1086ffcc6768b50fc0d72333ddb48cd96e6ef50eb00836c8`.
  Built from this lane under swarm-build (2 Cargo jobs, 12G), using its own target/scratch.
  `build-enrollment2.log`: 10 enrollment tests passed, one retained-capture test ignored
  because its fixture was not supplied. Overlay manifest records source hashes/base candidate.
- Runtime root `/home/hbox/aa-run/hroot` rebound to that overlay with `build-runtime-root --rebind`.
  Source `/home/hbox/aa-run/src`; key remains in the private secrets directory (never printed).
- Run 9 leftover Store `ccf03eb175bf8943` and retry Store `5320a39851e808a4` fully removed.
  Run 13 Store `887fc39eb7972738` ended with `WORLD DOWN ... removal_assertions=0`.
  Runs 10/11 stopped at input validation before creating a world.
- Run 14: `/home/hbox/aa-run/run14.sh`, `run14.pid`, `run14.log`, `step14/oracle`.
  The declaration-file allowance was added after platform setup, before activation; exact
  before/after source bytes and hashes are in `step14/oracle/source-overlays`.
- Run 14 Store `5d0acb33423f64a5` and run 15 Store `46b9ef64fe07728e` torn down with
  removal_assertions=0. Native consent full-readiness succeeded under the corrected sandbox
  using run 14's retained Store; output is `step14/oracle/world/consent-mount-probe`.
- Run 16: `/home/hbox/aa-run/run16.sh`, `run16.pid`, `run16.log`, `step16/oracle`;
  Store `637a0f8b3e76c3b1`. Worker/room/typed enrollment passed. Actual provider tool-result
  evidence confirms `typed-apps-not-granted` and no dispatch without the grant. Granted
  PUT and GET both met `typed-dispatch-not-begun`; native history remained empty. The tool
  projection discarded the underlying detail, so native dispatch diagnostics were added.
  Teardown removal_assertions=0 and registry absence checked. Retained diagnostic journal:
  `step16/oracle/dispatch-diagnosis-journal.json`.
- Run 17 uses `bin-dispatch`/`cand-dispatch`, runtime SHA256
  `fbf079a8f7596d5010913746eb88b63e318e3bcc5999bfd32698f49d3aaa8e79`, 13 typed tests passed
  including the actual native HTTP input parser. `run17.sh`/`run17.pid`/`run17.log`;
  broker readiness refused a copied bin directory with mode 775. Corrected staging to 755.
  Store `4ab25f057111c6e3` removed with removal_assertions=0 and absent registry confirmed.
  Cleanup now follows the recovery locator even before broker.json exists, and stops a
  loaded/restarting broker. Regression test passes. The first launch lacked the step parent
  and stopped before any world; that log is retained as `run17-init.log`.
- Candidate `8cb74aba593663adf5fb42b49c5bf1b6329f16c1` became READY during run 16.
  Its diff has no grain-runtime, mini-sdk, controller installer, or attachment changes.
  Run 18 uses this new base with the same diagnostic runtime overlay in `bin-8cb74aba` /
  `cand-8cb74aba`; original manifest retained and 26 binary-role digests verified before
  overlay. `/home/hbox/aa-run/run18.sh`, `run18.pid`, `run18.log`, `step18/oracle`.
  Run 18 completed during a local network/sleep interruption. Store `f668228ec27ece30`
  torn down with removal_assertions=0; registry absence confirmed after reconnecting.
- Run 18's diagnostic stderr identified the actual refusal: session verification could
  no longer read `source-0000000000000031.json`. History compaction had deleted the exact
  source/attempt/author files still referenced by the admitted birth record. Fixed compaction
  to retain journal-referenced operation groups and workspace evidence, while still pruning
  unrelated later operations. Four focused tests pass, including the real birth verifier
  after compaction and refusal of a changed preimage. No digest-only replacement is accepted.
- Run 18 also exceeded the full controller export's 4096-file bound. Added the fixed
  `controller-export ... application` selection: journal, resident completion state,
  retained provider requests, and application request/reply files; all existing file/byte
  and ownership bounds remain. Apps uses this selection and records service logs before
  evidence assertions. Focused export, source-pin and three apps-driver tests pass.
- Run 19 uses the newest READY `ebaeb14c795051c74489f0ac91dd36ac5e5546df` with the tested
  retention/enrollment overlay in `bin-retention` / `cand-retention` (original manifest kept;
  candidate roles SHA-checked). Runtime SHA256
  `a62684a9291da25629095be2fdf2094ed445e256b9230c756db1e8ace1ab41a6`.
  Build: `/home/hbox/aa-run/build-retention2.log`, swarm-build 2 Cargo jobs/12G.
  Run: `/home/hbox/aa-run/run19.sh`, `run19.pid`, `run19.log`, `step19/oracle`.
  hroot rebound to the same runtime; run active. Candidate changes since 8cb do not change
  grain-runtime or mini-sdk, so the source overlay is still against identical native inputs.
- Focused hbox tests passed: consent dependency custody/unit mounts, installer source pin,
  absent-vs-replaced public socket teardown, bounded attachment paths, typed attachment options,
  and the journey's refusal/dispatch evidence guards. These are not end-to-end admission evidence.

### Integration
- Local branch starts at `2b9debe99`. The requested merge of origin/main failed because the
  sandbox cannot write `/Users/ember/dev/minidregg/.git/worktrees/apps-agents/ORIG_HEAD.lock`.
  Leave `target/aa-commit.sh` for the parent: merge main, stage named paths only, commit with
  `Co-Authored-By: codex (gpt-6-astra)`, then push `origin lane/apps-agents`.
- No end-to-end green is claimed until the live probe and teardown complete.
