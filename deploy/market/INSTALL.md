# Installing the app market on the demo box

What the infra lane applies (dregg-infra `demo-vm`, `edge/demo/`) and what the candidate ships, for
`docs/APP-MARKET-2026-10-27.md`. Every path below is on `dregg-demo`; nothing here holds a secret.

## 1. Accounts and groups (install-demo.sh, split tenancy)

| account / group | why |
|---|---|
| user `mini-market` (nologin, primary group `mini-apps`) | the fetcher; the one uid with egress to the app index |
| user `mini-apps-edge` (nologin, primary group `mini-edge`) | the grain front; connects to route sockets, nothing else |
| group `mini-apps` | readers of the quarantine: `mini-market` writes it, `mini-core` (the worker) reads it |
| group `mini-edge` | the edge: `mini-apps-edge` is a member; the worker's unit carries `SupplementaryGroups=mini-edge` (membership inside that process only, never the account), so the worker can create `edge.sock` with that group |
| `mini-core` | unchanged; the worker runs in its user manager beside `mini-spk-broker@` |

## 2. Directories

```
/var/lib/mini-market                 mini-market:mini-apps 0750
  index.json                         0644   the catalogue (mini apps search/show read it; L12's pane too)
  quarantine/                        0750   ID.spk 0640 (sha256 prefix == ID, <= 256 MiB)
  meta/ refused/                     0755   ID.json 0644
  wanted/                            0730   flags dropped by the worker (mini-core, via group mini-apps)
/var/lib/mini-apps                   root:root 0711       (NOT under /var/lib/mini: the front must traverse it)
  origins/                           mini-core 0755             a<app>.json 0644, read by the front
  edge.sock                          mini-core:mini-edge 0660   the edge connector: the front asks `connect {grain, route}` and receives the custodian socket (SCM_RIGHTS); created by the worker
  verdicts/                          mini-core 0755             ID.json 0644, the ingest's verdict the catalogue shows
  requests/ grains/ work/ exports/   mini-core 0700             the worker's private state
/run/mini-apps                       mini-core:mini-sessions 0750  worker.sock 0660 mini-core:mini-sessions (members connect; SO_PEERCRED names them); tmpfiles.d: `d /run/mini-apps 0750 mini-core mini-sessions -`
/etc/mini/market.json                root 0644  {"index":"https://app-index.sandstorm.io/apps/index.json"} (the egress resolver's input)
```

Route sockets stay where `spk-host grain route` puts them, under the operator's 0700 state root;
no `routes/` directory under `/var/lib/mini-apps` is needed: the front reaches a grain through the
worker's edge connector (design doc §4), which adds no authority.

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
install -m 0644 deploy/market/mini-apps-worker@.service /etc/systemd/user/     # the operator's user manager, exactly where mini-spk-broker@.service goes (mini-core's home is root's /var/lib/mini)
echo 'd /run/mini-apps 0750 mini-core mini-sessions -' >/etc/tmpfiles.d/mini-apps.conf && systemd-tmpfiles --create
install -d -m 0711 -o root /var/lib/mini-apps
systemctl enable --now mini-market.timer mini-market.path mini-apps-front.service
systemctl start mini-market.service          # the first index refresh, so the catalogue is there before a member asks
sudo -u mini-core XDG_RUNTIME_DIR=/run/user/$(id -u mini-core) systemctl --user enable --now mini-apps-worker@STORE.service
```

`/etc/mini/apps.json` (root 0644, world-readable; `mini-apps-config-v1`) tells members what the
world is: `{"protocol":"mini-apps-config-v1","managementSubject":"8","toolRef":"tool","parentRef":"parent","tariff":{"base":"2","perBirth":"1"}}`.
A member's `apps install` births the application as their own op 30, whose admitted shape names the
world's metered parent (7901) and tool (7902) tasks. The frame grants them at enrolment
(dregg-infra `mini-reenroll`, `lib.sh apps_member_grants`, 400c94c); the three choices, confirmed:

1. **The grant bound** (`delegate ID REF SUBJECT observe,mutate MAX`): `MINI_REENROLL_APPS_MAX`
   default **1000**, the door's funding. `MAX` bounds one operation's cost under the delegated
   capability; the metered reserve of one application birth is 5 units (`tariff.base` 2 +
   `perBirth` 1 per resource, three resources), so 1000 is ample and the member's own purse bounds
   the total. Who pays the reserve is L1b's ruling; the sponsor's account meanwhile.
2. **The sponsor's references** are named exactly as `apps.json`'s `toolRef` and `parentRef`
   (default `tool`, `parent`). The sponsor must hold them before the first enrolment: in the
   sponsor's workspace, `import tool object 7902 81 81` and `import parent object 7901 73 73`
   (the plan's management capabilities on the tool and parent tasks; if the sponsor is not the
   subject that holds them, the operator delegates them to the sponsor first).
3. **Delivery to the member**: the frame copies each grant's `recipient-reference.json` to the
   member's `HOME/inbox/<toolRef>.json` and `HOME/inbox/<parentRef>.json` (member-owned; the
   shell's `inbox` lists that directory). `mini apps install` (with `--home`, which the shell passes)
   imports the two references from there by name before anything else, so a door member never runs
   an import by hand; only when neither the reference nor the inbox file exists does it refuse
   `meteredGrantRequired`, naming the file it looked for.

`mini-apps-worker@STORE.service` reads `/var/lib/mini-spk-worlds/STORE/apps-world.json` (the
operator writes it, 0600: `mini-apps-world-v1`, naming the grain-host profile, `mini`, the public
socket, the metered tool/parent tasks, the genesis, the quarantine, the market's `wanted/`, the
verdict directory, the domain and a nonce file). The worker creates `edge.sock` with group
`mini-edge` and `worker.sock` with group `mini-sessions` itself, under the unit's
`SupplementaryGroups`; a missing group is reported and refused, never silently 0600.

## 5. Caddy: the wildcard origin block

DNS: `*.demo.dregg.online` A/AAAA (live). TLS: the one `*.demo.dregg.online` certificate the infra
lane issues (Caddy built with the Gandi DNS module, DNS-01 off the box's own token policy as ember
ruled; hybrid key exchange first, classical fallback). **Routing rule: one entrance that dispatches by
`Host`.** Caddy proxies the whole wildcard to the front on `127.0.0.1:8799`; the front picks the
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
	reverse_proxy 127.0.0.1:8799 {
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

The box keeps its own Caddy-issued wildcard `tls` block (the Gandi DNS module the infra lane
built in) and takes only the proxy body above (`request_body`, `reverse_proxy 127.0.0.1:8799` with
its `header_up` and `transport` lines); the `tls` lines in the block are the file-based variant for
a box that installs the certificate as files. The 8 MiB body cap is the custodian's own bound (`http_entrance.rs`); the front
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
