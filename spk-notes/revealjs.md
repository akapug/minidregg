# reveal.js markdown decks (replaces Hacker Slides) — repackaging state

App slug: `revealjs` · SPK-FRESH row 12 (docs/SPK-FRESH-2026-10-29.md line 51):
Hacker Slides 0.4.0 (2016, no releases, src jacksingleton/hacker-slides@3e5a0e4d) →
decision **(a) successor: current reveal.js behind the markdown-deck grain interface**, P1.

## Step 1 — plan ✅ DONE (2026-10-29)

- **Upstream**: reveal.js **6.0.2** (latest release, published 2026-09-10).
  Source: https://github.com/hakimel/reveal.js — release tarball, tag `6.0.2`
  (**NO `v` prefix** — `v6.0.2` URL 404s; see step 2). 6.x ships a prebuilt
  `dist/` (incl. `plugin/markdown/`), so no upstream build step — use dist/ as-is.
- **Build approach**: plain build dir on dregg-forge at **/srv/spk-build/revealjs**
  (NOT vagrant-spk): dist/ + `deck.md` default + zero-dep Node `server.js`
  (GET static, GET/PUT `/deck.md` → `/var/deck.md`). Pack with Sandstorm 308 `spk`.
- **Manifest**: `bridgeConfig.apiPath "/"` (api interface next to web); app
  marketing name "reveal.js markdown decks"; `webPath` is NOT a BridgeConfig
  field (checked package.capnp:197+) — web at / is the bridge default, nothing
  to declare.

## Step 2 — fetch+build ✅ DONE (2026-10-29)

- Tarball `/srv/spk-build/revealjs/downloads/reveal.js-6.0.2.tar.gz`, sha256
  `441971008b214586af6feeb4d1125ece8f9f9a3803bad9069cdbfa0498576ccf`.
- App tree `/srv/spk-build/revealjs/rootfs/opt/app/` = `dist/` + `index.html`
  (`data-markdown="deck.md"`, separators `^\n---\n?$` / `^\n--\n?$`) + `server.js`
  + `deck.md.default`. Rootfs = Debian 13.7 minbase + nodejs v20.19.2 + bash,
  ca-certificates; `sandstorm-http-bridge` at `/`. chroot-only binaries
  (libnode.so.115 not on host path).
- In-build smoke passed: shell at `/`, `/dist/*` 200, `/deck.md` GET 200, PUT
  then exact read-back, persisted at `/var/deck.md`.
- Tooling: `spk` = `/var/lib/spk-fresh/tools/spk` (symlink →
  `sandstorm-308/bin/spk`); 308 include at `.../sandstorm-308/usr/include`.

## Step 3 — pack+sign ✅ DONE (2026-10-29)

- **Key**: `/srv/spk-build/revealjs/revealjs.key` (0600, 128 B) + Mac copy
  `/Users/ember/.dregg-secrets/spk-keys/revealjs.key` (0600, scp'd, never
  printed/committed). NOTE: `spk keygen -k<path>` requires the keyring file to
  pre-exist (": not found" otherwise) — `: > file` first, then keygen, then
  `spk listkeys -k<path>` to read the app ID.
- **App ID**: `vku2z06we4n4cfpvn28y6159fsgft9nttvvfeg1wndu8szvrtm3h`
  (also `/srv/spk-build/revealjs/app-id`).
- **Package ID**: `667f3752d4a28a084a26eb09ac55e9ea`
- **Artifact**: `/srv/spk-build/revealjs/out/revealjs.spk` (64.9 MB; rootfs
  277M after apt-get clean + lists strip in pack.sh), sha256
  `667f3752d4a28a084a26eb09ac55e9eaa4dc703a029bab9e390bede2cea18adc`
  (= out/revealjs.spk.sha256; packageId is its first 32 hex), built
  2026-10-29T16:42:09Z. `spk verify --details` clean: title, marketingVersion
  6.0.2, icons embedded, MIT, [productivity, webPublishing].
