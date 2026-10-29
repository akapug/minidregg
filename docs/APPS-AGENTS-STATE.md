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

## CONTINUATION (rewritten 2026-10-29 at wind-down; a successor starts here)

Goal: a Hermes resident in the shared lobby room puts and gets a Davros file in one task through
Mini (typed tools), a refusal by name without the room apps grant (hermes/tools bit 16), and a human
read of the same grain; real provider (OpenRouter pool row). Direction from ember: typed operations as
first-class Mini capabilities across every packaged app, declarations the shared vocabulary (Davros
first, then Forgejo and the rest as repackaged). Row: native/resource-client/journey.d/j14-apps.py.

### Where the Davros journey stands
- Passing on hbox: phases world, prepare_platform, prepare_application (Davros package 5485d227).
- The Hermes runtime root is SORTED: /home/hbox/aa-run/hroot, built by deploy/hermes/build-runtime-root
  from /othersys/lanes/infra/hermes-agent (already at 6d8a8beb) against /home/hbox/aa-run/cand/manifest.json
  (the 2b8f75 binaries in /home/hbox/aa-run/bin, copies). A newer candidate: `build-runtime-root --rebind
  /home/hbox/aa-run/hroot CANDIDATE` swaps only the two binaries; the worker's grain-runtime must equal
  the controller's. Infra also has a c7a632 root at /othersys/lanes/infra/hroot-c7a632f7befd (c7a632
  contains eca26cc6c typed tools; it lacks e6c5d4da4 v4 web-kind routes, which are only on staging).
- Run area moved to the NVMe: /home/hbox/aa-run (bin, data, secrets/openrouter.key mode 600, hroot, cand,
  src = rsync of this worktree, run.sh = the wrapper, step9 = last step dir). Rerun:
  `mkdir -m 755 /home/hbox/aa-run/stepN`, edit JOURNEY_STEP_DIR in run.sh, rsync the worktree to
  /home/hbox/aa-run/src, `nohup swarm-build ./run.sh probe > runN.log & echo $! > runN.pid`.
- FAILS in phase worker (run9, step 56 controller-run, `grain-runtime create`): "prepare dispatch
  controller full consent exited ... local process
  /var/lib/mini-spk-worlds/<store>/controller/bin/minidregg-client-consent ended before answering: consent
  closed (consent transport lost before an answer ...)". Unread yet: the consent process's own stderr
  (step9/oracle/homes/*, participant.stderr, the world's controller logs). Suspect first: the consent
  binary in /home/hbox/aa-run/bin (copy of the 2b8f75 candidate's minidregg-client-consent) versus
  what deploy/spk-host/install-user-world installs, or the controller-world.py pin edit made this lane
  (typedApplications key; code pin 442af8ed...). Compare with a green J14_ORACLE worker step if any
  exists in docs/ROWS-OWED.md before concluding.
- The world of run9 is torn down (world-down.sh, "removal_assertions=1"); one /etc/mini-spk-volumes entry
  matching ccf03eb may remain: check it before the next world.

### Still to write
- The human read: a second delegate (sessionKind web) in inputs.provision plus its route; read notes.txt
  over the grain's http.sock with the browser token (as featured-qualify.sh `req`).
- Probe evidence: application_attempts() reads the controller journal's applicationApiHistory; check key
  names (routeName vs route_name) against the live journal.
- A test for application-attachment.py's new options; a test that the Davros text ops reach Mini admission.
- Then Forgejo and other apps: one declaration + typed attachment each (names/aliases unique).
- Land through the integrator (agent aca7a1fd39def735a): nothing new is green; the lane tip is the
  already-merged set plus the j14-apps driver (e2a54044e and this docs commit).
