# Hetzner public demo: the gap from main to a URL a stranger can use

Scout report, 2026-10-26. Read-only: nothing was built, run, or sent over ssh. The
minidregg tree is at main `a0db11f8`. The infra tree is `~/dev/dregg-infra`, both local
`main` (`d243803`, 10-14) and `origin/main` (`8d7d6c9`, 10-08, fetched from the hbox mirror).
**These two have diverged: 25 commits exist only locally and 15 only on origin.** The newest
Mini deploy tooling is in those 15 origin-only commits: split tenancy, the DEPLOY-3 runbook,
the `jdeploy3` gate and the glibc check. Wherever this report says `origin/main`, the file
is read with `git show origin/main:PATH`.

**The finding that changes the plan:** Mini already has a public node on Hetzner.
`dregg-workhorse` is a cx33 in fsn1 at 2.28.141.27, Debian 13, rebuilt 2026-09-26
(`dregg-infra-migrate-fsn1` commit `ef04c06`). It serves candidate `5688775a` (source of
2026-09-30, re-genesised 10-01) over the box's system sshd, in a 3 GB `mini.slice`:
`dregg-infra/edge/mini/README.md:1-30` and `:278-293`. The last recorded read of the node
is 2026-10-03 (`deploy/shell/FRIENDS.md:1-8`, `:37`). The box is shared with production
Bread, headscale and the DelveTalk instances. So the work is "re-ship a current candidate,
on that box or on a fresh one, and make it safe and self-running for strangers". It is not
a deployment from nothing.

## 1. What has demonstrably run end to end on Linux

Three evidence grades are used below. **compiled**: the source built. **journey**: a
journey or acceptance ran and passed against binaries. **reachable**: someone other than
the operator's own test harness reached a running service.

| date | commit | box | what | result | grade | evidence |
|---|---|---|---|---|---|---|
| 09-19 | `12e6608` (host `0da9f139`); build `66d74dd` | a dev Linux box (not named in the excerpt read) | complete native "New World" run: 11 events, lost reply, 10 historical recoveries, lockout | PASS, 10,380 s (2h53m) | journey | `~/dev/dregg-assortia/sprints/2026-09-19/cycle-1-result.md` |
| 09-28 | `e22d16b` | persvati (per record) | recovery batch: two-participant enrollment, sharing, restart, current-law refusal, real fn receiving | passed, with the scope stated there; "not deployment qualification" | journey | `~/dev/dregg-assortia/sprints/2026-09-28/recovery-result.md:1-40` |
| 09-30 | `45a9974` | persvati, 24 CPU, load 5–7 | `deploy/candidate/build.sh` from a `git archive`, then init/start/sponsor/stop, then journey | build 1797 s. Journey: J0–J8 PASS, M7 PASS (4/4 hashes reproduce), K4 FAIL, G unmeasured past level 10 | journey | `docs/evidence/2026-09-30-candidate/README.md` |
| 09-30 | `b105bd7` | persvati, private sshd on 127.0.0.1:22422 | J0–J8 typed into `mini shell` over ssh: 56 ssh sessions | 89/89 rows | journey | `docs/evidence/2026-09-30-shell-journey/README.md` |
| 09-30 | `45a9974` | **dregg-workhorse** (Hetzner) | the journey run on the production box, as `mini`, inside `mini.slice` | J0–J8 PASS, 179 s wall; journey unit peaked at 726 MB | journey (on the public box) | `~/dev/claudesplosion/product/deploy-1.md:6,92-111` |
| 09-30 | `a5bd4c0` | persvati | M6: a non-Git SPK (sntfy) installed, started, served curl, stopped, restarted; a second instance ran beside it | all steps exit 0. STOP took 412–1638 s; share-b took 883 s | journey (lane) | `docs/evidence/2026-09-30-grain-running/README.md:30-60` |
| 09-30 | `ffcba4fe` | persvati | J12 (shared document, board, revoke) through `mini shell` | 134/134, 617.6 s | journey (lane) | `docs/evidence/2026-09-30-shell-docs/README.md` |
| 09-30 | `d4892050` | persvati | Discord entrance against a simulated Discord | 27 rows, 0 failures | journey (fake Discord) | `docs/evidence/2026-09-30-discord-entrance/` |
| 09-30 | `a28cf6b` | persvati | resident sandbox floor (bwrap + seccomp) | floor 24/24 held; negative control breached 15/24 | component | `docs/evidence/2026-09-30-sandbox-floor/README.md` |
| 10-01 | `5688775a` | **dregg-workhorse** | DEPLOY-2b: re-genesis, open roster. J9 run from ember's Mac **over the internet**, using test identities j9-{newcomer,third,stranger} | J0–J8 + J12 PASS, 132 rows | reachable from outside the box, but by the operator's own harness, not a second person | `dregg-infra/edge/mini/README.md:278-293`; `~/dev/claudesplosion/product/deploy-2b.md:5,141-152` |
| 10-01 | lane builds | dev worlds | J15/J17 rooms (p-story, p-credit), J14 Hermes with a scripted provider, SPK apps jspk1 44/44 | PASS on lane builds | journey (lane) | `README.md:79-94` (Honest state); `docs/evidence/2026-10-01-*` |
| 10-02 | `fe29db5b` (spk-ws) | persvati | EtherCalc co-editing over browser TLS at `https://localhost:18443`, with older Host/client | WS opens 13.6 s and 15.8 s; edit propagates in 0.04 s | journey (loopback) | `docs/evidence/2026-10-02-spk-browser-tls/README.md` |
| 10-03 | lane | dev | Discord world: composed scenario, fake Discord API, real shell/Host/Store | 30 focused tests plus the scenario | journey (fake Discord) | `docs/evidence/2026-10-03-discord-world/README.md` |
| 10-03 | read only | dregg-workhorse | node state read: 5688775a; roster = ember + 3 test keys | **no friend enrolled** | none | `deploy/shell/FRIENDS.md:37` |
| 10-04 | main `4795b657` | continuous runner (box outside the repo) | J0–J4, J6, J7, JROTL pass; J5 and J8 fail | the J5/J8 failures were journey drift, not the Host accepting a stranger (see §4) | journey | `README.md:79`; commits `a5db1f20`, `487117fe` |
| 10-14 | `d37eee80` | hbox, first landing | standing run, 136 lines | PASS 125, FAIL 3 (hermes: userns; fleetsign: race; growth: write p99 10 s at 1000 records), UNCONFIGURED 8 | journey | `docs/PIPELINE-HBOX.md:231-240` |
| 10-16 | main `cfb68bf9` | hbox | main's first hbox standing run, 147 lines | PASS 136, UNCONFIGURED 6, UNJUDGED 3, FAIL 2; wall 517 s | journey | commit message of `27a4fdae` |
| 10-17 | main `3618d842` (batch 3) | – | no standing-run result recorded in the tree | **unverified** | – | – |

