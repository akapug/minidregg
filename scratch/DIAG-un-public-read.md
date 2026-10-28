# un-public-read DIAG (scratch/DIAG.md is another lane's tracked file; this one is ours)

Red: the anonymous public reader gets 403 on every published document (demo-dry, candidate e89fe7b8b).

## What answers 403, and why

- Gateway/anonymous path: fine. mini-web forwards the cookieless GET to the public body; the body's
  doc route (`web/body.rs`, `site.route(["doc", NAME])`) does a signed read as the public subject.
- Reference lookup: fine. refs/welcome.json in the public workspace names target 12881843939966565825
  and capability 9883098191428022900, imported from the helper's inbox hand-off (journal confirms).
- Host read: REFUSES. `refused: no-grant: this key holds no grant covering this target and operation
  (phase observation)` (Host refused query, effect no-record). Same refusal from the shell as `public`
  (`doc show welcome`), so it is not web-specific.
- Cause: the publication's grant has `maxCost 0`. Publish runs `delegate ID NAME PUBLIC observe 0`
  (web/body.rs publish route; deploy/demo-seed/seed.sh publish_public; INSTALL.md section 7). The
  child capability in house/workspace/proposals/pub-welcome/intent.json is `"maxCost":"0"`.
  Every signed read is judged with `cost := (intentCodec.encode intent).length`
  (Kernel/NativeObservationController.lean `requestAt`), and
  `Theory/AuthorizationDeclaration.lean` `scopeCoversCheck` requires `request.cost <= scope.maxCost`.
  A ceiling of 0 therefore covers no read: `Capability.Admissible` fails and the Host reports noGrant.
- Probe on demo-dry (infra, a298031c78e86d651): `delegate probe-w welcome 12330442335703059863 observe 50000`
  + submit + publish -> imported as refs/welcome-<cap> -> GET /doc/welcome-<cap> = 200 with the text;
  the old ref (maxCost 0) still 403.
- Why no row caught it: jweb-frontend's `public-reader` row only asked `GET /` -> 200|502 with the
  public body being the member itself; no row published to a second subject.

## Fix
Publication ceiling = 50000 (`PUBLIC_READ_MAX_COST`, body.rs; seed.sh; INSTALL.md). Rows added to
journey.d/jweb-frontend.sh (second member as public reader, publish, anonymous 200, front-doc,
unpublished refused, revoked 403).

## Separate red
The poisoned consent transport (502) is lane/un-consent-reconnect 0b88b837f, not this lane.
