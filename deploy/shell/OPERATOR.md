# Operator: accounts on a Mini box

This is ember's checklist for the demo box (`dregg-demo`, `demo.dregg.online`; where the box stands is
`docs/DEMO-PREFIX-2026-10-26.md` §2). Box layout, units and the ship, render and health scripts are in
the infra repo (`dregg-infra`: `edge/mini/README.md`, and `edge/demo/` for the demo box); they are not in
this repository. Members read `FRIENDS.md`.

## Who enrols whom

| who | route | who holds the member's Mini key | where it is written |
|---|---|---|---|
| a stranger | the door at `/join` (free, or pay-to-enrol) | the member's account on the box (hosted) | `deploy/door/README.md` |
| an operator friend, hosted | by hand, below; the same scripts the door runs | the member's account on the box | this file |
| a friend who keeps the key on their own machine | `mini join` there, `enroll plan` here | the friend; no process on the box holds it | `README.md` in this directory, "The sponsor's side" |

**Strangers never need the operator.** The door's root processor is the only writer of door accounts, hosted
keys, `authorized_keys` and the Discord roster; it renders the login, runs the member's own `keygen`,
enrols with `mini-reenroll`, and issues the Discord link code. Its trust boundary, funding caps, paid route
and custody table are `deploy/door/README.md`; the browser side is `deploy/web-frontend/INSTALL.md`.
The operator watches the door, not each stranger:

```
journalctl -u mini-door-process --since today         # one line per decision
cat /var/lib/mini-door-status/door-state.json         # open or closed, and why
ls /var/lib/mini-door-process/requests/ /var/lib/mini-door-process/rejected/
```

The free route closes by itself when the sponsor's balance is below `sponsorFloor + funding` or a cap in
`/etc/mini/door.json` is reached (`deploy/door/README.md`, "Funding and caps"); the page and
`door-state.json` say which. Top the sponsor up or raise the caps; nothing else reopens it.

Names used below:

```
BOX=<the box's root ssh destination>
C=/var/lib/mini/candidate/current
NODE=/var/lib/mini/store/node   # Store, sponsor workspace (NODE/sponsor), sockets
S=/var/lib/mini/sessions        # S/NAME = a member's session home
```

**Precondition.** The box runs split tenancy (each member is the account `mini-s-NAME`; the door refuses to
run otherwise, `deploy/door/README.md`). The candidate's shell has `enroll` and `provision`
(`native/resource-client/src/shell_grammar.rs:429-438`). Check the render with
`ssh $BOX 'head -n 2 /etc/mini/authorized_keys.d/mini'`: it must say `mode=open`.

## An operator friend, hosted (by hand, same path as the door)

1. **Roster.** One line `ssh-ed25519 AAAA… comment` and a NAME matching `^[a-z][a-z0-9-]{0,24}$`.
   Put it in the box's roster directory in dregg-infra (`edge/demo/friends/`; it has a `BOX` file) and render:
   ```
   cp their.pub edge/demo/friends/NAME.pub && git add edge/demo/friends/NAME.pub && git commit -m "mini: add NAME"
   BOX=dregg-demo MINI_ROSTER_DIR=edge/demo/friends edge/mini/render-authorized-keys.sh
   ```
   The render creates `mini-s-NAME` and `S/NAME` (0700). The door's own entries live in the box's
   `friends/door/`, which the Mac half never touches (`deploy/door/infra/INSTALL.md`).
2. **Their first login.** `ssh -t mini-s-NAME@HOST`, then `keygen mini.key`. Check:
   `ssh $BOX test -s $S/NAME/keys/mini.key.pub && echo ok`.
3. **Enrol and provision.** `ssh $BOX /usr/local/lib/mini/mini-reenroll NAME` prints `NAME SUBJECT`.
   It plans from the member's public key, has the member's own account sign possession over the public
   plan files in its home (`mini enroll --action possess`), seals, submits, provisions a funded account
   (`MINI_REENROLL_FUNDING`, default 1000) and delivers the birth context. No copy of the member's key is
   made anywhere; the proof is `native/resource-client/journey.d/jdoor.sh --box`
   (`deploy/door/README.md`, "Custody contract"). The script is `deploy/door/infra/dregg-infra.patch`
   applied to dregg-infra's `mini-reenroll`.