- **Recipe** (source of truth, mirrored at local scratchpad
  `.../scratchpad/kimi-spk/revealjs-recipe/`): `sandstorm-pkgdef.capnp`
  (id = app ID above; `alwaysInclude = ["opt/app","usr","etc",
  "sandstorm-http-bridge"]`; `fileList = "sandstorm-files.list"`; bridgeConfig
  `apiPath "/"` + `saveIdentityCaps = false`; argv `["/sandstorm-http-bridge",
  "8000","--","/usr/bin/node","/opt/app/server.js"]`), `sandstorm-files.list`
  (dokuwiki's 7 lines), `version.txt` 6.0.2, `description.md`, `changelog.md`,
  `icons.py` (pure-stdlib PNG gen; appGrid 24, grain 128, market 150 —
  slide-stack motif, analyzer-verified clean), `pack.sh` (stages pkgdef+embeds
  at $BASE, cleans apt, `spk pack -I… -k… -p…`, verify, sha256).
- Logs: `logs/pack.log`, `logs/pack-outer.log` (verify JSON),
  `logs/verify-details.txt`, `logs/pack.exit` = 0. Launch slip: `&` backgrounded
  the whole ssh chain so `logs/pack.pid` was never written — the run
  self-completed (exit 0); no live PID to track.

## Step 4 — qualify ✅ DONE (2026-10-29)

- **4 PASS of 4 rows** on hbox. World `q1-run/run1` (store `c53f2627221dc52f`),
  import profile standard-v1 (277 M decoded < 768 M bound), letters j (web)
  + k (api), `QUALIFY_STOP=1`. Driver `/tank/lanes/spk-fresh-revealjs/qualify1.sh`
  (local mirror `.../scratchpad/kimi-spk/revealjs-qualify/qualify1.sh`; PID file
  `q1-run/qualify1.pid`, last driver 958970, exited on its own). All stage exits
  0: world1/import1/qualify1/world1-down. Rows at
  `/tank/lanes/spk-fresh-revealjs/qualification1/rows.tsv`:
  web journey PASS 228 s; web write PASS (PUT /deck.md 204, GET 200, exact
  marker read-back); **api journey PASS 287 s; api write PASS (Bearer over the
  api route, same PUT/GET read-back)** — the `bridgeConfig.apiPath "/"`
  manifest need is PROVEN: an api interface sits next to web and carries the
  same write. Teardown `WORLD DOWN store=c53f2627221dc52f
  removal_assertions=0` (`q1-run/world1-down.log`).
- Setup facts for successors: hbox operator is **uid 1000 `hbox`** — world-up
  needs `env MINI_OPERATOR_UID=1000 MINI_OPERATOR_NAME=hbox` (mediawiki lane's
  pattern); lane dirs must be **≤755** (world-up's scratch-custody check
  refused my 775 mkdir defaults — chmod before launching); spk staged at
  `/tank/lanes/spk-fresh-revealjs/cache/667f3752d4a28a084a26eb09ac55e9ea.spk`
  (sha256 verified = pack sha); bin+src copied from the etherpad lane's
  (scripts checksum-identical to this tree); write fn
  `revealjs-writes/write_revealjs.sh`, table `revealjs.tsv`.

## Step 5 — land ✅ DONE (2026-10-29)

- **apps/interfaces/revealjs.json** created (none existed): `deck.replace`
  (PUT `deck.md`, text body, 204, decode status) + `deck.read` (GET
  `deck.md`, 200, decode text), `member-route`, sources = upstream 6.0.2
  tag + `package:667f…/opt/app/server.js`. Validated via
  `uv run --no-project --with jsonschema==4.23.0 --with websocket-client==1.8.0
  python scripts/spk-platform/app-interface/row.py tools revealjs` (exit 0,
  both tools generated; NOTE: row.py takes the app NAME, and `-I` breaks its
  sibling imports). Canonical declaration digest (binding.py `digest`:
  sha256 of sort_keys+compact JSON) =
  `41eaee9b89a31cbc03567dc89f39d99ac0732b70ea31619201e22f45ac7f8863`
  (ethercalc/hedgedoc/datasette rows confirm the formula; etherpad's row
  digest is stale, not a different formula).
- **FEATURED** (apps.rs:302): old `7qvcjh7gk0…` (Hacker Slides, "slides.md
  … <grain>-www" hook — the publish clause dropped, my build has no publish
  route) → `("vku2z06we4n4cfpvn28y6159fsgft9nttvvfeg1wndu8szvrtm3h", "the
  deck is deck.md: PUT /deck.md, GET it back")`.
- **Test repaired** (same commit): `apps_search_shows_the_featured_set_
  first_with_its_agent_hook` had been RED since the etherpad/davros
  repoints (asserted names[0]=="Etherpad" + "every featured appId is in the
  recorded index" — false once FEATURED carries post-index appIds; my
  repoint made it no worse: names[0] failure identical before/after). Now
  asserts the honest invariant: resolvable ranks lead search in FEATURED
  order, nothing after the prefix is featured, first ranked entry carries
  rank + agentHook verbatim. `cargo nextest run -p minidregg-resource-client
  -E 'test(apps)'`: 40/41 PASS; the 1 fail is
  `apps_front_serves_the_publishing_origin_through_the_connector`, green
  2× in isolation — macOS Unix-socket parallel flake (known class), not
  FEATURED-related.
- Old appId intentionally left in: apps.rs fixture test (resolve() over the
  recorded index — still true), apps_worker.rs (test mocks),
  store-qualification.json (historical ledger), APP-MARKET doc (dated
  snapshot), tests fixture (frozen).
- **Row 12** → `QUALIFIED — app vku2z06…; package 667f3752…; version
  6.0.2; API / (web+api); declaration 41eaee9b…`.
- **Commit `41279bd86`** (3 named files, `git commit -F`), pushed
  lane/spk-fresh (fast-forward bf49ce23a..41279bd86; pull --rebase
  refused on OTHER lanes' unstaged files — left untouched, push proved
  remote had nothing new). Landings line appended to
  `…/scratchpad/kimi-spk/landings.md`.

## Aftermath / for a successor

Nothing owed by this lane. Observation for the integrator: ethercalc,
hedgedoc, datasette, sntfy rows record new appIds but FEATURED still
carries their OLD store ids (only etherpad+davros+revealjs repointed);
each repoint needs its FEATURED tuple swapped the same way or the card
keeps pointing at the stale store package.
