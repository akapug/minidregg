# COMPUTE: jobs as cells, checked by re-execution, paid through the Book

This is the present-state description of the compute market and the tail bound. The Lean modules
are the authority; this document says what they do and where they are. Section numbers, lane names
(C1, C2, C3, C14), decision names (D3, D4) and assumption names (A6) are kept from the design of
2026-09-30, so the `COMPUTE §N` citations in `Kernel/`, `native/resource-client` and its journey
hooks resolve here. Only the sections the code cites are kept.

Each section is marked **shipped** (in `main`, with the module named), **changed** (shipped, but
not as first designed: the difference is stated) or **design** (not built).

## 0. Summary

The kernel has no job object. A job is one declared cell whose installed law is the job law
(`native/resource-client/templates/job/law.job`, written out as a `Pred` in `Kernel.Job`). A provider
claims it under a bond, answers, and anyone may submit the truth: a turn the kernel admits only
after re-executing the job's program itself. Decide and close are bookkeeping over the cell's
fields and the clock. The money (escrow, bond, payouts) is held by the Book and moved by one
receiver (`Kernel.JobMoney`, `Kernel.JobMoneyReceiver`). Separately, a node may run at most `L`
heights past its last certified head (`Kernel.TailBound`).

## 1. What is trusted

| party | what it can do if it lies | what bounds it |
|---|---|---|
| the provider | post a wrong output, or stall | a wrong output is slashed by one truth turn inside the window; a stall is slashed after `answerBy` |
| the operator (sequencer) | drop truth turns until the window closes, so a wrong answer is upheld | nothing yet: the follower inclusion rule of §5.2 is design |
| the operator's certify key | certify a head it did not execute | the tail bound only limits how far the head runs ahead; certification is the operator's word today |

## 2. A job is a cell with a law

### 2.2 The job's fields. **Changed.**

Sixteen fields, by index (`Kernel.Job`, `native/resource-client/templates/job/fields.json`):
`state` 0, `program` 1, `input` 2, `caller` 3, `callerAcct` 4, `price` 5, `claimBy` 6, `answerBy` 7,
`escrow` 8, `provider` 9, `providerAcct` 10, `bond` 11, `output` 12, `steps` 13, `finalAt` 14,
`truth` 15. States: 0 open, 1 claimed, 2 answered, 3 upheld, 4 slashed, 5 void, 6 closed.

Changed from the design: `window` is not a field; it is the law constant `{WINDOW}`, and the answer
edge fixes `finalAt = clock/now + WINDOW` with two `leSlotsOff` clauses. `escrow` and `bond` exist
from birth at 0. A job cell is born declaring its sixteen fields, and the scalar receiver refuses a
write that changes any other field before the law runs (`Kernel.FieldClosure`;
`closed_job_refuses_undeclared_field`).

A job's program is pinned (K-RUN-PIN, lane C2): its ABI context is `pinned`, so its sample is a
function of the ABI's named slots and the target ids (`Kernel.NockProgramCell.sampleOf_pinned_of_fields`),
and one run claim is admissible at every height where those fields are unchanged
(`Kernel.ResourceTransaction.pinned_claim_admissible_across_heights`).

### 2.3 The law. **Changed.**

The whole lifecycle is one law of 45 clauses (`Kernel.Job.jobLaw`, clause numbers as in
`law.job`; `scripts/gen-joblaw.py --check` keeps the grammar, the JSON and the Lean term equal):

| edge | who | guard |
|---|---|---|
| order (birth) → 0 | the caller | `price > 0`; `clock/now ≤ claimBy ≤ answerBy`; born unfunded (escrow, bond, provider 0) |
| fund (0, escrow 0 → price) | the caller, through the money receiver | §2.6 |
| claim 0 → 1 | the subject becoming the provider, through the money receiver | `clock/now ≤ claimBy`; `price ≤ bond` |
| answer 1 → 2 | the provider | `clock/now ≤ answerBy`; posts `output`, `steps`, `finalAt`; no truth yet |
| truth (state unchanged) | state 1: the provider; state 2: anyone | `ran PROGRAM`; `truth` absent before; `clock/now ≤ answerBy` in 1, `≤ finalAt` in 2 |
| decide → 3 | anyone | state 1 with truth present; or state 2 with `truth = output`; or state 2, no truth, `clock/now > finalAt` |
| decide → 4 | anyone | state 2 with `truth ≠ output`; or state 1, no truth, `clock/now > answerBy` |
| decide → 5 | the caller at any time; anyone after `claimBy` | state 0 |
| close {3,4,5} → 6 | anyone, through the money receiver | escrow and bond end at 0; payouts per §2.6 |

Changed from the design: fund is its own edge (an order is born unfunded); claim, fund and close
are money turns that must carry the slot only the money receiver projects (clause 44); the law of
a live job cannot be replaced or revoked (clause 0).

`ran PROGRAM` reads the slot `run/program/<id>`, which the controller projects only when the
command's run claim was re-executed by `Kernel.Run.checkRun` at the evaluator the program names and
its product is exactly the command's writes. No field write supplies that slot.

