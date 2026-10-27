/- The effect Plan's keystone (statement first: docs/evidence/2026-10-27-world-native/DOMAINS.md,
"The effect Plan: statement first").

An activity's Plan may ask the kernel to perform an effect at its yield (`decodePlan`:
`transfer {to, amount, write}` and `commit {write}`, each a `PlanAwait` whose source is
`PlanSource.performed`). The yield's await is decided by the kernel at the yield itself
(`commitYield`): `settled` when performed, `refused` with its reason when not, and the next
delivery resumes with exactly that outcome (`settle`). A performed transfer is ONE posting in the
turn's own batch (`effectOps`, `withEffect`); a refused one posts and writes nothing.

This file states the keystone (Performed, Refused, Resumed, and the law's teeth on a commit) and
its poles (satisfiable, teeth, premise inhabitation) as propositions. -/
import Kernel.ObjectiveActivity

namespace Minidregg.Kernel.ObjectiveActivityEffect
open Minidregg.Theory Minidregg.Compiler
open Minidregg.Theory.TypedAuthorization (Digest SubjectId)
open Minidregg.Kernel.DurableDataIntent
open Minidregg.Kernel.ObjectiveActivityWire
open Minidregg.Kernel.ObjectiveActivity
open Minidregg.Theory.ObjectiveBendDemandData (Data)
open Minidregg.Theory.ObjectiveBendDemandMachine (State resume)
open Minidregg.Theory.CanonicalResourceKernel (Book Batch Operation AccountId AssetId logicalBook)
open Minidregg.Kernel.ObjectRecord (ObjectRecord admitWrite)
set_option autoImplicit false

/-! ## Vocabulary -/

/-- The await a yield at `height` records for an effect the kernel decided `verdict`: an effect
Plan's patience is 1. -/
def decidedAwait (cell : CellId) (generation : Nat) (checkpoint : Digest) (height : Nat) (verdict : Verdict) :
    Await :=
  ⟨awaitId cell generation checkpoint, .performed verdict, height + 1, height⟩

/-- The Plan `transfer {to, amount, write}` decodes to. -/
def transferPlan (write : Data) (recipient : AccountId) (amount : Nat) : PlanAwait :=
  ⟨write, .performed (.transfer recipient amount), 1⟩

/-- The Plan `commit {write}` decodes to. -/
def commitPlan (write : Data) : PlanAwait := ⟨write, .performed .commit, 1⟩

/-- A recipient the kernel transfers to: an open account of the Book (after the turn's own
postings) other than the purse, the collector and the issuer well. -/
def Admissible (config : Config) (funds : Funds) (written : Option StateWritten) (recipient : AccountId) : Prop :=
  recipient ≠ funds.purse ∧ recipient ≠ config.collector ∧ recipient ≠ config.asset ∧
    recipient ∈ (funds.book written).accounts

/-- The purse covers the transfer and still reserves `reserve` of the settled await after it. -/
def Covered (config : Config) (funds : Funds) (reserve : Await → Nat) (written : Option StateWritten)
    (settledAwait : Await) (amount : Nat) : Prop :=
  amount + reserve settledAwait ≤ purse (funds.book written) config.asset funds.purse

/-! ## The keystone -/

/-- **1. Performed.** A yield whose Plan is `transfer {to, amount, write}`, on a program that types
the effect outcomes, whose write builds, whose recipient is admissible and whose purse covers the
amount and the await's reserve after it, commits exactly: the await decided `settled`, the write
built, the write's post, and the transfer as the yield's effect; the turn's batch gets exactly the
one posting `purse → to` of `amount` in the credit asset. -/
def PerformedStatement : Prop :=
  ∀ {rootBytes : Bytes → Digest} (config : Config) (snapshot : Snapshot rootBytes) (height : Nat)
    (transaction : TransactionId) (cell object : CellId) (generation : Nat) (checkpoint : Digest)
    (current : Option ObjectState) (viewed : Bool) (write : Data) (recipient : AccountId) (amount : Nat)
    (funds : Funds) (reserve : Await → Nat) (written : Option StateWritten),
    1 ≤ config.maxPatience → height + 1 < 256 ^ 8 → funds.effects = true →
    stateWrite config snapshot object current viewed write = .ok written →
    Admissible config funds written recipient →
    Covered config funds reserve written (decidedAwait cell generation checkpoint height .settled) amount →
    ∃ committed,
      commitYield config snapshot height transaction cell object generation checkpoint current viewed
        (transferPlan write recipient amount) funds reserve = .ok committed ∧
      committed.await = decidedAwait cell generation checkpoint height .settled ∧
      committed.written = written ∧
      committed.posts = (written.map StateWritten.post).toList ∧
      effectOps config funds.purse (some committed) = [.transfer funds.purse recipient config.asset amount]

/-- **1'. Performed, in the turn.** An admitted delivery whose yield performed a transfer posts,
in its one batch, exactly its own charges followed by the transfer out of the purse, and the batch
conserves every asset on the Book. -/
def DeliveryPerformedStatement : Prop :=
  ∀ {rootBytes : Bytes → Digest} {config : Config} {snapshot : Snapshot rootBytes} {height : Nat}
    {request : DeliverRequest} (delivery : Delivery config snapshot height request) (committed : YieldCommit)
    (recipient : AccountId) (amount : Nat),
    delivery.yielded = some committed → committed.effect = some (recipient, amount) →
    delivery.posted.batch = withEffect
        (deliveryCharges config delivery.record request.record delivery.settlement.path request
          (drainFee config delivery.object (delivery.yielded.bind YieldCommit.written)))
        [.transfer (heldAccount request.record) recipient config.asset amount] ∧
    ∀ asset, (logicalBook delivery.posted.post.logical).totalAsset asset =
      (logicalBook delivery.book.logical).totalAsset asset

/-- **1''. The transfer moves exactly `amount`** from the purse to the recipient (two distinct
accounts) and nothing else of either balance. -/
def TransferMovesStatement : Prop :=
  ∀ (book : Book) (source recipient : AccountId) (asset : AssetId) (amount : Nat), source ≠ recipient →
    ((Operation.transfer source recipient asset amount).apply book).balance source asset =
        book.balance source asset - amount ∧
      ((Operation.transfer source recipient asset amount).apply book).balance recipient asset =
        book.balance recipient asset + amount

/-- **2. Refused (teeth).** A transfer whose verdict is a refusal commits the await decided
`refused` by that reason, with NO write, NO post and NO effect. -/
def RefusedStatement : Prop :=
  ∀ {rootBytes : Bytes → Digest} (config : Config) (snapshot : Snapshot rootBytes) (height : Nat)
    (transaction : TransactionId) (cell object : CellId) (generation : Nat) (checkpoint : Digest)
    (current : Option ObjectState) (viewed : Bool) (write : Data) (recipient : AccountId) (amount : Nat)
    (funds : Funds) (reserve : Await → Nat) (written : Option StateWritten) (reason : EffectRefusal),
    1 ≤ config.maxPatience → height + 1 < 256 ^ 8 → funds.effects = true →
    stateWrite config snapshot object current viewed write = .ok written →
    transferVerdict config funds (reserve (decidedAwait cell generation checkpoint height .settled)) written
      recipient amount = .refused reason →
    commitYield config snapshot height transaction cell object generation checkpoint current viewed
      (transferPlan write recipient amount) funds reserve =
      .ok ⟨decidedAwait cell generation checkpoint height (.refused reason), none, [], none⟩

/-- **2'. The refusals, by name.** An uncovered transfer to an admissible recipient is refused
`unfunded`; a transfer to the purse, the collector or the issuer well is refused `reserved`; one
to an account the Book does not hold open is refused `closed`. Exactly the covered transfer to an
admissible recipient is performed. -/
def VerdictStatement : Prop :=
  ∀ (config : Config) (funds : Funds) (reserve : Nat) (written : Option StateWritten)
    (recipient : AccountId) (amount : Nat),
    (Admissible config funds written recipient → purse (funds.book written) config.asset funds.purse < amount + reserve →
      transferVerdict config funds reserve written recipient amount = .refused .unfunded) ∧
    ((recipient = funds.purse ∨ recipient = config.collector ∨ recipient = config.asset) →
      transferVerdict config funds reserve written recipient amount = .refused .reserved) ∧
    ((recipient ≠ funds.purse ∧ recipient ≠ config.collector ∧ recipient ≠ config.asset) →
      recipient ∉ (funds.book written).accounts →
      transferVerdict config funds reserve written recipient amount = .refused .closed) ∧
    (transferVerdict config funds reserve written recipient amount = .settled ↔
      Admissible config funds written recipient ∧ amount + reserve ≤ purse (funds.book written) config.asset funds.purse)

/-- **2''. Refused, in the turn.** An admitted delivery whose yield's effect was refused posts
only its own charges (nothing from the purse to the recipient) and its yield writes no state. -/
def DeliveryRefusedStatement : Prop :=
  ∀ {rootBytes : Bytes → Digest} {config : Config} {snapshot : Snapshot rootBytes} {height : Nat}
    {request : DeliverRequest} (delivery : Delivery config snapshot height request) (committed : YieldCommit)
    (reason : EffectRefusal),
    delivery.yielded = some committed → committed.await.source = .performed (.refused reason) →
    delivery.posted.batch = withEffect
        (deliveryCharges config delivery.record request.record delivery.settlement.path request
          (drainFee config delivery.object none)) [] ∧
    committed.written = none ∧ committed.posts = []

/-- **2'''. The law's teeth on a commit.** A `commit` writes only through the object's law: every
admitted delivery whose segment yields a `commit` and writes, wrote a state the object's law
admitted under the activity's principal. So a law-refused commit refuses the turn: no delivery is
admitted, nothing is written. -/
def CommitJudgedStatement : Prop :=
  ∀ {rootBytes : Bytes → Digest} {config : Config} {snapshot : Snapshot rootBytes} {height : Nat}
    {request : DeliverRequest} (delivery : Delivery config snapshot height request) (state : State)
    (write : Data) (committed : YieldCommit) (written : StateWritten),
    delivery.segment = .yielded state (commitPlan write) → delivery.yielded = some committed →
    committed.written = some written →
    admitWrite delivery.object (factsOf delivery.record.escrow.payer height delivery.record.object 2
      (some delivery.record.pin)) (written.before.map ObjectState.value) written.after.value = .ok ()

/-- **3. Resumed.** A performed await is settled by any delivery at any height with exactly the
outcome the yield recorded (no decider, no due height, no deadline, no slot), and the delivery
resumes the stored checkpoint with `responseData outcome view`. -/
def ResumedStatement : Prop :=
  (∀ {rootBytes : Bytes → Digest} (config : Config) (snapshot : Snapshot rootBytes) (height : Nat)
    (cell : CellId) (await : Await) (verdict : Verdict),
    await.source = .performed verdict →
    settle config snapshot height cell await = .ok ⟨.resumed, verdict.outcome, [], [], []⟩) ∧
  (∀ {rootBytes : Bytes → Digest} {config : Config} {snapshot : Snapshot rootBytes} {height : Nat}
    {request : DeliverRequest} (delivery : Delivery config snapshot height request) (verdict : Verdict),
    delivery.await.source = .performed verdict →
    delivery.settlement.decided = verdict.outcome ∧
      resume (responseData verdict.outcome delivery.view).term delivery.state = some delivery.resumed)

/-! ## The poles -/

/-- The pole's purse, payer (recipient) and asset. -/
def polePurse : AccountId := 1001
def polePayer : AccountId := 7
def poleAsset : AssetId := 0

/-- The pole's Book: the purse holds 10 of the credit asset; the purse and the payer are open. -/
def poleBook : Book :=
  { Book.empty with accounts := {polePurse, polePayer}, balances := DFinsupp.single (polePurse, poleAsset) 10 }

/-- The pole's funds: a program typing the effect outcomes, the pole's purse and Book. -/
def poleFunds (base : Record) : Funds := ⟨true, polePurse, fun _ => poleBook, base⟩

/-- The pole's reserve: 3 (the await's fee pair plus its storage deposit). -/
def poleReserve : Await → Nat := fun _ => 3

/-- The deployments the poles run in: the credit asset is `poleAsset`, the collector is neither the
purse nor the payer, and a patience of 1 is admitted. -/
def PoleConfig (config : Config) : Prop :=
  config.asset = poleAsset ∧ config.collector ≠ polePurse ∧ config.collector ≠ polePayer ∧ 1 ≤ config.maxPatience

/-- **Satisfiable.** In a pole deployment, a yield `commit {write: {}}` (keep every field of present
state) is performed `settled`; a yield `transfer {to: payer, amount: 1}` is performed `settled` with
the one posting; and the delivery's response for the recorded await is
`resumed {outcome: settled {}, view}`. -/
def SatisfiablePole : Prop :=
  ∀ {rootBytes : Bytes → Digest} (config : Config) (snapshot : Snapshot rootBytes) (height : Nat)
    (transaction : TransactionId) (cell object : CellId) (generation : Nat) (checkpoint : Digest)
    (state : ObjectState) (base : Record) (view : ObjectState),
    PoleConfig config → height + 1 < 256 ^ 8 →
    (∃ committed, commitYield config snapshot height transaction cell object generation checkpoint (some state) true
        (commitPlan (.record [])) (poleFunds base) poleReserve = .ok committed ∧
      committed.await = decidedAwait cell generation checkpoint height .settled ∧ committed.effect = none) ∧
    (∃ committed, commitYield config snapshot height transaction cell object generation checkpoint (some state) true
        (transferPlan (.record []) polePayer 1) (poleFunds base) poleReserve = .ok committed ∧
      committed.await = decidedAwait cell generation checkpoint height .settled ∧
      effectOps config polePurse (some committed) = [.transfer polePurse polePayer poleAsset 1] ∧
      ∃ settlement, settle config snapshot height cell committed.await = .ok settlement ∧
        responseData settlement.decided view =
          .variant "resumed" (.record [("outcome", .variant "settled" (.record [])), ("view", viewData view)]))

/-- **Teeth.** In the same deployment, `transfer {to: payer, amount: 8}` (one above
purse − reserve = 10 − 3) is refused `unfunded` and `transfer {to: purse, amount: 1}` is refused
`reserved`; each writes nothing, posts nothing and moves nothing (no effect posting); the purse,
the recipient and the state are untouched by the yield. -/
def TeethPole : Prop :=
  ∀ {rootBytes : Bytes → Digest} (config : Config) (snapshot : Snapshot rootBytes) (height : Nat)
    (transaction : TransactionId) (cell object : CellId) (generation : Nat) (checkpoint : Digest)
    (state : ObjectState) (base : Record),
    PoleConfig config → height + 1 < 256 ^ 8 →
    commitYield config snapshot height transaction cell object generation checkpoint (some state) true
        (transferPlan (.record []) polePayer 8) (poleFunds base) poleReserve =
      .ok ⟨decidedAwait cell generation checkpoint height (.refused .unfunded), none, [], none⟩ ∧
    commitYield config snapshot height transaction cell object generation checkpoint (some state) true
        (transferPlan (.record []) polePurse 1) (poleFunds base) poleReserve =
      .ok ⟨decidedAwait cell generation checkpoint height (.refused .reserved), none, [], none⟩ ∧
    effectOps config polePurse
      (some ⟨decidedAwait cell generation checkpoint height (.refused .unfunded), none, [], none⟩) = []

/-- **Premise inhabitation.** The performed premises hold together: a pole deployment's funds have
an admissible recipient (the payer's own open account) and a purse covering amount 1 plus the
reserve. -/
def PremiseInhabitedPole : Prop :=
  ∀ (config : Config) (base : Record) (written : Option StateWritten) (settledAwait : Await),
    PoleConfig config →
    Admissible config (poleFunds base) written polePayer ∧
      Covered config (poleFunds base) poleReserve written settledAwait 1

/-! ## Proofs -/

theorem transferVerdict_settled_iff {config : Config} {funds : Funds} {reserve : Nat} {written : Option StateWritten}
    {recipient : AccountId} {amount : Nat} :
    transferVerdict config funds reserve written recipient amount = .settled ↔
      Admissible config funds written recipient ∧
        amount + reserve ≤ purse (funds.book written) config.asset funds.purse := by
  unfold transferVerdict Admissible
  by_cases r : recipient = funds.purse ∨ recipient = config.collector ∨ recipient = config.asset
  · rw [if_pos r]
    constructor
    · intro h; cases h
    · rintro ⟨⟨a, b, c, _⟩, _⟩; rcases r with r | r | r <;> contradiction
  · rw [if_neg r]
    simp only [not_or] at r
    by_cases o : recipient ∈ (funds.book written).accounts
    · rw [if_neg (not_not.mpr o)]
      by_cases c : amount + reserve ≤ purse (funds.book written) config.asset funds.purse
      · rw [if_pos c]; exact ⟨fun _ => ⟨⟨r.1, r.2.1, r.2.2, o⟩, c⟩, fun _ => rfl⟩
      · rw [if_neg c]
        constructor
        · intro h; cases h
        · rintro ⟨_, h⟩; exact absurd h c
    · rw [if_pos o]
      constructor
      · intro h; cases h
      · rintro ⟨⟨_, _, _, h⟩, _⟩; exact absurd h o

theorem verdict : VerdictStatement := by
  intro config funds reserve written recipient amount
  refine ⟨?_, ?_, ?_, transferVerdict_settled_iff⟩
  · rintro ⟨a, b, c, o⟩ short
    unfold transferVerdict
    rw [if_neg (by rintro (h | h | h) <;> contradiction), if_neg (not_not.mpr o), if_neg (by omega)]
  · intro r
    unfold transferVerdict
    rw [if_pos r]
  · intro r closed
    unfold transferVerdict
    rw [if_neg (by rintro (h | h | h) <;> simp_all), if_pos closed]

/-- How a yield commits a transfer Plan: by the verdict, at the settled await's reserve. -/
theorem commitYield_transfer {rootBytes : Bytes → Digest} {config : Config} {snapshot : Snapshot rootBytes}
    {height : Nat} {transaction : TransactionId} {cell object : CellId} {generation : Nat} {checkpoint : Digest}
    {current : Option ObjectState} {viewed : Bool} {write : Data} {recipient : AccountId} {amount : Nat}
    {funds : Funds} {reserve : Await → Nat} {written : Option StateWritten}
    (patient : 1 ≤ config.maxPatience) (narrow : height + 1 < 256 ^ 8) (effects : funds.effects = true)
    (wrote : stateWrite config snapshot object current viewed write = .ok written) :
    commitYield config snapshot height transaction cell object generation checkpoint current viewed
        (transferPlan write recipient amount) funds reserve =
      match transferVerdict config funds (reserve (decidedAwait cell generation checkpoint height .settled)) written
          recipient amount with
      | .settled => .ok ⟨decidedAwait cell generation checkpoint height .settled, written,
          (written.map StateWritten.post).toList, some (recipient, amount)⟩
      | .refused reason => .ok ⟨decidedAwait cell generation checkpoint height (.refused reason), none, [], none⟩ := by
  unfold commitYield
  simp only [transferPlan]
  rw [if_neg (by omega), if_neg (by omega), wrote]
  simp only [effects, Bool.not_true, Bool.false_eq_true, if_false]
  rfl

/-- How a yield commits a commit Plan: settled, with its write. -/
theorem commitYield_commit {rootBytes : Bytes → Digest} {config : Config} {snapshot : Snapshot rootBytes}
    {height : Nat} {transaction : TransactionId} {cell object : CellId} {generation : Nat} {checkpoint : Digest}
    {current : Option ObjectState} {viewed : Bool} {write : Data}
    {funds : Funds} {reserve : Await → Nat} {written : Option StateWritten}
    (patient : 1 ≤ config.maxPatience) (narrow : height + 1 < 256 ^ 8) (effects : funds.effects = true)
    (wrote : stateWrite config snapshot object current viewed write = .ok written) :
    commitYield config snapshot height transaction cell object generation checkpoint current viewed
        (commitPlan write) funds reserve =
      .ok ⟨decidedAwait cell generation checkpoint height .settled, written, (written.map StateWritten.post).toList,
        none⟩ := by
  unfold commitYield
  simp only [commitPlan]
  rw [if_neg (by omega), if_neg (by omega), wrote]
  simp only [effects, Bool.not_true, Bool.false_eq_true, if_false]
  rfl

theorem performed : PerformedStatement := by
  intro rootBytes config snapshot height transaction cell object generation checkpoint current viewed write
    recipient amount funds reserve written patient narrow effects wrote admissible covered
  have settled := transferVerdict_settled_iff.mpr ⟨admissible, covered⟩
  rw [commitYield_transfer patient narrow effects wrote, settled]
  exact ⟨_, rfl, rfl, rfl, rfl, rfl⟩

theorem refused : RefusedStatement := by
  intro rootBytes config snapshot height transaction cell object generation checkpoint current viewed write
    recipient amount funds reserve written reason patient narrow effects wrote decided
  rw [commitYield_transfer patient narrow effects wrote, decided]

theorem transferMoves : TransferMovesStatement := by
  intro book source recipient asset amount distinct
  have other : (recipient, asset) ≠ (source, asset) := fun h => distinct (congrArg Prod.fst h).symm
  have other' : (source, asset) ≠ (recipient, asset) := fun h => distinct (congrArg Prod.fst h)
  simp only [Operation.apply, Operation.posting, Operation.leaseRecord?, Operation.floorSetting?, Book.applyPosting,
    Book.balance, DFinsupp.coe_add, Pi.add_apply, DFinsupp.single_apply, other, other', if_true, if_false]
  constructor <;> simp <;> omega

/-- A committed yield whose await was refused wrote, posted and moved nothing. -/
theorem commitYield_refused_shape {rootBytes : Bytes → Digest} {config : Config} {snapshot : Snapshot rootBytes}
    {height : Nat} {transaction : TransactionId} {cell object : CellId} {generation : Nat} {checkpoint : Digest}
    {current : Option ObjectState} {viewed : Bool} {plan : PlanAwait} {funds : Funds} {reserve : Await → Nat}
    {committed : YieldCommit} {reason : EffectRefusal}
    (ok : commitYield config snapshot height transaction cell object generation checkpoint current viewed plan funds
      reserve = .ok committed)
    (source : committed.await.source = .performed (.refused reason)) :
    committed.written = none ∧ committed.posts = [] ∧ committed.effect = none := by
  unfold commitYield at ok
  split at ok
  · cases ok
  · split at ok
    · cases ok
    · split at ok
      · cases ok
      · split at ok
        · split at ok
          · cases ok
          · simp only [Except.ok.injEq] at ok; subst ok; cases source
        · split at ok
          · cases ok
          · simp only [Except.ok.injEq] at ok; subst ok; cases source
        · split at ok
          · cases ok
          · split at ok
            · simp only [Except.ok.injEq] at ok; subst ok; cases source
            · split at ok
              · simp only [Except.ok.injEq] at ok; subst ok; cases source
              · simp only [Except.ok.injEq] at ok; subst ok; exact ⟨rfl, rfl, rfl⟩

/-- An admitted delivery's yield commit is its segment's commit under the delivery's funds. -/
theorem delivery_commit {rootBytes : Bytes → Digest} {config : Config} {snapshot : Snapshot rootBytes}
    {height : Nat} {request : DeliverRequest} (delivery : Delivery config snapshot height request)
    {committed : YieldCommit} (yielded : delivery.yielded = some committed) :
    delivery.segment.yields = true ∧
      ∃ state plan funds reserve, delivery.segment = .yielded state plan ∧
        commitYield config snapshot height (deliveryTransaction delivery.await.id) request.record
          delivery.record.object (delivery.record.generation + 1)
          (checkpointDigest (checkpointBytes state)) (some delivery.view) true plan funds reserve = .ok committed := by
  have commit := resumedSegment_commit delivery.endExact
  rw [yielded] at commit
  obtain ⟨state, plan, isYield, committedExact⟩ := segmentCommit_spec commit
  refine ⟨by rw [isYield]; rfl, state, plan, _, _, isYield, committedExact⟩

theorem deliveryPerformed : DeliveryPerformedStatement := by
  intro rootBytes config snapshot height request delivery committed recipient amount yielded effect
  obtain ⟨yields, _⟩ := delivery_commit delivery yielded
  have settled := settlePurse_yields _ _ _ _ _ _ _ _ yields delivery.batchExact
  refine ⟨?_, delivery.conserves⟩
  rw [delivery.postedBatch, settled.1]
  simp only [effectOps, yielded, effect]

theorem deliveryRefused : DeliveryRefusedStatement := by
  intro rootBytes config snapshot height request delivery committed reason yielded source
  obtain ⟨yields, state, plan, funds, reserve, _, ok⟩ := delivery_commit delivery yielded
  obtain ⟨noWrite, noPosts, noEffect⟩ := commitYield_refused_shape ok source
  have settled := settlePurse_yields _ _ _ _ _ _ _ _ yields delivery.batchExact
  refine ⟨?_, noWrite, noPosts⟩
  rw [delivery.postedBatch, settled.1]
  simp only [effectOps, yielded, noEffect, Option.bind_some, noWrite]

theorem commitJudged : CommitJudgedStatement := by
  intro rootBytes config snapshot height request delivery state write committed written _ yielded writes
  exact judgeWritten_ok delivery.judged written (by rw [yielded]; exact writes)

theorem resumed : ResumedStatement := by
  refine ⟨?_, ?_⟩
  · intro rootBytes config snapshot height cell await verdict source
    unfold settle
    rw [source]
  · intro rootBytes config snapshot height request delivery verdict source
    have settledEq := delivery.settled
    unfold settle at settledEq
    rw [source] at settledEq
    have decided : delivery.settlement.decided = verdict.outcome := by
      rw [← Except.ok.inj settledEq]
    exact ⟨decided, decided ▸ delivery.resumeExact⟩

/-! ### The poles, proved -/

theorem poleBook_purse : purse poleBook poleAsset polePurse = 10 := by
  simp [purse, poleBook, Book.balance, polePurse, poleAsset]

theorem poleBook_payer_open : polePayer ∈ poleBook.accounts := by
  simp [poleBook, polePayer, polePurse]

theorem pole_unviewed_keep {rootBytes : Bytes → Digest} (config : Config) (snapshot : Snapshot rootBytes)
    (object : CellId) (state : ObjectState) :
    stateWrite config snapshot object (some state) true (.record []) = .ok none := rfl

theorem premiseInhabited : PremiseInhabitedPole := by
  rintro config base written settledAwait ⟨asset, collectorPurse, collectorPayer, _⟩
  refine ⟨⟨show polePayer ≠ polePurse by decide, Ne.symm collectorPayer,
    show polePayer ≠ config.asset by rw [asset]; decide, poleBook_payer_open⟩, ?_⟩
  show 1 + poleReserve settledAwait ≤ purse poleBook config.asset polePurse
  rw [asset, poleBook_purse]
  show 1 + 3 ≤ 10
  decide

theorem satisfiable : SatisfiablePole := by
  intro rootBytes config snapshot height transaction cell object generation checkpoint state base view
    pole narrow
  have patient := pole.2.2.2
  have wrote := pole_unviewed_keep config snapshot object state
  refine ⟨⟨_, commitYield_commit patient narrow rfl wrote, rfl, rfl⟩, ?_⟩
  obtain ⟨admissible, covered⟩ := premiseInhabited config base none
    (decidedAwait cell generation checkpoint height .settled) pole
  have settled := transferVerdict_settled_iff.mpr ⟨admissible, covered⟩
  have committed := commitYield_transfer (recipient := polePayer) (amount := 1) (reserve := poleReserve)
    (transaction := transaction) (cell := cell) (generation := generation) (checkpoint := checkpoint)
    patient narrow (show (poleFunds base).effects = true from rfl) wrote
  rw [settled] at committed
  refine ⟨_, committed, rfl, by simp [effectOps, pole.1], ⟨.resumed, .settled, [], [], []⟩, ?_, rfl⟩
  exact (resumed.1 config snapshot height cell _ .settled rfl)

theorem teeth : TeethPole := by
  intro rootBytes config snapshot height transaction cell object generation checkpoint state base pole narrow
  have patient := pole.2.2.2
  have wrote := pole_unviewed_keep config snapshot object state
  refine ⟨?_, ?_, rfl⟩
  · rw [refused config snapshot height transaction cell object generation checkpoint (some state) true (.record [])
      polePayer 8 (poleFunds base) poleReserve none .unfunded patient narrow rfl wrote]
    obtain ⟨admissible, _⟩ := premiseInhabited config base none
      (decidedAwait cell generation checkpoint height .settled) pole
    apply (verdict config (poleFunds base) 3 none polePayer 8).1 admissible
    show purse poleBook config.asset polePurse < 8 + 3
    rw [pole.1, poleBook_purse]; decide
  · rw [refused config snapshot height transaction cell object generation checkpoint (some state) true (.record [])
      polePurse 1 (poleFunds base) poleReserve none .reserved patient narrow rfl wrote]
    exact (verdict config (poleFunds base) 3 none polePurse 1).2.1 (.inl rfl)

/-- info: 'Minidregg.Kernel.ObjectiveActivityEffect.performed' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms performed
#assert_axioms performed
#assert_axioms deliveryPerformed
#assert_axioms transferMoves
#assert_axioms refused
#assert_axioms verdict
#assert_axioms deliveryRefused
#assert_axioms commitJudged
#assert_axioms resumed
#assert_axioms satisfiable
#assert_axioms teeth
#assert_axioms premiseInhabited

end Minidregg.Kernel.ObjectiveActivityEffect
