# Installing the web front end on the demo box

For the infra lane. The design is `docs/WEB-FRONTEND-2026-10-27.md`; this is the box side. Three
processes: the gateway `mini-web` (uid `mini-web`, loopback 8797, behind Caddy), the root helper
`mini-web-spawn` (one Unix socket, root:mini-web 0660), and per member a `mini web --body` and
`mini shell` the helper starts as `mini-s-NAME` in that member's `user-UID.slice`.

## 1. Accounts and directories

```sh
useradd --system --user-group --home-dir /var/lib/mini-web --shell /usr/sbin/nologin mini-web
# mini-web is in NO other group: it reaches no Mini socket and no Store path.
install -d -m 0700 -o root -g root /var/lib/mini-web-spawn /var/lib/mini-web-spawn/logins /var/lib/mini-web-spawn/sessions
```

The public reader `mini-pubread` and its workspace `/var/lib/mini-pubread/workspace` stay as
`deploy/web/README.md` made them (the `public` subject with observe grants); the helper runs the
anonymous body as that account. The pubread render timer and `/srv/mini-public` are no longer
needed: disable `mini-pubread.timer` and `mini-pubread-collect.service` once this is serving.

## 2. Binaries

From the candidate: `mini-web` and `mini-web-spawn` are workspace members
(`cargo build --release -p minidregg-mini-web -p minidregg-mini-web-spawn`), installed as
`/usr/local/bin/mini-web` and `/usr/local/bin/mini-web-spawn` (root 0755). The body is the
candidate's own `mini` (`mini web --body`), reached at `/var/lib/mini/candidate/current/bin/mini`
through the same `mini-shell-ssh` wrapper paths the door and the Discord runner use.

## 3. Units

```sh
install -m 0644 deploy/web-frontend/mini-web.service deploy/web-frontend/mini-web-spawn.socket deploy/web-frontend/mini-web-spawn.service /etc/systemd/system/
install -d /etc/systemd/system/mini-web.service.d /etc/systemd/system/mini-web-spawn.service.d
install -m 0644 deploy/web-frontend/demo/mini-web.service.d-60-demo-confine.conf /etc/systemd/system/mini-web.service.d/60-demo-confine.conf
install -m 0644 deploy/web-frontend/demo/mini-web-spawn.service.d-60-demo-confine.conf /etc/systemd/system/mini-web-spawn.service.d/60-demo-confine.conf
printf 'MINI_WEB_ORIGIN=https://demo.dregg.online\nMINI_WEB_SHUTDOWN=11 November 2026\nMINI_WEB_FRAME_SRC=\n' >/etc/mini/web.env
systemctl daemon-reload
systemctl enable --now mini-web-spawn.socket mini-web-spawn.service mini-web.service
```

`MINI_WEB_FRAME_SRC` is the CSP `frame-src` for grains opened in a pane (L13's per-grain origins,
e.g. `https://*.demo.dregg.online`); empty means `'none'`.

The helper's `install-demo.sh` contract check: `mini-web.service` carries the full
`placeholders/web-gateway.conf` floor; `mini-web-spawn.service` is root by design (the door's
`mini-session-run@.service` is its precedent) and declares its `CapabilityBoundingSet`,
`ProtectSystem=strict` and exact `ReadWritePaths`.

## 4. Caddy

Import `deploy/web-frontend/Caddyfile.app` into the `demo.dregg.online` block after the `/join`,
`/interactions` and `/mini/v1/*` handles, in place of the fallback `handle` and the docuverse
snapshot route. `/ws/*` is the terminal's WebSocket; the second handle is everything else.

## 5. The door

`lane/door`'s processor now writes the one-time web login record when it enrols an account
(`native/discord-entrance/src/bin/mini-door-process.rs`, `enrolled()`:
`/var/lib/mini-web-spawn/logins/<sha256(code)>.json` = `{name, request, expires}`, root 0600) and
publishes `webLogin` (`https://HOST/login/CODE`) on the stranger's status page; the form shows it
beside the ssh line. The code lives `linkTtlHours` (7 days by default). Nothing else changes in
the door; the processor remains the only writer of identities.

## 6. Check

```sh
systemctl is-active mini-web-spawn.socket mini-web-spawn.service mini-web.service
curl -s http://127.0.0.1:8797/healthz                                  # ok
ls -la /run/mini-web-spawn.sock                                        # srw-rw---- root mini-web
sudo -u mini-web ls /var/lib/mini/store 2>&1 | grep -q denied && echo "gateway cannot see the Store"
native/resource-client/journey.d/jweb-frontend.sh --box NAME           # as root; NAME a hosted account
```

The journey writes a login record as the door would, opens a session through the gateway with the
public Origin, runs `whoami` in a terminal over the WebSocket, creates and appends a document through
the forms, reads the receipt, logs out, and checks the public reader answers `/`.

## 7. What an RCE reaches

Gateway: the session ids of requests in flight (so those members' bodies and shells while the
sessions live), `/var/lib/mini-web`, nothing else; no key, no Store, no network. Helper: root; it is
the only such process and refuses everything but its seven verbs from uid `mini-web`. Body or
shell: that member's key and the world-readable Store, as the ssh shell does.
