# A public, confined web docuverse and one SPK grain: design

Design review, 2026-10-26, at main `a0db11f8`. Read-only. Nothing was built, run or sent over
ssh. It builds on the scout report `HCLOUD-GAP.md` in this directory (gap numbers `#N` are its
§7) and does not repeat it.

Ember's two constraints are taken as binding:

- **The docuverse and SPK matter; Discord does not.**
- **Confinement over correctness.** Assume the code has bugs. Whatever is internet-facing must not
  be able to reach anything beyond what an anonymous visitor could already do.

The design follows from three facts the code forces:

1. **Every read is a signed observation by an enrolled subject.** No "everyone" or anonymous grant
   exists anywhere in the kernel (§3.4).
2. **The signer must be a full peer.** Every signature passes a consent provider that replays the
   whole Store (`docs/CLIENT-SIGNING-CONSENT.md:70-78`). Whoever signs can therefore read the Store,
   and a browser cannot be that signer today (§2).
3. **Every request to an app is a full Mini transaction on the one serial Host**, and it appends
   to the shared history (`docs/PERFORMANCE-REVIEW-2026-10-03.md:40-75`). Anonymous traffic to a
   grain is therefore a write amplifier against the whole world (§4.6).

**The resulting shape for the first public week:**

- **Reading in the browser is static, and anonymous.** One snapshot renderer runs as the designated
  "public reader" subject with no network listener. A TLS edge serves only its files.
- **Writing happens in the hosted shell, over ssh.** This is shape A.
- **SPK is optional.** At most one grain, behind one shared guest route, in its own Store and its
  own operator uid.

The real design adds per-session dynamic `mini web` under split tenancy, cookie sessions issued by
the self-serve door, and session leases for app HTTP. Browser-held keys wait for a thin-peer
consent producer.

---

## 1. What exists

### 1.1 The `mini web` server (`native/resource-client/src/web.rs`, 1,292 lines, plus 1,493 in `web/`, `web_admission.rs`, `web_actions.rs`)

**Process model.** `mini web --dir WS --listen 127.0.0.1:PORT [--home H]` (`web.rs:52-59`;
`main.rs:3213`):

- It serves one workspace, so one subject and one key, per process (`web.rs:61`, `:74`, `:123-133`).
- The listen address is refused unless it is exactly `127.0.0.1:port` (`web.rs:107-117`). The bound
  address is re-checked after `bind` (`:68-70`).
- Connections go to a pool of 16 threads (`web_admission.rs:7`). Overflow gets a 503 at accept
  (`:36-41`).
- One 10 s deadline covers the request head and form body together (`web_admission.rs:8`, `:52-58`).
- The request head is capped at 16 KiB (`web.rs:40`). The form body is capped at 3 × 64 KiB + 64
  (`web/editor.rs:8`).
- Each response is `Connection: close`. It carries `X-Frame-Options: DENY`, `nosniff`,
  `Referrer-Policy: same-origin` and a CSP with `default-src 'none'` and no scripts at all
  (`web.rs:997-1015`).

**Authentication: who you are is "whoever has the URL".**

- `gate` (`web.rs:187-248`) accepts only GET, HEAD and POST.
- It requires exactly one `Host:` header, equal to `127.0.0.1:PORT` or `localhost:PORT` (the
  DNS-rebinding guard, `:194-209`).
- It refuses any foreign `Origin` and `Sec-Fetch-Site: cross-site` (`:210-220`).
- It requires the first path segment to equal a per-launch 128-bit secret printed on stdout
  (`:62`, `:119-121`, `:226-229`). The secret is compared in constant time (`:177-184`).
- POST is allowed only on an explicit list of editor, create and studio routes (`:241-246`). It
  additionally needs an exact `Origin == "http://{host}"`, form content type, one Content-Length
  and no transfer coding (`web/editor.rs:12-45`; the `http://` is hard-coded at `:26`).
- No cookie, session or CSRF token exists. The path secret plus the Origin check are the whole
  scheme.

**Signing, and where the key lives.**

- Every page that shows kernel state is one or more signed reads under the workspace's own key
  (`web.rs:699-701` → `workspace::signed_view`, `workspace.rs:1383-1440`).
- That path writes an intent into `WS/sources/`, then calls `query_retained` with
  `member_path(workspace, "key")`, a seed file on disk in the workspace (`workspace.rs:1414-1436`).
  Each signature first passes the local consent provider (`client_consent`;
  `docs/CLIENT-SIGNING-CONSENT.md:19-24`).
- The provider replays the deployment Store named by its config. It reads that Store with the
  serving process's permissions (`deploy/shell/README.md:80-83`).
- **The browser holds nothing.** The `mini web` process holds the key and signs for whoever has
  the URL.

**Reads and writes.**

- **Reads:** the workspace's `refs/*.json` (`web.rs:664-680`), retained birth sources (`:704-709`)
  and the Host over the workspace's pinned socket.
- **Writes:** the workspace custody tree (`sources/`, attempts, drafts). A draft-opening GET
  mutates custody too. Such GETs and all POSTs take one process-wide mutex (`web.rs:124-126`,
  `:597`, `:612-618`).

**Verbs reachable** (`web.rs:625-662`, `:599-608`):

- **Reads:** index, `/doc/N`, `/at/H/doc/N`, history, diff, `/doc/N/inspect`, board, room (with
  the `who` member list), object, the resident page, search and search-hit, and Studio read
  pages.
- **Writes:** the document editor (edit, lookup, action), `new-document` (create, lookup, finish)
  and Studio (`new`, manifest, snapshot, compose, fork, preview).
- Streams are 501.
- The help line still calls it "read-only loopback hypertext" (`main.rs:702`). That is stale, since
  POST forms exist.

**What it assumes:**

- **Loopback only.** The process owner is the only user, and reaches it by `ssh -L`. The sshd
  drop-in sets `AllowTcpForwarding no`, which blocks even that (`HCLOUD-GAP.md` §3).
- **One trusted browser.**
- **A Host that answers in seconds.** A pool permit spans the whole Host call, and the Host
  serves one request at a time (`deploy/candidate/INTERFACES.md:206-210`).

**Gates that exercise it:** `journey.d/jweb.sh` (251 lines) and `jdocuverse.sh` (388).

- `jweb` asserts that the web document is byte-identical to `doc show --format html`.
- `jweb` asserts that `--listen 0.0.0.0` and a LAN address are refused (`jweb.sh:13-16`).
- No journey touches Studio, and no unit runs `mini web`.

### 1.2 The hyperdocument model a web UI renders

- **Document.** A document is a cell whose namespaces are documents, atoms, runs, elements,
  fields, conflicts, links, transclusions, marks, annotations and a blinding key
  (`Theory/Hyperdocument.lean:853-866`).
- **Order.** Document order is the pre-order walk of the element tree. An `atom` leaf names a line
  of text and an `embed` leaf names a transclusion. Neither leaf stores bytes itself
  (`:350-362`).
- **Transclusion.** A transclusion stores a complete `StoredTransclusionRef`: source identity
  (history domain, object, entry and semantic roots), an opening descriptor, a mode (`snapshot` or
  `live`), a disclosure scope and a capability ceiling (`:483-531`, `:345-348`). It always writes
  its forward link in the same patch. Backlinks are derived from link history and are never a
  mutable row (`Theory/HyperdocumentOperations.lean:52-62`; `Hyperdocument.lean:541-552`).
- **Mark.** A mark is bold, italic, code, heading or a link (the mark overlays a `LinkRecord`). It
  is laid on a stable range, or on an atom or element at the revision its author read. It goes
  stale when the target moves and is never re-anchored (`Hyperdocument.lean:566-594`).
- **Annotation.** An annotation is anchored to the document, a range or an atom at a revision. Its
  body is inline bytes, a document reference or a sealed fragment (`:596-621`).
- **Revision.** `AtomRecord.revision` and `ElementRecord.revision` are the operation that last
  wrote the record, so an edit naming a position is checked against what its author read
  (`:308-320`, `:364-376`).
- **Guarded patch.** The six actions are create, editAtom, link, transclude, mark and annotate
  (`HyperdocumentOperations.lean:80-86`). Each derives one patch of guarded writes: every write is
  guarded by the exact prior value, or by absence (`:110-120`, `:274-282`). The request's
  `preStateRoot` is the intent's `expectedContentRoot` (`:309`). A stale editor therefore refuses
  rather than merging. The web editor already carries this as "retained editing base" and the
  `EditBase` stamp (`web.rs:263-264`).
- **Shell verbs a web UI would need** (`shell.rs:90`):
  - read: `doc show [--at H]`, `doc outline`, `doc history`, `doc diff`, `doc links`,
    `doc backlinks`, `doc transclusions`, `doc follow`, `doc search` and `doc hit`;
  - write: `doc new`, `doc append`, `doc edit`, `doc insert`, `doc move`, `doc remove`, `doc mark`,
    `doc unmark`, `doc annotate`, `doc link`, `doc range` and `doc transclude … [snapshot|live]`;
  - access (`shell.rs:78`, `:88`): `delegate ID REF RECIPIENT VERB[,VERB...] MAX-COST` and
    `revoke ID REF RECIPIENT`;
  - protected documents: `doc share`, `doc accept` and `doc protect`.
