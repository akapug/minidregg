# WBO (Whitebophir) — state

ALL STEPS DONE (completed across earlier sessions; this session verified and
finished the last bookkeeping). Landed on origin/lane/spk-fresh.

## 1. plan — done
- Upstream: Whitebophir v2.18.26 (2026-10-28), https://github.com/lovasoa/whitebophir/releases/tag/v2.18.26
- Build: Sandstorm 308 toolchain, Node 22.23.4, plain build dir recipe committed at `apps/packages/wbo/build.sh`
- Manifest: `bridgeConfig.apiPath "/"` → both `web` and `api` interfaces (`apps/packages/wbo/sandstorm-pkgdef.capnp`)

## 2. fetch+build — done
- Build recipe + files list committed: `apps/packages/wbo/` (build.sh, bootstrap.mjs, sandstorm-files.list, pkgdef)
- NOTE: no `/srv/spk-build/wbo` on dregg-forge (box dir cleaned or built elsewhere); the in-repo tree is the durable artifact. Rebuild from `apps/packages/wbo/build.sh` if ever needed.

## 3. pack+sign — done
- Key: `/Users/ember/.dregg-secrets/spk-keys/wbo.key` (0600, 128 B, verified exists; never printed/committed)
- App ID: `j4jvn386t7un76qu6yyw1vwc5ke50t07e38r82kzy4qqg6qq7msh`
- Package ID: `d3b06718d12bc377db7b494679440b91` (version 2.18.26)

## 4. qualify — done
- Harness committed: `apps/packages/wbo/qualify.sh`, `qualify.tsv`, `qualify-writes/{wbo-sio.py,wbo.sh}`, `smoke.sh`
- Proven (apps.rs hook line): socket.io mutation broadcast + replay on fresh connection; saved-board read-back via GET /download/<board> (SVG)
- Corroborating merged commits: `34ffb85aa` (green only when item in saved board), `fb7826e25` (getboard read-back on second socket)
- Doc row 47 of docs/SPK-FRESH-2026-10-29.md: QUALIFIED with the IDs above

## 5. land — done (this session finished the last line)
- apps/interfaces/wbo.json: never existed (nothing to re-pin)
- FEATURED re-pin (old `rhtntjye…` → new `j4jvn386…`): commit `700c70f80`
- Package tree + QUALIFIED doc row: commit `96051e057` (= origin/lane/spk-fresh HEAD; both pushed)
- landings.md append: done this session (`96051e057e608b61b35a16789cfd16bca6664ef5 — WBO (Whitebophir): qualified`)
- Old appId still in `apps/interfaces/catalogue.json` — that is the untouched upstream market mirror; no landing edits it (pattern).

## Nothing next. WBO is fully landed.
