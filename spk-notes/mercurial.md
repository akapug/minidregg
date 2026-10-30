# Mercurial hgweb — spk-fresh repackaging state

App: Mercurial (hgweb). Row 14 in docs/SPK-FRESH-2026-10-29.md:53. P1, approach (a) repackage current Mercurial and hgweb.

## Steps

1. [x] plan — done 2026-10-29
2. [x] fetch+build — done 2026-10-29. CPython 3.13.5 + mercurial 7.2.4 (pip) in `/srv/spk-build/mercurial/pkg/opt/python`
3. [x] pack+sign — done 2026-10-29 (details below)
4. [x] qualify — done 2026-10-29 (attempt 3; details in "Step 4 result" below)
5. [x] land — done 2026-10-30, commit `196daf77f` on lane/spk-fresh (pushed; fast-forward over `73027ee02`)

## Step 4 result (2026-10-29)

- **QUALIFIED**: `qualify-3/rows.tsv` = `featured: 2 PASS of 2 rows` on world-3 (store `c094304f611cc8c7`, driver PID 1478140, `qualification-run-3.{pid,log}`)
  - PASS create/install/share/start/enrol/page `/` — 239 s (all six grain-journey phases exit=0)
  - PASS write beneath the HTML: `POST /repo unbundle pushed changeset 7000ca46efe0; GET raw-file 200 holds the text; GET /rev 200` — hand-built HG10UN changegroup pushed over the grain's own route (owner session), read back through hgweb's webcommands
- Teardown clean: `WORLD DOWN store=c094304f611cc8c7 removal_assertions=0` (`world-down-3.log`)
- **Qualified package: `56a636adfcd3f6977de2fc2b82ee68d2` (mercurial-7.2.4-2.spk, appVersion 2)** — appId `1mvdqjv5z596dtyg5fh0p9573x32u5anrfze9rs6wpxthhyejk50`. The r1 package `4c027848…` is dead (failed start-k; kept in the hbox cache only as a record).
- Import profile: standard-v1 (default; decoded ~335M < 768M bound). Class S.

## Step 3 result (2026-10-29, superseded by r2 below)

- **spk**: `/srv/spk-build/mercurial/out/mercurial-7.2.4-1.spk` (55.8 MB, verified signature)
- **appId**: `1mvdqjv5z596dtyg5fh0p9573x32u5anrfze9rs6wpxthhyejk50`
- **packageId**: `4c02784853a64522fea93c443176cfe6` ← FAILED qualify (image lacked lib/lib64/etc)
- **Key** (0600, never printed/committed): Mac `~/.dregg-secrets/spk-keys/mercurial.key` + forge `/srv/spk-build/mercurial/mercurial.key` (keyring format; forge copy for re-packs at `/srv/spk-build/mercurial/keyhome/.sandstorm-keyring` too)
- Pkgdef + runner + branding live in-repo at `apps/packages/mercurial/` (uncommitted; step 5 commits) and on forge at `/srv/spk-build/mercurial/{sandstorm-pkgdef.capnp,branding/,CHANGELOG.md,appdef/}` next to `pkg/`
- spk tool: `/srv/spk-build/etherpad/toolchain/sandstorm-308-unpack/sandstorm-308/bin/spk` (pack with `HOME=/srv/spk-build/mercurial/keyhome`; its `keygen -k` flag is broken — isolated-HOME trick)
- **pkg** (281M after trim): removed `lib/python3.13/{test,idlelib,tkinter,turtledemo,lib2to3}`, `__pycache__`, `share/man`, `include`, pip/setuptools; swept 15 runtime libs + `/lib64/ld-linux` + ca-certificates via `runtime-libs.list` (cp --parents); `hg` shebang rewritten to `#!/opt/python/bin/python3.13`
- **Verified**: `chroot pkg` imports `mercurial.hgweb/ssl/zlib/sqlite3` and runs `hg version` (7.2.4); chroot smoke test served hgweb (`<title>Mercurial repositories index</title>`, repo page `<title>repo: log</title>`) and `hg clone http://127.0.0.1:8123/repo` → CLONE-OK (capabilities/batch/getbundle 200)
- Manifest: `bridgeConfig.apiPath = "/"` (api interface next to web), roles contributor/viewer, permission "push"; command `["/sandstorm-http-bridge","8000","--","/opt/python/bin/python3","/opt/app/runner.py"]`, env PATH includes `/opt/python/bin`, HOME=/var
- Icon is a **placeholder monogram** `branding/mercurial.svg` (upstream has no stable SVG endpoint — mercurial-scm.org/logo.svg 404s, wikimedia misses); swap when an official mark lands

## Runner lessons (hg 7.2.4 / CPython 3.13, `apps/packages/mercurial/runner.py`)

- `hgwebdir(config)` needs a **bytes** path: `hgwebdir(os.fsencode(config))`
- `from mercurial import ui` gives the module; the class is `ui.ui()`
- Do NOT mix in-process `hg.repository()` with hgweb — "duplicate registration for name: branches"; first-run repo init runs as a subprocess `/opt/python/bin/hg init` (fresh process, mirrors grain PATH)
- Runner: config `$HOME/hgweb.conf` (`[web] push_ssl=False allow_push=*`, `[collections] $HOME/repos = $HOME/repos`), first repo named from `SANDSTORM_GRAIN_TITLE` (slug, fallback "repo"), threading wsgiref on 127.0.0.1:8000

## Step 4 (qualify) — in progress 2026-10-29

