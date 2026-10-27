# The oracle as a grain: installed through the app market, answering on its own origin

Present state, 2026-10-27, lane `lane/oracle-grain`. Ember's ruling this morning: "yes i want the
oracle to land as a grain if we can get away with it." This file says how it lands on the demo box
through the app market's path (`docs/APP-MARKET-2026-10-27.md`, `deploy/market/INSTALL.md`), what
the operator provisions, what a member does, what a stranger sees, and every refusal by name. The
oracle itself is veri7vn (`~/dev/o7vn`), Oracle7's sibling with an Isabelle spine; its Mini
packaging is ember's codex session's work, committed on main at 2bf5036f and read here as recorded:
`deploy/oracle/README.md`, `docs/oracle-shared-data-packaging.md`,
`docs/oracle-shared-data-acceptance.md`, `docs/oracle-agent-tools.md`,
`docs/oracle-replay-2026-10-27.md`, `deploy/oracle/runtime-v4-receipt.json`.

## 0. Status, said plainly

| piece | state |
|---|---|
| the signed runtime SPK, v4 | **built and independently verified** (codex session): raw SHA-256 `bded240f916b93d51ad5e90ffc12d8a8cc9985e35306105eff69f926b3333ed0`, 91,944,584 bytes, 15,155 members, appId `ephaf4h4cx8f9s36hmukm4yzkznyhqjhvj8efp3at9cru2zn10mh`, version 4; the market's packageId is the first 16 bytes of that hash, `bded240f916b93d51ad5e90ffc12d8a8` |
| the public dataset | **inventory pinned**: digest `32bb3cf1a6337ee2c7b6ec902bb5bfdff11ba1fd5f1fa3b730dc269431b27d0a`, 26 files, 15,046,949,326 bytes (14.01 GiB); the bytes live on hbox at `/othersys/oracle-acceptance-20261027/data-source` (the source the inventory describes; verified byte-for-byte by `spk-data-publish` on every publication) |
| the custodian's data admission | **exists on main, now on this lane** (merge 69f12aaf): `native/spk-host/src/shared_data.rs` opens the operator's publication by the package's signed inventory digest and passes its `data` directory as fd 7; bubblewrap mounts it `--ro-bind-fd 7 /opt/oracle-data` (`sandbox.rs:38`); the spawn gate refuses a fd without the fixed arguments or the arguments without the fd (`spawn_gate.rs:87`); START checks the app uid can read the mount before accepting (`resident_privilege.rs:335`). **No new admission is needed**; what the box needs is the publication present under each world's catalogue (§3) |
| the market pin | **built on this lane**: an operator-local index (`local.json`) merged by `mini apps index-check --local`; a pinned entry carries the whole `sha256`, an optional `packageUrl`, a `class`; the fetcher's `adopt` verb puts a box-local package into the quarantine through the same hash checks; the catalogue shows `pinned` and the pinned class (§2) |
| the import budget | **selectable on a world**: `world-up.sh` writes the broker's `importProfile` from `MINI_IMPORT_PROFILE`; the runtime's 15,155 members need `operator-appliance-v1` (1,800 s) and time out under the standard 120 s (measured by the codex session) |
| the role basis | **fixed on this lane**: the worker's share ticket takes role 0 when the signed bridge declares roles (the oracle: role 0 `Researcher`, permission `query`), the world's `allAccess` otherwise (`apps_worker.rs`, `role_basis`) |
| the journey row `joracle` | **written** (`native/resource-client/journey.d/joracle.sh`), built on `scripts/spk-platform/apps-e2e.sh` (knobs added) and the oracle acceptance harness's publication step; **runs on dregg-build** against a scratch world once the dataset lands there (transfer hbox to build box in progress at the time of writing: §7) |
| the stranger's page | **not in v4**: the bridge serves JSON only; a browser at the origin gets `404 route_not_found` on `/` (`native/oracle-appliance/src/lib.rs:325`). The page is one bounded change to the bridge, a v5 package (§5). Until then the surface is the API on the origin and the agent tools |
| the infra side | **staged in §8** for the infra lane: a volume, two mount units, the pin, the adopt, the broker setting, a Caddy redirect; no egress |

