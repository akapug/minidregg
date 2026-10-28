# demo-seed: a world that is already lived in

`seed.sh` makes the demo world feel inhabited before the first stranger arrives. It is run once by the
operator, as root on the demo box, and uses only the verbs a member types: every line is one seed
member's shell line handed to `mini-shell-ssh` as that member's own account (the way
`mini-session-run` does), so each is an admitted, receipted turn. Nothing writes the Store any other way.
Its texts are plain files in `data/`.

## Where it runs in the run sheet

After: genesis, the `public` reader enrolled (`/etc/mini/public-subject` exists), the two seed members
below enrolled and provisioned, and `mini apps bootstrap`. Before: the door opens.

    sudo deploy/demo-seed/seed.sh        # as root, on the box, from the candidate checkout

It needs `/usr/local/lib/mini/infra/lib.sh` (the same variables `mini-session-run` reads: `C`, `NODE`, `S`,
`LIB`, `TENANT_GROUP`, `TENANCY=split`), `jq`, `curl`, `setpriv`. Optional: `SEED_HOST`, `SEED_GUEST`,
`SEED_HERMES_BUDGET` (default 100), `TALLY_SRC` (default `$C/world/activity/Tally.obend`).

Time: about 8 to 12 minutes without apps (roughly 120 shell calls, a few seconds each, `summon` and
`bend` longer), plus the three grain installs, which are minutes each (EtherCalc's lifecycle measured
741 s on a loaded box): budget 45 to 60 minutes end to end. A second run takes about two minutes
(only `history`/`doc show` checks) and prints `skip` for everything.

## What the frame must provide

- Seed member `box`: the house account (hosted, enrolled, provisioned, with an account for `bend` and the
  `summon` budget). It founds and owns everything and holds the Hacker Slides, Etherpad and EtherCalc grains.
- Seed member **`sage`**: NEW, a second hosted member (roster entry, `mini-reenroll sage`, provisioned,
  initialised). Names are overridable with `SEED_HOST` / `SEED_GUEST`.
- The `public` reader and `/etc/mini/public-subject`. The lobby's Hermes resident, installed first
  by `deploy/hermes/demo/install-hermes` with `FOUNDER_MEMBER=box ROOM=lobby` (the example in its
  header): its `room` step founds the lobby as `box`, its `summon` step summons Hermes there, and
  the registry it writes to `box`'s `HOME/hermes/registry.json` is what `summon lobby` finds.
- The door's `room` setting, `{"founder": "box", "name": "lobby"}` (beside `story`), so every member
  joins the lobby at enrolment.
- The front page should render the published document named `welcome`; the script publishes it but
  does not set any front-page pointer.

## What the world holds afterwards

- Public documents (delegated `observe` to the public reader): `welcome`, `what-is-mini`,
  `a-refusal-explains-itself`, `the-lost-reply`, `the-lamplighters-note` (a small story), `house-rules`,
  `field-notes`. `welcome` links to all of them (`doc link`), transcludes `what-is-mini` lines 2..4 live,
  and, when the deck is verified, ends with: "This deck was published by a member's app; open it without
  an account: https://aN-www.demo.dregg.online".
- Room `lobby` (founder `box`, member `sage`) with signed posts, published to the public reader, and the
  Hermes librarian summoned with budget 100 and an intro post that says `ask lobby your question`.
  The lobby is the house's shared room: every member the door enrols joins it, and Hermes there
  answers all of them. A member's `summon lobby as librarian` says Hermes is already there and how
  to ask it; only `box` summons, funds and dismisses. This is the tour's Hermes step (step 6).
- Story `tale` installed under the sealed law, GM `sage`, first scene narrated. `box` is the author.
- Bend `tally` published from `world/activity/Tally.obend` and run on object `lobby-tally`.
- Delegation: `field-notes` is `box`'s with `observe,mutate` to `sage` (one admitted note); `house-rules`
  is `box`'s with `observe` only, and `sage-overstep` is `sage`'s append to it, refused at submit (a receipt in
  sage's `history`).
- Grains: EtherCalc (sheet `lobby-tally`), Etherpad (pad `welcome`), Hacker Slides (deck published on its `-www` origin).

## Idempotence and failure

Each step looks for its object first (`doc show`, an attempt id in `history all`, `chat rooms`,
`story list`, `bend show`, `apps list`) and prints one `seed: ok|skip|FAIL <what>` line. A FAIL does not
stop the run; the exit status is non-zero if any step failed, and re-running resumes.

## Unverified, for the validator (the lane ran nothing)

1. The app writes beneath the HTML are not shell verbs. The script does them as the member over the grain's own
   origin: `apps open GRAIN --json`, POST the printed token to `/__mini/bootstrap`, then plain HTTP with the
   cookie. EtherCalc's `PUT /_/SHEET` is the recorded qualify write. Etherpad uses its package's real pad UI
   route, multipart `POST /p/welcome/import` with the text as `file`, then checks `GET /p/welcome/export/txt`
   (its Sandstorm build disables `/api` unconditionally). Hacker Slides uses its editor's real
   `PUT /slides.md`; that one route saves and republishes `/var/www/slides.md` (there is no
   `POST /publish`), so the seed checks the markdown anonymously on the `-www` origin before
   naming the deck on the welcome page.
2. The shape of `apps list --json` (the script finds a grain id with a recursive `jq`), and the output of
   `history all` (`attempt<TAB>ID<TAB>...`, as `j12.sh` greps it).
3. Whether the public reader can read a chat room's per-member streams from the `lobby` grant alone.
4. Every member the door enrols joins `tale` as a player: the door processor runs `story invite tale SUBJECT`
   as `box`, hands the member the invitation and runs `story join` as the member (`story` in `door.json`,
   deploy/door/README.md). It retries each tick until the seed has made `tale`, and again after a re-genesis.
