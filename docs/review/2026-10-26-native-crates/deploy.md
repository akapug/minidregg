# Review: `deploy/` (the deployment tree, reviewed as one "crate")

- **Shard:** `/Users/ember/dev/minidregg/deploy`, the whole tree.
- **Files covered:** 262 files, 24,151 lines (`find deploy -type f | xargs wc -l`). By kind:
  98 `.md` (6,100 lines), 55 `.json` (7,993), 28 extensionless scripts (3,716), 14 `.sh` (1,577),
  11 `.py` (1,871), 5 `.rs` (1,207), 7 `.service` (228), 3 `.timer` (35), 6 `.hoon` (310),
  5 `.shell` (175), 10 `.log` (298), and 20 law-grammar/other files. The per-file table is Appendix A.
- **Reading:** every non-`.log` file was read in full except the large rendered law JSON files
  (`shell/templates/job/law.job.json` 1,894 lines, `shell/templates/mud/sheet/law.sheet.json` 1,863,
  `mud/org/law.ballot.json` 505, `mud/market/law.market.json` 306, `mud/quest/cellar-key/law.quest.json`
  282, `story/tale/law.player.json` 265, `mud/item/law.item.json` 230, `mud/org/law.org.json` 207),
  which are machine renderings of grammar files that were read in full; for those the structure
  (top-level `all` of N clauses) and head were read and checked against the source grammar. The 30
  three-line room `.md` scene files and the MUD `area.json`/`init.*.json` data were read as data. Each
  `.log` had its first 40 lines read (Section 1.10).
- **Date:** 2026-10-26. Read-only review; nothing was built or run.

## Executive summary (15 lines)

1. `deploy/` is four different things in one tree: (a) a real, careful **candidate packager** (`candidate/`, 2,416 lines) that is the only path from a commit to a shippable, SHA-256-pinned binary family; (b) **Linux service glue** (7 units, 3 timers, ~25 scripts); (c) **compile-time source for the Rust binaries** (`include_str!` of shell templates into `mini`, of `spk-host/spk-var-volume` into `mini-spk-volume-helper`, and `native/launch-gate/Cargo.toml` building `deploy/grain-host/launch-gate.rs`); (d) **~4,000 lines of dated evidence notes and logs** plus ~7,300 lines of never-shipped MUD game data.
2. The lead's premise that `native/launch-gate` is empty is wrong: its `Cargo.toml` has `[[bin]] path = "../../deploy/grain-host/launch-gate.rs"` (`native/launch-gate/Cargo.toml:13-15`). `launch-gate.rs` is built three ways (cargo via the packager, `rustc -O` in journeys, plain `rustc` per the README), so its bytes are not one identity.
3. What the public node actually runs (README "Honest state", `README.md:79`) is `run.sh serve` of the 2026-10-01 candidate behind the hosted-shell ssh entrance. Of the units in this tree, none is shown deployed except, by implication, the shell wrapper; `mini-store.service`, `mini-keys.service`, `ship.sh`, `install.sh`, `render-authorized-keys.sh` and the authorized-keys roster live in the **outside** `dregg-infra` repository (`shell/OPERATOR.md:4`, `hermes/mini-hermes.service:2`).
4. **Biggest security fact:** in the deployed "hosted shell" mode every friend's ssh session, the Store, the Host, the sponsor workspace and every other friend's secret key run as one Unix account `mini` (`shell/FRIENDS.md:50-52`, `shell/OPERATOR.md:14,17`, `shell/README.md:7`). The only fence between members is `mini shell`'s word grammar and file-name confinement. Any client bug that reads or writes an arbitrary path is a full compromise.
5. The forced-command entrances themselves are sound: `restrict` (plus `pty` only for the hosted shell), fixed argv, `SSH_ORIGINAL_COMMAND` passed as one `--line` argument and never to a shell (`shell/mini-shell-ssh:22-27`, `shell/render-shell-key:55-60`, `grain-host/grain-ssh:14-19`, `grain-host/render-friend-key:32-33`).
6. `candidate/run.sh` verifies the SHA-256 of **every** output named by the manifest before `init`/`serve`/`start`/`sponsor` (`candidate/lib.sh:86-100`, `run.sh:53-54,103-107`); `check-tamper.sh` proves the refusal by flipping one byte of `bin/grain-runtime` (`check-tamper.sh:28-56`). The manifest itself is unsigned: it is an operator-selected trust root, not publisher authentication (`INTERFACES.md:134-136`).
7. `package.py --capsule` can never succeed: it builds `toolchains` without a `rustc` key (`package.py:261`) and `package()` then dies in `build_identity` (`package.py:280-284,306`). A dead code path that the docs still advertise (`INTERFACES.md:12-13,181-185`).
8. `spk-host/spk-ingest-prepared` is broken against the current `spk-ingest`: it calls it with 4 arguments as root (`spk-ingest-prepared:136`), while `spk-ingest` requires `--root SPK_ROOT` plus 5 more (6 total) and refuses root (`spk-ingest:5,17`). The whole GitWeb-fixture root chain (`spk-ingest-prepared`, `spk-stage-prepared-inbox`, `spk-qualify`, `spk-install-phase`, `spk-publish-host-identity`, 601 lines) is referenced by no code.
9. `grain-host/probe_control.rs` + `probe-shell.sh` cannot compile any more: they `#[path]`-include `native/grain-runtime/src/control.rs`, which now `use serde_json` (`control.rs:6`) and has `Event` variants `InspectAttached`/`Tool` the probe's `match` does not cover (`probe_control.rs:29-42` vs `control.rs:31-37`), and `probe-shell.sh:20` compiles with bare `rustc`.
10. `grain-host/host-frontend.rs` hard-codes its own public-operation allowlist `0..=11, 17, 19` with hand-written payload shape limits (`host-frontend.rs:295-332`), a twin of `protocol/host-operations.json` routes and of `transport::public_envelope` (`native/resource-client/src/transport.rs:223-239`). Lean is still the gate for every operation (Section 3); the twin can only refuse more.
11. Rust/scripts in this tree decide **no Lean-owned semantics**; they decide physical custody (paths, modes, UIDs, unit names, cgroups), which is their job. The places that come closest: the job/story/market/MUD **laws** are authored here as data and installed through the Host (generator-checked against `Kernel/Job.lean`, `Assurance/StoryLaw.lean`, `Kernel/SealedMarket.lean`), and `shell/templates/mud/sim.py` is a hand-written Python twin of `Pred.eval` (`sim.py:58-73`).
12. The `.md` files contradict each other and the code in at least 20 places (Section 10): three different SPK broker socket paths, a root broker that `USER-TENANCY.md` says is refused, a pay price defect the root README still calls open but the code has fixed, the MUD data called "never run against a Host" while journey KC installs its sheet law on a Host, `start` waiting for a log line that `run.sh` no longer looks for.
13. Unit/binary paths disagree across units: `/usr/local/bin/mini`, `/opt/mini/bin/mini`, `/var/lib/mini/candidate/current/bin/...`, `/usr/local/lib/mini/...`, `%h/.local/libexec/...` (`checkpoint/...service:20`, `pay/mini-pay-watcher:52`, `hermes/mini-hermes.service:31`, `discord/mini-discord.service:21`, `spk-host/mini-spk-broker@.service:6`). Only `mini-clock-tick.service` and `mini-discord.service` carry real systemd sandboxing (`ProtectSystem=strict` etc.); the Store unit `run.sh unit` prints has only `NoNewPrivileges` and `PrivateTmp` (`run.sh:250-273`).
14. A minimal "small public Hetzner VM demo" needs 57 files / 7,361 lines of `deploy/` (packager, shell entrance, clock and checkpoint units, and the template files `mini`/`spk-host` compile in) plus 12 files / 2,469 lines of journey fixtures that should move out of `deploy/`; 193 files / ~14,300 lines can be deleted (Section 9).
15. The candidate builds Linux x86-64 only (`build.sh:64-67`); `launch-gate.rs` hard-codes the x86-64 value of `O_NOFOLLOW` (`launch-gate.rs:13`), which on arm64 is `O_LARGEFILE`, so an arm64 Hetzner (CAX) box would silently lose the no-follow check if anyone ever built it there.

---

## 1. What this code is and does

The tree has eleven subtrees. I describe each file; the large ones get more.

### 1.1 `deploy/candidate/` — the packager and the standalone Store operator (11 files, 2,416 lines)

**`params.sh` (59 lines).** The one place a genesis clock is chosen (`params.sh:2-3`). Two verbs:
`fill-genesis PARAMS.json` writes `.clock.genesisNow` / `.clock.maxStepSeconds` as JSON integers;
`fill-source SOURCE.json` writes `.clockGenesisNow` / `.clockMaxStepSeconds` as decimal strings
(`params.sh:5-10,25-29`). An absent/null value becomes `$GENESIS_NOW` or `date +%s`, and
`$MAX_STEP_SECONDS` or 300 (`params.sh:32-33`). One jq program refuses (exit 2, file untouched) any
present value that is not a positive integer `< 2^53`, any present value other than the one it would
write ("a genesis time is chosen once", `params.sh:41-55`), then writes through a temp file and `mv`
(`params.sh:38-39,58-59`). `chmod --reference` is GNU-only (`params.sh:58`).

**`lib.sh` (168 lines).** Sourced helpers, no top-level side effects (`lib.sh:1-2`).
- `candidate_resolve MANIFEST` (`lib.sh:32-83`): requires `type == "minidregg-candidate-manifest-v2"` and a
  nonempty `.outputs` (`:37-39`); `.candidate` must be an absolute path whose SHA-256 equals
  `.sha256.candidate` (`:40-46`); then one jq predicate binds manifest to provenance: provenance type
  `minidregg-candidate-provenance-v1`, `.outputs` byte-equal, every output key matches
  `^bin/([A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+$`, each has a 64-hex sha and a `build` record with the 40-hex
  `sourceTree`, `rustcVerbose` containing `commit-hash:`, nonempty `leanToolchain`, `cargoLockSha256` and
  rust/native flags; every `.binaries` role is an output with the same sha and the same manifest pin; and
  the 15 roles `host consent mini store verifier grainRuntime grainProviderBridge inferenceScheduler spkHost
  spkBrowserProxy spkBroker spkHostd discord payWatcher keys` must all exist (`:47-69`). It then sets
  `HOST MINI STORE VERIFIER CONSENT` from provenance-relative paths and checks the manifest names exactly
  those absolute paths (`:70-82`).
- `candidate_verify_outputs` hashes **every** output file and refuses `binary NAME sha256 mismatch:
  manifest X, file Y` (`:86-100`).
- `candidate_state` loads `state.json` (`minidregg-candidate-state-v1`) and re-resolves its manifest
  (`:104-110`); `candidate_state_bindings` requires `deployment/pinned-config.json`, compares the state's
  `hostSha256` with the current Host bytes and the config's `storageBinary`/`signatureBinary` with the
  manifest's (`:113-124`).
- `candidate_require_stopped` scans every `/proc/*/cmdline` for the config or socket path and refuses
  (`:129-138`). This is a check, not a lock (`:128`), and Linux-only.
- `candidate_build_root` / `_release` (`:153-168`): a fixed symlinked build root under flock. **Unused by the
  packager** (`build.sh` comment `:179-180`; `INTERFACES.md:105-106`); its only caller is
  `scripts/pipeline/check-reproducible`.

**`build.sh` (357 lines).** From-scratch build of the whole family from one `git archive`
(`build.sh:2-42`). Linux x86-64 only (`:64-67`). Steps: copy or create `source.tar`, read its commit with
`git get-tar-commit-id`, extract to `OUT/work/src`, hash every file into `logs/source-files.sha256`
(`:91-113`); install the pinned Rust channel and client targets, check the Lean on PATH matches
`lean-toolchain` (`:115-140`); fetch the mathlib cache into the build dir (`:147-152`); build the native
Host with `scripts/build-native-host.sh` (`:156-163`) and the consent provider as its companion
(`Host.ClientConsentSession`, `:167-176`); build every Rust role read from `package.py --rust-roles`
(`:198-206`) with `--locked`, `CARGO_INCREMENTAL=0`, path remaps (`:181-197`), checking each ELF's
`.comment` names the pinned rustc (`:193-195`); cross-build the macOS arm64 `mini` with a zig `cc` wrapper
(`:213-261`); smoke every binary's usage text and the Host cold-start budget (`:265-306`); call
`package.py --roles ... --into-existing` (`:314-343`); then re-check that provenance pins the consent pair in
`.binaries` and the Linux friend bundle and that the bundle files are byte-equal to `bin/` (`:344-355`). The
header lists 15 binaries (`:3-16`) but the build also ships the two test fixtures `mini-hermes-test-provider`
and `launch-gate` (they are in `package.py` `RUST_ROLES`, `package.py:74-78,90`).

**`package.py` (460 lines).** "The one shipping format" (`package.py:2`).
- `ROLES` maps 18 roles to file names, including the test fixtures `testProvider` and `launchGate`
  (`:57-79`); `RUST_ROLES` is "the ONE list both builders read" (`:80-90`); `REQUIRED = host consent mini
  store verifier keys` (`:95`); `ALIASES` shell→mini, hermes→grainRuntime, browserProxy→spkBrowserProxy,
  consentHost→consent (`:96`); the Linux friend bundle is five hard links (`:99-101`); `SCRIPTS` copies
  `check-tamper.sh run.sh lib.sh params.sh genesis.sh genesis-params.example.json INTERFACES.md` from the
  archive (`:103-108`).
- `roles_from_manifest` requires absolute paths and 64-hex pins that match the bytes, all `REQUIRED` roles,
  and aliases that pin the same bytes (`:197-222`).
- `capsule` validates a sealed hbox family (`seal-result.json` covers the manifest, one source commit, every
  role built at that commit) (`:225-275`), but see Section 4: it always ends in a refusal.
- `build_identity` refuses unless toolchains carry the builder's `rustc -vV` and `buildFlags.rust/native`,
  and reads the source tree id from the packaging repository (`:278-300`).
- `package` copies binaries into `bin/` (mode 0555), records each ELF's GLIBC needs via `readelf -V`
  (`:147-164`), extracts the scripts, writes `logs/source-files.sha256`, links the friend bundle
  (`:363-372`), writes `provenance.json`, `SHA256SUMS` and the v2 `manifest.json` with `outputs` for every
  file under `bin/` (`:303-413`).
- `--rust-roles` prints `ROLE CRATE BINARY` (`:425-428`). `main` refuses a roles manifest missing any built
  role, so builder drift is loud (`:447-451`).

**`lane-build.sh` (115 lines).** Incremental build in a lane clone, four steps run one at a time under
`swarm-build` (`lane-build.sh:2-18`): `host` (records `host-build.commit`, refuses a dirty tree, builds the
Host), `consent` (companion build, refuses if compiled inputs changed since the host build), `rust` (builds
every `RUST_ROLES` binary with `--offline --locked`), `pack` (refuses unless clean and no compiled input —
`.lean`, lake/cargo manifests and locks, `native/*/src/**`, `protocol/**`, the builder script — changed since
each build commit, then calls `package.py`) (`:39-49,50-115`).