Mini acceptance and public deployment were "separate outcomes" in the codex session's record; this
lane keeps them separate too: the row below is a scratch-world acceptance on the build box, not the
demo box, and nothing here claims a stranger has asked the oracle anything yet.

## 1. The pieces, who runs what

| piece | runs as | does | reaches |
|---|---|---|---|
| **data volume** `/opt/oracle-data` (host path) | mounted by the box (`systemd` mount unit), read-only after publication | holds the operator's publication `public-data/sha256-<inventory digest>/{inventory.json,receipt.json,data/}` (files 0444, directories 0555, owner `mini-core`) and the runtime package `oracle-runtime-v4.spk` | nothing; it is bytes |
| **publication** `spk-data-publish publish` | `mini-core` (the operator), once | streams the 26 files from the source into a staged copy, hashes every byte against the inventory, writes the custody receipt (inode, size, mode, timestamps of every node), renames atomically; refuses a short disk, a hash that differs, an existing stage | the source directory (read), the volume (write, once) |
| **catalogue bind** | the box | `GRAINS_ROOT/spk/public-data` of each world is a bind mount of the volume's `public-data` (a mount unit per world; §3) | - |
| **broker** `mini-spk-broker@STORE` | `mini-core` | `importProfile: operator-appliance-v1` in its `config.json`: 1,800 s to materialise a package (the standard 120 s stays for every other app on the box only if the operator keeps two brokers, which it does not: the budget is a deadline, not a cost; §4) | as before |
| **market pin** `local.json` | written by the operator (root, 0644) under `/var/lib/mini-market/` | one entry: appId, packageId, name, version, `sha256`, `class: L`, no `packageUrl` (the package is adopted from the volume, never downloaded) | `mini apps index-check --local` merges it at every refresh; a collision with an upstream packageId refuses the refresh by name |
| **adopt** `mini-market-fetch adopt` | `mini-market` | copies `/opt/oracle-data/oracle-runtime-v4.spk` into the quarantine through the same checks a download passes (size within 256 MiB, SHA-256 equals the pin and starts with the packageId); meta `url: file:///opt/oracle-data/oracle-runtime-v4.spk` | the volume (read), the quarantine (write) |
| **member turn** `mini apps install bded240f916b93d51ad5e90ffc12d8a8 --class L` | the member (the operator's tour member on the demo box) | births the application as the member's own op 30, delegates hosting to the manager, writes the request cell under `law.apps`; the worker performs `spk-host grain install/start/route` | the worker socket |
| **worker** `mini apps-worker` | `mini-core` | ingest (signature, appId equals the pin's, bridge profile), class L, the share ticket at role 0, the route under the grain's origin | the operator socket, the broker, the quarantine |
| **grain** | app uid, bwrap | `/usr/bin/python3.12 -B /opt/oracle-bin/launch.py`: the adapter on loopback 7070 and the capnp bridge on fd 3; `/opt/oracle` read-only from the image, `/opt/oracle-data` read-only from fd 7, `/var` its private volume | its own loopback; no network (the sandbox floor) |
| **origin** `a<app>.demo.dregg.online` | Caddy, the front | the wildcard block proxies to the front; the front dispatches by `Host` and the member's cookie or bearer to the custodian's route socket | the route socket only |
| **alias** `oracle.demo.dregg.online` | Caddy | a `301` to `https://a<app>.demo.dregg.online/` (an explicit site block, which wins over the wildcard) | - |

## 2. Install through the market, step by step, with the refusals

1. **The operator pins.** `/var/lib/mini-market/local.json`:
   ```json
   {"apps":[{"appId":"ephaf4h4cx8f9s36hmukm4yzkznyhqjhvj8efp3at9cru2zn10mh","packageId":"bded240f916b93d51ad5e90ffc12d8a8",
     "name":"veri7vn oracle","version":"4","versionNumber":4,"author":{"name":"ember (local candidate signing identity)"},
     "upstreamAuthor":"psiloceyeben (Oracle7), veri7vn","shortDescription":"Answers questions with evidence ...",
     "categories":["Science","Reference"],"isOpenSource":true,
     "sha256":"bded240f916b93d51ad5e90ffc12d8a8cc9985e35306105eff69f926b3333ed0","class":"L"}]}
   ```
   `mini-market-fetch refresh` runs `mini apps index-check --in RAW --out index.json --local local.json`.
   Refusals: `pinned sha256 ... does not start with packageId` (a pin that cannot be the package it
   names), `local entry ... carries no sha256 pin`, `local entry <id> collides with the index's <name>`
   (the pin would shadow a public package: refused, the previous index stands). The catalogue then
   shows the entry with `pinned: {sha256, packageUrl: null, class: "L"}`, `suggestedClass: "L"`, and
   `packageUrl: "file: adopted by the operator (...)"`: no URL is invented for it.

   app.sandstorm.io cannot host this package (it is signed with a local candidate identity, and its
   dataset is not a Sandstorm concept), so the pin is the index entry. If a later package is to be
   fetched by URL, the entry carries `packageUrl` (https only) and the fetcher refuses any bytes but
   the pinned hash (`pinMismatch`); that host then needs an egress row like the index's (§8). The
   oracle needs none.

2. **The operator adopts the package.** `sudo -u mini-market mini-market-fetch adopt
   bded240f916b93d51ad5e90ffc12d8a8 bded240f...3333ed0 /opt/oracle-data/oracle-runtime-v4.spk`.
   Refusals: `sizeOverProfile` (over 256 MiB), `pinMismatch:<sha>` (the file is not the pinned bytes),
   `adopt takes an absolute regular file` (a symlink, a relative path). A fetch of a pinned id whose
   entry has no URL is refused `localAdoptionRequired`: the fetcher never downloads it from anywhere.

3. **The operator publishes the dataset** (once per volume, §3) and binds it into the world.

4. **The member installs.** `mini apps install --app bded240f916b93d51ad5e90ffc12d8a8 --class L --dir WORKSPACE`
   (the member names the class; `auto` would size a 92 MB package `M`, and the oracle needs `L`).
   The worker's `admit` refuses `unknownApp` (not in the catalogue), `classRefused` (not S, M, L), the
   funding and birth refusals the market doc lists. `advance` then: package from the quarantine
   (`packageIdMismatch` if the copy hashes differently), `spk-host grain install ... --class L`
   (`unverifiedSignature`, `unsupportedBridge`, `appIdMismatch` when the signed appId differs from the
   pin's), `grain start`. START is where the dataset is checked: the broker's launcher reads the
   package's signed `minidregg-data.json` from the verified image, opens
   `GRAINS_ROOT/spk/public-data/sha256-<digest>`, rechecks the whole tree against the receipt, and
   refuses, before BEGIN, with `signed public-data <digest> custody refused: <cause>`: the directory
   absent (ENOENT), `published inventory differs from signed attachment digest`, `published data
   entry custody changed` (a file not 0444, a directory not 0555, an owner that is not root or the
   operator, a group- or world-writable mode), `published data identity or timestamps changed`. The
   worker surfaces these as `installRefused`/`undecided` with the exact cause; the catalogue's
   verdict names them.

   Materialisation of 15,155 members takes minutes; under `standard-v1` the first attempt timed out
   at 120 s with INSTALL prepared and no START (codex session). Under `operator-appliance-v1` the
   member's `install` is `undecided: installing` with its exact retry until the ingest unit finishes;
   the row retries every 15 s for up to 130 attempts (the profile's 1,800 s budget plus slack).

5. **The route and the origin.** The worker shares the grain to the installing member at role 0
   (`Researcher`, `can ask questions`, the one permission `query`), enrols the session, binds the
   route with `expectedHost = a<app>.demo.dregg.online`, and publishes `origins/a<app>.json`. Other
   members get the grain by `mini apps share --grain a<app> --to <member>` (the door's welcome can
   do this for the tour's visitors; that is the door lane's call: §9).

## 3. The data volume on the demo box

**Size.** The publication is 15,046,949,326 bytes of data plus two small files: 14.01 GiB. The
publisher refuses to start unless the destination has that much free (a preflight, not a
reservation). The demo box's 20 GB state volume cannot hold it beside the Store, the images and the
grain volumes; the box itself (ccx23) has 16 GB of RAM, so the dataset is never in memory either: it
is read through the page cache. A **dedicated volume of 32 GB** holds the publication (14.0 GiB),
the runtime package (88 MB) and leaves room for one more revision of a changed file set without a
second volume; a 20 GB volume would hold exactly one publication with no room for the next revision
and no room for the transient source (below). Money and the exact size are ember's (batch).

**Fetch and verification.** The publisher copies from a source directory: so the source must be
on the box for the length of one publication. Two shapes; the first is what rehearsal #3 uses:

- *Direct, from hbox*: `rsync -a` from `hbox:/othersys/oracle-acceptance-20261027/data-source` over
  ssh to the volume's `incoming/` (hbox can reach the box as this lane's build box showed; the
  operator supplies the key once), `spk-data-publish publish --store /opt/oracle-data/public-data
  --source /opt/oracle-data/incoming/data-source --inventory .../data-inventory.json`, then remove
  `incoming/`. The source and the publication coexist for the duration: 28 GiB peak, hence 32 GB.
  The inventory file is pinned by its SHA-256 (`32bb3cf1...`) before anything is copied; a source
  whose bytes differ from the inventory is refused by `publish` at the differing file
  (`source hash differs from inventory: <path>`), and nothing is published.
- *Standing source, for every re-genesis*: a Hetzner Object Storage bucket seeded once from hbox
  with the 26 files and the inventory; the box fetches it with the operator's read credential into
  `incoming/`, publishes, removes. Same verification; the bucket is a cache, never an authority (the
  inventory is). Cost is ember's; the bucket is the right place for the dataset to outlive hbox.

`spk-data-publish audit --store ... --inventory-sha256 <digest>` re-hashes every published byte
(bit rot) and is the operator's periodic check; START's recheck is metadata only (inode, size,
mode, timestamps of every node against the receipt) so a 15 GB rehash is not on the critical path.

**Who owns it.** `publish` runs as `mini-core` (the operator) and writes files 0444 and directories
0555 owned by it; the custody check accepts root or the operator as owner and refuses any mode
with group or world write. The volume is mounted `ro` after publication (a remount in the mount
unit's companion, §8), so even the operator cannot rewrite it without an explicit remount.

**Into the world, into the grain.** `open_published` opens `GRAINS_ROOT/spk/public-data/sha256-<digest>`:
a path under the operator's world root, which a re-genesis changes (new Store, new `GRAINS_ROOT`).
The publication is not copied per world: `GRAINS_ROOT/spk/public-data` is a **bind mount** of
`/opt/oracle-data/public-data` (a `systemd` mount unit per world, `Options=bind,ro`). The custody
code follows no symlinks, so a symlink there is refused (`public_data_mountpoint_refuses_missing_and_symlinked_ancestors`),
and a bind mount is a real directory to it; inode and device identity of the receipt are those of
the volume's filesystem and do not change across bind mounts. The launcher then passes the `data`
directory as fd 7 and bubblewrap mounts it read-only at `/opt/oracle-data` inside the grain
(`--ro-bind-fd 7 /opt/oracle-data`). The signed package carries an empty `/opt/oracle-data`
directory and one signed symlink per externalised file (`/opt/oracle/root/relstore/relations_v2.sqlite3
-> /opt/oracle-data/root/relstore/relations_v2.sqlite3`), so the adapter's `--data-root /opt/oracle/root`
is unchanged and NLTK finds WordNet at `NLTK_DATA=/opt/oracle-data/root/nltk_data`.

The sandbox floor admits exactly this and nothing wider: the mount is fixed in name and mode; the
app cannot name a host path, a URL or another dataset; a package without the attachment gets no fd
7 and no mount; a fd without the arguments or the arguments without the fd refuse the spawn.

## 4. The grain's resource class

**Class L**: `MemoryMax=2G`, `MemorySwapMax=0` (`broker.rs:82`), the class the codex session's
acceptance ran two oracle grains in. Oracle7's head measured 1.96 GB resident on its own
(`~/dev/o7vn/docs/performance/fleet.md`); the appliance's adapter, engine workers and the bridge
run under the one limit. The 15 GB of SQLite is read through `pread`/mmap; those pages are charged
to the grain's cgroup as page cache and reclaimed under the limit, so a cold relation query is
slower, not an OOM. What is **not measured**: the grain's `memory.peak` after a question and the
cold-start time of the adapter's store check; `joracle` is the place to read both (batch).

**STOP** took 1,049.752 s in the acceptance, dominated by two cold full-history inspections; the
merged op 155 (`APPLICATION_STOP_INSPECT`) serves the inspection from the resident Host's retained
verified session (`docs/oracle-replay-2026-10-27.md`). The first served inspection still pays one
walk. The worker's `stop` is synchronous; `mini apps stop` returns the decided state when the
custodian is done, with no spinner in between.

**Import** materialises 15,155 members into the image store: minutes, inside the broker's
`operator-appliance-v1` budget. It is a deadline the operator selects in the broker config, not a
package declaration; every other app on the box imports well inside it.

**Disk per grain**: the materialised image (501 MB decoded) in the world's image store (on the 20 GB
state volume) and the grain's `/var` volume (class L's quota) for the conversation workspace.

## 5. A stranger's question, end to end

**Today (v4).** The stranger is a door member (`/join`) whose shell holds the grain: the operator
installed it once as the tour's member and shared it (`mini apps share`). `mini apps open --grain
a<app>` prints the one-time bootstrap token and the origin; the browser posts it at
`https://a<app>.demo.dregg.online/__mini/bootstrap`, the front sets the `__Host-mini_spk_session`
cookie for that origin only. From there:

- `GET /health`, `GET /capabilities`: JSON (the bridge's `get`, `lib.rs:314`), the latter naming the
  operation discovery routes and `"deployment_content_hashes_checked_by_adapter": false`.
- `POST /query` `{"request_id","conversation_id","text"}` with `Content-Type: application/json`: the
  custodian authors and admits the dispatch (op36/37/34), the bridge forwards to the adapter on
  loopback 7070, the reply carries the original HTTP status and the complete JSON.
- `GET /` in a browser: `404 route_not_found` (`Accept: text/html,...,*/*;q=0.8` is accepted as JSON,
  then the path is unknown). There is no page in v4.
- Agents: `mini_oracle_discover` / `mini_oracle_call` through the controller's `applicationServices`
  profile (`docs/oracle-agent-tools.md`), which is how the resident Hermes room asks it.

The reply (an actual one, from the retained acceptance run):

```json
{"outcome":"completed","reply":{"status":"answered",
 "path":"organ:relation>form:author>READ>FRAME>LINK>RELATE:fwd:P50>CHECK:P50>BIND>EXPAND>VERIFY",
 "response":"Walt Whitman. Leaves of Grass is a collection of poetry by American writer Walt Whitman (1819–1892).",
 "provenance":{"kind":"verified_reach","by":"relation_form","form":"author","replaced_path":"compose:bridge"},
 "latency_ms":11.5,"zero_model_gate":{"lm_calls":0,"transformer_calls":0},
 "evidential":{"input_marked":null,"answer_licensed":"unknown"},
 "references":["wd:Q132042 P50 wd:Q81438","simplewiki_2cc693b35bb6a059e9dc02d2"]}}
```

**The page (v5): "exactly what was checked".** The experience document (door 8) wants the answer
with its evidence and the machine-checked function it rests on, and never "the answer is proved".
The honest rendering of the fields above, and the smallest change that produces it:

- `response` as the answer; `path` as the route taken, each `>` step a line; `references` as the
  rows read (`wd:Q132042 P50 wd:Q81438` is a Wikidata statement in `relations_v2.sqlite3`;
  `simplewiki_...` a passage id); `provenance.kind`, `evidential.answer_licensed` and
  `zero_model_gate` as three labelled facts (verified reach; licensed direct/unknown; zero model calls).
- **What was checked**: for a `/invoke` of a `live_direct` operation the descriptor from
  `GET operations/<id>` names the exported kernel and its sources; the page shows that operation id
  and the kernel's binary hash from the receipt (`deploy/oracle/runtime-v4-receipt.json`
  `kernel_overlay_binaries`: `earth`, `space`). For a `/query` answered by a relation reader the
  checked thing is the relation kernel's read (the `CHECK:P50` step); the page says so and names the
  store. It never says "proved": a kernel's theorem is about the computation on the rows received,
  not about the English reading, the model of the world or the rows' truth (veri7vn's README, and
  `capabilities` says the adapter did not check deployment content hashes).
- **Where**: the bridge, `native/oracle-appliance/src/lib.rs:314-333` (`Session::get`): when `path`
  is empty and the context's `Accept` prefers `text/html`, answer `200 text/html` with a static page
  (a form that `fetch`es `POST /query` with the JSON above and renders the fields); every other
  request unchanged. The adapter (`~/dev/o7vn/tools/appliance/serve.py`) is not touched: the JSON is
  the contract and o7vn's semantics stay o7vn's. The change re-stages and re-signs the package
  (`deploy/oracle/stage.py`, `pack`), so it is **version 5 with a new packageId and a new pin**; the
  v4 receipt pins the bridge's source hash, which is why this is not a hot patch. Owner: the codex
  session's recipe on hbox; this lane names the change and does not fork it.

**Who may ask.** The grain is private: the front answers `403 private grain a<app>` without a
credential and nothing in that answer touches Mini. A public, credential-less oracle is a different
contract (an anonymous route is not something the custodian issues today) and is not proposed
here; the tour's visitors are members.

## 6. Refusals, by name

| where | refusal | means |
|---|---|---|
| `index-check --local` | `local entry <id> collides with the index's <name>` | the pin would shadow a public package; the previous index stands |
| `index-check --local` | `pinned sha256 <sha> does not start with packageId <id>`, `pinned class is S, M or L`, `pinned packageUrl must be a bounded https URL`, `carries no sha256 pin` | a malformed pin refuses the whole local file |
| `mini-market-fetch adopt` | `sizeOverProfile`, `pinMismatch:<sha>`, `adopt takes an absolute regular file` | the file is not the pinned package |
| `mini-market-fetch fetch` of a pinned id | `localAdoptionRequired` | a pin without a URL is never downloaded |
| `mini-market-fetch fetch` with a pin | `pinConflict:<sha>` (a `pin` verb naming another hash), `pinMismatch:<sha>` | the bytes are not the pinned ones |
| `mini apps install` | `unknownApp`, `classRefused`, `funding`, `birthRequired`, `meteredGrantRequired` | the member turn's own refusals (market doc §3) |
| the worker | `packageIdMismatch`, `unverifiedSignature`, `appIdMismatch`, `unsupportedBridge`, `installRefused` | the ingest's verdict, also written to the catalogue |
| the broker, before INSTALL completes | the ingest unit exceeds the profile's deadline | `undecided: installing` with its exact retry; under `standard-v1` the oracle always does |
| START | `signed public-data <digest> custody refused: <cause>` | dataset absent, wrong revision, modes/owner/identity changed; refused before BEGIN, no running or uncertain generation |
| the custodian's route | `403` without the credential, `404 no such grain` | the front's answers; nothing reaches Mini |
| the bridge | `406 json_not_acceptable`, `404 route_not_found`, `405 head_unsupported`, `415`/`400` on a non-JSON body, `400 context_unsupported` | the signed API's bounds |
| the adapter | `busy`, `unknown operation`, invalid arguments, `terminal refusal` (an uncertain ordering is withheld rather than answered) | kept with their original status and body; completion is not an answer |

## 7. Verification: what ran where

- Mac: `scripts/host-operations.py check` green after the merge (op 155 with `effect: none`);
  `cargo check -p minidregg-resource-client --bin mini`; `cargo test -p minidregg-resource-client --bin mini apps_`
  (the catalogue tests, including `apps_index_check_merges_operator_pinned_entries_and_refuses_collisions`);
  `bash -n` and `shellcheck -S warning` on the four scripts.
- dregg-build (`/build/lanes/oracle-grain`): the merged tree's Lean Host (op 155, 790 modules, the
  closure built from the integration lane's warm `.lake`), consent and Rust roles under
  `swarm-build`; the extra bins `spk-data-publish` and the stream reader's `inspect`; then
  `world-up.sh` with `MINI_IMPORT_PROFILE=operator-appliance-v1` and `joracle.sh --box` against it
  with the dataset transferred from hbox (`/build/oracle-source/incoming`, rsync, PID file on hbox).
  The row's result is recorded in the lane report, not claimed here.
- Not run: anything on the demo box; a stranger's question; the v5 page.

## 8. Infra, staged (for the infra lane: dregg-infra `demo-vm`, `edge/demo/`)

Everything below is on `dregg-demo`; nothing holds a secret but the hbox read key, which is ember's.

1. **Volume**: one Hetzner Volume, 32 GB, ext4, attached to `dregg-demo`, mounted at
   `/opt/oracle-data` by a mount unit (`opt-oracle\x2ddata.mount`, `Options=defaults,nodev,nosuid,noexec`);
   `install -d -o mini-core -g mini-core -m 0755 /opt/oracle-data/public-data /opt/oracle-data/incoming`.
2. **Source**: `rsync -a hbox:/othersys/oracle-acceptance-20261027/{data-source,data-inventory.json,oracle-runtime-v4.spk}
   /opt/oracle-data/incoming/` (as `mini-core`, with the read key ember supplies; or from the Object
   Storage bucket once it exists). `sha256sum data-inventory.json` must print `32bb3cf1a6337ee2c7b6ec902bb5bfdff11ba1fd5f1fa3b730dc269431b27d0a`
   and `sha256sum oracle-runtime-v4.spk` must print `bded240f916b93d51ad5e90ffc12d8a8cc9985e35306105eff69f926b3333ed0`
   before the next step; otherwise stop.
3. **Publish**: `sudo -u mini-core /var/lib/mini/candidate/current/bin/spk-data-publish publish
   --store /opt/oracle-data/public-data --source /opt/oracle-data/incoming/data-source
   --inventory /opt/oracle-data/incoming/data-inventory.json` (up to an hour on a volume; the
   publisher refuses if less than 14.1 GiB is free). Keep its JSON line as the receipt. Then
   `mv /opt/oracle-data/incoming/oracle-runtime-v4.spk /opt/oracle-data/` and remove
   `incoming/data-source`. Remount read-only: `mount -o remount,ro /opt/oracle-data` (and put
   `ro` in the mount unit from now on).
4. **Catalogue bind, per world**: a templated mount unit
   `var-lib-mini\x2dspk\x2dworlds-STORE-spk-public\x2ddata.mount` with `What=/opt/oracle-data/public-data`,
   `Type=none`, `Options=bind,ro`, `RequiresMountsFor=/opt/oracle-data /var/lib/mini-spk-worlds/STORE/spk`;
   the mount point directory is created by `install-user-world` for the world (`spk/` exists);
   `install -d -o mini-core -m 0755 .../spk/public-data` before the first mount. A re-genesis
   repeats this one unit for the new STORE and nothing else.
5. **Broker**: `importProfile: "operator-appliance-v1"` in `/var/lib/mini-spk-worlds/STORE/broker/config.json`
   (the v3 config `mini-spk-broker.example.json` plus this key), then `systemctl --user restart
   mini-spk-broker@STORE` as `mini-core`.
6. **Pin and adopt**: install `local.json` (§2.1) as root 0644 at `/var/lib/mini-market/local.json`;
   `systemctl start mini-market.service` (the refresh merges it; `head -c 400 index.json` shows
   `"pinned": 1`); `sudo -u mini-market /usr/local/lib/mini/market/mini-market-fetch adopt
   bded240f916b93d51ad5e90ffc12d8a8 bded240f916b93d51ad5e90ffc12d8a8cc9985e35306105eff69f926b3333ed0 /opt/oracle-data/oracle-runtime-v4.spk`.
7. **Egress**: none. The oracle grain has no network (the floor); the package is adopted, not
   fetched; the dataset arrives once by the operator's hand. No nftables row changes.
8. **Resource class**: the grain is class L (2 GiB); the box's 16 GB holds it beside the broker
   (512 MiB) and the rest of the candidate. Nothing to configure beyond the member's `--class L`.
9. **Install**: as the tour's member, `mini apps install --app bded240f916b93d51ad5e90ffc12d8a8 --class L`
   and retry its exact id until decided (minutes); note the grain id `a<app>` and the origin.
10. **Origin alias**: an explicit Caddy site block `oracle.@DOMAIN@ { redir https://a<app>.@DOMAIN@{uri} 301 }`
    beside `calc.`/`nano.` (explicit blocks win over the wildcard); DNS already covers it through
    `*.demo.dregg.online`. The custodian pins `expectedHost = a<app>.demo.dregg.online`, so the alias
    is a redirect, not a second Host.
11. **Checks**: `curl -sS -o /dev/null -w '%{http_code}\n' https://a<app>.demo.dregg.online/` (403, private);
    `curl -sS -I https://oracle.demo.dregg.online/ | head -1` (301); as the member, through the
    cookie, `GET /health` 200 and one `POST /query`; `sudo -u mini-core spk-data-publish audit
    --store /opt/oracle-data/public-data --inventory-sha256 32bb3cf1...` (the periodic bit-rot check).

## 9. Where the oracle's own shape must change, and what it is not

- **The page**: `native/oracle-appliance/src/lib.rs:314-333` (`Session::get`), one `text/html` branch
  for the empty path; a v5 package; the adapter untouched (§5). Nothing else in o7vn changes for
  this surface. The agent tools and the `/query` JSON are the contract.
- **Store layout**: no change. The split (26 public files outside the SPK, signed symlinks inside,
  `/opt/oracle-data` fixed) is the codex session's and this file keeps it; a changed file set is a
  new inventory digest, a new `minidregg-data.json`, a new package and a new publication beside the
  old one (no garbage collection in the custody module: the operator removes an old revision by hand
  after no package pins it).
- **Door and web lanes**: sharing the oracle grain to each new member on join is a door-lane verb;
  rendering the catalogue's `pinned` field in the `/apps` pane is L12's; neither is needed for the
  row to pass.

This file does not claim the row has passed, a stranger has asked, or the page exists. The lane
report carries the row's result and the batch for the parent.
