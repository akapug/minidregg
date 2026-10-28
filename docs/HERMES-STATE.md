# Hermes lane state

Present-state record of the Hermes lane (L4), rewritten whole when its shape changes. The operator
documentation is deploy/hermes/README.md; this file is the lane's: what is where, how it is run, what
is owed. Lane L4d, 2026-10-28.

## Where things are

- Branch `lane/hermes-b`; Mac worktree `/Users/ember/dev/minidregg-lanes/hermes-b`.
- dregg-build (`ssh dregg-build`, user `lanes`): the lane checkout `/build/lanes/hermes-tier`
  (detached at the lane tip; its `.lake` is stale, so Lean is checked by the integrator's build),
  target `/build/lanes/hermes-tier-target`, J14 runs under `/build/lanes/hermes-live-run/` (the sudo
  rule for the root-owned provider table names that parent), the Hermes checkout
  `/build/lanes/hermes-live-run/hermes-agent` (6d8a8beb).
- Mac target for filtered tests: `CARGO_TARGET_DIR=/Users/ember/dev/minidregg-lanes/.target-hermes-b`.

## Running J14 on dregg-build

`C=/build/candidates/SHA LANE_GRAIN=1 /build/lanes/hermes-tier-run/hb-q3.sh /build/lanes/hermes-live-run/hb-q3-N`
with a PID file `/build/lanes/hermes-live-run/hb-q3-N.pid`. `LANE_GRAIN=1` puts the tree's
grain-runtime, bridge and mini over the candidate; check out the lane tip in `/build/lanes/hermes-tier`
first (the journey reads its scripts from there). It runs J0-J5 and J14 keep-going with J14_TOOLS=1
and J14_AWAIT=1 on the pool route. Constraints: one J14 per account (it holds the user unit
`mini-grain-controller@9870001`); the manifest's `shell` is the lane `mini`; a runtime root built
before 05b69e7e needs a full rebuild, not `--rebind`.

Rows planted on this lane that have not run yet (first run: the next candidate's J14):
`house` (two strangers in the shared room: a member's summon says Hermes is there, carl asks, dave's
tail shows the reply), `resummon` (summon after dismiss, new budget account, controller re-provisioned),
and the await rows after `bend deliver`'s heap fix.

## Runs

- hb-q3-4 (lane over 68cf4ba7a): 12 reds of 240 (await resume, notDecider check, redteam calls 0-6,
  the turn bound), each fixed after it.
- hb-q3-5 (ee22e9a81 over 68cf4ba7a): 4 reds of 246; tools, own-pass and the redteam calls
  green. Rows 168/170/172: `bend deliver` refused `heapUncovered 200018 200000` and the two checks
  after it (fixed by e7475d739: deliver declares the quoted extra heap). Row 208: the redteam pass
  paid 8 turns against a bound of 5; the bound counted only the model's writes, while the pass also
  pays the resident's request-status entries (3) and the sandbox compute of the planted terminal call
  (1), so the row is restated by kind (writes ≤ 5, statuses ≤ 3, compute = the prompt's compute
  ledger, and every paid turn has its payment record).

## What the lane carries beyond main

Pushed on lane/hermes-b after 9f3855a7d (all of main through it): ee22e9a81 (the redteam report is
the final reply), 6895a5dbe (resident route allowlist: activity ops 210-214 in, unused reads out),
38c456653 (ops 46/76 and the lifetime grant log their refusal reason; Lean unbuilt on the lane, the
integrator's build checks it), 29af88045 (the shared house room: door `room`, member summon, tour
step 6, install-hermes `FOUNDER_MEMBER`, J14 `house`), e376736a2 (install-hermes refill, dismiss,
resummon; J14 `resummon`), c334611aa (room-workspace compaction), e7475d739 (`bend deliver` extra
heap), the redteam restatement, and this file.

## Measured footprint (the resident's quota)

hb-q3-4's per-pass peaks (footprint-passes.tsv): 36.9 MiB and 7,063 inodes by the end, about
300-700 inodes per pass. The room workspace reached 2,547 inodes; c334611aa compacts its local
renders and Host-refused reads (about 40 of its 164 attempts). The rest of a peak is structural: a
pass holds its own prompt's operations (about 18 inodes each; the redteam prompt ran 140) plus the
previous prompt's, which compaction keeps from the prompt origin on (`keep_from`), plus the
attempts room write records name (RoomTools::lookup). The 32 MiB / 2,000 inode target is below one
heavy prompt; the interim quota (48/56 MiB, 10K/12K inodes) fits. Reaching the target needs
compaction of decided operations inside an active prompt, a design change to the controller's
recovery retention, not a tuning.

## Owed

1. Run J14 on the next candidate the integrator names (after 9bd52317c), with the planted rows above.
2. Hermes through the Oracle on the demo box: install-hermes binds no Oracle lifetime route.
   J14_ORACLE composes it on spk-host's Store-registered controller (application-attachment phases),
   a different topology from the uid-per-resident controller; porting it is days of work with infra.
   Proposed to the qualification lead as post-rehearsal.
3. Infra (a298031c78e86d651): the door's `room` setting; the lobby install before the seed; the
   quota figure above; whether the sponsor's account can pay a PAY refill (the Store's pay tariff,
   and the sponsor not the credit issuer's well); a unit for the Hermes dispatch pump
   (deploy/hermes-dispatch), without which only `install-hermes dismiss` delivers a dismissal.
4. From the claudesplosion scavenge (docs/SCAVENGE-CLAUDESPLOSION-2026-10-28.md on lane/scavenge):
   K-BOOK-SLOTS (a payment and the write it buys in one transaction; the concierge grants windows from
   its own journal); the out-of-budget notice is the one unmetered write; overflow refusals stay in
   controller custody and are never published to the room.