**`run.sh` (285 lines).** Operates one Store from a built candidate (`run.sh:2-15`). `umask 077`; unsets the
three consent variables (`:17,25`). Verbs:
- `init` resolves and verifies the manifest, checks params with `genesis.sh --check`, refuses an existing
  state dir or a socket path ≥ 108 bytes, makes `keys public namespace tmp logs` 0700, generates the sponsor
  key (with `--no-prerotation` only when `.sponsor.nextKeyDigest` is null, else refuses) and the clock key,
  runs `genesis.sh`, `mini bootstrap`, and writes `state.json` (`:50-101`).
- `serve` (`load_state` + `exec mini serve --host --config --socket`) (`:153-158`); `start` backgrounds it with
  `nohup`, writes `public/server.pid`, waits ≤120 s for the socket **and** a log line
  `^mini: host process [0-9]+$` (`:172-194`); `stop` signals only a pid whose cmdline is
  `* serve *--socket $SOCKET*` and waits ≤60 s for it and its children (`:160-170,203-217`) — PID-file based,
  consistent with the operator's no-pattern-kill rule.
- `upgrade` rebinds a stopped Store to a new manifest: checks the pinned config hash, that no process names
  the config/socket, rewrites `storageBinary`/`signatureBinary` and `state.json` (`:110-151`).
- `sponsor` creates the sponsor workspace and imports the factory reference (`:224-248`).
- `unit` prints a systemd unit (`:250-273`) with `Type=simple`, `Restart=on-failure`, `UMask=0077`,
  `KillMode=control-group`, `NoNewPrivileges=yes`, `PrivateTmp=yes` and nothing else.

**`check-tamper.sh` (58 lines).** M7's refusal plant: copy the candidate, relocate absolute manifest paths,
flip the bit at offset 64 of `bin/grain-runtime`, and require that `run.sh init` and `run.sh serve` both fail
with the exact `binary grain-runtime sha256 mismatch: manifest X, file Y` line and that `init` created no
state (`check-tamper.sh:11-58`). Called by `scripts/kn2/plant-m7-tamper.sh` and
`scripts/kn2/plant-m7-no-verification.sh`.

**`test-package.py` (222), `test-lane-build.sh` (88), `test-params.sh` (58).** Real runs on stub binaries and
throwaway git repos: the full role set packages; missing consent, keys or a builder role (`spkBroker`) is
refused by name; a wrong commit and a bad pin refuse; null pins cannot count as membership
(`test-package.py:103-217`); lane `pack` refuses a changed compiled input, a missing consent artifact and a
dirty tree (`test-lane-build.sh:60-87`); `params.sh` refuses 0, strings, fractions, negatives, 2^53, and
re-dating (`test-params.sh:18-47`). All three are wired into `scripts/local-gates.sh` (`g_deploy-scripts`).

**`INTERFACES.md` (546 lines).** The operator contract: build inputs/outputs (`:40-106`), manifest and
provenance schema (`:108-172`), process tree (`:198-220`), the client socket and framing (`:222-280`), wire
codecs (`:282-338`), Host↔helper protocols (`:340-362`), state directory (`:364-445`), supervision
(`:447-460`), key files (`:462-488`), operator decisions (`:490-529`) and hosted composition (`:531-546`).

### 1.2 `deploy/checkpoint/` (2 files, 37 lines)

`mini-checkpoint-certify.service` is a **user** unit (`%h`, `checkpoint/...service:13-14,21`) that runs
`mini checkpoint --action certify --workspace $MINI_CHECKPOINT_WORKSPACE --control 53 --min-tail 64`
(`:20-24`); `53` is the example genesis `factoryControllerCapability`
(`native/resource-client/genesis-params.example.json`). The comment explains the tail bound: the node admits
no write more than L=256 heights past its last certified head, so if this unit stops, writes are refused
`tail-bound` (`:3-11`). The timer fires every 15 s (`.timer:8`). No hardening directives.

### 1.3 `deploy/clock/` (2 files, 66 lines)

`mini-clock-tick.service` is a **system** unit, `User=mini`, `Slice=mini.slice`, `Requires=mini-store.service`,
`ConditionPathExists=/var/lib/mini/clock/workspace.json`, running `mini clock --action tick --workspace
/var/lib/mini/clock` with `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, `ProtectHome`,
`ReadWritePaths=/var/lib/mini/clock` (`clock/...service:34-55`). The comment documents the clock subject's
key at `/var/lib/mini/clock/clock.key` and its sole `C_tick` authority, ephemeral attempts and a rotating
1 MiB journal (`:1-29`). Timer: once a minute (`.timer:6`).

### 1.4 `deploy/discord/` (5 files, 286 lines)

`mini-discord.service`: system unit, `User=mini`, `EnvironmentFile=/etc/mini/discord.env`,
`ExecStart=/usr/local/lib/mini/mini-discord`, `RuntimeDirectory=mini-discord`, `NoNewPrivileges`,
`PrivateTmp`, `ProtectSystem=strict`, `ProtectHome`, `ProtectKernelTunables`, `ProtectKernelModules`,
`ProtectControlGroups`, `RestrictSUIDSGID`, `LockPersonality`, and `ReadWritePaths=/var/lib/mini/sessions
/var/lib/mini/store/node/sponsor /var/lib/mini/store/node/public` (`discord/mini-discord.service:13-38`).
`discord.env.example` sets the application id, public key, `MINI_DISCORD_LISTEN=10.10.1.10:8793` (a private
address; "Never 0.0.0.0"), roster path, spool, the shell wrapper and the four client paths, the sessions dir
and `MINI_SPONSOR=ember` → sponsor workspace (`discord.env.example:4-20`). `discord-roster.example.json` maps
one Discord id to `ember` (`:4`). `commands.json` registers `/mini`, `/mini-help`, `/mini-world`,
`/mini-status`. `README.md` (155 lines) documents the interactions endpoint, signature check (`verify_strict`,
±300 s), roster, durable interaction custody, the Caddy front, the split-tenancy runner via `sudo -n --
/usr/local/lib/mini/mini-session-run NAME`, and the optional `mini-discord-mirror` runner.

### 1.5 `deploy/grain-host/` (48 files, 4,761 lines) — the Hermes/grain controller stack

**`bwrap` (180 lines).** Not bubblewrap: a Bash launcher named `bwrap` that the runtime treats as its worker
program. It first requires a sibling `launch-gate` answering `mini-grain-launch-gate-v1`
(`bwrap:6-20`), takes `--workspace ABS --runtime-root ABS --network none|host -- /agent/PROGRAM...`
(`:26-46`), canonicalizes both directories (`:47-49`), refuses if any controller secret
(`MINI_GRAIN_STATE_DIR`, `_CUSTODY_KEY`, `_TASK_CONFIG`, `_HOST_CONFIG`, optional `_TOOL_CUSTODY_KEY`,
`_PROVIDER_CUSTODY_KEY`, `_CREDENTIAL_BROKER`) lies inside a mount root (`/usr`, workspace, runtime root, and
with host network `/etc/ssl`, `/etc/resolv.conf`) (`:50-71`), validates the optional broker socket and the
provider socket/port (the provider socket must sit directly in the state dir and needs
`grain-provider-bridge` in the runtime root) (`:72-88`), requires `MINI_GRAIN_UNIT=mini-grain-tN-oM`
(`:89-92`), `MINI_GRAIN_RUNTIME_MAX_SEC` 1..1800, default 600 (`:93-101`), and refuses to reuse an existing
unit name (`:109-114`).

The sandbox profile, every flag (`bwrap:116-138`):

| flag | effect |
|---|---|
| `/usr/bin/bwrap` (or `/usr/local/libexec/mini-grain-bwrap` after `materialize-bwrap.py`) | the physical bubblewrap |
| `--die-with-parent` | sandbox dies with the gate |
| `--unshare-user --unshare-pid --unshare-ipc --unshare-uts --unshare-cgroup` | new user, PID, IPC, UTS, cgroup namespaces |
| `--clearenv` then `--setenv HOME /workspace --setenv PATH /usr/bin:/bin` | empty environment except HOME/PATH |
| `--ro-bind /usr /usr`, `--symlink usr/bin /bin`, `usr/lib /lib`, `usr/lib64 /lib64` | whole host `/usr` read-only |
| `--dev /dev --proc /proc --tmpfs /tmp` | minimal devtmpfs, new procfs, private tmp |
| `--ro-bind RUNTIME_ROOT /agent` | the worker program and assets, read-only |
| `--bind WORKSPACE /workspace --chdir /workspace` | the one writable host path |
| `--dir /run` + `--ro-bind BROKER /run/mini-grain.sock` and/or `--ro-bind PROVIDER /run/mini-provider.sock` | the two optional Unix sockets |
| `--unshare-net` (network none) or `--share-net` + ro `/etc/ssl`, `/etc/resolv.conf` (network host) | no network, or the full host network |
| with a provider socket: `-- /agent/grain-provider-bridge --socket ... --port P --seconds T -- PROGRAM...` | a loopback bridge inside the netns |

Not present: `--new-session`, `--cap-drop ALL` (bubblewrap drops capabilities by default for an
unprivileged caller), a seccomp filter, `--disable-userns`, any `/etc` other than ssl/resolv. The launcher
then starts a transient **user** unit `systemd-run --user --wait --pipe --collect --unit=$MINI_GRAIN_UNIT`
with `KillMode=control-group`, `RuntimeMaxSec`, `MemoryMax=2G`, `TasksMax=128`, plus `BindsTo=` the
controller for a user-manager controller, or `launch-gate check-lifetime` for a system-manager controller
(`:159-178`); its ExecStart is `launch-gate run STATE UNIT -- <sandbox argv>` (`:175-178`). A TERM/INT/HUP
trap SIGKILLs the whole unit twice (to beat a unit created after the first kill) and stops it (`:140-157`).

**`launch-gate.rs` (450 lines, std only).** The per-operation gate. `init` creates `STATE/UNIT.gate` with
`O_EXCL|O_NOFOLLOW` 0600, writes `armed\n` (or `armed\n<manager unit pid invocation start>\n` when a
controller identity is in the environment), fsyncs the file and directory (`launch-gate.rs:357-380`).
`fence` writes `fenced\n` (`:396-405`). `run` requires an absolute command, takes the gate under `flock`,
accepts only `armed`, rewrites to `started`, then either `exec`s the sandbox (legacy) or supervises it with a
pidfd on the controller (`:406-436`). `Controller::verify` checks `systemctl --MANAGER show` MainPID,
InvocationID, ActiveState=active, the process start time from `/proc/PID/stat` field 22, and same UID
(`:188-221`); `open` uses raw syscall 434 (`pidfd_open`) and verifies before and after (`:222-243`);
`supervise` sets `PR_SET_PDEATHSIG=SIGKILL` in the child, polls the pidfd every 100 ms, and on controller
exit kills/reaps the sandbox **before** taking the gate lock to write `fenced` (`:280-336`).
`check-lifetime` is called by `bwrap` for a system controller (`:381-395`). Protocol probes print
`mini-grain-launch-gate-v1` / `mini-controller-manager-v1` (`:340-347`). Built by
`native/launch-gate/Cargo.toml` (`[workspace]`, `opt-level = 3`) for the candidate, and by
`rustc -O --edition 2021` in `native/grain-runtime/hermes-journey.sh:185` and
`docs/evidence/2026-09-30-hermes-keys/run.sh:158`, and by `rustc --edition=2021 launch-gate.rs -o
launch-gate` (no `-O`) per `grain-host/README.md:41-42` and `GATE-INTEGRATION-2026-09-26.md:11`. A
prototype twin lives in `launch-gate.rs [deleted a9a68a7f]` (`scripts/overnight-tests/LAUNCH-GATE.md:3-4`).

**`resolve-bwrap` (40), `materialize-bwrap.py` (28).** `resolve-bwrap` picks the physical bubblewrap: the
AppArmor-profiled root copy `/usr/local/libexec/mini-grain-bwrap` if it can create a user namespace, else
`/usr/bin/bwrap`; `MINI_BWRAP` may select only one of those two (`resolve-bwrap:1-40`).
`materialize-bwrap.py` requires the chosen ELF be root-owned, not group/world-writable, and hash to a given
SHA-256, then rewrites the unique `/usr/bin/bwrap --die-with-parent ...` line of `bwrap` and writes the result
with `O_EXCL` (`materialize-bwrap.py:9-27`). Both are used by `native/grain-runtime/hermes-journey.sh` and
`native/resource-client/journey.d/jpay6.sh`.

**`mini-grain-controller@.service` (20).** User template: `Type=exec`,
`Environment=MINI_GRAIN_CONTROLLER_UNIT=%n`, `ExecStart=/opt/mini/bin/grain-runtime serve
/opt/mini/grains/%i.json`, `Restart=on-failure`, `UMask=0077`, `NoNewPrivileges`, `LimitCORE=0`,
`TasksMax=64`, `MemoryMax=1G` (`:7-17`). `README.md:61-64` calls it "historical"; `install-controller`
renders the same text per task.

**`install-controller` (226).** Run as the task account; checks the config is an owned 0600 file, required
paths and `systemdScope:true` commands, the state dir 0700, the control socket directly inside it, every key
file owned 0600, an existing journal bound to the same task, and a pins file of unique `{path,sha256}`
artifacts that must cover the runtime, `mini`, the Host, every `bwrap` command and its sibling `launch-gate`
(and `grain-provider-bridge` for an isolated provider) (`install-controller:56-157`); checks the unit dir is
in the live user manager's `UnitPath`, refuses an active/foreign unit, then hard-links a rendered unit into
place and `daemon-reload` (`:159-226`). Never starts or enables.

**`install-operator-stack` (591).** Run as the operator; one private `mini serve` user unit plus one
`host-frontend` unit per task UID plus optional loopback fixture providers
(`install-operator-stack:2-3,123-228`). It pins itself (`:66-71`), every binary/config by SHA-256 with
protected ancestors (`:35-58`), checks Host config helper closure (`:105-107`), cross-checks each task
controller's config/fragment through `sudo -n -u TASK` (`:232-294`), and has verbs `render install status
quiescence start restart enable guard` (`:14-18`). Every generated unit has `ExecStartPre=... guard UNIT`
(`:132,179,216`), `NoNewPrivileges`, `LimitCORE=0`, `TasksMax`, `MemoryMax`, `CPUQuota`, and **no**
`[Install]` (`enable` deliberately refuses, `:517-519`). `status` checks running UID, `/proc/PID/exe` bytes
and argv, listener ownership via `ss`, exact ACLs via `getfacl`, and that the task UID can connect to its
frontend but not the private socket (`:391-449`). `restart` requires a pinned `signedCheck.binary` whose
decimal content root must be unchanged across the Host restart (`:561-591`). It reads task journals' fields
(`connection`, `child`, `pending`, `toolPending`, `providerPending`, holds, `unresolvedExternal`) directly
(`:466-474`).

**`host-frontend.rs` (616) and `host-frontend-probe.rs` (67).** An operator-owned per-task Unix-socket relay
(`host-frontend.rs:1-3`). Linux-only (`:4-5`). It refuses a task UID that is 0 or the operator's (`:396-398`),
requires private/public dirs owned and 0700, the public dir to hold only `host.json`/`host.sock`/`host.lock`
(`:399-434`), the public config to be byte-identical to the private socket's `.config` sidecar and not
hard-linked (`:451-469`), resets and sets ACLs with `/usr/bin/setfacl` (`:470-473,495`), takes an exclusive
non-blocking flock (`:150-179`), removes a stale socket only after `ConnectionRefused` and an inode recheck
(`:181-200`), and then serves connections **serially** (`:501-512`), checking `SO_PEERCRED` uid equals the
task UID (`:50-65,503-510`). `pinned_v2` admits only envelope version 2 with the exact config bytes and Host
SHA-256, and operations `0..=11`, `17` (with a call-length/≤1024-trailer shape) and `19` (metadata ≤4096,
request ≤1 MiB, response ≤8 MiB) (`:285-337`); refused frames get `254` + reason (`:356-365`). Relay: 10 s to
read a request, 10 s to write it, 600 s for the reply, no retry (`:339-386`). Two unit tests (`:556-616`).
The probe sends op 255 and a 1-byte slow prefix and expects the 254 refusal / deadline close
(`host-frontend-probe.rs:1-63`). Neither file is compiled by any build script or crate; the README says to
`rustc` it by hand (`HOST-FRONTEND.md:9-10`).

**`grain-ssh` (19), `render-friend-key` (33).** The friend's forced command: two absolute paths and an
optional `hard|soft`; ignores `SSH_ORIGINAL_COMMAND`; `exec grain-runtime connect SOCKET MODE`
(`grain-ssh:1-19`). `render-friend-key` checks the paths, a live socket and one ssh-ed25519 key, then prints
`restrict,command="WRAPPER RUNTIME SOCKET MODE" ssh-ed25519 ...` (`render-friend-key:14-33`).

**`check-hosted-pair` (133), `render-hosted-pair` (120).** Single-account two-controller path preflight:
distinct task ids/subjects, state, cwd, custody files, worker mounts; no secret visible in any mount
(`check-hosted-pair:32-133`). `render-hosted-pair` copies two base configs, writes command overlays
(`hermes-acp` with **`--network host`**, `render-hosted-pair:97-99`), pins, runs `check-hosted-pair` and
`install-controller --render-only` (`:69-120`).

**`offer-*` (5 scripts, 763 lines) + `OFFER-PAIR.md`.** The two-account "fixed workroom profile"
(`mini-hosted-workroom-780x-v1`): tasks 7801/7802/7803/7804, subjects 7..10, content 8001, capabilities
71/73/95-98/111/113 hard-coded (`offer-check-authority:29-33`, `offer-render-task:143-149`,
`offer-check-provision:108-146`). `offer-check-provision` asks the pinned Host to `inspect` every retained
`outcome.bin`/`view.bin` and compares the canonical JSON with the saved JSON
(`offer-check-provision:98-107,157-208`); it also pins `scripts/workroom/provision.sh` to one literal SHA-256
(`:64-66`). `offer-render-task` renders one controller with **`--network host`** (`offer-render-task:192-194`).
`offer-check-authority` performs five fresh signed queries through the task's frontend and requires the
fresh-grain views (`offer-check-authority:53-104`). `offer-check-pair` cross-checks both accounts' handoffs
(`offer-check-pair:24-120`). `offer-render-entry` checks the installed unit, the live controller's exe bytes
and argv, then prints the friend key line via `render-friend-key` (`offer-render-entry:42-109`).

**Probes:** `probe.sh` (159) containment probe with `probe_socket.rs` (30, ping/pong helper);
`probe-shell.sh` (69) with `probe_control.rs` (44) (broken, Section 4); `probe-hermes-acp.sh` (73) upstream
Hermes ACP init in a no-network worker; `probe-controller-lifetime.py` (82) system-controller/user-worker
lifetime receiving using `sudo -n systemd-run` (`probe-controller-lifetime.py:54`).

**Contract docs:** `README.md` (175), `HOST-FRONTEND.md` (61), `OPERATOR-STACK.md` (67), `OFFER-PAIR.md` (129),
`HOSTED-PAIR.md` (38), `FRIEND-GRAINS.md` (30). **Dated notes:** `CONTROL-SSH`, `CONTROLLER-CRASH`,
`GATE-INTEGRATION`, `HERMES-GATED-INIT`, `HERMES-LINUX`, `INSTALL-CONTROLLER`, `OWNER-DEMO`, `PROBE`,
`SSH-LIVE` (all 2026-09-26), `CONTROLLER-LIFETIME-2026-10-02.md`, with 8 `.log` files (Section 1.10). They are
evidence and belong under `docs/evidence/`.

### 1.6 `deploy/hermes/` (2 files, 246 lines)

`mini-hermes.service`: system unit, `User=mini`, `Requires=mini-store.service`, four
`ConditionPathExists` (`/etc/mini/providers.json`, `/etc/mini/keys-client.json`, the candidate's
`grain-runtime`, `/var/lib/mini/hermes/controller.json`), `ExecStart=/var/lib/mini/candidate/current/bin/
grain-runtime serve /var/lib/mini/hermes/controller.json`, `Restart=on-failure`, `KillMode=control-group`,
`PrivateTmp`, `ProtectSystem=strict`, `ProtectHome`, `ReadWritePaths=/var/lib/mini/hermes
/var/lib/mini/store/node/public`, `ProtectKernelTunables/Modules`, `RestrictSUIDSGID`, `LockPersonality`; no
`NoNewPrivileges` (`hermes/mini-hermes.service:15-48`). `README.md` documents the provider table
(`mini-provider-table-v2`, routes `user`/`pool`/`homelab`), the key broker custody, the friend's `key set/
grant/ls/revoke`, and the per-route tariff. Note `hermes_catalogue_probe.rs [deleted 708a07fd]:31`
references `deploy/hermes/runtime-inputs/probe-catalogue.py`, which does not exist (the test is `#[ignore]`).

