# Mercurial (hgweb) — repackaged spk

Repackage of Mercurial for the fresh app set (SPK-FRESH). The heavy build
lives on dregg-forge under `/srv/spk-build/mercurial/` (see `build.sh`,
`finish.sh`, logs there; state notes in `spk-notes/mercurial.md`):

- `pkg/opt/python` — CPython 3.13.5 + mercurial 7.2.4 (pip, from sources.json).
- `pkg/opt/app/runner.py` — copy of `runner.py` here; grain-start config
  generation, first repo init, wsgiref hgwebdir server on 127.0.0.1:8000.
- `appdef/` — this directory plus the packed `.spk` output in `out/`.

Pack with the sandstorm-308 `spk` tool
(`/srv/spk-build/etherpad/toolchain/sandstorm-308-unpack/sandstorm-308/bin/spk`):

    spk keygen mercurial.key            # app id printed here
    spk pack -k mercurial.key appdef/sandstorm-pkgdef.capnp out/mercurial-7.2.4-1.spk
    spk verify out/mercurial-7.2.4-1.spk

Signing key (secret, 0600, never committed): the Mac's
`~/.dregg-secrets/spk-keys/mercurial.key`, mirrored on the forge at
`/srv/spk-build/mercurial/mercurial.key`.

The icon is a placeholder monogram (upstream exposes no stable SVG endpoint);
swap `branding/mercurial.svg` when an official mark is available.
