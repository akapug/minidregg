# DreggNet’s cloud-lite hosting work

Scope: `/Users/ember/dev/DreggNet` at `7f51591` (`dregg-native-rebuild`), plus read-only ClusterVision history. DreggCloud was another investigator’s scope. I ran no builds or remote checks; “tested” below means test artifacts and historical session evidence, not a fresh run.

## What existed

### Static sites and micro-domains — **working, then deployed**
Ember’s request was “minisites and hostings … on the `dregg.works` domain” (`claude:a9fdb049`, msg 0). A site became a name/owner/asset-map cell with a `site-host/<name>` capability and publish receipt (`webapp/src/hosting.rs:71-84,175-217`). Separate subdomains supplied cookie/storage/CORS isolation (`docs/WEB-HOSTING.md:82-91`). Real-TCP publish/serve, restart, fork and time-travel tests exist (`webapp/tests/site_publish_serve.rs:88-146`; `durable_sites_restart.rs:28-132`).

Commit `810740d` (2026-06-29) mounted the gateway and shipped `hello.dregg.works`; the go-live brief is `claude:af90d4a3`, msg 0. Caddy used wildcard DNS plus **per-name on-demand Let’s Encrypt HTTP-01**, gated by `/internal/site-exists`, not a wildcard certificate (`deploy/staging/Caddyfile:64-89`). Important limit: the registry was in-process and the real node `Effect::Write` remained a seam, despite a real off-chain Poseidon2 root (`webapp/src/hosting.rs:31-47`). Dependencies were cells/caps/receipts, gateway Host routing, DNS and Caddy. Minidregg already has all four analogues, including stronger Lean admission and grain origins.

### Custom domains — **working library prototype; deployment not found**
`dregg-domains` binds an owner-approved domain to a site, requiring a TXT nonce or CNAME before routing or certificate approval (`dregg-domains/src/lib.rs:31-50,93-150`). It has a real Hickory DNS resolver; lookup failure stays `Pending` (`live.rs:23-35,47-83`). Tests cover capability forgery, owner-only rebinding, CNAME and restart (`tests/custom_domain_roundtrip.rs:72-181`; `durable_domains_restart.rs:37-83`). It depended on external DNS/ACME and the site registry; minidregg has no custom-domain flow, but does not need one for micro-domains.

### Code execution and member-hosted services — **narrow prototype**
Only numeric core wasm/wat executed, in wasmi with **no host imports and no fuel**, explicitly for trusted/bounded compute. JIT, native/Python/Node, Caged, microVM and GPU all failed closed (`docs/COMPUTE-TIERS.md:24-30,51-94`; `exec/src/lib.rs:468-487`). Agent WebApps mapped exact HTTP routes and integer query parameters to WAT handlers (`docs/AGENT-WEB-APPS.md:24-44,90-107`). Persistent servers had durable lifecycle/metering tests over `LocalProvider`; real KVM/Firecracker processes and mesh ingress were explicitly future work (`control/src/server.rs:31-54`). Thus budgets did not bound CPU runaway, and no general tenant service runtime shipped. Minidregg’s SPK grains are the appropriate existing replacement.

### Shells and git deploy — **shell withdrawn; deploy prototype unsafe for strangers**
Hosted raw `shell` was removed after the critical finding that bash could read operator/co-tenant files and exfiltrate them (`docs/HOSTED-ISOLATION.md:7-41`). A per-tenant bwrap design followed, but uid allocation, seccomp/Landlock, egress proxy and sshd wiring remained undeployed (`:64-132`); its referenced `agent-host/` is absent at this HEAD.

`dregg-deploy` did test local clone→build→publish→serve, but ran repository-controlled `sh -c`. Network unshare and rlimit failures were non-fatal, and no mount namespace hid absolute host paths (`dregg-deploy/src/sandbox.rs:81-107,186-220`). It was not a hard multi-tenant boundary.

### Notebooks / IPython / Jupyter — **not found**
No implementation or relevant session was found. “Local notebook” meant CLI JSON state (`cli/src/main.rs:1300-1314`); the hosted “REPL” was an agent goal loop, not code cells (`docs/HOSTED-AGENT-SESSIONS.md:61-79`).

### Secrets — **working prototype, not deployed KMS**
The crate implemented encrypted versioned storage, cap/account-gated injection, rotation and receipted audit, with integration/no-plaintext tests (`dregg-secrets/src/lib.rs:1-28,60-150`). An operator-held root could still decrypt (`:9-14`). No deployment evidence was found. Minidregg has no equivalent general KMS, but already has a constrained provider bridge.

### Billing / metering — **in-process product prototype**
Publish, bandwidth, uptime, certificate and build charges worked against an in-process conserving ledger; real node settlement was gated (`control/src/hosting_meter.rs:10-54`). Invoices/limits/estimates had unit tests. This was not production paid hosting: the red-team recorded free-compute, self-reported metering and lease-double-spend paths (`docs/RED-TEAM-FINDINGS.md:43-52,541-550`). A session’s claimed `exec/src/budget.rs` and `meter.rs` (`claude:ca30c0fe`, msg 0) are absent at HEAD, so I do not count them.

### Agent workrooms — **prototyped; already superseded HERE**
Hosted Hermes sessions combined SSH/browser attach, caps, budgets and receipt chains; tests covered shared viewer/driver roles, attenuated forks and concurrent tenant isolation, using a scripted brain (`attach/tests/concurrent_multitenant_isolation.rs:1-40`). Production attach deployment was not established. Minidregg already has Hermes residents, rooms, purses and Lean-admitted writes.

## What could come HERE, ranked by stranger value per day

1. **Show the hosting that already works (highest).** Add one tour/journey beat: edit a Hacker Slides deck, publish it, open `<grain>-www.demo.dregg.online` anonymously beside the install receipt and grant boundary. Hacker Slides is already recorded qualified on w3/w5 (`docs/APP-MARKET-2026-10-27.md:184-199`); the anonymous, cookieless publishing boundary is implemented (`deploy/market/INSTALL.md:191-225`). **No new effect, DNS or hosting stack.** Risk: low; keep active published HTML on the separate `-www` origin.

2. **One general static-site SPK.** The existing B4 plan names Hugo, WordPress, Hacker CMS and Hakyll CMS, with exactly the right beneath-HTML row: write, build, GET `-www` (`docs/APP-MARKET-2026-10-27.md:94-100`). Pick Hugo first, reuse grain admission/origin, and do not port `SiteCell` or `DomainRegistry`. Risk: bridge/DAV/streaming prerequisites; scope to one small site.

3. **A notebook only if a compatible Jupyter SPK really exists.** First verify the package; none was verified here. Install it as an ordinary grain and label execution “sandboxed app computation,” never Lean-proved. Risk: native runtime, WebSockets, supply chain and memory/CPU exhaustion; bwrap is not itself a resource quota. If no maintained SPK fits, stop rather than hand-roll a notebook engine.

**Do not bring now:** raw shells, DreggNet’s git-build sandbox, wasmi persistent-server plane, custom domains, generic KMS or hosting billing. They add substantial trust surface without improving the demo’s central admission story; a future shell effect must come through the derived Effects path and a real OS boundary.
