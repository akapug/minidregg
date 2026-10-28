# qualify-lean-refusals: state

Branch `lane/qualify-lean-refusals`; the code is commit 664f8e09b (Host/Main.lean only), on main 327096423.
Every Host refusal on these paths now reaches the operator's log (Host stderr) with its reason. What the
member gets back is byte-identical: a blind refusal is uniformed by `publicSubmissionOutcome` whatever
its detail (`public_refusal_uniform`), and the paths that are not uniformed keep their old text.

| op | site | status |
|---|---|---|
| 34 app write | `dispatchApplicationSubmitSession` | done: reason bound, logged, uniform NO_RECORD frame |
| 34 app write (carried) | `carriedApplicationSubmit` | done: reason logged; unavailable/uncertain detail logged (`host: submission unavailable/uncertain (operator log)`), member text unchanged |
| 26 app start claim | v3 and retry-v4 arms | done |
| 22 app start begin | v3 and retry-v4 arms | done: logged only; member keeps the bare "request refused" |
| 84 enrolment (carried) | `carriedEnrollmentSubmit` | done: reason logged, member keeps "carried enrollment refused"; unavailable/uncertain logged |
| 84 enrolment | `applicationSessionEnrollmentSubmitSession` | done: logs (member already got the detail) |
| 105 pay, 242 platform install, 246 meter refill, 189 key adoption | dispatch arms | done: `logOperatorRefusal outcome` before the uniform encode (189 only, not lookup 190) |
| extra: 20 selected release, selected-source publication | Host | done: reason via `reprStr`; Repr from a `deriving instance` in Host/Main.lean |
| extra: fn consumer namespace, selected poll, empty poll v2 | Host | done: String reason kept |
| 46, 76, lifetime grant | | untouched (L4d, 38c456653) |

Pins: no `#guard_msgs`/`#assert_axioms` in Host/Main.lean touches these functions; journeys grep
`submission refused (operator log)` for presence or counts that only grow, and the new
unavailable/uncertain line uses different text, so those counts don't move.

## Elaboration: UNELABORATED at push time

- First `scripts/pipeline/lane-check Host/Main.lean` on dregg-ref (tree /srv/lanes/qualify-lean-refusals,
  a cp -a of thin-birth's .lake): its stale-import rebuild was OOM-killed at 17:53:54Z in the shared
  swarm.slice while other lanes ran unlocked builds. Host/Main.lean itself was never reached.
- Retry running: `/srv/lanes/qlr-state/qlr-retry.sh` (PID in `/srv/lanes/qlr-state/retry.pid`) runs
  `closure-lock swarm-build lake build -j 2 <Host/Main imports>`, then, separately and not nested,
  `scripts/pipeline/lane-check Host/Main.lean`. The verdict goes to `/srv/lanes/qlr-state/retry.log`
  (`IMPORTS rc=`, then `EXIT=`).
- Risk spots if it is red: the `deriving instance Repr` line (namespaces under `open Minidregg.Kernel`),
  and `reprStr` on those Reject types.