### 1.7 `deploy/hermes-dispatch/` (4 files, 339 lines)

`mini-hermes-dispatch.py` (105): a pump that reads a trusted service config
(`mini-hermes-dispatch-service-v1`: `mini`, `socket`, `registrationsDir`, `memberHomes`) and trusted
registrations (`O_NOFOLLOW`, root/self-owned, not group/world-writable, ≤4 MiB, duplicate-key-refusing JSON)
(`:8-43`), round-robins member homes for `outbox/*/room-*/assignment-*/{handoff,dismissal}.json` hints
(`:45-67`), and runs `mini hermes-handoff --action dispatch --registration R --bundle B` with 4 workers and a
60 s timeout (`:69-98`). Bounded caches (`:79-94`). `test_dispatch.py` (23): pagination, malformed-hint
isolation, duplicate-key refusal. `receiving.py` (85) is a **journey** that bootstraps a fresh Store and
exercises the pump; it is not deployment code. `README.md` (126) is the contract. No systemd unit is in the
repo ("SYSTEM unit installation ... belong to the service installer", `README.md:89-90`).

### 1.8 `deploy/pay/` (7 files, 911 lines)

`mini-pay-watcher` (128, POSIX sh): one tick — `mini pay watch-config` from the signed pay view (op 107),
`pay-watcher` writes observations to `STATE/tick`, `mini pay observe` submits one report, then
`pay-watcher --ack-tick`; while observe prints `enrol-pending`, repeat up to `PAY_ENROL_ROUNDS` (default 8)
until the tip stops moving (`mini-pay-watcher:1-128`). Locks `$PAY_STATE/.service.lock` with `flock -n`
(`:62-63`). `mini-pay-watcher.service`: system oneshot, `User=mini`, two EnvironmentFiles
(`/etc/mini/pay/watcher.env`, `/etc/mini/pay/rpc.env`), `ExecStart=/opt/mini/bin/mini-pay-watcher`,
`StateDirectory=mini/pay`, `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`,
`ReadWritePaths=/var/lib/mini`, `ProtectHome`, `LimitCORE=0`, `TasksMax=32`, `MemoryMax=512M`
(`pay/mini-pay-watcher.service:6-25`); timer every 60 s after the previous run (`.timer:4-8`).
`enrol-terms.json`: the enrollment address `5N2uUG4TEwvM4acjWRpZ981CJa4p5e9RcuAYQvuUZLp6`, mint
`XkeTXo1125vz5H9svJpGiw4JvLbN8VmMu9cmMvspump`, Token-2022 program, 6 decimals, `weekPriceAtomic 50000000`,
operator socket path and login `mini@2.28.141.27` (`enrol-terms.json:3-15`). `render-enrol` (235, Python
stdlib) renders `book.json`, `tariff-on.json`, `enrol.json`, `enrol-v2.json`, `watcher.env`, `report.txt`
from the terms, validates canonical base58 for 32-byte keys, computes `nodeWeekRate = weekPriceAtomic ×
creditPerAtomic` exactly, and `--verify-tariff` refuses any `nodeHourRate` (`render-enrol:97-124,127-195`).
`test-render-enrol.py` (197) pins those integers. `README.md` (299) is the operator procedure.

### 1.9 `deploy/shell/` (144 files, 11,937 lines)

**Entrance scripts.**
- `mini-shell-ssh` (27): six absolute paths; `umask 077`; with `SSH_ORIGINAL_COMMAND`, `exec mini shell ...
  --line "$SSH_ORIGINAL_COMMAND"`, else interactive `mini shell` (`mini-shell-ssh:12-27`).
- `mini-shell-ssh-credentials` (23): only when installed at `FRAME/usr/local/lib/mini/` (checks `$0`,
  `:14`); `SSH_ORIGINAL_COMMAND == mini-provider-credentials-v1` relays bytes to `mini-keys relay
  --client-config FRAME/etc/mini/keys-client.json` (`:18-22`); otherwise execs `mini-shell-ssh`.
- `mini-socket-proxy` (35): proxy mode; the credential command relays to `mini-keys relay`; any other command
  exits 64; no command runs `mini socket-proxy --socket PUBLIC` (`mini-socket-proxy:15-35`), which filters each
  frame with `transport::public_envelope` (`native/resource-client/src/proxy.rs:58-69`).
- `render-shell-key` (60): `mode=shell` prints `restrict,pty,command="WRAPPER MINI HOST CONFIG SOCKET WORKSPACE
  HOME" ssh-ed25519 ...`; `mode=proxy` prints `restrict,command="PROXY MINI SOCKET" ...`; paths must match
  `^/[A-Za-z0-9_./-]+$` without `..`; one ssh-ed25519 key, validated by `ssh-keygen -lf`
  (`render-shell-key:16-60`).
- `motd.txt` (11): "your signing key lives on this box, and root can read it."

**Docs.** `README.md` (163) two modes and their custody table, the friend's three proxy commands, the
consent variables, binding a key to a session, endings; `OPERATOR.md` (134) the per-friend checklist for the
live box `dregg-workhorse` / `2.28.141.27`; `FRIENDS.md` (620) the friends' guide, with a node-vs-main table;
`DOC-VERBS.md` (79) the `doc` verb table and rendering notation.

**`templates/` (135 files, 10,785 lines).** Data the `mini` client reads or compiles in:

| subtree | files / lines | consumer |
|---|---|---|
| `room/` workroom, social(+member), story `template.shell`; `chat/law.author.json`; `private/law.{keys,room}.json`; READMEs | 10 / 291 | compiled into `mini` (`native/resource-client/src/shell/template.rs:28-38`, `chat.rs:137`, `roomkey.rs:133-135`) |
| `story/tale/table` (+ generated `law.player`, `law.player.json`, `law.table.json`, README) | 5 / 420 | `table` compiled into `mini` (`story.rs:65`); law files generated by `scripts/gen-storylaw.py`, proved equal in `Assurance/StoryLaw.lean` (`story/README.md:54-60`) |
| `hermes/{librarian,runner,gm}/` + README | 13 / 301 | librarian `grants/program/budget` and runner `grants/budget` compiled into `mini` (`hermes.rs:44-48`); `gm/*` (4 files, 81 lines) compiled by nothing (`summon … as gm` refuses, `hermes/gm/README.md:3-7`) |
| `job/` `law.job` (source), `law.job.json` (45 clauses), `law.job.shell`, `fields.json`, `programs/{collatz,liar}.hoon` + `.jam.provenance` | 9 / 2,283 | `law.job.json` and `law.job.shell` compiled into `mini` (`job.rs:34-36`); generated by `scripts/gen-joblaw.py` with `Kernel/Job.lean` §2 (`job/README.md:12-14`); `.hoon` are the sources of the jams `journey.d/jjob.sh`/`jjob1.sh` take from `JOB_PROGRAMS` (no `.jam` is in the repo) |
| `market/sealed/law.market` + `fields.json` | 2 / 79 | `law.market` compiled into `mini` (`market.rs:36`); rendered by `scripts/SealedMarketTemplate.lean` from `Kernel/SealedMarket.lean` (`market/sealed/law.market:2`) |
| `mud/` (realm `tidewrack`, refusal fixture `tidewrack-broken`, sheet/room/item/quest/org/market laws, `programs/*.hoon`, `render.py`, `sim.py`, `validate.py`, `tariff.json`, `affliction-table.json`) | 95 / 7,312 | no Rust consumer; `journey.d/jclock.sh:340-362` installs `law.management.json` + `sheet/law.sheet.json` + `sheet/init.sheet.json` with `tidewrack/realm.json` constants on a fresh Host; everything else is unshipped design data ("Nothing here was built, installed or run against a Host", `mud/README.md:3-5`) |

`mud/render.py` (129) is the grammar-to-`Pred`-JSON renderer (also used by `scripts/gen-joblaw.py`);
`mud/sim.py` (433) re-implements `Pred.eval` in Python with a projection model and asserts ~90 J-MUD rows
(`sim.py:1-17,58-73,77-90`); `mud/validate.py` (107) validates area graphs (dangling exits, unreachable rooms,
unplaced keys, constants vs. the affliction table). The four MUD Hoon programs are "TEXT, NOT COMPILED"
(`mud/programs/README.md:1-6`).

### 1.10 `deploy/spk-host/` (37 files, 3,152 lines)

