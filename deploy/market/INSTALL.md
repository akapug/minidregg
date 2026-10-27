# Installing the app market on the demo box

What the infra lane applies (dregg-infra `demo-vm`, `edge/demo/`) and what the candidate ships, for
`docs/APP-MARKET-2026-10-27.md`. Every path below is on `dregg-demo`; nothing here holds a secret.

## 1. Accounts and groups (install-demo.sh, split tenancy)

| account / group | why |
|---|---|
| user `mini-market` (nologin, primary group `mini-apps`) | the fetcher; the one uid with egress to the app index |
| user `mini-apps-edge` (nologin, primary group `mini-edge`) | the grain front; connects to route sockets, nothing else |
| group `mini-apps` | readers of the quarantine: `mini-market` writes it, `mini-core` (the worker) reads it |
| group `mini-edge` | the W6 `edgeGid`: route directories are `0750 mini-core:mini-edge`, sockets `0660`; `mini-apps-edge` is its only member (not `caddy`: Caddy never reaches a socket) |
| `mini-core` | unchanged; the worker runs in its user manager beside `mini-spk-broker@` |

## 2. Directories

```
/var/lib/mini-market                 mini-market:mini-apps 0750
  index.json                         0644   the catalogue (mini apps search/show read it; L12's pane too)
  quarantine/                        0750   ID.spk 0640 (sha256 prefix == ID, <= 256 MiB)
  meta/ refused/                     0755   ID.json 0644
  wanted/                            0730   flags dropped by the worker (mini-core, via group mini-apps)
/var/lib/mini-apps                   root:root 0711       (NOT under /var/lib/mini: Caddy and the front must traverse it)
  origins/                           mini-core:mini-edge 0750   a<app>.json 0644, read by the front
  routes/                            mini-core:mini-edge 0750   a<app>/<member>/ 0750 with http.sock 0660 and the 0600 custodian files
  verdicts/                          mini-core 0755             ID.json 0644, the ingest's verdict the catalogue shows
  requests/ guests/ receipts/        mini-core 0700             the worker's private state (guest keys live in guests/)
/run/mini-apps                       mini-core:mini-sessions 0750  worker.sock 0660 (members connect; SO_PEERCRED names them)
/etc/mini/market.json                root 0644  {"index":"https://app-index.sandstorm.io/apps/index.json"} (the egress resolver's input)
```

`/var/lib/mini-apps/routes` is the broker's route directory for market grains: the worker passes
`directory=/var/lib/mini-apps/routes/a<app>/<member>` in each route request; the resident's
`custodian.json` carries `edgeGid` = the gid of `mini-edge`.

## 3. nftables: one egress row

Add to `edge/demo/host/nftables.conf` and `demo-egress-resolve`, in the shape of the existing rows:

| unit (cgroup) | uid | destination (derived from) | port |
|---|---|---|---|
| `mini-market.service` (`cg_market`) | `mini-market` | hosts of `/etc/mini/market.json .index` and `.packages` (`app-index.sandstorm.io`) | 443 (+53 to the resolvers) |

The service drop-in `60-demo-confine.conf` adds `NFTSet=cgroup:inet:filter:cg_market`. Every other
uid of the market (`mini-apps-edge`, the worker's `mini-core`, every grain) stays in the default
deny. The index host resolves to a CDN; the caveat is the same as for `openrouter.ai` (CONFINEMENT §1).

## 4. Units (ship with the candidate; this directory)

```
install -m 0755 deploy/market/mini-market-fetch /usr/local/lib/mini/market/mini-market-fetch
install -m 0644 deploy/market/mini-market.{service,timer,path} deploy/market/mini-apps-front.service /etc/systemd/system/
systemctl enable --now mini-market.timer mini-market.path mini-apps-front.service
systemctl start mini-market.service          # the first index refresh, so the catalogue is there before a member asks
```

The worker's user unit (`mini-apps-worker@STORE.service`, `systemctl --user` of `mini-core`) ships
with the worker (the next increment of this lane); until then `scripts/spk-platform/grain-journey.sh`
performs the same steps for the journey.

## 5. Caddy: the wildcard origin block

DNS: `*.demo.dregg.online` A/AAAA (live). TLS: the one `*.demo.dregg.online` certificate the infra
lane issues (Caddy built with the Gandi DNS module, DNS-01 off the box's own token policy as ember
ruled; hybrid key exchange first, classical fallback). **Routing rule: one entrance that dispatches by
`Host`.** Caddy proxies the whole wildcard to the front on `127.0.0.1:8797`; the front picks the
grain from `Host` and the participant route from the credential. Why not one upstream per grain: a
custodian socket is per participant, so a shared grain has several sockets and the choice is the
token's, which Caddy cannot look up (and token hashes do not belong in a Caddyfile that restarts per
share). Why not Caddy to the sockets: `/var/lib/mini` and the route files stay hidden from `caddy`.