- **Link stores.** `hyperdocument-link-store` is a 4096-byte, non-authoritative recovery byte
  store. `hyperdocument-link-sqlite-store` is the exact-byte compare-and-swap BLOB transport under
  the Lean durable receiver, with a 64 MiB image bound and a whole-image rewrite per commit
  (`native/hyperdocument-link-sqlite-store/README.md:3-27`). Neither parses anything. The web
  front end never touches them; it reaches them only through the Host.

### 1.3 The SPK browser route, end to end (as it ran on 10-02, loopback only)

```
browser ──TLS 1.3, X25519MLKEM768 only──▶ spk-browser-proxy DIR PORT     (operator uid; 127.0.0.1 only)
        ──Unix stream, verbatim frame──▶ DIR/http.sock                 (0600, peer uid must == resident euid)
        ──resident (spk-host resident-run, operator uid) authenticates cookie/bearer against custodian.json
        ──authors op36 plan → inspect → sign with the PARTICIPANT seed → op37 assemble → op34/164 submit
                         (operator socket; one durable Store record per request)
        ──fd 3 Cap'n Proto ──▶ app inside bwrap, mapped subuid, seccomp resident-web.policy
```

**The TLS hop.** `spk-browser-proxy` binds `127.0.0.1:port` only (`spk-browser-proxy.rs:496`). Its
module comment says it is meant to be reached through an owner's `ssh -L` (`:1-5`).

- It speaks TLS 1.3 with the single key-exchange group X25519MLKEM768 (`:52-59`, `:78`).
- It allows at most 136 connections (`:29`).
- It authenticates nothing itself.
- The certificate is operator-provided, and the browser must be told to trust it
  (`deploy/spk-host/BROWSER-WEBSOCKETS.md:19-22`).

**The custodian.** The resident serves each participant route's `http.sock`.
`serve_dynamic_with_aux` (`http_entrance.rs:960-1145`) accepts only peers whose uid equals its own
euid (`:1100`). Authentication (`:670-738`) works like this:

- **Host and Origin are pinned.** The request's `Host` must equal `custodian.json` `expectedHost`,
  and any Origin must be `https://expectedHost`.
- **Fetch metadata is checked.**
- **Exactly one credential is accepted:** either the `__Host-mini_spk_session` cookie, or an API
  bearer token. Each is checked against the SHA-256 in `custodian.json`.
- **Unsafe methods** need the exact Origin.

The tokens come from `init-custodian` (`http_entrance.rs:306-377`). It writes `bootstrap.token`,
`browser.token` and `api.token` (all 0600) and leaves the operator to hand them over.

- `/__mini/bootstrap` trades the bootstrap token for the cookie, once (`:1311-1381`).
- The tokens never expire (sibling review `spk-host--A-hostd-http-routes.md` §Executive summary,
  item 2).

Admission queues (`http_entrance.rs:741-750`):

- 16 pending requests overall and 2 per subject;
- 64 waiting connections overall and 16 per subject;
- a 30 s queue deadline.

**Who signs.** `spk-host grain route` stores the participant's seed path in the route's dispatch
custody (`grain_route.rs:198-222`). The resident signs every dispatch as that participant
(`grain_route.rs:1-13`). Lean cannot tell host-signed requests from member-signed ones. This is the
same hosted-key model as the shell.

**Who runs as what** (v3 user tenancy, current source):

- **Store operator, broker and residents** all run as the operator uid.
  - The broker is "Operator-owned … never runs with host uid zero" (`broker.rs:1-3`). It refuses
    root at start (`broker.rs:1192`). It runs as `mini-spk-broker@STORE.service`, a *user* unit
    (`deploy/spk-host/mini-spk-broker@.service`; `USER-TENANCY.md:20-25`).
- **Apps** run as broker-chosen subordinate uids, mapped in by `newuidmap`/`newgidmap`
  (`docs/SPK-RESIDENT-PRIVILEGE-BOUNDARY.md:10-60`).
- **Root** is confined to three things:
  - the one-time `install-user-world`;
  - one sudo rule for exactly the one-shot volume helper (`install-user-world:157-162`);
  - the setuid uidmap helpers.
- **The scout's "broker runs as root" is the stale `deploy/spk-host/README.md:34-60`.**
  `USER-TENANCY.md:26-29` says v1 root broker configs are refused.

**What is dead or stale on this route.** `spk-hostd serve-http-unavailable` is the 503 the scout
cites. It is run by no unit, script or journey; with `endpoint.rs` it is about 356 lines of dead
code (`spk-hostd.rs:14-31`; sibling review item 6). `HTTP-CUSTODIAN-CONTRACT.md:66-68` and `:79-81`
still say that the signer and native delivery are unimplemented and that the proxy is one
connection at a time. The 09-30 and 10-02 runs contradict both
(`docs/evidence/2026-09-30-grain-running/README.md:40-46`; `2026-10-02-spk-browser-tls/README.md:18-29`).

**Measured costs:**

| step | 09-30 sntfy on persvati (`grain-running/README.md:32-56`) | 10-02 EtherCalc on loopback TLS (`spk-browser-tls/README.md:21-23`, `:48-60`) |
|---|---|---|
| install | 120 s | 137 s |
| share | 249.5 s (second instance: 882.5 s) | 107 s |
| START | 111.6 s | 145 s; 381.6 s for continue START |
| enrollment | 64.8–221.8 s | 18.7–41.4 s |
| one HTTP GET | 26–59 s, journey-step wall time | – |
| STOP | 411.9–1638.3 s | 453.6 s, of which about 180 s came before the physical stop and 275 s after it |
| WebSocket opens | – | 13.6 s and 15.8 s |
| edit propagation | – | 0.04 s |

### 1.4 mini-sdk and mini-sdk-ts

- **`native/mini-sdk`.** With default features this is the offline core. It builds for
  `wasm32-unknown-unknown`: profiles, typed intents, `explain()`, confirmation-gated signing and
  attempt custody, with no Lean, processes, filesystem or sockets (`lib.rs:13-31`, `Cargo.toml`
  features). The `native` feature adds the consent-process client.
- **Signature schemes.**
  - **Ed25519** (algorithm 1) is the only scheme the Host admits (`signer.rs:4-6`;
    `Compiler/CredentialSignatureAdmission.lean:44`).
  - **Hybrid Ed25519 + ML-DSA-65** (algorithm 2) exists in the SDK only.
  - **Observation intents** must be signed by the subject's current *Ed25519* key
    (`Kernel/NativeObservationController.lean:452-466`).
- **`native/mini-sdk-ts`.** A private package for Node ≥23.6 (`package.json`).
  - It builds its wasm core with `wasm-bindgen --target nodejs` and loads it through `node:module`
    (`src/core.ts:6`). **No browser build exists.**
  - Keys are derived from a raw seed with blake3 (`profile.ts:23-37`). The seed is extractable by
    construction.
  - Its own header says consent is "reached from a browser through a native-messaging bridge"
    (`src/index.ts:6-7`). `docs/design/SDK-DESIGN.md:142-169` designs that bridge as an MV3
    extension and states why: the consent producer is a full peer, and "a browser cannot be one".
    Nothing of the extension exists.

---

## 2. The identity problem in the browser

A stranger with a URL has no key, and Mini has no unauthenticated read (§3.4). So every option
comes down to who holds a signing key, and who plays the consent provider that replays the Store.

| option | who signs | consent provider | works today? | blocker |
|---|---|---|---|---|
| **(a) hosted keys** | the box, per session account | the box (full peer), reading the Store as the session account | yes: the ssh shell does exactly this | key custody is the operator's (`deploy/shell/README.md:3-8`); needs split tenancy (#8) to keep friends apart; Store read by every signer (§5.3) |
| **(b) browser-held keys** | the browser (WebCrypto Ed25519, non-extractable) | **must be a full peer**: replay the whole Store from genesis, including protected cells (`CLIENT-SIGNING-CONSENT.md:70-78`; `deploy/shell/README.md:75-81`) | no | see below |
| **(c) passkeys / WebAuthn** | the authenticator | still needs (b)'s consent | no | see below |
| **(d) anonymous read + hosted-key write** | a designated "public reader" subject held by the box; writers as (a) | box | reads yes (enroll one subject); writes as (a) | nothing new in Lean; "public" is a grant to that subject (§3.4) |

**Why (b) does not work.**

- **The signing half is feasible.** WebCrypto Ed25519 sign is pure Ed25519 over arbitrary bytes,
  which is exactly what the verifier accepts (`credential-signature-verifier/README.md:1-18`). A
  non-extractable key pair, plus a second one for the K-PREROTATE next key, fits IndexedDB.
  Recovery would lose mini-sdk's blake3 seed path, because a non-extractable key cannot be derived
  from a seed.
- **The consent half is not.** The provider is the Lean `minidregg-client-consent` executable,
  running natively over a local Store helper and verifier (`deploy/shell/README.md:60-68`).
  - A browser replay would need the Lean consent closure compiled to wasm, plus the whole Store in
    IndexedDB.
  - Today's consent replay ships the entire world, protected cells included, which is itself a
    disclosure (`CLIENT-SIGNING-CONSENT.md:70-74`).
  - For sizes: the Store image bound is 64 MiB (`hyperdocument-link-sqlite-store/README.md:22`), an
    idle Store is about 320 MB RSS, and the Host ELF is 159 MB (`HCLOUD-GAP.md` §6).
