# apps-agents lane state

Branch `lane/apps-agents`, worktree `/Users/ember/dev/minidregg-lanes/apps-agents` (2026-10-29).

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

## CONTINUATION (written at ~540k tokens; a successor starts here)

Goal: a Hermes resident in the shared lobby room puts and gets a Davros file in one task through
Mini (typed tools), a refusal by name without the room apps grant (hermes/tools bit 16), and a human
read of the same grain; real provider (OpenRouter pool row). Direction from ember via the coordinator:
typed operations as first-class Mini capabilities across every packaged app, declarations the shared
vocabulary (Davros first, then Forgejo and the rest as repackaged).

### Landed or with the integrator (lane/apps-agents tip merged with integration/staging)
eca26cc6c typed Hermes tools (on main); 289e0088b op36 linkage clauses (on staging); d707dd84d Davros
text helpers; e6c5d4da4 web-kind agent route v4; application-attachment.py `route`/`typed` options;
and the uncommitted-at-time-of-writing set below (commit it first: `git status`).

### Uncommitted/just written (verify, commit, push)
- native/resource-client/journey.d/j14-oracle.py: hooks MODEL, start_provider, gateway_config,
  set_provider_keys (defaults = the old fixture behaviour; the Oracle driver test has one macOS-tmp
  failure that also fails on baseline).
- native/resource-client/journey.d/j14-oracle-inputs.py: sizeClass, expectedHost, attachmentExtras.
- native/resource-client/journey.d/j14-apps.py: the Davros journey driver (class Apps; phases
  world, prepare_platform, prepare_application, worker, room, attach, probe; pool provider; probe =
  refused turn then granted put/get turn).
- scripts/application-attachment.py: typed.declarationSource is carried into the controller bundle
  (state/shared-app-refs/ALIAS.declaration.json) and typedApplications.declarationPath points at it.
- deploy/spk-host/controller-world.py: 'typedApplications' added to the worker tool-config keys a
  config update may change; deploy/spk-host/install-user-world: companion code pin updated to the
  new controller-world.py sha256 (442af8ed...). Anyone changing controller-world.py must update it.

### hbox state (run area /othersys/aa-run; no group/world-writable ancestors; bins are copies)
- Wrapper /othersys/lanes/apps-agents/run2.sh (edit step dir each run: mkdir -m 755 stepN). Source
  synced to /othersys/lanes/apps-agents/src (rsync from the Mac worktree before each run).
- Passing so far with Davros: world, prepare_platform, prepare_application (Davros package
  5485d227 copied to /othersys/aa-run/data/davros.spk). Fails in worker: the Hermes runtime root
  ($J14_HERMES_ROOT = old j14-acp-12 root) is a stand-in with no pins.json/venv.
- NEXT: build a real runtime root: `deploy/hermes/build-runtime-root SOURCE OUT CANDIDATE` with SOURCE =
  a git checkout of github.com/NousResearch/hermes-agent at 6d8a8bebf70b09554deda5a0fcd95facbbde7b07,
  uv + python3 3.11-3.13, network, and CANDIDATE = a dir whose manifest.json has grainRuntime,
  grainProviderBridge (paths) and sha256.grainRuntime/grainProviderBridge (the integrator relocated
  candidates under /ci/c-<sha>...; /othersys/lanes/integ is gone). My copied binaries are in
  /othersys/aa-run/bin; a synthesized /othersys/aa-run/candidate-manifest.json exists (extend it).
  Then set J14_HERMES_ROOT and rerun: `./run2.sh probe`.
- The OpenRouter key is at /othersys/aa-run/secrets/openrouter.key (mode 600; never print). The pool
  row, caps and the broker `key set --pool` are in j14-apps.py (Apps.start_provider/set_provider_keys).
- Worlds: tear down failed ones with scripts/spk-platform/world-down.sh over a copy of a
  broker-NNNN/recovery.json laid out as RUN/broker-setup/recovery.json plus RUN/bin -> /othersys/aa-run/bin.
  Leftover: 27a7c547 registry/`vars` dir (integrator's housekeeping). Stores 7dca8d66 and the step8
  store may need teardown; check /etc/mini-spk-volumes.

### Still to write
- The human read: a second delegate (sessionKind web) in inputs.provision plus its route; read
  notes.txt over the grain's http.sock with the browser token (as featured-qualify.sh `req`).
- Probe evidence: application_attempts() reads the controller journal's applicationApiHistory; check
  the key names (routeName vs route_name) against the live journal.
- A test for application-attachment.py's new options; a Lean/Rust test that the Davros text ops reach
  Mini admission (the typed unit tests use a fake controller half).
- Then Forgejo and other apps: one declaration + typed attachment each (names/aliases must be unique).