**Units/config.** `mini-spk-broker@.service`: user template, `ExecStart=%h/.local/libexec/mini-spk-broker
serve /var/lib/mini-spk-worlds/%i/broker/config.json`, `Restart=on-failure`, `UMask=0077`,
**`NoNewPrivileges=no`** (`:5-12`), because the broker uses `sudo` and the uid-mapping helpers (`:10-11`).
`mini-spk-broker.example.json` (`mini-spk-broker-config-v3`): store, grains/spk roots, broker socket,
`operatorUser: ember`, `spk-host`/`bwrap`/ingest/volume helper paths with SHA pins, `appUids` 165536-165539
(`:2-16`).

**Scripts.**
- `install-user-world` (166, root): requires root-owned `newuidmap`/`newgidmap`; `install` validates store
  (16 hex), helper path (`/usr/local/libexec/mini-spk-volume-helper[-16hex]`), subuid/subgid range ownership
  and non-collision, installs the helper root 0755, creates `/var/lib/mini-spk-worlds/STORE/{attest,volumes,
  volume-custody,vars,broker,STORE,runtime-STORE,spk/{packages,inbox}}`, grants `r-x` ACLs on the profiled
  bwrap to the operator and each app uid, writes `host-identity` and a registry
  `/etc/mini-spk-volumes/STORE.json`, and installs `/etc/sudoers.d/mini-spk-STORE` =
  `#UID ALL=(root) NOPASSWD: HELPER` after `visudo -cf` (`install-user-world:13-166`); `remove` reverses it
  and refuses while mounted (`:51-86`). Used by `scripts/spk-platform/two-world-journey.sh:36` and
  `scripts/pipeline/journey-rows:495-502`.
- `spk-var-volume` (325, root): provisions/attests a per-app ext4 loop `/var`: refuses non-root-owned or
  writable ancestors (`:90-99`), reads a 2-line host identity under inode-stable checks (`:109-125`), creates
  an image with `fallocate`+`mkfs.ext4`, mounts `loop,nosuid,nodev,noatime`, chowns to the app uid
  (`:157-202`); `create-from` copies an untrusted image's tree with `debugfs rdump` run as the app uid via
  `setpriv --reuid --regid --clear-groups --no-new-privs --inh-caps=-all --bounding-set=-all` after `blkid -p`
  and `e2fsck -fn`, never mounting the bytes (`:49-58,203-224`); `attest` publishes a
  `DREGG/SPK-VAR-CUSTODY/v1` witness re-collected three times around publication (`:264-324`). **Compiled into
  `mini-spk-volume-helper`**: `native/spk-host/src/volume_helper.rs:219` runs
  `include_str!("../../../deploy/spk-host/spk-var-volume")` via `/bin/bash -c`.
- `spk-ingest` (44, operator, not root): validates the per-store `.../STORE16HEX/spk` root, the inbox file
  (owner, 0600, ≤256 MiB), the Host pin, dir custody, takes a flock, runs `spk-host materialize` in a
  transient **user** unit (`NoNewPrivileges`, `MemoryMax=2G`, `MemorySwapMax=0`, `CPUQuota=100%`,
  `TasksMax=16`, `RuntimeMaxSec=120`, `LimitFSIZE=256MiB`), then requires the published image to have no
  writable, setuid/setgid or special nodes (`spk-ingest:5-44`). A fixture twin is
  `native/spk-host/tests/fixture-os/spk-ingest`.
- `spk-ingest-prepared` (149, root), `spk-stage-prepared-inbox` (124, root), `spk-qualify` (109, root),
  `spk-install-phase` (105, root), `spk-publish-host-identity` (65, root): a GitWeb-only fixture chain rooted at
  `/var/lib/minidregg/spk` with the GitWeb SPK SHA `2bbfe6d3...` and its manifest/bridge hashes hard-coded
  (`spk-ingest-prepared:36-38,101-109`, `spk-stage-prepared-inbox:26,48,68`). Each runs one transient
  **system** unit with `User=root` or the operator, `NoNewPrivileges`, `PrivateNetwork`, `PrivateTmp`,
  `ProtectSystem=strict`, memory/CPU/task/runtime/file-size limits, and parses `systemd-run`'s own stderr
  lines as success evidence (`spk-qualify:78-91`, `spk-install-phase:80-104`, `spk-ingest-prepared:87-99`).
  None is referenced by code (`git grep` finds only docs).
- `tests/` (3 scripts, 88 lines): `eval` the exact production function out of the script with `sed` and test it
  (`deploy/spk-host/tests/ingest-prepared-custody.sh:7`, `stage-inbox-recovery.sh:7`, `var-volume-import-untrusted.sh:14`);
  gated by `scripts/check-spk-shell-tests.sh`.

**Docs.** Contracts: `README.md` (244), `USER-TENANCY.md` (53), `BROKER-RUNTIME-UPGRADE.md` (117),
`BROWSER-WEBSOCKETS.md` (44), `HOT-ROUTE-ENROLLMENT.md` (139), `HTTP-CUSTODIAN-CONTRACT.md` (104),
`MINI-CLAIM-DISPATCH-CONTRACT.md` (105), `PROFILE-UPGRADE.md` (55), `SAME-STORE-AND-CHECKPOINT.md` (270),
`STREAM-CONTINUITY.md` (95), `WS-AUTHORITY-LEASES.md` (85). Dated probe notes: `GITWEB-CACHE-CAPACITY`,
`GITWEB-SESSION-PROBE`, `GITWEB-SMOKE`, `HOST-WIRE-STAGING-CHECK`, `HOSTD-ADAPTER-PROBE`, `HOSTD-PROBE`,
`HTTP-ENTRANCE-CHECK`, `PRIVATE-BROWSER-BOOTSTRAP`, `SMOKE`, `SPAWN-GATE-PROBE` (2026-09-27) and
`INGEST-2026-09-26.md`, with two `.log` files.

### 1.11 The `.log` files (first 40 lines of each)

| log | run it documents |
|---|---|
| `grain-host/CONTROL-SSH-2026-09-26.log` (16) | `probe_control` event log: hard attach 1 → `hard-interrupt:1`, soft attaches 2 and 3, each with a `status` line |
| `grain-host/CONTROLLER-CRASH-2026-09-26.log` (55) | persvati task 7401: binary SHA list (Host bbf, `mini`, `grain-runtime 8126b343...`, store, verifier, bwrap, gate), SIGKILL of the controller, worker unit inactive via `BindsTo`, gate `started`, durable child marker retained |
| `grain-host/GATE-INTEGRATION-2026-09-26.log` (11) | `probe.sh` PASS lines: gate protocol, broker socket bind, `/usr` and workspace exposure refusals, wrapper TERM and `BindsTo` stopping 4 setsid PIDs |
| `grain-host/GATE-RUNTIME-MAX-2026-09-26.log` (12) | the same probe plus `MINI_GRAIN_RUNTIME_MAX_SEC` refusal and the 47 s `RuntimeMaxUSec` (no `.md` companion) |
| `grain-host/HERMES-GATED-INIT-2026-09-26.log` (15) | upstream Hermes 0.21.3 `hermes-acp --check` and ACP `initialize` in a no-network worker unit; unit inactive after stop |
| `grain-host/HERMES-LINUX-2026-09-26.log` (15) | an earlier run of the same probe |
| `grain-host/PROBE-2026-09-26.log` (9) | the first containment probe (broker socket, `/usr` and workspace refusals, TERM and `BindsTo` stops) |
| `grain-host/SSH-LIVE-2026-09-26.log` (108) | persvati private loopback sshd: SHA list for Host combined31a, `mini`, `grain-runtime 903e7ab5...`, fixtures; signed bootstrap read; soft SSH `run short` → gate fenced, generation 1 remaining 99 |
| `spk-host/HTTP-ENTRANCE-CHECK-2026-09-27.log` (18) | `cargo nextest -E 'test(http_entrance)'` 6/6 PASS and clippy, on a persvati source copy |
| `spk-host/PRIVATE-BROWSER-BOOTSTRAP-2026-09-27.log` (39) | source hashes, 8/8 http_entrance tests, release ELF hashes, five transient units, bootstrap form GET 200 / POST 303 / replay refused / GitWeb GET 503 |

## 2. What it assumes of its surroundings

### 2.1 Host protocol operations used

Nothing in `deploy/` frames Host operations directly except `host-frontend.rs` (it relays, and filters by
operation byte) and `host-frontend-probe.rs` (sends op 255 to be refused). All other Host traffic goes
through the `mini` client (`mini shell`, `mini pay`, `mini clock`, `mini checkpoint`, `mini query`,
`mini author`, `mini hermes-handoff`, `mini socket-proxy`) or `minidregg-host CONFIG inspect` (pure codec,
`offer-check-provision:101-102`).

Cross-check of `host-frontend.rs`'s allowlist against `protocol/host-operations.json`:

| byte | registry symbol / routes / receiver | frontend | agreement |
|---|---|---|---|
| 0-11 | DESCRIBE, AUTHORIZED_PREPARE, SUBMIT, LOOKUP, OBSERVATION_CHALLENGE, AUTHORIZED_QUERY, PROFILE, AUTHOR, INSPECT, SIGNATURES, OBSERVATION_ASSEMBLE, CALL_ASSEMBLE; public+operator; `dispatchSession` / `fnDispatch` (2, 3) | allowed, no payload shape check (`host-frontend.rs:296`) | subset of public; Lean decodes |
| 12-16, 18 | FN_POLL, FN_ACK, FN_REPLY_POLL, FN_REPLY_ACK, FN_ORIGIN_OUTBOX, FN_ORIGIN_OUTBOX_EXPORT; public+operator; `fnDispatch` | refused (`:331`, tests `:590-593`) | stricter than registry, by design (`HOST-FRONTEND.md:43-45`) |
| 17 | PROVIDER_CONTINUITY; public+operator; `fnDispatch` → `runProviderContinuitySession` (`Host/Main.lean:6718-6724`) | allowed if payload = `u32 LE call_length` + call (>0) + trailer ≤ 1024 (`:297-306`) | Lean is the gate (refuses `operationRejected "provider-continuity"` when unconfigured); whether the Rust shape equals what `runProviderContinuitySession` decodes is Q8.1 |
| 19 | PROVIDER_USAGE_QUOTE; public+operator; `fnDispatch` → `ProviderUsage.quotePayload` (`Host/Main.lean:6744-6754`) | allowed if `u32 meta (1..4096)` + meta + `u32 req (1..1 MiB)` + req + response ≤ 8 MiB (`:307-330`) | Lean is the gate; shape agreement is Q8.2 |
| 20-21, 28-31 and every other public byte | public routes in the registry | refused | stricter |
| 255 | response marker, request reserved | refused (`:594`) | agrees |
| 254 reply | "Transport refusal: request never forwarded" | the frontend's own refusal uses 254 + UTF-8 (`:357`) | agrees with `response_markers` |

Error/response markers: the frontend forwards the private socket's reply bytes unchanged (`:373-385`), so
255/254 semantics are the Host's and `mini serve`'s.

Operations that docs in this tree name and that a Lean reader should confirm: ops 117-120 (self-enrollment,
operator socket only, `pay/README.md:136-149`), 107/111/112/121 (pay view, exact lookup, enrollment view,
quote; `pay/mini-pay-watcher:4-5`, `pay/README.md:182-203,213-215`, `render-enrol:25`), 152 (stream
continuity, operator-only, `spk-host/STREAM-CONTINUITY.md:13`), 164/34/36 (route-bound dispatch, ordinary
dispatch, unsigned authoring, `HOT-ROUTE-ENROLLMENT.md:101-116`), 160-163 (job money, `job/README.md:21`),
206-209 (failed-start recovery, `spk-host/README.md:113-119`), 26/27 (lifecycle claim,
`HOST-WIRE-STAGING-CHECK-2026-09-27.md:4-5`). None of these is framed by code in `deploy/`.

### 2.2 OS facilities

Linux-only throughout: `/proc/*/cmdline` (`lib.sh:130`), `/proc/PID/stat` start time (`launch-gate.rs:245-251`),
`pidfd_open` syscall 434 (`launch-gate.rs:224-230`), `PR_SET_PDEATHSIG` (`:286-292`), `SO_PEERCRED`
(`host-frontend.rs:50-65`), POSIX ACLs via `/usr/bin/setfacl`/`getfacl` (`host-frontend.rs:95-136`,
`install-operator-stack:421-429`, `install-user-world:31,142-148`), cgroup v2 with memory/pids/cpu delegation
to the user manager (`USER-TENANCY.md:3-4`; `bwrap:159-162`), **systemd user managers with linger** for every
task/operator account (`grain-host/README.md:160`, `OPERATOR-STACK.md:65`), unprivileged user namespaces or the
AppArmor-profiled `mini-grain-bwrap` (`resolve-bwrap:4-12`), bubblewrap ≥ a version with `--disable-userns`
and `--userns-block-fd` (`USER-TENANCY.md:6-7`), `newuidmap`/`newgidmap` and `/etc/subuid`
(`install-user-world:8-12,94-96`), loop devices, `mkfs.ext4`, `debugfs`, `e2fsck`, `blkid`, `losetup`,
`findmnt`, `fsfreeze`-style freezing (`spk-var-volume`, `spk-host/README.md:132-136`), optional ZFS
(`spk-var-volume:286-292`), `sudo` with `NOPASSWD` rules (`install-user-world:158-162`,
`install-operator-stack:265-272`), GNU coreutils (`chmod --reference`, `cp --reflink`, `stat -c`,
`realpath -e/-m`), `jq`, `flock`, `ss`, `nc -U`, `readelf`, `sha256sum`, `ssh-keygen`, Python 3, `zig` for the
macOS client, `elan`/`lake`, `rustup`. glibc version floor from `provenance.json .abi.glibcRequired`
(`package.py:147-164`). The candidate is x86-64 only (`build.sh:64-67`).

### 2.3 Network services

- Solana JSON-RPC (≥2 providers, URLs with API keys in `/etc/mini/pay/rpc.env`, `pay/README.md:113-119`).
- Discord interactions (inbound HTTPS via Caddy on the anchor `discord.dregg.net` → `10.10.1.10:8793`;
  outbound `PATCH /webhooks/...` with curl) (`discord/README.md:11-24,86-94`).
- OpenAI-compatible providers (OpenRouter, a tailnet homelab) via the key broker (`hermes/README.md:70-96`).
- fn/NNTP: mentioned only as an operator stage and an image pin (`OFFER-PAIR.md:119`, `INTERFACES.md:492`).
- Build-time: elan release server, Lean package git URLs, the mathlib artifact cache, rustup dist, crates.io,
  GitHub (`INTERFACES.md:54-62`; `spk-host/INGEST-2026-09-26.md:7-9` Bread `sandstorm-package` from
  `github.com/emberian/dregg.git`).

### 2.4 File layouts the docs assume on the box