- **Not feasible.** Signing operator-proposed plans without that replay reopens the hole the
  consent model exists to close (`SDK-DESIGN.md:160-166`).
- **No transport either.** No HTTP or WebSocket relay of public socket frames exists. The one
  enrollment Caddy snippet says "Do not add operator-socket routes or a generic Host operation
  endpoint" (dregg-infra `origin/main:edge/mini/templates/enrollment-bootstrap.Caddyfile`).

**Why (c) does not work.**

- **The Host rejects the signed bytes.** A WebAuthn assertion signs
  `authenticatorData ‖ SHA-256(clientDataJSON)`, not the frame, and the Lean side admits only raw
  Ed25519 over the canonical frame (`CredentialSignatureAdmission.lean:44`,
  `NativeObservationController.lean:452-466`).
- **The algorithm is usually wrong.** Most authenticators produce ES256 (P-256), and the verifier
  has no P-256 code (grep for `p256|ecdsa|webauthn` across `native/credential-signature-verifier`,
  `mini-sdk`, `Host/`, `Kernel/` and `Compiler/` finds nothing).
- **Supporting it would be a large job.** It needs a new algorithm code, a Lean frame for
  `clientDataJSON` (challenge, type and origin checks) and a native P-256 verifier. The result
  still has no consent: a passkey prompt shows the user nothing about what is being signed.

**Recommendation for the first public week: (d) plus (a).**

- **Anonymous visitors read** what authors chose to publish. Publishing means delegating
  `observe` to the public-reader subject; revoking means un-publishing.
