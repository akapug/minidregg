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