```
# edge/demo/host/caddy/grain-origins.caddy — every market grain's origin, https://a<app>.@DOMAIN@.
# The explicit site blocks (@DOMAIN@, calc.@DOMAIN@, nano.@DOMAIN@) take precedence over the wildcard.
*.@DOMAIN@ {
	tls /etc/caddy/certs/wildcard.@DOMAIN@.crt /etc/caddy/certs/wildcard.@DOMAIN@.key {
		# Hybrid post-quantum key exchange first, then classical: browsers without ML-KEM still connect.
		curves x25519mlkem768 x25519 secp256r1
	}
	request_body {
		max_size 8MB
	}
	# The grain entrance (deploy/market/mini-apps-front.service). It needs the exact Host (the
	# custodian pins expectedHost) and no X-Forwarded-* rewriting of the request it forwards.
	reverse_proxy 127.0.0.1:8797 {
		header_up Host {host}
		header_up X-Real-IP {remote_host}
		transport http {
			dial_timeout 2s
			# A first GET through a fresh grain is a full Mini transaction (op36/37/34): minutes on a loaded Host.
			response_header_timeout 900s
		}
		# WebSockets: Caddy switches to a byte pump on 101; no idle deadline on upgraded streams.
	}
}
```

If the wildcard certificate is managed by Caddy's DNS module rather than installed as files, replace
the `tls` line's two paths with the `dns gandi {env.GANDI_TOKEN}` block the infra lane uses; the
rest is unchanged. The 8 MiB body cap is the custodian's own bound (`http_entrance.rs`); the front
answers 413 above its 128-byte bootstrap-form bound.

## 6. What a stranger sees

`https://a4501.demo.dregg.online/` without a credential: `403 private grain a4501; open it from your
Mini shell: mini apps open --grain a4501`. `GET /__mini/bootstrap`: the tokenless sign-in form;
POSTing the one-time bootstrap token `mini apps open` printed sets the `__Host-mini_spk_session`
cookie for that origin only. An unknown `a<n>`: `404 no such grain`. Nothing in these answers calls
Mini or writes a record.

## 7. Checks after install

```
curl -sS https://a1.demo.dregg.online/ -o /dev/null -w '%{http_code}\n'            # 404, no such grain
curl -sS -I https://demo.dregg.online/ | head -1                                   # the explicit block still wins
openssl s_client -connect demo.dregg.online:443 -servername a1.demo.dregg.online -groups X25519MLKEM768 </dev/null 2>&1 | grep -E 'Verification|Negotiated'
openssl s_client -connect demo.dregg.online:443 -servername a1.demo.dregg.online -groups X25519 </dev/null 2>&1 | grep -E 'Verification|Negotiated'
sudo -u mini-market /usr/local/lib/mini/market/mini-market-fetch refresh && head -c 200 /var/lib/mini-market/index.json
sudo -u mini-s-NAME mini apps search --term slides                                 # the catalogue, with verdicts
```

The journey row is `native/resource-client/journey.d/japps.sh` (`--dry` anywhere, `--box` on a
Linux box with the candidate's `bin/`).
