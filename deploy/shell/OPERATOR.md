# Operator: accounts on a Mini box

This is ember's checklist. Box layout, units and scripts are in `dregg-infra/edge/mini/README.md`
(and `edge/demo/` for the demo box); members read `FRIENDS.md`.

**Strangers never need the operator.** On the demo box (`demo.dregg.online`) a stranger gets an account
at `/join`: the door's root processor writes their roster entry, renders the login, runs their own
`keygen`, enrols them with `mini-reenroll`, and issues their Discord link code (`deploy/door/README.md`).
The operator watches the door, not each stranger:

```
journalctl -u mini-door-process --since today         # one line per decision
cat /var/lib/mini-door-status/door-state.json         # open or closed, and why
ls /var/lib/mini-door-process/requests/ /var/lib/mini-door-process/rejected/
```

The free route closes by itself when the sponsor's balance is below `sponsorFloor + funding` or the caps
in `/etc/mini/door.json` are reached; the page and `door-state.json` say which. Top the sponsor up or raise
the caps; nothing else reopens it.

Names used below:

```
BOX=<the box's root ssh destination>
C=/var/lib/mini/candidate/current
NODE=/var/lib/mini/store/node   # Store, sponsor workspace (NODE/sponsor), sockets
S=/var/lib/mini/sessions        # S/NAME = a member's session home
```

**Precondition.** The shipped candidate's client has `mini shell` and `provision`, and the box runs split
tenancy (each member is the account `mini-s-NAME`). Check the render with
`ssh $BOX 'head -n 2 /etc/mini/authorized_keys.d/mini'`: it must say `mode=open`.

## An operator friend (by hand, same path as the door)

1. **Roster.** One line `ssh-ed25519 AAAA… comment` and a NAME matching `^[a-z][a-z0-9-]{0,24}$`.
   Put it in the box's own roster directory in dregg-infra (`edge/demo/friends/` for the demo box,
   `edge/mini/friends/` for the workhorse; each has a `BOX` file) and render:
   ```
   cp their.pub edge/demo/friends/NAME.pub && git add edge/demo/friends/NAME.pub && git commit -m "mini: add NAME"
   BOX=dregg-demo MINI_ROSTER_DIR=edge/demo/friends edge/mini/render-authorized-keys.sh
   ```
   The render creates `mini-s-NAME` and `S/NAME` (0700). The door's own entries live in the box's
   `friends/door/`, which the Mac half never touches.
2. **Their first login.** `ssh -t mini-s-NAME@HOST`, then `keygen mini.key`. Check:
   `ssh $BOX test -s $S/NAME/keys/mini.key.pub && echo ok`.
3. **Enrol and provision.** `ssh $BOX /usr/local/lib/mini/mini-reenroll NAME` prints `NAME SUBJECT`.
   It plans from the member's public key, has the member's account sign possession over the public plan
   files in its own home, seals, submits, provisions a funded account (`MINI_REENROLL_FUNDING`, default
   1000) and delivers the birth context. **No copy of the member's key is made anywhere** (this is the
   `mini-reenroll` of `deploy/door/infra/dregg-infra.patch`; the version before it copied
   `keys/mini.key` into the sponsor's home and must not be used for strangers).
4. **Tell them** their SUBJECT: `init mini.key SUBJECT`, then `whoami` (it shows `"initialized": true`).

A stranger's Discord user is linked by the door (`/mini line:link CODE`). For an operator friend, add
`"<discord id>": "NAME"` to `/etc/mini/discord-roster.json` (root 0644) by hand. The roster never maps
to the sponsor.

## Re-genesis, as members experience it

Before: post in the members' channel ("reset at HH:MM UTC; keys stay, everything you made goes").

1. Ship: `edge/mini/ship.sh L --regenesis`. The old Store moves to `store/retired-<ts>`; ship re-renders
   the roster and runs `mini-health`.
2. Move every member's old-Store state aside and keep the keys:
   ```
   ssh $BOX 'ts=$(date -u +%Y%m%dT%H%M%SZ); for d in /var/lib/mini/sessions/*/; do \
     for x in workspace namespace provision requests inbox refusals enroll possess; do \
       [ -e $d/$x ] && install -d -m 0700 -o "$(stat -c %U $d)" $d/retired-$ts && mv $d/$x $d/retired-$ts/; done; done'
   ```
3. `ship.sh --regenesis` runs `mini-reenroll --all`, which covers operator friends and door accounts;
   members then `init mini.key SUBJECT` with their new subject (door accounts: the processor's status page
   does not re-run; tell members through the channel).

## Health, restart, backups

- **Health:** `ssh $BOX /usr/local/lib/mini/mini-health`. Healthy means a signed sponsor read was
  answered, not that a pid exists.
- **Restart:** `ssh $BOX systemctl restart mini-store`, then health.
- **Backups:** `mini-backup.timer` nightly; archives in `/var/lib/mini-backups/` contain the **sponsor
  secret key**. `mini-restore-check [ARCHIVE]` checks one without touching anything live.
- **Not backed up: members' session homes** (their keys, workspaces). If the box is lost, members keygen
  again and are re-enrolled.

## Removing a member

1. Remove their roster file (`edge/<box>/friends/NAME.pub` for an operator friend, the box's
   `/usr/local/lib/mini/infra/friends/door/NAME.pub` for a door account) and render. Their ssh stops at once.
2. Their key stays enrolled and their grants live in the Store; the secret exists only in `S/NAME/keys`.
   Revoke what they were granted from the session that delegated it: `revoke ID REF SUBJECT`, `submit ID`.
3. Remove their Discord roster line if any. `S/NAME` is their data: archive or delete it by hand.
