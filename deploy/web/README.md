# deploy/web: the public docuverse snapshot

Week 1 of the public demo shows documents in the browser as a **static,
anonymous, read-only snapshot** of what authors publish to one operator-held
subject, `public` (WEB-SPK-PUBLIC.md §2, §3.2–§3.3, §5, §7 W1–W4; rulings D1,
D2, D8). Mini has no anonymous read: every observation is signed by an enrolled
key, and every signature first passes a consent provider that replays the Store.
So the signer is the box, as uid `mini-pubread`, with no network, on a timer;
the internet sees only Caddy's `file_server` over the files it wrote. Writing
stays in the hosted ssh shell. Members' own dynamic `mini web` (per-member,
split tenancy, cookie sessions) is the real design, not week 1.

**Everything on this box is world-readable** (D8): a signer of any kind reads the
whole Store through its consent replay, so the public reader could read more
than it shows. The demo world must never hold private data. Every static page
and the join page say so.

## Files

| file | runs as | what |
|---|---|---|
| `mini-pubread.service` | `mini-pubread` | imports delivered publications, then `mini web --read-only --render-static /srv/mini-public --public-origin https://demo.dregg.online` |
| `mini-pubread.timer` | — | re-renders 10 min after the previous render ends (set from the cost below) |
| `mini-pubread-collect.service` | root (read/chown only, no network) | `collect-publications.sh`: copies authors' published references addressed to `public` into the reader's inbox |
| `collect-publications.sh`, `import-publications.sh` | (as above) | the hand-off; neither decides anything: the render's signed reads publish or refuse |
| `Caddyfile.docuverse` | `caddy` | the `/` route: headers plus `file_server` over `/srv/mini-public/current` |

`mini web --render-static OUT` writes `OUT/<sha256>/` (`index.html`,
`doc/N/`, `doc/N/history/`, and for the 16 most recent history rows of each
document `at/H/doc/N/` and `doc/N/diff/H-1/H/`), names the tree by the SHA-256
of its paths and bytes (same Store, same bytes, same name), flips `OUT/current`
by one rename, and keeps only the snapshot it replaced. A reference the Host
refuses is not published; a client failure (no Host, a broken socket) fails the
render and the previous snapshot stays current. `--history-pages N` changes the
16.

## Authors: publish and unpublish

In the hosted shell (`PUBLIC` is the public reader's subject number, shown on
the join page and in every snapshot's header):

```
mini> delegate pub-paper paper PUBLIC observe 0
mini> submit pub-paper
mini> publish pub-paper          # proposals/pub-paper/recipient-reference.json
```

The next render shows `paper` at `https://demo.dregg.online/doc/paper` (a later
publication under a name already taken becomes `paper-CAPABILITY`). To
unpublish: `revoke pub-unpaper paper PUBLIC`, then `submit pub-unpaper`; the
page leaves the snapshot within one timer period plus one render. Links out of
a published document show their target ids, and a published room shows its
members and when each last wrote (WEB-SPK-PUBLIC.md §3.3).

## Operator: create the public reader (once per genesis)

Not yet run on any box. `<HOST>`, `<CONFIG>` and `<PUBLIC-SOCKET>` are the
candidate's Host image, pinned config and public relay socket, the same three
the shell's forced command passes (`/etc/mini/authorized_keys`).

```
useradd --system --home-dir /var/lib/mini-pubread --shell /usr/sbin/nologin mini-pubread
usermod -aG mini-public mini-pubread        # the public relay socket's group (§5.1)
install -d -o mini-pubread -g mini-pubread -m 0700 /var/lib/mini-pubread /var/lib/mini-pubread/keys /var/lib/mini-pubread/inbox
install -d -o mini-pubread -g mini-pubread -m 0755 /srv/mini-public
AS='systemd-run -q --wait --pipe --collect --uid=mini-pubread --gid=mini-pubread -p UMask=0077 -E HOME=/var/lib/mini-pubread --'
$AS mini keygen --secret /var/lib/mini-pubread/keys/public.key --public /var/lib/mini-pubread/keys/public.key.pub \
    --next-to /var/lib/mini-pubread/keys/public.key.next   # prints the next public key and co-signature
```

Enroll it from the sponsor session exactly as `deploy/shell/OPERATOR.md` steps
4–5 enroll a friend (NAME `public`, the custody copy of `public.key`, the two
words `keygen` printed), and note SUBJECT. **Skip step 6**: the public reader
gets no funding and no factory grant; it can only hold observe grants. Then:

```
$AS mini workspace --socket <PUBLIC-SOCKET> --action init --dir /var/lib/mini-pubread/workspace \
    --host <HOST> --config <CONFIG> --key /var/lib/mini-pubread/keys/public.key --subject SUBJECT \
    --next-pub /var/lib/mini-pubread/keys/public.key.next.pub
install -d -m 0755 /usr/local/lib/mini/web
install -m 0755 collect-publications.sh import-publications.sh /usr/local/lib/mini/web/
install -m 0644 mini-pubread.service mini-pubread.timer mini-pubread-collect.service /etc/systemd/system/
systemctl daemon-reload && systemctl start mini-pubread.service && systemctl enable --now mini-pubread.timer
```

Move `public.key.next` off the box, as a friend would. Put SUBJECT on the join
page.

## What the infra lane installs (dregg-infra `edge/demo/`)

- The uids and groups above; `mini-public` must be the group of the public
  relay socket (`serve-public-proxy`, 0660), and `mini-pubread` must be able to
  read the Store the consent provider replays (read-only; the unit also marks
  `/var/lib/mini/store` read-only, so adjust that path to the box's Store).
- The units and scripts, with `PUBLISH_GLOB` set in the collect unit if session
  workspaces do not live at `/var/lib/mini/sessions/*/workspace`.
- `Caddyfile.docuverse` imported into the `demo.dregg.online` block after the
  `/join`, `/interactions` and `/mini/v1/*` handles; `caddy` needs read access
  to `/srv/mini-public` and nothing else of Mini's.
- nftables per-source limits on 443 (§3.1); stock Caddy has no rate limiter.

## Render cost

**Not measured.** This Mac has no current Host: its only `minidregg-host` is the
2026-09-19 build of `66d74dd0`, and no `minidregg-client-consent` exists here,
without which every signing flow refuses. The estimate from the code: a
document costs about 3 signed reads for its page (page, links, backlinks), 1
for its history, and about 3 per rendered history row (the page at that height,
which reads each transcluded source again, and the diff), so with the default
16 rows about **52 signed reads per document**. At the ~1 s per signed read of
the serial Host on a loaded box (`PERFORMANCE-REVIEW-2026-10-03.md`), 20
published documents take on the order of **15–20 minutes**; that is why the
period is `OnUnitInactiveSec` and `RuntimeMaxSec=30min`, and why
`--history-pages` exists.

**Recipe (hbox, no build needed beyond the candidate).** The `jweb` journey row
`static-equals-live` renders carol's workspace and puts the renderer's own
summary line in its detail column (`render-static P page(s) for D document(s),
about N signed read(s), in S s`), so the next journey run of a candidate that
includes this branch records the number in `steps/WEB/web-rows.tsv`. That
Store has passed growth G (1000 writes) before JDV/WEB run. To measure by hand
on that run's world:

```
R=<journey run root>; MINI=<candidate>/bin/mini
/usr/bin/time -v "$MINI" web --dir "$R/world/carol-workspace" --read-only \
  --render-static /tank/scratch/static-measure --public-origin https://demo.dregg.online 2>measure.err
tail -2 measure.err      # the summary line, then time's wall clock and max RSS
```

Write the number here, and set the timer period to at least twice it.