`/var/lib/mini/candidate/current/bin/*` (candidate), `/var/lib/mini/store/node/{deployment,public,operator,
sponsor,tmp}` (Store), `/var/lib/mini/sessions/NAME/{keys,workspace,home,requests,provision,refusals,...}`
(friends), `/var/lib/mini/clock`, `/var/lib/mini/pay/{observer,tick}`, `/var/lib/mini/hermes/controller.json`,
`/var/lib/mini/credentials` (sealed provider keys), `/var/lib/mini-backups` (nightly, include the sponsor
secret key, `shell/OPERATOR.md:116-118`), `/etc/mini/{discord.env,discord-roster.json,providers.json,
keys-client.json,credentials.key,pay/*,ingress.json,tenancy,hermes-residents.json,
hermes-dispatch-service.json}`, `/usr/local/lib/mini/{mini-shell-ssh,mini-discord,mini-health,mini-restore-check,
mini-session-run}`, and for SPK three different roots (Section 10).

### 2.5 Other crates

Binaries from `native/resource-client` (`mini`), `hyperdocument-link-sqlite-store`,
`credential-signature-verifier`, `grain-runtime` (`grain-runtime`, `grain-provider-bridge`),
`inference-scheduler`, `spk-host` (5 binaries), `discord-entrance`, `pay-watcher`, `mini-keys`,
`hermes-test-provider`, `launch-gate` (`package.py:83-90`). Compile-time inbound dependencies **from**
crates **into** this tree: `native/resource-client/src/{story,hermes,job,shell/template,roomkey,chat,
market}.rs` (`include_str!` of 15 template files), `native/spk-host/src/volume_helper.rs:219`
(`spk-var-volume`), `native/launch-gate/Cargo.toml:15` (`launch-gate.rs`). Deleting those files breaks the
client and spk-host builds.

## 3. Does it decide anything semantic?

The design test is whether anything here decides authority, balances, retry/replay semantics, identity,
ordering, receipt validity, signature acceptance, tariffs or quotas that a Lean admission should own.

**Correctly deferred (physical custody, the Rust/infra job):**
- `run.sh`/`lib.sh` decide which binary bytes may run, from an operator-selected manifest
  (`lib.sh:32-100`). Not semantic.
- `bwrap`/`launch-gate.rs` decide unit names, mounts, network, lifetimes and the one-shot
  `armed → started → fenced` launch state (`launch-gate.rs:356-436`). This is a physical replay guard for a
  process launch; the Mini reservation/settlement is the runtime's and the Host's (`grain-host/README.md:45-56`).
- `host-frontend.rs` decides which UID may connect and which operation bytes reach the private socket
  (`:285-337,503-510`). It is a **mirror that can only refuse more**: every allowed operation is still
  decoded and admitted by `dispatchSession`/`fnDispatch` (`Host/Main.lean:6718-6754`); a frontend bug that
  allowed op 12 would reach a Lean receiver that checks fn service configuration and signed authority. Not a
  law violation, but a twin (Section 5).
- `mini-shell-ssh`, `grain-ssh`, `mini-socket-proxy` choose no authority; the workspace/key are fixed by the
  authorized_keys line (`render-shell-key:55-60`).
- `mini-pay-watcher` decides only when to tick and how many rounds (`:68-127`); credit, enrol/renew/journal
  are the Host's (`pay/README.md:206-214`: "The client decides nothing").
- `render-enrol` computes `nodeWeekRate` from the operator's terms (`render-enrol:97-103`) and writes the
  tariff **proposal** the factory controller installs with `mini pay book`; the Host's tariff codec and
  `Kernel/PayTariff.lean` own validity, and the friend sees the Host's op-121 quote, never this number
  (`render-enrol:24-25`). Mirrors for UX.
- `mini-hermes-dispatch.py` treats files as hints; `mini hermes-handoff` and the Host admit (`:2`, `README.md:41-48`).
- `install-operator-stack` reads task journal fields to decide "quiescent" before a restart (`:466-474`)
  and compares a signed content root across restart (`:568-584`). An operational safety interlock, not
  admission.

**Closest to the line (worth naming):**
1. **Laws authored as data in `deploy/`.** `job/law.job` (45 clauses, the whole job lifecycle and its money
   edges), `story/tale/law.player*`, `market/sealed/law.market`, `room/chat/law.author.json`,
   `room/private/law.keys.json`, and the MUD laws. These ARE semantics (who may write which field when), but
   they are installed as `Pred` predicates that the Host evaluates; the Host is the gate. The job, story and
   market laws are generator-checked against Lean (`job/README.md:12-14`; `story/README.md:54-60`;
   `law.market:2`). `room/chat/law.author.json` and `room/private/law.keys.json` are not generated; they are
   hand-written JSON compiled into `mini` (`chat.rs:137`, `roomkey.rs:133`), and `Kernel/PrivateRoomKeys.lean`
   mentions the keys law (Q8.4). Blast radius if a hand law is wrong: the room/keys cell admits writes it
   should not (author impersonation in a chat stream; a non-founder appending to the keys cell).
2. **`mud/sim.py` re-implements `Pred.eval`** (`sim.py:58-73`) and the projection (`:77-90`). It decides
   nothing at runtime (no consumer), but it is a hand twin of `Pred/Core.lean` used to "prove" law rows.
   Delete with the MUD data.
3. **`host-frontend.rs` payload shape limits for ops 17 and 19** (`:297-330`) are numbers (1024, 4096,
   1 MiB, 8 MiB) chosen in Rust. If Lean accepts larger payloads, the frontend silently narrows the protocol
   for task accounts; if Lean's layout differs, every op 17/19 from a task account is refused at the frontend
   (fail-closed, loud 254). Not a law violation; a drift risk.
4. **`offer-*` hard-code identities** (tasks 7801-7804, subjects 7-10, capabilities 71/73/95-98/111/113,
   content 8001) and check views against literal values (`offer-check-authority:72-84`,
   `offer-check-provision:108-146`). Read-only preflights; Mini still admits. They make the scripts a
   one-fixture tool.
5. **`spk-ingest` and `spk-var-volume` decide physical package acceptance** (no setuid/special nodes;
   ext4-only import) (`spk-ingest:36-40`, `spk-var-volume:49-58`). Physical; correct place.

**Violations of "Rust/infra decides nothing semantic": none found in `deploy/`.**

## 4. Flaws noticed

Each with the exact line and a concrete failure.

**4.1 `package.py --capsule` always refuses (dead path).** `capsule()` returns
`toolchains = {"recorded": "capsule", "rustBuild": None, "nativeHostManifest": None}` plus maybe `lean`
(`package.py:261-270`); `package()` immediately calls `build_identity(archive, commit, toolchains)`
(`:306`), which dies `build provenance requires the builder's rustc -vV` when `toolchains["rustc"]` is
absent (`:280-284`). So every `package.py --capsule FAMILY --out DIR` exits 1 after validating the seal.
`INTERFACES.md:129` admits "Sealed capsules without this evidence refuse", but `:12-13,181-185` and the module
docstring (`package.py:6,26-34`) still present it as one of three routes.

**4.2 `spk-ingest-prepared` cannot run its ingest.** It calls `"$helper_dir/spk-ingest" "$host" "$host_sha"
"$inbox" "$uid"` (4 args, as root, `spk-ingest-prepared:7,136`). `spk-ingest` requires exactly 6 args
starting with `--root` (`spk-ingest:5`), a root path ending `/spk` under a 16-hex store dir (`:7-12`), and
refuses EUID 0 (`:17`). Result: the root ingest always fails at usage; the script writes the durable
`ingest-requested.json` marker first (`spk-ingest-prepared:124-135`), so a single attempt permanently blocks
re-ingest of that image ("earlier physical ingest was requested but image absent", `:125-127`). Combined with
the hard-coded GitWeb SHA, the chain is dead and should be deleted with its tests
(`deploy/spk-host/tests/ingest-prepared-custody.sh`, `deploy/spk-host/tests/stage-inbox-recovery.sh`).

**4.3 `probe_control.rs`/`probe-shell.sh` do not compile.** `probe-shell.sh:18-20` copies
`native/grain-runtime/src/control.rs` beside `probe_control.rs` and runs `rustc --edition=2021`. `control.rs`
imports `serde_json` (`control.rs:6`), which plain `rustc` cannot resolve; and `probe_control.rs:29-42`
matches `control::Event` with three arms while the enum now has five (`InspectAttached`, `Tool` added,
`control.rs:31-37`) — a non-exhaustive match error. The evidence in `CONTROL-SSH-2026-09-26.md` cannot be
reproduced from this tree.

**4.4 `launch-gate.rs` hard-codes x86-64 constants.** `O_NOFOLLOW = 0o400000` (`launch-gate.rs:13`) is the
x86-64 value; on arm64 that bit is `O_LARGEFILE` and `O_NOFOLLOW` is `0o100000`. Syscall 434 for
`pidfd_open` (`:226`) happens to match on both. If built for arm64, `open_gate` would follow a symlinked
`*.gate` path (`:60-79`); the post-open owner/mode check (`:71-77`) would still catch a foreign-owned target
but not a same-owner symlink. Latent today (x86-64-only candidate), real for a CAX VM. Use `libc` constants or
`std::os::unix::fs::OpenOptionsExt::custom_flags(libc::O_NOFOLLOW)`.

**4.5 Hosted shell: one UID for everyone.** Described in the summary. Concrete exposures documented by the
operator's own runbook: the sponsor copies each newcomer's daily secret key into the sponsor home for
`enroll plan` (`OPERATOR.md:44-49`); backups contain the sponsor secret (`:117`); friends' `mini.key.next`
sits beside `mini.key` (`FRIENDS.md:72-75`). Any shell verb that escapes `HOME` (e.g., a future `@FILE` path
bug) reads every other friend's keys and the Store, because they share uid `mini`. `mini serve` "handles one
request at a time" (`INTERFACES.md:208-209`) with a 600 s client wait (`:257-258`), so one member's slow
request stalls everyone.

**4.6 `run.sh unit` has thin hardening.** The printed Store unit (`run.sh:255-272`) lacks `ProtectSystem`,
`ProtectHome`, `ReadWritePaths`, `PrivateDevices`, `ProtectKernel*`, `RestrictAddressFamilies` (the Store
needs only `AF_UNIX`), `MemoryMax`, `TasksMax`. The Store is the most valuable process on the box; the clock
tick unit is better confined than it (`clock/mini-clock-tick.service:51-55`).

**4.7 `run.sh start` readiness line drift.** `start` waits for `^mini: host process [0-9]+$` (`run.sh:187`);
`INTERFACES.md:456` tells operators it waits for `mini: serving`. If `mini serve` changes its log line, `start`
times out at 120 s and reports "socket and Host launch were not ready" (`:190`) with the Host actually
serving.

**4.8 `candidate_resolve` demands 15 roles that `package.py` treats as optional.** `package.py` requires only
`host consent mini store verifier keys` (`:95`) for `--capsule`, but `run.sh` refuses any manifest whose
provenance lacks `grainRuntime ... payWatcher` (`lib.sh:65-68`). Today all builders build every role
(`package.py:448-451`) so this is consistent in practice, but a "shell + documents only" demo candidate
cannot omit SPK/Discord/pay binaries without editing `lib.sh`.

**4.9 Test fixtures ship in production candidates.** `testProvider` (`mini-hermes-test-provider`) and
`launchGate` are `ROLES`/`RUST_ROLES` (`package.py:74-78,90`) and therefore in `bin/` and `SHA256SUMS` of every
candidate. The deterministic provider fixture is harmless unless started, but it is not a product binary.

**4.10 `host-frontend.rs` serial accept loop.** `for accepted in listener.incoming()` handles one client to
completion (`:501-512`); a task UID that opens a connection and sends 1 byte holds the frontend for up to 10 s
(`:349`), and a slow backend reply holds it 600 s (`:23,376`). Per-tenant availability isolation is
explicitly not claimed (`HOST-FRONTEND.md:51-53`), but the frontend also stalls that tenant's own controller.
`read_frame` allocates `Vec::with_capacity(4 + len)` up to ~12.2 MB from an untrusted length (`:274-281`);
serial, so bounded to one at a time.

**4.11 `bwrap` lacks `--new-session`.** The sandboxed program shares the controlling terminal of its caller
if one exists. Under `systemd-run --pipe` the worker gets pipes, not a tty, so TIOCSTI injection is not
reachable in the designed path; adding `--new-session` is cheap defense. No seccomp profile for grain workers
(the SPK path has one, `spk-host/README.md:157-158`).