**Attempt 2 (package 56a636ad, world-2, driver PID 1180709)**: row 1 **PASS** — create, install, share, start, enrol, page / in 218 s (all six grain-journey phases exit=0; the r2 lib fix works — attempt 1's start-k exec ENOENT is gone). Row 2 FAIL — my write driver's repo discovery, not the app: the hgwebdir index's own self-link `href="/"` matched the zero-or-more pattern first → empty repo name. Index hrefs seen (qualify-2/bodies/k): `/`, `/repo/`, `/repo/atom-log`, `?sort=*`, `/static/*`. Fixed qualify-writes/mercurial.sh line 10 to `href="/[A-Za-z0-9_.-][A-Za-z0-9_.-]*/\?"` (≥1 name char); tested against the saved body → discovers `repo`. World torn down clean: `WORLD DOWN store=244ad9fc158b162a removal_assertions=0` (world-down-2.log).

**Attempt 3 (same package, world-3, driver PID 1478140, `qualification-run-3.{pid,log}`, rows `qualify-3/rows.tsv`)** — **QUALIFIED** (see "Step 4 result").

**Attempt 1 (package 4c027848) FAILED at start-k**: bridge `execvp: No such file or directory; argvp[0] = /opt/python/bin/python3`. Root cause: the pkg dir had lib/lib64/etc (15 runtime libs + ld-linux + ca-certs swept) but the packed image did NOT — `alwaysInclude` listed only opt/python, opt/app and the bridge files, and spk pack's dependency scan resolved python's libs against the toolchain, so /lib64/ld-linux was absent from the grain → exec ENOENT. Confirmed by `spk unpack` of the r1 spk (no lib/lib64/etc in image; python3 symlink WAS present — not a symlink problem; our materialize.rs handles symlinks).

**Fix (r2 pkgdef, applied on forge AND in-repo `apps/packages/mercurial/sandstorm-pkgdef.capnp`)**: `alwaysInclude` += `lib`, `lib64`, `etc`; `appVersion = 2`; `appMarketingVersion = "7.2.4-2"`. Repacked:
- **spk r2**: `/srv/spk-build/mercurial/out/mercurial-7.2.4-2.spk` (60.5 MB), sha256 `56a636adfcd3f6977de2fc2b82ee68d2da48ec14a884cd86dc7d9bfdbb4fda6f`
- **packageId (r2)**: `56a636adfcd3f6977de2fc2b82ee68d2` (appId unchanged: `1mvdqjv5z596dtyg5fh0p9573x32u5anrfze9rs6wpxthhyejk50`)
- unpack-check of r2 image: has etc/ssl, lib (runtime libs), lib64/ld-linux ✓

**hbox lane**: `/tank/lanes/spk-fresh-mercurial/` (mode 700 — world-up refuses writable ancestors; attempt 0 died on exactly that). Layout: `repo/` (cp -a of spk-fresh-dokuwiki's checkout), `cache/<pkgid>.spk` (MINI_MARKET_CACHE; holds both 4c027848… and 56a636ad…), `mercurial.tsv` (QUALIFY_TABLE row `k Mercurial <pkgid> S / web`), `qualify-writes/{mercurial.sh,hg-push.py}` (hg-push.py = b8-hg-push.py with a 4th argv `base` so the push/read-back go to `/<repo>` — hgwebdir collection, not `/`; write_Mercurial discovers the repo name from the index at /), `run-qualification.sh` (dokuwiki's pattern: world-up under `flock -o /tank/lanes/world-up.lock`, featured-qualify letter k, QUALIFY_STOP=1, world-down trap). NOTE: the `.exit` file's 0 on a failed run is a script quirk — rows.tsv is the verdict of record; delete the stale `.exit` before relaunching.

## Step 5 result (2026-10-30)

- FEATURED re-pin: apps.rs line 304 `61gh7gnn…` → `1mvdqjv5…`; hook now reads `POST /<repo>?cmd=unbundle … GET /<repo>/raw-file/<rev>/<path> and /<repo>/rev/<node>` (the `/<repo>` collection prefix hgwebdir actually serves — matches the qualified write row)
- docs/SPK-FRESH row 14: `queued` → `QUALIFIED — app/package/version/API` in the table's standing format (this edit rode in on the sibling's Forgejo commit `73027ee02` — commit-others'-work-as-found; not duplicated)
- No `apps/interfaces/mercurial.json` (confirmed again; the doc row carries no declaration sha, matching WBO/Davros rows whose surface is the manifest's own web+api)
- Verified: `apps_search_shows_the_featured_set_first_with_its_agent_hook` PASS on the Mac (1 passed, filtered; queued apps' upstream appIds keep `ranks` non-empty in the recorded index)
- Committed (named files): apps.rs + apps/packages/mercurial/{README,CHANGELOG,runner.py,sandstorm-pkgdef.capnp,sources.json,branding/*} = `196daf77f`; pushed lane/spk-fresh (pull --rebase refused on siblings' unstaged files — left untouched; push fast-forwarded, so remote had nothing newer)
- landings.md appended: `- 196daf77f — Mercurial hgweb: qualified`
- catalogued index snapshots (apps/interfaces/catalogue.json, fixtures) intentionally untouched — they record the upstream market, same as the reveal/dokuwiki landings

## Next

Nothing — all five steps done. The one known debt: the icon is a placeholder monogram (`branding/mercurial.svg`); swap when an official SVG mark lands.
