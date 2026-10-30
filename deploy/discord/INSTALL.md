# Discord entrance: gateway mode on the demo box (for the infra lane)

The demo uses the existing **Dragon's Egg** application (`1507638321877090374`), whose Interactions
Endpoint URL nobody can set (the owning account's admin access is lost). With no endpoint URL, Discord
delivers interactions to the bot over the gateway, so `mini-discord` runs in **gateway mode**: it connects
out, takes `INTERACTION_CREATE`, and answers through the REST callback. The bot is already in guild
`1507637841235017768` (Wyrmware) and the four commands (`mini`, `mini-help`, `mini-world`, `mini-status`) are
registered for that guild. HTTP mode stays the default for an application we administer.

## Install

1. **The bot token**, as a credential file: `/etc/mini/discord-bot-token`, root:root **0600**, one line.
   It never goes in `discord.env`, the environment or git.
2. **`/etc/mini/discord.env`** (root 0600): `MINI_DISCORD_APPLICATION_ID=1507638321877090374` and the rest
   of `discord.env.example`. `MINI_DISCORD_PUBLIC_KEY` and `MINI_DISCORD_LISTEN` are not used in gateway mode.
3. **The drop-in**: `mini-discord.service.d-50-gateway.conf` from this directory as
   `/etc/systemd/system/mini-discord.service.d/50-gateway.conf`. It sets `MINI_DISCORD_MODE=gateway`,
   `LoadCredential=discord-bot-token:/etc/mini/discord-bot-token` and
   `MINI_DISCORD_BOT_TOKEN_FILE=%d/discord-bot-token`. The split-tenancy drop-in (`40-tenancy.conf`) still
   applies; NoNewPrivileges and the rest of the hardening hold.
4. **Egress** (the nftables triple; `edge/demo/demo-egress-resolve` fills `dst_discord`):

   | cgroup set | uid | destinations |
   |---|---|---|
   | `cg_discord` (mini-discord.service, `NFTSet=cgroup:inet:filter:cg_discord`) | `mini-discord` | `gateway.discord.gg` tcp/443 (the WebSocket) and `discord.com` tcp/443 (callbacks and follow-ups) |

   Resumes go to `gateway.discord.gg` too, never to READY's `resume_gateway_url` host, so no other name is
   needed. The trust anchors are the system bundle (`/etc/ssl/certs/ca-certificates.crt`,
   `MINI_DISCORD_CA_FILE` to change it).
5. **Caddy**: the `/interactions` route is not needed in gateway mode (nothing listens on 8793); leave it
   or remove it.

## Check

```sh
systemctl restart mini-discord && journalctl -u mini-discord -n 20   # "gateway: READY as <bot name>"
```

Then `/mini-help` in a Wyrmware channel answers ephemerally. A Discord user who is not linked is pointed
at the door; `/mini line:link CODE` links them (`deploy/door/README.md`).

## What the gateway client does

IDENTIFY with intents 0 (interactions need none), heartbeats at HELLO's interval (the first one jittered),
a missed ACK ends the connection and RESUMEs, RECONNECT and a resumable INVALID_SESSION RESUME, a
non-resumable one IDENTIFYs afresh after 1-5 s, close codes 4004 and 4010-4014 stop the unit (exit 78:
the token or configuration is refused), every other drop reconnects with a jittered backoff from 1 s to
60 s. Each interaction goes through the same handler as HTTP mode (roster, bounded line, 4 at once,
ephemeral, durable custody); a deferred line runs only after Discord accepted the callback.