**4.12 `--network host` in the offering path.** `offer-render-task:193` and `render-hosted-pair:98` hard-code
`"--network","host"` for `hermes-acp`. `FRIEND-GRAINS.md:11-14` says a real provider-backed task uses
`--network none` and host network is "reserved for an explicit local deterministic fixture";
`grain-host/README.md:165-173` warns a host-network worker reaches loopback services. The offering recipe is
therefore fixture-only. A friend's worker launched this way shares the host network namespace and can reach
every TCP listener on the box: the loopback provider fixtures (`install-operator-stack:202`), any
`spk-browser-proxy` loopback port (`BROWSER-WEBSOCKETS.md:3`), and the public internet. Unix sockets are not
reachable (the worker's filesystem view excludes them).

**4.13 `mini-pay-watcher.service` write scope.** `ReadWritePaths=/var/lib/mini` (`pay/mini-pay-watcher.service:20`)
gives the watcher write access to the Store, sessions and candidate (all owned by `mini` anyway in the shared
account). `pay/README.md:145-147` justifies it by the operator socket connect; a socket connect needs no write
permission on the path (the clock unit's own comment says so, `clock/mini-clock-tick.service:31-33`), so
`ReadWritePaths=/var/lib/mini/pay` would do.

**4.14 Discord entrance can act as the sponsor.** `MINI_SPONSOR=ember` maps to the sponsor workspace
(`discord.env.example:19-20`), the unit can write it (`mini-discord.service:38`), and the example roster maps a
Discord id to `ember` (`discord-roster.example.json:4`). Whoever controls that Discord account (or a roster
edit) signs as the factory controller through `/mini` lines, and Discord sees every answer
(`discord/README.md:55`).

**4.15 `spk-host/README.md` documents commands that refuse.** `spk-ingest HOST_BINARY HOST_SHA256 INBOX_SPK
APP_UID` with a root-owned inbox (`README.md:19-22`) is refused by the script (`spk-ingest:5,17,19`). An
operator following the README cannot ingest.

**4.16 `mini-spk-broker@.service` sets `NoNewPrivileges=no`** (`:12`) for a long-running service that parses
operator inputs and holds a sudo rule to a root helper (`install-user-world:159`). The helper validates its
JSON verbs (`USER-TENANCY.md:31-35`), and the rule names one binary, but the sudoers line allows **any
arguments** to that helper (`install-user-world:159`); the helper's own argument checks are the boundary.

**4.17 `test-*` that do not test their fixture.** `deploy/spk-host/tests/var-volume-import-untrusted.sh` creates a setuid file
in the source image (`:21`) and never asserts anything about it (the destination is a plain directory here,
not a `nosuid` mount, so a preserved setuid bit would go unnoticed). `spk-host/tests/*.sh` test functions
`eval`'d out of the scripts with `sed -n '/^name() {/,/^}/p'` (`ingest-prepared-custody.sh:7`): a renamed or
reformatted function makes the test eval nothing and then fail on "command not found", which is loud, good.

**4.18 Lost-reply hazard recorded but owned elsewhere.** `SSH-LIVE-2026-09-26.md:11` records a real committed
effect shown to the user as HTTP 409 because the MCP broker waited 300 s (`mcp.rs` at the time). That is
`native/grain-runtime`'s, not this tree's; noting it because the evidence lives here.

**4.19 Docs that encode now-wrong numbers.** `grain-host/README.md:170` "600 second runtime ceiling" while
`bwrap:93-101` allows 1..1800 via `MINI_GRAIN_RUNTIME_MAX_SEC`; `INGEST-2026-09-26.md:23` "1 GiB/120s" while
`spk-ingest:30` sets 2G (dated, acceptable).

## 5. Unwired / undone

**Not referenced by any code, unit, journey or gate** (a `git grep` outside `deploy/` and `docs/review`
finds only docs or nothing):
- `spk-host/{spk-ingest-prepared,spk-stage-prepared-inbox,spk-qualify,spk-install-phase,
  spk-publish-host-identity}` (552 lines) and their two tests (49).
- `grain-host/{install-operator-stack,host-frontend.rs,host-frontend-probe.rs,check-hosted-pair,
  render-hosted-pair,offer-*,render-friend-key,probe-controller-lifetime.py,probe-hermes-acp.sh,
  probe-shell.sh,probe_control.rs}`; `probe.sh`/`probe_socket.rs` only by docs and evidence.
  (`grain-ssh` is referenced by docs and evidence; no journey uses it.)
- `checkpoint/*.service|timer`, `clock/*.service|timer` (journeys use the `mini checkpoint` and `mini clock`
  verbs directly, `native/resource-client/journey.sh:408-412`).
- `hermes-dispatch/mini-hermes-dispatch.py` (only `receiving.py` and `test_dispatch.py`;
  `scripts/gates/unit-tests.tsv` runs `test_dispatch.py`).
- `shell/templates/hermes/gm/*` (4 files): compiled by nothing (`hermes.rs:44-48` has no GM constants).
- `shell/templates/mud/**` except the four files `jclock.sh` installs; `mud/programs/*.hoon` (not compiled,
  `mud/programs/README.md:1-6`).
- `shell/templates/job/programs/*.jam` — absent; the journeys need `JOB_PROGRAMS` supplied externally
  (`journey.d/jjob.sh:11-13`).
- `deploy/hermes/runtime-inputs/probe-catalogue.py` — referenced by
  `hermes_catalogue_probe.rs [deleted 708a07fd]:31`, does not exist.

**Units with no service in the repo:** `mini-store.service` (`Requires=` in clock, discord, hermes units),
`mini-keys.service` (`hermes/mini-hermes.service:5`, `hermes/README.md:51`), `mini-spk-broker.service` (root,
`spk-host/README.md:147`), the broker-rendered `mini-spk-a<app>-g<gen>.service`,
`<prefix>-spk-supervisor@.service`, `<prefix>-grains.slice`, `mini-backup.timer` (`OPERATOR.md:116`), the
Hermes dispatch service, `mini-discord-mirror`. These live in `dregg-infra` or are rendered by binaries.

**Twins:**

| one | twin | reachable | delete |
|---|---|---|---|
| `host-frontend.rs` op allowlist (`:295-332`) | `protocol/host-operations.json` routes + `transport::public_envelope` (`transport.rs:223-239`, used by `mini socket-proxy`) | registry path is reachable from `mini`; frontend only by hand-built binary | the frontend (or make it call the generated route table) |
| `deploy/grain-host/launch-gate.rs` | `launch-gate.rs [deleted a9a68a7f]` (prototype) | deploy copy | the overnight copy |
| `deploy/spk-host/spk-ingest`, `spk-var-volume` | `native/spk-host/tests/fixture-os/{spk-ingest,spk-var-volume}` | both (fixture-os journeys) | keep only if the fixture journeys stay |
| `mud/sim.py` `ev` | `Pred/Core.lean` `eval` | neither at runtime | `sim.py` |
| `mini-grain-controller@.service` | the unit text in `install-controller:180-202` | installer | the template (README calls it historical) |
| `install-operator-stack` journal checks (`:466-474`) | grain-runtime's own journal semantics | — | move the quiescence check into `grain-runtime` as a verb |
| three readers of `enrol-terms.json` integers (`render-enrol`, `test-render-enrol.py`, `FRIENDS.md:519-523`) | `Kernel/PayTariff.lean` `nodeWeekRate` | — | FRIENDS should cite the file, not restate numbers |
| `room/chat/law.author.json` (hand JSON) | `Kernel/PrivateRoomKeys.lean`-style Lean source | client | emit it from Lean like the job/story/market laws |

**Versioned siblings / stale states:** spk broker config v1/v2 refused, v3 current
(`USER-TENANCY.md:26-29`); manifest v1 refused, v2 current (`lib.sh:37-39`); `HERMES-LINUX` and
`HERMES-GATED-INIT` are two runs of one probe; `PROBE`, `GATE-INTEGRATION`, `GATE-RUNTIME-MAX` are three runs
of `probe.sh`.

**TODO/FIXME/`unimplemented!`/`todo!`/`#[allow(dead_code)]`:** none in the `.rs` files;
`probe-shell.sh:20` passes `-A dead_code` to rustc.

## 6. Size and shape

| subtree | files | lines | what |
|---|---|---|---|
| `candidate/` | 11 | 2,416 | packager, operator scripts, 3 tests (368 lines), contract (546) |
| `checkpoint/` | 2 | 37 | user unit + timer |
| `clock/` | 2 | 66 | system unit + timer |
| `discord/` | 5 | 286 | unit, env/roster examples, commands, README |
| `grain-host/` | 48 | 4,761 | launcher, gate, controller installers, frontend, offer chain, probes, 18 dated notes/logs (518 lines) |
| `hermes/` | 2 | 246 | unit + README |
| `hermes-dispatch/` | 4 | 339 | pump, journey, test, README |
| `pay/` | 7 | 911 | tick script, unit+timer, terms, renderer + test, README |
| `shell/` (excl. templates) | 9 | 1,152 | 4 wrappers, motd, 4 docs |
| `shell/templates/` | 135 | 10,785 | of which `mud/` 95 files / 7,312 lines |
| `spk-host/` | 37 | 3,152 | 8 scripts, 3 tests, unit, example, 11 contracts (1,311), 13 dated notes/logs (634) |
| **total** | **262** | **24,151** | |

Tests vs. code: the only `#[cfg(test)]` region is `host-frontend.rs:556-616` (61 lines). Test scripts:
`candidate/test-*` (368), `pay/test-render-enrol.py` (197), `hermes-dispatch/test_dispatch.py` (23),
`spk-host/tests/*` (88), `grain-host/probe*`/`host-frontend-probe.rs`/`probe_*.rs` (524). Fixtures/journeys
misplaced here: `hermes-dispatch/receiving.py` (85), MUD `sim.py`/`validate.py`/`tidewrack-broken/`.
Evidence/notes: 24 dated `.md` + 10 `.log` = ~1,450 lines.

The minimal version is in Section 9: keep 57 files / 7,361 lines, move 12 files / 2,469 lines of journey
fixtures, delete 193 files / 14,321 lines.

## 7. Deployability on a small public Linux VM

**Must exist on the box** for the current public shape (shell + documents, README `README.md:79`):
- A Linux x86-64 VM with glibc ≥ `provenance.json .abi.glibcRequired` (`package.py:356`), systemd,
  `jq`, `flock`, `sha256sum`, `od`, `tr`, `ps` (`run.sh:22`), OpenSSH server.
- A candidate directory built by `build.sh` on a matching Linux x86-64 builder (it needs Lean, mathlib cache,
  Rust nightly, zig; `build.sh:68-72`) — the VM itself need not build.
- One Unix account owning the state dir (`run.sh init --state`, `mkdir -m 700`, `run.sh:63-64`), the socket
  path < 108 bytes (`:59-62`).
- The Store unit (from `run.sh unit`, or dregg-infra's `mini-store.service`), and — new since the 10-01
  candidate — the clock tick timer (else no `clock/now` advances; laws reading the clock refuse) and the
  checkpoint timer (else writes stop with `tail-bound` after 256 records; `checkpoint/...service:3-11`). The
  README's description of the public node does not say whether its candidate predates the tail bound.
- For the hosted shell: `mini-shell-ssh` in a root-owned path, an authorized_keys file whose lines come from
  `render-shell-key`, session homes `0700`, and `motd`.

**Operator-configured:** genesis params (`params.sh fill-genesis`, `INTERFACES.md:494-500`), the sponsor key
custody (`:501-504`), the authorized_keys roster, `/etc/mini/*` for any optional service, backup policy (the
state dir holds several owners' secrets, `INTERFACES.md:513-517`).

**Dangerous to expose:**
- The operator socket (`/var/lib/mini/store/node/operator/mini.sock`, `pay/README.md:136-149`) — must stay
  `0700`-dir private; ops 117-120 run the verifier twice per call.
- The sponsor workspace and `keys/sponsor.key` — factory controller authority. Discord can reach it
  (Flaw 4.14); the hosted shell's shared UID can read it (Flaw 4.5).
- `/var/lib/mini-backups` (contains the sponsor secret, `OPERATOR.md:117`).
- `mini-discord` listener: must be on a private address behind TLS (`discord.env.example:6-7`); a public bind
  would expose an HTTP endpoint whose only gate is the Ed25519 signature and roster.
- Any grain worker with `--network host` (Flaw 4.12).

**What a stranger on the internet can exercise:** sshd (key-only is a dregg-infra setting, not shown here;
`FRIENDS.md:3-9` and `OPERATOR.md:20-23` mention `mode=closed` → `mini-closed` exit 69, defined outside this
repo). Discord, if deployed: unsigned/badly-signed POSTs get 401 before anything (`discord/README.md:28-31`);
a correctly signed interaction from a non-roster user gets a fixed refusal (`:36-37`). No other inbound
listener is described for the demo shape. Pay-to-enrol (not deployed) would let a stranger become a proxy-mode
member by paying (`FRIENDS.md:510-566`).

**What a malicious enrolled member can exercise:**
- Hosted shell: every `mini shell` verb as uid `mini` (same as Store and other members); file I/O confined to
  `HOME` by the shell's grammar only (`shell/README.md:125-128`); a bug there is total. Resource exhaustion:
  `mini serve` is single-request (`INTERFACES.md:208`) — a member can monopolize it with expensive reads
  (each up to 600 s client wait); disk growth in their session home (attempts, refusals, requests are
  retained). Members can sign only with their own key; authority is the Host's.
- Proxy mode: only frames `transport::public_envelope` admits (public routes, pinned config,
  `proxy.rs:58-69`); no shell, no files. The safer default; signing on a friend's machine is still refused
  until a local admitted Store exists (`shell/README.md:75-79`).
- Grain friend (if offered): only `grain-runtime connect` lines (`grain-ssh:14-19`); the worker sandbox's
  writable workspace, and the network if `--network host`.

## 8. Questions for the Lean side

- **Q8.1** Op 17 (`PROVIDER_CONTINUITY`): what exact payload layout does `runProviderContinuitySession`
  (`Host/Main.lean:6723`) decode? `host-frontend.rs:297-306` assumes `u32 LE call_length`, a nonempty call of
  that length, then a trailer of at most 1024 bytes. Is 1024 the Lean bound, and is the trailer a fixed
  field?
- **Q8.2** Op 19 (`PROVIDER_USAGE_QUOTE`): does `ProviderUsage.quotePayload` (`Host/Main.lean:6749`) take
  `u32 meta_len (≤4096) · meta · u32 req_len (≤1 MiB) · req · response (≤8 MiB)` as `host-frontend.rs:307-330`
  assumes? Point at the decoder and its bounds.
- **Q8.3** Is there a Lean declaration that generates the public-route set used by
  `transport::public_envelope`, so that `host-frontend.rs` could consume the same table instead of
  `0..=11,17,19`?
- **Q8.4** `room/chat/law.author.json` and `room/private/law.keys.json` are hand-written `Pred` JSON compiled
  into the client. Which Lean declaration states the intended law (the keys law is mentioned by
  `Kernel/PrivateRoomKeys.lean`), and is there a theorem that the JSON parses to it? The job, story and
  market laws have generators; these two do not.
- **Q8.5** `job/law.job` clause 44 relies on the slot `authority/operation/job-money` being projected **only**
  by the job-money receiver. Which declaration in `Kernel/JobMoney.lean` (or the controller) guarantees no
  other receiver projects it?
- **Q8.6** The checkpoint unit certifies with `--control 53`. Which Lean receiver admits `certify` and what
  capability does it require: the factory controller capability or a dedicated one? If dedicated, the unit's
  default is wrong.
- **Q8.7** `pay/README.md:136-138` says ops 117-120 are admitted only on the operator socket. Is the route
  restriction enforced in Lean (`dispatchSession`/`serveFrame` refusing on a public-mode socket) or only by
  `mini serve`'s socket mode? Point at the check.
- **Q8.8** `render-enrol` writes `nodeWeekRate` and the README says the Host refuses `nodeHourRate` and v3
  tariffs (`pay/README.md:42-44`). Point at the `Kernel/PayTariff.lean` decoder arm that refuses them.
- **Q8.9** The MUD sheet law installed by journey KC uses `eqSlots`/`leSlots`/`leSlotsOff`
  (`mud/sheet/law.sheet`). Does the Host's `Pred` JSON parser now accept `leSlotsOff` with keys `left`,
  `right`, `offset` (`mud/render.py:9-10` says the key names were ASSUMED)? `evidence/2026-10-05-clock-law`
  suggests yes; confirm the constructor.
- **Q8.10** `HOT-ROUTE-ENROLLMENT.md:110-120` describes opcode 164's no-record refusal payload
  `DREGG/APPLICATION/DISPATCH-NO-RECORD-REFUSAL/v1`. Which Lean declaration emits it, and is it the
  registry's `response_markers` entry 164?

## 9. Minimal "small public Hetzner VM demo" subset

Goal: the shell + documents node, proxy mode available, clock and checkpoint running, no Hermes, SPK,
Discord or pay. Line counts from `wc -l`.

**Keep in `deploy/` (57 files, 7,361 lines):**
- `candidate/` all 11 files (2,416). Edit `lib.sh:65-68` so optional roles are optional, drop `testProvider`
  and `launchGate` from `package.py:74-78,90`, and fix `--capsule` or delete it.
- `checkpoint/` 2 (37), `clock/` 2 (66). Harmonize binary paths and make checkpoint a system unit as
  `User=mini` like clock.
- `shell/mini-shell-ssh`, `mini-socket-proxy`, `render-shell-key`, `motd.txt`, `README.md`, `OPERATOR.md`,
  `FRIENDS.md`, `DOC-VERBS.md`.
- Template files the client compiles in (must stay, or move into `native/resource-client/`, which is the
  better home): `templates/README.md`; `room/` all 10; `story/README.md`, `story/tale/{table,law.player,
  law.player.json,law.table.json}`; `hermes/README.md`, `hermes/librarian/*` (4), `hermes/runner/*` (4);
  `job/{fields.json,law.job,law.job.json,law.job.shell,README.md}`; `market/sealed/{law.market,fields.json}`.
- `spk-host/spk-var-volume` (compiled into `mini-spk-volume-helper`) and `spk-host/spk-ingest` (used by
  `scripts/spk-platform/*`), only while the `spk-host` crate stays in the workspace build; otherwise move
  `spk-var-volume` into `native/spk-host/`.

**Move out of `deploy/` to journey fixtures (12 files, 2,469 lines):** `mud/law.management(.json)`,
`mud/sheet/{law.sheet,law.sheet.json,init.sheet.json,fields.json}`, `mud/tidewrack/realm.json`, `mud/render.py`
(also used by `scripts/gen-joblaw.py`), `job/programs/*` (4). Used by `journey.d/jclock.sh`,
`jjob.sh`, `jjob1.sh`, `scripts/gen-*law.py`.

**Delete (193 files, 14,321 lines):**

| group | files | lines | why |
|---|---|---|---|
| `grain-host/` everything except `bwrap`, `resolve-bwrap`, `materialize-bwrap.py`, `launch-gate.rs` (keep those 4 only if Hermes journeys stay; for the demo delete all) | 44-48 | 4,063-4,761 | no unit in the demo; offer chain is a one-fixture tool; probes broken or historical; 18 dated notes/logs → `docs/evidence/` |
| `hermes/`, `hermes-dispatch/` | 6 | 585 | Hermes off on the node (`README.md:88`) |
| `discord/` | 5 | 286 | entrance inactive, no Discord application (`README.md:89`) |
| `pay/` | 7 | 911 | not deployed (`README.md:94`); keep `enrol-terms.json` + `render-enrol` + test on a pay branch if wanted |
| `spk-host/` except `spk-var-volume`, `spk-ingest` | 35 | 2,783 | SPK not deployed; dead GitWeb root chain (Flaw 4.2); contradictory contracts (Section 10); 13 dated notes/logs → `docs/evidence/` |
| `shell/mini-shell-ssh-credentials` | 1 | 23 | split tenancy "on no box" (`README.md:87`) |
| `shell/templates/mud/` except the moved files | 87 | 4,891 | unshipped game data; `sim.py` is a `Pred.eval` twin |
| `shell/templates/hermes/gm/` | 4 | 81 | compiled by nothing |

(The table's per-group numbers overlap where noted; the exact total of everything not in the two lists above
is 193 files / 14,321 lines.)

## 10. Duplicated or contradictory instructions

1. **SPK broker: root service vs. user service.** `spk-host/README.md:37-41,147-150` (root
   `mini-spk-broker.service`, socket `/run/mini-spk-broker.sock`, `/etc/mini/spk-broker.json`) vs.
   `spk-host/USER-TENANCY.md:20-27` (user template `mini-spk-broker@.service`, operator-owned
   `WORLD/runtime-STORE/broker.sock`; "The v1 root broker config and global socket are refused").
2. **SPK broker socket: three paths.** `/run/mini-spk-broker.sock` (`BROKER-RUNTIME-UPGRADE.md:76-77`,
   `spk-host/README.md:38`), exactly `GRAINS_ROOT/broker.sock` for isolated installs
   (`BROKER-RUNTIME-UPGRADE.md:77-82`), and `.../runtime-STORE/broker.sock` (`mini-spk-broker.example.json:6`,
   `USER-TENANCY.md:25`).
3. **SPK filesystem roots: three.** `/var/lib/minidregg/spk` (`spk-host/README.md:21`, `spk-qualify:10`,
   `spk-ingest-prepared:12`), `/var/lib/mini-spk-worlds/STORE` (`install-user-world:33`,
   `mini-spk-broker@.service:6`), and `/etc/minidregg/spk/host-identity` (`spk-publish-host-identity:9`,
   `spk-host/README.md:189-190`) vs. `GRAINS/host-identity` (`spk-var-volume:110`,
   `install-user-world:151`).
4. **`spk-ingest` usage.** `spk-host/README.md:19-21` (4 args, root inbox, "system unit") vs.
   `spk-ingest:5,17,29` (6 args with `--root`, refuses root, `systemd-run --user`).
5. **Pay price defect.** Root `README.md:94` ("the tariff counts hours, so the quoted week is 49.999992
   DREGG, not 50", "known defect is open") vs. `pay/README.md:32-44`, `render-enrol:21-25`,
   `test-render-enrol.py:4-6`, `Kernel/PayTariff.lean:31` (week unit, exactly 50.000000, hourly unit retired).
6. **MUD templates "never run against a Host".** `shell/templates/mud/README.md:3-5` and
   `shell/FRIENDS.md:612-613` vs. `native/resource-client/journey.d/jclock.sh:340-362` (installs
   `law.management ; law.sheet` on a fresh Host) and `docs/evidence/2026-10-05-clock-law`.
7. **`run.sh start` readiness.** `INTERFACES.md:456` ("waits ... for the `mini: serving` line") vs.
   `run.sh:187` (`^mini: host process [0-9]+$`).
8. **Genesis clock placeholder.** `clock/mini-clock-tick.service:10-11` ("replace the example's zero
   placeholder") vs. `INTERFACES.md:402-410` and `native/resource-client/genesis-params.example.json`
   (`genesisNow: null`; 0 is refused).
9. **Room roster ceiling.** `hermes-dispatch/README.md:8-11` ("The roster reserves 499 historical non-founder
   subject slots ... A new subject at the boundary receives an explicit refusal") vs.
   `shell/templates/room/chat/README.md:12-17` (ROOM-SCHEMA v2: "there is no member ceiling. A room born under
   v1 ... 499 slots ... is refused by name").
10. **Pred atoms.** `shell/templates/README.md:68-69` ("none of them compares one slot with another") vs.
    `room/private/law.keys.json` (uses `eqSlots`) and `mud/README.md:78-80` (`eqSlots`/`leSlots` landed).
11. **Frontend public config name.** `OFFER-PAIR.md:64` (`"frontConfig":"/ABS/operator-front-a/host.config"`)
    vs. `install-operator-stack:164-165` (public config must be `PUBLIC_DIR/host.json`) and
    `OPERATOR-STACK.md:25`.
12. **Launch-gate build.** `grain-host/README.md:41-42` and `GATE-INTEGRATION-2026-09-26.md:11` (`rustc
    --edition=2021`, no `-O`) vs. `native/grain-runtime/hermes-journey.sh:185` (`rustc -O`) vs.
    `native/launch-gate/Cargo.toml:17-18` (cargo, `opt-level = 3`). Three byte identities for "the deployed
    gate".
13. **Controller unit template status.** `grain-host/README.md:61-64` calls `mini-grain-controller@.service`
    "historical"; `FRIEND-GRAINS.md:16` instructs "Run `mini-grain-controller@TASK.service` under that task
    account's `systemd --user` manager" without saying it is the rendered direct unit.
14. **Grain worker network.** `FRIEND-GRAINS.md:11-14` ("A real provider-backed task ... selects `--network
    none`", host network "reserved for an explicit local deterministic fixture") vs. `offer-render-task:193`,
    `render-hosted-pair:98` (hard-coded `--network host` in the offering recipe).
15. **Worker runtime ceiling.** `grain-host/README.md:170` ("600 second runtime ceiling") vs.
    `bwrap:93-101` (configurable 1..1800).
16. **Control socket name.** `grain-host/README.md:137-138` (`controller.sock`) vs. `FRIEND-GRAINS.md:21`,
    `offer-render-task:186` (`control.sock`).
17. **Pool key setup.** `hermes/README.md:56` (`mini-keys pool --action set --provider openrouter-pool
    --secret -` as root) vs. `hermes/README.md:101-103` (`sudo -u mini mini key --action set --pool true
    --provider pool --secret -`).
18. **Mirror secrets custody.** `discord/README.md:14` ("the key broker `mini-keys` holds both [webhook and
    bot token] and posts/reads for it") vs. `discord/README.md:122` ("`MINI_MIRROR_WEBHOOK_URL` and
    `MINI_MIRROR_BOT_TOKEN` (secrets: a 0600 EnvironmentFile)").
19. **Discord binary location.** `discord/README.md:67-70` (build `native/discord-entrance` separately with
    `cargo +nightly-2026-06-21 build`, install `/usr/local/lib/mini/mini-discord`) and
    `mini-discord.service:21` vs. `candidate/build.sh:14` and `package.py:71` (the candidate ships
    `bin/mini-discord`, pinned).
20. **Binary paths across units.** `/usr/local/bin/mini` (`checkpoint/...service:20`,
    `clock/...service:47`), `/opt/mini/bin/mini` and `/opt/mini/bin/pay-watcher` (`pay/mini-pay-watcher:52-53`,
    `pay/mini-pay-watcher.service:13`), `/var/lib/mini/candidate/current/bin/*` (`hermes/mini-hermes.service:31`,
    `discord.env.example:13-14`), `/opt/mini/bin/grain-runtime` (`mini-grain-controller@.service:10`),
    `%h/.local/libexec/mini-spk-broker` (`mini-spk-broker@.service:6`).
21. **Checkpoint unit scope.** `checkpoint/...service:13-14` (user unit, `%h/mini/operator-workspace`) vs. the
    other Store-adjacent units (system units, `User=mini`, sponsor workspace at
    `/var/lib/mini/store/node/sponsor`, `shell/OPERATOR.md:12`, `discord.env.example:20`).
22. **INTERFACES output table is stale.** `INTERFACES.md:64-86` omits `bin/mini-keys`, `bin/mini-spk-broker`,
    `bin/spk-hostd`, `bin/mini-spk-volume-helper`, `bin/mini-hermes-test-provider`, `bin/launch-gate`, and
    `OUT/check-tamper.sh`, all of which `package.py:57-79,103-108` ships. Also `build.sh:3-16` omits the two test
    fixtures.
23. **Capsule route.** `INTERFACES.md:12-13,181-185` and `package.py:6,26-34` (a supported route) vs.
    `package.py:261,280-284,306` (always refuses) and `INTERFACES.md:129`.
24. **Enrollment key handling, two recipes.** `shell/OPERATOR.md:44-66` (copy the friend's daily key into the
    sponsor home, `enroll plan NAME NAME.key NEXT COSIGN`) vs. `shell/README.md:85-94,156-163` (the friend keeps
    the key; `enroll plan NAME PUBKEY NEXT COSIGN`). Both are current; the README calls the first a "Known
    limit". Not contradictory, but two procedures for one step.
25. **Duplicate statements of fixed numbers.** The 50 DREGG/week integers appear in `pay/README.md:31-44`,
    `render-enrol:21-25`, `test-render-enrol.py`, `FRIENDS.md:519-523`; the "one public node" facts
    (`mini@2.28.141.27`, candidate `5688775a`) appear in `FRIENDS.md:3-9,92-101`, `OPERATOR.md:3,17,38`,
    `enrol-terms.json:15`, root `README.md:79`. Each restatement is a future contradiction.

---

## Appendix A — every file and its line count

| file | lines |
|---|---|
| `deploy/candidate/build.sh` | 357 |
| `deploy/candidate/check-tamper.sh` | 58 |
| `deploy/candidate/INTERFACES.md` | 546 |
| `deploy/candidate/lane-build.sh` | 115 |
| `deploy/candidate/lib.sh` | 168 |
| `deploy/candidate/package.py` | 460 |
| `deploy/candidate/params.sh` | 59 |
| `deploy/candidate/run.sh` | 285 |
| `deploy/candidate/test-lane-build.sh` | 88 |
| `deploy/candidate/test-package.py` | 222 |
| `deploy/candidate/test-params.sh` | 58 |
| `deploy/checkpoint/mini-checkpoint-certify.service` | 24 |
| `deploy/checkpoint/mini-checkpoint-certify.timer` | 13 |
| `deploy/clock/mini-clock-tick.service` | 55 |
| `deploy/clock/mini-clock-tick.timer` | 11 |
| `deploy/discord/commands.json` | 57 |
| `deploy/discord/discord-roster.example.json` | 6 |
| `deploy/discord/discord.env.example` | 27 |
| `deploy/discord/mini-discord.service` | 41 |
| `deploy/discord/README.md` | 155 |
| `deploy/grain-host/bwrap` | 180 |
| `deploy/grain-host/check-hosted-pair` | 133 |
| `deploy/grain-host/CONTROL-SSH-2026-09-26.log` | 16 |
| `deploy/grain-host/CONTROL-SSH-2026-09-26.md` | 36 |
| `deploy/grain-host/CONTROLLER-CRASH-2026-09-26.log` | 55 |
| `deploy/grain-host/CONTROLLER-CRASH-2026-09-26.md` | 9 |
| `deploy/grain-host/CONTROLLER-LIFETIME-2026-10-02.md` | 65 |
| `deploy/grain-host/FRIEND-GRAINS.md` | 30 |
| `deploy/grain-host/GATE-INTEGRATION-2026-09-26.log` | 11 |
| `deploy/grain-host/GATE-INTEGRATION-2026-09-26.md` | 15 |
| `deploy/grain-host/GATE-RUNTIME-MAX-2026-09-26.log` | 12 |
| `deploy/grain-host/grain-ssh` | 19 |
| `deploy/grain-host/HERMES-GATED-INIT-2026-09-26.log` | 15 |
| `deploy/grain-host/HERMES-GATED-INIT-2026-09-26.md` | 7 |
| `deploy/grain-host/HERMES-LINUX-2026-09-26.log` | 15 |
| `deploy/grain-host/HERMES-LINUX-2026-09-26.md` | 48 |
| `deploy/grain-host/host-frontend-probe.rs` | 67 |
| `deploy/grain-host/HOST-FRONTEND.md` | 61 |
| `deploy/grain-host/host-frontend.rs` | 616 |
| `deploy/grain-host/HOSTED-PAIR.md` | 38 |
| `deploy/grain-host/install-controller` | 226 |
| `deploy/grain-host/INSTALL-CONTROLLER-2026-09-26.md` | 9 |
| `deploy/grain-host/install-operator-stack` | 591 |
| `deploy/grain-host/launch-gate.rs` | 450 |
| `deploy/grain-host/materialize-bwrap.py` | 28 |
| `deploy/grain-host/mini-grain-controller@.service` | 20 |
| `deploy/grain-host/offer-check-authority` | 105 |
| `deploy/grain-host/offer-check-pair` | 120 |
| `deploy/grain-host/offer-check-provision` | 216 |
| `deploy/grain-host/OFFER-PAIR.md` | 129 |
| `deploy/grain-host/offer-render-entry` | 109 |
| `deploy/grain-host/offer-render-task` | 213 |
| `deploy/grain-host/OPERATOR-STACK.md` | 67 |
| `deploy/grain-host/OWNER-DEMO-2026-09-26.md` | 17 |
| `deploy/grain-host/probe_control.rs` | 44 |
| `deploy/grain-host/probe_socket.rs` | 30 |
| `deploy/grain-host/PROBE-2026-09-26.log` | 9 |
| `deploy/grain-host/PROBE-2026-09-26.md` | 56 |
| `deploy/grain-host/probe-controller-lifetime.py` | 82 |
| `deploy/grain-host/probe-hermes-acp.sh` | 73 |
| `deploy/grain-host/probe-shell.sh` | 69 |
| `deploy/grain-host/probe.sh` | 159 |
| `deploy/grain-host/README.md` | 175 |
| `deploy/grain-host/render-friend-key` | 33 |
| `deploy/grain-host/render-hosted-pair` | 120 |
| `deploy/grain-host/resolve-bwrap` | 40 |
| `deploy/grain-host/SSH-LIVE-2026-09-26.log` | 108 |
| `deploy/grain-host/SSH-LIVE-2026-09-26.md` | 15 |
| `deploy/hermes-dispatch/mini-hermes-dispatch.py` | 105 |
| `deploy/hermes-dispatch/README.md` | 126 |
| `deploy/hermes-dispatch/receiving.py` | 85 |
| `deploy/hermes-dispatch/test_dispatch.py` | 23 |
| `deploy/hermes/mini-hermes.service` | 48 |
| `deploy/hermes/README.md` | 198 |
| `deploy/pay/enrol-terms.json` | 16 |
| `deploy/pay/mini-pay-watcher` | 128 |
| `deploy/pay/mini-pay-watcher.service` | 25 |
| `deploy/pay/mini-pay-watcher.timer` | 11 |
| `deploy/pay/README.md` | 299 |
| `deploy/pay/render-enrol` | 235 |
| `deploy/pay/test-render-enrol.py` | 197 |
| `deploy/shell/DOC-VERBS.md` | 79 |
| `deploy/shell/FRIENDS.md` | 620 |
| `deploy/shell/mini-shell-ssh` | 27 |
| `deploy/shell/mini-shell-ssh-credentials` | 23 |
| `deploy/shell/mini-socket-proxy` | 35 |
| `deploy/shell/motd.txt` | 11 |
| `deploy/shell/OPERATOR.md` | 134 |
| `deploy/shell/README.md` | 163 |
| `deploy/shell/render-shell-key` | 60 |
| `deploy/shell/templates/hermes/gm/budget.json` | 6 |
| `deploy/shell/templates/hermes/gm/grants.json` | 22 |
| `deploy/shell/templates/hermes/gm/program.md` | 46 |
| `deploy/shell/templates/hermes/gm/README.md` | 7 |
| `deploy/shell/templates/hermes/librarian/budget.json` | 6 |
| `deploy/shell/templates/hermes/librarian/grants.json` | 17 |
| `deploy/shell/templates/hermes/librarian/program.md` | 54 |
| `deploy/shell/templates/hermes/librarian/README.md` | 7 |
| `deploy/shell/templates/hermes/README.md` | 69 |
| `deploy/shell/templates/hermes/runner/budget.json` | 6 |
| `deploy/shell/templates/hermes/runner/grants.json` | 16 |
| `deploy/shell/templates/hermes/runner/program.md` | 35 |
| `deploy/shell/templates/hermes/runner/README.md` | 10 |
| `deploy/shell/templates/job/fields.json` | 38 |
| `deploy/shell/templates/job/law.job` | 182 |
| `deploy/shell/templates/job/law.job.json` | 1894 |
| `deploy/shell/templates/job/law.job.shell` | 48 |
| `deploy/shell/templates/job/programs/collatz.hoon` | 24 |
| `deploy/shell/templates/job/programs/collatz.jam.provenance` | 9 |
| `deploy/shell/templates/job/programs/liar.hoon` | 6 |
| `deploy/shell/templates/job/programs/liar.jam.provenance` | 9 |
| `deploy/shell/templates/job/README.md` | 73 |
| `deploy/shell/templates/market/sealed/fields.json` | 35 |
| `deploy/shell/templates/market/sealed/law.market` | 44 |
| `deploy/shell/templates/mud/affliction-table.json` | 159 |
| `deploy/shell/templates/mud/area/README.md` | 57 |
| `deploy/shell/templates/mud/item/fields.json` | 21 |
| `deploy/shell/templates/mud/item/init.item.json` | 62 |
| `deploy/shell/templates/mud/item/item.json` | 32 |
| `deploy/shell/templates/mud/item/lantern.json` | 10 |
| `deploy/shell/templates/mud/item/law.item` | 23 |
| `deploy/shell/templates/mud/item/law.item-reward` | 9 |
| `deploy/shell/templates/mud/item/law.item-reward.json` | 64 |
| `deploy/shell/templates/mud/item/law.item.json` | 230 |
| `deploy/shell/templates/mud/item/README.md` | 29 |
| `deploy/shell/templates/mud/law.management` | 6 |
| `deploy/shell/templates/mud/law.management.json` | 34 |
| `deploy/shell/templates/mud/market/fields.json` | 45 |
| `deploy/shell/templates/mud/market/law.market` | 22 |
| `deploy/shell/templates/mud/market/law.market.json` | 306 |
| `deploy/shell/templates/mud/market/market.json` | 18 |
| `deploy/shell/templates/mud/org/charter.md` | 27 |
| `deploy/shell/templates/mud/org/fields.json` | 39 |
| `deploy/shell/templates/mud/org/law.ballot` | 29 |
| `deploy/shell/templates/mud/org/law.ballot.json` | 505 |
| `deploy/shell/templates/mud/org/law.org` | 20 |
| `deploy/shell/templates/mud/org/law.org.json` | 207 |
| `deploy/shell/templates/mud/org/law.treasury` | 12 |
| `deploy/shell/templates/mud/org/law.treasury.json` | 28 |
| `deploy/shell/templates/mud/org/offices.json` | 119 |
| `deploy/shell/templates/mud/org/org.json` | 47 |
| `deploy/shell/templates/mud/programs/market.hoon` | 59 |
| `deploy/shell/templates/mud/programs/rat.hoon` | 88 |
| `deploy/shell/templates/mud/programs/README.md` | 40 |
| `deploy/shell/templates/mud/programs/resolver.hoon` | 91 |
| `deploy/shell/templates/mud/programs/tally.hoon` | 42 |
| `deploy/shell/templates/mud/quest/cellar-key/init.quest.json` | 54 |
| `deploy/shell/templates/mud/quest/cellar-key/law.quest` | 27 |
| `deploy/shell/templates/mud/quest/cellar-key/law.quest-lawful` | 11 |
| `deploy/shell/templates/mud/quest/cellar-key/law.quest-lawful.json` | 58 |
| `deploy/shell/templates/mud/quest/cellar-key/law.quest.json` | 282 |
| `deploy/shell/templates/mud/quest/cellar-key/quest.json` | 64 |
| `deploy/shell/templates/mud/quest/fields.json` | 15 |
| `deploy/shell/templates/mud/README.md` | 134 |
| `deploy/shell/templates/mud/render.py` | 129 |
| `deploy/shell/templates/mud/room/fields.json` | 67 |
| `deploy/shell/templates/mud/room/law.room` | 10 |
| `deploy/shell/templates/mud/room/law.room.json` | 90 |
| `deploy/shell/templates/mud/sheet/fields.json` | 52 |
| `deploy/shell/templates/mud/sheet/init.sheet.json` | 134 |
| `deploy/shell/templates/mud/sheet/law.sheet` | 152 |
| `deploy/shell/templates/mud/sheet/law.sheet-cure-lawful` | 12 |
| `deploy/shell/templates/mud/sheet/law.sheet-cure-lawful.json` | 83 |
| `deploy/shell/templates/mud/sheet/law.sheet-witnessed` | 8 |
| `deploy/shell/templates/mud/sheet/law.sheet-witnessed.json` | 25 |
| `deploy/shell/templates/mud/sheet/law.sheet.json` | 1863 |
| `deploy/shell/templates/mud/sheet/README.md` | 64 |
| `deploy/shell/templates/mud/sheet/sheet.json` | 46 |
| `deploy/shell/templates/mud/sim.py` | 433 |
| `deploy/shell/templates/mud/tariff.json` | 50 |
| `deploy/shell/templates/mud/tidewrack-broken/README.md` | 19 |
| `deploy/shell/templates/mud/tidewrack-broken/realm.json` | 52 |
| `deploy/shell/templates/mud/tidewrack-broken/warrens/area.json` | 208 |
| `deploy/shell/templates/mud/tidewrack-broken/warrens/rooms/sump.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/harbour/area.json` | 140 |
| `deploy/shell/templates/mud/tidewrack/harbour/rooms/chandlery.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/harbour/rooms/fishmarket.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/harbour/rooms/hall.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/harbour/rooms/lanes-gate.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/harbour/rooms/loft.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/harbour/rooms/quay.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/harbour/rooms/shrine.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/harbour/rooms/square.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/harbour/rooms/tavern.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/harbour/rooms/tower.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/manses/area.json` | 106 |
| `deploy/shell/templates/mud/tidewrack/manses/rooms/plot-1.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/manses/rooms/plot-2.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/manses/rooms/plot-3.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/manses/rooms/plot-4.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/manses/rooms/plot-5.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/manses/rooms/row-upper.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/manses/rooms/row.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/manses/rooms/rows-end.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/realm.json` | 51 |
| `deploy/shell/templates/mud/tidewrack/warrens/area.json` | 193 |
| `deploy/shell/templates/mud/tidewrack/warrens/rooms/arch.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/warrens/rooms/cellar.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/warrens/rooms/cistern.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/warrens/rooms/collapse.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/warrens/rooms/court.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/warrens/rooms/crawlway.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/warrens/rooms/grotto.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/warrens/rooms/junction.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/warrens/rooms/midden.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/warrens/rooms/niche.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/warrens/rooms/sluice.md` | 3 |
| `deploy/shell/templates/mud/tidewrack/warrens/rooms/undercroft.md` | 3 |
| `deploy/shell/templates/mud/validate.py` | 107 |
| `deploy/shell/templates/README.md` | 99 |
| `deploy/shell/templates/room/chat/law.author.json` | 1 |
| `deploy/shell/templates/room/chat/README.md` | 48 |
| `deploy/shell/templates/room/private/law.keys.json` | 1 |
| `deploy/shell/templates/room/private/law.room.json` | 1 |
| `deploy/shell/templates/room/private/README.md` | 89 |
| `deploy/shell/templates/room/README.md` | 24 |
| `deploy/shell/templates/room/social/member.shell` | 14 |
| `deploy/shell/templates/room/social/template.shell` | 27 |
| `deploy/shell/templates/room/story/template.shell` | 37 |
| `deploy/shell/templates/room/workroom/template.shell` | 49 |
| `deploy/shell/templates/story/README.md` | 91 |
| `deploy/shell/templates/story/tale/law.player` | 18 |
| `deploy/shell/templates/story/tale/law.player.json` | 265 |
| `deploy/shell/templates/story/tale/law.table.json` | 30 |
| `deploy/shell/templates/story/tale/table` | 16 |
| `deploy/spk-host/BROKER-RUNTIME-UPGRADE.md` | 117 |
| `deploy/spk-host/BROWSER-WEBSOCKETS.md` | 44 |
| `deploy/spk-host/GITWEB-CACHE-CAPACITY-2026-09-27.md` | 54 |
| `deploy/spk-host/GITWEB-SESSION-PROBE-2026-09-27.md` | 66 |
| `deploy/spk-host/GITWEB-SMOKE-2026-09-27.md` | 67 |
| `deploy/spk-host/HOST-WIRE-STAGING-CHECK-2026-09-27.md` | 32 |
| `deploy/spk-host/HOSTD-ADAPTER-PROBE-2026-09-27.md` | 26 |
| `deploy/spk-host/HOSTD-PROBE-2026-09-27.md` | 40 |
| `deploy/spk-host/HOT-ROUTE-ENROLLMENT.md` | 139 |
| `deploy/spk-host/HTTP-CUSTODIAN-CONTRACT.md` | 104 |
| `deploy/spk-host/HTTP-ENTRANCE-CHECK-2026-09-27.log` | 18 |
| `deploy/spk-host/HTTP-ENTRANCE-CHECK-2026-09-27.md` | 37 |
| `deploy/spk-host/INGEST-2026-09-26.md` | 64 |
| `deploy/spk-host/install-user-world` | 166 |
| `deploy/spk-host/MINI-CLAIM-DISPATCH-CONTRACT.md` | 105 |
| `deploy/spk-host/mini-spk-broker.example.json` | 17 |
| `deploy/spk-host/mini-spk-broker@.service` | 15 |
| `deploy/spk-host/PRIVATE-BROWSER-BOOTSTRAP-2026-09-27.log` | 39 |
| `deploy/spk-host/PRIVATE-BROWSER-BOOTSTRAP-2026-09-27.md` | 90 |
| `deploy/spk-host/PROFILE-UPGRADE.md` | 55 |
| `deploy/spk-host/README.md` | 244 |
| `deploy/spk-host/SAME-STORE-AND-CHECKPOINT.md` | 270 |
| `deploy/spk-host/SMOKE-2026-09-27.md` | 74 |
| `deploy/spk-host/SPAWN-GATE-PROBE-2026-09-27.md` | 27 |
| `deploy/spk-host/spk-ingest` | 44 |
| `deploy/spk-host/spk-ingest-prepared` | 149 |
| `deploy/spk-host/spk-install-phase` | 105 |
| `deploy/spk-host/spk-publish-host-identity` | 65 |
| `deploy/spk-host/spk-qualify` | 109 |
| `deploy/spk-host/spk-stage-prepared-inbox` | 124 |
| `deploy/spk-host/spk-var-volume` | 325 |
| `deploy/spk-host/STREAM-CONTINUITY.md` | 95 |
| `deploy/spk-host/tests/ingest-prepared-custody.sh` | 18 |
| `deploy/spk-host/tests/stage-inbox-recovery.sh` | 31 |
| `deploy/spk-host/tests/var-volume-import-untrusted.sh` | 39 |
| `deploy/spk-host/USER-TENANCY.md` | 53 |
| `deploy/spk-host/WS-AUTHORITY-LEASES.md` | 85 |