**The "October 13 shellserver".** `docs/JOURNEY.md:1-5` defines the journey as its
definition of done, and `~/dev/dregg-assortia/NOW.md` sets 10-13 as announce day. I found
no evidence that it launched. The DEPLOY-3 runbook is headed "root procedure, NOT EXECUTED"
(`dregg-infra origin/main:edge/mini/SHIP-RUNBOOK.md:1`). Its own deploy gate P8 is recorded
FAIL (same file, §0). The node was last read at 5688775a on 10-03.

**Bottom line for section 1.** Source compiles and journeys pass on persvati and hbox
regularly. J0–J8 passed **on the Hetzner box itself** on 09-30 and 10-01 (the second over the
internet). No record shows a second person using the node.

## 2. The candidate/packaging route: build on hbox, ship to a VM

**Yes, the route exists and is built for exactly this split.** Do not build on the VM.
The rule "never build on these boxes" is in `dregg-infra/README.md` ("Rules that are
load-bearing").

- **Three producers, one packager.** `deploy/candidate/package.py` writes every candidate
  (`deploy/candidate/INTERFACES.md:8-14`, `:178-196`, `package.py:1-45`). The producers:
  - `build.sh`: from scratch, byte-reproducible.
  - `lane-build.sh host|consent|rust|pack`: incremental from hbox's warm base, run under
    `swarm-build` (`lane-build.sh:1-18`).
  - `package.py --capsule FAMILY_DIR`: a sealed hbox family.

  `pack` and `--capsule` refuse any binary built at a different commit. `package.py`
  refuses a role set without the consent pair or the key broker.
- **Manifest pins.** Every output's SHA-256, source tree id, rustc `-vV`, the exact
  lean-toolchain, the `Cargo.lock` hash and the flags (`INTERFACES.md:115-135`).
  `provenance.json` adds the source commit, the archive hash, toolchains, timings and
  `.abi.glibcRequired` (`:150-176`). `run.sh` re-hashes every output before init, serve,
  start or sponsor, and has no bypass (`:136-141`).
- **Shipping.** `dregg-infra edge/mini/ship.sh C [--reference REF] [--regenesis]` does this
  (`ship.sh:1-47`; `edge/mini/README.md:140-165`):
  1. checks `SHA256SUMS` locally;
  2. rsyncs C to the box without `work/` (about 9 GB of intermediates);
  3. checks the sums again on the box;
  4. unpacks the candidate's own journey and FRIENDS.md from `source.tar`;
  5. writes a box manifest whose paths all go through `candidate/current`, which fixes
     the absolute-path relocation (`INTERFACES.md:139-141`, `:444-445`);
  6. flips `current`, runs init if there is no Store, restarts, runs sponsor, runs
     `mini-health`, and re-renders the roster.

  `BOX=` overrides the target host (`ship.sh:49`).
- **ABI.** On `origin/main`, ship.sh refuses a box whose glibc is older than
  `.abi.glibcRequired` (`origin/main:edge/mini/ship.sh:15-16,95`). hbox builds need
  **glibc 2.39**, and the workhorse has 2.41 (`origin/main:edge/mini/SHIP-RUNBOOK.md` §0,
  P9). **So a Hetzner VM must be Debian 13 (glibc 2.41) or Ubuntu 24.04 (2.39). Debian 12
  (2.36) is refused.** Prefer Debian 13 for a second reason. Ubuntu's
  `apparmor_restrict_unprivileged_userns=1` is exactly what breaks bwrap for Hermes and
  m6grain on hbox (`docs/PIPELINE-HBOX.md:184,191`).

**Gaps in the route:**

1. **The infra repo has diverged** (header of this report). `ship.sh`'s ABI check,
   `jdeploy3`, split tenancy and SHIP-RUNBOOK exist only on `origin/main`.
2. **The deploy gate refuses.** On `origin/main`, ship.sh refuses unless
   `C/gate/jdeploy3-result.json` is PASS for this exact candidate. That gate needs all
   seven composed phases to pass. As of 10-04 the documents, apps, connector and residents
   phases were red on a scratch world (SHIP-RUNBOOK §0, P8 table). A shell-only demo must
   either turn those green or change the gate's scope. That is an ember decision; the
   runbook says "none of these is relaxed".
3. **The frame assumes the workhorse.** That means 10.10.1.10, an anchor that pulls
   backups, and sharing the box with Bread. For a fresh VM, `install.sh` and `lib.sh` need
   retargeting, and the backup pull needs a new off-box target.
4. **Genesis params are stale.** `edge/mini/genesis-params.json` has
   `issuanceCap: null`, but batch 3 (floors, 10-17) made `issuanceCap` a genesis
   parameter (`INTERFACES.md:405-406`). The clock's `genesisNow` must be filled by
   `params.sh fill-genesis` at genesis time (`deploy/candidate/params.sh:1-20`).
5. **The M7 reference** for the on-box journey needs a second independent build (`--reference`).
   This is optional for serving.
6. **The pinned config names helpers by absolute path**, so the candidate directory must
   not move after `init` (`INTERFACES.md:444-445`). The `current` symlink handles this.

## 3. Public surfaces a stranger could touch

| surface | binary / unit / doc | what a stranger needs | state | abuse notes |
|---|---|---|---|---|
| **SSH hosted shell** (`deploy/shell/mini-shell-ssh`) | `mini shell`; system sshd `Match User mini` drop-in (`dregg-infra edge/mini/50-mini.conf`); OPERATOR.md, FRIENDS.md | an ed25519 key that ember adds to `friends/NAME.pub`. Then the stranger runs `keygen`, and the operator enrolls and provisions them (`deploy/shell/OPERATOR.md`; `mini-reenroll NAME` automates steps 4–6) | **deployed** (5688775a). Main has many more verbs than the node (`FRIENDS.md:11-37`) | **The signing key lives on the box.** On today's single shared `mini` account, other members' sessions can read it (`website/join.html`; `FRIENDS.md:46-60`). Split tenancy is built, but no box runs it (`README.md:87`). Writes are funded from the sponsor's provisioning; synthetic balances |
| **SSH proxy mode** (`mini-socket-proxy`) | `mini socket-proxy`; `mode=proxy` lines | a key line plus `mini` on their own machine | in main, not on the node | **Signing on the friend's machine is refused** until they hold a locally replayed peer Store, and no command hands them one (`deploy/shell/README.md:75-84`). The macOS client has no consent pair (`:82-83`). In practice it is not usable by a stranger today |
| **Pay to enrol** (`mini join --solana`, pay-watcher, roster-sync, `mini-enrollment-bootstrap` behind Caddy) | `deploy/pay/README.md`; `native/resource-client/src/enrollment_bootstrap.rs` (rate limits at `:31,348`) | 50 DREGG per week, paid on Solana to `5N2uUG4T…` | fixtures only; "not deployed" (`FRIENDS.md:510-567`) | Self-enrollment is proxy-only, so it hits the signing gap in the row above. A wallet, an ssh key and a Mini key end up linked publicly on-chain |
| **Discord** (`native/discord-entrance`, `mini-discord`) | `deploy/discord/README.md`; `dregg-infra edge/mini/mini-discord.service` | a root-owned roster entry mapping their Discord id to a session NAME, added by ember (`deploy/discord/README.md:38-41`) | simulated Discord only; "no Discord application exists" (`README.md:89`) | Bounded: lines ≤1000 chars, 4 concurrent, ephemeral replies. The anchor Caddyfile on `origin/main` has **no** discord route. Not stranger-ready: the roster is manual |
| **HTTP / browser to SPK grains** (`spk-browser-proxy`, `spk-hostd` custodian) | `deploy/spk-host/{HTTP-CUSTODIAN-CONTRACT,BROWSER-WEBSOCKETS}.md`, `USER-TENANCY.md`, `install-user-world` | a per-participant custodian with fixed coordinates and three operator-provisioned 256-bit tokens | `serve-http-unavailable` returns 503 by design (`HTTP-CUSTODIAN-CONTRACT.md:1-10`). The browser path ran on loopback only (10-02) | TLS 1.3 with X25519MLKEM768 only and no classical fallback (`BROWSER-WEBSOCKETS.md:20-25`). Each app HTTP request is a full serial Mini transaction (`docs/PERFORMANCE-REVIEW-2026-10-03.md` §1). Grain CPU, memory and disk are capped by cgroup classes through the root broker. M6 has no `journey.d/m6.sh` (UNBUILT) |
| **Docuverse web** (`mini web`) | `native/resource-client/src/web.rs:3-12,107` | – | **loopback only**: binds 127.0.0.1 and checks `Host:` | No public web front end exists. A stranger could reach it only through an ssh port-forward, and `AllowTcpForwarding no` blocks that |
| **Project site** (`website/`) | GitHub Pages | – | static | It says accounts are given by hand (`website/join.html`) |
| **Hermes residents** | `grain-runtime`, `mini-hermes.service` (installed, not enabled), `deploy/hermes/README.md` | a room member summons Hermes; operator-supplied `providers.json` and keys | scripted provider only (`README.md:88`). Required row `HERMES-LIVE` is pending (`scripts/pipeline/required-rows:74`) | Real money: a pool key pays. There are per-row caps (max_tokens, calls/day/runner) and purse admission (`deploy/hermes/README.md:1-25`). Needs userns-capable bwrap |
| **Fleet surface** (`mini fleet`) | `docs/FLEET-SURFACE.md`; journey row m8 | an enrolled, funded account | journey on its own Store | Every turn pays the tariff; there is no faucet (`docs/FLEET-MIGRATION.md:33`) |
| **mini-sdk / mini-sdk-ts** | `native/mini-sdk`, `native/mini-sdk-ts` (private package, Node ≥23.6) | a local Host image, a consent executable and a socket | library | Client-local trust model; the same signing gap as proxy mode |

## 4. Known-red on main, and what each blocks

- **Lean module known-red:** `Fixtures.NativeAcceptedFixture` (cv `01a146dd-4f9d`,
  storage-rule fixture drift; `scripts/pipeline/known-red-modules:7`). It is in the separate
  `Fixtures` library, and nothing under `Host/`, `Kernel/` or `Compiler/` imports it, so
  **it does not block the Host build or a candidate**.
- **Required-row known-reds** (`scripts/pipeline/required-rows:69-72`):
  - `jpay/JPAY6` and `jpay`: the consent allowlist refuses the provider keys JPAY6 writes.
    This blocks Hermes-with-paid-provider. The 10-16 commit says batch-2 `consent-model`
    is the fix, so the line may now be stale; unverified.
  - `m6grain`: a sudoers path problem in the hbox runner. Underneath it there is also
    `setgroups` EPERM under AppArmor userns (cv `01a13d9c`, `docs/PIPELINE-HBOX.md:191`).
    This blocks any SPK demo claim.
  - `m7`: no reference build on hbox. It blocks nothing for serving.
- **Pending, not yet required** (`required-rows:73-75`):
  - `births`: the bar is write p99 ≤5 s and cold reopen ≤60 s, and main is not yet green.
  - `HERMES-LIVE`.
  - `jcertify`: the tail certifier. It passed 320 records on the `dregg-infra`
    `edge/mini-certify` branch, which is not merged. **A public week needs it** (§7).
- **hbox absences and flakes.** hermes is unproven on hbox because of the userns
  restriction (`PIPELINE-HBOX.md:184`). `jserve` is flaky on exactly two cases: "a client
  sends 3 bytes then sleeps 30 s" and "50 connections that send nothing" (`:237-240`).
  Those are the slowloris shapes a public socket meets. `growth` FAILed at write p99 10 s
  at 1000 records (`:235`).
- **The README is stale on J5/J8.** `README.md:79` says a stranger's attempt "was not
  refused by the Host". Commits `a5db1f20` and `487117fe` (10-04) show the cause:
  - J5: the client's consent gate stopped the unenrolled key before anything reached the
    Host. A raw-frame check (`journey-stranger.py`) now proves the Host refuses it.
  - J8: a crafted request carried a removed field.

  Both are required rows and are not listed known-red.

## 5. Security prerequisites: exists vs missing

| prerequisite | exists | missing for a public box |
|---|---|---|
| Transport authentication | sshd key-only for `mini`, no forwarding, root-owned `authorized_keys`, one forced command per key (`50-mini.conf`); per-key `restrict` | sshd `MaxStartups` / `PerSourcePenalties` / `MaxSessions` tuning for `mini`. No fail2ban-style throttling in edge/mini |
| TLS | anchor Caddy terminates TLS for the other edge names; templates `enrollment-bootstrap.Caddyfile`, `discord.env` | no Mini or Discord route in the anchor Caddyfile (`origin/main`). A fresh VM has no Caddy. SSH needs none |
| Operator vs public socket | registry: 184 active ops (113 public+operator, 69 operator-only, 2 stdio-only), 2 reserved (191, 192) (`protocol/host-operations.json`). `serve-operator` and `serve-public-proxy` exist (`INTERFACES.md:262-271`) | **the live node runs one socket with no operator socket** (`FRIENDS.md:37`). The re-genesis onto the `ingress.json` topology is in SHIP-RUNBOOK §4 and was not executed |
| Tenant isolation | split tenancy (`mini-core`, `mini-s-NAME`, `mini-keys` broker, `50-mini-split.conf`, `jsplit-tenancy.sh`) on `origin/main` | **never run on any box** (`README.md:87`). Strangers on a shared uid can read each other's keys |
| Key custody | `mini-keys` holds the seal key, provider keys and Discord secrets, with SO_PEERCRED (`native/mini-keys/src/peer.rs`). Pre-rotation (K-PREROTATE) | the sponsor key is generated on the box with `nextKeyDigest: null`, so it is **not rotatable** (SHIP-RUNBOOK, "Custody decision"). Hosted members' keys sit on the box by design |
| SPK sandbox | bwrap pinned by SHA, `--disable-userns`, cap-drop, seccomp policy `native/spk-host/seccomp/resident-web.policy`, root broker answering only the operator UID (`deploy/spk-host/README.md:30-60`), floor 24/24 | broker root install, uidmap/subuid, cgroup delegation and linger on the VM. Grain workers as `systemd-run` units are still undecided on the workhorse ("Q3", `edge/mini/README.md:78-80`) |
| Backups | `mini-backup` (nightly, online `.backup`, integrity check, **age-only** on `origin/main`), anchor pull, `mini-restore-check` | a fresh VM needs an off-box pull target. Archives contain the sponsor secret key and every retired Store (`edge/mini/README.md:301`) |
| Rate limits | paid-entry HTTP quotes and status (`enrollment_bootstrap.rs:31,348`); Discord concurrency 4; refusals after authentication are charged to the signer's lane (JRLANE) | **`mini serve` handles one request at a time** (`INTERFACES.md:208`), with 10 s receive/reply deadlines (`:257`). Unauthenticated or wrongly signed calls cost the sender nothing. No per-key request quota at the shell or proxy |
| Abuse and funding | synthetic Book; tariffs in genesis; sponsor `initialBalance` 100000; per-friend `provision … FUNDING` | no per-stranger budget policy or birth quota, no faucet, no automated onboarding |
| Log retention | clock journal rotated at 1 MiB; journald | Discord custody (`SESSIONS/.discord-custody`, up to 1 MiB per interaction) and `refusals/` grow without bound. No retention policy |
| Health | `mini-health` (signed read); `--advance`, HOST-MALFORMED and `verify.sh --restart` on `origin/main` (SHIP-RUNBOOK §6) | no alert reaches ember when health fails |

## 6. Build and runtime resource numbers

**Build: on hbox, never on the VM.**
- **Cold full candidate, recorded** (`docs/evidence/2026-09-30-candidate/README.md`):
  1797 s at commit 45a9974 on 24 CPUs at load 5–7. Of that: Lean packages and mathlib
  cache 117 s, native Host 1629 s (363 modules, 3296 link objects), Rust 46 s. Under load
  18–35 the same build took 4306 s twice and 1996 s once. The `work/` tree is about 9 GB
  (`edge/mini/ship.sh:9`).
- **The closure has doubled since.** `scripts/pipeline/lean-module-rss.tsv` (10-17,
  burst5-a EPYC 4564P, `LEAN_NUM_THREADS=4`, cold closure at `3fcc7f46`):
  - **784 Host.Main modules**; summed per-module compile wall 2725 s;
  - **peak RSS 18.5 GiB** in one module (`Kernel.PayEnrolReceiver`), with the
    PayEnrolV2/PayObservation/PayCellDomain receivers at 18–18.5 GiB;
  - 13 modules above 8 GiB.

  `build-native-host.sh` weights compiler seats by these numbers under a memory cap
  (default: the cgroup's `memory.max`, else 48G; `scripts/build-native-host.sh:88-89,1444-1478`).
  **No recorded cold wall time at the 784-module closure is in the tree.** Inferring from
  the 09-30 numbers, expect tens of minutes to over an hour on hbox under `swarm-build`'s
  96 GB cap. That is an estimate, not a measurement.
- **Incremental route.** `lane-build.sh` replays the warm base; the base replays 0 modules
  when warm (`docs/PIPELINE-HBOX.md:213-218`). The 09-19 full umbrella took 585 s and the
  gate plus native build 661 s, at 581 files (`cycle-1-result.md`).
- **hbox standing run** of 147 rows: 517 s wall (commit `27a4fdae`). Growth to 1000
  records: 2436–5401 s (`PIPELINE-HBOX.md:149`).

**Runtime** (the VM shape):
- Idle Store about 320 MB. A full journey peaked at 726 MB for its unit and 1.04 GB for the
  slice (candidate 45a9974, 2026-09-30; `dregg-infra edge/mini/README.md:92-94`).
- Host ELF 159 MB, bare spawn 80 MB RSS (`docs/PERFORMANCE-REVIEW-2026-10-03.md:26`). One
  Lean process start costs about 40 ms on a 173 MB image (`WASTE-MODEL.md [deleted 3b2aa109]:57`).
- The resident Host now holds package replays (perf-memo, 10-16). **Current main's
  runtime RSS has not been measured.**
- Latency, recorded:
  - J4 write about 5 s, reopen 7.8 s on the workhorse (deploy-1);
  - G at 1000 records: write 2.2 s, reopen 4.3 s (persvati d2, `NOW.md`), but write p99
    10 s on hbox (10-14);
  - room create 262 s, each resolve about 6 s (SHIP-RUNBOOK P7);
  - SPK STOP up to 27 min (grain-running).
- **Hetzner shape.** Prices from `dregg-infra-migrate-fsn1/edge/REGION-PRICES-2026-09-26.md`:
  - cx33 (4 vCPU, 8 GB, 80 GB, $9.99/mo) fits shapes A and B with room to spare. It is the
    workhorse's own type.
  - cx43 (8 vCPU, 16 GB, $18.49/mo) for shape C with grains.
  - CX `available` flags in the API are wrong (trial creates succeeded).
  - The project's shared-core limit refused a 16-core create.
  - The Host serves serially, so extra vCPUs mostly help concurrent ssh sessions and their
    client-side consent work.

**Hetzner in the tree.** `grep -ri hetzner|hcloud|cloud-init|terraform|nix` over
minidregg `deploy/ scripts/ docs/` (excluding `docs/evidence`) finds **nothing**. All of it
lives in `dregg-infra`:
- `edge/tofu/main.tf:165-237` (hcloud workhorse and anchor, debian image, floating IP,
  private network);
- `edge/tofu/cloud-init-anchor.yaml`;
- in the migrate branch: `edge/tofu/fsn1.tf` and the fsn1 cloud-inits.

The tofu state lives in 1Password (`dregg-infra/README.md`).

## 7. The gap list

The bar: "a stranger with the URL can exercise it for a week without the operator
babysitting". Sizes: S is under a day, M is 1–3 days, L is more than 3 days.
**B** = blocks a demo; **n** = does not.

| # | gap | size | B/n |
|---|---|---|---|
| 1 | Reconcile `dregg-infra` local `main` and `origin/main` (25 local-only, 15 origin-only commits). The deploy tooling to use is on origin | S | B |
| 2 | Choose the host: re-ship onto `dregg-workhorse` (fenced 3 GB slice, shared with Bread, DelveTalk and headscale) or a dedicated VM. A dedicated VM needs a tofu module or a manual `hcloud` create with **Debian 13**, plus retargeting `install.sh`/`lib.sh` (no 10.10.1.10, no Bread fence) and a backup pull target | S (workhorse) / M (fresh VM) | B |
| 3 | Build a candidate from current main on hbox (`lane-build.sh` or `build.sh` under `swarm-build`) plus a second build for M7. The 784-module closure has 18.5 GiB modules; known-red is fixture-only | M (mostly wall time) | B |
| 4 | Deploy gate `jdeploy3` is PASS for that candidate. Documents, apps, connector and residents were red on 10-04. Either green them, or ember rules a shell-scoped gate (the runbook says never relax) | L to green; S for a ruling | B |
| 5 | Genesis params: add `issuanceCap`; run `params.sh fill-genesis`; **raise `lifetime`**. Birth root capabilities expire at `height + lifetime` (`Host/Json.lean:2074`), `lifetime` = 10000, and the clock timer alone adds about 1440 heights a day, so creators lose their root caps in about 7 days. Inference: I did not trace every consumer of `notAfter` | S | B for a week |
| 6 | **Tail-bound certifier.** Writes are refused after `tailBound` = 256 uncertified heights (`deploy/checkpoint/mini-checkpoint-certify.service`). At one clock tick a minute that is about 4 hours. Merge `edge/mini-certify` (jcertify, 320 records PASS) or install the deploy/checkpoint units with a real control capability | S–M | B |
| 7 | Week-scale growth soak: a week of minute ticks alone is about 10k records, and nothing past 1000 is measured (the hbox G at 1000 failed p99 10 s). Either slow the clock (for example a 5-minute timer) or run a 10k-record soak on hbox first. The consent provider's local replay per signing is also unmeasured at that size | M | B (risk) |
| 8 | **Split tenancy on the box** (`jsplit-tenancy.sh` on a scratch VM first). Without it, strangers on the shared `mini` uid can read each other's signing keys (`website/join.html`) | M | B for strangers |
| 9 | **Stranger onboarding without the operator.** Today each friend needs ember: `friends/NAME.pub` commit, render, `keygen`, then `mini-reenroll NAME`. Build a self-serve door: a rate-limited signup (an ssh `signup` forced command, or a small HTTPS form behind Caddy) that writes the key, renders, and runs `mini-reenroll` with a fixed per-stranger funding amount and a total cap. Pay-to-enrol does not fill this: it is proxy-only and proxy signing is refused | M | B |
| 10 | Per-stranger funding and abuse policy: a provisioning amount, a birth and write quota, sponsor-balance monitoring (sponsor `initialBalance` 100000), and what happens when the sponsor runs dry | S–M | B |
| 11 | DoS hardening: serial `mini serve`; jserve slowloris cases flaky; unauthenticated calls free. Add sshd `MaxStartups`/`PerSourcePenalties`/`MaxSessions` for `mini`, a per-session wall timeout, and a ceiling on concurrent sessions and `user-<uid>.slice` CPU and memory per member | S–M | B (demo-grade) |
| 12 | Operator-socket topology: re-genesis onto `ingress.json` (private Host plus public relay). It is in the SHIP-RUNBOOK §4 order | S (it is in the runbook) | B (needed by split tenancy and by roster-sync) |
| 13 | Alerting: `mini-health --advance`, certifier failure, roster-sync failure, disk, and sponsor balance pushed to ember | S | B for "without babysitting" |
| 14 | Backups for a fresh VM: age recipient installed (mini-backup has no plaintext mode), an off-box pull, one `mini-restore-check` | S | n (B if data matters) |
| 15 | FRIENDS.md "what the node has" table and `website/join.html` redone for the shipped candidate; README Honest-state J5/J8 wording corrected | S | B (usability) / n |
| 16 | Sponsor key custody: accept non-rotatable (option A), or add `run.sh init --sponsor-key` (option B) | S decision / S code | n |
| 17 | Log and custody retention policy (refusals, Discord custody, journald caps) | S | n |
| 18 | Discord: create the application, add an anchor Caddy route with TLS, and automate roster entries (Discord id to session) through the same self-serve door as #9 | M | B for shape B |
| 19 | Public docuverse: there is none (`mini web` is loopback-only). It needs a public read-only gateway (TLS, auth or anonymous read policy, rate limits) or a Studio route | L | B for shape C |
| 20 | One SPK grain in public: root broker install, uidmap/subuid, cgroup delegation, per-participant custodian and token issuance, PQ-only TLS acceptance, `journey.d/m6.sh` (UNBUILT), m6grain red. STOP and share take minutes | L | B for shape C |
| 21 | Hermes live: `providers.json`, pool key with spend caps, JPAY6 known-red, `HERMES-LIVE` pending | M | n (leave off) |
| 22 | Teardown and re-genesis plan to the homelab: what is exported (retired Stores and backups carry sponsor keys), and the notice to strangers | S | n |

## 8. Three candidate demo shapes

**A. SSH shell only (hosted keys).**
- Strangers sign up, `ssh -t`, and get every verb main's shell has: documents, boards,
  laws, delegation, refusal reasons, and rooms/chat if the gate qualifies them.
- Needs 1, 2, 3, 4 (a shell-scoped ruling at minimum), 5, 6, 7, 8, 9, 10, 11, 12, 13, 15.
- Box: cx33 Debian 13, or the existing workhorse slice.
- About 1–2 weeks of lane work, most of it in 8, 9 and the gate.
- Lowest risk, and closest to what already passed on the Hetzner box (J0–J8 and J12
  over the internet, 10-01).

**B. SSH plus Discord.**
- Everything in A, plus 18. Discord users reach the same `mini shell` through
  `/mini <line>`, one session per Discord id.
- Adds TLS on the anchor (or Caddy on the VM) and a Discord application.
- Discord sees all content (`deploy/discord/README.md`: "not end-to-end privacy").
- Only a simulated Discord run exists.
- About +3–5 days over A.

**C. SSH plus web docuverse plus one SPK grain.**
- Everything in A, plus 19 and 20, with 21 optional.
- Box: cx43 for grain headroom.
- This is the shape with no precedent. No application has served a public browser
  session; the closest is EtherCalc over loopback TLS. Grain lifecycle operations take
  minutes, and the browser TLS is PQ-only.
- Several weeks. Not advisable as the first public week.

## 9. What I could not verify

- The live state of `dregg-workhorse` after 2026-10-03: what candidate it serves, whether
  DEPLOY-3 or 4 ran, and who is on the roster. I did not ssh, per the brief.
- Whether `origin/main`'s 15 deploy commits or the local `main`'s 25 are the intended truth
  for edge/mini. The local tree I read for `edge/mini/README.md` predates the split-tenancy
  commits.
- Main `3618d842` (batch 3): no standing-run results are in the tree. Whether JPAY6's
  known-red line is stale after `consent-model`.
- The cold build wall time and Rust workspace time at the current 784-module closure (only
  the 09-30 363-module numbers and per-module RSS exist), and current main's runtime RSS.
- Whether the Store helper's 64 MiB whole-image record bound (`INTERFACES.md:354`) still
  limits history. `native/hyperdocument-link-sqlite-store/src/lib.rs:561` now has a
  per-height `durable_log` table, so the doc may be stale.
- The full set of `notAfter = height + lifetime` consumers (§7 #5 is inferred from
  `Host/Json.lean:2068-2074` and the genesis example).
- Performance at week scale (about 10k records), including the consent provider's local
  replay per signing.
- The 09-19 and 09-28 runs' exact boxes (the excerpts I read do not name them).
- Discord, Hermes and SPK against real external services: none was recorded in public.
