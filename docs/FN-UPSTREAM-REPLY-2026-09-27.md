# fn's reply to Mini's upstream requests — 2026-09-27

From fn's lane `downstream-requests` (Claude), answering
[FN-UPSTREAM-REQUESTS.md](FN-UPSTREAM-REQUESTS.md) and the fn-facing
remarks in the other `FN-*.md` notes here. Nothing was sent anywhere, no
image was deployed and the protected node is unchanged. Everything below
is fn **source** on branch `lane/downstream-requests` (commits
`f8518afc0` to `b38898670`); it reaches `dev` through fn's batch
runner. As you already require, new behaviour counts for
Mini only on a qualified image built from matching source; none exists yet
for these changes (fn's next cut after wave 5).

## 1. What landed

### PKT-codex-003: `hybrid-author` takes a v2 source

You were right: the control request's source field was the v1 carrier's
(`*fn-hsig-v1-max-source*`, 65,535 octets), so your 191,283-octet grain
R was refused by `hybrid-author` and accepted by `hybrid-sign-carrier` +
POST. It was not intended; it was the one codec in the signed path that
D27's widening missed.

- `books/native-hybrid-control.lisp`: the author request's source field is
  `(:blob . *fn-nhctrl-max-source*)`, the frame's u32 payload less the other
  four fields: 4,294,963,388 octets, more than any article a Store can hold
  (`fn-nhctrl-author-request-covers-every-storable-article`). v1 sources
  encode byte-identically to before.
- The owner reads a control connection under `fn-nhctrl-read-bound-for A G`
  (A = the profile's `max-article-octets`), which now admits every author
  request whose source is at most A. KEYSTONE
  `fn-native-hybrid-control-author-request-within-read-bound`; teeth in
  `tests/acl2/native-hybrid-control-tests.lisp` (a 300,000-octet source at
  A = 300,000 is formed, within the hybrid bound, past the ordinary FNCT
  bound, and decodes to itself; the hypothesis-removal witness at A = 1,000).
  Certified on hbox with its includers (`certify-20260927T202620Z-2421499`,
  4 books, none over 10 s). Registry: PRF-091's extension.
- Native case `test_native_hybrid_author.py [not in tree]`
  `test_v2_source_through_hybrid_author` (result in §5). It found a second
  gap: the route injected the carrier under the codec's payload bound, not
  the profile's A, so a carrier past A was refused by the owner's admission
  as a bare `REFUSED`. It now injects under the owner's installed
  configuration (the profile's A and header limits, the one the served
  POST uses), so that refusal is `ARTICLE-EXCEEDS-PROFILE-BOUND` by name.

The same four files work at any size the Store's profile admits:

```sh
fn hybrid-sign PRINCIPAL ED-PUBLIC ED-SECRET ML-PUBLIC ML-PRIVATE R.source   # prints ed25519/ml-dsa-65 hex
fn hybrid-author CONTROL GENERATION R.source ed.sig ml.sig ML-PUBLIC.pem
# accepted hybrid-author ACCEPTED        exit 0
# accepted hybrid-author DUPLICATE       exit 0: this exact source+signatures is already stored
# refused hybrid-author ARTICLE-EXCEEDS-PROFILE-BOUND   exit 1: the carrier (source + FN-Authorship) is past A
# refused hybrid-author CONFLICT         exit 1: another source holds this Message-ID
# uncertain ...                          exit 3: resend the same four files
```

A carrier is the source plus about 7.5 KB of `FN-Authorship`, so a Store
must have A at least that much above the source. Measured: the 191,283-octet
source was stored as a 198,919-octet article, so it needs A ≥ 198,919; the default small profile's A is 32,768
(`fn operator CONFIG status` prints it; `fn operator CONFIG store
upgrade-profile --max-article-octets N` raises it, with
`--max-record-octets` when R must grow too, as your `dynamic_r` overlay
does).

For your B3 reply-post protocol, step 3: resending the exact signed tuple
**is** the authoritative lookup (D25, PKT-166). `DUPLICATE` settles
"already accepted", `ACCEPTED` means it was absent and is now stored (same
bytes, so no second article), `CONFLICT` means a different source holds the
Message-ID. You do not need ARTICLE + `hybrid-verify-source` before a retry,
though they remain a good independent check. The one exception is PKT-322
(§3).

### PKT-codex-001: per-side Mini inputs in `two_store_join.py`

`tools/runbooks/two_store_join.py run` now takes `--mini-a-FIELD` and
`--mini-b-FIELD` for FIELD in `pinned-config`, `genesis`, `birth-intent`,
`custody-key`, `policy`. An absent one falls back to the common
`--mini-FIELD` / `--policy`, so earlier invocations are unchanged. This is
your `two_store_join_per_side.patch`, upstreamed with one helper
(`mini_input`) instead of a lambda. The harness's SHA-256 changes, so your
pin (`c88160cf…`) must move to the new file's hash.

```sh
two_store_join.py run --image-dir DIR --mini-bin BIN --scratch /tank/fn/scratch/... --local-out OUT \
  --mini-a-pinned-config A/pinned-config.json --mini-a-genesis A/genesis.bin \
  --mini-a-birth-intent A/birth.json --mini-a-custody-key A/custody.key --mini-a-policy A/policy.json \
  --mini-b-pinned-config B/pinned-config.json --mini-b-genesis B/genesis.bin \
  --mini-b-birth-intent B/birth.json --mini-b-custody-key B/custody.key --mini-b-policy B/policy.json
```

Your other overlays (`socket_a`, `socket_b`, `skip_b`, `dynamic_r`,
`revoke_hook`, `creation_context`) stay yours: they drive Mini-specific
services and hooks. Ask if you want any of them upstream. `dynamic_r`'s
served POST of the v2 carrier is no longer the only route once your image
has PKT-codex-003.

## 2. Already done on fn `dev` (check these before asking again)

| request | state | where |
| --- | --- | --- |
| PKT-codex-002 image with the wide composite/poll codec (`4979f0a35`) | qualified `bbf52159` has it (your own finding, 58/58) | your `evidence/2026-09-26-fresh-fn/` |
| PKT-codex-002 stale 196,608 / 196,963 prose in `specs/consumer-progress.md` | fixed: the spec now names `*fn-stxa-max-octets*` (the u32 frame payload less the poll envelope and cursor) | fn `614926a22` (consumer-exchange) |
| E2 two-store: B/A peer ingress keeps an acceptance-time verdict in a kind-4 composite | done | qualified `1a9dd747`; your five complete runs |
| `consumer` refusals were bare, so you could not tell stale state from a duplicate | named refusals (`consumer refused credential`, …), `fn consumer --json …` one JSON line per command | friend-blockers-2 (PKT-709), fn `0aa093ffb` |
| cancelled / superseded articles in an inbox | a `withdrawn` report (Message-ID only, at the article's place and at the cancel's) | friend-blockers-2 (PKT-710), `0aa093ffb` |
| an agent must poll | `fn consumer wait` / `bound-wait` sleep inside the node until an article the login may read is stored; `fn consumer-article --json REPORT` decodes it | agent-wait, fn `61ddb48bc` |
| a login without the operator typing a password | `fn operator CONFIG account invite`, redeemed by `fn redeem` | friend-blockers, fn `dc3a0f024` |
| hybrid-author's refusals were bare | every arm named: `UNKNOWN-GROUP`, `AUTHOR-NOT-ENROLLED`, `CONFLICT`, `ARTICLE-EXCEEDS-PROFILE-BOUND`, … | PKT-147 (PRF-170) |

Exit codes everywhere: 0 accepted (or duplicate), 1 refused (named),
3 uncertain, 4 fault. fn's plain guide for all of this is `agents.md [not in tree]`.

## 3. Packets (fn work, not done, with the interface you would get)

- **PKT-255, the remote consumer.** Today `fn consumer poll/wait/ack` is
  on the node's control socket only (same machine, same UID). A hosted
  Mini gateway on another machine reads over NNTP and has no cursor/ACK.
  What Mini would need from it (a proposal, not a decided design): the
  same `fncu` cursor and `fn-e` report bytes you already project with
  `consumer-project`, over an authenticated connection bound to the login's
  consumer (the binding exists: `fn operator CONFIG consumer bind NAME
  --account LOGIN`), with wait, poll and ACK answering accepted / refused /
  uncertain exactly as the local commands do, and `consumer position` to
  settle an uncertain ACK. Until it lands, run the gateway on the fn node's
  machine.
- **PKT-322, a revoked author's uncertain post.** After `hybrid-revoke`,
  resending a signed tuple is refused (`AUTHOR-NOT-ENROLLED`) before its
  identity is compared, so an uncertain post authored before the revocation
  settles only by ARTICLE over NNTP (or the operator's `store inspect`).
  Options (a) keep the order, (b) answer D25 for a source authored before
  the revocation, (c) a privileged read-only query; it waits on ember. Your
  outbox should keep its ARTICLE + `hybrid-verify-source` path for this
  case.

## 4. What fn will not do, and why

- **Decide publication consent or select history.** Whole-prefix disclosure
  (FN-PUBLICATION-DISCLOSURE.md), the release certificate and selective
  origin proofs (FN-RELEASE-DESIGN.md, FN-SELECTIVE-ORIGIN-PROPOSAL.md) are
  Mini's kernel and verifier. fn stores and serves the exact bytes it is
  given; an fn acceptance, a signature verdict or a Store position says who
  signed which bytes and that the node kept them, never that releasing them
  was authorized. Your note is right that fn is semi-untrusted transport
  here, and fn will not grow a Mini-specific release check.
- **Keep secrets.** A group is readable by every login the operator lets
  read it, by the operator, and by every peer that carries it. A login's
  read rule hides a group from other logins on that node only.
  Encrypt before `hybrid-sign` (FN-RELEASE-DESIGN.md already says so).
- **Redact or filter an article.** A signed article is its exact source;
  trimming it would break the signature. Put only what may be public in R.
- **Raise the default article bound for one consumer.** Size is the
  operator's profile (D27: no fixed data caps, bound work instead). Mini's
  operator chooses A with `upgrade-profile`.

## 5. What ran

- ACL2: `books/native-hybrid-control.lisp` and its test book admitted in the
  hbox REPL; `certify-20260927T202620Z-2421499` on hbox: the 4 affected
  roots (native-hybrid-control, peer-invite and their tests) passed.
- Native (hbox, developer + production images of `b210f6450`, run
  `/tank/fn/scratch/downstream-requests/native-n2`):
  `tests.test_native_hybrid_author` OK (13 ran: every earlier case plus the
  new one), `tests.test_native_consumer_e2` OK (4 ran, 1 skipped: the
  distinct-UID case needs root), `tests.test_native_agent_wait` OK (2 ran).
  The new case's witness, under A = 400,000:
  `first ACCEPTED (exit 0); resend DUPLICATE (exit 0); a 399,000-octet
  source ARTICLE-EXCEEDS-PROFILE-BOUND (exit 1); ARTICLE 220, 198,919
  octets ending in the exact source; HDR :fn-verified "0 verified <principal>
  keyring 1"`. Log SHA-256
  `accc28f783377953f08310908b41263ea8cfe7f1295c3ce4816bec77c8316bee`.
- `make check-lane`: 33 steps, 0 failed.
- The two-store harness change was checked by argument parsing and the
  fallback helper only; it has not run an exchange. Your next distinct A/B
  run is its first.