- **Writers use the hosted ssh shell** (shape A, #8 and #9). No browser write path exists in
  week 1. A browser write path in week 1 would put a signing process on the internet edge, which
  §5 rules out.

**Recommendation for the real design: (a) in the browser too, per session account.**

- **Each session gets its own `mini web`.** Split tenancy gives each hosted member an account
  `mini-s-NAME`. That account runs its own `mini web` on a Unix socket, behind the edge, reached
  through a cookie session issued by the self-serve door (§7, R1–R2). This keeps one custody model
  for shell and web: the same key file, the same consent replay, the same uid fence.
- **Browser-held keys are the eventual target.** They come only after the thin-peer consent
  producer exists: "a checked read-footprint planner with authenticated granular openings"
  (`CLIENT-SIGNING-CONSENT.md:74-78`). When it does, mini-sdk wasm (rebuilt with `--target web`)
  plus WebCrypto non-extractable Ed25519 is the client, and the edge relays public-route frames
  only. Passkeys stay out unless that producer exists *and* ember wants a P-256 algorithm.

---

## 3. The public gateway

### 3.1 Shape

```
internet ─443─▶ edge (Caddy, uid caddy)
                 ├─ docs.HOST   file_server /srv/mini-public/current   (static snapshot, week 1)
                 ├─ docs.HOST/~NAME/*  reverse_proxy unix//run/mini-web/NAME/web.sock   (real design)
                 └─ grain.HOST  reverse_proxy unix//var/lib/mini-spk-worlds/STORE/edge/ROUTE/http.sock
mini-pubread (uid) ── timer: mini web --read-only --render-static OUT  ── signed reads ──▶ public relay socket
mini-core (uid)    ── mini serve + serve-operator + serve-public-proxy (#12)
```

**Why one TLS terminator, and why Caddy.**

- Caddy does ACME, HTTP/2, WebSocket upgrade and Unix-socket upstreams out of the box.
- It is already the dregg-infra edge (`HCLOUD-GAP.md` §5, TLS row).
- Choosing it means `spk-browser-proxy`'s TLS has no public role. Two terminators would be a twin,
  so the proxy is deleted after the edge passes the same journey (§6).
- **The alternative** is to grow `spk-browser-proxy` into the one Rust edge. That needs:
  - an external ACME client;
  - SNI routing to several upstreams;
  - a hybrid-plus-X25519 group list;
  - static file serving.

  That is ember's call (§8, D2). Either way there is one terminator, not two.

**Rate limiting.** Stock Caddy has no rate-limit directive; that needs the third-party
`caddy-ratelimit` module. So per-IP limits go in nftables: a `ct count over 16` per source on 443,
and a meter with `limit rate 30/second burst 60` on new connections. Behind that sit the
per-process bounds already in code: web pool 16, custodian queues 16/2/64/16, and a 4096-byte
request body cap on the enrollment snippet.

### 3.2 The docuverse: static for anonymous, dynamic for members

**Week 1: a static snapshot of the public reader's view.** A dynamic public `mini web` would put
the following on the internet-facing path:

- a signing process;
- the consent replay;
- about 3 signed reads per page, each about 1 s on the serial Host (`web.rs:792-808`;
  `PERFORMANCE-REVIEW-2026-10-03.md:24`);
- a mutex over custody.

One crawler would queue every shell user behind it. A snapshot keeps the internet-facing surface
to Caddy's `file_server`, and costs nothing on the Host per view. The pages stay derived: `jweb`
already holds the web document byte-identical to `doc show --format html` (`jweb.sh:21`).

**The snapshot renderer.** Add a `mini web --render-static OUT` mode to `web.rs`, not a crawler.

- It walks `names()` (`web.rs:664-680`). For each reference it writes `/doc/N`, its history, and
  the `at` and diff pages that history links to (`render_history`, `:481-496`).
- It renders with the same `Site` methods it serves with.
- It writes relative links under a fixed `/` base instead of the launch secret (`base()`,
  `:554-556`).
- A timer runs it every N minutes as uid `mini-pubread`. It writes to `/srv/mini-public/H/`
  (H = the read height) and flips a `current` symlink.

**Stopgap if `--render-static` is not wanted:** `wget --mirror` against a loopback
`mini web --read-only`, with `--reject-regex 'edit|new-document|studio'`. This is fragile. Without
the reject rule, a crawler following "Edit and inspect" links opens drafts, because draft GETs
mutate custody (`web.rs:612-618`).

**`--read-only`** (needed by both forms):

- `gate` refuses every POST (`web.rs:241-246`).
- `route` refuses `edit`, `new-document`, `studio`, `room/N/new-document` and `room/N/resident`
  (`:629-640`, `:653`).
- The index omits those links (`:747`).
- The mutex is never taken.

**Real design: dynamic per-session `mini web`, grown in place, not a new crate.**

The repository law is to delete twins. `web.rs` already is the docuverse front end, with its gate,
renderer and journeys. A new gateway crate would be a second front end beside it. The changes are
listed below; each is small, and `jweb`/`jdocuverse` gate them.

| concern | today | change |
|---|---|---|
| bind | TCP 127.0.0.1 only (`web.rs:107-117`) | keep that refusal for TCP (jweb's `bind-*-refused` rows stay). Add `--unix PATH` and systemd socket activation (`LISTEN_FDS`). The socket is 0660 `NAME:mini-edge` in a 0750 directory, the same custody shape as `public_proxy::public_directory` with a group (`public_proxy.rs:233-260`) |
| Host / Origin | `127.0.0.1:P` / `localhost:P` and `http://` (`web.rs:194-215`; `web/editor.rs:26`) | add `--public-origin https://docs.HOST`. `gate` then accepts that exact Host, and Origin must equal it; `body_length` compares against the configured origin, not `http://{host}`. Caddy preserves `Host`, `Origin` and `Sec-Fetch-*` by default |
| who you are | per-launch path secret (`web.rs:62`, `:226-229`) | a `__Host-mini_web_session` cookie (`Secure; HttpOnly; SameSite=Strict; Path=/`) issued by a one-shot bootstrap, **the same mechanism** as the custodian's `/__mini/bootstrap` (`http_entrance.rs:1311-1381`). Move that code into one small shared module both binaries link, rather than writing a second bootstrap. The self-serve door (#9) mints the bootstrap link at signup |
| CSRF | exact Origin on POST, form type, `Sec-Fetch-Site` | unchanged, plus SameSite=Strict. No token is needed: CSP forbids scripts and forms are same-origin |
| request size | 16 KiB head, about 192 KiB form | unchanged. Caddy `request_body max_size 256KB` in front |
| timeouts | 10 s ingress, 10 s write (`web.rs:560`) | the Host may take 5–10 s on a write (p99 10 s, `HCLOUD-GAP.md` §6). Caddy `response_header_timeout` 120 s; the web permit already spans Host work |
| concurrency | pool of 16 per process | per session that is ample. The real ceiling is the serial Host (§4.6); per-session `CPUQuota` and `TasksMax` in the unit (§5) |
| logs | stdout errors | Caddy access logs without query strings and without cookie or authorization headers |

### 3.3 Anonymous read policy: what is "public" in a Store?

Nothing is public by default, and there is no notion of a public read root or an "everyone"
observe grant. Since FIX-DISCLOSE, every observation request carries the subject's signature. The
Host checks that signature against the subject's current live Ed25519 key before it reads anything
about the targets; an unenrolled caller gets `unknownKey` (`NativeObservationController.lean:438-466`).

Three things look like "public" and are not:

- **`Holder.bearer`.** It authenticates possession, not identity (`Theory/TypedAuthorization.lean:227-236`).
  But the request carrying it still needs an enrolled signer.
- **`TargetAudience.publicView`.** This means "no encryption audience" (`Kernel/DeclaredResourceController.lean:1477-1505`).
  It is not anonymous access.
- **The fn native-prefix publication.** It exports the *entire* accepted prefix of its Store
  (`docs/FN-PUBLICATION-DISCLOSURE.md`, "What the current R discloses"), so it must not be used to
  publish to the web.

**So, concretely:** "public" means "observable by the designated subject `public`". The operator
enrolls that subject with no funding and no factory grant. An author publishes with
`delegate ID doc public observe 0` (`shell.rs:78`) and un-publishes with
`revoke ID doc public` (`:88`). The snapshot lags a revoke by at most one timer period; the banner
must say so.

What a publisher reveals beyond the text:

- the target ids of links out of a published document, shown as "not in your workspace"
  (`web.rs:408-413`);
- for a published room, its members and when each last wrote (`web.rs:947-966`).

**Unverified:** how the public reader learns of a new delegation. That needs the reference JSON
`import` (`shell.rs:71`), or `inbox`. I did not trace whether `inbox` lists incoming observe grants.

A Lean-level public read ("audience everyone", or an unauthenticated read path) is not needed for
this design. It would reopen what FIX-DISCLOSE closed.

---

## 4. One SPK grain in public

### 4.1 Minimal confined shape

**The grain lives in its own world.** That means its own Store, Host, `mini serve`, clock and
certifier, under its own operator uid `mini-grain`, separate from the docuverse world under
`mini-core`.

- **Why.** Every app HTTP request is a full serial Mini transaction that appends a record
  (`PERFORMANCE-REVIEW-2026-10-03.md:40-75`). Anonymous grain traffic would otherwise starve the
  docuverse Host, grow its history and hit the tail bound: writes are refused after 256 uncertified
  heights (#6).
- **What stays separate.** Broker names already carry the Store id (`deploy/spk-host/README.md:64-76`).
- **The caveat.** The volume id binds only (deployment domain, app)
  (`grain-running/README.md:79-89`). Give the grain world its own deployment domain.

**The route.** One shared guest route:

- one participant session, ticket and enrollment, for a hosted `guest` subject funded by the
  sponsor;
- `expectedHost=grain.HOST` (no port; the Origin check is `https://expectedHost`,
  `http_entrance.rs:675`);
- the route socket in a 0750 directory, group `mini-edge`.

**The edge.** Caddy reverse-proxies `grain.HOST` to that `http.sock` and supplies the guest
cookie. With `header_up Cookie "__Host-mini_spk_session=<browser token>"` the visitor's own cookies
are replaced, and the custodian receives exactly one credential.

- **Unverified:** whether the chosen app needs its own cookies. The custodian forwards ordinary
  cookies only when they arrive in the same header (`http_entrance.rs:710-733`).
- No per-visitor token is issued in week 1.

**One code change is required.** The custodian accepts only peers whose uid equals its own
(`http_entrance.rs:1100`). With no change, the edge would have to run as the grain operator, and
an edge RCE would then be the Store operator.

- **Change:** accept a peer whose uid is the resident euid, *or* whose gid is a configured edge gid
  read from `custodian.json`. Check it with `SO_PEERCRED` (the code already reads `ucred`), in a
  0750 directory owned by the group.
- **Unchanged:** the token check remains the authentication.

**App choice.**

- **EtherCalc** is the only app with browser-shaped evidence: WebSocket co-editing over TLS,
  10-02. That was with older binaries, and the evidence asks that no more expensive journeys run
  on that kernel (`spk-browser-tls/README.md:62-65`).
- **sntfy** is the M6 package (pinned by `fetch-test-spk.sh`). Its 09-30 evidence is curl only.
- **Recommendation.** sntfy for the M6 gate. EtherCalc for the public demo, only after one
  candidate-binary browser run through the edge passes.

**Concurrency is "a handful of visitors".** With one guest subject, every visitor shares
`MAX_PENDING_PER_SUBJECT = 2` and `MAX_WAITING_PER_SUBJECT = 16` (`http_entrance.rs:741-750`).
Each request costs at least a second of fixed work (8 image hashes plus 5 spawns, `PERFORMANCE-REVIEW`
§1) plus Host queueing.

**Availability hazard.** One uncertain dispatch fences every participant of the grain until
operator recovery (sibling review item 13, `dispatch_delivery.rs:113-124`). With anonymous,
flaky-network clients, a public grain will need babysitting. **That breaks the "without
babysitting" bar** unless ember accepts it (§8, D4).

### 4.2 The broker does not need root, and Debian 13 helps

The broker is already unprivileged (§1.3).

**What still needs root, on Debian 13:**

- `install-user-world install …` once;
- the sudo one-shot `mini-spk-volume-helper` (it does the loop ext4 mount, freeze and thaw; kernel
  mounts need root);
- setuid `newuidmap`/`newgidmap` from the `uidmap` package;
- `/etc/subuid` and `/etc/subgid` ranges;
- linger for `mini-grain`.

**User namespaces.**

- **On hbox, the failures come from Ubuntu's AppArmor userns restriction.** That restriction is
  `kernel.apparmor_restrict_unprivileged_userns=1` (`docs/PIPELINE-HBOX.md:184-199`). It causes both
  the setgroups EPERM and the profiled `mini-grain-bwrap` workaround.
- **Debian 13 lacks that restriction.** It ships unprivileged user namespaces enabled, so
  `deploy/grain-host/resolve-bwrap` falls back to `/usr/bin/bwrap`, and `install-user-world` skips
  its ACL grants when the profiled copy is absent (`install-user-world:138-150`). **Unverified on a
  real Debian 13 VM.** The first M6 run there decides it.
- **The `m6grain` known-red is a test-harness problem, not a product one.** The hbox runner
  executes `install-user-world` from a private extract outside the sudoers paths
  (`scripts/pipeline/required-rows:71`).

### 4.3 PQ-only TLS: recommend hybrid-preferred with classical fallback at the public edge

`spk-browser-proxy` accepts only X25519MLKEM768 and has a test proving that classical clients fail
(`spk-browser-proxy.rs:52-59`, `:811-815`). Support for that group, from my knowledge (not verified
in this session):

- **Default on:** Chrome and Edge 131+, Firefox 132+ on desktop, and Safari on iOS/macOS 26.
- **Fail the handshake:**
  - Safari 18 and earlier, which covers every Apple device not yet on the 26 releases;
  - older Android WebViews;
  - curl and Python built on OpenSSL older than 3.5;
  - Go clients older than 1.24;
  - most crawlers and link-preview bots.

A public demo that fails for every not-yet-updated iPhone is the wrong trade. The content is a
devnet, so harvest-now-decrypt-later risk is negligible.

**The recommended setting** is X25519MLKEM768 preferred with X25519 fallback, TLS 1.3, which I
believe is Caddy ≥2.10's default under Go 1.24. Verify it on the deployed binary with
`openssl s_client -groups X25519MLKEM768` (OpenSSL 3.5) and again with `-groups X25519`.

PQ-only stays meaningful on paths whose clients are ours, such as `mini` over ssh. If ember wants
the edge PQ-only anyway, it is one line, and the cost is the list above (§8, D3).

### 4.4 Token issuance for a stranger

- **Week 1:** none. The shared guest route's browser token lives in the edge config.
- **Real design:** the self-serve door (#9) creates the stranger's session, ticket and enrollment,
  then registers a new route on the *running* generation with no restart
  (`deploy/spk-host/HOT-ROUTE-ENROLLMENT.md:1-49`). It hands the stranger a one-time bootstrap
  link.
  - **Limits:** 64 routes per generation (`:70`). The share costs minutes (249–882 s), so issuance
    must be asynchronous ("your access is ready in a few minutes").
  - **Restarts:** every generation change requires re-enrollment (`grain-running/README.md:23`).
    A STOP or START therefore invalidates every stranger's route until it is re-enrolled.

### 4.5 STOP latency: why minutes

`lifecycle_v3_stop_service.rs` `run` (`:1166-1330`) is a chain of Mini operations. Each one is
signed, assembled and submitted through the serial Host:

1. BEGIN (`stop_begin_native::submit_once`, `:1239`);
2. claim authoring, plus the fresh op26 claim (`submit_fresh_once`, `:1259`);
3. the physical fence (`fence_exact`), which is quick;
4. re-inspections, the custodian-signed report, and the op38 completion with its exact readback
   (`:1004-1075`).

Each signed step pays the following:

- Host spawns for author, inspect and signatures;
- the Host image pin check, which re-hashes the 159 MB ELF on each call (about 0.09 s each, 7–8
  per action; `PERFORMANCE-REVIEW-2026-10-03.md:52-66`);
- the consent replay;
- the Host's per-request whole-history rebuild after any write (`:130-140`);
- queueing behind every other request on the single Host thread.

The 10-02 split (about 180 s before the app stopped, about 275 s after, 309 CPU-seconds in the
command unit; `spk-browser-tls/README.md:55-60`) puts the time in this Mini work, not in process
termination. STOP gets longer as history grows: 412 s at the first stop and 1,638 s at the last on
09-30. Remedies (a) and (b) from the performance review, the pin cache and in-process codecs, cut
the fixed part. Nothing short of fewer records per lifecycle cuts the growth part.

### 4.6 Cgroup limits per grain

**Today.** Broker size classes are written into per-app slices:

| class | `MemoryMax` | `CPUWeight` | `TasksMax` | `IOWeight` | `/var` | WebSocket opens | WebSocket bytes per minute |
|---|---|---|---|---|---|---|---|
| S | 512M | 50 | 256 | 50 | 512 MiB | 32 | 4 MiB |
| M | 1G | 100 | 512 | 100 | 1 GiB | | |
| L | 2G | 200 | 1024 | 200 | 2 GiB | | |

All classes set `MemorySwapMax=0` (`broker.rs:59-91`, `:902-903`).

**Missing:**

- **A CPU ceiling.** `CPUWeight` only shares the CPU under contention, so a spinning app can take
  every core while the Host is idle. Add `CPUQuota` per class (S 50%, M 100%, L 200%).
- **A cap on the whole grain world.** Put a `MemoryMax` on the world's user slice, for example
  1.5G on a cx33.
- **IO delegation.** Confirm that the user manager delegates the `io` controller on Debian 13's
  systemd. If it does not, `IOWeight` in a user slice is inert (unverified).

### 4.7 What the M6 hook must do

`journey.sh` registers step M6 (`:1008`) and finds no `journey.d/m6.sh`, so it reports UNBUILT
(`:970-975`). `scripts/gates/journey-unbuilt.tsv:2` gives the reason: root on a grain host. The
pipeline row `m6grain` already runs the scenario through `two-world-journey.sh`, which calls
`grain-journey.sh` (`journey-rows:482-545`).

Two drivers for one claim would be a twin. **Recommendation: `m6.sh` is a thin delegate**, not a
second scenario. It must do the following:

1. **Check prerequisites.** Read `SPK_HOST_BIN` from the hook environment. Exit 5 (UNCONFIGURED)
   naming the missing input when any of these is absent: linger, a subuid range of at least 32,
   `uidmap`, `sudo -n` for `install-user-world`, or the pinned sntfy (`fetch-test-spk.sh`). Use
   the same probes as `row_m6grain`.
2. **Run the scenario.** Run `two-world-journey.sh full BIN BIN RUN SPK` into
   `$JOURNEY_STEP_DIR`. The last stdout line is the `result.log` path; the last stderr line is the
   first failing step.
3. **Add an edge phase** (new, in `grain-journey.sh`, so the pipeline row gets it too). Start a
   Caddy, or the chosen terminator, on a loopback port with a test certificate, pointed at the
   route socket. Then:
   - a GET with `Host: grain.test`, the cookie and `Origin: https://grain.test` returns 200, and
     the Store's op34 count advanced by one;
   - the same GET without the cookie returns the custodian's refusal, and the Store count is
     unchanged;
   - a WebSocket open reaches 101;
   - with the peer-gid change (§4.1), the edge runs as a uid other than the operator.
4. **Record, do not gate, the STOP wall time.**

---

## 5. Confinement for the web and SPK units

### 5.1 The uid map

| uid | runs | may read | may write | sockets |
|---|---|---|---|---|
| `caddy` (edge) | Caddy | `/srv/mini-public` (read-only), its certificates, the guest browser token (in config) | its ACME state, logs | listens 80/443; connects `unix:` sockets whose directory group is `mini-edge` |
| `mini-pubread` | the snapshot timer (`mini web --read-only --render-static`) | the `public` workspace and key; the docuverse Store, read-only (consent replay) | its workspace custody; `/srv/mini-public/*` (it owns the tree, Caddy only reads) | connects the public relay socket (group `mini-public`); **no network** |
| `mini-core` | docuverse `mini serve` (Host child), `serve-operator`, `serve-public-proxy` (#12), clock, certifier | Store | Store | operator socket 0600; public relay 0660 group `mini-public` |
| `mini-s-NAME` | hosted shell (ssh); later `mini web@NAME` | own home and key; Store read-only (consent) | own home | public relay (group); later own `web.sock` 0660 group `mini-edge` |
| `mini-grain` | grain-world `mini serve`, user broker, residents | grain Store, grain state | same | grain operator socket; route `http.sock` 0660 group `mini-edge` |
| app subuids | the SPK app in bwrap | package image (read-only), own `/var` | own `/var`, tmpfs | fd 3 only; private netns |
| root | `install-user-world` (once); sudo volume helper (one-shot) | – | – | – |

### 5.2 Hardening per unit (systemd)

**All of them:**

- `NoNewPrivileges=yes` (except the resident unit, which needs setuid uidmap; already documented);
- `ProtectSystem=strict`, `ProtectHome=yes` (or `tmpfs` plus explicit `BindReadOnlyPaths`),
  `PrivateTmp=yes`, `PrivateDevices=yes`;
- `ProtectKernelTunables`, `ProtectKernelModules`, `ProtectKernelLogs`, `ProtectControlGroups`,
  `ProtectClock`, `ProtectHostname`;
- `RestrictNamespaces=yes` (except the grain world);
- `LockPersonality=yes`, `RestrictSUIDSGID=yes`, `RestrictRealtime=yes`;
- `SystemCallArchitectures=native`, `SystemCallFilter=@system-service`, `UMask=0077`.

**Per unit:**

- **Edge.** `AmbientCapabilities=CAP_NET_BIND_SERVICE`, `RestrictAddressFamilies=AF_INET AF_INET6
  AF_UNIX`, `ReadOnlyPaths=/srv/mini-public`, `MemoryMax=512M`, `TasksMax=256`.
- **`mini-pubread`.** `RestrictAddressFamilies=AF_UNIX`, `IPAddressDeny=any`,
  `ReadOnlyPaths=<docuverse Store>`, `ReadWritePaths=<its workspace> /srv/mini-public`,
  `MemoryMax=1G` (consent replay plus Host image), `CPUQuota=100%`, `RuntimeMaxSec=30min`.
- **`mini web@NAME`.** `User=mini-s-NAME`, `RestrictAddressFamilies=AF_UNIX`, `IPAddressDeny=any`,
  `ReadWritePaths=/home/mini-s-NAME`, `ReadOnlyPaths=<Store>`, `MemoryMax=512M`, `CPUQuota=50%`,
  `TasksMax=64`. Socket-activated with an idle exit, so an idle member costs nothing.
- **Grain world.** Its own slice with `MemoryMax`. Units keep the broker-rendered properties
  (§4.6) plus `CPUQuota`.

### 5.3 What an RCE reaches, stated honestly

- **The edge (Caddy).**
  - It can read the static snapshot, which is public anyway.
  - It holds the guest grain token, so it can act as `guest`, which any visitor can do.
  - It can connect to `mini-edge` sockets and present bytes there. Every one of those still
    authenticates with its own token or cookie: the custodian's hashes, and `mini web`'s session
    cookie.
  - **It has no key, no Store and no operator socket.** This is the boundary ember asked for, and
    it holds by construction.
- **`mini-pubread`.** It is not internet-reachable: it reads Host replies and writes files. A
  compromise (for example through a malicious document payload in the renderer) reaches the
  `public` key, which holds only observe grants. It also reaches **read access to the whole
  docuverse Store**, because the consent provider is a full peer.
- **A per-session `mini web@NAME` (real design).** It reaches that member's key and workspace,
  **and read access to the whole Store**, for the same full-peer reason.
  - So **"that uid's sessions and nothing else" is not achievable while hosted signing needs a
    full-peer consent replay.**
  - What is achievable: no other member's *key* and no write to the Store. It can still *read*
    every unprotected cell; protected fragments stay ciphertext without device keys.
- **The resulting rule.** The public box runs a **demo world whose whole Store is treated as
  world-readable.** That is consistent with today's "devnet, re-genesised" stance
  (`deploy/shell/FRIENDS.md:40-43`). It must never hold private friend data, and the join page
  must say so.
- **The thin-peer consent producer is also the confinement fix.** It removes Store read from
  signers, and browser-held keys need it too.
- **The grain resident.** It holds the participant seeds of its routes and the grain operator
  identity. It can reach the docuverse world in no way, because that world has a separate Store,
  uid and sockets. That is the payoff of §4.1.

---

## 6. What to delete or not build on this path

| item | lines | why |
|---|---|---|
| `spk-hostd.rs [deleted 469d69a5]` + `src/endpoint.rs` + `http_entrance::serve_resident`/`serve_unavailable` (`:1221-1239`) | 42 + 314 + about 20 | run by nothing. It is the 503 the scout read as "by design". Delete together with the duplicate `init-custodian` entry point |
| `deploy/spk-host/HTTP-CUSTODIAN-CONTRACT.md` | 104 | contradicts the code (signer and delivery "unimplemented", proxy "one connection"). Rewrite it whole as the custodian contract, or fold it into the spk-host README |
| `deploy/spk-host/README.md` "Who runs what" root-broker text (`:34-60`, `:147-150`) | about 35 | twin of `USER-TENANCY.md`, which says root broker configs refuse. Rewrite the section whole |
| `native/spk-host/src/bin/spk-browser-proxy.rs` | 840 (320 tests) | if Caddy is the edge (D2), it has no role left: it is loopback-only and uses operator-trusted certificates. Delete it after the edge passes the M6 edge phase plus `jspk10-ws.py` through the edge. If D2 picks Rust, this binary *is* the edge and grows instead |
| `deploy/grain-host/host-frontend.rs` + `HOST-FRONTEND.md` | 616 + 61 | a hand-written public-op allowlist (`host-frontend.rs:295-332`) that twins `serve-public-proxy` with a group (`public_proxy.rs:233-260`) (sibling deploy review item 10) |
| `journey.sh` step M6 placeholder + `journey-unbuilt.tsv:2` | 2 | replaced by the thin `m6.sh` delegate (§4.7) |
| Discord: `native/discord-entrance` (3,101 lines, all files), `deploy/discord/` (286), `native/mini-keys/src/server/discord.rs` (171) | 3,558 | **do not build #18** (application, Caddy route, roster automation). Deleting the code is ember's call (D6): it is tested against a fake Discord and dormant, and under the "everything replaces" law, dormant code is budget |
| Studio on any public surface: `web/studio.rs` (359), `workspace/studio.rs` (602), `workspace/studio_preview.rs` (222) | 1,183 | it has no producer, no publication, and the deleted Gen-1 shape (`README.md:82`). `--read-only` refuses it. Keep it loopback-only or delete it (D7) |
| `mini web`'s per-launch path secret (`web.rs:62`, `:119-121`, `:226-229`) | about 15 | replaced by the cookie session in R2. Do not keep both |
| loopback-only wording: `main.rs:702` "read-only loopback hypertext"; `web.rs:1-14` | – | fix with R1. The TCP loopback refusal itself **stays** (jweb rows) |
| a second bootstrap/cookie implementation | – | **do not write one** for `mini web`. Share `http_entrance`'s (R2) |
| three hand copies of Lean's ordinary-header allowlist (`http_entrance.rs:415-436`, `dispatch_web_input.rs:332-381`) | about 70 | sibling finding. On this path they matter because the edge forwards browser headers. Derive them from `Kernel/ApplicationDispatchAdmission.lean:116-120` |
| a public HTTP relay of Host frames | – | **do not build** before thin consent. Without it, a browser signer is the hole the consent model closes |
| passkey algorithm support | – | **do not build** (§2) |

---

## 7. The week-1 build list (revised after ember's rulings, 2026-10-26)

**The rulings.** Everything is on in week 1:

- the ssh shell;
- the web docuverse;
- one SPK grain (EtherCalc);
- Hermes residents;
- PAY;
- Discord, through Caddy on `demo.dregg.online`, with the roster automated by the self-serve door.

D1 yes. D2 Caddy (delete `spk-browser-proxy` once Caddy terminates). D3 hybrid with X25519
fallback. D4 yes. D6 ships. D7 delete Studio. D8 yes, stated on the join page. D9 yes.

**D5, sntfy against EtherCalc.** sntfy is *not* materially cheaper to make public, so EtherCalc
stays.

- **What sntfy saves is gate work only.** It is already the pinned M6 package
  (`fetch-test-spk.sh`, sha `bc424d5f…`). Choosing it would remove one pin item (P-S0 below, S).
- **What sntfy costs in steady state is higher.** Its browser UI subscribes by polling or long
  streams, and each poll is a full Mini transaction plus a Store record (`grain-running/README.md:46`;
  `PERFORMANCE-REVIEW-2026-10-03.md:75-84`).
- **EtherCalc's steady state is cheaper.** Once open, it is one WebSocket under an authority lease
  of about 60 s, renewed by a read that writes no Store record (sibling spk-host review, item 8).
  That makes it cheaper on the history and on the tail bound (#6).
- **The rule that follows.** M6 keeps sntfy, as the gate package. The public grain is EtherCalc.

**Names.** `demo.dregg.online` carries the docuverse snapshot, `/join` (the door), `/interactions`
(Discord) and `/mini/v1/*` (PAY enrolment quote and status). The grain gets **its own origin**,
`calc.demo.dregg.online`.

- EtherCalc ships its own JavaScript, so it must not share an origin with the docuverse or the door.
- The custodian pins `expectedHost` without a port (`http_entrance.rs:671-675`).
- This needs two DNS records. The hostname `calc` is my proposal.

**Sizes.** S is under a day, M is 1–3 days, L is more than 3 days. `#N` refers to
`HCLOUD-GAP.md` §7. Items marked *(scout)* keep the scout's size and scope.

**Lanes.** Items in one lane run in order. Different lanes run in parallel. They touch disjoint
files except where a row says "integrator", and the edge lane owns the one Caddyfile. Phases are
serial: phase 1 code must be merged before the phase 2 candidate is built, because a candidate
pins one commit (`deploy/candidate/INTERFACES.md:115-141`).

### Phase 0: decisions and accounts (serial; ember plus one integrator; day 0)

| # | item | size | files | closes |
|---|---|---|---|---|
| 0.1 | Reconcile dregg-infra local `main` with `origin/main` *(scout)* | S | dregg-infra | #1 |
| 0.2 | Host: fresh **cx43, Debian 13** (grain, Hermes and Discord on one box need the headroom, `HCLOUD-GAP.md` §6). DNS `demo.dregg.online` and `calc.demo.dregg.online`. Retarget `install.sh`/`lib.sh` (no 10.10.1.10, no anchor) | M *(scout)* | dregg-infra `edge/tofu`, `edge/mini/install.sh`, `lib.sh` | #2 |
| 0.3 | Ember's external accounts, started now because they gate later phases: Discord application (ID, public key, commands PUT); OpenRouter pool key with a provider-side spend limit plus the `providers.json` rows (pool only, see H3); Solana mainnet RPC endpoints for `rpc.env`; `EMBER_ENROL_ADDRESS` confirmed | S (ember) | `deploy/discord/README.md:96-105`; `deploy/hermes/README.md:50-63`; `deploy/pay/README.md:113-121` | #18, #21, PAY |
| 0.4 | Sponsor key custody (option A or B), funding policy (amount per stranger, birth and write quota, global cap), slower clock (5-minute timer) | S (ember) | `HCLOUD-GAP.md` #16, #10, #7 | #16, #10, #7 (decision) |

### Phase 1: code lanes (parallel; about 3–5 days wall clock)

| lane | # | item | size | files touched | closes |
|---|---|---|---|---|---|
| **W web** | W0 | Delete Studio (D7): routes, POST arms, index link, help text, README row | S | `web.rs:25`, `:243`, `:603-604`, `:629-637`, `:747`; delete `web/studio.rs` (359), `workspace/studio.rs` (602), `workspace/studio_preview.rs` (222); `main.rs:702`; `README.md:82` | #19 (hygiene) |
| W | W1 | `mini web --read-only` (§3.2); jweb refusal rows | S | `web.rs:187-248`, `:611-662`, `:711-749`; `web/editor.rs`; `journey.d/jweb.sh` | #19 |
| W | W2 | `mini web --render-static OUT` (§3.2); jweb row: static page equals the live page | M | `web.rs:554-556`, `:664-680`, `:755-877` | #19 |
| **S spk** | S0 | Pin the EtherCalc SPK: a sha-checked fetcher like `fetch-test-spk.sh` | S | `scripts/spk-platform/fetch-test-spk.sh` (second pin) | #20 |
| S | W6 | Custodian accepts a configured edge gid as well as its own uid (§4.1), plus a test | S | `http_entrance.rs:1100`, `:1153-1219`, `:214-280` | #20 |
| S | S1 | Per-class `CPUQuota` (S 50%, M 100%, L 200%) | S | `broker.rs:59-91`, `:902-903` | #20 |
| S | W8a | `journey.d/m6.sh` thin delegate, plus the edge phase in `grain-journey.sh` (§4.7); fix the `m6grain` runner's sudoers path | M | `journey.d/m6.sh` (new), `scripts/spk-platform/grain-journey.sh`, `scripts/pipeline/journey-rows:482-545`, `required-rows:71`, `scripts/gates/journey-unbuilt.tsv:2` | #20, m6grain known-red |
| S | W5 | Rewrite `deploy/spk-host/README.md` (who runs what) and `HTTP-CUSTODIAN-CONTRACT.md` whole; delete `spk-hostd`, `endpoint.rs`, `serve_resident` (§6) | S | as in §6 | – |
| **H hermes** | H1 | **JPAY6 known-red**: the consent allowlist refuses the `continuityProviderResourceId` and `providerMetering` keys JPAY6 writes (`scripts/pipeline/required-rows:69`). Fix it at its owner. The fix is Lean, so it forces a full native Host rebuild: **this is on the candidate's critical path** | S–M (plus rebuild wall time) | `Host/ClientConsentCore.lean` (allowlist), JPAY6 driver `journey.d/jpay6.sh` | JPAY6, #21 |
| **D discord** | D1 | Roster automation. An unrostered user's `/mini link CODE` is accepted by the entrance: the signed interaction proves the Discord id. It appends a bounded, one-time link request to a spool instead of today's "Ember must add you" (`server.rs:210`). The door's root processor (G2) matches the code to a door-created session NAME and renders the root-owned roster. The entrance itself never writes the roster | M | `native/discord-entrance/src/server.rs:~200-215`, `src/roster.rs`; `deploy/discord/commands.json` (the `link` option); door processor (G2) | #18, #9 |
| D | D2 | Discord custody and log retention, so that `SESSIONS/.discord-custody` (up to 1 MiB per interaction) is bounded: age and size caps, operator-visible | S | `native/discord-entrance/src/session.rs`, `deploy/discord/README.md:48-53` | #17 |
| **G door** | G1 | Door front: `demo.dregg.online/join`, a no-script form (ssh public key, optional "link Discord"), rate-limited, unprivileged uid `mini-door`. It writes one bounded request to a spool and answers "pending". No key, no Store, no sudo | M | new `deploy/door/` (front plus unit); Caddy route (E1) | #9 |
| G | G2 | Door processor: a root oneshot on a timer. It validates the request and enforces the global cap and sponsor balance. It then creates `mini-s-NAME`, does a hosted keygen, renders `authorized_keys`, runs `mini-reenroll NAME` with the fixed funding, and mints the Discord link code (D1). Every step is idempotent by request id | M–L | dregg-infra `edge/mini/render-authorized-keys.sh`, `mini-reenroll`; new `deploy/door/processor` | #9, #10 |
| **P pay** | P1 | Pay-to-enrol through the door. Today a self-enrolled subject becomes a proxy-mode row that cannot sign (`HCLOUD-GAP.md` §3). Instead the door creates the hosted account and key first, then shows that key's memo for payment. The watcher's `enrol` decision (`deploy/pay/README.md:204-214`) then lands on a hosted account. With this, the free door quota and paid enrolment are two inputs to one processor | M | `deploy/pay/` roster-sync input; door processor (G2); `native/resource-client/src/join_solana*.rs` (memo for a box-held key: read only, unverified whether it needs a change) | #9, PAY |

Phase 1 parallelism: lanes W, S, H, D, G and P are independent.

- **Shared item:** D1 and P1 both end in G2. G2's author integrates them.
- **Long pole:** H1. It is the only Lean change, and it gates the candidate build.

### Phase 2: candidate (serial; integrator; hbox)

| # | item | size | files | closes |
|---|---|---|---|---|
| 2.1 | Build one candidate from merged main under `swarm-build`, plus the M7 reference. It must carry `discord-entrance`, `grain-runtime`, `spk-host`, `mini-spk-broker`, `mini-spk-volume-helper`, `mini-keys`, `pay-watcher` and the consent pair; `spk-browser-proxy` is dropped | M (wall) *(scout)* | `deploy/candidate/{lane-build.sh,package.py}` | #3 |
| 2.2 | Genesis params: `issuanceCap`, `fill-genesis`, larger `lifetime`, clock period from 0.4; Hermes route fees in the profile (fees are fixed at purse birth, `deploy/hermes/README.md:190-198`) | S *(scout)* | dregg-infra `edge/mini/genesis-params.json`; `deploy/candidate/params.sh` | #5, #7 |

### Phase 3: box bring-up (three serial steps, then parallel surface lanes)

| lane | # | item | size | files | closes |
|---|---|---|---|---|---|
| box (serial) | 3.1 | Ship, init, operator topology (`ingress.json`: private Host plus public relay), certifier units | S + S–M *(scout)* | dregg-infra `ship.sh`, SHIP-RUNBOOK §4; `deploy/checkpoint/` | #12, #6 |
| box (serial) | 3.2 | Split tenancy on the box, after a scratch run of `jsplit-tenancy.sh`: `mini-core`, `mini-s-*`, `mini-keys`, `mini-discord`, plus the new `mini-pubread`, `mini-door` and `mini-grain` accounts (§5.1) | M *(scout)* | dregg-infra `50-mini-split.conf`, `install.sh` | #8 |
| box (serial) | 3.3 | sshd and DoS: `MaxStartups`, `PerSourcePenalties`, per-session wall timeout, per-member `user-*.slice` caps | S–M *(scout)* | dregg-infra | #11 |
| **E edge** (integrator owns the Caddyfile) | E1 | Caddy with TLS 1.3, hybrid plus X25519 (checked both ways). Routes: static `/` (W2 output), `/join` → door socket, `/interactions` → `127.0.0.1:8793` (the entrance default, `discord-entrance/src/server.rs:67`), `/mini/v1/*` → `127.0.0.1:8794` with a 4096-byte body cap (the enrollment snippet), `calc.` → route socket with cookie injection. nftables per-IP limits on 443, and an egress rule (H4). Access logs scrubbed. Hardening as §5.2 | S | new `deploy/web/Caddyfile`, `deploy/web/nftables.conf`; the dregg-infra snippet `edge/mini/templates/enrollment-bootstrap.Caddyfile` folded in | #19, #18, #11 (edge), §5 TLS |
| **W web** | W3 | Enroll the `public` subject; run the `mini-pubread` service and timer; banner (snapshot height, revoke lag); publish and unpublish in FRIENDS.md | S | new `deploy/web/mini-pubread.{service,timer}`; `deploy/shell/FRIENDS.md` | #19 |
| **S spk** | W7 | Grain world: `install-user-world` (root, once); separate Store and deployment domain under `mini-grain`; user broker; world-slice `MemoryMax`; then **m6 on this box green** before anything public | M | `deploy/spk-host/install-user-world`, `USER-TENANCY.md`; dregg-infra units | #20 |
| S | W9 | EtherCalc install and start; guest participant session, ticket and enrollment; route with `expectedHost=calc.demo.dregg.online`; edge cookie injection; one real-browser run through the edge (`jspk10-ws.py` with `SPK_BROWSER_ORIGIN=https://calc.demo.dregg.online`); then **delete `spk-browser-proxy.rs`** (840 lines) | S (after W7 and E1) | `scripts/spk-platform/jspk10-ws.py` (as is); delete `native/spk-host/src/bin/spk-browser-proxy.rs` | #20 |
| **D discord** | D3 | `mini-discord` as account `mini-discord` with the `mini-session-run` sudo rule (split mode, README:57); env with application ID and key; Interactions Endpoint URL `https://demo.dregg.online/interactions` (Discord's PING and bad-signature test must pass); `native-world.py` against the shipped candidate | S | `deploy/discord/{mini-discord.service,discord.env.example}`; dregg-infra `mini-session-run` | #18 |
| **H hermes** | H2 | bwrap userns on Debian 13, the same probe as W7 (`deploy/grain-host/resolve-bwrap`), checked for the Hermes sandbox too | S | – | #21 |
| H | H3 | `/etc/mini/providers.json` with **pool and homelab rows only** in week 1. `user` rows need ember to pin `onBehalfOf` by hand per friend (`deploy/hermes/README.md:108-118`, `:142-145`), which the door does not automate. Seal the pool key with `mini-keys`; `controller.json` per Hermes; enable `mini-hermes` | S | `deploy/hermes/{README.md,mini-hermes.service}`; `deploy/grain-host/mini-grain-controller@.service` | #21 |
| H | H4 | Hermes needs nothing inbound from the web or edge side: no Caddy route; the snapshot omits resident pages (`--read-only` refuses `room/N/resident`). It needs **egress**: nftables output allowed to the provider endpoint host for uid `mini-keys` only (the broker makes the call), with everything else denied for service uids | S | `deploy/web/nftables.conf` (output chain) | #21 |
| H | H5 | `HERMES-LIVE` row green: real inference on the pool row, with per-call and per-day caps observed and the purse refusal (`no-credit`) observed. Requires H1 in the candidate | S–M | `scripts/pipeline/required-rows:74`; the Hermes journey | #21, HERMES-LIVE |
| **P pay** | P2 | `rpc.env` (mainnet), the `mini-pay-watcher` timer, roster-sync, enrollment-bootstrap on 127.0.0.1:8794; terms pin published with the bundle | S | `deploy/pay/{mini-pay-watcher,*.service,*.timer}`; `deploy/pay/README.md:50-160` | PAY |
| P | P3 | Acceptance: one real mainnet payment by ember through the door, from memo to enrolled hosted account (P1), plus `pay status` and `pay audit` | S | – | PAY |
| **G door** | G3 | Door live: front plus processor timers, cap and sponsor-balance alerts | S | `deploy/door/` | #9, #10 |
| ops | O1 | Alerting (health, certifier, roster sync, door queue, disk, sponsor balance, Hermes purse); backups with an age recipient and an off-box pull; retention (journald, refusals) | S + S + S *(scout)* | dregg-infra | #13, #14, #17 |
| docs | O2 | Join page and FRIENDS.md: what the node has, **"everything on this box is world-readable"** (D8), Discord ephemeral-but-not-private, the Hermes pool caps, the grain is a shared guest | S *(scout)* | `website/join.html`, `deploy/shell/FRIENDS.md` | #15 |

Phase 3 parallelism: after 3.1–3.3, the lanes E, W, S, D, H, P, G and ops run in parallel.

- **Shared by lanes:** E1 (one Caddyfile and one nftables file, integrator-owned) and the root
  steps (`install-user-world`, the door processor, the sudo rules), done by one root operator, one
  at a time.
- **Serial inside lanes:** W7 → W9, H2 → H3 → H5 and P2 → P3.

### Phase 4: the gate (serial; integrator)

| # | item | size | files | closes |
|---|---|---|---|---|
| 4.1 | `jdeploy3` PASS for this candidate with **every** phase green: the documents, apps, connector and residents phases were red on 10-04. "Everything on" leaves no room for a shell-scoped ruling | **L** *(scout)* | dregg-infra `SHIP-RUNBOOK.md` §0 P8, `jdeploy3` | #4 |
| 4.2 | Teardown and re-genesis notice | S *(scout)* | – | #22 |

**Honest schedule.** Phase 1 is about 3–5 days with six lanes; the door (G2) and H1 plus its
rebuild are the long poles. Phase 2 is one to two days of wall time. Phase 3 is two to three days.
Phase 4 is open-ended (L).

That is roughly two weeks of lane work, not one. The items that can slip week 1 by themselves:

- **#4**, the gate;
- **W7**, M6 on Debian 13, which is unproven;
- **H1**, which needs a Lean rebuild;
- **the rooms red**: the private-rooms row was 0/88 at `4795b657` (`README.md:80`), and Hermes and
  Discord rooms depend on rooms.

### What week 1 does NOT have

The list above is a demo with every surface switched on. It is not the real design, which stays
R1–R8 below. Week 1 has:

- **No browser writes.** The web is a static, anonymous, read-only snapshot. Members write over
  ssh or Discord.
- **No per-member web session and no browser-held key** (R1, R2, R7, R8).
- **No per-stranger grain access.** Every visitor is the one `guest` of one EtherCalc instance,
  queued on two pending slots (R4).
- **No session leases.** Every grain HTTP request is still a Store record (R3).
- **Minutes-long STOP and START** (R5).
- **No `user`-route Hermes.** It is pool and homelab only, because `onBehalfOf` is pinned by hand.
- **No Discord room mirror.** It needs a bot token and the Message Content intent (README:114-123).
- **No privacy.** Every hosted signer can read the whole Store (D8).
- **No grain on the docuverse Store.** The grain lives in its own world (R6 not done).

Nothing in week 1 is a step toward R7. The real isolation fix remains the thin-peer consent
producer.

### The real design (unchanged)

| # | item | size | touches | closes |
|---|---|---|---|---|
| R1 | `mini web` on a Unix socket with socket activation and `--public-origin`; `editor.rs` origin from config; `mini web@.socket/.service` per `mini-s-NAME`; edge `/~NAME/` routes rendered with the roster (as `render-authorized-keys.sh` does) | M | `web.rs:52-117`, `:187-220`; `web/editor.rs:12-45`; new `deploy/web/mini-web@.{socket,service}`; dregg-infra render | #19 |
| R2 | One bootstrap-to-`__Host-` cookie module shared by `mini web` and the custodian; the signup door mints web bootstrap links; the web path secret is deleted | M | `http_entrance.rs:1311-1381` (moved), `web.rs:62`, `:226-229` | #19, #9 |
| R3 | Session leases for app HTTP: one admission per lease, renewals as signed op152 reads, no Store record per request (performance review remedy 1(c)) | L (Lean + Rust) | `Kernel/ApplicationDispatchAdmission*`, `dispatch_native.rs`, `dispatch_delivery.rs`, `stream_continuity.rs` | #20, #7 (growth) |
| R4 | Per-stranger grain routes: the door runs session birth, ticket and enrollment asynchronously, then `grain register-route`; route lifecycle across restarts | M–L | `grain_route.rs`, `resident_route_control.rs`, signup door | #20, #9 |
| R5 | Lifecycle and dispatch fixed cost: Host pin verified once per inode; in-process Lean codecs (performance review 1(a), 1(b)). Shortens STOP and START | M–L | `dispatch_native.rs:260-295`, `PrivateOperator`; a Lean static library | #20 |
| R6 | Two Stores per host made safe: bind the genesis identity into the volume id or the root registration | S–M | `Kernel` volume id derivation, `spk-var-volume`, `install-user-world` registry | #20 |
| R7 | Thin-peer consent producer (checked read-footprint planner with authenticated openings). Unblocks browser-held keys **and** removes Store read from every signer (§5.3) | L (research) | `Host/ClientConsentCore.lean`, `Kernel/NativeClientConsent.lean` | #8 (true isolation), future browser keys |
| R8 | After R7: mini-sdk-ts browser build (`wasm-bindgen --target web`, no `node:module`), WebCrypto non-extractable Ed25519 plus next-key, public-route frame relay over WebSocket at the edge (public ops only, as `public_envelope` filters) | M | `native/mini-sdk-ts/{package.json,src/core.ts,src/profile.ts}`, `public_proxy.rs` | – |

---

## 8. Decisions for ember

**Ruled 2026-10-26** (see §7): D1 yes; D2 Caddy; D3 hybrid with X25519 fallback; D4 yes, in week 1; D5 EtherCalc (sntfy is not materially cheaper, §7); D6 ships through Caddy with door-automated roster; D7 delete Studio; D8 yes, on the join page; D9 yes. The original questions are kept below for the record.

- **D1.** Week-1 browser surface = static, anonymous, read-only snapshot of what authors
  `delegate` to the subject `public`; all writes in the ssh shell. **yes / no**
- **D2.** One TLS terminator: **Caddy** (ACME, static, WebSocket, Unix upstreams; Go in the
  boundary; `spk-browser-proxy` deleted) or **grow the rustls proxy** into the edge (Rust boundary;
  needs ACME, SNI and static work)? **Caddy / Rust**
- **D3.** Public-edge TLS: **hybrid X25519MLKEM768 preferred with X25519 fallback**, or **PQ-only**
  (loses Safari ≤18, older WebViews, curl or OpenSSL <3.5, bots)? **hybrid / PQ-only**
- **D4.** One SPK grain in week 1? It requires a separate grain world, the custodian edge-gid
  change, a green M6 on a Debian 13 scratch VM, and acceptance that a public grain may need
  operator recovery after an uncertain dispatch. **yes / no / after week 1**
- **D5.** If D4 = yes: **EtherCalc** (browser and WebSocket evidence, older binaries) or **sntfy**
  (the M6 package, curl evidence)? **EtherCalc / sntfy**
- **D6.** Discord: stop at "do not build #18", or also delete `discord-entrance`,
  `deploy/discord` and the mini-keys Discord role (3,558 lines)? **park / delete**
- **D7.** Studio (1,183 lines, no producer or publication): keep it loopback-only behind
  `--read-only`'s refusal, or delete it until a producer exists? **keep / delete**
- **D8.** Accept that every hosted signer (shell or web) can read the whole demo Store, and state
  "everything on this box is world-readable" on the join page, until the thin-peer consent
  producer exists? **yes / no**. A "no" means no hosted members on a public box.
- **D9.** The M6 gate: a thin `m6.sh` delegating to `two-world-journey.sh` plus an edge phase, as
  opposed to a second driver. **yes / no**

---

## 9. What I could not verify

- **Debian 13 behaviour:** that `/usr/bin/bwrap` creates the resident namespace unprivileged, that
  the user manager delegates `io`, and the setgroups path. Everything SPK-on-Debian is inferred
  from the hbox failure cause and Debian defaults; no Debian 13 run is recorded.
- **Browser and Caddy facts:** which browsers offer X25519MLKEM768, and Caddy's default curves.
  These come from my knowledge, not from a check in this session.
- **Caddy support for this routing:** whether Caddy's `header_up Cookie` replacement interacts
  cleanly with the custodian's cookie parser (`http_entrance.rs:393-413`), and whether EtherCalc or
  sntfy needs its own cookies.
- **How the public reader discovers new delegations:** I did not trace whether `inbox` surfaces
  incoming observe grants for `import`.
- **Snapshot cost:** the cost of `--render-static` at the demo world's size. Each page is about 3
  signed reads at about 1 s each, so 100 documents with history could take tens of minutes per
  render. The timer period must be set from a measurement.
- **The sibling claims I relied on:** `dispatch_delivery.rs:113-124` (one uncertain dispatch fences
  the grain) and the header-allowlist twins, from `spk-host--A-hostd-http-routes.md`. I did not
  re-read those lines.
- **The brief's reading list:** `docs/OBJECTIVE-BEND-FRONTEND.md` was read for web content and has
  none; it is about the Lean front end. No `docs/HYPERDOCUMENT*.md` exists except the performance
  plan, which I did not need.
- **Untouched:** I did not read the live state of any box, nor `dregg-infra` beyond
  `50-mini-split.conf`, `jsplit-tenancy.sh` and the enrollment Caddyfile on `origin/main`.

## Agreements and disagreements with the sibling crate reviews

**`spk-host--A-hostd-http-routes.md`:**

- **Agreed.** The HTTP entrance is not internet-facing. The custodian signs as the participant.
  `spk-hostd` is dead. `HTTP-CUSTODIAN-CONTRACT.md` is stale. Per-request Lean admission is real.
  An uncertain dispatch fences the grain.
- **Differs.** Its item 14 lists `spk-browser-proxy` as needed "if browsers connect". This design
  removes it from the public path, provided the edge takes TLS and the custodian learns an edge gid.
  Keeping it would make an edge RCE equal to the grain operator, because of the same-uid peer check.

**`resource-client--A-entry-shell-workspace.md`:**

- **Agreed.** Studio is reachable only through loopback `mini web`. The minimal demo arm set is
  shell, socket-proxy, serve, serve-public-proxy, workspace and the rest.
- **Adds.** This design adds the `web` arm, for `--read-only` and `--render-static`, to that set.

**`deploy.md`:**

- **Agreed.** It too finds the root-broker contradiction and the `host-frontend.rs` allowlist twin.