Theorems in `Kernel.Job`: `caller_cannot_forge_truth`, `truth_needs_ran`,
`bond_slashed_iff_mismatch`, `slashed_only_by_mismatch_or_stall`, `upheld_requires_match_or_timeout`,
`settle_requires_match_or_timeout` (over an accepted log), `no_double_settle` (over every field,
with field closure), `money_frozen_without_slot`, `escrow_moves_only_on_fund_or_close`; both poles
per edge by `decide`. Journey: `journey.d/jjob1.sh` (each refusal names its clause) and
`journey.d/jjob.sh` (the end-to-end job).

### 2.6 Settlement. **Changed.**

The Book holds a job's credit in an account whose id is the job cell's id
(`Kernel.JobMoney.heldAccount`), registered fresh by the fund turn. The cell's `escrow + bond` is the
law's view of it; every money turn keeps the two equal (`held_agrees`). One signed command (job,
action, account, amount) is one turn over the job cell and the Book, decided by
`JobMoney.decideMoney`:

- **fund**: the caller moves `price` from an account it owns into the held account
  (`fund_requires_caller`, `fund_holds_price`);
- **claim**: the provider moves a bond of at least `price` in and takes the job in the same turn
  (`claim_requires_bond`);
- **settle**: from 3, 4 or 5 the job closes, and `payouts`, a pure function of the job, leave the
  held account for the accounts the job's fields name (`settle_requires_terminal`). Upheld: the
  provider gets `price + bond`, the caller the rest of the escrow. Slashed: the caller gets the
  escrow and its share of the bond (§9 D4); the rest is retired into the well. Void: each party
  gets back what it put in.

`escrow_conserved`: every accepted money turn leaves the Book's total in the credit asset unchanged;
`Δheld + Δcirculating = 0` on fund and claim and `= −retired` on a slash. A cell that claims credit
the Book does not hold pays nothing (`heldMismatch`, `fixture_forged_held_refused`).
`provider_paid_iff_unchallenged_or_upheld` and `no_double_settle` are in the same file.
`Kernel.PayLedger` carries these postings in the credit asset's audit identity.

Changed from the design: funds are transfers into a held Book account, not burns, and payouts are
transfers out of it, not mints from the well; only a slash's retired share enters the well.
Journey: `journey.d/jjob-money.sh`.

### 2.7 What a challenge costs. **Changed.**

`Kernel.JobMoney.griefing_cost_bounded`: a truth turn that agrees with the output costs its
submitter exactly a fee, leaves the Book's total unchanged, moves no bond, and the settle still
pays the provider `price + bond`. The fee is a parameter of the theorem; no per-step fee is bound
to the truth turn in `Kernel.JobMoney`.

`settle_requires_match_or_timeout` (`Kernel.Job`) names the three reasons a job enters upheld
(`UpheldBy`): state 1 with truth present; state 2 with truth equal to output; state 2 with no truth
after `finalAt`.

## 5. More than one machine

### 5.2 The tail bound. **Shipped.** The inclusion rule. **Design.**

A record at height `head` is admitted only if `head − certified ≤ L` (`Kernel.TailBound.gate`,
`tail_bounded`). `certified` and `L` live in the system cell (`Kernel.SystemCell`); the rule is the
system law `leSlotsOff head/height certified/height L`, judged by `Pred.eval` at the durable
admission on every record: live, on reopen, and in `audit`. No user law can drop it.

The one exemption is a certify record (`Kernel.CertifyReceiver`): it writes exactly
`certifyNext` of the current head and log chain, strictly advancing, under the factory control
capability (today the operator). So certification can always follow a full tail
(`certify_admitted_at_full_tail`), and nothing else moves `certified`
(`certified_written_only_by_checkpoint`, `certified_monotone`). Poles: `tailBound_refuses_73`,
`tailBound_admits_72`. Journey: `journey.d/jtail.sh`.

Design (not built): the follower inclusion rule, under which a follower holding an admissible
truth turn votes for no head that closes the job to the provider without it.

## 6. No proving market. **Shipped as a decision.**

Proving a node's history is that node's own obligation, bounded by the tail bound (§5.2), not a
market. The evidence that certifies a head is today the operator's certify record; follower votes
and proofs are not built.

## 8. Lanes

| lane | status | where |
|---|---|---|
| C1 JOB-LAW | shipped | `Kernel.Job`, `templates/job/law.job`, `native/resource-client/src/shell/law.rs` |
| C2 K-RUN-PIN | shipped | `Compiler.NockProgramCodec` (`Abi.context`), `Kernel.NockProgramCell`; journey `jnock3p.sh` |
| C3 K-JOB-MONEY | shipped | `Kernel.JobMoney`, `Kernel.JobMoneyReceiver`; journey `jjob-money.sh` |
| C14 TAIL-BOUND | shipped | `Kernel.TailBound`, `Kernel.SystemCell`, `Kernel.CertifyReceiver`; journey `jtail.sh` |

## 9. Decisions

- **D3 bond floor. Shipped.** `bond ≥ price` (law clause 30; `JobMoney.claim_requires_bond`).
- **D4 the slashed bond. Changed.** The caller's share is the tariff line `slashCallerPermille`
  (`Kernel.PayTariff.Tariff`, at most 1000, default 500: half to the caller); the rest is retired
  into the well. No challenger bounty.

## 10. Assumptions

- **A6. Settled.** A slot-pair atom on an absent slot is false, so `eqSlots s s` expresses
  "present" with no new atom (`Kernel.Job.present_iff`, `present_false_on_absent`).