4. **Tell them** their SUBJECT: `init mini.key SUBJECT`, then `whoami` (it shows `"initialized": true`).

A stranger's Discord user is linked by the door (`/mini line:link CODE`). For an operator friend, add
`"<discord id>": "NAME"` to `/etc/mini/discord-roster.json` by hand. The roster never maps to the sponsor
(`deploy/door/README.md`, "Rate limits and abuse").

## A friend who keeps their key

The friend runs `mini join --key` on their own machine and sends the three printed lines; you run
`enroll plan NAME PUBLIC-KEY-HEX NEXT-PUBLIC-KEY-HEX COSIGN-HEX`, `enroll offer`, `enroll seal`,
`enroll submit`, `provision`, `enroll welcome` in the sponsor's hosted shell. The exact recipe is in
`README.md` in this directory ("The sponsor's side"); the key line is
`render-shell-key mode=proxy …`. This route exists (`native/resource-client/journey.d/jpriv2.sh` enrols and
writes over it); no recorded run of that journey exists, and the box's door never creates proxy rows
(`deploy/door/README.md`, "Paid").

## Re-genesis

Before: post in the members' channel ("reset at HH:MM UTC; keys stay, everything you made goes").
1. `ship.sh --regenesis` (dregg-infra, `edge/mini/ship.sh`) moves the old Store aside, re-renders the roster
   and runs `mini-reenroll --all`, which covers operator friends, door accounts and the `public` reader
   (`deploy/door/README.md`, "Composition with the box").
2. Move every member's old-Store client state aside and keep the keys (the workspace, namespace and
   retained attempts name the old world; the keys do not):
   ```
   ssh $BOX 'ts=$(date -u +%Y%m%dT%H%M%SZ); for d in /var/lib/mini/sessions/*/; do \
     for x in workspace namespace provision requests inbox refusals enroll possess; do \
       [ -e $d/$x ] && install -d -m 0700 -o "$(stat -c %U $d)" $d/retired-$ts && mv $d/$x $d/retired-$ts/; done; done'
   ```
3. Members then `init mini.key SUBJECT` with their new subject; door accounts are told through the
   channel. The `public` reader's subject is re-recorded by hand (`deploy/web-frontend/INSTALL.md` §2 step 4).

## Health, restart, backups

- **Health:** `ssh $BOX /usr/local/lib/mini/mini-health`. Healthy means a signed sponsor read was
  answered, not that a pid exists.
- **Restart:** `ssh $BOX systemctl restart mini-store`, then health.
- **Backups:** `mini-backup.timer` (dregg-infra) writes archives to `/var/lib/mini-backups/` and pushes them
  to `dreggnet-demo-mini-backups`; `mini-restore-check [ARCHIVE]` checks one without touching anything live
  (a recorded push and check: `docs/DEMO-PREFIX-2026-10-26.md` §2). The archives contain the sponsor's
  secret key. What a Store backup must include (the head anchor beside the database) is
  `docs/DURABLE-STORE.md`. Members' session homes (their hosted keys, workspaces) are not in them: if the box
  is lost, members keygen again and are re-enrolled.

## Removing a member

1. Remove their roster file (`edge/demo/friends/NAME.pub` for an operator friend,
   `/usr/local/lib/mini/infra/friends/door/NAME.pub` for a door account) and render. Their ssh stops at
   once; the account and `S/NAME` stay (`deploy/door/README.md`, "Composition with the box").
2. Their key stays enrolled and their grants live in the Store. Revoke what they were granted from the
   session that delegated it: `revoke ID REF SUBJECT`, `submit ID`
   (`native/resource-client/src/shell_grammar.rs:199-200`).
3. Remove their Discord roster line if any. `S/NAME` is their data: archive or delete it by hand.
